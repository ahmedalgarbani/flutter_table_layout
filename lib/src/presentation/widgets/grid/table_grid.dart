import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/labels.dart';
import '../../../core/theme.dart';
import '../../../data/exporters/export_utils.dart';
import '../../../domain/models/column_definition.dart';
import '../../../domain/models/table_aggregate.dart';
import '../../../domain/models/table_column_group.dart';
import '../../../domain/utils/table_text_normalizer.dart';
import '../../cubit/table_cubit.dart';
import '../../cubit/table_cubit_state.dart';
import '../../export/table_export_runner.dart';
import '../adaptive_table_layout.dart';
import 'cell_editor.dart';
import 'cell_renderer.dart';
import 'pinned_row.dart';
import 'table_entries.dart';

/// Builds what the grid shows under its header when there are no rows.
/// [columns] are the visible columns in display order with their laid-out
/// `width`, [leadingWidth] the width of the expand / selection columns.
typedef GridEmptyBuilder =
    Widget Function(List<ColumnDefinition> columns, double leadingWidth);

/// The desktop data grid: sticky header, frozen columns, virtualized rows,
/// resizable / reorderable columns, per-column filters, grouping, inline
/// editing, a totals row and keyboard navigation.
class TableGrid<T> extends StatefulWidget {
  final TableLoaded<T> state;
  final List<AdaptiveTableColumn<T>> columns;
  final CellRenderer<T> renderer;
  final bool showSelection;
  final double minDesktopWidth;
  final ValueChanged<T>? onRowTap;
  final ValueChanged<T>? onRowLongPress;
  final Widget Function(BuildContext, T)? expandedRowBuilder;
  final bool showColumnFilters;
  final bool allowColumnResize;
  final bool allowColumnReorder;
  final bool showColumnMenu;
  final bool enableKeyboardNavigation;
  final bool enableRangeSelection;
  final bool tristateSort;
  final List<TableColumnGroup> columnGroups;
  final RowReorderCallback<T>? onRowReorder;
  final CellEditCallback<T>? onCellEdited;
  final CanEditCell<T>? canEditCell;
  final GroupHeaderBuilder<T>? groupHeaderBuilder;
  final double minRowHeight;
  final TableExportRunner<T>? exportRunner;
  final GridEmptyBuilder emptyBuilder;
  final AdaptiveTableTheme theme;
  final AdaptiveTableLabels labels;

  const TableGrid({
    super.key,
    required this.state,
    required this.columns,
    required this.renderer,
    required this.showSelection,
    required this.minDesktopWidth,
    this.onRowTap,
    this.onRowLongPress,
    this.expandedRowBuilder,
    this.showColumnFilters = false,
    this.allowColumnResize = true,
    this.allowColumnReorder = true,
    this.showColumnMenu = true,
    this.enableKeyboardNavigation = true,
    this.enableRangeSelection = true,
    this.tristateSort = false,
    this.columnGroups = const [],
    this.onRowReorder,
    this.onCellEdited,
    this.canEditCell,
    this.groupHeaderBuilder,
    this.minRowHeight = 0,
    this.exportRunner,
    required this.emptyBuilder,
    required this.theme,
    required this.labels,
  });

  static const double selectionColumnWidth = 48;
  static const double expandColumnWidth = 44;
  static const double reorderColumnWidth = 36;
  static const double minFlexColumnWidth = 80;

  /// Splits spreadsheet clipboard text into rows of cells (tab-separated,
  /// with `"quoted"` cells that may hold tabs, line breaks and `""`).
  static List<List<String>> parseClipboard(String text) =>
      _TableGridState.parseClipboard(text);

  @override
  State<TableGrid<T>> createState() => _TableGridState<T>();
}

/// What a dragged row carries (see `onRowReorder`).
class RowDragData<T> {
  final T item;
  const RowDragData(this.item);
}

/// The cell being edited: its row key, its row index (fallback when the
/// edited item is replaced by a new instance) and its column.
typedef _EditRef = ({Object? key, int row, String columnId});

class _TableGridState<T> extends State<TableGrid<T>> {
  final ScrollController _h = ScrollController();
  final ScrollController _v = ScrollController();
  final FocusNode _focusNode = FocusNode(debugLabel: 'TableGrid');
  BuildContext? _focusedCellContext;

  /// Widths while a header edge is being dragged (not yet in the cubit).
  final Map<String, double> _dragWidths = {};

  /// Widths computed on the last layout (used to start a resize).
  final Map<String, double> _lastWidths = {};

  _EditRef? _editing;
  bool _editingDropdown = false;
  String? _editError;
  bool _committing = false;

  /// Focused cell: index among displayed rows / among visible columns.
  ({int row, int col})? _focus;

  /// The other corner of the selected cell range (`null` = only [_focus]).
  ({int row, int col})? _anchor;
  bool _dragSelecting = false;
  bool _pasting = false;

  /// The selected rectangle of cells, or `null` without a focused cell.
  ({int top, int left, int bottom, int right})? get _range {
    final f = _focus;
    if (f == null) return null;
    final a = _anchor ?? f;
    return (
      top: math.min(a.row, f.row),
      left: math.min(a.col, f.col),
      bottom: math.max(a.row, f.row),
      right: math.max(a.col, f.col),
    );
  }

  bool get _hasRange {
    final r = _range;
    return r != null && (r.top != r.bottom || r.left != r.right);
  }

  bool _inRange(int row, int col) {
    final r = _range;
    return r != null &&
        row >= r.top &&
        row <= r.bottom &&
        col >= r.left &&
        col <= r.right;
  }

  // Snapshot of the last build, used by the keyboard handler.
  List<RowEntry<T>> _rows = const [];
  List<AdaptiveTableColumn<T>> _cols = const [];
  Set<Object?> _selectedKeys = const {};
  Set<Object?> _expandedKeys = const {};

  AdaptiveTableTheme get theme => widget.theme;
  AdaptiveTableLabels get labels => widget.labels;
  TableCubit<T> get _cubit => context.read<TableCubit<T>>();

