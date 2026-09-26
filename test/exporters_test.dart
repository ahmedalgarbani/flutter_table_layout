import 'dart:convert';

import 'package:excel/excel.dart';
import 'package:flutter_table_layout/flutter_table_layout.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/widgets.dart' as pw;

class Item {
  final int id;
  final String name;
  final double price;
  final DateTime date;
  Item(this.id, this.name, this.price, this.date);
}

final _items = [
  Item(1, 'Tom & <Jerry>', 9.5, DateTime(2026, 4, 22)),
  Item(2, 'قهوة "عربية"', 12, DateTime(2026, 4, 23, 14, 30)),
];

const _columns = [
  ColumnDefinition(id: 'id', title: 'ID'),
  ColumnDefinition(id: 'name', title: 'Name'),
  ColumnDefinition(id: 'price', title: 'Price'),
  ColumnDefinition(id: 'date', title: 'Date'),
  ColumnDefinition(id: 'actions', title: 'Actions', isExportable: false),
];

final _providers = <String, dynamic Function(Item)>{
  'id': (i) => i.id,
  'name': (i) => i.name,
  'price': (i) => i.price,
  'date': (i) => i.date,
};

void main() {
  group('ExportUtils', () {
    test('formatValue', () {
      expect(ExportUtils.formatValue(null), '');
      expect(ExportUtils.formatValue(12.0), '12');
      expect(ExportUtils.formatValue(9.5), '9.5');
      expect(ExportUtils.formatValue(DateTime(2026, 1, 2)), '2026-01-02');
      expect(
        ExportUtils.formatValue(DateTime(2026, 1, 2, 3, 4)),
        '2026-01-02 03:04',
      );
      expect(ExportUtils.formatValue(true), '✓');
    });

    test('sanitizeFileName keeps Arabic and strips path characters', () {
      expect(
        ExportUtils.sanitizeFileName(
          'تقرير / الحسابات: 2026',
          extension: 'pdf',
        ),
        'تقرير_الحسابات_2026.pdf',
      );
      expect(
        ExportUtils.sanitizeFileName('../../etc', extension: '.xlsx'),
        'etc.xlsx',
      );
      expect(
        ExportUtils.sanitizeFileName('  ', extension: 'doc'),
        'report.doc',
      );
    });

    test('exportableColumns skips hidden and non-exportable columns', () {
      final cols = ExportUtils.exportableColumns(
        _columns,
        hiddenColumnIds: ['price'],
      );
      expect(cols.map((c) => c.id), ['id', 'name', 'date']);
    });
  });

  group('WordExporter', () {
    test('escapes HTML and honours hidden columns', () async {
      final bytes = await const WordExporter().generateWord<Item>(
        title: 'A <b>title</b>',
        columns: _columns,
        items: _items,
        valueProviders: _providers,
        hiddenColumnIds: ['date'],
        isRtl: true,
      );
      final html = utf8.decode(bytes);
      expect(html, contains('Tom &amp; &lt;Jerry&gt;'));
      expect(html, contains('A &lt;b&gt;title&lt;/b&gt;'));
      expect(html, contains('قهوة &quot;عربية&quot;'));
      expect(html, isNot(contains('<th>Date</th>')));
      expect(html, isNot(contains('<th>Actions</th>')));
      expect(html, contains('dir="rtl"'));
    });

    test('uses per-column formatters', () async {
      final bytes = await const WordExporter().generateWord<Item>(
        title: 'T',
        columns: _columns,
        items: _items,
        valueProviders: _providers,
        formatters: {'price': (v) => '\$${(v as num).toStringAsFixed(2)}'},
      );
      expect(utf8.decode(bytes), contains(r'$9.50'));
    });
  });

  group('ExcelExporter', () {
    test('produces a readable workbook with typed cells', () async {
      final bytes = await const ExcelExporter().generateExcel<Item>(
        sheetName: 'Report: 2026/04 [final]',
        columns: _columns,
        items: _items,
        valueProviders: _providers,
        hiddenColumnIds: ['date'],
      );
      final excel = Excel.decodeBytes(bytes);
      expect(excel.tables.keys, ['Report  2026 04  final']);
      final sheet = excel.tables.values.first;
      expect(sheet.maxRows, 3);
      final header = sheet.row(0).map((c) => c?.value.toString()).toList();
      expect(header, ['ID', 'Name', 'Price']);
      expect(sheet.row(1)[0]?.value, isA<IntCellValue>());
      expect(sheet.row(1)[2]?.value, isA<DoubleCellValue>());
    });

    test('sanitizeSheetName', () {
      expect(ExcelExporter.sanitizeSheetName(''), 'Sheet1');
      expect(ExcelExporter.sanitizeSheetName('x' * 40).length, 31);
    });
  });

  group('PdfExporter', () {
    test('generates a PDF with an explicit font (offline)', () async {
      final bytes = await PdfExporter(font: pw.Font.helvetica())
          .generatePdf<Item>(
            title: 'Report',
            subtitle: 'Sub',
            columns: _columns,
            items: [_items.first],
            valueProviders: _providers,
          );
      expect(bytes.length, greaterThan(500));
      expect(String.fromCharCodes(bytes.sublist(0, 5)), '%PDF-');
    });
  });
}
