import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/labels.dart';
import '../../core/theme.dart';
import '../../domain/models/column_definition.dart';
import '../../domain/models/table_state_model.dart';
import '../cubit/table_cubit.dart';
import '../cubit/table_cubit_state.dart';
import '../export/table_export_runner.dart';
import 'adaptive_table_layout.dart';
import 'grid/cell_renderer.dart';
import 'grid/table_entries.dart';
import 'grid/table_grid.dart';
import 'skeleton/table_skeleton.dart';

/// The core content renderer. Detects screen size and toggles between a dense
/// desktop tabular view and a responsive mobile card list view.
class TableContent<T> extends StatelessWidget {
  final List<AdaptiveTableColumn<T>> columns;
  final Map<String, dynamic Function(T)> valueProviders;
  final bool showSelection;
  final Widget? emptyWidget;
  final Widget? loadingWidget;
  final TableLoadingStyle loadingStyle;
  final int? skeletonRowCount;
  final bool isLoading;
  final double minDesktopWidth;
  final double mobileBreakpoint;
  final ValueChanged<T>? onRowTap;
  final ValueChanged<T>? onRowLongPress;
  final Color? Function(T item)? rowColorBuilder;
  final Widget Function(BuildContext, T)? expandedRowBuilder;
  final String? mobileTitleColumnId;
  final String? mobileSubtitleColumnId;
  final bool showColumnFilters;
  final bool allowColumnResize;
  final bool allowColumnReorder;
  final bool enableKeyboardNavigation;
  final bool tristateSort;
  final bool showCardSortBar;
  final CellEditCallback<T>? onCellEdited;
  final CanEditCell<T>? canEditCell;
  final GroupHeaderBuilder<T>? groupHeaderBuilder;
  final double minRowHeight;
  final TableExportRunner<T>? exportRunner;
  final AdaptiveTableTheme theme;
  final AdaptiveTableLabels labels;

  const TableContent({
    super.key,
    required this.columns,
    required this.valueProviders,
    required this.showSelection,
    this.emptyWidget,
    this.loadingWidget,
    this.loadingStyle = TableLoadingStyle.spinner,
    this.skeletonRowCount,
    this.isLoading = false,
    required this.minDesktopWidth,
    this.mobileBreakpoint = 600,
    this.onRowTap,
    this.onRowLongPress,
    this.rowColorBuilder,
    this.expandedRowBuilder,
    this.mobileTitleColumnId,
    this.mobileSubtitleColumnId,
    this.showColumnFilters = false,
    this.allowColumnResize = true,
    this.allowColumnReorder = true,
    this.enableKeyboardNavigation = true,
    this.tristateSort = false,
    this.showCardSortBar = true,
    this.onCellEdited,
    this.canEditCell,
    this.groupHeaderBuilder,
    this.minRowHeight = 0,
    this.exportRunner,
    required this.theme,
    this.labels = AdaptiveTableLabels.en,
  });

