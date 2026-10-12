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
import '../../domain/models/table_aggregate.dart';
import '../../domain/models/table_snapshot.dart';
import '../../domain/models/table_state_model.dart';
import '../../domain/usecases/filter_items_usecase.dart';
import '../../domain/utils/table_text_normalizer.dart';
import '../controller/adaptive_table_controller.dart';
import '../cubit/table_cubit.dart';
import '../cubit/table_cubit_state.dart';
import '../export/table_export_runner.dart';
import 'adaptive_table_column.dart';
import 'date_range/date_range_preset.dart';
import 'grid/table_entries.dart';
import 'skeleton/table_skeleton.dart';
import 'table_content.dart';
import 'table_filter_bar.dart';
import 'table_footer.dart';
import 'table_header.dart';

export '../export/table_export_runner.dart'
    show TableExportCallback, TablePrintCallback;
export 'adaptive_table_column.dart';

/// How rows are rendered.
enum TableLayoutMode {
  /// Cards below `mobileBreakpoint`, data grid above it (default).
  auto,

  /// Always the data grid (scrolls horizontally on small screens).
  table,

  /// Always expandable cards, even on wide screens.
  cards,
}

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

  /// Drives the table from outside (search, filters, selection, export…).
  final AdaptiveTableController<T>? controller;

  /// Identifies a row across data updates, e.g. `(invoice) => invoice.id`.
  ///
  /// Selected and expanded rows are matched by this key instead of `==`, so
  /// they survive new item instances (immutable `copyWith` updates, server
  /// reloads) and stay selected across server pages.
  final RowKeyBuilder<T>? rowKey;

  /// Enables global text search box.
  final bool showSearch;

  /// Shows the From / To date pickers. Defaults to `dateProvider != null`.
  final bool? showDateFilter;

  /// Enables row selection checkbox column.
  final bool showSelection;

  /// Enables export formats (Excel, CSV, Word, PDF).
  final bool showExport;

  /// Enables direct PDF printing action.
  final bool showPrint;

  /// Enables column toggle visibility checkboxes.
  final bool showColumnsToggle;

  /// Shows a "Group by" menu in the toolbar, listing the columns declared
  /// with `isGroupable: true` (the default) that have a value provider.
  final bool showGroupingMenu;

  /// Enables pagination footer. When `false`, every row is rendered.
  final bool showPagination;

  /// Enables totals/summaries footer banner.
  final bool showSummary;

  /// Shows a "clear filters" button while a search / date / custom filter is
  /// active.
  final bool showClearFilters;

  /// Shows a "Sort by" selector above the cards (phones have no column
  /// headers to click).
  final bool showCardSortBar;

  /// Pagination size options, defaults to `[5, 10, 20, 50]`. A value `<= 0`
  /// adds an "All" option.
  final List<int> pageSizes;

  /// Initial rows per page. Defaults to 10 when it's in [pageSizes],
  /// otherwise the first entry of [pageSizes]. `0` shows every row.
  final int? initialPageSize;

  /// Column sorted on first build.
  final String? initialSortColumnId;

  /// Direction of [initialSortColumnId].
  final bool initialSortAscending;

  /// A third click on a sorted column header removes its sort
  /// (ascending → descending → unsorted).
  final bool tristateSort;

  /// Restores a query and column layout saved from [onSnapshotChanged] (e.g.
  /// from the previous visit). Wins over [initialSortColumnId],
  /// [initialPageSize] and [groupByColumnId].
  final TableSnapshot? initialSnapshot;

  /// Called whenever the query (search, filters, sort, page, grouping) or
  /// the column layout (hidden, widths, order, frozen) changes. Persist the
  /// snapshot (`snapshot.encode()`) and pass it back as [initialSnapshot].
  final ValueChanged<TableSnapshot>? onSnapshotChanged;

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

  /// Vertical spacing of grid rows and column headers, applied on top of
  /// [theme].
  final TableDensity density;

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
  /// Page Up / Down, Ctrl + A (select all), Ctrl + C (copy), Escape
  /// (desktop grid).
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

  /// Column used as card title on mobile. Defaults to the first visible
  /// column showing text (so an id / number column is skipped).
  final String? mobileTitleColumnId;

  /// Column used as card subtitle on mobile. Defaults to the visible column
  /// after the title.
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

  /// How text is compared by the search and the column filters. The default
  /// is case-insensitive and tolerant of Arabic spelling variants
  /// (`أحمد` = `احمد`, `مدرسة` = `مدرسه`, `١٢٣` = `123`); use
  /// [TableTextNormalizer.caseInsensitive] for plain matching. Read once.
  final TextNormalizer textNormalizer;

  /// Date filter look: one "Period" button with presets and a range calendar
  /// (default) or the legacy separate From / To buttons.
  final DateFilterStyle dateFilterStyle;

  /// Quick periods of the date panel. `null` = [DateRangePreset.defaults],
  /// empty = no presets (calendar and typed fields only).
  final List<DateRangePreset>? datePresets;

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
  /// Takes precedence over [loadingStyle].
  final Widget? loadingWidget;

  /// What is shown while the first rows load: a spinner (default) or
  /// skeleton rows / cards with a shimmer ([TableLoadingStyle.skeleton]).
  /// Colors come from [AdaptiveTableTheme.skeletonBaseColor] and
  /// [AdaptiveTableTheme.skeletonHighlightColor].
  final TableLoadingStyle loadingStyle;

  /// Number of skeleton rows. `null` = the page size (at most 10).
  final int? skeletonRowCount;

  const AdaptiveTableLayout({
    super.key,
    this.items = const [],
    required this.columns,
    required this.valueProviders,
    this.dateProvider,
    this.customFilterMatcher,
    this.controller,
    this.rowKey,
    this.showSearch = true,
    this.showDateFilter,
    this.showSelection = true,
    this.showExport = true,
    this.showPrint = true,
    this.showColumnsToggle = true,
    this.showGroupingMenu = false,
    this.showPagination = true,
    this.showSummary = true,
    this.showClearFilters = true,
    this.showCardSortBar = true,
    this.pageSizes = const [5, 10, 20, 50],
    this.initialPageSize,
    this.initialSortColumnId,
    this.initialSortAscending = true,
    this.tristateSort = false,
    this.initialSnapshot,
    this.onSnapshotChanged,
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
    this.density = TableDensity.standard,
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
    this.textNormalizer = TableTextNormalizer.normalize,
    this.firstDate,
    this.lastDate,
    this.dateFilterStyle = DateFilterStyle.rangePicker,
    this.datePresets,
    this.exportOptions = const TableExportOptions(),
    this.isLoading = false,
    this.emptyWidget,
    this.loadingWidget,
    this.loadingStyle = TableLoadingStyle.spinner,
    this.skeletonRowCount,
  }) : assert(pageSizes.length > 0, 'pageSizes must not be empty');

  @override
  State<AdaptiveTableLayout<T>> createState() => _AdaptiveTableLayoutState<T>();
}

