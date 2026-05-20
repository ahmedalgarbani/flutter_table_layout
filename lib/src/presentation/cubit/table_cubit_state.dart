import '../../domain/models/table_state_model.dart';

/// Sealed class representing the reactive state of the table layout.
/// Designed according to Dart 3 specifications (exhaustiveness, no code generation).
sealed class TableCubitState<T> {
  const TableCubitState();
}

/// The initial state before items are set.
class TableInitial<T> extends TableCubitState<T> {
  const TableInitial();
}

/// The processing state, e.g. when filtering or sorting large datasets.
class TableLoading<T> extends TableCubitState<T> {
  const TableLoading();
}

/// The active state containing data, pagination slices, and selection models.
class TableLoaded<T> extends TableCubitState<T> {
  /// The full list of source items.
  final List<T> originalItems;

  /// The items after applying search, dates, and custom filters.
  final List<T> filteredAndSortedItems;

  /// The subset of items for the active page.
  final List<T> paginatedItems;

  /// Total item count post-filtering (used to calculate pages).
  final int totalCount;

  /// Current search, sort, and pagination state.
  final TableStateModel tableState;

  /// IDs/Indices of selected items.
  final List<T> selectedItems;

  /// IDs of columns hidden by the user.
  final List<String> hiddenColumnIds;

  const TableLoaded({
    required this.originalItems,
    required this.filteredAndSortedItems,
    required this.paginatedItems,
    required this.totalCount,
    required this.tableState,
    this.selectedItems = const [],
    this.hiddenColumnIds = const [],
  });

  /// Copy helper to transition states.
  TableLoaded<T> copyWith({
    List<T>? originalItems,
    List<T>? filteredAndSortedItems,
    List<T>? paginatedItems,
    int? totalCount,
    TableStateModel? tableState,
    List<T>? selectedItems,
    List<String>? hiddenColumnIds,
  }) {
    return TableLoaded<T>(
      originalItems: originalItems ?? this.originalItems,
      filteredAndSortedItems:
          filteredAndSortedItems ?? this.filteredAndSortedItems,
      paginatedItems: paginatedItems ?? this.paginatedItems,
      totalCount: totalCount ?? this.totalCount,
      tableState: tableState ?? this.tableState,
      selectedItems: selectedItems ?? this.selectedItems,
      hiddenColumnIds: hiddenColumnIds ?? this.hiddenColumnIds,
    );
  }
}

/// State representation when an operation throws an exception.
class TableError<T> extends TableCubitState<T> {
  final String errorMessage;
  const TableError(this.errorMessage);
}
