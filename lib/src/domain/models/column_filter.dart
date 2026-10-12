import '../utils/table_text_normalizer.dart';

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
/// * Dates can be written as `yyyy-MM-dd` (e.g. `>=2026-01-01`).
/// * Numbers may use thousands separators (`>=1,500`); a comma followed by
///   exactly three digits is part of the number, any other comma, `|` or the
///   Arabic comma `،` separates alternatives.
/// * Arabic-Indic digits are accepted (`>١٠٠`).
/// * Text comparisons go through a [TextNormalizer] (by default
///   [TableTextNormalizer.normalize]), and "contains" / "equals" also match
///   the displayed text of the cell when one is given.
///
/// Parse an expression once with [ColumnFilterMatcher.parse] and call [test]
/// for every row, or use the one-shot [matches].
class ColumnFilterMatcher {
  final List<_Clause> _clauses;
  final TextNormalizer _normalize;

  ColumnFilterMatcher._(this._clauses, this._normalize);

  /// Compiles [expression]. An empty expression matches every value.
  factory ColumnFilterMatcher.parse(
    String expression, {
    TextNormalizer normalize = TableTextNormalizer.normalize,
  }) {
    final expr = TableTextNormalizer.digitsToAscii(expression.trim());
    final clauses = <_Clause>[
      if (expr.isNotEmpty)
        for (final part in expr.split(_separators))
          if (part.isNotEmpty) _Clause.parse(part, normalize),
    ];
    return ColumnFilterMatcher._(clauses, normalize);
  }

  /// Whether [value] satisfies [expression]. An empty expression matches all.
  ///
  /// [displayText] is the text shown in the cell (e.g. a formatted amount or
  /// date); "contains" and "equals" also look at it.
  static bool matches(
    Object? value,
    String expression, {
    String? displayText,
    TextNormalizer normalize = TableTextNormalizer.normalize,
  }) {
    return ColumnFilterMatcher.parse(
      expression,
      normalize: normalize,
    ).test(value, displayText == null ? null : () => displayText);
  }

  /// Whether the expression matches nothing in particular (always `true`).
  bool get isEmpty => _clauses.isEmpty;

  /// Whether [value] satisfies the compiled expression. [display] lazily
  /// returns the displayed text of the cell, if any.
  bool test(Object? value, [String? Function()? display]) {
    if (_clauses.isEmpty) return true;
    String? shown;
    var shownResolved = false;
    String? displayed() {
      if (!shownResolved) {
        shownResolved = true;
        final raw = display?.call();
        shown = raw == null ? null : _normalize(raw);
      }
      return shown;
    }

    for (final clause in _clauses) {
      if (clause.matches(value, _normalize, displayed)) return true;
    }
    return false;
  }

  /// `|`, the Arabic comma, or a comma that is not a thousands separator.
  static final _separators = RegExp(
    r'\s*(?:[|،]|(?<!\d),|,(?!\d{3}(?!\d)))\s*',
  );

  static final _range = RegExp(r'^(.+?)\s*\.\.\s*(.+)$');
  static final _operator = RegExp(r'^(>=|<=|!=|>|<|=|!)\s*(.*)$');

  static String _text(Object? value) {
    if (value == null) return '';
    if (value is DateTime) return _date(value);
    return value.toString();
  }

  static String _date(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}

/// A typed operand, parsed once.
class _Operand {
  /// Normalized text (for text comparisons).
  final String text;
  final num? number;
  final DateTime? day;
  final bool? boolean;

  _Operand(String raw, TextNormalizer normalize)
    : text = normalize(raw.trim()),
      number = num.tryParse(raw.trim().replaceAll(',', '')),
      day = _parseDay(raw.trim()),
      boolean = switch (raw.trim().toLowerCase()) {
        'true' || 'yes' || '1' || '✓' => true,
        'false' || 'no' || '0' || '✗' => false,
        _ => null,
      };

  static DateTime? _parseDay(String s) {
    final d = DateTime.tryParse(s);
    return d == null ? null : DateTime(d.year, d.month, d.day);
  }

  /// Compares a cell value with the operand using the cell's type.
  int compare(Object? value, TextNormalizer normalize) {
    if (value == null) return text.isEmpty ? 0 : -1;
    final n = number;
    if (value is num && n != null) return value.compareTo(n);
    final d = day;
    if (value is DateTime && d != null) {
      return DateTime(value.year, value.month, value.day).compareTo(d);
    }
    final b = boolean;
    if (value is bool && b != null) return value == b ? 0 : (value ? 1 : -1);
    return normalize(ColumnFilterMatcher._text(value)).compareTo(text);
  }
}

sealed class _Clause {
  const _Clause();

  factory _Clause.parse(String expr, TextNormalizer normalize) {
    final range = ColumnFilterMatcher._range.firstMatch(expr);
    if (range != null) {
      return _RangeClause(
        _Operand(range.group(1)!, normalize),
        _Operand(range.group(2)!, normalize),
      );
    }
    final op = ColumnFilterMatcher._operator.firstMatch(expr);
    if (op == null) return _ContainsClause(normalize(expr), negate: false);
    final operand = op.group(2)!;
    if (operand.trim().isEmpty) return const _AnyClause();
    return switch (op.group(1)!) {
      '!' => _ContainsClause(normalize(operand.trim()), negate: true),
      final symbol => _CompareClause(symbol, _Operand(operand, normalize)),
    };
  }

  bool matches(
    Object? value,
    TextNormalizer normalize,
    String? Function() displayed,
  );
}

/// An operator without operand (e.g. a lone `>` while typing).
class _AnyClause extends _Clause {
  const _AnyClause();

  @override
  bool matches(Object? value, TextNormalizer normalize, _) => true;
}

class _ContainsClause extends _Clause {
  final String needle;
  final bool negate;

  const _ContainsClause(this.needle, {required this.negate});

  @override
  bool matches(
    Object? value,
    TextNormalizer normalize,
    String? Function() displayed,
  ) {
    final found =
        normalize(ColumnFilterMatcher._text(value)).contains(needle) ||
        (displayed()?.contains(needle) ?? false);
    return negate ? !found : found;
  }
}

class _RangeClause extends _Clause {
  final _Operand from;
  final _Operand to;

  const _RangeClause(this.from, this.to);

  @override
  bool matches(Object? value, TextNormalizer normalize, _) =>
      from.compare(value, normalize) >= 0 && to.compare(value, normalize) <= 0;
}

class _CompareClause extends _Clause {
  final String symbol;
  final _Operand operand;

  const _CompareClause(this.symbol, this.operand);

  bool _equals(
    Object? value,
    TextNormalizer normalize,
    String? Function() displayed,
  ) =>
      operand.compare(value, normalize) == 0 ||
      (value != null && displayed() == operand.text);

  @override
  bool matches(
    Object? value,
    TextNormalizer normalize,
    String? Function() displayed,
  ) {
    return switch (symbol) {
      '>' => value != null && operand.compare(value, normalize) > 0,
      '>=' => value != null && operand.compare(value, normalize) >= 0,
      '<' => value != null && operand.compare(value, normalize) < 0,
      '<=' => value != null && operand.compare(value, normalize) <= 0,
      '=' => _equals(value, normalize, displayed),
      '!=' => !_equals(value, normalize, displayed),
      _ => true,
    };
  }
}
