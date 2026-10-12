import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/datasource/table_data_source.dart';
import '../../domain/models/column_definition.dart';
import '../../domain/models/table_snapshot.dart';
import '../../domain/models/table_state_model.dart';
import '../../domain/usecases/filter_items_usecase.dart';
import 'table_cubit_state.dart';

/// Cubit responsible for managing the logical state, column visibility,
/// search queries, date limits, and pagination slicing of the table.
///
/// It keeps its own copy of the items, query state, selection and hidden
/// columns, so it never mutates the lists you pass in, and a failing
/// `valueProvider` emits [TableError] without losing the last good state.
///
/// With a [dataSource] the cubit works in *server mode*: every query change
/// (search, filters, sort, page…) calls `dataSource.fetch` and the returned
/// page is displayed as-is. Out-of-order responses are ignored.
class TableCubit<T> extends Cubit<TableCubitState<T>> {
  List<ColumnDefinition> _columns;
  Map<String, dynamic Function(T)> _valueProviders;
  DateTime? Function(T)? _dateProvider;
  bool Function(T, Map<String, dynamic>)? _customFilterMatcher;
  Map<String, DisplayFormatter> _displayFormatters;
  Map<String, TableAggregator<T>> _aggregators;
  RowKeyBuilder<T>? _rowKey;
  final FilterItemsUseCase _filterUseCase;
  final TableStateModel _initialTableState;

  List<T> _items = const [];
  TableStateModel _tableState;
  List<T> _selected = const [];
  List<String> _hidden;
  List<T> _expanded = const [];
  Map<String, double> _widths = const {};
  List<String> _order = const [];
  Map<String, ColumnPin> _pins = const {};
  Set<String> _collapsed = const {};
  Map<String, Object?> _aggregates = const {};

  AdaptiveTableDataSource<T>? _dataSource;
  List<T> _remoteItems = const [];
  int _remoteTotal = 0;
  bool _fetching = false;
  int _requestId = 0;

  TableCubit({
    required List<T> items,
    required List<ColumnDefinition> columns,
    required Map<String, dynamic Function(T)> valueProviders,
    DateTime? Function(T)? dateProvider,
    bool Function(T, Map<String, dynamic>)? customFilterMatcher,
    FilterItemsUseCase filterUseCase = const FilterItemsUseCase(),
    TableStateModel initialTableState = const TableStateModel(),
    AdaptiveTableDataSource<T>? dataSource,
    RowKeyBuilder<T>? rowKey,
    Map<String, DisplayFormatter> displayFormatters = const {},
    Map<String, TableAggregator<T>> aggregators = const {},
    TableSnapshot? initialSnapshot,
  }) : _dataSource = dataSource,
       _columns = List.unmodifiable(columns),
       _valueProviders = Map.unmodifiable(valueProviders),
       _dateProvider = dateProvider,
       _customFilterMatcher = customFilterMatcher,
       _displayFormatters = Map.unmodifiable(displayFormatters),
       _aggregators = Map.unmodifiable(aggregators),
       _rowKey = rowKey,
       _filterUseCase = filterUseCase,
       _initialTableState = initialTableState,
       _tableState = initialTableState,
       _hidden = List.unmodifiable(
         columns.where((c) => !c.isVisible).map((c) => c.id),
       ),
       super(const TableLoading()) {
    if (initialSnapshot != null) _applySnapshot(initialSnapshot);
    setItems(items);
  }

  // --- Read accessors ---

  /// The column definitions this cubit works with.
  List<ColumnDefinition> get columns => _columns;

  /// The current search / sort / page state.
  TableStateModel get tableState => _tableState;

  /// The current raw items.
  List<T> get items => _items;

  /// Currently selected items.
  List<T> get selectedItems => _selected;

  /// IDs of hidden columns.
  List<String> get hiddenColumnIds => _hidden;

  /// Visible column definitions in display order.
  List<ColumnDefinition> get visibleColumns =>
      _columns.where((c) => !_hidden.contains(c.id)).toList();

  /// Whether rows come from a server-side [AdaptiveTableDataSource].
  bool get isRemote => _dataSource != null;

  /// Whether a server request is in flight.
  bool get isFetching => _fetching;

  /// The current query and column layout (see [restoreSnapshot]).
  TableSnapshot get snapshot => TableSnapshot(
    tableState: _tableState,
    hiddenColumnIds: _hidden,
    columnWidths: _widths,
    columnOrder: _order,
    columnPins: _pins,
  );

