import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/theme.dart';
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
  final double minDesktopWidth;
  final ValueChanged<T>? onRowTap;
  final Widget Function(BuildContext, T)? expandedRowBuilder;
  final AdaptiveTableTheme theme;

  const TableContent({
    super.key,
    required this.columns,
    required this.valueProviders,
    required this.showSelection,
    this.emptyWidget,
    this.loadingWidget,
    required this.minDesktopWidth,
    this.onRowTap,
    this.expandedRowBuilder,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TableCubit<T>, TableCubitState<T>>(
      builder: (context, state) {
        if (state is TableLoading<T>) {
          return loadingWidget ??
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32.0),
                  child: CircularProgressIndicator(),
                ),
              );
        }

        if (state is TableError<T>) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Text(
                state.errorMessage,
                style: const TextStyle(color: Colors.red),
              ),
            ),
          );
        }

        if (state is TableLoaded<T>) {
          final items = state.paginatedItems;
          if (items.isEmpty) {
            return emptyWidget ??
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.inbox_outlined,
                          size: 48,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          Directionality.of(context) == TextDirection.rtl
                              ? 'لا توجد بيانات متاحة'
                              : 'No data available',
                          style: theme.footerTextStyle,
                        ),
                      ],
                    ),
                  ),
                );
          }

          return LayoutBuilder(
            builder: (context, constraints) {
              // Breakpoint for adaptive layouts
              if (constraints.maxWidth < 600) {
                return _buildMobileLayout(context, items, state);
              }
              return _buildDesktopLayout(
                context,
                items,
                state,
                constraints.maxWidth,
              );
            },
          );
        }

        return const SizedBox.shrink();
      },
    );
  }

  // --- Desktop Render Engine ---

  Widget _buildDesktopLayout(
    BuildContext context,
    List<T> items,
    TableLoaded<T> state,
    double availableWidth,
  ) {
    final useHorizontalScroll = availableWidth < minDesktopWidth;
    final tableWidget = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Column Headers
        _buildDesktopHeader(context, state),
        const Divider(height: 1, thickness: 1),
        // Rows List
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: items.length,
          separatorBuilder: (context, index) =>
              Divider(height: 1, color: theme.dividerColor),
          itemBuilder: (context, index) {
            final item = items[index];
            final isSelected = state.selectedItems.contains(item);
            final isAlternate = theme.useAlternateRows && (index % 2 == 1);
            return _buildDesktopRow(context, item, isSelected, isAlternate);
          },
        ),
      ],
    );

    if (useHorizontalScroll) {
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(width: minDesktopWidth, child: tableWidget),
      );
    }
    return tableWidget;
  }

  Widget _buildDesktopHeader(BuildContext context, TableLoaded<T> state) {
    final visibleCols = columns
        .where((c) => !state.hiddenColumnIds.contains(c.id))
        .toList();

    return Container(
      color: theme.headerBackgroundColor,
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          // Select All Checkbox
          if (showSelection)
            SizedBox(
              width: 50,
              child: Checkbox(
                value:
                    state.selectedItems.length ==
                        state.filteredAndSortedItems.length &&
                    state.filteredAndSortedItems.isNotEmpty,
                onChanged: (val) {
                  context.read<TableCubit<T>>().toggleSelectAll(val ?? false);
                },
              ),
            ),

          // Render Column Titles
          ...visibleCols.map((col) {
            final isSorted = state.tableState.sortByColumnId == col.id;
            final isAscending = state.tableState.sortAscending;

            Widget headerCell = InkWell(
              onTap: col.isSortable
                  ? () => context.read<TableCubit<T>>().toggleSort(col.id)
                  : null,
              child: Padding(
                padding: theme.headerPadding,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: _getAlignment(col.alignment),
                  children: [
                    if (col.headerBuilder != null)
                      col.headerBuilder!(context)
                    else
                      Text(col.title, style: theme.headerTextStyle),
                    if (col.isSortable) ...[
                      const SizedBox(width: 4),
                      AnimatedOpacity(
                        duration: const Duration(milliseconds: 200),
                        opacity: isSorted ? 1.0 : 0.2,
                        child: Icon(
                          isSorted
                              ? (isAscending
                                    ? Icons.arrow_upward
                                    : Icons.arrow_downward)
                              : Icons.arrow_upward,
                          size: 14,
                          color: isSorted
                              ? Colors.blue.shade600
                              : theme.actionIconColor,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );

            // Alignment wrapper
            headerCell = Align(
              alignment: _getAlignPlacement(col.alignment),
              child: headerCell,
            );

            if (col.width != null) {
              return SizedBox(width: col.width, child: headerCell);
            }
            return Expanded(flex: col.flex, child: headerCell);
          }),
        ],
      ),
    );
  }

  Widget _buildDesktopRow(
    BuildContext context,
    T item,
    bool isSelected,
    bool isAlternate,
  ) {
    final state = context.read<TableCubit<T>>().state as TableLoaded<T>;
    final visibleCols = columns
        .where((c) => !state.hiddenColumnIds.contains(c.id))
        .toList();

    return Material(
      color: isSelected
          ? Colors.blue.shade500.withOpacity(0.08)
          : (isAlternate
                ? theme.alternateRowBackgroundColor
                : theme.rowBackgroundColor),
      child: InkWell(
        hoverColor: theme.rowHoverColor,
        onTap: () {
          if (onRowTap != null) onRowTap!(item);
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  // Row Selection Checkbox
                  if (showSelection)
                    SizedBox(
                      width: 50,
                      child: Checkbox(
                        value: isSelected,
                        onChanged: (val) {
                          context.read<TableCubit<T>>().toggleRowSelection(
                            item,
                          );
                        },
                      ),
                    ),

                  // Cells
                  ...visibleCols.map((col) {
                    Widget cellChild;
                    if (col.cellBuilder != null) {
                      cellChild = col.cellBuilder!(context, item);
                    } else {
                      final extractor = valueProviders[col.id];
                      final val = extractor != null ? extractor(item) : '';
                      cellChild = Text(
                        val?.toString() ?? '',
                        style: theme.rowTextStyle,
                        overflow: TextOverflow.ellipsis,
                      );
                    }

                    // Apply layout alignments
                    cellChild = Padding(
                      padding: theme.rowPadding,
                      child: Align(
                        alignment: _getAlignPlacement(col.alignment),
                        child: cellChild,
                      ),
                    );

                    if (col.width != null) {
                      return SizedBox(width: col.width, child: cellChild);
                    }
                    return Expanded(flex: col.flex, child: cellChild);
                  }),
                ],
              ),
            ),
            if (expandedRowBuilder != null && isSelected)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16.0),
                color: theme.headerBackgroundColor.withOpacity(0.5),
                child: expandedRowBuilder!(context, item),
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
    TableLoaded<T> state,
  ) {
    final visibleCols = columns
        .where((c) => !state.hiddenColumnIds.contains(c.id))
        .toList();
    if (visibleCols.isEmpty) return const SizedBox.shrink();

    // Use first column as identifier title, and second column as header value
    final titleCol = visibleCols.first;
    final subtitleCol = visibleCols.length > 1 ? visibleCols[1] : null;

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      itemBuilder: (context, index) {
        final item = items[index];
        final isSelected = state.selectedItems.contains(item);

        final titleExtractor = valueProviders[titleCol.id];
        final cardTitle = titleExtractor != null
            ? titleExtractor(item)?.toString() ?? ''
            : '';

        String? cardSubtitle;
        if (subtitleCol != null) {
          final subtitleExtractor = valueProviders[subtitleCol.id];
          cardSubtitle = subtitleExtractor != null
              ? subtitleExtractor(item)?.toString()
              : null;
        }

        return Card(
          elevation: 1,
          margin: const EdgeInsets.only(bottom: 10),
          color: isSelected
              ? Colors.blue.shade500.withOpacity(0.04)
              : theme.cardBackgroundColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(
              color: isSelected ? Colors.blue.shade300 : theme.dividerColor,
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: ExpansionTile(
            title: Row(
              children: [
                if (showSelection) ...[
                  Checkbox(
                    value: isSelected,
                    onChanged: (val) {
                      context.read<TableCubit<T>>().toggleRowSelection(item);
                    },
                  ),
                  const SizedBox(width: 4),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        cardTitle,
                        style: theme.headerTextStyle.copyWith(
                          fontSize: 14,
                          color: Colors.blue.shade800,
                        ),
                      ),
                      if (cardSubtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(cardSubtitle, style: theme.footerTextStyle),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            children: [
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Column(
                  children: visibleCols.skip(2).map((col) {
                    final colValExtractor = valueProviders[col.id];
                    Widget valWidget;
                    if (col.cellBuilder != null) {
                      valWidget = col.cellBuilder!(context, item);
                    } else {
                      final val = colValExtractor != null
                          ? colValExtractor(item)
                          : '';
                      valWidget = Text(
                        val?.toString() ?? '',
                        style: theme.rowTextStyle,
                      );
                    }

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            col.title,
                            style: theme.footerTextStyle.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          valWidget,
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
              if (expandedRowBuilder != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  color: theme.headerBackgroundColor.withOpacity(0.5),
                  child: expandedRowBuilder!(context, item),
                ),
            ],
          ),
        );
      },
    );
  }

  // --- Alignment Helpers ---

  MainAxisAlignment _getAlignment(TableColumnAlignment alignment) {
    return switch (alignment) {
      TableColumnAlignment.start => MainAxisAlignment.start,
      TableColumnAlignment.center => MainAxisAlignment.center,
      TableColumnAlignment.end => MainAxisAlignment.end,
    };
  }

  Alignment _getAlignPlacement(TableColumnAlignment alignment) {
    return switch (alignment) {
      TableColumnAlignment.start => Alignment.centerLeft,
      TableColumnAlignment.center => Alignment.center,
      TableColumnAlignment.end => Alignment.centerRight,
    };
  }
}