  CellRenderer<T> get _renderer => CellRenderer<T>(
    valueProviders: valueProviders,
    theme: theme,
    rowColorBuilder: rowColorBuilder,
  );

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TableCubit<T>, TableCubitState<T>>(
      builder: (context, state) {
        if (state is TableLoading<T> || state is TableInitial<T>) {
          return _loadingIndicator(null);
        }

        if (state is TableError<T>) return _errorView(context, state);

        if (state is! TableLoaded<T>) return const SizedBox.shrink();

        final loading = isLoading || state.isFetching;
        final items = state.paginatedItems;
        final waitingForRows = loading && state.originalItems.isEmpty;

        final content = LayoutBuilder(
          builder: (context, constraints) {
            final mobile = constraints.maxWidth < mobileBreakpoint;
            if (mobile) {
              if (items.isEmpty) {
                if (waitingForRows) {
                  return _loadingIndicator(state, mobile: true);
                }
                return emptyWidget ?? _defaultEmpty(state);
              }
              return _buildMobileLayout(
                context,
                state,
                bounded: constraints.hasBoundedHeight,
              );
            }
            // The grid keeps its column headers when there are no rows, so
            // the columns stay visible (and sortable / filterable).
            return TableGrid<T>(
              state: state,
              columns: columns,
              renderer: _renderer,
              showSelection: showSelection,
              minDesktopWidth: minDesktopWidth,
              onRowTap: onRowTap,
              onRowLongPress: onRowLongPress,
              expandedRowBuilder: expandedRowBuilder,
              showColumnFilters: showColumnFilters,
              allowColumnResize: allowColumnResize,
              allowColumnReorder: allowColumnReorder,
              enableKeyboardNavigation: enableKeyboardNavigation,
              tristateSort: tristateSort,
              onCellEdited: onCellEdited,
              canEditCell: canEditCell,
              groupHeaderBuilder: groupHeaderBuilder,
              minRowHeight: minRowHeight,
              exportRunner: exportRunner,
              emptyBuilder: (gridColumns, leadingWidth) => waitingForRows
                  ? _loadingIndicator(
                      state,
                      mobile: false,
                      header: false,
                      gridColumns: gridColumns,
                      leadingWidth: leadingWidth,
                    )
                  : emptyWidget ?? _defaultEmpty(state),
              theme: theme,
              labels: labels,
            );
          },
        );

        if (!loading || _skeletonShown(state)) return content;
        return Stack(
          fit: StackFit.passthrough,
          children: [
            AbsorbPointer(child: Opacity(opacity: 0.6, child: content)),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: LinearProgressIndicator(
                minHeight: 2,
                color: theme.accentColor,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _errorView(BuildContext context, TableError<T> state) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              size: 40,
              color: theme.statusNegativeColor,
            ),
            const SizedBox(height: 8),
            Text(
              state.errorMessage,
              textAlign: TextAlign.center,
              style: theme.rowTextStyle.copyWith(
                color: theme.statusNegativeColor,
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              icon: const Icon(Icons.refresh, size: 18),
              label: Text(labels.retry),
              onPressed: () => context.read<TableCubit<T>>().refresh(),
            ),
          ],
        ),
      ),
    );
  }

  /// The skeleton replaces the rows entirely, so the "busy" overlay on top
  /// of the content is not needed.
  bool _skeletonShown(TableLoaded<T> state) =>
      loadingWidget == null &&
      loadingStyle == TableLoadingStyle.skeleton &&
      state.originalItems.isEmpty;

