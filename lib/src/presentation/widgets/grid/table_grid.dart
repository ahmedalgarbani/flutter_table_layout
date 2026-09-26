import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/labels.dart';
import '../../../core/theme.dart';
import '../../../data/exporters/export_utils.dart';
import '../../../domain/models/column_definition.dart';
import '../../cubit/table_cubit.dart';
import '../../cubit/table_cubit_state.dart';
import '../adaptive_table_layout.dart';
import 'cell_editor.dart';
import 'cell_renderer.dart';
import 'pinned_row.dart';
import 'table_entries.dart';

/// The desktop data grid: sticky header, frozen columns, virtualized rows,
/// resizable / reorderable columns, per-column filters, grouping, inline
/// editing and keyboard navigation.
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
  final bool enableKeyboardNavigation;
  final CellEditCallback<T>? onCellEdited;
  final CanEditCell<T>? canEditCell;
  final GroupHeaderBuilder<T>? groupHeaderBuilder;
  final double minRowHeight;
  final Widget emptyPlaceholder;
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
    this.enableKeyboardNavigation = true,
    this.onCellEdited,
    this.canEditCell,
    this.groupHeaderBuilder,
    this.minRowHeight = 0,
    required this.emptyPlaceholder,
    required this.theme,
    required this.labels,
  });

  static const double selectionColumnWidth = 48;
  static const double expandColumnWidth = 44;
  static const double minFlexColumnWidth = 80;

  @override
  State<TableGrid<T>> createState() => _TableGridState<T>();
}

typedef _CellRef = ({Object? item, String columnId});

class _TableGridState<T> extends State<TableGrid<T>> {
  final ScrollController _h = ScrollController();
  final ScrollController _v = ScrollController();
  final FocusNode _focusNode = FocusNode(debugLabel: 'TableGrid');
  BuildContext? _focusedCellContext;

  /// Widths while a header edge is being dragged (not yet in the cubit).
  final Map<String, double> _dragWidths = {};

  /// Widths computed on the last layout (used to start a resize).
  final Map<String, double> _lastWidths = {};

  _CellRef? _editing;
  String? _editError;
  bool _committing = false;

  /// Focused cell: index among displayed rows / among visible columns.
  ({int row, int col})? _focus;

