import 'dart:convert';
import 'dart:typed_data';

import '../../domain/models/column_definition.dart';
import 'export_utils.dart';

/// Exporter producing RFC 4180 CSV files.
///
/// * UTF-8 with a byte-order mark (by default), so Excel shows Arabic text
///   correctly when the file is double-clicked.
/// * Values are written raw (numbers without grouping, dates as
///   `yyyy-MM-dd`), so they stay machine readable, unless [formatters] are
///   given.
/// * Text cells starting with `=`, `+`, `-`, `@` are prefixed with `'` so a
///   spreadsheet never runs them as formulas (CSV injection).
class CsvExporter {
  const CsvExporter();

  /// Generates the CSV bytes.
  ///
  /// [totals] adds a last row with the column totals, and [totalsLabel] in
  /// the first column when it has no total of its own.
  Future<Uint8List> generateCsv<T>({
    required List<ColumnDefinition> columns,
    required List<T> items,
    required Map<String, dynamic Function(T)> valueProviders,
    Iterable<String> hiddenColumnIds = const [],
    Map<String, ExportValueFormatter>? formatters,
    Map<String, Object?>? totals,
    String totalsLabel = 'Total',
    String delimiter = ',',
    bool includeBom = true,
  }) async {
    final visibleCols = ExportUtils.exportableColumns(
      columns,
      hiddenColumnIds: hiddenColumnIds,
    );
    final buffer = StringBuffer();
    void writeRow(Iterable<Object?> cells) {
      buffer
        ..writeAll(
          cells.map((c) => encodeCell(c, delimiter: delimiter)),
          delimiter,
        )
        ..write('\r\n');
    }

    writeRow(visibleCols.map((c) => c.title));
    for (final item in items) {
      writeRow([
        for (final col in visibleCols)
          _cell(valueProviders[col.id]?.call(item), formatters?[col.id]),
      ]);
    }
    if (totals != null && totals.isNotEmpty) {
      final row = ExportUtils.totalsRow(visibleCols, totals);
      writeRow([
        for (var i = 0; i < visibleCols.length; i++)
          i == row.labelIndex ? totalsLabel : row.values[i],
      ]);
    }

    final bytes = utf8.encode(buffer.toString());
    if (!includeBom) return Uint8List.fromList(bytes);
    return Uint8List.fromList([0xEF, 0xBB, 0xBF, ...bytes]);
  }

  static Object? _cell(Object? raw, ExportValueFormatter? formatter) {
    if (formatter == null || raw == null) return raw;
    return formatter(raw);
  }

  /// Encodes one CSV field: quoted when it contains the [delimiter], a quote
  /// or a line break, and protected against formula injection.
  static String encodeCell(Object? value, {String delimiter = ','}) {
    if (value == null) return '';
    var text = switch (value) {
      DateTime() => ExportUtils.formatDate(value),
      double() => ExportUtils.formatValue(value),
      _ => value.toString(),
    };
    if (value is String && _looksLikeFormula(text)) text = "'$text";
    final needsQuotes =
        text.contains(delimiter) ||
        text.contains('"') ||
        text.contains('\n') ||
        text.contains('\r');
    if (!needsQuotes) return text;
    return '"${text.replaceAll('"', '""')}"';
  }

  /// Text a spreadsheet would evaluate. Formatted numbers such as
  /// `-1,250.00` are left alone.
  static bool _looksLikeFormula(String text) {
    if (text.isEmpty || !'=+-@\t\r'.contains(text[0])) return false;
    return num.tryParse(text.replaceAll(',', '')) == null;
  }
}