  /// [state] is `null` before the first load. [mobile] `null` = decide from
  /// the available width. [header] draws a placeholder header row (off when
  /// the real grid header is already shown). [gridColumns] / [leadingWidth]
  /// align the placeholder cells with the real grid columns.
  Widget _loadingIndicator(
    TableLoaded<T>? state, {
    bool? mobile,
    bool header = true,
    List<ColumnDefinition>? gridColumns,
    double? leadingWidth,
  }) {
    if (loadingWidget != null) return loadingWidget!;
    if (loadingStyle == TableLoadingStyle.spinner) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: CircularProgressIndicator(color: theme.accentColor),
        ),
      );
    }
    final pageSize = state?.tableState.pageSize ?? 0;
    final rows = skeletonRowCount ?? (pageSize > 0 ? pageSize.clamp(1, 10) : 8);
    final visible =
        gridColumns ??
        [
          for (final c
              in state == null
                  ? columns.where((c) => c.definition.isVisible)
                  : state.arrange(columns, (c) => c.definition))
            c.definition,
        ];
    Widget skeleton(bool compact) => TableSkeleton(
      columns: visible,
      rowCount: compact ? (rows / 2).ceil() : rows,
      compact: compact,
      showHeader: header,
      showSelection: showSelection,
      leadingWidth: compact ? null : leadingWidth,
      theme: theme,
    );
    if (mobile != null) return skeleton(mobile);
    return LayoutBuilder(
      builder: (context, constraints) =>
          skeleton(constraints.maxWidth < mobileBreakpoint),
    );
  }

  Widget _defaultEmpty(TableLoaded<T> state) {
    final filtered =
        state.originalItems.isNotEmpty && state.tableState.hasActiveFilters;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              filtered ? Icons.search_off : Icons.inbox_outlined,
              size: 48,
              color: theme.actionIconColor.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 8),
            Text(
              filtered ? labels.noResults : labels.noData,
              style: theme.footerTextStyle,
            ),
          ],
        ),
      ),
    );
  }

  VoidCallback? _tapHandler(BuildContext context, T item) {
    if (onRowTap != null) return () => onRowTap!(item);
    if (expandedRowBuilder != null) {
      return () => context.read<TableCubit<T>>().toggleRowExpansion(item);
    }
    return null;
  }

  // --- Mobile Adaptive Render Engine ---

  /// Default card title: the first visible column showing text (an id or
  /// number column makes a poor title), else the first visible column.
  AdaptiveTableColumn<T> _defaultTitleColumn(
    List<AdaptiveTableColumn<T>> visible,
    List<T> sample,
  ) {
    final rows = sample.take(5).toList();
    for (final c in visible) {
      final provider = valueProviders[c.id];
      if (provider == null) continue;
      final showsText = rows.any((r) {
        final v = provider(r);
        return v is String && v.trim().isNotEmpty;
      });
      if (showsText) return c;
    }
    return visible.first;
  }

  Widget _buildMobileLayout(
    BuildContext context,
    TableLoaded<T> state, {
    required bool bounded,
  }) {
    final visibleCols = state.arrange(columns, (c) => c.definition);
    if (visibleCols.isEmpty) return const SizedBox.shrink();
    final renderer = _renderer;
    final selected = state.selectedKeys;
    final expanded = state.expandedKeys;
    final groupId = state.tableState.groupByColumnId;
    final entries = buildTableEntries<T>(
      state,
      valueProviders: valueProviders,
      groupFormatter: groupId == null
          ? null
          : columns.where((c) => c.id == groupId).firstOrNull?.valueFormatter,
    );

    AdaptiveTableColumn<T>? byId(String? id) =>
        id == null ? null : visibleCols.where((c) => c.id == id).firstOrNull;

    final titleCol =
        byId(mobileTitleColumnId) ??
        _defaultTitleColumn(visibleCols, state.paginatedItems);
    // The column after the title (or before it when it is the last one).
    final titleIndex = visibleCols.indexOf(titleCol);
    final subtitleCol =
        byId(mobileSubtitleColumnId) ??
        (titleIndex + 1 < visibleCols.length
            ? visibleCols[titleIndex + 1]
            : visibleCols.where((c) => c != titleCol).firstOrNull);
    final detailCols = visibleCols
        .where((c) => c != titleCol && c != subtitleCol)
        .toList();

    Widget buildEntry(BuildContext context, TableEntry<T> entry) {
      if (entry is GroupEntry<T>) {
        return _mobileGroupHeader(context, entry.info);
      }
      final item = (entry as RowEntry<T>).item;
      final key = state.keyOf(item);
      final isSelected = selected.contains(key);
      return _MobileCard<T>(
        item: item,
        isSelected: isSelected,
        isExpanded: expanded.contains(key),
        canExpand: detailCols.isNotEmpty || expandedRowBuilder != null,
        showSelection: showSelection,
        theme: theme,
        labels: labels,
        backgroundColor: renderer.rowColor(
          item,
          selected: isSelected,
          alternate: false,
        ),
        title: _mobileText(context, titleCol, item, isTitle: true),
        subtitle: subtitleCol == null
            ? null
            : _mobileText(context, subtitleCol, item),
        details: [
          for (final col in detailCols)
            _MobileDetail(
              title: col.title,
              theme: theme,
              child: renderer.cellFor(context, col, item),
            ),
        ],
        expandedBuilder: expandedRowBuilder == null
            ? null
            : (context) => expandedRowBuilder!(context, item),
        onTap: _tapHandler(context, item),
        onLongPress: onRowLongPress == null
            ? null
            : () => onRowLongPress!(item),
      );
    }

    final sortBar = showCardSortBar
        ? _CardSortBar<T>(
            columns: [
              for (final c in columns)
                if (c.isSortable && valueProviders.containsKey(c.id)) c,
            ],
            tableState: state.tableState,
            theme: theme,
            labels: labels,
          )
        : null;
    final totals = _mobileTotals(state, visibleCols);

    const padding = EdgeInsets.symmetric(horizontal: 10, vertical: 8);
    if (bounded) {
      // Lazy building: only the visible cards are created.
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (sortBar != null && sortBar.hasColumns) sortBar,
          Expanded(
            child: Scrollbar(
              child: ListView.builder(
                padding: padding,
                itemCount: entries.length,
                itemBuilder: (context, i) => buildEntry(context, entries[i]),
              ),
            ),
          ),
          ?totals,
        ],
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (sortBar != null && sortBar.hasColumns) sortBar,
        Padding(
          padding: padding,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [for (final e in entries) buildEntry(context, e)],
          ),
        ),
        ?totals,
      ],
    );
  }

  /// The column totals as a compact panel under the cards.
  Widget? _mobileTotals(
    TableLoaded<T> state,
    List<AdaptiveTableColumn<T>> visibleCols,
  ) {
    final cols = [
      for (final c in visibleCols)
        if (c.hasAggregate && state.aggregates.containsKey(c.id)) c,
    ];
    if (cols.isEmpty || state.paginatedItems.isEmpty) return null;
    return Container(
      margin: const EdgeInsets.fromLTRB(10, 0, 10, 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: theme.effectiveSummaryBackgroundColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            labels.total,
            style: theme.headerTextStyle.copyWith(fontSize: 13),
          ),
          const SizedBox(height: 4),
          for (final c in cols)
            _MobileDetail(
              title: c.title,
              theme: theme,
              child: Text(
                c.aggregateText(state.aggregates[c.id]),
                textAlign: TextAlign.end,
                style: theme.rowTextStyle.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
        ],
      ),
    );
  }

  Widget _mobileGroupHeader(BuildContext context, TableGroupInfo<T> info) {
    final col = columns.where((c) => c.id == info.columnId).firstOrNull;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 4),
      child: Material(
        color: theme.headerBackgroundColor,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () =>
              context.read<TableCubit<T>>().toggleGroupCollapsed(info.key),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
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
                Expanded(
                  child: Text(
                    '${col?.title ?? ''}: ${info.key.isEmpty ? '—' : info.key}',
                    style: theme.headerTextStyle.copyWith(fontSize: 13),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  '${info.rows.length}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: theme.accentColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _mobileText(
    BuildContext context,
    AdaptiveTableColumn<T> col,
    T item, {
    bool isTitle = false,
  }) {
    // Prefer plain text (it fits the card typography); fall back to the
    // custom cell when there is no value provider.
    if (!valueProviders.containsKey(col.id) && col.cellBuilder != null) {
      return col.cellBuilder!(context, item);
    }
    return Text(
      _renderer.textFor(col, item),
      maxLines: isTitle ? 2 : 1,
      overflow: TextOverflow.ellipsis,
      style: isTitle
          ? theme.headerTextStyle.copyWith(
              fontSize: 14,
              color: theme.headerGradient != null ? theme.accentColor : null,
            )
          : theme.footerTextStyle,
    );
  }
}

/// "Title ........ value" line of a card's details / totals panel.
class _MobileDetail extends StatelessWidget {
  final String title;
  final AdaptiveTableTheme theme;
  final Widget child;

  const _MobileDetail({
    required this.title,
    required this.theme,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: theme.footerTextStyle.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            flex: 2,
            child: Align(
              alignment: AlignmentDirectional.centerEnd,
              child: child,
            ),
          ),
        ],
      ),
    );
  }
}

