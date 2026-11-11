import 'dart:convert';
import 'dart:typed_data';

import 'zip_writer.dart';

/// Look of a cell in an [XlsxWriter] sheet.
enum XlsxStyle { normal, header, bold }

/// One cell: its [value] (`null`, `String`, `num`, `bool` or `DateTime`) and
/// [style].
class XlsxCell {
  final Object? value;
  final XlsxStyle style;

  const XlsxCell(this.value, [this.style = XlsxStyle.normal]);
}

/// Writes a single-sheet `.xlsx` workbook (Office Open XML) with typed
/// cells, a styled header row, column widths, a frozen header, an
/// auto-filter and merged cells. No dependency: the package is zipped by
/// [ZipWriter].
class XlsxWriter {
  final String sheetName;
  final bool rightToLeft;

  /// Header fill as `RRGGBB`.
  final String headerFillRgb;

  /// Header font color as `RRGGBB`.
  final String headerFontRgb;

  /// Number of leading rows kept visible while scrolling (0 = none).
  final int frozenRows;

  final _rows = <List<XlsxCell>>[];
  final _widths = <int, double>{};
  final _merges = <String>[];
  final _strings = <String, int>{};
  String? _autoFilter;

  XlsxWriter({
    required this.sheetName,
    this.rightToLeft = false,
    this.headerFillRgb = '1565C0',
    this.headerFontRgb = 'FFFFFF',
    this.frozenRows = 0,
  });

  int get rowCount => _rows.length;

  void addRow(List<XlsxCell> cells) => _rows.add(cells);

  /// Width of column [index] in characters.
  void setColumnWidth(int index, double width) => _widths[index] = width;

  /// Merges the cells from ([row], [firstColumn]) to ([row], [lastColumn]).
  void mergeRow(int row, int firstColumn, int lastColumn) {
    if (lastColumn <= firstColumn) return;
    _merges.add('${cellRef(row, firstColumn)}:${cellRef(row, lastColumn)}');
  }

  /// Adds filter buttons to the header at [row] over [columns] columns down
  /// to [lastRow].
  void setAutoFilter({
    required int row,
    required int columns,
    required int lastRow,
  }) {
    if (columns <= 0) return;
    _autoFilter = '${cellRef(row, 0)}:${cellRef(lastRow, columns - 1)}';
  }

  /// `A1`-style reference of a zero-based [row] / [column].
  static String cellRef(int row, int column) =>
      '${columnName(column)}${row + 1}';

  /// `A`, `B`, … `Z`, `AA`… for a zero-based column index.
  static String columnName(int index) {
    var n = index + 1;
    final chars = <int>[];
    while (n > 0) {
      final rem = (n - 1) % 26;
      chars.insert(0, 65 + rem);
      n = (n - 1) ~/ 26;
    }
    return String.fromCharCodes(chars);
  }

  /// Excel serial number of [d]'s wall-clock date and time.
  static double dateSerial(DateTime d) {
    final utc = DateTime.utc(
      d.year,
      d.month,
      d.day,
      d.hour,
      d.minute,
      d.second,
    );
    return utc.difference(DateTime.utc(1899, 12, 30)).inSeconds / 86400;
  }

  /// Escapes [text] for XML and drops characters XML 1.0 forbids.
  static String escape(String text) {
    final b = StringBuffer();
    for (final r in text.runes) {
      switch (r) {
        case 0x26:
          b.write('&amp;');
        case 0x3C:
          b.write('&lt;');
        case 0x3E:
          b.write('&gt;');
        case 0x22:
          b.write('&quot;');
        default:
          final valid =
              r == 0x9 ||
              r == 0xA ||
              r == 0xD ||
              (r >= 0x20 && r <= 0xD7FF) ||
              (r >= 0xE000 && r <= 0xFFFD) ||
              r >= 0x10000;
          if (valid) b.writeCharCode(r);
      }
    }
    return b.toString();
  }

  // Cell formats (indexes into cellXfs of styles.xml).
  static const _xfHeader = 1;
  static const _xfDate = 2;
  static const _xfDateTime = 3;
  static const _xfBold = 4;
  static const _xfBoldDate = 5;
  static const _xfBoldDateTime = 6;

  int _xf(XlsxStyle style, {bool date = false, bool time = false}) {
    switch (style) {
      case XlsxStyle.header:
        return _xfHeader;
      case XlsxStyle.bold:
        return date ? (time ? _xfBoldDateTime : _xfBoldDate) : _xfBold;
      case XlsxStyle.normal:
        return date ? (time ? _xfDateTime : _xfDate) : 0;
    }
  }

