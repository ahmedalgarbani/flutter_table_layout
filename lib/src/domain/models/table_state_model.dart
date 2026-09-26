import 'dart:collection';

/// One level of a (multi-column) sort.
class ColumnSort {
  final String columnId;
  final bool ascending;

  const ColumnSort(this.columnId, {this.ascending = true});

  ColumnSort toggled() => ColumnSort(columnId, ascending: !ascending);

  @override
  bool operator ==(Object other) =>
      other is ColumnSort &&
      other.columnId == columnId &&
      other.ascending == ascending;

  @override
  int get hashCode => Object.hash(columnId, ascending);

  @override
  String toString() => '$columnId ${ascending ? 'asc' : 'desc'}';
}

/// Represents the filtering, sorting, grouping and pagination configuration.
/// Used in the domain layer to compute item operations, and sent as-is to a
/// server-side `AdaptiveTableDataSource`.
class TableStateModel {
  /// Global search phrase.
  final String searchQuery;

  /// Unique ID of the column active in sorting, or `null` for the original order.
  final String? sortByColumnId;

  /// Whether active sorting is ascending.
  final bool sortAscending;

  /// Secondary sort levels applied after [sortByColumnId] (Shift + click).
  final List<ColumnSort> additionalSorts;

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

  /// Per-column filter expressions (column id → text), e.g. `acme`, `>100`,
  /// `10..20`, `=2026-01-05`, `!=open`. See `ColumnFilterMatcher`.
  final Map<String, String> columnFilters;

  /// Rows are grouped by this column's value (`null` = no grouping).
  final String? groupByColumnId;

  const TableStateModel({
    this.searchQuery = '',
    this.sortByColumnId,
    this.sortAscending = true,
    this.additionalSorts = const [],
    this.currentPage = 1,
    this.pageSize = 10,
    this.startDate,
    this.endDate,
    this.customFilters = const {},
    this.columnFilters = const {},
    this.groupByColumnId,
  });

  /// Whether pagination is active.
  bool get isPaginated => pageSize > 0;

  /// Every sort level in priority order (primary first).
  List<ColumnSort> get sorts => [
    if (sortByColumnId != null)
      ColumnSort(sortByColumnId!, ascending: sortAscending),
    ...additionalSorts.where((s) => s.columnId != sortByColumnId),
  ];

  /// Whether any search, date, column or custom filter is currently applied.
  bool get hasActiveFilters =>
      searchQuery.trim().isNotEmpty ||
      startDate != null ||
      endDate != null ||
      customFilters.isNotEmpty ||
      columnFilters.values.any((v) => v.trim().isNotEmpty);

  /// Copy helper.
  ///
  /// Nullable fields cannot be reset by passing `null`, so use the `clear*`
  /// flags (e.g. `clearStartDate: true`) to remove a value.
  TableStateModel copyWith({
    String? searchQuery,
    String? sortByColumnId,
    bool clearSort = false,
    bool? sortAscending,
    List<ColumnSort>? additionalSorts,
    int? currentPage,
    int? pageSize,
    DateTime? startDate,
    bool clearStartDate = false,
    DateTime? endDate,
    bool clearEndDate = false,
    Map<String, dynamic>? customFilters,
    Map<String, String>? columnFilters,
    String? groupByColumnId,
    bool clearGroup = false,
  }) {
    return TableStateModel(
      searchQuery: searchQuery ?? this.searchQuery,
      sortByColumnId: clearSort
          ? null
          : (sortByColumnId ?? this.sortByColumnId),
      sortAscending: sortAscending ?? this.sortAscending,
      additionalSorts: clearSort
          ? const []
          : (additionalSorts != null
                ? List.unmodifiable(additionalSorts)
                : this.additionalSorts),
      currentPage: currentPage ?? this.currentPage,
      pageSize: pageSize ?? this.pageSize,
      startDate: clearStartDate ? null : (startDate ?? this.startDate),
      endDate: clearEndDate ? null : (endDate ?? this.endDate),
      customFilters: customFilters != null
          ? UnmodifiableMapView(Map<String, dynamic>.of(customFilters))
          : this.customFilters,
      columnFilters: columnFilters != null
          ? UnmodifiableMapView(Map<String, String>.of(columnFilters))
          : this.columnFilters,
      groupByColumnId: clearGroup
          ? null
          : (groupByColumnId ?? this.groupByColumnId),
    );
  }

  static bool _mapEquals<V>(Map<String, V> a, Map<String, V> b) {
    if (a.length != b.length) return false;
    for (final entry in a.entries) {
      if (!b.containsKey(entry.key) || b[entry.key] != entry.value) {
        return false;
      }
    }
    return true;
  }

  static bool _listEquals<V>(List<V> a, List<V> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! TableStateModel) return false;
    return _mapEquals(other.customFilters, customFilters) &&
        _mapEquals(other.columnFilters, columnFilters) &&
        _listEquals(other.additionalSorts, additionalSorts) &&
        other.searchQuery == searchQuery &&
        other.sortByColumnId == sortByColumnId &&
        other.sortAscending == sortAscending &&
        other.currentPage == currentPage &&
        other.pageSize == pageSize &&
        other.startDate == startDate &&
        other.endDate == endDate &&
        other.groupByColumnId == groupByColumnId;
  }

  @override
  int get hashCode => Object.hash(
    searchQuery,
    sortByColumnId,
    sortAscending,
    Object.hashAll(additionalSorts),
    currentPage,
    pageSize,
    startDate,
    endDate,
    Object.hashAllUnordered(
      customFilters.entries.map((e) => Object.hash(e.key, e.value)),
    ),
    Object.hashAllUnordered(
      columnFilters.entries.map((e) => Object.hash(e.key, e.value)),
    ),
    groupByColumnId,
  );

  @override
  String toString() =>
      'TableStateModel(search: "$searchQuery", sorts: $sorts, '
      'page: $currentPage/$pageSize, dates: $startDate → $endDate, '
      'custom: $customFilters, columns: $columnFilters, '
      'group: $groupByColumnId)';
}
