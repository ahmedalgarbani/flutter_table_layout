import 'dart:convert';
import 'dart:typed_data';
import '../../domain/models/column_definition.dart';

/// Exporter responsible for generating Word-readable documents (.doc)
/// using an HTML table template with custom CSS styling.
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
  }) async {
    final visibleCols = columns.where((c) => c.isVisible).toList();

    // Build the HTML representation
    final buffer = StringBuffer();
    buffer.write('''
<html xmlns:o="urn:schemas-microsoft-com:office:office" 
      xmlns:w="urn:schemas-microsoft-com:office:word" 
      xmlns="http://www.w3.org/TR/REC-html40">
<head>
  <meta charset="utf-8">
  <title>$title</title>
  <style>
    body { 
      font-family: 'Segoe UI', Arial, sans-serif; 
      margin: 40px;
      direction: ${isRtl ? 'rtl' : 'ltr'};
    }
    .header {
      margin-bottom: 20px;
      border-bottom: 2px solid #1565C0;
      padding-bottom: 10px;
    }
    h1 {
      color: #1565C0;
      font-size: 24px;
      margin: 0 0 5px 0;
    }
    h2 {
      color: #555555;
      font-size: 14px;
      margin: 0 0 15px 0;
      font-weight: normal;
    }
    table { 
      width: 100%; 
      border-collapse: collapse; 
      margin-top: 20px;
      direction: ${isRtl ? 'rtl' : 'ltr'};
    }
    th { 
      background-color: #1565C0; 
      color: white; 
      padding: 12px 10px; 
      border: 1px solid #E0E0E0; 
      text-align: ${isRtl ? 'right' : 'left'};
      font-weight: bold;
    }
    td { 
      padding: 10px; 
      border: 1px solid #E0E0E0; 
      text-align: ${isRtl ? 'right' : 'left'};
      color: #333333;
    }
    tr:nth-child(even) { 
      background-color: #F5F5F5; 
    }
  </style>
</head>
<body>
  <div class="header">
    <h1>$title</h1>
    ${subtitle != null ? '<h2>$subtitle</h2>' : ''}
    <p style="font-size: 11px; color: #888888;">Exported: ${DateTime.now().toString().split(' ').first}</p>
  </div>
  <table>
    <thead>
      <tr>
''');

    for (final col in visibleCols) {
      buffer.write('        <th>${col.title}</th>\n');
    }

    buffer.write('''      </tr>
    </thead>
    <tbody>
''');

    for (final item in items) {
      buffer.write('      <tr>\n');
      for (final col in visibleCols) {
        final extractor = valueProviders[col.id];
        final val = extractor != null ? extractor(item) : '';
        buffer.write('        <td>${val?.toString() ?? ''}</td>\n');
      }
      buffer.write('      </tr>\n');
    }

    buffer.write('''    </tbody>
  </table>
</body>
</html>
''');

    final bytes = utf8.encode(buffer.toString());
    return Uint8List.fromList(bytes);
  }
}
