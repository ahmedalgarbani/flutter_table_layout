import '../models/column_definition.dart';
import '../models/column_filter.dart';
import '../models/table_state_model.dart';
import '../utils/table_text_normalizer.dart';

/// Converts a raw cell value into the text displayed in the table.
typedef DisplayFormatter = String Function(dynamic value);

/// The full output of a [FilterItemsUseCase] pass.
class TableQueryResult<T> {
  /// Every item that survived the date / custom / search filters, sorted.
  final List<T> filteredAndSorted;

  /// The slice of [filteredAndSorted] for [effectivePage].
  final List<T> paginated;

  /// `filteredAndSorted.length`.
  final int totalCount;

  /// Number of pages (at least 1, even when there are no rows).
  final int totalPages;

  /// The requested page clamped into `1..totalPages`.
  final int effectivePage;

  const TableQueryResult({
    required this.filteredAndSorted,
    required this.paginated,
    required this.totalCount,
    required this.totalPages,
    required this.effectivePage,
  });
}

/// Pure Dart usecase to filter, search, sort, and paginate generic data lists.
/// Conforms to domain purity constraints (zero Flutter imports).
///
/// The pipeline runs in this order:
/// 1. date range (via `dateProvider`, compared by calendar day, both ends inclusive)
/// 2. custom filters (via `customFilterMatcher`)
/// 3. per-column filters (`TableStateModel.columnFilters`)
/// 4. global search (over visible + searchable columns, raw and displayed text)
/// 5. stable multi-level sort (group column first when grouping; nulls last)
/// 6. pagination (the requested page is clamped to the last available page)
///
/// Text is compared through [textNormalizer]: by default case-insensitive and
/// tolerant of Arabic spelling variants (see [TableTextNormalizer.normalize]).
class FilterItemsUseCase {
  /// Applied to cell text and to what the user typed before they are compared
  /// (search, column filters, and the order of text values when sorting).
  final TextNormalizer textNormalizer;

  const FilterItemsUseCase({
    this.textNormalizer = TableTextNormalizer.normalize,
  });