  String _cell(int row, int col, XlsxCell cell) {
    final ref = cellRef(row, col);
    final v = cell.value;
    String styled(int xf) => xf == 0 ? '' : ' s="$xf"';
    final base = styled(_xf(cell.style));
    if (v == null || (v is String && v.isEmpty)) {
      return cell.style == XlsxStyle.normal ? '' : '<c r="$ref"$base/>';
    }
    if (v is bool) return '<c r="$ref"$base t="b"><v>${v ? 1 : 0}</v></c>';
    if (v is num && v.isFinite) return '<c r="$ref"$base><v>$v</v></c>';
    if (v is DateTime && v.year >= 1900) {
      final time = v.hour != 0 || v.minute != 0 || v.second != 0;
      final xf = _xf(cell.style, date: true, time: time);
      return '<c r="$ref"${styled(xf)}><v>${dateSerial(v)}</v></c>';
    }
    final text = v.toString();
    final index = _strings.putIfAbsent(text, () => _strings.length);
    return '<c r="$ref"$base t="s"><v>$index</v></c>';
  }

  String _sheetXml() {
    final b = StringBuffer(_xmlHeader)
      ..write(
        '<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/'
        '2006/main"><sheetViews><sheetView workbookViewId="0"',
      );
    if (rightToLeft) b.write(' rightToLeft="1"');
    final frozen = frozenRows > 0 && _rows.length > frozenRows;
    if (frozen) {
      b.write(
        '><pane ySplit="$frozenRows" topLeftCell="A${frozenRows + 1}" '
        'activePane="bottomLeft" state="frozen"/></sheetView>',
      );
    } else {
      b.write('/>');
    }
    b.write('</sheetViews><sheetFormatPr defaultRowHeight="15"/>');
    if (_widths.isNotEmpty) {
      b.write('<cols>');
      for (final i in _widths.keys.toList()..sort()) {
        b.write(
          '<col min="${i + 1}" max="${i + 1}" '
          'width="${_widths[i]!.toStringAsFixed(2)}" customWidth="1"/>',
        );
      }
      b.write('</cols>');
    }
    b.write('<sheetData>');
    for (var r = 0; r < _rows.length; r++) {
      b.write('<row r="${r + 1}">');
      final row = _rows[r];
      for (var c = 0; c < row.length; c++) {
        b.write(_cell(r, c, row[c]));
      }
      b.write('</row>');
    }
    b.write('</sheetData>');
    if (_autoFilter != null) b.write('<autoFilter ref="$_autoFilter"/>');
    if (_merges.isNotEmpty) {
      b.write('<mergeCells count="${_merges.length}">');
      for (final m in _merges) {
        b.write('<mergeCell ref="$m"/>');
      }
      b.write('</mergeCells>');
    }
    b.write('</worksheet>');
    return b.toString();
  }

  String _sharedStringsXml() {
    final b = StringBuffer(_xmlHeader)
      ..write(
        '<sst xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/'
        'main" count="${_strings.length}" uniqueCount="${_strings.length}">',
      );
    for (final s in _strings.keys) {
      b.write('<si><t xml:space="preserve">${escape(s)}</t></si>');
    }
    b.write('</sst>');
    return b.toString();
  }

