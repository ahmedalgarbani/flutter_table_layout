import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/labels.dart';
import '../../core/theme.dart';
import '../cubit/table_cubit.dart';
import '../cubit/table_cubit_state.dart';
import 'adaptive_table_layout.dart';
import 'grid/cell_renderer.dart';
import 'grid/table_entries.dart';
import 'grid/table_grid.dart';

/// The core content renderer. Detects screen size and toggles between a dense
/// desktop tabular view and a responsive mobile card list view.
class TableContent<T> extends StatelessWidget {
  final List<AdaptiveTableColumn<T>> columns;
  final Map<String, dynamic Function(T)> valueProviders;
  final bool showSelection;
  final Widget? emptyWidget;
  final Widget? loadingWidget;
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
  final CellEditCallback<T>? onCellEdited;
  final CanEditCell<T>? canEditCell;
  final GroupHeaderBuilder<T>? groupHeaderBuilder;
  final double minRowHeight;
  final AdaptiveTableTheme theme;
  final AdaptiveTableLabels labels;

  const TableContent({
    super.key,
    required this.columns,
    required this.valueProviders,
    required this.showSelection,
    this.emptyWidget,
    this.loadingWidget,
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
    this.onCellEdited,
    this.canEditCell,
    this.groupHeaderBuilder,
    this.minRowHeight = 0,
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
          return _loadingIndicator();
        }

        if (state is TableError<T>) {
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

        if (state is! TableLoaded<T>) return const SizedBox.shrink();

        final loading = isLoading || state.isFetching;
        final items = state.paginatedItems;

        final content = LayoutBuilder(
          builder: (context, constraints) {
            final mobile = constraints.maxWidth < mobileBreakpoint;
            if (items.isEmpty && (mobile || !showColumnFilters)) {
              if (loading && state.originalItems.isEmpty) {
                return _loadingIndicator();
              }
              return emptyWidget ?? _defaultEmpty(state);
            }
            if (mobile) {
              return _buildMobileLayout(
                context,
                state,
                bounded: constraints.hasBoundedHeight,
              );
            }
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
              onCellEdited: onCellEdited,
              canEditCell: canEditCell,
              groupHeaderBuilder: groupHeaderBuilder,
              minRowHeight: minRowHeight,
              emptyPlaceholder: emptyWidget ?? _defaultEmpty(state),
              theme: theme,
              labels: labels,
            );
          },
        );

        if (!loading) return content;
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

  Widget _loadingIndicator() {
    return loadingWidget ??
        Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: CircularProgressIndicator(color: theme.accentColor),
          ),
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

  Widget _buildMobileLayout(
    BuildContext context,
    TableLoaded<T> state, {
    required bool bounded,
  }) {
    final visibleCols = state.arrange(columns, (c) => c.definition);
    if (visibleCols.isEmpty) return const SizedBox.shrink();
    final renderer = _renderer;
    final selected = state.selectedItems.toSet();
    final expanded = state.expandedItems.toSet();
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

    final titleCol = byId(mobileTitleColumnId) ?? visibleCols.first;
    final subtitleCol =
        byId(mobileSubtitleColumnId) ??
        visibleCols.where((c) => c != titleCol).firstOrNull;
    final detailCols = visibleCols
        .where((c) => c != titleCol && c != subtitleCol)
        .toList();

    Widget buildEntry(BuildContext context, TableEntry<T> entry) {
      if (entry is GroupEntry<T>) {
        return _mobileGroupHeader(context, entry.info);
      }
      final item = (entry as RowEntry<T>).item;
      final isSelected = selected.contains(item);
      return _MobileCard<T>(
        item: item,
        isSelected: isSelected,
        isExpanded: expanded.contains(item),
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
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Text(
                      col.title,
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
                      child: renderer.cellFor(context, col, item),
                    ),
                  ),
                ],
              ),
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

    const padding = EdgeInsets.symmetric(horizontal: 10, vertical: 8);
    if (bounded) {
      // Lazy building: only the visible cards are created.
      return Scrollbar(
        child: ListView.builder(
          padding: padding,
          itemCount: entries.length,
          itemBuilder: (context, i) => buildEntry(context, entries[i]),
        ),
      );
    }
    return Padding(
      padding: padding,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [for (final e in entries) buildEntry(context, e)],
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
        border: Border.all(
          color: isSelected ? theme.accentColor : theme.dividerColor,
          width: isSelected ? 1.5 : 1,
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
