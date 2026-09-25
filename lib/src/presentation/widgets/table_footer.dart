import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/labels.dart';
import '../../core/theme.dart';
import '../cubit/table_cubit.dart';
import '../cubit/table_cubit_state.dart';

/// The bottom footer of the table layout.
/// Displays summary aggregate bars, items per page selectors, and page navigators.
class TableFooter<T> extends StatelessWidget {
  final Widget Function(BuildContext, List<T> visibleItems)? summaryBuilder;
  final bool showPagination;
  final bool showSummary;
  final List<int> pageSizes;
  final double mobileBreakpoint;
  final AdaptiveTableTheme theme;
  final AdaptiveTableLabels labels;

  const TableFooter({
    super.key,
    this.summaryBuilder,
    required this.showPagination,
    required this.showSummary,
    required this.pageSizes,
    this.mobileBreakpoint = 600,
    required this.theme,
    this.labels = AdaptiveTableLabels.en,
  });

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TableCubit<T>, TableCubitState<T>>(
      builder: (context, state) {
        if (state is! TableLoaded<T>) return const SizedBox.shrink();

        final items = state.filteredAndSortedItems;
        final showSummaryRow =
            showSummary && summaryBuilder != null && items.isNotEmpty;

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Aggregation / Summary row
            if (showSummaryRow)
              Container(
                decoration: BoxDecoration(
                  color: theme.effectiveSummaryBackgroundColor,
                  border: Border(
                    top: BorderSide(color: theme.dividerColor, width: 1),
                  ),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 12.0,
                ),
                child: summaryBuilder!(context, items),
              ),

            // 2. Pagination bar
            if (showPagination) _buildPaginationBar(context, state),
          ],
        );
      },
    );
  }

  Widget _buildPaginationBar(BuildContext context, TableLoaded<T> state) {
    final tState = state.tableState;
    final totalPages = state.totalPages;
    final currentPage = tState.currentPage.clamp(1, totalPages);
    final total = state.totalCount;
    final from = total == 0 ? 0 : (currentPage - 1) * tState.pageSize + 1;
    final to = total == 0 ? 0 : (currentPage * tState.pageSize).clamp(0, total);

    final status = Text(
      labels.rangeStatus(from, to, total),
      style: theme.footerTextStyle,
    );

    final pageSize = _buildPageSizeSelector(context, tState.pageSize);

    return Container(
      decoration: BoxDecoration(
        color: theme.footerGradient != null
            ? null
            : theme.footerBackgroundColor,
        gradient: theme.footerGradient,
        border: Border(top: BorderSide(color: theme.dividerColor, width: 1.0)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final narrow = constraints.maxWidth < mobileBreakpoint;
          final controls = _buildPaginationControls(
            context,
            currentPage,
            totalPages,
            compact: narrow,
          );
          if (narrow) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(child: status),
                    pageSize,
                  ],
                ),
                const SizedBox(height: 4),
                controls,
              ],
            );
          }
          return Row(
            children: [
              Expanded(child: status),
              pageSize,
              const SizedBox(width: 16),
              controls,
            ],
          );
        },
      ),
    );
  }

  Widget _buildPageSizeSelector(BuildContext context, int current) {
    // The current size must be one of the dropdown values, otherwise
    // DropdownButton throws an assertion.
    final sizes = {...pageSizes.where((s) => s > 0), current}.toList()..sort();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          labels.itemsPerPage,
          style: theme.footerTextStyle.copyWith(fontSize: 11),
        ),
        const SizedBox(width: 6),
        SizedBox(
          height: 30,
          child: DropdownButton<int>(
            value: current,
            dropdownColor: theme.cardBackgroundColor.withValues(alpha: 1),
            underline: const SizedBox.shrink(),
            isDense: true,
            style: theme.footerTextStyle.copyWith(fontWeight: FontWeight.bold),
            icon: Icon(
              Icons.arrow_drop_down,
              size: 16,
              color: theme.actionIconColor,
            ),
            onChanged: (val) {
              if (val != null) context.read<TableCubit<T>>().setPageSize(val);
            },
            items: [
              for (final size in sizes)
                DropdownMenuItem<int>(value: size, child: Text('$size')),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPaginationControls(
    BuildContext context,
    int currentPage,
    int totalPages, {
    bool compact = false,
  }) {
    final cubit = context.read<TableCubit<T>>();
    final hasPrev = currentPage > 1;
    final hasNext = currentPage < totalPages;

    // Icons are mirrored automatically in RTL by the Icon widget.
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _NavButton(
          icon: Icons.first_page,
          tooltip: labels.firstPage,
          enabled: hasPrev,
          onPressed: () => cubit.setPage(1),
          theme: theme,
        ),
        _NavButton(
          icon: Icons.chevron_left,
          tooltip: labels.previousPage,
          enabled: hasPrev,
          onPressed: () => cubit.setPage(currentPage - 1),
          theme: theme,
        ),
        for (final page in _visiblePages(
          currentPage,
          totalPages,
          compact ? 3 : 5,
        ))
          page == null
              ? Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Text('…', style: theme.footerTextStyle),
                )
              : _PageChip(
                  page: page,
                  selected: page == currentPage,
                  onTap: () => cubit.setPage(page),
                  theme: theme,
                ),
        _NavButton(
          icon: Icons.chevron_right,
          tooltip: labels.nextPage,
          enabled: hasNext,
          onPressed: () => cubit.setPage(currentPage + 1),
          theme: theme,
        ),
        _NavButton(
          icon: Icons.last_page,
          tooltip: labels.lastPage,
          enabled: hasNext,
          onPressed: () => cubit.setPage(totalPages),
          theme: theme,
        ),
      ],
    );
  }

  /// A sliding window of page numbers; `null` marks a gap ("…").
  static List<int?> _visiblePages(int current, int total, int window) {
    if (total <= window + 2) return [for (var i = 1; i <= total; i++) i];
    final half = window ~/ 2;
    var start = (current - half).clamp(2, total - window);
    var end = start + window - 1;
    if (end >= total) {
      end = total - 1;
      start = end - window + 1;
    }
    return [
      1,
      if (start > 2) null,
      for (var i = start; i <= end; i++) i,
      if (end < total - 1) null,
      total,
    ];
  }
}

class _PageChip extends StatelessWidget {
  final int page;
  final bool selected;
  final VoidCallback onTap;
  final AdaptiveTableTheme theme;

  const _PageChip({
    required this.page,
    required this.selected,
    required this.onTap,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Material(
        color: selected ? theme.accentColor : Colors.transparent,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: selected ? null : onTap,
          child: SizedBox(
            width: 28,
            height: 28,
            child: Center(
              child: Text(
                '$page',
                style: theme.footerTextStyle.copyWith(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: selected ? theme.onAccentColor : null,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final bool enabled;
  final VoidCallback onPressed;
  final AdaptiveTableTheme theme;

  const _NavButton({
    required this.icon,
    required this.tooltip,
    required this.enabled,
    required this.onPressed,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
      iconSize: 18,
      color: theme.actionIconColor,
      disabledColor: theme.actionIconColor.withValues(alpha: 0.3),
      onPressed: enabled ? onPressed : null,
      icon: Icon(icon),
    );
  }
}