  String _stylesXml() {
    const bold = 'applyFont="1"';
    return '$_xmlHeader'
        '<styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/'
        '2006/main">'
        '<numFmts count="2">'
        '<numFmt numFmtId="164" formatCode="yyyy\\-mm\\-dd"/>'
        '<numFmt numFmtId="165" formatCode="yyyy\\-mm\\-dd\\ hh:mm"/>'
        '</numFmts>'
        '<fonts count="3">'
        '<font><sz val="11"/><name val="Calibri"/><family val="2"/></font>'
        '<font><b/><sz val="11"/><name val="Calibri"/><family val="2"/></font>'
        '<font><b/><sz val="11"/><color rgb="FF$headerFontRgb"/>'
        '<name val="Calibri"/><family val="2"/></font>'
        '</fonts>'
        '<fills count="3">'
        '<fill><patternFill patternType="none"/></fill>'
        '<fill><patternFill patternType="gray125"/></fill>'
        '<fill><patternFill patternType="solid">'
        '<fgColor rgb="FF$headerFillRgb"/><bgColor indexed="64"/>'
        '</patternFill></fill>'
        '</fills>'
        '<borders count="1"><border><left/><right/><top/><bottom/>'
        '<diagonal/></border></borders>'
        '<cellStyleXfs count="1">'
        '<xf numFmtId="0" fontId="0" fillId="0" borderId="0"/>'
        '</cellStyleXfs>'
        '<cellXfs count="7">'
        '<xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0"/>'
        '<xf numFmtId="0" fontId="2" fillId="2" borderId="0" xfId="0" '
        '$bold applyFill="1" applyAlignment="1">'
        '<alignment horizontal="center" vertical="center"/></xf>'
        '<xf numFmtId="164" fontId="0" fillId="0" borderId="0" xfId="0" '
        'applyNumberFormat="1"/>'
        '<xf numFmtId="165" fontId="0" fillId="0" borderId="0" xfId="0" '
        'applyNumberFormat="1"/>'
        '<xf numFmtId="0" fontId="1" fillId="0" borderId="0" xfId="0" $bold/>'
        '<xf numFmtId="164" fontId="1" fillId="0" borderId="0" xfId="0" '
        '$bold applyNumberFormat="1"/>'
        '<xf numFmtId="165" fontId="1" fillId="0" borderId="0" xfId="0" '
        '$bold applyNumberFormat="1"/>'
        '</cellXfs>'
        '<cellStyles count="1">'
        '<cellStyle name="Normal" xfId="0" builtinId="0"/></cellStyles>'
        '</styleSheet>';
  }

  static const _xmlHeader =
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n';
  static const _pkg = 'http://schemas.openxmlformats.org/package/2006';
  static const _doc = 'http://schemas.openxmlformats.org/officeDocument/2006';
  static const _ct =
      'application/vnd.openxmlformats-officedocument'
      '.spreadsheetml';

  /// The `.xlsx` file bytes.
  Uint8List encode() {
    // The sheet is built first: it fills the shared strings table.
    final sheet = _sheetXml();
    final files = <String, String>{
      '[Content_Types].xml':
          '$_xmlHeader<Types xmlns="$_pkg/content-types">'
          '<Default Extension="rels" ContentType="application/vnd.'
          'openxmlformats-package.relationships+xml"/>'
          '<Default Extension="xml" ContentType="application/xml"/>'
          '<Override PartName="/xl/workbook.xml" '
          'ContentType="$_ct.sheet.main+xml"/>'
          '<Override PartName="/xl/worksheets/sheet1.xml" '
          'ContentType="$_ct.worksheet+xml"/>'
          '<Override PartName="/xl/styles.xml" '
          'ContentType="$_ct.styles+xml"/>'
          '<Override PartName="/xl/sharedStrings.xml" '
          'ContentType="$_ct.sharedStrings+xml"/>'
          '</Types>',
      '_rels/.rels':
          '$_xmlHeader<Relationships xmlns="$_pkg/relationships">'
          '<Relationship Id="rId1" Type="$_doc/relationships/officeDocument" '
          'Target="xl/workbook.xml"/></Relationships>',
      'xl/workbook.xml':
          '$_xmlHeader<workbook xmlns="http://schemas.openxmlformats.org/'
          'spreadsheetml/2006/main" xmlns:r="$_doc/relationships">'
          '<bookViews><workbookView/></bookViews>'
          '<sheets><sheet name="${escape(sheetName)}" sheetId="1" '
          'r:id="rId1"/></sheets></workbook>',
      'xl/_rels/workbook.xml.rels':
          '$_xmlHeader<Relationships xmlns="$_pkg/relationships">'
          '<Relationship Id="rId1" Type="$_doc/relationships/worksheet" '
          'Target="worksheets/sheet1.xml"/>'
          '<Relationship Id="rId2" Type="$_doc/relationships/styles" '
          'Target="styles.xml"/>'
          '<Relationship Id="rId3" Type="$_doc/relationships/sharedStrings" '
          'Target="sharedStrings.xml"/></Relationships>',
      'xl/styles.xml': _stylesXml(),
      'xl/sharedStrings.xml': _sharedStringsXml(),
      'xl/worksheets/sheet1.xml': sheet,
    };
    final zip = ZipWriter();
    files.forEach((name, xml) => zip.addFile(name, utf8.encode(xml)));
    return zip.encode();
  }
}
