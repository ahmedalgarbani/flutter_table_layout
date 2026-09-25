import 'dart:collection';

/// Represents the filtering, sorting, and pagination configuration.
/// Used in the domain layer to compute item operations.
class TableStateModel {
  /// Global search phrase.
  final String searchQuery;

  /// Unique ID of the column active in sorting, or `null` for the original order.
  final String? sortByColumnId;

  /// Whether active sorting is ascending.
  final bool sortAscending;

  /// Active page index (1-indexed).
  final int currentPage;

  /// Maximum rows allowed per page. A value `<= 0` disables pagination and
  /// returns every filtered row on a single page.
  final int pageSize;

  /// From boundary date (inclusive, compared by calendar day).
  final DateTime? startDate;

  /// To boundary date (inclusive, compared by calendar day).
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

  /// Whether pagination is active.
  bool get isPaginated => pageSize > 0;

  /// Whether any search, date, or custom filter is currently applied.
  bool get hasActiveFilters =>
      searchQuery.trim().isNotEmpty ||
      startDate != null ||
      endDate != null ||
      customFilters.isNotEmpty;

  /// Copy helper.
  ///
  /// Nullable fields cannot be reset by passing `null`, so use the `clear*`
  /// flags (e.g. `clearStartDate: true`) to remove a value.
  TableStateModel copyWith({
    String? searchQuery,
    String? sortByColumnId,
    bool clearSort = false,
    bool? sortAscending,
    int? currentPage,
    int? pageSize,
    DateTime? startDate,
    bool clearStartDate = false,
    DateTime? endDate,
    bool clearEndDate = false,
    Map<String, dynamic>? customFilters,
  }) {
    return TableStateModel(
      searchQuery: searchQuery ?? this.searchQuery,
      sortByColumnId: clearSort
          ? null
          : (sortByColumnId ?? this.sortByColumnId),
      sortAscending: sortAscending ?? this.sortAscending,
      currentPage: currentPage ?? this.currentPage,
      pageSize: pageSize ?? this.pageSize,
      startDate: clearStartDate ? null : (startDate ?? this.startDate),
      endDate: clearEndDate ? null : (endDate ?? this.endDate),
      customFilters: customFilters != null
          ? UnmodifiableMapView(Map<String, dynamic>.of(customFilters))
          : this.customFilters,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! TableStateModel) return false;
    if (other.customFilters.length != customFilters.length) return false;
    for (final entry in customFilters.entries) {
      if (!other.customFilters.containsKey(entry.key) ||
          other.customFilters[entry.key] != entry.value) {
        return false;
      }
    }
    return other.searchQuery == searchQuery &&
        other.sortByColumnId == sortByColumnId &&
        other.sortAscending == sortAscending &&
        other.currentPage == currentPage &&
        other.pageSize == pageSize &&
        other.startDate == startDate &&
        other.endDate == endDate;
  }

  @override
  int get hashCode => Object.hash(
    searchQuery,
    sortByColumnId,
    sortAscending,
    currentPage,
    pageSize,
    startDate,
    endDate,
    Object.hashAllUnordered(
      customFilters.entries.map((e) => Object.hash(e.key, e.value)),
    ),
  );

  @override
  String toString() =>
      'TableStateModel(search: "$searchQuery", sort: $sortByColumnId '
      '${sortAscending ? 'asc' : 'desc'}, page: $currentPage/$pageSize, '
      'dates: $startDate → $endDate, custom: $customFilters)';
}
