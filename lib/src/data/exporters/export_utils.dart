import '../../domain/models/column_definition.dart';

/// Converts any cell value into the text written to PDF / Word exports.
typedef ExportValueFormatter = String Function(dynamic value);

/// Helpers shared by the exporters.
class ExportUtils {
  const ExportUtils._();

  /// Columns that should be written to an export: visible, exportable, and not
  /// hidden by the user.
  static List<ColumnDefinition> exportableColumns(
    List<ColumnDefinition> columns, {
    Iterable<String> hiddenColumnIds = const [],
  }) {
    final hidden = hiddenColumnIds.toSet();
    return columns
        .where((c) => c.isVisible && c.isExportable && !hidden.contains(c.id))
        .toList();
  }

  /// Default textual representation of a cell value.
  ///
  /// * `null` → empty string
  /// * `DateTime` → `yyyy-MM-dd` (plus `HH:mm` when it has a time part)
  /// * `double` → without a useless trailing `.0`
  /// * `bool` → `✓` / `✗`
  static String formatValue(dynamic value) {
    if (value == null) return '';
    if (value is DateTime) return formatDate(value);
    if (value is double) {
      if (value == value.truncateToDouble() && value.abs() < 1e15) {
        return value.toInt().toString();
      }
      return value.toString();
    }
    if (value is bool) return value ? '✓' : '✗';
    return value.toString();
  }

  /// `yyyy-MM-dd` or `yyyy-MM-dd HH:mm`.
  static String formatDate(DateTime d) {
    String two(int v) => v.toString().padLeft(2, '0');
    final date = '${d.year}-${two(d.month)}-${two(d.day)}';
    if (d.hour == 0 && d.minute == 0 && d.second == 0) return date;
    return '$date ${two(d.hour)}:${two(d.minute)}';
  }

  /// Turns an arbitrary title into a safe file name (keeps Unicode letters so
  /// Arabic titles still work) and appends [extension].
  static String sanitizeFileName(
    String? name, {
    required String extension,
    String fallback = 'report',
  }) {
    var base = (name ?? '')
        .replaceAll(RegExp(r'[\\/:*?"<>|\x00-\x1F]'), '')
        .trim()
        .replaceAll(RegExp(r'\s+'), '_');
    while (base.startsWith('.')) {
      base = base.substring(1);
    }
    if (base.isEmpty) base = fallback;
    if (base.length > 100) base = base.substring(0, 100);
    final ext = extension.startsWith('.') ? extension : '.$extension';
    return '$base$ext';
  }

  /// Minimal HTML escaping for text inserted into the Word document.
  static String escapeHtml(String input) {
    final buffer = StringBuffer();
    for (final rune in input.runes) {
      switch (rune) {
        case 0x26:
          buffer.write('&amp;');
        case 0x3C:
          buffer.write('&lt;');
        case 0x3E:
          buffer.write('&gt;');
        case 0x22:
          buffer.write('&quot;');
        case 0x27:
          buffer.write('&#39;');
        case 0x0A:
          buffer.write('<br>');
        default:
          buffer.writeCharCode(rune);
      }
    }
    return buffer.toString();
  }
}
