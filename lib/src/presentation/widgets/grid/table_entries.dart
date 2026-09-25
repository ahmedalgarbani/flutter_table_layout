import '../../../data/exporters/export_utils.dart';
import '../../cubit/table_cubit_state.dart';

/// Information about one group of rows (see `groupByColumnId`).
class TableGroupInfo<T> {
  /// Column the rows are grouped by.
  final String columnId;

  /// Stable key of the group (the formatted value).
  final String key;

  /// Raw value of the grouped column for this group.
  final Object? value;

  /// Every row of the group across all pages (current page in server mode).
  final List<T> rows;

  /// Whether the group is collapsed.
  final bool isCollapsed;

  const TableGroupInfo({
    required this.columnId,
    required this.key,
    required this.value,
    required this.rows,
    required this.isCollapsed,
  });
}

/// A displayed line: a data row or a group header.
sealed class TableEntry<T> {
  const TableEntry();
}

class RowEntry<T> extends TableEntry<T> {
  final T item;

  /// Index among the displayed rows (for zebra striping / keyboard focus).
  final int rowIndex;

  const RowEntry(this.item, this.rowIndex);
}

class GroupEntry<T> extends TableEntry<T> {
  final TableGroupInfo<T> info;
  const GroupEntry(this.info);
}

/// Builds the displayed entries of the current page, inserting group headers
/// and skipping the rows of collapsed groups.
List<TableEntry<T>> buildTableEntries<T>(
  TableLoaded<T> state, {
  required Map<String, dynamic Function(T)> valueProviders,
  String Function(dynamic value)? groupFormatter,
}) {
  final groupId = state.tableState.groupByColumnId;
  final extractor = groupId == null ? null : valueProviders[groupId];
  final page = state.paginatedItems;
  if (groupId == null || extractor == null) {
    return [for (var i = 0; i < page.length; i++) RowEntry<T>(page[i], i)];
  }

  final format = groupFormatter ?? ExportUtils.formatValue;
  final byKey = <String, List<T>>{};
  final values = <String, Object?>{};
  for (final item in state.filteredAndSortedItems) {
    final value = extractor(item) as Object?;
    final key = format(value);
    (byKey[key] ??= []).add(item);
    values.putIfAbsent(key, () => value);
  }

  final entries = <TableEntry<T>>[];
  String? currentKey;
  var rowIndex = 0;
  for (final item in page) {
    final value = extractor(item) as Object?;
    final key = format(value);
    final collapsed = state.collapsedGroups.contains(key);
    if (key != currentKey) {
      currentKey = key;
      entries.add(
        GroupEntry<T>(
          TableGroupInfo<T>(
            columnId: groupId,
            key: key,
            value: values[key] ?? value,
            rows: byKey[key] ?? [item],
            isCollapsed: collapsed,
          ),
        ),
      );
    }
    if (!collapsed) entries.add(RowEntry<T>(item, rowIndex++));
  }
  return entries;
}
