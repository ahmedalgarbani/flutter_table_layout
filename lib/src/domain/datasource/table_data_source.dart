import 'dart:async';

import '../models/table_state_model.dart';

/// One page of rows returned by a server.
class TableDataPage<T> {
  /// The rows of the requested page (already filtered and sorted by the server).
  final List<T> items;

  /// Total number of rows matching the query on the server (all pages).
  final int totalCount;

  const TableDataPage({required this.items, required this.totalCount});
}

/// Loads rows from a server (or any async source) page by page.
///
/// The table sends its whole [TableStateModel] (search, dates, custom and
/// column filters, sort levels, grouping, page and page size) and shows what
/// comes back. Filtering, sorting and pagination are then the server's job.
///
/// ```dart
/// final source = AdaptiveTableDataSource<Invoice>.fromCallback((query) async {
///   final res = await api.invoices(
///     page: query.currentPage,
///     size: query.pageSize,
///     search: query.searchQuery,
///     sort: query.sorts.map((s) => '${s.columnId}:${s.ascending ? 'asc' : 'desc'}'),
///   );
///   return TableDataPage(items: res.rows, totalCount: res.total);
/// });
/// ```
abstract class AdaptiveTableDataSource<T> {
  const AdaptiveTableDataSource();

  /// Creates a data source from a function.
  factory AdaptiveTableDataSource.fromCallback(
    FutureOr<TableDataPage<T>> Function(TableStateModel query) fetch,
  ) = _CallbackDataSource<T>;

  /// Fetches the page described by [query].
  FutureOr<TableDataPage<T>> fetch(TableStateModel query);
}

class _CallbackDataSource<T> extends AdaptiveTableDataSource<T> {
  final FutureOr<TableDataPage<T>> Function(TableStateModel query) _fetch;

  const _CallbackDataSource(this._fetch);

  @override
  FutureOr<TableDataPage<T>> fetch(TableStateModel query) => _fetch(query);
}
