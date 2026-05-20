import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/theme.dart';
import '../../domain/models/column_definition.dart';
import '../cubit/table_cubit.dart';
import 'table_content.dart';
import 'table_filter_bar.dart';
import 'table_footer.dart';
import 'table_header.dart';

/// Alignment helper maps.
typedef AdaptiveTableColumnAlignment = TableColumnAlignment;

/// Column configuration combining structural definitions and Flutter widget builders.
class AdaptiveTableColumn<T> {
  final ColumnDefinition definition;
  final Widget Function(BuildContext context, T item)? cellBuilder;
  final Widget Function(BuildContext context)? headerBuilder;

  AdaptiveTableColumn({
    required String id,
    required String title,
    required String fieldName,
    bool isSortable = true,
    bool isVisible = true,
    double? width,
    int flex = 1,
    AdaptiveTableColumnAlignment alignment = AdaptiveTableColumnAlignment.start,
    this.cellBuilder,
    this.headerBuilder,
  }) : definition = ColumnDefinition(
         id: id,
         title: title,
         fieldName: fieldName,
         isSortable: isSortable,
         isVisible: isVisible,
         width: width,
         flex: flex,
         alignment: alignment,
       );

  String get id => definition.id;
  String get title => definition.title;
  String get fieldName => definition.fieldName;
  bool get isSortable => definition.isSortable;
  bool get isVisible => definition.isVisible;
  double? get width => definition.width;
  int get flex => definition.flex;
  AdaptiveTableColumnAlignment get alignment => definition.alignment;
}

/// The main entry point widget. Orchestrates header toolbars, advanced date inputs,
/// responsive horizontal data grid, and page controllers.
class AdaptiveTableLayout<T> extends StatefulWidget {
  /// The collection of generic records to display.
  final List<T> items;

  /// Schema details mapping headers and alignments.
  final List<AdaptiveTableColumn<T>> columns;

  /// Extractors retrieving comparable values from items for search/sort/export.
  final Map<String, dynamic Function(T)> valueProviders;

  /// Optional date extractor enabling calendar limits search.
  final DateTime? Function(T)? dateProvider;

  /// Optional custom filter matcher for custom widget filter values.
  final bool Function(T, Map<String, dynamic>)? customFilterMatcher;

  /// Enables global text search box.
  final bool showSearch;

  /// Enables row selection checkbox column.
  final bool showSelection;

  /// Enables export formats (Excel, Word, PDF).
  final bool showExport;

  /// Enables direct PDF printing action.
  final bool showPrint;

  /// Enables column toggle visibility checkboxes.
  final bool showColumnsToggle;

  /// Enables pagination footer.
  final bool showPagination;

  /// Enables totals/summaries footer banner.
  final bool showSummary;

  /// Pagination size options, defaults to [5, 10, 20, 50].
  final List<int> pageSizes;

  /// Widget builder to aggregate totals in the bottom summary row.
  final Widget Function(BuildContext context, List<T> visibleItems)?
  summaryBuilder;

  /// Optional custom widget to display when selected row expands.
  final Widget Function(BuildContext context, T item)? expandedRowBuilder;

  /// Main title of the table dashboard.
  final String? title;

  /// Subtitle of the table dashboard.
  final String? subtitle;

  /// Icon next to the title.
  final Widget? titleIcon;

  /// Custom filter widgets injected in the filter bar.
  final List<Widget>? customFilters;

  /// Triggered when the refresh toolbar button is pressed.
  final VoidCallback? onRefreshPressed;

  /// Triggered when the Add New button is pressed.
  final VoidCallback? onAddNewPressed;

  /// Triggered when the date query button is pressed.
  final VoidCallback? onQueryPressed;

  /// Styling decoration overrides. Uses light theme as fallback.
  final AdaptiveTableTheme? theme;

  /// Minimum scrollable width before desktop tabular layout overflows.
  final double minDesktopWidth;

  /// Callback when a row cell is clicked.
  final ValueChanged<T>? onRowTap;

  /// Localized search placeholder.
  final String searchHint;

  /// Localized From date tag.
  final String dateFromLabel;

  /// Localized To date tag.
  final String dateToLabel;

  /// Localized query trigger tag.
  final String queryButtonLabel;

