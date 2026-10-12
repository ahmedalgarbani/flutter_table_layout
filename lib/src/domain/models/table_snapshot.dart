import 'dart:collection';
import 'dart:convert';

import 'column_definition.dart';
import 'table_state_model.dart';

/// Everything a user can change in a table and may expect to find again:
/// the query (search, filters, sort, grouping, page) and the column layout
/// (hidden columns, widths, order, frozen positions).
///
/// Persist it to restore the table on the next visit:
///
/// ```dart
/// AdaptiveTableLayout<Invoice>(
///   initialSnapshot: TableSnapshot.tryDecode(prefs.getString('invoices')),
///   onSnapshotChanged: (s) => prefs.setString('invoices', s.encode()),
///   ...
/// )
/// ```
class TableSnapshot {
  /// Search, filters, sort levels, grouping, page and page size.
  final TableStateModel tableState;

  /// Columns hidden by the user.
  final List<String> hiddenColumnIds;

  /// Widths set by dragging a header edge (column id → px).
  final Map<String, double> columnWidths;

  /// Display order chosen by drag & drop.
  final List<String> columnOrder;

  /// Frozen positions changed at runtime.
  final Map<String, ColumnPin> columnPins;

  const TableSnapshot({
    this.tableState = const TableStateModel(),
    this.hiddenColumnIds = const [],
    this.columnWidths = const {},
    this.columnOrder = const [],
    this.columnPins = const {},
  });

  /// JSON-compatible representation. See [TableStateModel.toJson] for the
  /// constraint on custom filter values.
  Map<String, Object?> toJson() => {
    'version': 1,
    'state': tableState.toJson(),
    if (hiddenColumnIds.isNotEmpty) 'hidden': hiddenColumnIds,
    if (columnWidths.isNotEmpty) 'widths': columnWidths,
    if (columnOrder.isNotEmpty) 'order': columnOrder,
    if (columnPins.isNotEmpty)
      'pins': {for (final e in columnPins.entries) e.key: e.value.name},
  };

  /// Reads the output of [toJson]. Unknown or malformed entries are ignored.
  factory TableSnapshot.fromJson(Map<String, Object?> json) {
    List<String> strings(Object? v) =>
        List.unmodifiable([if (v is List) ...v.whereType<String>()]);
    return TableSnapshot(
      tableState: json['state'] is Map
          ? TableStateModel.fromJson({
              for (final e in (json['state']! as Map).entries)
                '${e.key}': e.value,
            })
          : const TableStateModel(),
      hiddenColumnIds: strings(json['hidden']),
      columnWidths: UnmodifiableMapView({
        if (json['widths'] case final Map<Object?, Object?> widths)
          for (final e in widths.entries)
            if (e.value is num) '${e.key}': (e.value! as num).toDouble(),
      }),
      columnOrder: strings(json['order']),
      columnPins: UnmodifiableMapView({
        if (json['pins'] case final Map<Object?, Object?> pins)
          for (final e in pins.entries)
            '${e.key}': ?ColumnPin.values.asNameMap()[e.value],
      }),
    );
  }

  /// [toJson] as a string.
  String encode() => jsonEncode(toJson());

  /// Decodes the output of [encode]; `null` when [source] is `null` or not a
  /// valid snapshot.
  static TableSnapshot? tryDecode(String? source) {
    if (source == null || source.isEmpty) return null;
    try {
      final json = jsonDecode(source);
      if (json is! Map) return null;
      return TableSnapshot.fromJson({
        for (final e in json.entries) '${e.key}': e.value,
      });
    } on FormatException {
      return null;
    }
  }

  TableSnapshot copyWith({
    TableStateModel? tableState,
    List<String>? hiddenColumnIds,
    Map<String, double>? columnWidths,
    List<String>? columnOrder,
    Map<String, ColumnPin>? columnPins,
  }) {
    return TableSnapshot(
      tableState: tableState ?? this.tableState,
      hiddenColumnIds: hiddenColumnIds ?? this.hiddenColumnIds,
      columnWidths: columnWidths ?? this.columnWidths,
      columnOrder: columnOrder ?? this.columnOrder,
      columnPins: columnPins ?? this.columnPins,
    );
  }

  static bool _listEquals(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  static bool _mapEquals<V>(Map<String, V> a, Map<String, V> b) {
    if (a.length != b.length) return false;
    for (final e in a.entries) {
      if (!b.containsKey(e.key) || b[e.key] != e.value) return false;
    }
    return true;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TableSnapshot &&
          other.tableState == tableState &&
          _listEquals(other.hiddenColumnIds, hiddenColumnIds) &&
          _mapEquals(other.columnWidths, columnWidths) &&
          _listEquals(other.columnOrder, columnOrder) &&
          _mapEquals(other.columnPins, columnPins);

  @override
  int get hashCode => Object.hash(
    tableState,
    Object.hashAll(hiddenColumnIds),
    Object.hashAllUnordered(
      columnWidths.entries.map((e) => Object.hash(e.key, e.value)),
    ),
    Object.hashAll(columnOrder),
    Object.hashAllUnordered(
      columnPins.entries.map((e) => Object.hash(e.key, e.value)),
    ),
  );

  @override
  String toString() =>
      'TableSnapshot($tableState, hidden: $hiddenColumnIds, '
      'widths: $columnWidths, order: $columnOrder, pins: $columnPins)';
}