  /// Identity of [item] (the `rowKey`, or the item itself).
  Object? keyOf(T item) {
    final key = _rowKey;
    return key == null ? item : key(item);
  }

  /// Whether [item] is selected (matched by row key).
  bool isSelected(T item) {
    final key = keyOf(item);
    return _selected.any((s) => keyOf(s) == key);
  }

  // --- Data & configuration ---

  /// Sets or updates the raw dataset items and recalculates output.
  ///
  /// Selected / expanded rows are matched to the new items by row key: they
  /// follow their new instances, and rows that no longer exist are dropped.
  /// The current page is clamped to the new page count.
  void setItems(List<T> items, [TableStateModel? stateOverride]) {
    _items = List.unmodifiable(items);
    if (stateOverride != null) _tableState = stateOverride;
    _selected = _refreshRows(_selected, _items);
    _expanded = _refreshRows(_expanded, _items);
    _recompute();
  }

  /// Replaces columns / providers / matchers / items (e.g. after a locale
  /// change or a parent rebuild).
  ///
  /// Only what actually changed triggers work: new items, columns, value
  /// providers, date provider or custom matcher re-run the query once; new
  /// aggregators only recompute the totals; identical values are ignored.
  /// Call [refresh] to force a recomputation.
  void updateConfiguration({
    List<T>? items,
    List<ColumnDefinition>? columns,
    Map<String, dynamic Function(T)>? valueProviders,
    DateTime? Function(T)? dateProvider,
    bool clearDateProvider = false,
    bool Function(T, Map<String, dynamic>)? customFilterMatcher,
    bool clearCustomFilterMatcher = false,
    AdaptiveTableDataSource<T>? dataSource,
    bool clearDataSource = false,
    Map<String, DisplayFormatter>? displayFormatters,
    Map<String, TableAggregator<T>>? aggregators,
    RowKeyBuilder<T>? rowKey,
    bool clearRowKey = false,
  }) {
    var requery = false;
    var refetch = false;
    var reaggregate = false;
    var relayout = false;
    final stateBefore = _tableState;

    if (dataSource != null || clearDataSource) {
      if (!identical(dataSource, _dataSource)) {
        _dataSource = dataSource;
        refetch = true;
      }
    }
    if (rowKey != null || clearRowKey) _rowKey = rowKey;
    if (columns != null && !listEquals(columns, _columns)) {
      _applyColumns(columns);
      requery = true;
      relayout = true;
    }
    if (valueProviders != null &&
        !_sameFunctions(valueProviders, _valueProviders)) {
      _valueProviders = Map.unmodifiable(valueProviders);
      requery = true;
    }
    if ((dateProvider != null || clearDateProvider) &&
        dateProvider != _dateProvider) {
      _dateProvider = dateProvider;
      requery = requery || _tableState.startDate != null;
      requery = requery || _tableState.endDate != null;
    }
    if ((customFilterMatcher != null || clearCustomFilterMatcher) &&
        customFilterMatcher != _customFilterMatcher) {
      _customFilterMatcher = customFilterMatcher;
      requery = requery || _tableState.customFilters.isNotEmpty;
    }
    if (displayFormatters != null &&
        !_sameFunctions(displayFormatters, _displayFormatters)) {
      _displayFormatters = Map.unmodifiable(displayFormatters);
      // Only the search and the column filters read the displayed text.
      requery =
          requery ||
          _tableState.searchQuery.trim().isNotEmpty ||
          _tableState.columnFilters.isNotEmpty;
    }
    if (aggregators != null && !_sameFunctions(aggregators, _aggregators)) {
      _aggregators = Map.unmodifiable(aggregators);
      reaggregate = true;
    }

    if (isRemote) {
      // The server filters and sorts: only a new source or a query changed
      // by removed columns needs a new request.
      if (refetch || _tableState != stateBefore) {
        _recompute();
        return;
      }
      if (reaggregate) {
        final next = _remoteAggregatesOr(_remoteItems);
        if (!mapEquals(next, _aggregates)) {
          _aggregates = next;
          relayout = true;
        }
      }
      if (relayout) _emitCurrent();
      return;
    }

    if (items != null && !listEquals(items, _items)) {
      _items = List.unmodifiable(items);
      _selected = _refreshRows(_selected, _items);
      _expanded = _refreshRows(_expanded, _items);
      requery = true;
    }
    if (requery || refetch) {
      _recompute();
    } else if (reaggregate) {
      final result = _lastResult;
      if (result == null) return;
      final next = _safeAggregates(result.filteredAndSorted);
      if (next == null || mapEquals(next, _aggregates)) return;
      _aggregates = next;
      _emitCurrent();
    }
  }

