import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/labels.dart';
import '../../core/theme.dart';
import '../../data/exporters/table_export_options.dart';
import '../../domain/datasource/table_data_source.dart';
import '../../domain/models/column_definition.dart';
import '../../domain/models/table_state_model.dart';
import '../controller/adaptive_table_controller.dart';
import '../cubit/table_cubit.dart';
import '../cubit/table_cubit_state.dart';
import 'grid/cell_editor.dart';
import 'grid/table_entries.dart';
import 'table_content.dart';
import 'table_filter_bar.dart';
import 'table_footer.dart';
import 'table_header.dart';

/// Alignment helper maps.
typedef AdaptiveTableColumnAlignment = TableColumnAlignment;

/// How rows are rendered.
enum TableLayoutMode {
  /// Cards below `mobileBreakpoint`, data grid above it (default).
  auto,

  /// Always the data grid (scrolls horizontally on small screens).
  table,

  /// Always expandable cards, even on wide screens.
  cards,
}

/// Replaces the built-in export for a format. Receives the rows the table
/// would export (selected rows if any, otherwise all filtered rows, in the
/// current sort order).
typedef TableExportCallback<T> =
    Future<void> Function(ExportFormat format, List<T> rows);

/// Called after an inline cell edit. Update your data (e.g. replace the
/// item in `items` and call `setState`). Return `false` to reject the value
/// (the editor stays open), or throw to show the error.
typedef CellEditCallback<T> =
    FutureOr<bool?> Function(T item, String columnId, dynamic newValue);

/// Decides whether a given cell can be edited (e.g. from user permissions).
typedef CanEditCell<T> = bool Function(T item, String columnId);

/// Extra content of a group header row (aggregates, actions…).
typedef GroupHeaderBuilder<T> =
    Widget Function(BuildContext context, TableGroupInfo<T> group);

/// Replaces the built-in print action.
typedef TablePrintCallback<T> = Future<void> Function(List<T> rows);

/// Converts a raw cell value into the text shown in the table and written to
/// PDF / Word exports.
typedef CellValueFormatter = String Function(dynamic value);

/// Column configuration combining structural definitions and Flutter widget builders.
class AdaptiveTableColumn<T> {
  final ColumnDefinition definition;

  /// Custom cell widget. When `null`, the column's `valueProvider` value is
  /// shown as text (formatted by [valueFormatter]).
  final Widget Function(BuildContext context, T item)? cellBuilder;

  /// Custom header widget replacing the [title] text.
  final Widget Function(BuildContext context)? headerBuilder;

  /// Formats the raw value for the default text cell, mobile cards, and
  /// PDF / Word exports (Excel keeps the raw typed value).
  final CellValueFormatter? valueFormatter;

  /// Inline editor of this column (when `isEditable`). Inferred from the
  /// value type when `null`.
  final CellEditor? editor;

  /// Validates an inline edit before `onCellEdited` is called. Return an
  /// error message to keep the editor open.
  final String? Function(dynamic value)? cellValidator;

  AdaptiveTableColumn({
    required String id,
    required String title,
    String? fieldName,
    bool isSortable = true,
    bool isVisible = true,
    bool isSearchable = true,
    bool isExportable = true,
    bool isHideable = true,
    bool isFilterable = true,
    bool isResizable = true,
    bool isEditable = false,
    ColumnPin pin = ColumnPin.none,
    double? width,
    double minWidth = 60,
    int flex = 1,
    AdaptiveTableColumnAlignment alignment = AdaptiveTableColumnAlignment.start,
    this.cellBuilder,
    this.headerBuilder,
    this.valueFormatter,
    this.editor,
    this.cellValidator,
  }) : definition = ColumnDefinition(
         id: id,
         title: title,
         fieldName: fieldName,
         isSortable: isSortable,
         isVisible: isVisible,
         isSearchable: isSearchable,
         isExportable: isExportable,
         isHideable: isHideable,
         isFilterable: isFilterable,
         isResizable: isResizable,
         isEditable: isEditable,
         pin: pin,
         width: width,
         minWidth: minWidth,
         flex: flex,
         alignment: alignment,
       );

