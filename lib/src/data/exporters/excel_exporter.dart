import 'dart:typed_data';
import 'package:excel/excel.dart';
import '../../domain/models/column_definition.dart';

/// Exporter responsible for producing Excel sheets (.xlsx) of the table content.
class ExcelExporter {
  const ExcelExporter();

  /// Generates the raw Excel file bytes.
  Future<Uint8List> generateExcel<T>({
    required String sheetName,
    required List<ColumnDefinition> columns,
    required List<T> items,
    required Map<String, dynamic Function(T)> valueProviders,
  }) async {
    final excel = Excel.createExcel();
    // Remove the default sheet if we add our custom one
    final defaultSheetName = excel.sheets.keys.first;
    final sheet = excel[sheetName];

    // Filter visible columns
    final visibleCols = columns.where((c) => c.isVisible).toList();

    // 1. Write headers
    final headerRow = visibleCols.map((c) => TextCellValue(c.title)).toList();
    sheet.appendRow(headerRow);

    // Style the header row if possible
    // In excel package, we can get the cells in row 0 and apply bold styles.
    for (int colIndex = 0; colIndex < visibleCols.length; colIndex++) {
      final cellIndex = CellIndex.indexByColumnRow(
        columnIndex: colIndex,
        rowIndex: 0,
      );
      final cell = sheet.cell(cellIndex);
      cell.cellStyle = CellStyle(
        bold: true,
        backgroundColorHex: ExcelColor.blue,
        fontColorHex: ExcelColor.white,
        horizontalAlign: HorizontalAlign.Center,
      );
    }

    // 2. Write data rows
    for (final item in items) {
      final List<CellValue> rowCells = [];
      for (final col in visibleCols) {
        final extractor = valueProviders[col.id];
        final rawVal = extractor != null ? extractor(item) : null;
        rowCells.add(_mapToCellValue(rawVal));
      }
      sheet.appendRow(rowCells);
    }

    // Auto-fit column widths (basic approximation)
    for (int i = 0; i < visibleCols.length; i++) {
      sheet.setColumnWidth(i, 20.0); // Default comfortable width
    }

    // Remove the unused default sheet if we created a custom one
    if (defaultSheetName != sheetName) {
      excel.delete(defaultSheetName);
    }

    final bytes = excel.encode();
    if (bytes == null) {
      throw Exception('Failed to generate Excel file');
    }
    return Uint8List.fromList(bytes);
  }

  /// Maps dynamic Dart values to Excel's CellValue sub-types.
  CellValue _mapToCellValue(dynamic val) {
    if (val == null) return TextCellValue('');
    if (val is int) return IntCellValue(val);
    if (val is double) return DoubleCellValue(val);
    if (val is bool) return BoolCellValue(val);
    if (val is DateTime) {
      // Format to simple date yyyy-MM-dd
      final dateStr =
          '${val.year}-${val.month.toString().padLeft(2, '0')}-${val.day.toString().padLeft(2, '0')}';
      return TextCellValue(dateStr);
    }
    return TextCellValue(val.toString());
  }
}
