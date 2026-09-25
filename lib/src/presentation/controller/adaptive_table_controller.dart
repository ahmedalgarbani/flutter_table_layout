import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../domain/models/table_state_model.dart';
import '../cubit/table_cubit.dart';
import '../cubit/table_cubit_state.dart';

/// Drives an `AdaptiveTableLayout` from the outside: search, filter, sort,
/// paginate, select, and read the current result.
///
/// ```dart
/// final controller = AdaptiveTableController<Invoice>();
///
/// AdaptiveTableLayout<Invoice>(controller: controller, ...);
///
/// controller.search('paid');
/// controller.setCustomFilter('status', 'open');
/// final picked = controller.selectedItems;
/// ```
///
/// The controller notifies its listeners on every table state change, so it
/// can be used with `ListenableBuilder` / `AnimatedBuilder`.
class AdaptiveTableController<T> extends ChangeNotifier {
  TableCubit<T>? _cubit;
  StreamSubscription<TableCubitState<T>>? _subscription;

  /// Whether the controller is attached to a live table.
  bool get isAttached => _cubit != null;

  /// The underlying cubit. Throws when the controller is not attached.
  TableCubit<T> get cubit {
    final c = _cubit;
    if (c == null) {
      throw StateError(
        'AdaptiveTableController is not attached to an AdaptiveTableLayout.',
      );
    }
    return c;
  }

  /// Latest table state, or `null` when not attached / not loaded yet.
  TableLoaded<T>? get value {
    final s = _cubit?.state;
    return s is TableLoaded<T> ? s : null;
  }

  /// Current search / sort / page state.
  TableStateModel get tableState =>
      _cubit?.tableState ?? const TableStateModel();

  /// Items after filters and sorting (all pages).
  List<T> get filteredItems => value?.filteredAndSortedItems ?? const [];

  /// Items on the current page.
  List<T> get pageItems => value?.paginatedItems ?? const [];

  /// Selected items.
  List<T> get selectedItems => _cubit?.selectedItems ?? const [];

  /// IDs of columns hidden by the user.
  List<String> get hiddenColumnIds => _cubit?.hiddenColumnIds ?? const [];

  void search(String query) => cubit.updateSearchQuery(query);
  void setDateRange(DateTime? start, DateTime? end) =>
      cubit.updateDateRange(start, end);
  void clearDateRange() => cubit.clearDateRange();
  void setCustomFilters(Map<String, dynamic> filters) =>
      cubit.updateCustomFilters(filters);
  void setCustomFilter(String key, dynamic value) =>
      cubit.setCustomFilter(key, value);
  void resetFilters() => cubit.resetFilters();
  void sortBy(String columnId, {bool ascending = true}) =>
      cubit.sortBy(columnId, ascending: ascending);
  void clearSort() => cubit.clearSort();
  void goToPage(int page) => cubit.setPage(page);
  void nextPage() => cubit.nextPage();
  void previousPage() => cubit.previousPage();
  void setPageSize(int size) => cubit.setPageSize(size);
  void setColumnVisibility(String columnId, bool visible) =>
      cubit.setColumnVisibility(columnId, visible);
  void setSelection(Iterable<T> items) => cubit.setSelection(items);
  void selectAll() => cubit.toggleSelectAll(true);
  void clearSelection() => cubit.clearSelection();
  void toggleRowExpansion(T item) => cubit.toggleRowExpansion(item);

  /// Called by the table. Not meant for app code.
  void attach(TableCubit<T> cubit) {
    if (identical(_cubit, cubit)) return;
    detach();
    _cubit = cubit;
    _subscription = cubit.stream.listen((_) => notifyListeners());
  }

  /// Called by the table. Not meant for app code.
  void detach([TableCubit<T>? cubit]) {
    if (cubit != null && !identical(_cubit, cubit)) return;
    _subscription?.cancel();
    _subscription = null;
    _cubit = null;
  }

  @override
  void dispose() {
    detach();
    super.dispose();
  }
}