  String get id => definition.id;
  String get title => definition.title;
  String get fieldName => definition.fieldName;
  bool get isSortable => definition.isSortable;
  bool get isVisible => definition.isVisible;
  bool get isSearchable => definition.isSearchable;
  bool get isExportable => definition.isExportable;
  bool get isHideable => definition.isHideable;
  bool get isFilterable => definition.isFilterable;
  bool get isResizable => definition.isResizable;
  bool get isEditable => definition.isEditable;
  ColumnPin get pin => definition.pin;
  double get minWidth => definition.minWidth;
  double? get width => definition.width;
  int get flex => definition.flex;
  AdaptiveTableColumnAlignment get alignment => definition.alignment;
}

/// The main entry point widget. Orchestrates header toolbars, advanced date inputs,
/// responsive horizontal data grid, and page controllers.
class AdaptiveTableLayout<T> extends StatefulWidget {
  /// The collection of generic records to display.
  ///
  /// Both new list instances and in-place changes (add / remove on the same
  /// list followed by a rebuild) are detected.
  final List<T> items;

  /// Schema details mapping headers and alignments.
  final List<AdaptiveTableColumn<T>> columns;

  /// Extractors retrieving comparable values from items for search/sort/export.
  /// Keys are column ids. Extra keys without a column are used by the search only.
  final Map<String, dynamic Function(T)> valueProviders;

  /// Optional date extractor enabling calendar limits search.
  final DateTime? Function(T)? dateProvider;

  /// Optional custom filter matcher for custom widget filter values.
  final bool Function(T, Map<String, dynamic>)? customFilterMatcher;

  /// Drives the table from outside (search, filters, selection…).
  final AdaptiveTableController<T>? controller;

  /// Enables global text search box.
  final bool showSearch;

  /// Shows the From / To date pickers. Defaults to `dateProvider != null`.
  final bool? showDateFilter;

  /// Enables row selection checkbox column.
  final bool showSelection;

  /// Enables export formats (Excel, Word, PDF).
  final bool showExport;

  /// Enables direct PDF printing action.
  final bool showPrint;

  /// Enables column toggle visibility checkboxes.
  final bool showColumnsToggle;

  /// Enables pagination footer. When `false`, every row is rendered.
  final bool showPagination;

  /// Enables totals/summaries footer banner.
  final bool showSummary;

  /// Shows a "clear filters" button while a search / date / custom filter is
  /// active.
  final bool showClearFilters;

  /// Pagination size options, defaults to [5, 10, 20, 50].
  final List<int> pageSizes;

  /// Initial rows per page. Defaults to 10 when it's in [pageSizes],
  /// otherwise the first entry of [pageSizes].
  final int? initialPageSize;

  /// Column sorted on first build.
  final String? initialSortColumnId;

  /// Direction of [initialSortColumnId].
  final bool initialSortAscending;

  /// Widget builder to aggregate totals in the bottom summary row.
  /// Receives every filtered row (all pages).
  final Widget Function(BuildContext context, List<T> visibleItems)?
  summaryBuilder;

  /// Optional details panel. Rows get an expand arrow; tapping the row also
  /// expands it when [onRowTap] is `null`.
  final Widget Function(BuildContext context, T item)? expandedRowBuilder;

  /// Main title of the table dashboard.
  final String? title;

  /// Subtitle of the table dashboard.
  final String? subtitle;

  /// Icon next to the title.
  final Widget? titleIcon;

  /// Custom filter widgets injected in the filter bar. They are built below
  /// the table's `BlocProvider`, so they can call
  /// `context.read<TableCubit<T>>().setCustomFilter(...)`.
  final List<Widget>? customFilters;