/// "Sort by: Amount ▾  ↑" above the cards: phones have no column headers.
class _CardSortBar<T> extends StatelessWidget {
  final List<AdaptiveTableColumn<T>> columns;
  final TableStateModel tableState;
  final AdaptiveTableTheme theme;
  final AdaptiveTableLabels labels;

  const _CardSortBar({
    required this.columns,
    required this.tableState,
    required this.theme,
    required this.labels,
  });

  bool get hasColumns => columns.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    // The popup lives in the Navigator overlay, outside the BlocProvider.
    final cubit = context.read<TableCubit<T>>();
    final sortId = tableState.sortByColumnId;
    final current = columns.where((c) => c.id == sortId).firstOrNull;
    final ascending = tableState.sortAscending;
    final accent = theme.accentColor;

    PopupMenuItem<String> item(String value, String text, bool selected) =>
        PopupMenuItem<String>(
          value: value,
          height: 40,
          child: Row(
            children: [
              SizedBox(
                width: 24,
                child: selected
                    ? Icon(Icons.check, size: 18, color: accent)
                    : null,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  text,
                  overflow: TextOverflow.ellipsis,
                  style: theme.rowTextStyle.copyWith(
                    fontSize: 13,
                    fontWeight: selected ? FontWeight.w600 : null,
                    color: selected ? accent : null,
                  ),
                ),
              ),
            ],
          ),
        );

    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(12, 8, 8, 0),
      child: Row(
        children: [
          Icon(Icons.sort, size: 18, color: theme.actionIconColor),
          const SizedBox(width: 6),
          Text('${labels.sortBy}:', style: theme.footerTextStyle),
          const SizedBox(width: 2),
          Flexible(
            child: PopupMenuButton<String>(
              tooltip: labels.sortBy,
              position: PopupMenuPosition.under,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              color: theme.cardBackgroundColor.withValues(alpha: 1),
              onSelected: (id) =>
                  id.isEmpty ? cubit.clearSort() : cubit.sortBy(id),
              itemBuilder: (_) => [
                item('', labels.noSorting, current == null),
                const PopupMenuDivider(),
                for (final c in columns) item(c.id, c.title, c.id == sortId),
              ],
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        current?.title ?? labels.noSorting,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.rowTextStyle.copyWith(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: current == null ? null : accent,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.expand_more,
                      size: 18,
                      color: theme.actionIconColor,
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (current != null)
            IconButton(
              tooltip: ascending ? labels.ascending : labels.descending,
              visualDensity: VisualDensity.compact,
              iconSize: 18,
              color: accent,
              onPressed: () => cubit.sortBy(current.id, ascending: !ascending),
              icon: Icon(ascending ? Icons.arrow_upward : Icons.arrow_downward),
            ),
        ],
      ),
    );
  }
}

