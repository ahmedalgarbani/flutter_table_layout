import 'dart:math' as math;
import 'dart:typed_data';

import 'package:excel/excel.dart';

import '../../domain/models/column_definition.dart';
import 'export_utils.dart';

/// Exporter responsible for producing Excel sheets (.xlsx) of the table content.
///
/// Numbers, booleans and dates keep their native cell types, so formulas and
/// sorting work inside Excel.
class ExcelExporter {
  const ExcelExporter();

  /// Generates the raw Excel file bytes.
  ///
  /// * [hiddenColumnIds] – columns hidden by the user, skipped in the output.
  /// * [isRtl] – mirrors the sheet (right-to-left) for Arabic content.
  /// * [headerColor] – header background as `#RRGGBB`.
  Future<Uint8List> generateExcel<T>({
    required String sheetName,
    required List<ColumnDefinition> columns,
    required List<T> items,
    required Map<String, dynamic Function(T)> valueProviders,
    Iterable<String> hiddenColumnIds = const [],
    bool isRtl = false,
    String headerColor = '#1565C0',
  }) async {
    final excel = Excel.createExcel();
    final safeName = sanitizeSheetName(sheetName);
    final defaultSheet = excel.getDefaultSheet();
    if (defaultSheet != null && defaultSheet != safeName) {
      excel.rename(defaultSheet, safeName);
    }
    final sheet = excel[safeName];
    excel.setDefaultSheet(safeName);
    sheet.isRTL = isRtl;

    final visibleCols = ExportUtils.exportableColumns(
      columns,
      hiddenColumnIds: hiddenColumnIds,
    );

    // 1. Header row
    sheet.appendRow(visibleCols.map((c) => TextCellValue(c.title)).toList());
    final headerStyle = CellStyle(
      bold: true,
      backgroundColorHex: ExcelColor.fromHexString(_toArgbHex(headerColor)),
      fontColorHex: ExcelColor.white,
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
    );
    for (var i = 0; i < visibleCols.length; i++) {
      sheet
              .cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0))
              .cellStyle =
          headerStyle;
    }

    // 2. Data rows + width estimation
    final widths = visibleCols.map((c) => c.title.length.toDouble()).toList();
    for (final item in items) {
      final row = <CellValue>[];
      for (var i = 0; i < visibleCols.length; i++) {
        final extractor = valueProviders[visibleCols[i].id];
        final raw = extractor?.call(item);
        row.add(mapToCellValue(raw));
        widths[i] = math.max(
          widths[i],
          ExportUtils.formatValue(raw).length.toDouble(),
        );
      }
      sheet.appendRow(row);
    }

    for (var i = 0; i < visibleCols.length; i++) {
      sheet.setColumnWidth(i, (widths[i] + 4).clamp(10, 60).toDouble());
    }

    final bytes = excel.encode();
    if (bytes == null) {
      throw StateError('Failed to generate Excel file');
    }
    return Uint8List.fromList(bytes);
  }

  static String _toArgbHex(String hex) {
    var h = hex.replaceAll('#', '').toUpperCase();
    if (h.length == 6) h = 'FF$h';
    if (!RegExp(r'^[0-9A-F]{8}$').hasMatch(h)) h = 'FF1565C0';
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

  /// Maps dynamic Dart values to Excel's CellValue sub-types.
  static CellValue mapToCellValue(dynamic val) {
    if (val == null) return TextCellValue('');
    if (val is int) return IntCellValue(val);
    if (val is double) {
      return val.isFinite ? DoubleCellValue(val) : TextCellValue('$val');
    }
    if (val is num) return DoubleCellValue(val.toDouble());
    if (val is bool) return BoolCellValue(val);
    if (val is DateTime) {
      final hasTime = val.hour != 0 || val.minute != 0 || val.second != 0;
      return hasTime
          ? DateTimeCellValue.fromDateTime(val)
          : DateCellValue.fromDateTime(val);
    }
    return TextCellValue(val.toString());
  }
}
