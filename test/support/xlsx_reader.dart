import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

/// Test-only reader: unzips an `.xlsx` (checking every CRC) and exposes the
/// first sheet's cells.
class XlsxFile {
  final Map<String, String> parts;

  XlsxFile._(this.parts);

  factory XlsxFile.decode(Uint8List bytes) {
    final data = ByteData.sublistView(bytes);
    final end = bytes.length - 22;
    if (data.getUint32(end, Endian.little) != 0x06054b50) {
      throw const FormatException('no end of central directory');
    }
    final count = data.getUint16(end + 10, Endian.little);
    var p = data.getUint32(end + 16, Endian.little);
    final parts = <String, String>{};
    for (var i = 0; i < count; i++) {
      if (data.getUint32(p, Endian.little) != 0x02014b50) {
        throw const FormatException('bad central directory entry');
      }
      final method = data.getUint16(p + 10, Endian.little);
      final crc = data.getUint32(p + 16, Endian.little);
      final packed = data.getUint32(p + 20, Endian.little);
      final size = data.getUint32(p + 24, Endian.little);
      final nameLen = data.getUint16(p + 28, Endian.little);
      final extra = data.getUint16(p + 30, Endian.little);
      final comment = data.getUint16(p + 32, Endian.little);
      final local = data.getUint32(p + 42, Endian.little);
      final name = utf8.decode(bytes.sublist(p + 46, p + 46 + nameLen));
      if (data.getUint32(local, Endian.little) != 0x04034b50) {
        throw const FormatException('bad local header');
      }
      final start =
          local +
          30 +
          data.getUint16(local + 26, Endian.little) +
          data.getUint16(local + 28, Endian.little);
      final raw = bytes.sublist(start, start + packed);
      final content = method == 8 ? ZLibCodec(raw: true).decode(raw) : raw;
      if (content.length != size) throw FormatException('size of $name');
      if (_crc32(content) != crc) throw FormatException('crc of $name');
      parts[name] = utf8.decode(content);
      p += 46 + nameLen + extra + comment;
    }
    return XlsxFile._(parts);
  }

  static int _crc32(List<int> data) {
    var c = 0xFFFFFFFF;
    for (final b in data) {
      c ^= b;
      for (var k = 0; k < 8; k++) {
        c = c & 1 != 0 ? 0xEDB88320 ^ (c >>> 1) : c >>> 1;
      }
    }
    return (c ^ 0xFFFFFFFF) & 0xFFFFFFFF;
  }

  static String _unescape(String s) => s
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&amp;', '&');

  String get sheetXml => parts['xl/worksheets/sheet1.xml']!;

  String get sheetName => _unescape(
    RegExp(r'<sheet name="([^"]*)"').firstMatch(parts['xl/workbook.xml']!)![1]!,
  );

  List<String> get sharedStrings => [
    for (final m in RegExp(
      r'<si><t[^>]*>(.*?)</t></si>',
      dotAll: true,
    ).allMatches(parts['xl/sharedStrings.xml']!))
      _unescape(m[1]!),
  ];

  /// Rows of typed values: `String`, `num`, `bool`, or `null` when empty.
  /// Dates come back as their serial number.
  List<Map<String, Object?>> get rows {
    final strings = sharedStrings;
    return [
      for (final row in RegExp(
        r'<row r="\d+">(.*?)</row>',
        dotAll: true,
      ).allMatches(sheetXml))
        {
          for (final c in RegExp(
            r'<c r="([A-Z]+)\d+"([^>]*?)(?:/>|><v>(.*?)</v></c>)',
          ).allMatches(row[1]!))
            c[1]!: c[3] == null
                ? null
                : c[2]!.contains('t="s"')
                ? strings[int.parse(c[3]!)]
                : c[2]!.contains('t="b"')
                ? c[3] == '1'
                : num.parse(c[3]!),
        },
    ];
  }

  /// Style index (`s="…"`) of the cell at [ref], 0 when unstyled.
  int styleOf(String ref) {
    final m = RegExp('<c r="$ref"([^>]*)').firstMatch(sheetXml);
    final s = m == null ? null : RegExp(r's="(\d+)"').firstMatch(m[1]!);
    return s == null ? 0 : int.parse(s[1]!);
  }
}