  /// Re-runs the query (server mode: fetches the current page again).
  void refresh() => _recompute();

  // --- Filtering ---

  /// Updates global search query and resets pagination to page 1.
  void updateSearchQuery(String query) {
    if (query == _tableState.searchQuery) return;
    _update(_tableState.copyWith(searchQuery: query, currentPage: 1));
  }

  /// Updates date range boundaries and resets pagination to page 1.
  /// Pass `null` to remove a boundary. Reversed ranges are swapped.
  void updateDateRange(DateTime? start, DateTime? end) {
    if (start != null && end != null && start.isAfter(end)) {
      final tmp = start;
      start = end;
      end = tmp;
    }
    _update(
      _tableState.copyWith(
        startDate: start,
        clearStartDate: start == null,
        endDate: end,
        clearEndDate: end == null,
        currentPage: 1,
      ),
    );
  }

  /// Removes both date boundaries.
  void clearDateRange() => updateDateRange(null, null);

  /// Replaces the custom filter map and resets pagination to page 1.
  void updateCustomFilters(Map<String, dynamic> customFilters) {
    _update(_tableState.copyWith(customFilters: customFilters, currentPage: 1));
  }

  /// Sets (or removes, when [value] is `null`) a single custom filter entry.
  void setCustomFilter(String key, dynamic value) {
    final next = Map<String, dynamic>.of(_tableState.customFilters);
    if (value == null) {
      next.remove(key);
    } else {
      next[key] = value;
    }
    updateCustomFilters(next);
  }

  /// Clears search, dates and custom filters (keeps sort & page size).
  void resetFilters() {
    _update(
      _tableState.copyWith(
        searchQuery: '',
        clearStartDate: true,
        clearEndDate: true,
        customFilters: const {},
        columnFilters: const {},
        currentPage: 1,
      ),
    );
  }

  /// Sets (or clears, when empty / `null`) the filter expression of one
  /// column. See `ColumnFilterMatcher` for the syntax.
  void setColumnFilter(String columnId, String? expression) {
    final next = Map<String, String>.of(_tableState.columnFilters);
    if (expression == null || expression.trim().isEmpty) {
      if (next.remove(columnId) == null) return;
    } else {
      if (next[columnId] == expression) return;
      next[columnId] = expression;
    }
    _update(_tableState.copyWith(columnFilters: next, currentPage: 1));
  }

  /// Clears every per-column filter.
  void clearColumnFilters() {
    if (_tableState.columnFilters.isEmpty) return;
    _update(_tableState.copyWith(columnFilters: const {}, currentPage: 1));
  }

  // --- Grouping ---

  /// Groups rows by [columnId] (`null` removes the grouping).
  void groupBy(String? columnId) {
    if (columnId == _tableState.groupByColumnId) return;
    _collapsed = const {};
    _update(
      _tableState.copyWith(
        groupByColumnId: columnId,
        clearGroup: columnId == null,
        currentPage: 1,
      ),
    );
  }

  /// Collapses / expands the group whose key is [groupKey].
  void toggleGroupCollapsed(String groupKey) {
    _collapsed = Set.unmodifiable(
      _collapsed.contains(groupKey)
          ? _collapsed.difference({groupKey})
          : {..._collapsed, groupKey},
    );
    _emitCurrent();
  }

  /// Collapses the given groups (or expands all when [groupKeys] is empty).
  void setCollapsedGroups(Iterable<String> groupKeys) {
    _collapsed = Set.unmodifiable(groupKeys.toSet());
    _emitCurrent();
  }

  /// Restores the initial state passed to the constructor (filters, sort,
  /// page size) and clears the selection.
  void resetAll() {
    _selected = const [];
    _expanded = const [];
    _collapsed = const {};
    _update(_initialTableState);
  }

  // --- Sorting ---

