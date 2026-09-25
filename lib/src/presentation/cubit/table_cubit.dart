import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/models/column_definition.dart';
import '../../domain/models/table_state_model.dart';
import '../../domain/usecases/filter_items_usecase.dart';
import 'table_cubit_state.dart';

/// Cubit responsible for managing the logical state, column visibility,
/// search queries, date limits, and pagination slicing of the table.
///
/// It keeps its own copy of the items, query state, selection and hidden
/// columns, so it never mutates the lists you pass in, and a failing
/// `valueProvider` emits [TableError] without losing the last good state.
class TableCubit<T> extends Cubit<TableCubitState<T>> {
  List<ColumnDefinition> _columns;
  Map<String, dynamic Function(T)> _valueProviders;
  DateTime? Function(T)? _dateProvider;
  bool Function(T, Map<String, dynamic>)? _customFilterMatcher;
  final FilterItemsUseCase _filterUseCase;
  final TableStateModel _initialTableState;

  List<T> _items = const [];
  TableStateModel _tableState;
  List<T> _selected = const [];
  List<String> _hidden;
  List<T> _expanded = const [];

  TableCubit({
    required List<T> items,
    required List<ColumnDefinition> columns,
    required Map<String, dynamic Function(T)> valueProviders,
    DateTime? Function(T)? dateProvider,
    bool Function(T, Map<String, dynamic>)? customFilterMatcher,
    FilterItemsUseCase filterUseCase = const FilterItemsUseCase(),
    TableStateModel initialTableState = const TableStateModel(),
  }) : _columns = List.unmodifiable(columns),
       _valueProviders = Map.unmodifiable(valueProviders),
       _dateProvider = dateProvider,
       _customFilterMatcher = customFilterMatcher,
       _filterUseCase = filterUseCase,
       _initialTableState = initialTableState,
       _tableState = initialTableState,
       _hidden = List.unmodifiable(
         columns.where((c) => !c.isVisible).map((c) => c.id),
       ),
       super(const TableLoading()) {
    setItems(items, initialTableState);
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

  // --- Data & configuration ---

  /// Sets or updates the raw dataset items and recalculates output.
  ///
  /// Selected / expanded items that no longer exist are dropped, and the
  /// current page is clamped to the new page count.
  void setItems(List<T> items, [TableStateModel? stateOverride]) {
    _items = List.unmodifiable(items);
    if (stateOverride != null) _tableState = stateOverride;
    if (_selected.isNotEmpty || _expanded.isNotEmpty) {
      final present = _items.toSet();
      _selected = List.unmodifiable(_selected.where(present.contains));
      _expanded = List.unmodifiable(_expanded.where(present.contains));
    }
    _recompute();
  }

  /// Replaces columns / providers / matchers / items (e.g. after a locale
  /// change) with a single recomputation.
  void updateConfiguration({
    List<T>? items,
    List<ColumnDefinition>? columns,
    Map<String, dynamic Function(T)>? valueProviders,
    DateTime? Function(T)? dateProvider,
    bool clearDateProvider = false,
    bool Function(T, Map<String, dynamic>)? customFilterMatcher,
    bool clearCustomFilterMatcher = false,
  }) {
    if (columns != null) {
      final oldIds = _columns.map((c) => c.id).toSet();
      final ids = columns.map((c) => c.id).toSet();
      _columns = List.unmodifiable(columns);
      _hidden = List.unmodifiable({
        ..._hidden.where(ids.contains),
        // Newly added columns that start hidden.
        ...columns
            .where((c) => !c.isVisible && !oldIds.contains(c.id))
            .map((c) => c.id),
      });
      if (_tableState.sortByColumnId != null &&
          !ids.contains(_tableState.sortByColumnId)) {
        _tableState = _tableState.copyWith(clearSort: true);
      }
    }
    if (valueProviders != null) {
      _valueProviders = Map.unmodifiable(valueProviders);
    }
    if (dateProvider != null || clearDateProvider) {
      _dateProvider = dateProvider;
    }
    if (customFilterMatcher != null || clearCustomFilterMatcher) {
      _customFilterMatcher = customFilterMatcher;
    }
    if (items != null) {
      setItems(items);
    } else {
      _recompute();
    }
  }

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
        currentPage: 1,
      ),
    );
  }

  /// Restores the initial state passed to the constructor (filters, sort,
  /// page size) and clears the selection.
  void resetAll() {
    _selected = const [];
    _expanded = const [];
    _update(_initialTableState);
  }

  // --- Sorting ---

  /// Sorts by the specified column, or toggles ascending/descending.
  void toggleSort(String columnId) {
    final isSameCol = _tableState.sortByColumnId == columnId;
    sortBy(columnId, ascending: isSameCol ? !_tableState.sortAscending : true);
  }

  /// Sorts by [columnId] in the given direction.
  void sortBy(String columnId, {bool ascending = true}) {
    _update(
      _tableState.copyWith(sortByColumnId: columnId, sortAscending: ascending),
    );
  }

  /// Restores the original item order.
  void clearSort() => _update(_tableState.copyWith(clearSort: true));

  // --- Pagination ---

  /// Updates current pagination page index (clamped to the valid range).
  void setPage(int page) => _update(_tableState.copyWith(currentPage: page));

  /// Goes to the next page if there is one.
  void nextPage() => setPage(_tableState.currentPage + 1);

  /// Goes to the previous page if there is one.
  void previousPage() => setPage(_tableState.currentPage - 1);

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
      final col = _columns.where((c) => c.id == columnId).firstOrNull;
      if (col == null || !col.isHideable) return;
      if (visibleColumns.length <= 1) return;
      _hidden = List.unmodifiable([..._hidden, columnId]);
    } else {
      _hidden = List.unmodifiable(_hidden.where((id) => id != columnId));
    }
    // Hidden columns are excluded from search, so the result may change.
    _recompute();
  }

  // --- Selection ---

  /// Toggles selected state of a single row.
  void toggleRowSelection(T item) {
    if (_selected.contains(item)) {
      _selected = List.unmodifiable(_selected.where((e) => e != item));
    } else {
      _selected = List.unmodifiable([..._selected, item]);
    }
    _emitCurrent();
  }

  /// Replaces the selection.
  void setSelection(Iterable<T> items) {
    _selected = List.unmodifiable(items.toSet());
    _emitCurrent();
  }

  /// Selects or deselects all rows currently filtered (across all pages).
  void toggleSelectAll(bool selectAll) {
    final current = state;
    final filtered = current is TableLoaded<T>
        ? current.filteredAndSortedItems
        : _items;
    if (selectAll) {
      _selected = List.unmodifiable({..._selected, ...filtered});
    } else {
      final remove = filtered.toSet();
      _selected = List.unmodifiable(
        _selected.where((e) => !remove.contains(e)),
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
    if (_expanded.contains(item)) {
      _expanded = List.unmodifiable(_expanded.where((e) => e != item));
    } else {
      _expanded = List.unmodifiable([..._expanded, item]);
    }
    _emitCurrent();
  }

  /// Collapses every expanded row.
  void collapseAll() {
    if (_expanded.isEmpty) return;
    _expanded = const [];
    _emitCurrent();
  }

  // --- Internals ---

  void _update(TableStateModel next) {
    _tableState = next;
    _recompute();
  }

  TableQueryResult<T>? _lastResult;

  void _recompute() {
    try {
      final result = _filterUseCase.apply<T>(
        items: _items,
        columns: _columns,
        state: _tableState,
        valueProviders: _valueProviders,
        dateProvider: _dateProvider,
        customFilterMatcher: _customFilterMatcher,
        hiddenColumnIds: _hidden.toSet(),
      );
      if (result.effectivePage != _tableState.currentPage) {
        _tableState = _tableState.copyWith(currentPage: result.effectivePage);
      }
      _lastResult = result;
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

  void _emitCurrent() {
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
      ),
    );
  }
}
