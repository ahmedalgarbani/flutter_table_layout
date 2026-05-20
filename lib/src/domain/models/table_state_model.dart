/// Represents the filtering, sorting, and pagination configuration.
/// Used in the domain layer to compute item operations.
class TableStateModel {
  /// Global search phrase.
  final String searchQuery;

  /// Unique ID of the column active in sorting.
  final String? sortByColumnId;

  /// Whether active sorting is ascending.
  final bool sortAscending;

  /// Active page index (1-indexed).
  final int currentPage;

  /// Maximum rows allowed per page.
  final int pageSize;

  /// From boundary date.
  final DateTime? startDate;

  /// To boundary date.
  final DateTime? endDate;

  /// Custom filters defined by consumer.
  final Map<String, dynamic> customFilters;

  const TableStateModel({
    this.searchQuery = '',
    this.sortByColumnId,
    this.sortAscending = true,
    this.currentPage = 1,
    this.pageSize = 10,
    this.startDate,
    this.endDate,
    this.customFilters = const {},
  });

  /// Copy helper.
  TableStateModel copyWith({
    String? searchQuery,
    String? sortByColumnId,
    bool? sortAscending,
    int? currentPage,
    int? pageSize,
    DateTime? startDate,
    DateTime? endDate,
    Map<String, dynamic>? customFilters,
  }) {
    return TableStateModel(
      searchQuery: searchQuery ?? this.searchQuery,
      sortByColumnId: sortByColumnId ?? this.sortByColumnId,
      sortAscending: sortAscending ?? this.sortAscending,
      currentPage: currentPage ?? this.currentPage,
      pageSize: pageSize ?? this.pageSize,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      customFilters: customFilters ?? this.customFilters,
    );
  }
}