  /// Runs the whole pipeline and returns a detailed [TableQueryResult].
  ///
  /// [displayFormatters] (column id → formatter) let the search and the
  /// column filters also match the text shown in the cells, e.g. `1,500.00`
  /// for a raw `1500` or `05/01/2026` for a date.
  TableQueryResult<T> apply<T>({
    required List<T> items,
    required List<ColumnDefinition> columns,
    required TableStateModel state,
    Map<String, dynamic Function(T)>? valueProviders,
    DateTime? Function(T item)? dateProvider,
    bool Function(T item, Map<String, dynamic> filters)? customFilterMatcher,
    Set<String> hiddenColumnIds = const {},
    Map<String, DisplayFormatter>? displayFormatters,
  }) {
    Iterable<T> result = items;

    // 1. Date range
    if (dateProvider != null &&
        (state.startDate != null || state.endDate != null)) {
      final startDay = state.startDate == null
          ? null
          : _dayOf(state.startDate!);
      final endDay = state.endDate == null ? null : _dayOf(state.endDate!);
      result = result.where((item) {
        final itemDate = dateProvider(item);
        if (itemDate == null) return false;
        final itemDay = _dayOf(itemDate);
        if (startDay != null && itemDay.isBefore(startDay)) return false;
        if (endDay != null && itemDay.isAfter(endDay)) return false;
        return true;
      });
    }

    // 2. Custom filters
    if (customFilterMatcher != null && state.customFilters.isNotEmpty) {
      result = result.where(
        (item) => customFilterMatcher(item, state.customFilters),
      );
    }

    // 3. Per-column filters (each expression is parsed once).
    final columnFilters = [
      for (final e in state.columnFilters.entries)
        if (e.value.trim().isNotEmpty && valueProviders?[e.key] != null)
          (
            valueProviders![e.key]!,
            ColumnFilterMatcher.parse(e.value, normalize: textNormalizer),
            displayFormatters?[e.key],
          ),
    ];
    if (columnFilters.isNotEmpty) {
      result = result.where((item) {
        for (final (provider, matcher, formatter) in columnFilters) {
          final value = provider(item) as Object?;
          final display = formatter == null
              ? null
              : () => _safeFormat(formatter, value);
          if (!matcher.test(value, display)) return false;
        }
        return true;
      });
    }

    // 4. Global search
    final query = textNormalizer(state.searchQuery.trim());
    if (query.isNotEmpty) {
      final extractors = _searchExtractors(
        columns,
        valueProviders,
        hiddenColumnIds,
        displayFormatters,
      );
      result = result.where(
        (item) => _matchesQuery(item, query, extractors, valueProviders),
      );
    }

    final filtered = result.toList();

    // 5. Sorting (stable: equal values keep their original relative order).
    // When grouping, the group column is the first sort level so that each
    // group is contiguous.
    final levels = <ColumnSort>[
      if (state.groupByColumnId != null &&
          !state.sorts.any((s) => s.columnId == state.groupByColumnId))
        ColumnSort(state.groupByColumnId!),
      ...state.sorts,
    ];
    final extractors = <(dynamic Function(T), bool)>[
      for (final level in levels)
        if (valueProviders?[level.columnId] != null)
          (valueProviders![level.columnId]!, level.ascending),
    ];
    if (extractors.isNotEmpty) {
      // Text is compared in its normalized form, so `أحمد` and `احمد` sort
      // together, consistently with the search.
      Object? sortKey(Object? v) => v is String ? textNormalizer(v) : v;
      final indexed = List<(int, T, List<Object?>)>.generate(
        filtered.length,
        (i) => (
          i,
          filtered[i],
          [for (final e in extractors) sortKey(e.$1(filtered[i]) as Object?)],
        ),
      );
      indexed.sort((a, b) {
        for (var l = 0; l < extractors.length; l++) {
          final cmp = compareCellValues(
            a.$3[l],
            b.$3[l],
            ascending: extractors[l].$2,
          );
          if (cmp != 0) return cmp;
        }
        return a.$1.compareTo(b.$1);
      });
      for (var i = 0; i < indexed.length; i++) {
        filtered[i] = indexed[i].$2;
      }
    }

    // 6. Pagination
    final totalCount = filtered.length;
    if (!state.isPaginated) {
      return TableQueryResult<T>(
        filteredAndSorted: filtered,
        paginated: List<T>.of(filtered),
        totalCount: totalCount,
        totalPages: 1,
        effectivePage: 1,
      );
    }

    final totalPages = totalCount == 0
        ? 1
        : (totalCount / state.pageSize).ceil();
    final page = state.currentPage.clamp(1, totalPages);
    final start = (page - 1) * state.pageSize;
    final end = (start + state.pageSize).clamp(0, totalCount);
    return TableQueryResult<T>(
      filteredAndSorted: filtered,
      paginated: start < totalCount ? filtered.sublist(start, end) : <T>[],
      totalCount: totalCount,
      totalPages: totalPages,
      effectivePage: page,
    );
  }

  /// Filters, searches, sorts, and slices the dataset.
  ///
  /// Returns a record: `(filteredAndSortedItems, paginatedItems, totalCount)`.
  /// Without [valueProviders] the search falls back to `Map` values or
  /// `toString()`, and sorting is skipped.
  (List<T> filteredAndSorted, List<T> paginated, int totalCount) execute<T>({
    required List<T> items,
    required List<ColumnDefinition> columns,
    required TableStateModel state,
    DateTime? Function(T item)? dateProvider,
    bool Function(T item, Map<String, dynamic> filters)? customFilterMatcher,
    Map<String, dynamic Function(T)>? valueProviders,
  }) {
    final r = apply<T>(
      items: items,
      columns: columns,
      state: state,
      dateProvider: dateProvider,
      customFilterMatcher: customFilterMatcher,
      valueProviders: valueProviders,
    );
    return (r.filteredAndSorted, r.paginated, r.totalCount);
  }