  /// Sorts by the specified column, or toggles ascending/descending.
  ///
  /// With [additive] (Shift + click) the column is added as a secondary
  /// sort level instead of replacing the current sort; clicking it again
  /// toggles its direction.
  ///
  /// With [tristate] a third click on a descending column removes it
  /// (ascending → descending → unsorted).
  void toggleSort(
    String columnId, {
    bool additive = false,
    bool tristate = false,
  }) {
    final sorts = _tableState.sorts;
    if (additive && sorts.isNotEmpty) {
      final index = sorts.indexWhere((s) => s.columnId == columnId);
      final next = [...sorts];
      if (index == -1) {
        next.add(ColumnSort(columnId));
      } else if (tristate && !next[index].ascending) {
        next.removeAt(index);
      } else {
        next[index] = next[index].toggled();
      }
      _setSorts(next);
      return;
    }
    final isPrimary = _tableState.sortByColumnId == columnId;
    if (isPrimary && tristate && !_tableState.sortAscending) {
      clearSort();
      return;
    }
    sortBy(columnId, ascending: isPrimary ? !_tableState.sortAscending : true);
  }

  /// Sorts by [columnId] in the given direction. With [additive] the column
  /// is appended as another sort level.
  void sortBy(String columnId, {bool ascending = true, bool additive = false}) {
    if (additive && _tableState.sortByColumnId != null) {
      final next = [
        ..._tableState.sorts.where((s) => s.columnId != columnId),
        ColumnSort(columnId, ascending: ascending),
      ];
      _setSorts(next);
      return;
    }
    _update(
      _tableState.copyWith(
        sortByColumnId: columnId,
        sortAscending: ascending,
        additionalSorts: const [],
      ),
    );
  }

  /// Replaces every sort level at once (first = primary).
  void setSorts(List<ColumnSort> sorts) => _setSorts(sorts);

  void _setSorts(List<ColumnSort> sorts) {
    if (sorts.isEmpty) {
      _update(_tableState.copyWith(clearSort: true));
      return;
    }
    _update(
      _tableState.copyWith(
        sortByColumnId: sorts.first.columnId,
        sortAscending: sorts.first.ascending,
        additionalSorts: sorts.skip(1).toList(),
      ),
    );
  }

  /// Restores the original item order.
  void clearSort() => _update(_tableState.copyWith(clearSort: true));

  // --- Pagination ---

  /// Updates current pagination page index (clamped to the valid range).
  void setPage(int page) => _update(_tableState.copyWith(currentPage: page));

  /// Goes to the next page if there is one.
  void nextPage() {
    final s = state;
    if (s is TableLoaded<T> && _tableState.currentPage >= s.totalPages) return;
    setPage(_tableState.currentPage + 1);
  }

  /// Goes to the previous page if there is one.
  void previousPage() {
    if (_tableState.currentPage <= 1) return;
    setPage(_tableState.currentPage - 1);
  }

  /// Changes the page slice size (e.g. 10 to 25 items per page).
  /// A value `<= 0` shows every row on one page.
  void setPageSize(int size) {
    _update(_tableState.copyWith(pageSize: size, currentPage: 1));
  }

  // --- Columns ---

  /// Toggles visibility of a specific column.
  ///
  /// The last visible column can't be hidden, and neither can columns with
  /// `isHideable: false`.
  void toggleColumnVisibility(String columnId) {
    setColumnVisibility(columnId, _hidden.contains(columnId));
  }

  /// Shows or hides a column.
  void setColumnVisibility(String columnId, bool visible) {
    final isHidden = _hidden.contains(columnId);
    if (visible == !isHidden) return;
    if (!visible) {
      final col = _column(columnId);
      if (col == null || !col.isHideable) return;
      if (visibleColumns.length <= 1) return;
      _hidden = List.unmodifiable([..._hidden, columnId]);
    } else {
      _hidden = List.unmodifiable(_hidden.where((id) => id != columnId));
    }
    // Hidden columns are excluded from search, so the result may change.
    _recompute();
  }

  /// Sets a column width (e.g. after dragging its header edge). The width
  /// is clamped to the column's `minWidth`.
  void setColumnWidth(String columnId, double width) {
    final w = _clampWidth(columnId, width);
    if (_widths[columnId] == w) return;
    _widths = Map.unmodifiable({..._widths, columnId: w});
    _emitCurrent();
  }

  /// Sets several column widths at once (one state update).
  void setColumnWidths(Map<String, double> widths) {
    _widths = Map.unmodifiable({
      ..._widths,
      for (final e in widths.entries) e.key: _clampWidth(e.key, e.value),
    });
    _emitCurrent();
  }

