import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../data/exporters/table_export_options.dart';
import '../../domain/models/column_definition.dart';
import '../../domain/models/table_snapshot.dart';
import '../../domain/models/table_state_model.dart';
import '../cubit/table_cubit.dart';
import '../cubit/table_cubit_state.dart';

/// Drives an `AdaptiveTableLayout` from the outside: search, filter, sort,
/// paginate, select, export, and read the current result.
///
/// ```dart
/// final controller = AdaptiveTableController<Invoice>();
///
/// AdaptiveTableLayout<Invoice>(controller: controller, ...);
///
/// controller.search('paid');
/// controller.setCustomFilter('status', 'open');
/// final picked = controller.selectedItems;
/// await controller.exportAs(ExportFormat.pdf);
/// ```
///
/// The controller notifies its listeners on every table state change, so it
/// can be used with `ListenableBuilder` / `AnimatedBuilder`.
class AdaptiveTableController<T> extends ChangeNotifier {
  TableCubit<T>? _cubit;
  StreamSubscription<TableCubitState<T>>? _subscription;
  bool _disposed = false;

  Future<void> Function(ExportFormat format, List<T>? rows)? _export;
  Future<void> Function(List<T>? rows)? _print;
  Future<int> Function(List<T>? rows)? _copy;

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

  /// Footer totals (column id → value) of the columns with an aggregate.
  Map<String, Object?> get aggregates => value?.aggregates ?? const {};

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

  /// Like a click on a column header (see [TableCubit.toggleSort]).
  void toggleSort(
    String columnId, {
    bool additive = false,
    bool tristate = false,
  }) => cubit.toggleSort(columnId, additive: additive, tristate: tristate);

  /// Adds a secondary sort level (like Shift + click on a header).
  void addSort(String columnId, {bool ascending = true}) =>
      cubit.sortBy(columnId, ascending: ascending, additive: true);
  void setSorts(List<ColumnSort> sorts) => cubit.setSorts(sorts);
  void setColumnFilter(String columnId, String? expression) =>
      cubit.setColumnFilter(columnId, expression);
  void clearColumnFilters() => cubit.clearColumnFilters();
  void groupBy(String? columnId) => cubit.groupBy(columnId);
  void toggleGroup(String groupKey) => cubit.toggleGroupCollapsed(groupKey);

  /// Collapses the given groups (or expands all when [groupKeys] is empty).
  void setCollapsedGroups(Iterable<String> groupKeys) =>
      cubit.setCollapsedGroups(groupKeys);

  /// Closes every expanded row.
  void collapseAllRows() => cubit.collapseAll();
  void setColumnWidth(String columnId, double width) =>
      cubit.setColumnWidth(columnId, width);
  void moveColumn(String columnId, {String? beforeColumnId}) =>
      cubit.moveColumn(columnId, beforeColumnId: beforeColumnId);
  void setColumnOrder(List<String> columnIds) =>
      cubit.setColumnOrder(columnIds);
  void setColumnPin(String columnId, ColumnPin pin) =>
      cubit.setColumnPin(columnId, pin);
  void resetColumnLayout() => cubit.resetColumnLayout();

  /// Restores the initial filters, sort and page size, and clears the
  /// selection.
  void resetAll() => cubit.resetAll();

  /// The current query and column layout, e.g. to persist them.
  TableSnapshot get snapshot => cubit.snapshot;

  /// Restores a query and column layout saved from [snapshot].
  void restoreSnapshot(TableSnapshot snapshot) =>
      cubit.restoreSnapshot(snapshot);

  /// Re-runs the query; with a server data source, reloads the current page.
  void refresh() => cubit.refresh();

  /// Whether a server request is in flight.
  bool get isFetching => _cubit?.isFetching ?? false;

  /// Exports [rows] (default: the selected rows, or every filtered row) like
  /// the toolbar's export menu does.
  Future<void> exportAs(ExportFormat format, {List<T>? rows}) =>
      _action(_export)(format, rows);

  /// Opens the print dialog for [rows] (default: as the toolbar does).
  Future<void> printTable({List<T>? rows}) => _action(_print)(rows);

  /// Copies [rows] (default: the selected rows, or every filtered row) to
  /// the clipboard as tab-separated text. Returns the number of rows.
  Future<int> copyToClipboard({List<T>? rows}) => _action(_copy)(rows);

  F _action<F extends Function>(F? action) {
    if (action == null) {
      throw StateError(
        'AdaptiveTableController is not attached to an AdaptiveTableLayout.',
      );
    }
    return action;
  }

  /// Called by the table. Not meant for app code.
  void attach(TableCubit<T> cubit) {
    if (identical(_cubit, cubit)) return;
    detach();
    _cubit = cubit;
    _subscription = cubit.stream.listen((_) => notifyListeners());
    // Listeners built before the table see its first state (scheduled: the
    // table attaches while it is being built).
    scheduleMicrotask(() {
      if (!_disposed && identical(_cubit, cubit)) notifyListeners();
    });
  }

  /// Called by the table. Not meant for app code.
  void bindActions({
    required Future<void> Function(ExportFormat format, List<T>? rows) export,
    required Future<void> Function(List<T>? rows) print,
    required Future<int> Function(List<T>? rows) copy,
  }) {
    _export = export;
    _print = print;
    _copy = copy;
  }

  /// Called by the table. Not meant for app code.
  void detach([TableCubit<T>? cubit]) {
    if (cubit != null && !identical(_cubit, cubit)) return;
    _subscription?.cancel();
    _subscription = null;
    _cubit = null;
    _export = null;
    _print = null;
    _copy = null;
  }

  @override
  void dispose() {
    _disposed = true;
    detach();
    super.dispose();
  }
}