  /// Same as [execute] with mandatory [valueProviders] (kept for compatibility).
  (List<T> filteredAndSorted, List<T> paginated, int totalCount) run<T>({
    required List<T> items,
    required List<ColumnDefinition> columns,
    required TableStateModel state,
    DateTime? Function(T item)? dateProvider,
    bool Function(T item, Map<String, dynamic> filters)? customFilterMatcher,
    required Map<String, dynamic Function(T)> valueProviders,
  }) {
    return execute<T>(
      items: items,
      columns: columns,
      state: state,
      dateProvider: dateProvider,
      customFilterMatcher: customFilterMatcher,
      valueProviders: valueProviders,
    );
  }

  /// Compares two cell values for sorting.
  ///
  /// Numbers are compared numerically, strings case-insensitively, `DateTime`s
  /// chronologically, booleans as `false < true`. Mixed or unknown types fall
  /// back to their string representation. `null` always sorts last.
  static int compareCellValues(Object? a, Object? b, {bool ascending = true}) {
    if (a == null && b == null) return 0;
    if (a == null) return 1;
    if (b == null) return -1;

    int cmp;
    if (a is num && b is num) {
      cmp = a.compareTo(b);
    } else if (a is String && b is String) {
      cmp = a.toLowerCase().compareTo(b.toLowerCase());
      if (cmp == 0) cmp = a.compareTo(b);
    } else if (a is DateTime && b is DateTime) {
      cmp = a.compareTo(b);
    } else if (a is bool && b is bool) {
      cmp = a == b ? 0 : (a ? 1 : -1);
    } else if (a is Comparable && a.runtimeType == b.runtimeType) {
      try {
        cmp = a.compareTo(b);
      } catch (_) {
        cmp = a.toString().compareTo(b.toString());
      }
    } else {
      cmp = a.toString().toLowerCase().compareTo(b.toString().toLowerCase());
    }
    return ascending ? cmp : -cmp;
  }

  static DateTime _dayOf(DateTime d) => DateTime(d.year, d.month, d.day);

  /// A formatter that throws (e.g. a cast in user code) never breaks the
  /// search: the displayed text is simply not matched.
  static String? _safeFormat(DisplayFormatter formatter, Object? value) {
    if (value == null) return null;
    try {
      return formatter(value);
    } catch (_) {
      return null;
    }
  }

  List<(dynamic Function(T), DisplayFormatter?)> _searchExtractors<T>(
    List<ColumnDefinition> columns,
    Map<String, dynamic Function(T)>? valueProviders,
    Set<String> hiddenColumnIds,
    Map<String, DisplayFormatter>? displayFormatters,
  ) {
    if (valueProviders == null) return const [];
    final byId = {for (final c in columns) c.id: c};
    final result = <(dynamic Function(T), DisplayFormatter?)>[];
    valueProviders.forEach((id, extractor) {
      final col = byId[id];
      // Providers without a matching column act as extra "search-only" keys.
      if (col == null) {
        result.add((extractor, null));
        return;
      }
      final visible = col.isVisible && !hiddenColumnIds.contains(id);
      if (visible && col.isSearchable) {
        result.add((extractor, displayFormatters?[id]));
      }
    });
    return result;
  }

  bool _matchesQuery<T>(
    T item,
    String query,
    List<(dynamic Function(T), DisplayFormatter?)> extractors,
    Map<String, dynamic Function(T)>? valueProviders,
  ) {
    bool matches(Object? value) =>
        value != null && textNormalizer(_searchableText(value)).contains(query);

    if (valueProviders != null) {
      for (final (extractor, formatter) in extractors) {
        final value = extractor(item) as Object?;
        if (matches(value)) return true;
        if (formatter != null) {
          final shown = _safeFormat(formatter, value);
          if (shown != null && textNormalizer(shown).contains(query)) {
            return true;
          }
        }
      }
      return false;
    }
    if (item is Map) return item.values.any(matches);
    return matches(item);
  }

  static String _searchableText(Object value) {
    if (value is DateTime) {
      final m = value.month.toString().padLeft(2, '0');
      final d = value.day.toString().padLeft(2, '0');
      return '${value.year}-$m-$d ${value.toIso8601String()}';
    }
    return value.toString();
  }
}