  // Snapshot of the last build, used by the keyboard handler.
  List<RowEntry<T>> _rows = const [];
  List<AdaptiveTableColumn<T>> _cols = const [];

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
    if (_focus != null &&
        (_focus!.row >= _rows.length || _focus!.col >= cols.length)) {
      _focus = null;
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
        final filterRow = widget.showColumnFilters
            ? _buildFilterRow(cols, layout.widths, metrics, direction)
            : null;

        Widget buildEntry(int index) {
          final entry = entries[index];
          final child = switch (entry) {
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

        final Widget body;
        if (entries.isEmpty) {
          body = ViewportAnchored(
            metrics: metrics,
            viewportWidth: viewport,
            child: widget.emptyPlaceholder,
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

        Widget grid = Column(
          mainAxisSize: bounded ? MainAxisSize.max : MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            header,
            Divider(height: 1, thickness: 1, color: theme.dividerColor),
            if (filterRow != null) ...[
              filterRow,
              Divider(height: 1, color: theme.dividerColor),
            ],
            if (bounded) Expanded(child: body) else body,
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
        if (widget.enableKeyboardNavigation) {
          grid = Focus(focusNode: _focusNode, onKeyEvent: _onKey, child: grid);
        }
        return grid;
      },
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

    Widget content = Padding(
      padding: theme.headerPadding,
      child: Row(
        mainAxisAlignment: CellRenderer.mainAxisAlignment(col.alignment),
        children: [
          Flexible(child: label),
          if (canSort) ...[
            const SizedBox(width: 4),
            AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: isSorted ? 1.0 : 0.3,
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
    );

    if (canSort) {
      content = Semantics(
        button: true,
        child: InkWell(
          onTap: () => _cubit.toggleSort(
            col.id,
            additive: HardwareKeyboard.instance.isShiftPressed,
          ),
          child: content,
        ),
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
    final selected = state.selectedItems.contains(item);
    final expanded = state.expandedItems.contains(item);
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

  bool _isEditing(T item, AdaptiveTableColumn<T> col) =>
      _editing != null &&
      _editing!.columnId == col.id &&
      _editing!.item == item;

  Widget _buildDataCell(
    T item,
    AdaptiveTableColumn<T> col,
    int rowIndex,
    int colIndex,
    EdgeInsets extraPadding,
  ) {
    final editing = _isEditing(item, col);
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
          if (_focus?.row != rowIndex || _focus?.col != colIndex) {
            setState(() => _focus = (row: rowIndex, col: colIndex));
          }
          if (!editing) _focusNode.requestFocus();
        },
        child: child,
      );
      // The wrapper is always present (only its border changes) so that the
      // cell subtree, and its double-tap recognizer, survive focus changes.
      final focused = _focus?.row == rowIndex && _focus?.col == colIndex;
      final inner = child;
      child = Builder(
        builder: (cellContext) {
          if (focused) _focusedCellContext = cellContext;
          return DecoratedBox(
            position: DecorationPosition.foreground,
            decoration: BoxDecoration(
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
        if (ok) _moveFocus(0, backwards ? -1 : 1, startEditing: true);
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
    final trimmed = text.trim();
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
          _editing = (item: item, columnId: col.id);
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

  // ---------------------------------------------------------------- keyboard

  void _moveFocus(int dRow, int dCol, {bool startEditing = false}) {
    if (_rows.isEmpty || _cols.isEmpty) return;
    final current = _focus ?? (row: 0, col: 0);
    final next = (
      row: (current.row + dRow).clamp(0, _rows.length - 1),
      col: (current.col + dCol).clamp(0, _cols.length - 1),
    );
    setState(() => _focus = next);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _focusedCellContext;
      if (ctx != null && ctx.mounted) {
        Scrollable.ensureVisible(
          ctx,
          duration: const Duration(milliseconds: 120),
          alignmentPolicy: dRow > 0 || dCol > 0
              ? ScrollPositionAlignmentPolicy.keepVisibleAtEnd
              : ScrollPositionAlignmentPolicy.keepVisibleAtStart,
        );
      }
    });
    if (startEditing) {
      final item = _rows[next.row].item;
      final col = _cols[next.col];
      if (_canEdit(item, col)) _startEdit(item, col, next.row, next.col);
    }
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (_editing != null) return KeyEventResult.ignored;
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final keyboard = HardwareKeyboard.instance;
    final ctrl = keyboard.isControlPressed || keyboard.isMetaPressed;

    if (key == LogicalKeyboardKey.arrowDown) {
      _moveFocus(1, 0);
    } else if (key == LogicalKeyboardKey.arrowUp) {
      _moveFocus(-1, 0);
    } else if (key == LogicalKeyboardKey.arrowRight) {
      _moveFocus(0, rtl ? -1 : 1);
    } else if (key == LogicalKeyboardKey.arrowLeft) {
      _moveFocus(0, rtl ? 1 : -1);
    } else if (key == LogicalKeyboardKey.home) {
      _moveFocus(ctrl ? -_rows.length : 0, -_cols.length);
    } else if (key == LogicalKeyboardKey.end) {
      _moveFocus(ctrl ? _rows.length : 0, _cols.length);
    } else if (key == LogicalKeyboardKey.pageDown) {
      _cubit.nextPage();
    } else if (key == LogicalKeyboardKey.pageUp) {
      _cubit.previousPage();
    } else if (key == LogicalKeyboardKey.tab) {
      _moveFocus(0, keyboard.isShiftPressed ? -1 : 1);
    } else if (ctrl && key == LogicalKeyboardKey.keyA && widget.showSelection) {
      _cubit.toggleSelectAll(true);
    } else if (key == LogicalKeyboardKey.escape) {
      if (_focus == null) return KeyEventResult.ignored;
      setState(() => _focus = null);
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