  /// Extra widgets appended to the toolbar actions.
  final List<Widget>? toolbarActions;

  /// Triggered when the refresh toolbar button is pressed.
  final VoidCallback? onRefreshPressed;

  /// Triggered when the Add New button is pressed.
  final VoidCallback? onAddNewPressed;

  /// Triggered when the date query button is pressed. When set, date changes
  /// are applied only when the button is pressed.
  final VoidCallback? onQueryPressed;

  /// Styling decoration overrides. Defaults to [AdaptiveTableTheme.of].
  final AdaptiveTableTheme? theme;

  /// Every user-facing string. Defaults to [AdaptiveTableLabels.of].
  final AdaptiveTableLabels? labels;

  /// Minimum scrollable width before desktop tabular layout overflows.
  final double minDesktopWidth;

  /// Below this width rows are rendered as cards (with [TableLayoutMode.auto]).
  final double mobileBreakpoint;

  /// Forces the grid or the cards regardless of the screen width.
  final TableLayoutMode layoutMode;

  /// Your own export implementation (e.g. your PDF template). When set, the
  /// export menu calls it instead of generating the file.
  final TableExportCallback<T>? onExportRequested;

  /// Your own print implementation.
  final TablePrintCallback<T>? onPrintRequested;

  /// Loads rows page by page from a server. When set, [items] is ignored and
  /// search / filters / sort / pagination are delegated to the data source.
  /// Create it once (e.g. in `initState`), not in `build`.
  final AdaptiveTableDataSource<T>? dataSource;

  /// Fixed height of the rows area. Enables a sticky header and lazy
  /// (virtualized) row building, for thousands of rows.
  final double? bodyHeight;

  /// Makes the table fill the height of its parent (which must have a
  /// bounded height, e.g. `Expanded` or `SizedBox`), with a sticky header
  /// and virtualized rows. Ignored when the parent height is unbounded.
  final bool fillHeight;

  /// Shows a filter field under each column header (desktop grid).
  final bool showColumnFilters;

  /// Lets users resize columns by dragging the header edge (desktop grid).
  /// Double-click the edge to restore the declared width.
  final bool allowColumnResize;

  /// Lets users reorder columns by long-pressing and dragging a header.
  final bool allowColumnReorder;

  /// Arrow keys, Enter / F2 (edit), Space (select), Tab, Home / End,
  /// Page Up / Down, Ctrl + A, Escape (desktop grid).
  final bool enableKeyboardNavigation;

  /// Groups rows by this column initially.
  final String? groupByColumnId;

  /// Extra content (aggregates…) shown in each group header.
  final GroupHeaderBuilder<T>? groupHeaderBuilder;

  /// Enables inline editing of columns declared with `isEditable: true`.
  final CellEditCallback<T>? onCellEdited;

  /// Per-cell edit permission.
  final CanEditCell<T>? canEditCell;

  /// Minimum height of desktop rows.
  final double minRowHeight;

  /// Callback when a row cell is clicked.
  final ValueChanged<T>? onRowTap;

  /// Callback when a row is long-pressed.
  final ValueChanged<T>? onRowLongPress;

  /// Called whenever the selection changes.
  final ValueChanged<List<T>>? onSelectionChanged;

  /// Called whenever search / filters / sort / page change (useful for
  /// persisting the table state or server-side queries).
  final ValueChanged<TableStateModel>? onTableStateChanged;

  /// Per-row background override (return `null` for the default).
  final Color? Function(T item)? rowColorBuilder;

  /// Column used as card title on mobile. Defaults to the first visible column.
  final String? mobileTitleColumnId;

  /// Column used as card subtitle on mobile. Defaults to the second visible column.
  final String? mobileSubtitleColumnId;

  /// Localized search placeholder. Overrides [labels].
  final String? searchHint;

  /// Localized From date tag. Overrides [labels].
  final String? dateFromLabel;

