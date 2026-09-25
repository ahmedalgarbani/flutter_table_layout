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

  /// Number of pages (always at least 1).
  final int totalPages;

  /// Current search, sort, and pagination state.
  final TableStateModel tableState;

  /// Selected items (a subset of [originalItems]).
  final List<T> selectedItems;

  /// IDs of columns hidden by the user.
  final List<String> hiddenColumnIds;

  /// Rows whose details (`expandedRowBuilder`) are currently open.
  final List<T> expandedItems;

  const TableLoaded({
    required this.originalItems,
    required this.filteredAndSortedItems,
    required this.paginatedItems,
    required this.totalCount,
    required this.tableState,
    int? totalPages,
    this.selectedItems = const [],
    this.hiddenColumnIds = const [],
    this.expandedItems = const [],
  }) : totalPages = totalPages ?? 1;

  /// Whether every filtered row is selected.
  bool get isAllSelected =>
      filteredAndSortedItems.isNotEmpty &&
      filteredAndSortedItems.every(selectedItems.toSet().contains);

  /// `true` = all filtered rows selected, `false` = none, `null` = some.
  bool? get selectAllValue {
    if (selectedItems.isEmpty) return false;
    final selected = selectedItems.toSet();
    final count = filteredAndSortedItems.where(selected.contains).length;
    if (count == 0) return false;
    if (count == filteredAndSortedItems.length) return true;
    return null;
  }

  /// Copy helper to transition states.
  TableLoaded<T> copyWith({
    List<T>? originalItems,
    List<T>? filteredAndSortedItems,
    List<T>? paginatedItems,
    int? totalCount,
    int? totalPages,
    TableStateModel? tableState,
    List<T>? selectedItems,
    List<String>? hiddenColumnIds,
    List<T>? expandedItems,
  }) {
    return TableLoaded<T>(
      originalItems: originalItems ?? this.originalItems,
      filteredAndSortedItems:
          filteredAndSortedItems ?? this.filteredAndSortedItems,
      paginatedItems: paginatedItems ?? this.paginatedItems,
      totalCount: totalCount ?? this.totalCount,
      totalPages: totalPages ?? this.totalPages,
      tableState: tableState ?? this.tableState,
      selectedItems: selectedItems ?? this.selectedItems,
      hiddenColumnIds: hiddenColumnIds ?? this.hiddenColumnIds,
      expandedItems: expandedItems ?? this.expandedItems,
    );
  }
}

/// State representation when an operation throws an exception
/// (e.g. a `valueProvider` or `customFilterMatcher` threw).
class TableError<T> extends TableCubitState<T> {
  final String errorMessage;
  final Object? error;
  final StackTrace? stackTrace;

  const TableError(this.errorMessage, {this.error, this.stackTrace});
}