  double _clampWidth(String columnId, double width) {
    final min = _column(columnId)?.minWidth ?? 0;
    return width < min ? min : width;
  }

  /// Restores the declared width of one column, or of all when [columnId]
  /// is `null`.
  void resetColumnWidths([String? columnId]) {
    if (columnId == null) {
      _widths = const {};
    } else {
      _widths = Map.unmodifiable({..._widths}..remove(columnId));
    }
    _emitCurrent();
  }

  /// Moves [columnId] so that it is displayed right before [beforeColumnId]
  /// (or last when [beforeColumnId] is `null`).
  void moveColumn(String columnId, {String? beforeColumnId}) {
    if (columnId == beforeColumnId) return;
    final ids = _currentOrder()..remove(columnId);
    final index = beforeColumnId == null ? -1 : ids.indexOf(beforeColumnId);
    if (index == -1) {
      ids.add(columnId);
    } else {
      ids.insert(index, columnId);
    }
    setColumnOrder(ids);
  }

  /// Replaces the column display order.
  void setColumnOrder(List<String> columnIds) {
    _order = List.unmodifiable(columnIds);
    _emitCurrent();
  }

  /// Freezes a column at the start / end, or unfreezes it.
  void setColumnPin(String columnId, ColumnPin pin) {
    _pins = Map.unmodifiable({..._pins, columnId: pin});
    _emitCurrent();
  }

  /// Restores declared widths, order and frozen positions.
  void resetColumnLayout() {
    _widths = const {};
    _order = const [];
    _pins = const {};
    _emitCurrent();
  }

  List<String> _currentOrder() {
    final declared = _columns.map((c) => c.id).toList();
    if (_order.isEmpty) return declared;
    return [
      ..._order.where(declared.contains),
      ...declared.where((id) => !_order.contains(id)),
    ];
  }

  ColumnDefinition? _column(String id) =>
      _columns.where((c) => c.id == id).firstOrNull;

  // --- Snapshots ---

  /// Restores a query and column layout saved with [snapshot] (e.g. from a
  /// previous visit). Unknown columns are ignored, and at least one column
  /// stays visible.
  void restoreSnapshot(TableSnapshot snapshot) {
    _collapsed = const {};
    _applySnapshot(snapshot);
    _recompute();
  }

  void _applySnapshot(TableSnapshot s) {
    final ids = {for (final c in _columns) c.id};
    bool known(String? id) => id == null || ids.contains(id);
    final state = s.tableState;
    final sorts = state.sorts.where((x) => known(x.columnId)).toList();
    _tableState = state.copyWith(
      clearSort: sorts.isEmpty,
      sortByColumnId: sorts.firstOrNull?.columnId,
      sortAscending: sorts.firstOrNull?.ascending,
      additionalSorts: sorts.skip(1).toList(),
      columnFilters: {
        for (final e in state.columnFilters.entries)
          if (known(e.key)) e.key: e.value,
      },
      clearGroup: !known(state.groupByColumnId),
    );
    final hidden = [
      for (final id in s.hiddenColumnIds)
        if (_column(id)?.isHideable ?? false) id,
    ];
    if (hidden.toSet().length < ids.length) _hidden = List.unmodifiable(hidden);
    _widths = Map.unmodifiable({
      for (final e in s.columnWidths.entries)
        if (ids.contains(e.key)) e.key: _clampWidth(e.key, e.value),
    });
    _order = List.unmodifiable(s.columnOrder.where(ids.contains));
    _pins = Map.unmodifiable({
      for (final e in s.columnPins.entries)
        if (ids.contains(e.key)) e.key: e.value,
    });
  }

