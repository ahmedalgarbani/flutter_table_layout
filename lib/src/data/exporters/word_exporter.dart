import 'dart:convert';
import 'dart:typed_data';

import '../../domain/models/column_definition.dart';
import 'export_utils.dart';

/// Exporter responsible for generating Word-readable documents (.doc)
/// using an HTML table template with custom CSS styling.
///
/// Every value and title is HTML-escaped, so content such as `<`, `&` or
/// quotes can't break the document.
class WordExporter {
  const WordExporter();

  /// Generates the raw document bytes containing HTML.
  Future<Uint8List> generateWord<T>({
    required String title,
    String? subtitle,
    required List<ColumnDefinition> columns,
    required List<T> items,
    required Map<String, dynamic Function(T)> valueProviders,
    bool isRtl = false,
    Iterable<String> hiddenColumnIds = const [],
    Map<String, ExportValueFormatter>? formatters,
    String exportedOnLabel = 'Exported',
    String accentColor = '#1565C0',
  }) async {
    final esc = ExportUtils.escapeHtml;
    final visibleCols = ExportUtils.exportableColumns(
      columns,
      hiddenColumnIds: hiddenColumnIds,
    );
    final dir = isRtl ? 'rtl' : 'ltr';
    final align = isRtl ? 'right' : 'left';

    final buffer = StringBuffer()
      ..write('''
<html xmlns:o="urn:schemas-microsoft-com:office:office"
      xmlns:w="urn:schemas-microsoft-com:office:word"
      xmlns="http://www.w3.org/TR/REC-html40" dir="$dir">
<head>
  <meta http-equiv="Content-Type" content="text/html; charset=utf-8">
  <meta charset="utf-8">
  <title>${esc(title)}</title>
  <style>
    body { font-family: 'Segoe UI', Tahoma, Arial, sans-serif; margin: 40px; direction: $dir; }
    .header { margin-bottom: 20px; border-bottom: 2px solid $accentColor; padding-bottom: 10px; }
    h1 { color: $accentColor; font-size: 24px; margin: 0 0 5px 0; }
    h2 { color: #555555; font-size: 14px; margin: 0 0 15px 0; font-weight: normal; }
    table { width: 100%; border-collapse: collapse; margin-top: 20px; direction: $dir; }
    th { background-color: $accentColor; color: white; padding: 12px 10px; border: 1px solid #E0E0E0; text-align: $align; font-weight: bold; }
    td { padding: 10px; border: 1px solid #E0E0E0; text-align: $align; color: #333333; }
    tr:nth-child(even) { background-color: #F5F5F5; }
  </style>
</head>
<body>
  <div class="header">
    <h1>${esc(title)}</h1>
''');
    if (subtitle != null && subtitle.isNotEmpty) {
      buffer.write('    <h2>${esc(subtitle)}</h2>\n');
    }
    buffer
      ..write(
        '    <p style="font-size: 11px; color: #888888;">'
        '${esc(exportedOnLabel)}: ${ExportUtils.formatDate(DateTime.now())}</p>\n',
      )
      ..write('  </div>\n  <table>\n    <thead>\n      <tr>\n');

    for (final col in visibleCols) {
      buffer.write('        <th>${esc(col.title)}</th>\n');
    }
    buffer.write('      </tr>\n    </thead>\n    <tbody>\n');

    for (final item in items) {
      buffer.write('      <tr>\n');
      for (final col in visibleCols) {
        final raw = valueProviders[col.id]?.call(item);
        final text = (formatters?[col.id] ?? ExportUtils.formatValue)(raw);
        buffer.write('        <td>${esc(text)}</td>\n');
      }
      buffer.write('      </tr>\n');
    }

    buffer.write('    </tbody>\n  </table>\n</body>\n</html>\n');
    return Uint8List.fromList(utf8.encode(buffer.toString()));
  }
}