  /// Optional widget displayed if dataset resolves empty.
  final Widget? emptyWidget;

  /// Optional widget displayed while calculations run.
  final Widget? loadingWidget;

  const AdaptiveTableLayout({
    super.key,
    required this.items,
    required this.columns,
    required this.valueProviders,
    this.dateProvider,
    this.customFilterMatcher,
    this.showSearch = true,
    this.showSelection = true,
    this.showExport = true,
    this.showPrint = true,
    this.showColumnsToggle = true,
    this.showPagination = true,
    this.showSummary = true,
    this.pageSizes = const [5, 10, 20, 50],
    this.summaryBuilder,
    this.expandedRowBuilder,
    this.title,
    this.subtitle,
    this.titleIcon,
    this.customFilters,
    this.onRefreshPressed,
    this.onAddNewPressed,
    this.onQueryPressed,
    this.theme,
    this.minDesktopWidth = 800,
    this.onRowTap,
    this.searchHint = 'Search...',
    this.dateFromLabel = 'From Date',
    this.dateToLabel = 'To Date',
    this.queryButtonLabel = 'Query',
    this.emptyWidget,
    this.loadingWidget,
  });

  @override
  State<AdaptiveTableLayout<T>> createState() => _AdaptiveTableLayoutState<T>();
}

class _AdaptiveTableLayoutState<T> extends State<AdaptiveTableLayout<T>> {
  late TableCubit<T> _cubit;

  @override
  void initState() {
    super.initState();
    _cubit = TableCubit<T>(
      items: widget.items,
      columns: widget.columns.map((c) => c.definition).toList(),
      valueProviders: widget.valueProviders,
      dateProvider: widget.dateProvider,
      customFilterMatcher: widget.customFilterMatcher,
    );
  }

  @override
  void didUpdateWidget(covariant AdaptiveTableLayout<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.items != oldWidget.items) {
      _cubit.setItems(widget.items);
    }
  }

  @override
  void dispose() {
    _cubit.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final effectiveTheme = widget.theme ?? AdaptiveTableTheme.light(context);

    return BlocProvider<TableCubit<T>>.value(
      value: _cubit,
      child: Container(
        margin: effectiveTheme.cardMargin,
        padding: effectiveTheme.cardPadding,
        decoration: BoxDecoration(
          color: effectiveTheme.cardBackgroundColor,
          borderRadius: effectiveTheme.borderRadius,
          border: effectiveTheme.cardBorder,
          boxShadow: effectiveTheme.cardShadow,
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Top Header Bar
            TableHeader<T>(
              title: widget.title,
              subtitle: widget.subtitle,
              titleIcon: widget.titleIcon,
              onRefreshPressed: widget.onRefreshPressed,
              onAddNewPressed: widget.onAddNewPressed,
              columns: widget.columns,
              valueProviders: widget.valueProviders,
              showExport: widget.showExport,
              showPrint: widget.showPrint,
              showColumnsToggle: widget.showColumnsToggle,
              theme: effectiveTheme,
            ),

            // 2. Filter Bar
            TableFilterBar<T>(
              showSearch: widget.showSearch,
              customFilters: widget.customFilters,
              searchHint: widget.searchHint,
              dateFromLabel: widget.dateFromLabel,
              dateToLabel: widget.dateToLabel,
              queryButtonLabel: widget.queryButtonLabel,
              onQueryPressed: widget.onQueryPressed,
              theme: effectiveTheme,
            ),

            // 3. Main Data Content
            TableContent<T>(
              columns: widget.columns,
              valueProviders: widget.valueProviders,
              showSelection: widget.showSelection,
              emptyWidget: widget.emptyWidget,
              loadingWidget: widget.loadingWidget,
              minDesktopWidth: widget.minDesktopWidth,
              onRowTap: widget.onRowTap,
              expandedRowBuilder: widget.expandedRowBuilder,
              theme: effectiveTheme,
            ),

            // 4. Footer Pagination & Summaries
            TableFooter<T>(
              summaryBuilder: widget.summaryBuilder,
              showPagination: widget.showPagination,
              showSummary: widget.showSummary,
              pageSizes: widget.pageSizes,
              theme: effectiveTheme,
            ),
          ],
        ),
      ),
    );
  }
}