  void _applyColumns(List<ColumnDefinition> columns) {
    final oldIds = _columns.map((c) => c.id).toSet();
    final ids = columns.map((c) => c.id).toSet();
    final removed = oldIds.difference(ids);
    _columns = List.unmodifiable(columns);
    _hidden = List.unmodifiable({
      ..._hidden.where(ids.contains),
      // Newly added columns that start hidden.
      ...columns
          .where((c) => !c.isVisible && !oldIds.contains(c.id))
          .map((c) => c.id),
    });
    if (removed.isEmpty) return;
    // Sorts, filters and grouping of removed columns would otherwise keep
    // acting invisibly.
    final sorts = _tableState.sorts
        .where((s) => !removed.contains(s.columnId))
        .toList();
    _tableState = _tableState.copyWith(
      clearSort: sorts.isEmpty,
      sortByColumnId: sorts.firstOrNull?.columnId,
      sortAscending: sorts.firstOrNull?.ascending,
      additionalSorts: sorts.skip(1).toList(),
      columnFilters: {
        for (final e in _tableState.columnFilters.entries)
          if (!removed.contains(e.key)) e.key: e.value,
      },
      clearGroup: removed.contains(_tableState.groupByColumnId),
    );
    _widths = Map.unmodifiable({
      for (final e in _widths.entries)
        if (!removed.contains(e.key)) e.key: e.value,
    });
    _pins = Map.unmodifiable({
      for (final e in _pins.entries)
        if (!removed.contains(e.key)) e.key: e.value,
    });
  }

  // --- Selection ---

  /// Toggles selected state of a single row.
  void toggleRowSelection(T item) {
    _selected = _toggle(_selected, item);
    _emitCurrent();
  }

  /// Replaces the selection.
  void setSelection(Iterable<T> items) {
    final seen = <Object?>{};
    _selected = List.unmodifiable([
      for (final i in items)
        if (seen.add(keyOf(i))) i,
    ]);
    _emitCurrent();
  }

  /// Selects or deselects all rows currently filtered (across all pages; the
  /// current page in server mode).
  void toggleSelectAll(bool selectAll) {
    final current = state;
    final filtered = current is TableLoaded<T>
        ? current.filteredAndSortedItems
        : _items;
    if (selectAll) {
      final seen = {for (final s in _selected) keyOf(s)};
      _selected = List.unmodifiable([
        ..._selected,
        for (final f in filtered)
          if (seen.add(keyOf(f))) f,
      ]);
    } else {
      final remove = {for (final f in filtered) keyOf(f)};
      _selected = List.unmodifiable(
        _selected.where((e) => !remove.contains(keyOf(e))),
      );
    }
    _emitCurrent();
  }

  /// Clears active row selections.
  void clearSelection() {
    if (_selected.isEmpty) return;
    _selected = const [];
    _emitCurrent();
  }

  // --- Row expansion ---

  /// Opens / closes the `expandedRowBuilder` panel of a row.
  void toggleRowExpansion(T item) {
    _expanded = _toggle(_expanded, item);
    _emitCurrent();
  }

  /// Collapses every expanded row.
  void collapseAll() {
    if (_expanded.isEmpty) return;
    _expanded = const [];
    _emitCurrent();
  }

  // --- Internals ---

  List<T> _toggle(List<T> rows, T item) {
    final key = keyOf(item);
    final index = rows.indexWhere((e) => keyOf(e) == key);
    return List.unmodifiable(
      index == -1 ? [...rows, item] : ([...rows]..removeAt(index)),
    );
  }

  /// Replaces tracked rows (selection, expansion) by their instances in
  /// [source]. Rows missing from [source] are dropped, or kept with
  /// [keepMissing] (server mode: rows on other pages).
  List<T> _refreshRows(
    List<T> tracked,
    List<T> source, {
    bool keepMissing = false,
  }) {
    if (tracked.isEmpty) return tracked;
    final byKey = <Object?, T>{for (final i in source) keyOf(i): i};
    return List.unmodifiable([
      for (final t in tracked)
        if (byKey.containsKey(keyOf(t)))
          byKey[keyOf(t)] as T
        else if (keepMissing)
          t,
    ]);
  }

  static bool _sameFunctions<F>(Map<String, F> a, Map<String, F> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (final e in a.entries) {
      if (!b.containsKey(e.key) || b[e.key] != e.value) return false;
    }
    return true;
  }

  void _update(TableStateModel next) {
    _tableState = next;
    _recompute();
  }

  TableQueryResult<T>? _lastResult;

  /// Totals of [rows], or `null` when an aggregator throws.
  Map<String, Object?>? _safeAggregates(List<T> rows) {
    if (_aggregators.isEmpty) return const {};
    try {
      return Map.unmodifiable({
        for (final e in _aggregators.entries) e.key: e.value(rows),
      });
    } catch (e, st) {
      if (kDebugMode) debugPrint('TableCubit: aggregate failed: $e\n$st');
      return null;
    }
  }

