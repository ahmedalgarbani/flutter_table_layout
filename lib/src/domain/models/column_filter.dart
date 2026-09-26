/// Evaluates the per-column filter expressions typed in the filter row.
///
/// Supported syntax (whitespace is ignored around operators):
///
/// | Expression   | Meaning                                   |
/// |--------------|-------------------------------------------|
/// | `acme`       | contains (case-insensitive)               |
/// | `=acme`      | equals (case-insensitive)                 |
/// | `!=acme`     | not equal                                 |
/// | `!acme`      | does not contain                          |
/// | `>100`       | greater than (numbers, dates, text)       |
/// | `>=100`      | greater than or equal                     |
/// | `<100`       | less than                                 |
/// | `<=100`      | less than or equal                        |
/// | `10..20`     | inclusive range                           |
/// | `a, b, c`    | any of (OR) – each part can use the above |
///
/// Dates can be written as `yyyy-MM-dd` (e.g. `>=2026-01-01`).
class ColumnFilterMatcher {
  const ColumnFilterMatcher._();

  /// Whether [value] satisfies [expression]. An empty expression matches all.
  static bool matches(Object? value, String expression) {
    final expr = expression.trim();
    if (expr.isEmpty) return true;
    final parts = expr.split(RegExp(r'\s*[,|]\s*')).where((p) => p.isNotEmpty);
    return parts.any((p) => _matchesSingle(value, p));
  }

  static bool _matchesSingle(Object? value, String expr) {
    final range = RegExp(r'^(.+?)\s*\.\.\s*(.+)$').firstMatch(expr);
    if (range != null) {
      return _compare(value, range.group(1)!) >= 0 &&
          _compare(value, range.group(2)!) <= 0;
    }
    final op = RegExp(r'^(>=|<=|!=|>|<|=|!)\s*(.*)$').firstMatch(expr);
    if (op == null) return _text(value).contains(expr.toLowerCase());
    final operand = op.group(2)!;
    if (operand.isEmpty) return true;
    switch (op.group(1)) {
      case '>':
        return value != null && _compare(value, operand) > 0;
      case '>=':
        return value != null && _compare(value, operand) >= 0;
      case '<':
        return value != null && _compare(value, operand) < 0;
      case '<=':
        return value != null && _compare(value, operand) <= 0;
      case '=':
        return _compare(value, operand) == 0;
      case '!=':
        return _compare(value, operand) != 0;
      case '!':
        return !_text(value).contains(operand.toLowerCase());
    }
    return true;
  }

  static String _text(Object? value) {
    if (value == null) return '';
    if (value is DateTime) return _date(value);
    return value.toString().toLowerCase();
  }

  static String _date(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  /// Compares a cell value with a typed operand using the cell's type.
  static int _compare(Object? value, String operand) {
    final o = operand.trim();
    if (value == null) return o.isEmpty ? 0 : -1;
    if (value is num) {
      final n = num.tryParse(o.replaceAll(',', ''));
      if (n != null) return value.compareTo(n);
    } else if (value is DateTime) {
      final d = DateTime.tryParse(o);
      if (d != null) {
        final day = DateTime(value.year, value.month, value.day);
        return day.compareTo(DateTime(d.year, d.month, d.day));
      }
    } else if (value is bool) {
      final b = switch (o.toLowerCase()) {
        'true' || 'yes' || '1' || '✓' => true,
        'false' || 'no' || '0' || '✗' => false,
        _ => null,
      };
      if (b != null) return value == b ? 0 : (value ? 1 : -1);
    }
    return _text(value).compareTo(o.toLowerCase());
  }
}