  /// Localized To date tag. Overrides [labels].
  final String? dateToLabel;

  /// Localized query trigger tag. Overrides [labels].
  final String? queryButtonLabel;

  /// Delay before a search keystroke is applied.
  final Duration searchDebounce;

  /// Earliest date selectable in the date filter.
  final DateTime? firstDate;

  /// Latest date selectable in the date filter.
  final DateTime? lastDate;

  /// Export / print configuration.
  final TableExportOptions exportOptions;

  /// Shows [loadingWidget] (or a progress indicator) instead of / above rows.
  final bool isLoading;

  /// Optional widget displayed if dataset resolves empty.
  final Widget? emptyWidget;

  /// Optional widget displayed while [isLoading] is `true` and there are no rows.
  final Widget? loadingWidget;

  const AdaptiveTableLayout({
    super.key,
    this.items = const [],
    required this.columns,
    required this.valueProviders,
    this.dateProvider,
    this.customFilterMatcher,
    this.controller,
    this.showSearch = true,
    this.showDateFilter,
    this.showSelection = true,
    this.showExport = true,
    this.showPrint = true,
    this.showColumnsToggle = true,
    this.showPagination = true,
    this.showSummary = true,
    this.showClearFilters = true,
    this.pageSizes = const [5, 10, 20, 50],
    this.initialPageSize,
    this.initialSortColumnId,
    this.initialSortAscending = true,
    this.summaryBuilder,
    this.expandedRowBuilder,
    this.title,
    this.subtitle,
    this.titleIcon,
    this.customFilters,
    this.toolbarActions,
    this.onRefreshPressed,
    this.onAddNewPressed,
    this.onQueryPressed,
    this.theme,
    this.labels,
    this.minDesktopWidth = 800,
    this.mobileBreakpoint = 600,
    this.layoutMode = TableLayoutMode.auto,
    this.onExportRequested,
    this.onPrintRequested,
    this.dataSource,
    this.bodyHeight,
    this.fillHeight = false,
    this.showColumnFilters = false,
    this.allowColumnResize = true,
    this.allowColumnReorder = true,
    this.enableKeyboardNavigation = true,
    this.groupByColumnId,
    this.groupHeaderBuilder,
    this.onCellEdited,
    this.canEditCell,
    this.minRowHeight = 0,
    this.onRowTap,
    this.onRowLongPress,
    this.onSelectionChanged,
    this.onTableStateChanged,
    this.rowColorBuilder,
    this.mobileTitleColumnId,
    this.mobileSubtitleColumnId,
    this.searchHint,
    this.dateFromLabel,
    this.dateToLabel,
    this.queryButtonLabel,
    this.searchDebounce = const Duration(milliseconds: 250),
    this.firstDate,
    this.lastDate,
    this.exportOptions = const TableExportOptions(),
    this.isLoading = false,
    this.emptyWidget,
    this.loadingWidget,
  }) : assert(pageSizes.length > 0, 'pageSizes must not be empty');

  @override
  State<AdaptiveTableLayout<T>> createState() => _AdaptiveTableLayoutState<T>();
}

class _AdaptiveTableLayoutState<T> extends State<AdaptiveTableLayout<T>> {
  late TableCubit<T> _cubit;
  List<T>? _lastSelection;
  TableStateModel? _lastTableState;

  int get _effectivePageSize {
    if (!widget.showPagination) return 0;
    final initial = widget.initialPageSize;
    if (initial != null && initial > 0) return initial;
    return widget.pageSizes.contains(10) ? 10 : widget.pageSizes.first;
  }

  /// Toolbar and footer switch to their compact layout by their own width,
  /// independently of how the rows are rendered.
  static const double _chromeCompactWidth = 600;

  double get _contentBreakpoint => switch (widget.layoutMode) {
    TableLayoutMode.auto => widget.mobileBreakpoint,
    TableLayoutMode.table => 0,
    TableLayoutMode.cards => double.infinity,
  };

