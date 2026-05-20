import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
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
  final AdaptiveTableTheme theme;

  const TableFooter({
    super.key,
    this.summaryBuilder,
    required this.showPagination,
    required this.showSummary,
    required this.pageSizes,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final textDirection = Directionality.of(context);
    final isRtl = textDirection == TextDirection.rtl;

    return BlocBuilder<TableCubit<T>, TableCubitState<T>>(
      builder: (context, state) {
        if (state is! TableLoaded<T>) return const SizedBox.shrink();

        final items = state.filteredAndSortedItems;
        final totalCount = state.totalCount;
        final tState = state.tableState;

        // Calculate pages
        final totalPages = (totalCount / tState.pageSize).ceil();
        final currentPage = tState.currentPage;

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Aggregation / Summary row
            if (showSummary && summaryBuilder != null && items.isNotEmpty)
              Container(
                decoration: BoxDecoration(
                  color: theme.headerGradient != null ? null : theme.headerBackgroundColor.withOpacity(0.4),
                  gradient: theme.headerGradient,
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
            if (showPagination)
              Container(
                decoration: BoxDecoration(
                  color: theme.footerGradient != null ? null : theme.footerBackgroundColor,
                  gradient: theme.footerGradient,
                  border: Border(
                    top: BorderSide(color: theme.dividerColor, width: 1.0),
                  ),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 10.0,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Slice text (e.g. "1 to 10 of 20 entries")
                    Flexible(
                      child: Text(
                        _buildStatusText(
                          currentPage,
                          totalPages,
                          totalCount,
                          isRtl,
                        ),
                        style: theme.footerTextStyle,
                      ),
                    ),

                    // Page size dropdown & Arrow navigators
                    Wrap(
                      spacing: 16,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        // Page Size Dropdown
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              isRtl ? 'العناصر في كل صفحة:' : 'Items per page:',
                              style: theme.footerTextStyle.copyWith(
                                fontSize: 11,
                              ),
                            ),
                            const SizedBox(width: 6),
                            SizedBox(
                              height: 30,
                              child: DropdownButton<int>(
                                value: tState.pageSize,
                                dropdownColor: theme.cardBackgroundColor,
                                underline: const SizedBox.shrink(),
                                style: theme.footerTextStyle.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                                icon: const Icon(
                                  Icons.arrow_drop_down,
                                  size: 16,
                                ),
                                onChanged: (val) {
                                  if (val != null) {
                                    context.read<TableCubit<T>>().setPageSize(
                                      val,
                                    );
                                  }
                                },
                                items: pageSizes.map((size) {
                                  return DropdownMenuItem<int>(
                                    value: size,
                                    child: Text('$size'),
                                  );
                                }).toList(),
                              ),
                            ),
                          ],
                        ),

                        // Navigation arrows
                        _buildPaginationControls(
                          context,
                          currentPage,
                          totalPages,
                          isRtl,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }

  String _buildStatusText(int page, int totalPages, int count, bool isRtl) {
    if (isRtl) {
      return '$page من $totalPages صفحة ($count عنصر)';
    }
    return 'Page $page of $totalPages ($count items)';
  }

  Widget _buildPaginationControls(
    BuildContext context,
    int currentPage,
    int totalPages,
    bool isRtl,
  ) {
    final hasPrev = currentPage > 1;
    final hasNext = currentPage < totalPages;

    // Flip icons dynamically based on directionality
    final firstIcon = isRtl ? Icons.last_page : Icons.first_page;
    final prevIcon = isRtl ? Icons.chevron_right : Icons.chevron_left;
    final nextIcon = isRtl ? Icons.chevron_left : Icons.chevron_right;
    final lastIcon = isRtl ? Icons.first_page : Icons.last_page;

    final cubit = context.read<TableCubit<T>>();

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // First Page
        _IconButton(
          icon: Icon(firstIcon, size: 18),
          enabled: hasPrev,
          onPressed: () => cubit.setPage(1),
          theme: theme,
        ),

        // Prev Page
        _IconButton(
          icon: Icon(prevIcon, size: 18),
          enabled: hasPrev,
          onPressed: () => cubit.setPage(currentPage - 1),
          theme: theme,
        ),

        // Page number circle
        Container(
          width: 26,
          height: 26,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.blue.shade600,
            shape: BoxShape.circle,
          ),
          child: Text(
            '$currentPage',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),

        // Next Page
        _IconButton(
          icon: Icon(nextIcon, size: 18),
          enabled: hasNext,
          onPressed: () => cubit.setPage(currentPage + 1),
          theme: theme,
        ),

        // Last Page
        _IconButton(
          icon: Icon(lastIcon, size: 18),
          enabled: hasNext,
          onPressed: () => cubit.setPage(totalPages),
          theme: theme,
        ),
      ],
    );
  }
}

class _IconButton extends StatelessWidget {
  final Widget icon;
  final bool enabled;
  final VoidCallback onPressed;
  final AdaptiveTableTheme theme;

  const _IconButton({
    required this.icon,
    required this.enabled,
    required this.onPressed,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final color = enabled
        ? theme.actionIconColor
        : theme.actionIconColor.withOpacity(0.3);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(4.0),
        onTap: enabled ? onPressed : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 4.0),
          child: IconTheme(
            data: IconThemeData(color: color),
            child: icon,
          ),
        ),
      ),
    );
  }
}
