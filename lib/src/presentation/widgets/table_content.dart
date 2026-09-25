import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/labels.dart';
import '../../core/theme.dart';
import '../../data/exporters/export_utils.dart';
import '../../domain/models/column_definition.dart';
import '../cubit/table_cubit.dart';
import '../cubit/table_cubit_state.dart';
import 'adaptive_table_layout.dart';

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
    required this.theme,
    this.labels = AdaptiveTableLabels.en,
  });

  static const double _selectionColumnWidth = 48;
  static const double _expandColumnWidth = 44;

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
                ],
              ),
            ),
          );
        }

        if (state is! TableLoaded<T>) return const SizedBox.shrink();

        final items = state.paginatedItems;
        if (items.isEmpty) {
          if (isLoading) return _loadingIndicator();
          return emptyWidget ?? _defaultEmpty(state);
        }

        final visibleCols = columns
            .where((c) => !state.hiddenColumnIds.contains(c.id))
            .toList();
        final selected = state.selectedItems.toSet();
        final expanded = state.expandedItems.toSet();

        final content = LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth < mobileBreakpoint) {
              return _buildMobileLayout(
                context,
                items,
                visibleCols,
                selected,
                expanded,
              );
            }
            return _buildDesktopLayout(
              context,
              state,
              visibleCols,
              selected,
              expanded,
              constraints.maxWidth,
            );
          },
        );

        if (!isLoading) return content;
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            LinearProgressIndicator(minHeight: 2, color: theme.accentColor),
            AbsorbPointer(child: Opacity(opacity: 0.6, child: content)),
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

  // --- Shared cell helpers ---

  String _textFor(AdaptiveTableColumn<T> col, T item) {
    final raw = valueProviders[col.id]?.call(item);
    return (col.valueFormatter ?? ExportUtils.formatValue)(raw);
  }

  Widget _cellFor(BuildContext context, AdaptiveTableColumn<T> col, T item) {
    if (col.cellBuilder != null) return col.cellBuilder!(context, item);
    return Text(
      _textFor(col, item),
      style: theme.rowTextStyle,
      overflow: TextOverflow.ellipsis,
      maxLines: 2,
      textAlign: _textAlign(col.alignment),
    );
  }

  Color _rowColor(T item, bool isSelected, bool isAlternate) {
    if (isSelected) {
      return Color.alphaBlend(
        theme.effectiveSelectedRowColor,
        theme.rowBackgroundColor,
      );
    }
    final custom = rowColorBuilder?.call(item);
    if (custom != null) return custom;
    return isAlternate
        ? theme.alternateRowBackgroundColor
        : theme.rowBackgroundColor;
  }

  VoidCallback? _tapHandler(BuildContext context, T item) {
    if (onRowTap != null) return () => onRowTap!(item);
    if (expandedRowBuilder != null) {
      return () => context.read<TableCubit<T>>().toggleRowExpansion(item);
    }
    return null;
  }

  // --- Desktop Render Engine ---

  Widget _buildDesktopLayout(
    BuildContext context,
    TableLoaded<T> state,
    List<AdaptiveTableColumn<T>> visibleCols,
    Set<T> selected,
    Set<T> expanded,
    double availableWidth,
  ) {
    final items = state.paginatedItems;
    final fixedWidth =
        visibleCols.fold<double>(0, (sum, c) => sum + (c.width ?? 0)) +
        (showSelection ? _selectionColumnWidth : 0) +
        (expandedRowBuilder != null ? _expandColumnWidth : 0) +
        visibleCols.where((c) => c.width == null).length * 80;
    final tableWidth = [
      minDesktopWidth,
      fixedWidth,
    ].reduce((a, b) => a > b ? a : b);
    final useHorizontalScroll = availableWidth < tableWidth;

    final tableWidget = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildDesktopHeader(context, state, visibleCols),
        Divider(height: 1, thickness: 1, color: theme.dividerColor),
        for (var index = 0; index < items.length; index++) ...[
          if (index > 0) Divider(height: 1, color: theme.dividerColor),
          _buildDesktopRow(
            context,
            items[index],
            visibleCols,
            selected.contains(items[index]),
            expanded.contains(items[index]),
            theme.useAlternateRows && index.isOdd,
          ),
        ],
      ],
    );

    if (useHorizontalScroll) {
      return Scrollbar(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(width: tableWidth, child: tableWidget),
        ),
      );
    }
    return tableWidget;
  }

  Widget _sizedCell(AdaptiveTableColumn<T> col, Widget child) {
    if (col.width != null) return SizedBox(width: col.width, child: child);
    return Expanded(flex: col.flex, child: child);
  }

  Widget _buildDesktopHeader(
    BuildContext context,
    TableLoaded<T> state,
    List<AdaptiveTableColumn<T>> visibleCols,
  ) {
    final cubit = context.read<TableCubit<T>>();
    return Container(
      decoration: BoxDecoration(
        color: theme.headerGradient == null
            ? theme.headerBackgroundColor
            : null,
        gradient: theme.headerGradient,
      ),
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          if (expandedRowBuilder != null)
            const SizedBox(width: _expandColumnWidth),
          if (showSelection)
            SizedBox(
              width: _selectionColumnWidth,
              child: Tooltip(
                message: labels.selectAll,
                child: Checkbox(
                  tristate: true,
                  value: state.selectAllValue,
                  activeColor: theme.accentColor,
                  checkColor: theme.onAccentColor,
                  side: BorderSide(
                    color: theme.headerTextStyle.color ?? theme.actionIconColor,
                    width: 1.5,
                  ),
                  onChanged: state.filteredAndSortedItems.isEmpty
                      ? null
                      : (_) =>
                            cubit.toggleSelectAll(state.selectAllValue != true),
                ),
              ),
            ),
          for (final col in visibleCols)
            _sizedCell(col, _buildHeaderCell(context, state, col)),
        ],
      ),
    );
  }

  Widget _buildHeaderCell(
    BuildContext context,
    TableLoaded<T> state,
    AdaptiveTableColumn<T> col,
  ) {
    final isSorted = state.tableState.sortByColumnId == col.id;
    final isAscending = state.tableState.sortAscending;
    final canSort = col.isSortable && valueProviders.containsKey(col.id);

    final Widget label;
    if (col.headerBuilder != null) {
      label = col.headerBuilder!(context);
    } else if (col.title.trim().contains(' ')) {
      // Multi-word titles wrap on word boundaries.
      label = Text(
        col.title,
        style: theme.headerTextStyle,
        overflow: TextOverflow.ellipsis,
        maxLines: 2,
        textAlign: _textAlign(col.alignment),
      );
    } else {
      // A single word is never split mid-word: it shrinks to fit instead.
      label = FittedBox(
        fit: BoxFit.scaleDown,
        alignment: _alignment(col.alignment),
        child: Text(col.title, style: theme.headerTextStyle, maxLines: 1),
      );
    }

    Widget content = Row(
      mainAxisAlignment: _mainAxisAlignment(col.alignment),
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
              child: Icon(
                Icons.arrow_upward,
                size: 14,
                color: isSorted && theme.headerGradient == null
                    ? theme.accentColor
                    : (theme.headerTextStyle.color ?? theme.actionIconColor),
              ),
            ),
          ),
        ],
      ],
    );

    content = Padding(padding: theme.headerPadding, child: content);
    if (!canSort) return content;

    return Semantics(
      button: true,
      child: InkWell(
        onTap: () => context.read<TableCubit<T>>().toggleSort(col.id),
        child: content,
      ),
    );
  }

  Widget _buildDesktopRow(
    BuildContext context,
    T item,
    List<AdaptiveTableColumn<T>> visibleCols,
    bool isSelected,
    bool isExpanded,
    bool isAlternate,
  ) {
    final cubit = context.read<TableCubit<T>>();

    return Material(
      color: _rowColor(item, isSelected, isAlternate),
      child: InkWell(
        hoverColor: theme.rowHoverColor,
        onTap: _tapHandler(context, item),
        onLongPress: onRowLongPress == null
            ? null
            : () => onRowLongPress!(item),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  if (expandedRowBuilder != null)
                    SizedBox(
                      width: _expandColumnWidth,
                      child: _ExpandButton(
                        expanded: isExpanded,
                        color: theme.actionIconColor,
                        tooltip: isExpanded ? labels.collapse : labels.expand,
                        onPressed: () => cubit.toggleRowExpansion(item),
                      ),
                    ),
                  if (showSelection)
                    SizedBox(
                      width: _selectionColumnWidth,
                      child: Checkbox(
                        value: isSelected,
                        activeColor: theme.accentColor,
                        checkColor: theme.onAccentColor,
                        side: BorderSide(
                          color: theme.actionIconColor,
                          width: 1.5,
                        ),
                        onChanged: (_) => cubit.toggleRowSelection(item),
                      ),
                    ),
                  for (final col in visibleCols)
                    _sizedCell(
                      col,
                      Padding(
                        padding: theme.rowPadding,
                        child: Align(
                          alignment: _alignment(col.alignment),
                          child: _cellFor(context, col, item),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            if (expandedRowBuilder != null)
              AnimatedSize(
                duration: const Duration(milliseconds: 200),
                alignment: AlignmentDirectional.topStart,
                child: isExpanded
                    ? Container(
                        padding: const EdgeInsets.all(16.0),
                        decoration: BoxDecoration(
                          color: theme.headerBackgroundColor.withValues(
                            alpha: 0.5,
                          ),
                          border: Border(
                            top: BorderSide(color: theme.dividerColor),
                          ),
                        ),
                        child: expandedRowBuilder!(context, item),
                      )
                    : const SizedBox(width: double.infinity),
              ),
          ],
        ),
      ),
    );
  }

  // --- Mobile Adaptive Render Engine ---

  Widget _buildMobileLayout(
    BuildContext context,
    List<T> items,
    List<AdaptiveTableColumn<T>> visibleCols,
    Set<T> selected,
    Set<T> expanded,
  ) {
    if (visibleCols.isEmpty) return const SizedBox.shrink();

    AdaptiveTableColumn<T>? byId(String? id) =>
        id == null ? null : visibleCols.where((c) => c.id == id).firstOrNull;

    final titleCol = byId(mobileTitleColumnId) ?? visibleCols.first;
    final subtitleCol =
        byId(mobileSubtitleColumnId) ??
        visibleCols.where((c) => c != titleCol).firstOrNull;
    final detailCols = visibleCols
        .where((c) => c != titleCol && c != subtitleCol)
        .toList();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final item in items)
            _MobileCard<T>(
              item: item,
              isSelected: selected.contains(item),
              isExpanded: expanded.contains(item),
              canExpand: detailCols.isNotEmpty || expandedRowBuilder != null,
              showSelection: showSelection,
              theme: theme,
              labels: labels,
              backgroundColor: _rowColor(item, selected.contains(item), false),
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
                            child: _cellFor(context, col, item),
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
            ),
        ],
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
      _textFor(col, item),
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

  // --- Alignment Helpers (direction-aware) ---

  MainAxisAlignment _mainAxisAlignment(TableColumnAlignment alignment) {
    return switch (alignment) {
      TableColumnAlignment.start => MainAxisAlignment.start,
      TableColumnAlignment.center => MainAxisAlignment.center,
      TableColumnAlignment.end => MainAxisAlignment.end,
    };
  }

  AlignmentDirectional _alignment(TableColumnAlignment alignment) {
    return switch (alignment) {
      TableColumnAlignment.start => AlignmentDirectional.centerStart,
      TableColumnAlignment.center => AlignmentDirectional.center,
      TableColumnAlignment.end => AlignmentDirectional.centerEnd,
    };
  }

  TextAlign _textAlign(TableColumnAlignment alignment) {
    return switch (alignment) {
      TableColumnAlignment.start => TextAlign.start,
      TableColumnAlignment.center => TextAlign.center,
      TableColumnAlignment.end => TextAlign.end,
    };
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
