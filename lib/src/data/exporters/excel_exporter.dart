import 'dart:math' as math;
import 'dart:typed_data';

import '../../domain/models/column_definition.dart';
import 'export_utils.dart';
import 'xlsx/xlsx_writer.dart';

/// Exporter responsible for producing Excel sheets (.xlsx) of the table content.
///
/// Numbers, booleans and dates keep their native cell types, so formulas and
/// sorting work inside Excel. The header row is styled, stays visible while
/// scrolling (frozen) and gets filter buttons.
///
/// The file is written by the package itself (no third-party spreadsheet
/// dependency), compressed on mobile / desktop and stored as-is on web.
class ExcelExporter {
  const ExcelExporter();

  /// Generates the raw Excel file bytes.
  ///
  /// * [hiddenColumnIds] – columns hidden by the user, skipped in the output.
  /// * [isRtl] – mirrors the sheet (right-to-left) for Arabic content.
  /// * [headerColor] – header background as `#RRGGBB`; the header text is
  ///   black or white, whichever reads better on it.
  /// * [totals] – adds a bold last row with the column totals (typed values),
  ///   and [totalsLabel] in the first column when it has no total.
  /// * [freezeHeader] – keeps the header row visible while scrolling.
  /// * [autoFilter] – adds Excel's filter buttons to the header row.
  Future<Uint8List> generateExcel<T>({
    required String sheetName,
    required List<ColumnDefinition> columns,
    required List<T> items,
    required Map<String, dynamic Function(T)> valueProviders,
    Iterable<String> hiddenColumnIds = const [],
    bool isRtl = false,
    String headerColor = '#1565C0',
    Map<String, Object?>? totals,
    String totalsLabel = 'Total',
    bool freezeHeader = true,
    bool autoFilter = true,
  }) async {
    final visibleCols = ExportUtils.exportableColumns(
      columns,
      hiddenColumnIds: hiddenColumnIds,
    );
    final fill = _toRgbHex(headerColor);
    final writer = XlsxWriter(
      sheetName: sanitizeSheetName(sheetName),
      rightToLeft: isRtl,
      headerFillRgb: fill,
      headerFontRgb: ExportUtils.isLightColor(int.parse(fill, radix: 16))
          ? '000000'
          : 'FFFFFF',
      frozenRows: freezeHeader ? 1 : 0,
    );

    // 1. Header row
    writer.addRow([
      for (final c in visibleCols) XlsxCell(c.title, XlsxStyle.header),
    ]);

    // 2. Data rows + width estimation
    final widths = visibleCols.map((c) => c.title.length.toDouble()).toList();
    for (final item in items) {
      final row = <XlsxCell>[];
      for (var i = 0; i < visibleCols.length; i++) {
        final raw = valueProviders[visibleCols[i].id]?.call(item) as Object?;
        row.add(XlsxCell(_cellValue(raw)));
        widths[i] = math.max(
          widths[i],
          ExportUtils.formatValue(raw).length.toDouble(),
        );
      }
      writer.addRow(row);
    }
    if (autoFilter && items.isNotEmpty) {
      writer.setAutoFilter(
        row: 0,
        columns: visibleCols.length,
        lastRow: items.length,
      );
    }

    // 3. Totals row
    if (totals != null && totals.isNotEmpty) {
      final totalsRow = ExportUtils.totalsRow(visibleCols, totals);
      writer.addRow([
        for (var i = 0; i < visibleCols.length; i++)
          XlsxCell(
            i == totalsRow.labelIndex
                ? totalsLabel
                : _cellValue(totalsRow.values[i]),
            XlsxStyle.bold,
          ),
      ]);
    }

    for (var i = 0; i < visibleCols.length; i++) {
      writer.setColumnWidth(i, (widths[i] + 4).clamp(10, 60).toDouble());
    }
    return writer.encode();
  }

  /// Keeps `num`, `bool`, `DateTime` and `String` as typed cells; anything
  /// else is written as text.
  static Object? _cellValue(Object? value) => switch (value) {
    null || num() || bool() || DateTime() || String() => value,
    _ => value.toString(),
  };

  static String _toRgbHex(String hex) {
    var h = hex.replaceAll('#', '').toUpperCase();
    if (h.length == 8) h = h.substring(2);
    if (!RegExp(r'^[0-9A-F]{6}$').hasMatch(h)) h = '1565C0';
    return h;
  }

  /// Excel sheet names: max 31 chars, none of `[]:*?/\`, not empty.
  static String sanitizeSheetName(String name) {
    var s = name.replaceAll(RegExp(r'[\[\]:*?/\\]'), ' ').trim();
    if (s.startsWith("'")) s = s.substring(1);
    if (s.endsWith("'")) s = s.substring(0, s.length - 1);
    if (s.isEmpty) s = 'Sheet1';
    return s.length > 31 ? s.substring(0, 31) : s;
  }
}