  @override
  void didUpdateWidget(covariant TableGrid<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.state.columnWidths, widget.state.columnWidths)) {
      _dragWidths.clear();
    }
  }

  @override
  void dispose() {
    _h.dispose();
    _v.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------- layout

  ({List<double> widths, double system, double total}) _computeWidths(
    List<AdaptiveTableColumn<T>> cols,
    double viewport,
  ) {
    final double system =
        (widget.onRowReorder != null ? TableGrid.reorderColumnWidth : 0) +
        (widget.expandedRowBuilder != null ? TableGrid.expandColumnWidth : 0) +
        (widget.showSelection ? TableGrid.selectionColumnWidth : 0);
    final widths = List<double?>.filled(cols.length, null);
    var fixedSum = 0.0;
    var flexSum = 0;
    var flexMinSum = 0.0;
    for (var i = 0; i < cols.length; i++) {
      final c = cols[i];
      final w = _dragWidths[c.id] ?? widget.state.columnWidths[c.id] ?? c.width;
      if (w != null) {
        widths[i] = math.max(w, c.minWidth);
        fixedSum += widths[i]!;
      } else {
        flexSum += c.flex;
        flexMinSum += math.max(TableGrid.minFlexColumnWidth, c.minWidth);
      }
    }
    final target = math.max(viewport, widget.minDesktopWidth);
    final flexSpace = math.max(target - system - fixedSum, flexMinSum);
    for (var i = 0; i < cols.length; i++) {
      if (widths[i] != null) continue;
      final c = cols[i];
      widths[i] = math.max(
        math.max(TableGrid.minFlexColumnWidth, c.minWidth),
        flexSum == 0 ? 0 : flexSpace * c.flex / flexSum,
      );
    }
    final result = widths.cast<double>();
    final total = system + result.fold<double>(0, (a, b) => a + b);
    return (widths: result, system: system, total: total);
  }

  /// Keeps the edited cell on its row when the rows are rebuilt: matched by
  /// row key, or by position when the edited item was replaced by a new
  /// instance that is not `==` to it (immutable models without `rowKey`).
  void _resolveEditing() {
    final editing = _editing;
    if (editing == null) return;
    final state = widget.state;
    final match = _rows.indexWhere((r) => state.keyOf(r.item) == editing.key);
    if (match == editing.row) return;
    if (match != -1) {
      _editing = (key: editing.key, row: match, columnId: editing.columnId);
    } else if (editing.row < _rows.length) {
      final item = _rows[editing.row].item;
      _editing = (
        key: state.keyOf(item),
        row: editing.row,
        columnId: editing.columnId,
      );
    } else {
      _editing = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final cols = state.arrange(widget.columns, (c) => c.definition);
    final entries = buildTableEntries<T>(
      state,
      valueProviders: widget.renderer.valueProviders,
      groupFormatter: _groupFormatter(state),
    );
    _cols = cols;
    _rows = entries.whereType<RowEntry<T>>().toList();
    _selectedKeys = state.selectedKeys;
    _expandedKeys = state.expandedKeys;
    _resolveEditing();
    if (_focus != null &&
        (_focus!.row >= _rows.length || _focus!.col >= cols.length)) {
      _focus = null;
    }
    if (_anchor != null &&
        (_focus == null ||
            _anchor!.row >= _rows.length ||
            _anchor!.col >= cols.length)) {
      _anchor = null;
    }
    final direction = Directionality.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final viewport = constraints.maxWidth;
        final bounded = constraints.hasBoundedHeight;
        final layout = _computeWidths(cols, viewport);
        _lastWidths
          ..clear()
          ..addAll({
            for (var i = 0; i < cols.length; i++) cols[i].id: layout.widths[i],
          });
        final metrics = GridHorizontalMetrics(
          controller: _h,
          overflow: math.max(0, layout.total - viewport),
        );
        final contentWidth = math.max(layout.total, viewport);

        final header = _buildHeader(cols, layout.widths, metrics, direction);
        final groupBand = _buildGroupBand(
          cols,
          layout.widths,
          metrics,
          direction,
        );
        final filterRow = widget.showColumnFilters
            ? _buildFilterRow(cols, layout.widths, metrics, direction)
            : null;
        final totalsRow = entries.isEmpty
            ? null
            : _buildTotalsRow(cols, layout.widths, metrics, direction);

        Widget buildEntry(int index) {
          final entry = entries[index];
          Widget child = switch (entry) {
            GroupEntry<T>() => _buildGroupHeader(entry.info, metrics, viewport),
            RowEntry<T>() => _buildRow(
              entry,
              cols,
              layout.widths,
              metrics,
              direction,
              viewport,
            ),
          };
          if (entry is RowEntry<T> && _canReorderRows) {
            child = _rowDropTarget(
              before: entry.item,
              child: child,
              // The last row also takes drops meant for "after it".
              last: index == entries.length - 1,
            );
          }
          if (index == 0) return child;
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Divider(height: 1, color: theme.dividerColor),
              child,
            ],
          );
        }

        Widget body;
        if (entries.isEmpty) {
          body = ViewportAnchored(
            metrics: metrics,
            viewportWidth: viewport,
            child: widget.emptyBuilder([
              for (var i = 0; i < cols.length; i++)
                cols[i].definition.copyWith(
                  width: layout.widths[i],
                  isVisible: true,
                ),
            ], layout.system),
          );
        } else if (bounded) {
          body = ListView.builder(
            controller: _v,
            padding: EdgeInsets.zero,
            itemCount: entries.length,
            itemBuilder: (context, i) => buildEntry(i),
          );
        } else {
          body = Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [for (var i = 0; i < entries.length; i++) buildEntry(i)],
          );
        }
        if (widget.enableKeyboardNavigation) {
          // The rows are one Tab stop with their own cell navigation; the
          // header and the filter fields stay regular Tab stops (and keep
          // their keys: typing in a filter field is not grid navigation).
          body = Focus(
            focusNode: _focusNode,
            descendantsAreTraversable: false,
            onKeyEvent: _onKey,
            onFocusChange: _onGridFocusChange,
            child: body,
          );
        }

        Widget grid = Column(
          mainAxisSize: bounded ? MainAxisSize.max : MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (groupBand != null) ...[
              groupBand,
              Divider(height: 1, color: theme.dividerColor),
            ],
            header,
            Divider(height: 1, thickness: 1, color: theme.dividerColor),
            if (filterRow != null) ...[
              filterRow,
              Divider(height: 1, color: theme.dividerColor),
            ],
            if (bounded) Expanded(child: body) else body,
            if (totalsRow != null) ...[
              Divider(height: 1, thickness: 1, color: theme.dividerColor),
              totalsRow,
            ],
          ],
        );

        if (metrics.scrolls) {
          grid = Scrollbar(
            controller: _h,
            notificationPredicate: (n) =>
                n.depth == 0 && n.metrics.axis == Axis.horizontal,
            child: SingleChildScrollView(
              controller: _h,
              scrollDirection: Axis.horizontal,
              child: SizedBox(width: contentWidth, child: grid),
            ),
          );
        }
        if (bounded && entries.isNotEmpty) {
          grid = Scrollbar(
            controller: _v,
            notificationPredicate: (n) => n.metrics.axis == Axis.vertical,
            child: grid,
          );
        }
        return grid;
      },
    );
  }

  // ---------------------------------------------------------- row reorder

  /// Rows can only be moved in their own order: not while sorted or grouped.
  bool get _canReorderRows =>
      widget.onRowReorder != null &&
      widget.state.tableState.sorts.isEmpty &&
      widget.state.tableState.groupByColumnId == null;

  Widget _dragHandle(T item) {
    final enabled = _canReorderRows;
    final icon = Icon(
      Icons.drag_indicator,
      size: 18,
      color: theme.actionIconColor.withValues(alpha: enabled ? 0.8 : 0.25),
    );
    if (!enabled) {
      return Tooltip(message: labels.reorderUnavailable, child: icon);
    }
    return Draggable<RowDragData<T>>(
      data: RowDragData<T>(item),
      axis: Axis.vertical,
      feedback: Material(
        elevation: 6,
        borderRadius: BorderRadius.circular(6),
        color: widget.renderer.opaque(theme.rowBackgroundColor),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.drag_indicator, size: 18, color: theme.accentColor),
              const SizedBox(width: 6),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 260),
                child: Text(
                  _cols.isEmpty
                      ? ''
                      : widget.renderer.textFor(_cols.first, item),
                  style: theme.rowTextStyle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
      child: MouseRegion(
        cursor: SystemMouseCursors.grab,
        child: Tooltip(message: labels.reorderRow, child: icon),
      ),
    );
  }

  /// Dropping a dragged row on [child] moves it before [before]; on the
  /// lower half of the [last] row it moves to the end.
  Widget _rowDropTarget({
    required T before,
    required Widget child,
    required bool last,
  }) {
    final state = widget.state;
    return Builder(
      builder: (targetContext) {
        bool after(DragTargetDetails<RowDragData<T>> d) {
          if (!last) return false;
          final box = targetContext.findRenderObject();
          if (box is! RenderBox || !box.hasSize) return false;
          return box.globalToLocal(d.offset).dy > box.size.height / 2;
        }

        return DragTarget<RowDragData<T>>(
          onWillAcceptWithDetails: (d) =>
              state.keyOf(d.data.item) != state.keyOf(before) || last,
          onAcceptWithDetails: (d) {
            final toEnd = after(d);
            if (!toEnd && state.keyOf(d.data.item) == state.keyOf(before)) {
              return;
            }
            widget.onRowReorder!(d.data.item, toEnd ? null : before);
          },
          builder: (context, candidates, rejected) => DecoratedBox(
            position: DecorationPosition.foreground,
            decoration: BoxDecoration(
              border: candidates.isEmpty
                  ? null
                  : Border(top: BorderSide(color: theme.accentColor, width: 2)),
            ),
            child: child,
          ),
        );
      },
    );
  }

  // --------------------------------------------------------- column groups

  /// The band of [TableColumnGroup] titles above the column headers, or
  /// `null` when no displayed column belongs to a group.
  Widget? _buildGroupBand(
    List<AdaptiveTableColumn<T>> cols,
    List<double> widths,
    GridHorizontalMetrics metrics,
    TextDirection direction,
  ) {
    if (widget.columnGroups.isEmpty) return null;
    final groupOf = <String, TableColumnGroup>{
      for (final g in widget.columnGroups)
        for (final id in g.columnIds) id: g,
    };
    if (!cols.any((c) => groupOf.containsKey(c.id))) return null;
    final state = widget.state;
    // Runs of adjacent columns of the same group and frozen zone.
    final cells = <PinnedCell>[];
    var i = 0;
    while (i < cols.length) {
      final group = groupOf[cols[i].id];
      final pin = state.pinOf(cols[i].definition);
      var width = widths[i];
      var j = i + 1;
      while (group != null &&
          j < cols.length &&
          identical(groupOf[cols[j].id], group) &&
          state.pinOf(cols[j].definition) == pin) {
        width += widths[j];
        j++;
      }
      cells.add(
        PinnedCell(
          width: width,
          pin: pin,
          child: group == null
              ? const SizedBox.shrink()
              : Container(
                  alignment: Alignment.center,
                  padding: EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: theme.headerPadding.vertical / 4,
                  ),
                  decoration: BoxDecoration(
                    border: BorderDirectional(
                      start: BorderSide(color: theme.dividerColor),
                      end: BorderSide(color: theme.dividerColor),
                    ),
                  ),
                  child: Text(
                    group.title,
                    style: theme.headerTextStyle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
        ),
      );
      i = j;
    }
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.headerGradient == null
            ? theme.headerBackgroundColor
            : null,
        gradient: theme.headerGradient,
      ),
      child: PinnedRow(
        metrics: metrics,
        textDirection: direction,
        pinnedBackground: _headerSolid,
        pinnedDividerColor: theme.dividerColor,
        children: [
          if (widget.onRowReorder != null)
            const PinnedCell(
              width: TableGrid.reorderColumnWidth,
              pin: ColumnPin.start,
              child: SizedBox.shrink(),
            ),
          if (widget.expandedRowBuilder != null)
            const PinnedCell(
              width: TableGrid.expandColumnWidth,
              pin: ColumnPin.start,
              child: SizedBox.shrink(),
            ),
          if (widget.showSelection)
            const PinnedCell(
              width: TableGrid.selectionColumnWidth,
              pin: ColumnPin.start,
              child: SizedBox.shrink(),
            ),
          ...cells,
        ],
      ),
    );
  }

  String Function(dynamic)? _groupFormatter(TableLoaded<T> state) {
    final id = state.tableState.groupByColumnId;
    if (id == null) return null;
    return widget.columns.where((c) => c.id == id).firstOrNull?.valueFormatter;
  }

  // ---------------------------------------------------------------- header

  Color get _headerSolid {
    final gradient = theme.headerGradient;
    if (gradient != null && gradient.colors.isNotEmpty) {
      return widget.renderer.opaque(gradient.colors.first);
    }
    return widget.renderer.opaque(theme.headerBackgroundColor);
  }

  Widget _buildHeader(
    List<AdaptiveTableColumn<T>> cols,
    List<double> widths,
    GridHorizontalMetrics metrics,
    TextDirection direction,
  ) {
    final state = widget.state;
    final cubit = _cubit;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.headerGradient == null
            ? theme.headerBackgroundColor
            : null,
        gradient: theme.headerGradient,
      ),
      child: PinnedRow(
        metrics: metrics,
        textDirection: direction,
        pinnedBackground: _headerSolid,
        pinnedDividerColor: theme.dividerColor,
        children: [
          if (widget.onRowReorder != null)
            const PinnedCell(
              width: TableGrid.reorderColumnWidth,
              pin: ColumnPin.start,
              child: SizedBox.shrink(),
            ),
          if (widget.expandedRowBuilder != null)
            const PinnedCell(
              width: TableGrid.expandColumnWidth,
              pin: ColumnPin.start,
              child: SizedBox.shrink(),
            ),
          if (widget.showSelection)
            PinnedCell(
              width: TableGrid.selectionColumnWidth,
              pin: ColumnPin.start,
              child: Center(
                child: Tooltip(
                  message: labels.selectAll,
                  child: Checkbox(
                    tristate: true,
                    value: state.selectAllValue,
                    activeColor: theme.accentColor,
                    checkColor: theme.onAccentColor,
                    side: BorderSide(
                      color:
                          theme.headerTextStyle.color ?? theme.actionIconColor,
                      width: 1.5,
                    ),
                    onChanged: state.filteredAndSortedItems.isEmpty
                        ? null
                        : (_) => cubit.toggleSelectAll(
                            state.selectAllValue != true,
                          ),
                  ),
                ),
              ),
            ),
          for (var i = 0; i < cols.length; i++)
            PinnedCell(
              width: widths[i],
              pin: state.pinOf(cols[i].definition),
              child: _buildHeaderCell(cols[i], widths[i]),
            ),
        ],
      ),
    );
  }

  Widget _buildHeaderCell(AdaptiveTableColumn<T> col, double width) {
    final state = widget.state;
    final sorts = state.tableState.sorts;
    final sortIndex = sorts.indexWhere((s) => s.columnId == col.id);
    final isSorted = sortIndex != -1;
    final isAscending = isSorted && sorts[sortIndex].ascending;
    final canSort =
        col.isSortable && widget.renderer.valueProviders.containsKey(col.id);
    final iconColor = isSorted && theme.headerGradient == null
        ? theme.accentColor
        : (theme.headerTextStyle.color ?? theme.actionIconColor);

    final Widget label;
    if (col.headerBuilder != null) {
      label = col.headerBuilder!(context);
    } else if (col.title.trim().contains(' ')) {
      label = Text(
        col.title,
        style: theme.headerTextStyle,
        overflow: TextOverflow.ellipsis,
        maxLines: 2,
        textAlign: CellRenderer.textAlign(col.alignment),
      );
    } else {
      label = FittedBox(
        fit: BoxFit.scaleDown,
        alignment: CellRenderer.alignment(col.alignment),
        child: Text(col.title, style: theme.headerTextStyle, maxLines: 1),
      );
    }

    Widget content = _HoverRegion(
      builder: (context, hovered) => _withMenuButton(
        col,
        hovered: hovered,
        child: Padding(
          padding: theme.headerPadding,
          child: Row(
            mainAxisAlignment: CellRenderer.mainAxisAlignment(col.alignment),
            children: [
              Flexible(child: label),
              if (canSort) ...[
                const SizedBox(width: 4),
                // Only the sorted columns show their arrow; the others reveal
                // it on hover, which keeps the header calm.
                AnimatedOpacity(
                  duration: const Duration(milliseconds: 150),
                  opacity: isSorted ? 1.0 : (hovered ? 0.45 : 0.0),
                  child: AnimatedRotation(
                    duration: const Duration(milliseconds: 200),
                    turns: isSorted && !isAscending ? 0.5 : 0,
                    child: Icon(Icons.arrow_upward, size: 14, color: iconColor),
                  ),
                ),
                if (isSorted && sorts.length > 1)
                  Text(
                    '${sortIndex + 1}',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: iconColor,
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );

    if (canSort) {
      content = Semantics(
        button: true,
        child: InkWell(
          onTap: () => _cubit.toggleSort(
            col.id,
            additive: HardwareKeyboard.instance.isShiftPressed,
            tristate: widget.tristateSort,
          ),
          child: content,
        ),
      );
    }

    if (widget.showColumnMenu) {
      content = GestureDetector(
        behavior: HitTestBehavior.translucent,
        onSecondaryTapUp: (d) => _openColumnMenu(col, d.globalPosition),
        child: content,
      );
    }

    if (widget.allowColumnReorder) {
      content = _reorderable(col, content, width);
    }

    if (!widget.allowColumnResize || !col.isResizable) return content;
    return Stack(
      children: [
        content,
        PositionedDirectional(
          top: 0,
          bottom: 0,
          end: 0,
          width: 10,
          child: _ResizeHandle(
            color: theme.dividerColor,
            onDrag: (dx) {
              final rtl = Directionality.of(context) == TextDirection.rtl;
              setState(() {
                if (!_dragWidths.containsKey(col.id)) _freezeColumnsBefore(col);
                final current =
                    _dragWidths[col.id] ?? _lastWidths[col.id] ?? width;
                _dragWidths[col.id] = math.max(
                  col.minWidth,
                  current + (rtl ? -dx : dx),
                );
              });
            },
            onEnd: () {
              if (_dragWidths.isNotEmpty) {
                _cubit.setColumnWidths(Map.of(_dragWidths));
              }
            },
            onReset: () => _cubit.resetColumnWidths(col.id),
          ),
        ),
      ],
    );
  }

  /// Shows the ⋮ button of the column menu over the header's end while the
  /// header is hovered.
  Widget _withMenuButton(
    AdaptiveTableColumn<T> col, {
    required bool hovered,
    required Widget child,
  }) {
    if (!widget.showColumnMenu || !hovered) return child;
    final color = theme.headerTextStyle.color ?? theme.actionIconColor;
    return Stack(
      children: [
        child,
        PositionedDirectional(
          end: 10,
          top: 0,
          bottom: 0,
          child: Center(
            child: Builder(
              builder: (buttonContext) => Tooltip(
                message: labels.columnMenu,
                child: Material(
                  color: _headerSolid,
                  shape: const CircleBorder(),
                  child: InkResponse(
                    radius: 14,
                    onTap: () {
                      final box =
                          buttonContext.findRenderObject()! as RenderBox;
                      _openColumnMenu(
                        col,
                        box.localToGlobal(box.size.bottomLeft(Offset.zero)),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(3),
                      child: Icon(Icons.more_vert, size: 16, color: color),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// The column menu: sort, freeze, group, auto-fit, hide.
  Future<void> _openColumnMenu(
    AdaptiveTableColumn<T> col,
    Offset position,
  ) async {
    final state = widget.state;
    final cubit = _cubit;
    final hasValues = widget.renderer.valueProviders.containsKey(col.id);
    final canSort = col.isSortable && hasValues;
    final sorts = state.tableState.sorts;
    final sort = sorts.where((s) => s.columnId == col.id).firstOrNull;
    final pin = state.pinOf(col.definition);
    final grouped = state.tableState.groupByColumnId == col.id;
    final visibleCount = widget.columns.length - state.hiddenColumnIds.length;
    final overlay =
        Overlay.of(context).context.findRenderObject()! as RenderBox;

    PopupMenuItem<String> item(
      String value,
      IconData icon,
      String text, {
      bool active = false,
    }) => PopupMenuItem<String>(
      value: value,
      height: 40,
      child: Row(
        children: [
          Icon(
            icon,
            size: 18,
            color: active ? theme.accentColor : theme.actionIconColor,
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              text,
              overflow: TextOverflow.ellipsis,
              style: theme.rowTextStyle.copyWith(
                fontSize: 13,
                color: active ? theme.accentColor : null,
                fontWeight: active ? FontWeight.w600 : null,
              ),
            ),
          ),
        ],
      ),
    );

    final choice = await showMenu<String>(
      context: context,
      position: RelativeRect.fromRect(
        position & Size.zero,
        Offset.zero & overlay.size,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      color: theme.cardBackgroundColor.withValues(alpha: 1),
      items: [
        if (canSort) ...[
          item(
            'asc',
            Icons.arrow_upward,
            labels.sortAscending,
            active: sort?.ascending == true,
          ),
          item(
            'desc',
            Icons.arrow_downward,
            labels.sortDescending,
            active: sort?.ascending == false,
          ),
          if (sort != null) item('unsort', Icons.close, labels.clearSort),
          const PopupMenuDivider(),
        ],
        if (pin != ColumnPin.start)
          item('pinStart', Icons.push_pin_outlined, labels.freezeStart),
        if (pin != ColumnPin.end)
          item('pinEnd', Icons.push_pin_outlined, labels.freezeEnd),
        if (pin != ColumnPin.none)
          item('unpin', Icons.push_pin, labels.unfreeze, active: true),
        if (col.isGroupable && hasValues)
          grouped
              ? item(
                  'ungroup',
                  Icons.account_tree_outlined,
                  labels.noGrouping,
                  active: true,
                )
              : item(
                  'group',
                  Icons.account_tree_outlined,
                  labels.groupByColumn(col.title),
                ),
        if (col.isResizable && widget.allowColumnResize)
          item('fit', Icons.fit_screen_outlined, labels.autoFitColumn),
        if (col.isHideable && visibleCount > 1) ...[
          const PopupMenuDivider(),
          item('hide', Icons.visibility_off_outlined, labels.hideColumn),
        ],
      ],
    );
    if (choice == null || !mounted) return;
    switch (choice) {
      case 'asc':
        cubit.sortBy(col.id);
      case 'desc':
        cubit.sortBy(col.id, ascending: false);
      case 'unsort':
        cubit.setSorts(sorts.where((s) => s.columnId != col.id).toList());
      case 'pinStart':
        cubit.setColumnPin(col.id, ColumnPin.start);
      case 'pinEnd':
        cubit.setColumnPin(col.id, ColumnPin.end);
      case 'unpin':
        cubit.setColumnPin(col.id, ColumnPin.none);
      case 'group':
        cubit.groupBy(col.id);
      case 'ungroup':
        cubit.groupBy(null);
      case 'fit':
        cubit.setColumnWidth(col.id, _fitWidth(col));
      case 'hide':
        cubit.setColumnVisibility(col.id, false);
    }
  }

  /// The width that shows [col]'s title and the text of its displayed rows
  /// (the first 500) without truncation.
  double _fitWidth(AdaptiveTableColumn<T> col) {
    final direction = Directionality.of(context);
    final scaler = MediaQuery.textScalerOf(context);
    double measure(String text, TextStyle style) {
      final painter = TextPainter(
        text: TextSpan(text: text, style: style),
        textDirection: direction,
        textScaler: scaler,
        maxLines: 1,
      )..layout();
      final w = painter.width;
      painter.dispose();
      return w;
    }

    // Title + sort arrow and menu button.
    var content = measure(col.title, theme.headerTextStyle) + 44;
    final measurable =
        col.cellBuilder == null &&
        widget.renderer.valueProviders.containsKey(col.id);
    if (measurable) {
      for (final row in _rows.take(500)) {
        content = math.max(
          content,
          measure(widget.renderer.textFor(col, row.item), theme.rowTextStyle),
        );
      }
    }
    final padding = theme.rowPadding.resolve(direction).horizontal;
    return (content + padding + 6).clamp(col.minWidth, 640).ceilToDouble();
  }

  /// Keeps the columns before [col] at their current width while it is
  /// resized, so its edge follows the pointer. The flexible columns after it
  /// absorb the change.
  void _freezeColumnsBefore(AdaptiveTableColumn<T> col) {
    for (final c in _cols) {
      if (c.id == col.id) break;
      final w = _lastWidths[c.id];
      if (w != null) _dragWidths.putIfAbsent(c.id, () => w);
    }
  }

  Widget _reorderable(AdaptiveTableColumn<T> col, Widget child, double width) {
    return DragTarget<String>(
      onWillAcceptWithDetails: (d) => d.data != col.id,
      onAcceptWithDetails: (d) =>
          _cubit.moveColumn(d.data, beforeColumnId: col.id),
      builder: (context, candidates, rejected) {
        final highlight = candidates.isNotEmpty;
        return LongPressDraggable<String>(
          data: col.id,
          axis: Axis.horizontal,
          feedback: Material(
            elevation: 6,
            borderRadius: BorderRadius.circular(6),
            color: _headerSolid,
            child: Container(
              width: width,
              padding: theme.headerPadding,
              child: Text(
                col.title,
                style: theme.headerTextStyle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          childWhenDragging: Opacity(opacity: 0.35, child: child),
          child: DecoratedBox(
            position: DecorationPosition.foreground,
            decoration: BoxDecoration(
              border: highlight
                  ? BorderDirectional(
                      start: BorderSide(color: theme.accentColor, width: 3),
                    )
                  : null,
            ),
            child: child,
          ),
        );
      },
    );
  }

  Widget _buildFilterRow(
    List<AdaptiveTableColumn<T>> cols,
    List<double> widths,
    GridHorizontalMetrics metrics,
    TextDirection direction,
  ) {
    final filters = widget.state.tableState.columnFilters;
    final background = widget.renderer.opaque(theme.rowBackgroundColor);
    return ColoredBox(
      color: theme.rowBackgroundColor,
      child: PinnedRow(
        metrics: metrics,
        textDirection: direction,
        pinnedBackground: background,
        pinnedDividerColor: theme.dividerColor,
        children: [
          if (widget.onRowReorder != null)
            const PinnedCell(
              width: TableGrid.reorderColumnWidth,
              pin: ColumnPin.start,
              child: SizedBox.shrink(),
            ),
          if (widget.expandedRowBuilder != null)
            const PinnedCell(
              width: TableGrid.expandColumnWidth,
              pin: ColumnPin.start,
              child: SizedBox.shrink(),
            ),
          if (widget.showSelection)
            PinnedCell(
              width: TableGrid.selectionColumnWidth,
              pin: ColumnPin.start,
              child: Center(
                child: Tooltip(
                  message: labels.filterHelp,
                  child: Icon(
                    Icons.filter_alt_outlined,
                    size: 16,
                    color: theme.actionIconColor,
                  ),
                ),
              ),
            ),
          for (var i = 0; i < cols.length; i++)
            PinnedCell(
              width: widths[i],
              pin: widget.state.pinOf(cols[i].definition),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                child:
                    cols[i].isFilterable &&
                        widget.renderer.valueProviders.containsKey(cols[i].id)
                    ? _ColumnFilterField(
                        key: ValueKey('filter-${cols[i].id}'),
                        value: filters[cols[i].id] ?? '',
                        theme: theme,
                        labels: labels,
                        onChanged: (v) => _cubit.setColumnFilter(cols[i].id, v),
                      )
                    : const SizedBox(height: 32),
              ),
            ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------- totals

  String _aggregateLabel(AdaptiveTableColumn<T> col) =>
      switch (col.aggregator == null ? col.aggregate : null) {
        TableAggregate.sum => labels.sum,
        TableAggregate.average => labels.average,
        TableAggregate.min => labels.minimum,
        TableAggregate.max => labels.maximum,
        TableAggregate.count => labels.count,
        null => labels.total,
      };

  /// The sticky totals row of the columns that declare an aggregate, aligned
  /// with them (frozen columns included).
  Widget? _buildTotalsRow(
    List<AdaptiveTableColumn<T>> cols,
    List<double> widths,
    GridHorizontalMetrics metrics,
    TextDirection direction,
  ) {
    final totals = widget.state.aggregates;
    bool shows(AdaptiveTableColumn<T> c) =>
        c.hasAggregate && totals.containsKey(c.id);
    if (!cols.any(shows)) return null;
    final labelIndex = cols.isNotEmpty && !shows(cols.first) ? 0 : -1;
    // A narrow first column ("No.") may lend its label the empty cell next
    // to it instead of truncating it.
    final labelCanOverflow =
        labelIndex == 0 &&
        cols.length > 1 &&
        !shows(cols[1]) &&
        widget.state.pinOf(cols[0].definition) ==
            widget.state.pinOf(cols[1].definition);
    final style = theme.rowTextStyle.copyWith(fontWeight: FontWeight.w700);
    final background = theme.effectiveSummaryBackgroundColor;

    Widget cell(int i) {
      final col = cols[i];
      Widget? child;
      if (i == labelIndex) {
        child = Text(
          labels.total,
          style: style,
          maxLines: 1,
          softWrap: false,
          overflow: labelCanOverflow
              ? TextOverflow.visible
              : TextOverflow.ellipsis,
        );
      } else if (shows(col)) {
        child = Tooltip(
          message: _aggregateLabel(col),
          child: Text(
            col.aggregateText(totals[col.id]),
            style: style,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: CellRenderer.textAlign(col.alignment),
          ),
        );
      }
      return Padding(
        padding: theme.rowPadding,
        child: Align(
          alignment: CellRenderer.alignment(col.alignment),
          child: child,
        ),
      );
    }

    return ColoredBox(
      color: Color.alphaBlend(background, theme.rowBackgroundColor),
      child: PinnedRow(
        metrics: metrics,
        textDirection: direction,
        pinnedBackground: widget.renderer.opaque(
          Color.alphaBlend(background, theme.rowBackgroundColor),
        ),
        pinnedDividerColor: theme.dividerColor,
        minHeight: widget.minRowHeight,
        children: [
          if (widget.onRowReorder != null)
            const PinnedCell(
              width: TableGrid.reorderColumnWidth,
              pin: ColumnPin.start,
              child: SizedBox.shrink(),
            ),
          if (widget.expandedRowBuilder != null)
            const PinnedCell(
              width: TableGrid.expandColumnWidth,
              pin: ColumnPin.start,
              child: SizedBox.shrink(),
            ),
          if (widget.showSelection)
            const PinnedCell(
              width: TableGrid.selectionColumnWidth,
              pin: ColumnPin.start,
              child: SizedBox.shrink(),
            ),
          for (var i = 0; i < cols.length; i++)
            PinnedCell(
              width: widths[i],
              pin: widget.state.pinOf(cols[i].definition),
              child: cell(i),
            ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------- rows

  Widget _buildGroupHeader(
    TableGroupInfo<T> info,
    GridHorizontalMetrics metrics,
    double viewport,
  ) {
    final col = widget.columns.where((c) => c.id == info.columnId).firstOrNull;
    final custom = widget.groupHeaderBuilder?.call(context, info);
    return Material(
      color: widget.renderer.opaque(
        theme.headerBackgroundColor.withValues(alpha: 0.7),
      ),
      child: InkWell(
        onTap: () => _cubit.toggleGroupCollapsed(info.key),
        child: ViewportAnchored(
          metrics: metrics,
          viewportWidth: viewport,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                AnimatedRotation(
                  duration: const Duration(milliseconds: 200),
                  // chevron_right mirrors in RTL, so the rotation does too.
                  turns: info.isCollapsed
                      ? 0
                      : (Directionality.of(context) == TextDirection.rtl
                            ? -0.25
                            : 0.25),
                  child: Icon(
                    Icons.chevron_right,
                    size: 20,
                    color: theme.actionIconColor,
                  ),
                ),
                const SizedBox(width: 4),
                Flexible(
                  child: Text.rich(
                    TextSpan(
                      children: [
                        if (col != null) TextSpan(text: '${col.title}: '),
                        TextSpan(
                          text: info.key.isEmpty ? '—' : info.key,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    style: theme.rowTextStyle,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: theme.accentColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${info.rows.length}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: theme.accentColor,
                    ),
                  ),
                ),
                if (custom != null) ...[
                  const SizedBox(width: 16),
                  Expanded(
                    child: Align(
                      alignment: AlignmentDirectional.centerEnd,
                      child: custom,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  VoidCallback? _tapHandler(T item) {
    if (widget.onRowTap != null) return () => widget.onRowTap!(item);
    if (widget.expandedRowBuilder != null) {
      return () => _cubit.toggleRowExpansion(item);
    }
    return null;
  }

  Widget _buildRow(
    RowEntry<T> entry,
    List<AdaptiveTableColumn<T>> cols,
    List<double> widths,
    GridHorizontalMetrics metrics,
    TextDirection direction,
    double viewport,
  ) {
    final state = widget.state;
    final item = entry.item;
    final key = state.keyOf(item);
    final selected = _selectedKeys.contains(key);
    final expanded = _expandedKeys.contains(key);
    final color = widget.renderer.rowColor(
      item,
      selected: selected,
      alternate: theme.useAlternateRows && entry.rowIndex.isOdd,
    );
    final cubit = _cubit;
    const cellVertical = EdgeInsets.symmetric(vertical: 2);

    return Material(
      color: color,
      child: InkWell(
        hoverColor: theme.rowHoverColor,
        onTap: _tapHandler(item),
        onLongPress: widget.onRowLongPress == null
            ? null
            : () => widget.onRowLongPress!(item),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PinnedRow(
              metrics: metrics,
              textDirection: direction,
              pinnedBackground: widget.renderer.opaque(color),
              pinnedDividerColor: theme.dividerColor,
              minHeight: widget.minRowHeight,
              children: [
                if (widget.onRowReorder != null)
                  PinnedCell(
                    width: TableGrid.reorderColumnWidth,
                    pin: ColumnPin.start,
                    child: Center(child: _dragHandle(item)),
                  ),
                if (widget.expandedRowBuilder != null)
                  PinnedCell(
                    width: TableGrid.expandColumnWidth,
                    pin: ColumnPin.start,
                    child: Center(
                      child: _ExpandButton(
                        expanded: expanded,
                        color: theme.actionIconColor,
                        tooltip: expanded ? labels.collapse : labels.expand,
                        onPressed: () => cubit.toggleRowExpansion(item),
                      ),
                    ),
                  ),
                if (widget.showSelection)
                  PinnedCell(
                    width: TableGrid.selectionColumnWidth,
                    pin: ColumnPin.start,
                    child: Center(
                      child: Checkbox(
                        value: selected,
                        activeColor: theme.accentColor,
                        checkColor: theme.onAccentColor,
                        side: BorderSide(
                          color: theme.actionIconColor,
                          width: 1.5,
                        ),
                        onChanged: (_) => cubit.toggleRowSelection(item),
                      ),
                    ),
                  ),
                for (var i = 0; i < cols.length; i++)
                  PinnedCell(
                    width: widths[i],
                    pin: state.pinOf(cols[i].definition),
                    child: _buildDataCell(
                      item,
                      cols[i],
                      entry.rowIndex,
                      i,
                      cellVertical,
                    ),
                  ),
              ],
            ),
            if (widget.expandedRowBuilder != null)
              AnimatedSize(
                duration: const Duration(milliseconds: 200),
                alignment: AlignmentDirectional.topStart,
                child: expanded
                    ? ViewportAnchored(
                        metrics: metrics,
                        viewportWidth: viewport,
                        child: Container(
                          padding: const EdgeInsets.all(16.0),
                          decoration: BoxDecoration(
                            color: theme.headerBackgroundColor.withValues(
                              alpha: 0.5,
                            ),
                            border: Border(
                              top: BorderSide(color: theme.dividerColor),
                            ),
                          ),
                          child: widget.expandedRowBuilder!(context, item),
                        ),
                      )
                    : const SizedBox(width: double.infinity),
              ),
          ],
        ),
      ),
    );
  }

  bool _canEdit(T item, AdaptiveTableColumn<T> col) =>
      col.isEditable &&
      widget.onCellEdited != null &&
      widget.renderer.valueProviders.containsKey(col.id) &&
      (widget.canEditCell?.call(item, col.id) ?? true);

  bool _isEditing(int rowIndex, AdaptiveTableColumn<T> col) =>
      _editing != null &&
      _editing!.columnId == col.id &&
      _editing!.row == rowIndex;

  Widget _buildDataCell(
    T item,
    AdaptiveTableColumn<T> col,
    int rowIndex,
    int colIndex,
    EdgeInsets extraPadding,
  ) {
    final editing = _isEditing(rowIndex, col);
    Widget child = editing
        ? _buildEditor(item, col, rowIndex, colIndex)
        : widget.renderer.cellFor(context, col, item);

    child = Padding(
      padding: theme.rowPadding.add(extraPadding),
      child: Align(
        alignment: CellRenderer.alignment(col.alignment),
        child: child,
      ),
    );

    if (!editing && _canEdit(item, col)) {
      child = GestureDetector(
        onDoubleTap: () => _startEdit(item, col, rowIndex, colIndex),
        child: child,
      );
    }

    if (widget.enableKeyboardNavigation) {
      child = Listener(
        onPointerDown: (_) {
          // A dropdown editor has no "tap outside" of its own: clicking
          // another cell closes it.
          if (!editing && _editing != null && _editingDropdown) _cancelEdit();
          final shift = HardwareKeyboard.instance.isShiftPressed;
          final next = (row: rowIndex, col: colIndex);
          final anchor = shift ? (_anchor ?? _focus) : null;
          if (_focus != next || _anchor != anchor) {
            setState(() {
              _focus = next;
              _anchor = anchor == next ? null : anchor;
            });
          }
          _dragSelecting = widget.enableRangeSelection && !editing;
          if (!editing) _focusNode.requestFocus();
        },
        onPointerUp: (_) => _dragSelecting = false,
        onPointerCancel: (_) => _dragSelecting = false,
        child: child,
      );
      if (widget.enableRangeSelection) {
        // Dragging with the mouse over other cells extends the range.
        child = MouseRegion(
          opaque: false,
          onEnter: (event) {
            if (!_dragSelecting || event.buttons & kPrimaryButton == 0) return;
            final f = _focus;
            if (f == null || (f.row == rowIndex && f.col == colIndex)) return;
            setState(() {
              _anchor ??= f;
              _focus = (row: rowIndex, col: colIndex);
            });
          },
          child: child,
        );
      }
      // The wrapper is always present (only its border changes) so that the
      // cell subtree, and its double-tap recognizer, survive focus changes.
      final focused = _focus?.row == rowIndex && _focus?.col == colIndex;
      final ranged = _hasRange && _inRange(rowIndex, colIndex);
      final inner = child;
      child = Builder(
        builder: (cellContext) {
          if (focused) _focusedCellContext = cellContext;
          return DecoratedBox(
            position: DecorationPosition.foreground,
            decoration: BoxDecoration(
              color: ranged ? theme.accentColor.withValues(alpha: 0.14) : null,
              border: Border.all(
                color: focused && (_focusNode.hasFocus || editing)
                    ? theme.accentColor
                    : Colors.transparent,
                width: 2,
              ),
            ),
            child: inner,
          );
        },
      );
    }
    return child;
  }

  // ---------------------------------------------------------------- editing

  Widget _buildEditor(
    T item,
    AdaptiveTableColumn<T> col,
    int rowIndex,
    int colIndex,
  ) {
    final current = widget.renderer.rawValue(col, item);
    final editor = col.editor ?? CellEditor.infer(current);
    if (editor.type == CellEditorType.dropdown) {
      return _InlineDropdownEditor(
        options: editor.options,
        value: current,
        label: editor.optionLabel ?? ExportUtils.formatValue,
        theme: theme,
        errorText: _editError,
        onSelected: (v) => _commit(item, col, v),
        onCancel: _cancelEdit,
      );
    }
    final isNumber = editor.type == CellEditorType.number;
    return _InlineTextEditor(
      initialText: current == null
          ? ''
          : (isNumber ? ExportUtils.formatValue(current) : current.toString()),
      isNumber: isNumber,
      textAlign: CellRenderer.textAlign(col.alignment),
      inputFormatters: editor.inputFormatters,
      errorText: _editError,
      theme: theme,
      onSubmit: (text) => _submitText(item, col, text, isNumber),
      onCancel: _cancelEdit,
      onTab: (text, backwards) async {
        final ok = await _submitText(item, col, text, isNumber);
        if (ok && mounted) _editNext(backwards: backwards);
      },
    );
  }

  Future<bool> _submitText(
    T item,
    AdaptiveTableColumn<T> col,
    String text,
    bool isNumber,
  ) {
    if (!isNumber) return _commit(item, col, text);
    final trimmed = TableTextNormalizer.digitsToAscii(text.trim());
    if (trimmed.isEmpty) return _commit(item, col, null);
    final n =
        num.tryParse(trimmed) ?? num.tryParse(trimmed.replaceAll(',', ''));
    if (n == null) {
      setState(() => _editError = labels.invalidNumber);
      return Future.value(false);
    }
    return _commit(item, col, n);
  }

  Future<void> _startEdit(
    T item,
    AdaptiveTableColumn<T> col,
    int rowIndex,
    int colIndex,
  ) async {
    if (!_canEdit(item, col)) return;
    final current = widget.renderer.rawValue(col, item);
    final editor = col.editor ?? CellEditor.infer(current);
    setState(() => _focus = (row: rowIndex, col: colIndex));
    switch (editor.type) {
      case CellEditorType.boolean:
        await _commit(item, col, !(current == true), showErrorAsSnackBar: true);
      case CellEditorType.date:
        final first = editor.firstDate ?? DateTime(1900);
        final last = editor.lastDate ?? DateTime(2200);
        var initial = current is DateTime ? current : DateTime.now();
        if (initial.isBefore(first)) initial = first;
        if (initial.isAfter(last)) initial = last;
        final picked = await showDatePicker(
          context: context,
          initialDate: initial,
          firstDate: first,
          lastDate: last,
        );
        if (picked != null && mounted) {
          await _commit(item, col, picked, showErrorAsSnackBar: true);
        }
        if (mounted) _focusNode.requestFocus();
      case CellEditorType.text:
      case CellEditorType.number:
      case CellEditorType.dropdown:
        setState(() {
          _editing = (
            key: widget.state.keyOf(item),
            row: rowIndex,
            columnId: col.id,
          );
          _editingDropdown = editor.type == CellEditorType.dropdown;
          _editError = null;
        });
    }
  }

  Future<bool> _commit(
    T item,
    AdaptiveTableColumn<T> col,
    Object? value, {
    bool showErrorAsSnackBar = false,
  }) async {
    if (_committing) return false;
    final messenger = ScaffoldMessenger.maybeOf(context);
    void fail(String message) {
      if (showErrorAsSnackBar) {
        messenger?.showSnackBar(SnackBar(content: Text(message)));
      } else {
        setState(() => _editError = message);
      }
    }

    final error = col.cellValidator?.call(value);
    if (error != null) {
      fail(error);
      return false;
    }
    final unchanged = widget.renderer.rawValue(col, item) == value;
    if (!unchanged) {
      _committing = true;
      try {
        final result = await widget.onCellEdited!(item, col.id, value);
        if (!mounted) return false;
        if (result == false) {
          fail(labels.invalidValue);
          return false;
        }
      } catch (e) {
        if (mounted) fail('$e');
        return false;
      } finally {
        _committing = false;
      }
    }
    if (!mounted) return false;
    setState(() {
      _editing = null;
      _editError = null;
    });
    _focusNode.requestFocus();
    return true;
  }

  void _cancelEdit() {
    setState(() {
      _editing = null;
      _editError = null;
    });
    _focusNode.requestFocus();
  }

  /// After Tab / Shift + Tab in an editor: edits the next editable cell in
  /// reading order (like a spreadsheet), or stays when there is none.
  void _editNext({required bool backwards}) {
    final f = _focus;
    if (f == null || _cols.isEmpty) return;
    final total = _rows.length * _cols.length;
    var index = f.row * _cols.length + f.col;
    while (true) {
      index += backwards ? -1 : 1;
      if (index < 0 || index >= total) return;
      final row = index ~/ _cols.length;
      final col = index % _cols.length;
      if (_canEdit(_rows[row].item, _cols[col])) {
        _focusCell(row, col, forward: !backwards, startEditing: true);
        return;
      }
    }
  }

  // ---------------------------------------------------------------- keyboard

  /// Focuses the cell at [row] / [col] (clamped) and scrolls it into view.
  void _focusCell(
    int row,
    int col, {
    required bool forward,
    bool startEditing = false,
    bool extend = false,
  }) {
    if (_rows.isEmpty || _cols.isEmpty) return;
    final next = (
      row: row.clamp(0, _rows.length - 1),
      col: col.clamp(0, _cols.length - 1),
    );
    setState(() {
      // Shift keeps the other corner of the range where the focus was.
      _anchor = extend && widget.enableRangeSelection
          ? (_anchor ?? _focus)
          : null;
      if (_anchor == next) _anchor = null;
      _focus = next;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _focusedCellContext;
      if (ctx != null && ctx.mounted) {
        Scrollable.ensureVisible(
          ctx,
          duration: const Duration(milliseconds: 120),
          alignmentPolicy: forward
              ? ScrollPositionAlignmentPolicy.keepVisibleAtEnd
              : ScrollPositionAlignmentPolicy.keepVisibleAtStart,
        );
      }
    });
    if (startEditing) {
      final item = _rows[next.row].item;
      final column = _cols[next.col];
      if (_canEdit(item, column)) _startEdit(item, column, next.row, next.col);
    }
  }

  /// Moves the focus by [dRow] / [dCol]. The first move focuses the first
  /// cell.
  void _moveFocus(int dRow, int dCol, {bool extend = false}) {
    final current = _focus;
    if (current == null) {
      _focusCell(0, 0, forward: true);
      return;
    }
    _focusCell(
      current.row + dRow,
      current.col + dCol,
      forward: dRow > 0 || dCol > 0,
      extend: extend,
    );
  }

  /// Tab / Shift + Tab: the next / previous cell in reading order. Returns
  /// `false` past the first / last cell, so the focus leaves the grid instead
  /// of being trapped in it.
  bool _tab({required bool backwards}) {
    if (_rows.isEmpty || _cols.isEmpty) return false;
    final current = _focus;
    if (current == null) {
      if (backwards) return false;
      _focusCell(0, 0, forward: true);
      return true;
    }
    final index =
        current.row * _cols.length + current.col + (backwards ? -1 : 1);
    if (index < 0 || index >= _rows.length * _cols.length) {
      setState(() {
        _focus = null;
        _anchor = null;
      });
      return false;
    }
    _focusCell(
      index ~/ _cols.length,
      index % _cols.length,
      forward: !backwards,
    );
    return true;
  }

  /// Ctrl / Cmd + C: the selected rows (tab-separated, pastes into a
  /// spreadsheet), otherwise the focused cell.
  bool _copy() {
    final runner = widget.exportRunner;
    if (runner == null) return false;
    final state = widget.state;
    final messenger = ScaffoldMessenger.maybeOf(context);
    final range = _range;
    if (range != null && _hasRange) {
      // The selected cells, as displayed, tab-separated like a spreadsheet.
      String clean(String s) => s.replaceAll(RegExp(r'[\t\r\n]+'), ' ');
      final text = [
        for (var r = range.top; r <= range.bottom; r++)
          [
            for (var c = range.left; c <= range.right; c++)
              clean(widget.renderer.textFor(_cols[c], _rows[r].item)),
          ].join('\t'),
      ].join('\n');
      unawaited(
        runner.copyText(
          text,
          messenger: messenger,
          count: range.bottom - range.top + 1,
        ),
      );
      return true;
    }
    if (state.selectedItems.isNotEmpty) {
      unawaited(
        runner.copyRows(
          state: state,
          messenger: messenger,
          rows: runner.selectedRows(state),
        ),
      );
      return true;
    }
    final f = _focus;
    if (f == null || _rows.isEmpty) return false;
    final text = widget.renderer.textFor(_cols[f.col], _rows[f.row].item);
    unawaited(runner.copyText(text, messenger: messenger));
    return true;
  }

  /// Splits spreadsheet clipboard text into rows of cells (tab-separated,
  /// with `"quoted"` cells that may hold tabs, line breaks and `""`).
  static List<List<String>> parseClipboard(String text) {
    final rows = <List<String>>[];
    var row = <String>[];
    final cell = StringBuffer();
    var quoted = false;
    var cellStart = true;
    for (var i = 0; i < text.length; i++) {
      final ch = text[i];
      if (quoted) {
        if (ch == '"') {
          if (i + 1 < text.length && text[i + 1] == '"') {
            cell.write('"');
            i++;
          } else {
            quoted = false;
          }
        } else {
          cell.write(ch);
        }
      } else if (ch == '"' && cellStart) {
        quoted = true;
        cellStart = false;
      } else if (ch == '\t') {
        row.add(cell.toString());
        cell.clear();
        cellStart = true;
      } else if (ch == '\n' || ch == '\r') {
        if (ch == '\r' && i + 1 < text.length && text[i + 1] == '\n') i++;
        row.add(cell.toString());
        cell.clear();
        rows.add(row);
        row = <String>[];
        cellStart = true;
      } else {
        cell.write(ch);
        cellStart = false;
      }
    }
    if (cell.isNotEmpty || row.isNotEmpty) {
      row.add(cell.toString());
      rows.add(row);
    }
    return rows;
  }

  static const _noValue = Object();

  /// Converts pasted [text] to the type [col] edits, or [_noValue] when it
  /// does not fit (e.g. letters pasted into a number column).
  Object? _coerce(AdaptiveTableColumn<T> col, T item, String text) {
    final current = widget.renderer.rawValue(col, item);
    final editor = col.editor ?? CellEditor.infer(current);
    final t = text.trim();
    switch (editor.type) {
      case CellEditorType.text:
        return text;
      case CellEditorType.number:
        if (t.isEmpty) return null;
        final ascii = TableTextNormalizer.digitsToAscii(t);
        return num.tryParse(ascii) ??
            num.tryParse(ascii.replaceAll(',', '')) ??
            _noValue;
      case CellEditorType.boolean:
        return switch (t.toLowerCase()) {
          'true' || 'yes' || '1' || '✓' || 'نعم' => true,
          'false' || 'no' || '0' || '✗' || 'لا' => false,
          _ => _noValue,
        };
      case CellEditorType.date:
        return TableTextNormalizer.tryParseDay(t) ??
            DateTime.tryParse(t) ??
            _noValue;
      case CellEditorType.dropdown:
        final label = editor.optionLabel ?? ExportUtils.formatValue;
        for (final option in editor.options) {
          if (label(option) == t || '$option' == t) return option;
        }
        return _noValue;
    }
  }

  /// Ctrl / Cmd + V: writes the clipboard's cells into the editable cells
  /// starting at the top-left of the selection (one copied value fills the
  /// whole selected range). Cells that are not editable, or whose value
  /// does not fit or is rejected, are skipped.
  Future<void> _paste() async {
    final onEdit = widget.onCellEdited;
    final start = _range;
    if (onEdit == null || start == null || _pasting) return;
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text;
    if (!mounted || text == null || text.isEmpty) return;
    final cells = parseClipboard(text);
    if (cells.isEmpty) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    final single = cells.length == 1 && cells.first.length == 1;
    final height = single ? start.bottom - start.top + 1 : cells.length;
    _pasting = true;
    var written = 0;
    try {
      for (var dr = 0; dr < height; dr++) {
        final source = single ? cells.first : cells[dr];
        final width = single ? start.right - start.left + 1 : source.length;
        var rowEdited = false;
        for (var dc = 0; dc < width; dc++) {
          final r = start.top + dr;
          final c = start.left + dc;
          if (r >= _rows.length || c >= _cols.length) continue;
          if (rowEdited) {
            // The app usually replaced the row by a new instance: wait for
            // the rebuild so the next cell edits the fresh one.
            await WidgetsBinding.instance.endOfFrame;
            await WidgetsBinding.instance.endOfFrame;
            if (!mounted || r >= _rows.length || c >= _cols.length) return;
          }
          final item = _rows[r].item;
          final col = _cols[c];
          if (!_canEdit(item, col)) continue;
          final value = _coerce(col, item, single ? source.first : source[dc]);
          if (identical(value, _noValue)) continue;
          if (col.cellValidator?.call(value) != null) continue;
          if (widget.renderer.rawValue(col, item) == value) continue;
          try {
            final ok = await onEdit(item, col.id, value);
            if (!mounted) return;
            if (ok == false) continue;
          } catch (_) {
            if (!mounted) return;
            continue;
          }
          written++;
          rowEdited = true;
        }
      }
    } finally {
      _pasting = false;
    }
    if (messenger != null && messenger.mounted) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(labels.pasted(written))));
    }
  }

  /// Reaching the rows with Tab shows the first cell as focused.
  void _onGridFocusChange(bool focused) {
    if (!mounted) return;
    if (focused && _focus == null && _rows.isNotEmpty && _cols.isNotEmpty) {
      setState(() => _focus = (row: 0, col: 0));
    } else if (!focused) {
      setState(() {}); // hide the focus border
    }
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    // Keys typed in a descendant (inline editor, a button inside a cell…)
    // belong to it.
    if (_editing != null || !node.hasPrimaryFocus) {
      return KeyEventResult.ignored;
    }
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final keyboard = HardwareKeyboard.instance;
    final ctrl = keyboard.isControlPressed || keyboard.isMetaPressed;
    final paginated = widget.state.tableState.isPaginated;
    final shift = keyboard.isShiftPressed;

    if (key == LogicalKeyboardKey.arrowDown) {
      _moveFocus(1, 0, extend: shift);
    } else if (key == LogicalKeyboardKey.arrowUp) {
      _moveFocus(-1, 0, extend: shift);
    } else if (key == LogicalKeyboardKey.arrowRight) {
      _moveFocus(0, rtl ? -1 : 1, extend: shift);
    } else if (key == LogicalKeyboardKey.arrowLeft) {
      _moveFocus(0, rtl ? 1 : -1, extend: shift);
    } else if (key == LogicalKeyboardKey.home) {
      _focusCell(
        ctrl ? 0 : (_focus?.row ?? 0),
        0,
        forward: false,
        extend: shift,
      );
    } else if (key == LogicalKeyboardKey.end) {
      _focusCell(
        ctrl ? _rows.length - 1 : (_focus?.row ?? 0),
        _cols.length - 1,
        forward: true,
        extend: shift,
      );
    } else if (key == LogicalKeyboardKey.pageDown) {
      paginated ? _cubit.nextPage() : _moveFocus(10, 0);
    } else if (key == LogicalKeyboardKey.pageUp) {
      paginated ? _cubit.previousPage() : _moveFocus(-10, 0);
    } else if (key == LogicalKeyboardKey.tab) {
      if (!_tab(backwards: keyboard.isShiftPressed)) {
        return KeyEventResult.ignored;
      }
    } else if (ctrl && key == LogicalKeyboardKey.keyA && widget.showSelection) {
      _cubit.toggleSelectAll(true);
    } else if (ctrl &&
        key == LogicalKeyboardKey.keyA &&
        widget.enableRangeSelection &&
        _rows.isNotEmpty &&
        _cols.isNotEmpty) {
      // Without row checkboxes, Ctrl + A selects every cell.
      setState(() {
        _anchor = (row: 0, col: 0);
        _focus = (row: _rows.length - 1, col: _cols.length - 1);
      });
    } else if (ctrl && key == LogicalKeyboardKey.keyC) {
      if (!_copy()) return KeyEventResult.ignored;
    } else if (ctrl && key == LogicalKeyboardKey.keyV) {
      if (widget.onCellEdited == null || _focus == null) {
        return KeyEventResult.ignored;
      }
      unawaited(_paste());
    } else if (key == LogicalKeyboardKey.escape) {
      if (_focus == null) return KeyEventResult.ignored;
      setState(() {
        // First Escape drops the range, the next one the focused cell.
        if (_hasRange) {
          _anchor = null;
        } else {
          _focus = null;
        }
      });
    } else if (_focus != null && _rows.isNotEmpty) {
      final f = _focus!;
      final item = _rows[f.row].item;
      final col = _cols[f.col];
      if (key == LogicalKeyboardKey.enter ||
          key == LogicalKeyboardKey.numpadEnter ||
          key == LogicalKeyboardKey.f2) {
        if (_canEdit(item, col)) {
          _startEdit(item, col, f.row, f.col);
        } else {
          _tapHandler(item)?.call();
        }
      } else if (key == LogicalKeyboardKey.space && widget.showSelection) {
        _cubit.toggleRowSelection(item);
      } else {
        return KeyEventResult.ignored;
      }
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }
}

// ------------------------------------------------------------------ widgets

/// Rebuilds [builder] when the mouse enters / leaves.
class _HoverRegion extends StatefulWidget {
  final Widget Function(BuildContext context, bool hovered) builder;

  const _HoverRegion({required this.builder});

  @override
  State<_HoverRegion> createState() => _HoverRegionState();
}

class _HoverRegionState extends State<_HoverRegion> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: widget.builder(context, _hovered),
    );
  }
}

class _ResizeHandle extends StatelessWidget {
  final Color color;
  final ValueChanged<double> onDrag;
  final VoidCallback onEnd;
  final VoidCallback onReset;

  const _ResizeHandle({
    required this.color,
    required this.onDrag,
    required this.onEnd,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.resizeColumn,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onHorizontalDragUpdate: (d) => onDrag(d.delta.dx),
        onHorizontalDragEnd: (_) => onEnd(),
        onDoubleTap: onReset,
        child: Align(
          alignment: AlignmentDirectional.centerEnd,
          child: Container(width: 1, height: 18, color: color),
        ),
      ),
    );
  }
}

class _ExpandButton extends StatelessWidget {
  final bool expanded;
  final Color color;
  final String tooltip;
  final VoidCallback onPressed;

  const _ExpandButton({
    required this.expanded,
    required this.color,
    required this.tooltip,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      visualDensity: VisualDensity.compact,
      onPressed: onPressed,
      // chevron_right mirrors itself in RTL, so the rotation is mirrored too.
      icon: AnimatedRotation(
        duration: const Duration(milliseconds: 200),
        turns: expanded
            ? (Directionality.of(context) == TextDirection.rtl ? -0.25 : 0.25)
            : 0,
        child: Icon(Icons.chevron_right, color: color, size: 20),
      ),
    );
  }
}

class _ColumnFilterField extends StatefulWidget {
  final String value;
  final AdaptiveTableTheme theme;
  final AdaptiveTableLabels labels;
  final ValueChanged<String> onChanged;

  const _ColumnFilterField({
    super.key,
    required this.value,
    required this.theme,
    required this.labels,
    required this.onChanged,
  });

  @override
  State<_ColumnFilterField> createState() => _ColumnFilterFieldState();
}

class _ColumnFilterFieldState extends State<_ColumnFilterField> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.value,
  );
  Timer? _debounce;

  @override
  void didUpdateWidget(covariant _ColumnFilterField oldWidget) {
    super.didUpdateWidget(oldWidget);
    // External change (e.g. "Clear filters").
    if (widget.value != _controller.text && !(_debounce?.isActive ?? false)) {
      _controller.text = widget.value;
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.theme;
    OutlineInputBorder border(Color c) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(6),
      borderSide: BorderSide(color: c),
    );
    return SizedBox(
      height: 32,
      child: TextField(
        controller: _controller,
        style: t.rowTextStyle.copyWith(fontSize: 12),
        cursorColor: t.accentColor,
        onChanged: (v) {
          _debounce?.cancel();
          _debounce = Timer(
            const Duration(milliseconds: 300),
            () => widget.onChanged(v),
          );
        },
        decoration: InputDecoration(
          isDense: true,
          hintText: widget.labels.filter,
          hintStyle: t.footerTextStyle.copyWith(fontSize: 11),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 8,
            vertical: 8,
          ),
          border: border(t.dividerColor),
          enabledBorder: border(t.dividerColor),
          focusedBorder: border(t.accentColor),
        ),
      ),
    );
  }
}

class _InlineTextEditor extends StatefulWidget {
  final String initialText;
  final bool isNumber;
  final TextAlign textAlign;
  final List<TextInputFormatter>? inputFormatters;
  final String? errorText;
  final AdaptiveTableTheme theme;
  final Future<bool> Function(String text) onSubmit;
  final VoidCallback onCancel;
  final void Function(String text, bool backwards) onTab;

  const _InlineTextEditor({
    required this.initialText,
    required this.isNumber,
    required this.textAlign,
    required this.inputFormatters,
    required this.errorText,
    required this.theme,
    required this.onSubmit,
    required this.onCancel,
    required this.onTab,
  });

  @override
  State<_InlineTextEditor> createState() => _InlineTextEditorState();
}

class _InlineTextEditorState extends State<_InlineTextEditor> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initialText)
        ..selection = TextSelection(
          baseOffset: 0,
          extentOffset: widget.initialText.length,
        );
  late final FocusNode _node = FocusNode(onKeyEvent: _onKey);
  bool _done = false;

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      _done = true;
      widget.onCancel();
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.tab) {
      widget.onTab(_controller.text, HardwareKeyboard.instance.isShiftPressed);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  void dispose() {
    _controller.dispose();
    _node.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.theme;
    OutlineInputBorder border(Color c) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(6),
      borderSide: BorderSide(color: c, width: 1.5),
    );
    return TapRegion(
      onTapOutside: (_) {
        if (!_done) widget.onSubmit(_controller.text);
      },
      child: TextField(
        controller: _controller,
        focusNode: _node,
        autofocus: true,
        textAlign: widget.textAlign,
        style: t.rowTextStyle,
        cursorColor: t.accentColor,
        keyboardType: widget.isNumber
            ? const TextInputType.numberWithOptions(decimal: true, signed: true)
            : TextInputType.text,
        inputFormatters: widget.inputFormatters,
        // Keep the focus on submit: when the value is rejected the user can
        // fix it or press Escape.
        onEditingComplete: () {},
        onSubmitted: (text) => widget.onSubmit(text),
        decoration: InputDecoration(
          isDense: true,
          errorText: widget.errorText,
          errorMaxLines: 2,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 8,
            vertical: 8,
          ),
          border: border(t.accentColor),
          enabledBorder: border(t.accentColor),
          focusedBorder: border(t.accentColor),
        ),
      ),
    );
  }
}

class _InlineDropdownEditor extends StatelessWidget {
  final List<Object?> options;
  final Object? value;
  final String Function(Object?) label;
  final AdaptiveTableTheme theme;
  final String? errorText;
  final ValueChanged<Object?> onSelected;
  final VoidCallback onCancel;

  const _InlineDropdownEditor({
    required this.options,
    required this.value,
    required this.label,
    required this.theme,
    required this.errorText,
    required this.onSelected,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final index = options.indexOf(value);
    return Focus(
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.escape) {
          onCancel();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: DropdownButtonFormField<int>(
        initialValue: index == -1 ? null : index,
        isExpanded: true,
        autofocus: true,
        isDense: true,
        style: theme.rowTextStyle,
        dropdownColor: theme.cardBackgroundColor.withValues(alpha: 1),
        decoration: InputDecoration(
          isDense: true,
          errorText: errorText,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 8,
            vertical: 6,
          ),
        ),
        items: [
          for (var i = 0; i < options.length; i++)
            DropdownMenuItem(value: i, child: Text(label(options[i]))),
        ],
        onChanged: (i) {
          if (i != null) onSelected(options[i]);
        },
      ),
    );
  }
}