  List<ColumnDefinition> get _definitions =>
      widget.columns.map((c) => c.definition).toList();

  @override
  void initState() {
    super.initState();
    _cubit = TableCubit<T>(
      items: widget.items,
      columns: _definitions,
      valueProviders: widget.valueProviders,
      dateProvider: widget.dateProvider,
      customFilterMatcher: widget.customFilterMatcher,
      initialTableState: TableStateModel(
        pageSize: _effectivePageSize,
        sortByColumnId: widget.initialSortColumnId,
        sortAscending: widget.initialSortAscending,
        groupByColumnId: widget.groupByColumnId,
      ),
      dataSource: widget.dataSource,
    );
    widget.controller?.attach(_cubit);
    _lastSelection = _cubit.selectedItems;
    _lastTableState = _cubit.tableState;
  }

  @override
  void didUpdateWidget(covariant AdaptiveTableLayout<T> oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (!identical(widget.controller, oldWidget.controller)) {
      oldWidget.controller?.detach(_cubit);
      widget.controller?.attach(_cubit);
    }

    final newDefs = _definitions;
    final columnsChanged = !listEquals(newDefs, _cubit.columns);
    final itemsChanged = !listEquals(widget.items, _cubit.items);

    // Providers are usually closures recreated on every build, so they are
    // always refreshed; one recompute covers items + configuration.
    _cubit.updateConfiguration(
      columns: columnsChanged ? newDefs : null,
      valueProviders: widget.valueProviders,
      dateProvider: widget.dateProvider,
      clearDateProvider: widget.dateProvider == null,
      customFilterMatcher: widget.customFilterMatcher,
      clearCustomFilterMatcher: widget.customFilterMatcher == null,
      items: itemsChanged ? widget.items : null,
      dataSource: widget.dataSource,
      clearDataSource: widget.dataSource == null,
    );

    if (widget.groupByColumnId != oldWidget.groupByColumnId) {
      _cubit.groupBy(widget.groupByColumnId);
    }

    if (widget.showPagination != oldWidget.showPagination ||
        (widget.showPagination &&
            !widget.pageSizes.contains(_cubit.tableState.pageSize) &&
            !listEquals(widget.pageSizes, oldWidget.pageSizes))) {
      _cubit.setPageSize(_effectivePageSize);
    }
  }

