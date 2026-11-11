/// A header band spanning several columns ("stacked" / multi-level header),
/// e.g. `Amounts` above `Debit`, `Credit` and `Balance`.
///
/// The band covers the member columns that are displayed next to each
/// other; when the user reorders, freezes or hides columns so that members
/// are no longer adjacent, each run of adjacent members gets its own band.
class TableColumnGroup {
  /// Text of the band.
  final String title;

  /// Ids of the member columns.
  final List<String> columnIds;

  const TableColumnGroup({required this.title, required this.columnIds});
}