  void _recompute() {
    if (_dataSource != null) {
      unawaited(_fetch());
      return;
    }
    try {
      final result = _filterUseCase.apply<T>(
        items: _items,
        columns: _columns,
        state: _tableState,
        valueProviders: _valueProviders,
        dateProvider: _dateProvider,
        customFilterMatcher: _customFilterMatcher,
        hiddenColumnIds: _hidden.toSet(),
        displayFormatters: _displayFormatters,
      );
      if (result.effectivePage != _tableState.currentPage) {
        _tableState = _tableState.copyWith(currentPage: result.effectivePage);
      }
      _lastResult = result;
      _aggregates = _safeAggregates(result.filteredAndSorted) ?? const {};
      _emitCurrent();
    } catch (e, st) {
      _lastResult = null;
      if (!isClosed) {
        emit(
          TableError<T>(
            'Failed to process table data: $e',
            error: e,
            stackTrace: st,
          ),
        );
      }
      if (kDebugMode) {
        debugPrint('TableCubit: $e\n$st');
      }
    }
  }

  Map<String, Object?>? _serverAggregates;

  Map<String, Object?> _remoteAggregatesOr(List<T> pageItems) {
    final server = _serverAggregates;
    if (server != null) return Map.unmodifiable(server);
    return _safeAggregates(pageItems) ?? const {};
  }

  Future<void> _fetch() async {
    final source = _dataSource;
    if (source == null || isClosed) return;
    final requestId = ++_requestId;
    final query = _tableState;
    _fetching = true;
    _emitRemote();
    try {
      final page = await source.fetch(query);
      if (isClosed || requestId != _requestId) return; // stale response
      _remoteItems = List.unmodifiable(page.items);
      _remoteTotal = page.totalCount < 0 ? 0 : page.totalCount;
      final totalPages = _remoteTotalPages;
      if (query.isPaginated &&
          _remoteTotal > 0 &&
          query.currentPage > totalPages) {
        // The requested page no longer exists (e.g. after a filter).
        _tableState = _tableState.copyWith(currentPage: totalPages);
        unawaited(_fetch());
        return;
      }
      // Selected rows on other pages stay selected; the ones on this page
      // follow their fresh instances.
      _selected = _refreshRows(_selected, _remoteItems, keepMissing: true);
      _expanded = _refreshRows(_expanded, _remoteItems);
      _serverAggregates = page.aggregates;
      _aggregates = _remoteAggregatesOr(_remoteItems);
      _fetching = false;
      _emitRemote();
    } catch (e, st) {
      if (isClosed || requestId != _requestId) return;
      _fetching = false;
      emit(TableError<T>('Failed to load data: $e', error: e, stackTrace: st));
      if (kDebugMode) debugPrint('TableCubit: $e\n$st');
    }
  }

  int get _remoteTotalPages => !_tableState.isPaginated || _remoteTotal == 0
      ? 1
      : (_remoteTotal / _tableState.pageSize).ceil();

  void _emitRemote() {
    if (isClosed) return;
    emit(
      TableLoaded<T>(
        originalItems: _remoteItems,
        filteredAndSortedItems: _remoteItems,
        paginatedItems: _remoteItems,
        totalCount: _remoteTotal,
        totalPages: _remoteTotalPages,
        tableState: _tableState,
        selectedItems: _selected,
        hiddenColumnIds: _hidden,
        expandedItems: _expanded,
        columnWidths: _widths,
        columnOrder: _order,
        columnPins: _pins,
        collapsedGroups: _collapsed,
        isFetching: _fetching,
        aggregates: _aggregates,
        rowKey: _rowKey,
      ),
    );
  }

  void _emitCurrent() {
    if (_dataSource != null) {
      _emitRemote();
      return;
    }
    final result = _lastResult;
    if (result == null || isClosed) return;
    emit(
      TableLoaded<T>(
        originalItems: _items,
        filteredAndSortedItems: result.filteredAndSorted,
        paginatedItems: result.paginated,
        totalCount: result.totalCount,
        totalPages: result.totalPages,
        tableState: _tableState,
        selectedItems: _selected,
        hiddenColumnIds: _hidden,
        expandedItems: _expanded,
        columnWidths: _widths,
        columnOrder: _order,
        columnPins: _pins,
        collapsedGroups: _collapsed,
        aggregates: _aggregates,
        rowKey: _rowKey,
      ),
    );
  }
}