class _MobileCard<T> extends StatelessWidget {
  final T item;
  final bool isSelected;
  final bool isExpanded;
  final bool canExpand;
  final bool showSelection;
  final AdaptiveTableTheme theme;
  final AdaptiveTableLabels labels;
  final Color backgroundColor;
  final Widget title;
  final Widget? subtitle;
  final List<Widget> details;
  final WidgetBuilder? expandedBuilder;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const _MobileCard({
    required this.item,
    required this.isSelected,
    required this.isExpanded,
    required this.canExpand,
    required this.showSelection,
    required this.theme,
    required this.labels,
    required this.backgroundColor,
    required this.title,
    required this.subtitle,
    required this.details,
    required this.expandedBuilder,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<TableCubit<T>>();
    final radius = BorderRadius.circular(10);
    final tap =
        onTap ?? (canExpand ? () => cubit.toggleRowExpansion(item) : null);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        borderRadius: radius,
        // Same width selected or not, so selecting doesn't shift the layout.
        border: Border.all(
          color: isSelected ? theme.accentColor : theme.dividerColor,
          width: 1.2,
        ),
      ),
      child: Material(
        color: backgroundColor,
        borderRadius: radius,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: tap,
          onLongPress: onLongPress,
          hoverColor: theme.rowHoverColor,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(4, 8, 4, 8),
                child: Row(
                  children: [
                    if (showSelection)
                      Checkbox(
                        value: isSelected,
                        activeColor: theme.accentColor,
                        checkColor: theme.onAccentColor,
                        side: BorderSide(
                          color: theme.actionIconColor,
                          width: 1.5,
                        ),
                        onChanged: (_) => cubit.toggleRowSelection(item),
                      )
                    else
                      const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          title,
                          if (subtitle != null) ...[
                            const SizedBox(height: 2),
                            subtitle!,
                          ],
                        ],
                      ),
                    ),
                    if (canExpand)
                      IconButton(
                        tooltip: isExpanded ? labels.collapse : labels.expand,
                        onPressed: () => cubit.toggleRowExpansion(item),
                        icon: AnimatedRotation(
                          duration: const Duration(milliseconds: 200),
                          turns: isExpanded ? 0.5 : 0,
                          child: Icon(
                            Icons.expand_more,
                            color: theme.actionIconColor,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 200),
                alignment: AlignmentDirectional.topStart,
                child: isExpanded && canExpand
                    ? Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Divider(height: 1, color: theme.dividerColor),
                          if (details.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              child: Column(children: details),
                            ),
                          if (expandedBuilder != null)
                            Container(
                              padding: const EdgeInsets.all(12),
                              color: theme.headerBackgroundColor.withValues(
                                alpha: 0.5,
                              ),
                              child: expandedBuilder!(context),
                            ),
                        ],
                      )
                    : const SizedBox(width: double.infinity),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