class _AdaptiveTableLayoutState<T> extends State<AdaptiveTableLayout<T>> {
  late TableCubit<T> _cubit;
  List<T>? _lastSelection;
  TableStateModel? _lastTableState;
  TableSnapshot? _lastSnapshot;
  Map<String, TableAggregator<T>> _aggregators = const {};

  /// Built-in aggregators by column id, reused while the aggregate and its
  /// value provider stay the same (so the cubit can skip recomputing them).
  final Map<String, (TableAggregate, Function, TableAggregator<T>)>
  _aggregatorCache = {};

  int get _effectivePageSize {
    if (!widget.showPagination) return 0;
    final initial = widget.initialPageSize;
    if (initial != null) return initial;
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

  Map<String, DisplayFormatter> get _displayFormatters => {
    for (final c in widget.columns)
      if (c.valueFormatter != null) c.id: c.valueFormatter!,
  };

  Map<String, TableAggregator<T>> _buildAggregators() {
    final result = <String, TableAggregator<T>>{};
    for (final c in widget.columns) {
      final custom = c.aggregator;
      if (custom != null) {
        result[c.id] = custom;
        continue;
      }
      final type = c.aggregate;
      final provider = widget.valueProviders[c.id];
      if (type == null || provider == null) continue;
      final cached = _aggregatorCache[c.id];
      if (cached != null && cached.$1 == type && cached.$2 == provider) {
        result[c.id] = cached.$3;
        continue;
      }
      Object? aggregate(List<T> rows) =>
          type.compute(rows.map((r) => provider(r) as Object?));
      _aggregatorCache[c.id] = (type, provider, aggregate);
      result[c.id] = aggregate;
    }
    return result;
  }

  /// The initial snapshot with the page size forced off when pagination is.
  TableSnapshot? get _initialSnapshot {
    final s = widget.initialSnapshot;
    if (s == null || widget.showPagination) return s;
    return s.copyWith(tableState: s.tableState.copyWith(pageSize: 0));
  }

  @override
  void initState() {
    super.initState();
    _aggregators = _buildAggregators();
    _cubit = TableCubit<T>(
      items: widget.items,
      columns: _definitions,
      valueProviders: widget.valueProviders,
      dateProvider: widget.dateProvider,
      customFilterMatcher: widget.customFilterMatcher,
      filterUseCase: FilterItemsUseCase(textNormalizer: widget.textNormalizer),
      initialTableState: TableStateModel(
        pageSize: _effectivePageSize,
        sortByColumnId: widget.initialSortColumnId,
        sortAscending: widget.initialSortAscending,
        groupByColumnId: widget.groupByColumnId,
      ),
      dataSource: widget.dataSource,
      rowKey: widget.rowKey,
      displayFormatters: _displayFormatters,
      aggregators: _aggregators,
      initialSnapshot: _initialSnapshot,
    );
    widget.controller?.attach(_cubit);
    _lastSelection = _cubit.selectedItems;
    _lastTableState = _cubit.tableState;
    _lastSnapshot = _cubit.snapshot;
  }

  @override
  void didUpdateWidget(covariant AdaptiveTableLayout<T> oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (!identical(widget.controller, oldWidget.controller)) {
      oldWidget.controller?.detach(_cubit);
      widget.controller?.attach(_cubit);
    }

    // The cubit only recomputes what actually changed (items by content,
    // columns by value, functions by identity).
    _aggregators = _buildAggregators();
    _cubit.updateConfiguration(
      columns: _definitions,
      valueProviders: widget.valueProviders,
      dateProvider: widget.dateProvider,
      clearDateProvider: widget.dateProvider == null,
      customFilterMatcher: widget.customFilterMatcher,
      clearCustomFilterMatcher: widget.customFilterMatcher == null,
      items: widget.items,
      dataSource: widget.dataSource,
      clearDataSource: widget.dataSource == null,
      displayFormatters: _displayFormatters,
      aggregators: _aggregators,
      rowKey: widget.rowKey,
      clearRowKey: widget.rowKey == null,
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

  /// Lets the controller export / print / copy like the toolbar does.
  void _bindControllerActions(TableExportRunner<T> runner) {
    TableLoaded<T>? loaded() {
      final s = _cubit.state;
      return mounted && s is TableLoaded<T> ? s : null;
    }

    bool rtl() => Directionality.of(context) == TextDirection.rtl;

    widget.controller?.bindActions(
      export: (format, rows) async {
        final state = loaded();
        if (state == null) return;
        await runner.export(
          format,
          state: state,
          isRtl: rtl(),
          messenger: ScaffoldMessenger.maybeOf(context),
          rows: rows,
        );
      },
      print: (rows) async {
        final state = loaded();
        if (state == null) return;
        await runner.printTable(
          state: state,
          isRtl: rtl(),
          messenger: ScaffoldMessenger.maybeOf(context),
          rows: rows,
        );
      },
      copy: (rows) async {
        final state = loaded();
        if (state == null) return 0;
        return runner.copyRows(
          state: state,
          messenger: ScaffoldMessenger.maybeOf(context),
          rows: rows,
        );
      },
    );
  }

  Widget _buildTable(BuildContext context, {required bool fill}) {
    final theme = (widget.theme ?? AdaptiveTableTheme.of(context)).withDensity(
      widget.density,
    );
    final baseLabels = widget.labels ?? AdaptiveTableLabels.of(context);
    final labels = baseLabels.copyWith(
      search: widget.searchHint,
      dateFrom: widget.dateFromLabel,
      dateTo: widget.dateToLabel,
      query: widget.queryButtonLabel,
    );

    final runner = TableExportRunner<T>(
      columns: widget.columns,
      valueProviders: widget.valueProviders,
      aggregators: _aggregators,
      options: widget.exportOptions,
      theme: theme,
      labels: labels,
      title: widget.title,
      subtitle: widget.subtitle,
      onExportRequested: widget.onExportRequested,
      onPrintRequested: widget.onPrintRequested,
      isRemote: widget.dataSource != null,
    );
    _bindControllerActions(runner);

    Widget content = TableContent<T>(
      columns: widget.columns,
      valueProviders: widget.valueProviders,
      showSelection: widget.showSelection,
      emptyWidget: widget.emptyWidget,
      loadingWidget: widget.loadingWidget,
      loadingStyle: widget.loadingStyle,
      skeletonRowCount: widget.skeletonRowCount,
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
      tristateSort: widget.tristateSort,
      showCardSortBar: widget.showCardSortBar,
      onCellEdited: widget.onCellEdited,
      canEditCell: widget.canEditCell,
      groupHeaderBuilder: widget.groupHeaderBuilder,
      minRowHeight: widget.minRowHeight,
      exportRunner: runner,
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
          showGroupingMenu: widget.showGroupingMenu,
          toolbarActions: widget.toolbarActions,
          exportRunner: runner,
          mobileBreakpoint: _chromeCompactWidth,
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
          dateFilterStyle: widget.dateFilterStyle,
          datePresets: widget.datePresets ?? DateRangePreset.defaults,
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
          // Compared by content: refreshed item lists don't count as a
          // selection change.
          if (!listEquals(_lastSelection, state.selectedItems)) {
            _lastSelection = state.selectedItems;
            widget.onSelectionChanged?.call(state.selectedItems);
          }
          if (_lastTableState != state.tableState) {
            _lastTableState = state.tableState;
            widget.onTableStateChanged?.call(state.tableState);
          }
          final onSnapshot = widget.onSnapshotChanged;
          if (onSnapshot != null) {
            final snapshot = state.snapshot;
            if (snapshot != _lastSnapshot) {
              _lastSnapshot = snapshot;
              onSnapshot(snapshot);
            }
          }
        },
        child: Padding(padding: theme.cardMargin, child: card),
      ),
    );
  }
}
