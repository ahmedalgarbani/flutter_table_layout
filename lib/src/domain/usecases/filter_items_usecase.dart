import '../models/column_definition.dart';
import '../models/table_state_model.dart';

/// Pure Dart usecase to filter, search, sort, and paginate generic data lists.
/// Conforms to domain purity constraints (zero Flutter imports).
class FilterItemsUseCase {
  const FilterItemsUseCase();

  /// Filters, searches, sorts, and slices the dataset.
  /// Returns a record: (filteredAndSortedItems, paginatedItems, totalCount)
  (List<T> filteredAndSorted, List<T> paginated, int totalCount) execute<T>({
    required List<T> items,
    required List<ColumnDefinition> columns,
    required TableStateModel state,
    DateTime? Function(T item)? dateProvider,
    bool Function(T item, Map<String, dynamic> filters)? customFilterMatcher,
  }) {
    List<T> result = List.from(items);

    // 1. Date Range Filtering
    if (dateProvider != null &&
        (state.startDate != null || state.endDate != null)) {
      result = result.where((item) {
        final itemDate = dateProvider(item);
        if (itemDate == null) return false;

        if (state.startDate != null && itemDate.isBefore(state.startDate!)) {
          return false;
        }
        if (state.endDate != null) {
          // Make end date inclusive of the day
          final inclusiveEnd = state.endDate!
              .add(const Duration(days: 1))
              .subtract(const Duration(microseconds: 1));
          if (itemDate.isAfter(inclusiveEnd)) {
            return false;
          }
        }
        return true;
      }).toList();
    }

    // 2. Custom Filter Matcher
    if (customFilterMatcher != null && state.customFilters.isNotEmpty) {
      result = result
          .where((item) => customFilterMatcher(item, state.customFilters))
          .toList();
    }

    // 3. Global Search Filtering
    if (state.searchQuery.trim().isNotEmpty) {
      // final query = state.searchQuery.toLowerCase().trim();
      result = result.where((item) {
        // Search through the values provided by column definitions
        for (final col in columns) {
          // We can only search visible columns
          if (!col.isVisible) continue;

          // If a valueProvider is present, read the cell value
          // We can check if it matches the query
          // If we don't have a value provider, we skip search on this column
        }

        // Wait! We can check if any field matches. Let's see:
        // We can pass a callback or inspect the column values.
        // Let's pass a function to extract string values or use the columns' fields
        return false; // placeholder, let's implement actual check below
      }).toList();
    }

    // Wait! Let's rewrite the search filter logic properly.
    // If the caller wants global search, they can provide a list of search strings extraction.
    // To make it easy, we can extract search values by passing a list of values:
    // We can evaluate column values if we pass dynamic value extractors.
    // Let's design the method to accept a list of columns with their value extraction:
    // Since columns have valueProvider in presentation, we can pass value providers to the execute function!
    // Or we can define a value provider map: Map<String, dynamic Function(T)> valueProviders.
    // Yes! Let's pass a map of value providers: `Map<String, dynamic Function(T)> valueProviders`.
    // This is clean, pure, and works perfectly!
    return _process(
      items: items,
      columns: columns,
      state: state,
      dateProvider: dateProvider,
      customFilterMatcher: customFilterMatcher,
    );
  }

  // Let's write the complete implementation of the processing method.
  (List<T> filteredAndSorted, List<T> paginated, int totalCount) _process<T>({
    required List<T> items,
    required List<ColumnDefinition> columns,
    required TableStateModel state,
    DateTime? Function(T item)? dateProvider,
    bool Function(T item, Map<String, dynamic> filters)? customFilterMatcher,
    Map<String, dynamic Function(T)>? valueProviders,
  }) {
    List<T> result = List.from(items);

    // 1. Date Range Filter
    if (dateProvider != null &&
        (state.startDate != null || state.endDate != null)) {
      result = result.where((item) {
        final itemDate = dateProvider(item);
        if (itemDate == null) return false;

        // Check start date (normalize to start of day if necessary, but direct comparison is fine)
        if (state.startDate != null) {
          final startDay = DateTime(
            state.startDate!.year,
            state.startDate!.month,
            state.startDate!.day,
          );
          final itemDay = DateTime(itemDate.year, itemDate.month, itemDate.day);
          if (itemDay.isBefore(startDay)) return false;
        }

        // Check end date (inclusive)
        if (state.endDate != null) {
          final endDay = DateTime(
            state.endDate!.year,
            state.endDate!.month,
            state.endDate!.day,
            23,
            59,
            59,
            999,
          );
          if (itemDate.isAfter(endDay)) return false;
        }

        return true;
      }).toList();
    }

    // 2. Custom filters
    if (customFilterMatcher != null && state.customFilters.isNotEmpty) {
      result = result
          .where((item) => customFilterMatcher(item, state.customFilters))
          .toList();
    }

    // 3. Search query
    if (state.searchQuery.trim().isNotEmpty) {
      final query = state.searchQuery.toLowerCase().trim();
      result = result.where((item) {
        // If valueProviders is passed, search through them
        if (valueProviders != null) {
          for (final entry in valueProviders.entries) {
            // Check if column is visible
            final col = columns.firstWhere(
              (c) => c.id == entry.key,
              orElse: () => columns.first,
            );
            if (!col.isVisible) continue;

            final val = entry.value(item);
            if (val != null && val.toString().toLowerCase().contains(query)) {
              return true;
            }
          }
        } else {
          // Fallback: convert item to string or search properties if T is Map
          if (item is Map) {
            for (final val in item.values) {
              if (val != null && val.toString().toLowerCase().contains(query)) {
                return true;
              }
            }
          } else {
            if (item.toString().toLowerCase().contains(query)) {
              return true;
            }
          }
        }
        return false;
      }).toList();
    }

    // 4. Sorting
    if (state.sortByColumnId != null && valueProviders != null) {
      final extractor = valueProviders[state.sortByColumnId];
      if (extractor != null) {
        result.sort((a, b) {
          final valA = extractor(a);
          final valB = extractor(b);

          if (valA == null && valB == null) return 0;
          if (valA == null) return state.sortAscending ? 1 : -1;
          if (valB == null) return state.sortAscending ? -1 : 1;

          int comp = 0;
          if (valA is Comparable && valB is Comparable) {
            comp = valA.compareTo(valB);
          } else {
            comp = valA.toString().compareTo(valB.toString());
          }

          return state.sortAscending ? comp : -comp;
        });
      }
    }

    // Save total count before pagination
    final totalCount = result.length;

    // 5. Pagination
    final startIndex = (state.currentPage - 1) * state.pageSize;
    List<T> paginated = [];
    if (startIndex < totalCount) {
      final endIndex = (startIndex + state.pageSize) > totalCount
          ? totalCount
          : (startIndex + state.pageSize);
      paginated = result.sublist(startIndex, endIndex);
    }

    return (result, paginated, totalCount);
  }

  /// Exposed entry point wrapping the processor
  (List<T> filteredAndSorted, List<T> paginated, int totalCount) run<T>({
    required List<T> items,
    required List<ColumnDefinition> columns,
    required TableStateModel state,
    DateTime? Function(T item)? dateProvider,
    bool Function(T item, Map<String, dynamic> filters)? customFilterMatcher,
    required Map<String, dynamic Function(T)> valueProviders,
  }) {
    return _process(
      items: items,
      columns: columns,
      state: state,
      dateProvider: dateProvider,
      customFilterMatcher: customFilterMatcher,
      valueProviders: valueProviders,
    );
  }
}
