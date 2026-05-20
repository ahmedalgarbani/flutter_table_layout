import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/models/column_definition.dart';
import '../../domain/models/table_state_model.dart';
import '../../domain/usecases/filter_items_usecase.dart';
import 'table_cubit_state.dart';

/// Cubit responsible for managing the logical state, column visibility,
/// search queries, date limits, and pagination slicing of the table.
class TableCubit<T> extends Cubit<TableCubitState<T>> {
  final List<ColumnDefinition> _columns;
  final Map<String, dynamic Function(T)> _valueProviders;
  final DateTime? Function(T)? _dateProvider;
  final bool Function(T, Map<String, dynamic>)? _customFilterMatcher;
  final FilterItemsUseCase _filterUseCase;

  TableCubit({
    required List<T> items,
    required List<ColumnDefinition> columns,
    required Map<String, dynamic Function(T)> valueProviders,
    DateTime? Function(T)? dateProvider,
    bool Function(T, Map<String, dynamic>)? customFilterMatcher,
    FilterItemsUseCase filterUseCase = const FilterItemsUseCase(),
    TableStateModel initialTableState = const TableStateModel(),
  }) : _columns = columns,
       _valueProviders = valueProviders,
       _dateProvider = dateProvider,
       _customFilterMatcher = customFilterMatcher,
       _filterUseCase = filterUseCase,
       super(const TableLoading()) {
    setItems(items, initialTableState);
  }

  /// Sets or updates the raw dataset items and recalculates output.
  void setItems(List<T> items, [TableStateModel? stateOverride]) {
    final currentState = stateOverride ?? _getCurrentTableState();
    final (filtered, paginated, total) = _filterUseCase.run(
      items: items,
      columns: _columns,
      state: currentState,
      dateProvider: _dateProvider,
      customFilterMatcher: _customFilterMatcher,
      valueProviders: _valueProviders,
    );

    emit(
      TableLoaded<T>(
        originalItems: items,
        filteredAndSortedItems: filtered,
        paginatedItems: paginated,
        totalCount: total,
        tableState: currentState,
        selectedItems: _getCurrentSelectedItems(),
        hiddenColumnIds: _getCurrentHiddenColumns(),
      ),
    );
  }

  /// Updates global search query and resets pagination to page 1.
  void updateSearchQuery(String query) {
    final state = this.state;
    if (state is TableLoaded<T>) {
      final newState = state.tableState.copyWith(
        searchQuery: query,
        currentPage: 1,
      );
      _recalculate(state.originalItems, newState);
    }
  }

  /// Updates date range boundaries and resets pagination to page 1.
  void updateDateRange(DateTime? start, DateTime? end) {
    final state = this.state;
    if (state is TableLoaded<T>) {
      final newState = state.tableState.copyWith(
        startDate: start,
        endDate: end,
        currentPage: 1,
      );
      _recalculate(state.originalItems, newState);
    }
  }

  /// Updates custom filter map values and resets pagination to page 1.
  void updateCustomFilters(Map<String, dynamic> customFilters) {
    final state = this.state;
    if (state is TableLoaded<T>) {
      final newState = state.tableState.copyWith(
        customFilters: customFilters,
        currentPage: 1,
      );
      _recalculate(state.originalItems, newState);
    }
  }

  /// Sorts by the specified column, or toggles ascending/descending.
  void toggleSort(String columnId) {
    final state = this.state;
    if (state is TableLoaded<T>) {
      final isSameCol = state.tableState.sortByColumnId == columnId;
      final newState = state.tableState.copyWith(
        sortByColumnId: columnId,
        sortAscending: isSameCol ? !state.tableState.sortAscending : true,
      );
      _recalculate(state.originalItems, newState);
    }
  }

  /// Updates current pagination page index.
  void setPage(int page) {
    final state = this.state;
    if (state is TableLoaded<T>) {
      final newState = state.tableState.copyWith(currentPage: page);
      _recalculate(state.originalItems, newState);
    }
  }

  /// Changes the page slice size (e.g. 10 to 25 items per page).
  void setPageSize(int size) {
    final state = this.state;
    if (state is TableLoaded<T>) {
      final newState = state.tableState.copyWith(
        pageSize: size,
        currentPage: 1,
      );
      _recalculate(state.originalItems, newState);
    }
  }

  /// Toggles visibility of a specific column.
  void toggleColumnVisibility(String columnId) {
    final state = this.state;
    if (state is TableLoaded<T>) {
      final updatedHidden = List<String>.from(state.hiddenColumnIds);
      if (updatedHidden.contains(columnId)) {
        updatedHidden.remove(columnId);
      } else {
        updatedHidden.add(columnId);
      }

      // Re-map column visibility definitions
      for (int i = 0; i < _columns.length; i++) {
        if (_columns[i].id == columnId) {
          _columns[i] = _columns[i].copyWith(
            isVisible: !updatedHidden.contains(columnId),
          );
        }
      }

      // Re-trigger calculation to filter out columns if global search counts them
      final (filtered, paginated, total) = _filterUseCase.run(
        items: state.originalItems,
        columns: _columns,
        state: state.tableState,
        dateProvider: _dateProvider,
        customFilterMatcher: _customFilterMatcher,
        valueProviders: _valueProviders,
      );

      emit(
        state.copyWith(
          hiddenColumnIds: updatedHidden,
          filteredAndSortedItems: filtered,
          paginatedItems: paginated,
          totalCount: total,
        ),
      );
    }
  }

  /// Toggles selected state of a single row.
  void toggleRowSelection(T item) {
    final state = this.state;
    if (state is TableLoaded<T>) {
      final selected = List<T>.from(state.selectedItems);
      if (selected.contains(item)) {
        selected.remove(item);
      } else {
        selected.add(item);
      }
      emit(state.copyWith(selectedItems: selected));
    }
  }

  /// Selects or deselects all rows currently filtered and visible.
  void toggleSelectAll(bool selectAll) {
    final state = this.state;
    if (state is TableLoaded<T>) {
      if (selectAll) {
        emit(
          state.copyWith(
            selectedItems: List<T>.from(state.filteredAndSortedItems),
          ),
        );
      } else {
        emit(state.copyWith(selectedItems: const []));
      }
    }
  }

  /// Clears active row selections.
  void clearSelection() {
    final state = this.state;
    if (state is TableLoaded<T>) {
      emit(state.copyWith(selectedItems: const []));
    }
  }

  // --- Helpers ---

  void _recalculate(List<T> originalItems, TableStateModel nextTableState) {
    final (filtered, paginated, total) = _filterUseCase.run(
      items: originalItems,
      columns: _columns,
      state: nextTableState,
      dateProvider: _dateProvider,
      customFilterMatcher: _customFilterMatcher,
      valueProviders: _valueProviders,
    );

    final state = this.state;
    if (state is TableLoaded<T>) {
      emit(
        state.copyWith(
          filteredAndSortedItems: filtered,
          paginatedItems: paginated,
          totalCount: total,
          tableState: nextTableState,
        ),
      );
    }
  }

  TableStateModel _getCurrentTableState() {
    final state = this.state;
    if (state is TableLoaded<T>) {
      return state.tableState;
    }
    return const TableStateModel();
  }

  List<T> _getCurrentSelectedItems() {
    final state = this.state;
    if (state is TableLoaded<T>) {
      return state.selectedItems;
    }
    return const [];
  }

  List<String> _getCurrentHiddenColumns() {
    final state = this.state;
    if (state is TableLoaded<T>) {
      return state.hiddenColumnIds;
    }
    return const [];
  }
}