  @override
  void dispose() {
    widget.controller?.detach(_cubit);
    _cubit.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.fillHeight) return _buildTable(context, fill: false);
    return LayoutBuilder(
      builder: (context, constraints) {
        final fill = constraints.hasBoundedHeight;
        assert(() {
          if (!fill) {
            debugPrint(
              'AdaptiveTableLayout: fillHeight needs a parent with a bounded '
              'height (Expanded, SizedBox…). Falling back to natural height.',
            );
          }
          return true;
        }());
        return _buildTable(context, fill: fill);
      },
    );
  }

  Widget _buildTable(BuildContext context, {required bool fill}) {
    final theme = widget.theme ?? AdaptiveTableTheme.of(context);
    final baseLabels = widget.labels ?? AdaptiveTableLabels.of(context);
    final labels = baseLabels.copyWith(
      search: widget.searchHint,
      dateFrom: widget.dateFromLabel,
      dateTo: widget.dateToLabel,
      query: widget.queryButtonLabel,
    );

    Widget content = TableContent<T>(
      columns: widget.columns,
      valueProviders: widget.valueProviders,
      showSelection: widget.showSelection,
      emptyWidget: widget.emptyWidget,
      loadingWidget: widget.loadingWidget,
      isLoading: widget.isLoading,
      minDesktopWidth: widget.minDesktopWidth,
      mobileBreakpoint: _contentBreakpoint,
      onRowTap: widget.onRowTap,
      onRowLongPress: widget.onRowLongPress,
      rowColorBuilder: widget.rowColorBuilder,
      expandedRowBuilder: widget.expandedRowBuilder,
      mobileTitleColumnId: widget.mobileTitleColumnId,
      mobileSubtitleColumnId: widget.mobileSubtitleColumnId,
      showColumnFilters: widget.showColumnFilters,
      allowColumnResize: widget.allowColumnResize,
      allowColumnReorder: widget.allowColumnReorder,
      enableKeyboardNavigation: widget.enableKeyboardNavigation,
      onCellEdited: widget.onCellEdited,
      canEditCell: widget.canEditCell,
      groupHeaderBuilder: widget.groupHeaderBuilder,
      minRowHeight: widget.minRowHeight,
      theme: theme,
      labels: labels,
    );
    if (fill) {
      content = Expanded(child: content);
    } else if (widget.bodyHeight != null) {
      content = SizedBox(height: widget.bodyHeight, child: content);
    }

    final Widget tableBody = Column(
      mainAxisSize: fill ? MainAxisSize.max : MainAxisSize.min,
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
          toolbarActions: widget.toolbarActions,
          exportOptions: widget.exportOptions,
          mobileBreakpoint: _chromeCompactWidth,
          onExportRequested: widget.onExportRequested,
          onPrintRequested: widget.onPrintRequested,
          theme: theme,
          labels: labels,
        ),

        // 2. Filter Bar
        TableFilterBar<T>(
          showSearch: widget.showSearch,
          showDateFilter: widget.showDateFilter ?? widget.dateProvider != null,
          showClearFilters: widget.showClearFilters,
          customFilters: widget.customFilters,
          onQueryPressed: widget.onQueryPressed,
          searchDebounce: widget.searchDebounce,
          firstDate: widget.firstDate,
          lastDate: widget.lastDate,
          theme: theme,
          labels: labels,
        ),

        // 3. Main Data Content
        content,

        // 4. Footer Pagination & Summaries
        TableFooter<T>(
          summaryBuilder: widget.summaryBuilder,
          showPagination: widget.showPagination,
          showSummary: widget.showSummary,
          pageSizes: widget.pageSizes,
          mobileBreakpoint: _chromeCompactWidth,
          theme: theme,
          labels: labels,
        ),
      ],
    );

    final decoration = BoxDecoration(
      color: theme.cardBackgroundColor,
      borderRadius: theme.borderRadius,
      border: theme.cardBorder,
    );

    Widget card;
    if (theme.enableGlassmorphism) {
      card = DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: theme.borderRadius,
          boxShadow: theme.cardShadow,
        ),
        child: ClipRRect(
          borderRadius: theme.borderRadius,
          child: BackdropFilter(
            filter: ImageFilter.blur(
              sigmaX: theme.blurSigma,
              sigmaY: theme.blurSigma,
            ),
            child: Container(
              padding: theme.cardPadding,
              decoration: decoration,
              child: tableBody,
            ),
          ),
        ),
      );
    } else {
      card = Container(
        padding: theme.cardPadding,
        decoration: decoration.copyWith(boxShadow: theme.cardShadow),
        clipBehavior: Clip.antiAlias,
        child: tableBody,
      );
    }

    return BlocProvider<TableCubit<T>>.value(
      value: _cubit,
      child: BlocListener<TableCubit<T>, TableCubitState<T>>(
        listenWhen: (prev, next) => next is TableLoaded<T>,
        listener: (context, state) {
          if (state is! TableLoaded<T>) return;
          if (!identical(_lastSelection, state.selectedItems)) {
            _lastSelection = state.selectedItems;
            widget.onSelectionChanged?.call(state.selectedItems);
          }
          if (_lastTableState != state.tableState) {
            _lastTableState = state.tableState;
            widget.onTableStateChanged?.call(state.tableState);
          }
        },
        child: Padding(padding: theme.cardMargin, child: card),
      ),
    );
  }
}
