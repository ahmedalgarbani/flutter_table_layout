import '../usecases/filter_items_usecase.dart';

/// A built-in footer aggregate of a column (see `AdaptiveTableColumn.aggregate`).
///
/// Aggregates are shown in a totals row under the grid (and at the end of
/// the card list on phones), and written to exports.
enum TableAggregate {
  /// Sum of the numeric values (`0` when there are none).
  sum,

  /// Arithmetic mean of the numeric values (`null` when there are none).
  average,

  /// Smallest value: numbers, dates or text.
  min,

  /// Largest value: numbers, dates or text.
  max,

  /// Number of non-empty values.
  count;

  /// Computes the aggregate of [values]. `null` and blank values are ignored.
  Object? compute(Iterable<Object?> values) {
    switch (this) {
      case TableAggregate.sum:
        num total = 0;
        for (final v in values) {
          if (v is num) total += v;
        }
        return total;
      case TableAggregate.average:
        num total = 0;
        var n = 0;
        for (final v in values) {
          if (v is num) {
            total += v;
            n++;
          }
        }
        return n == 0 ? null : total / n;
      case TableAggregate.min:
      case TableAggregate.max:
        final sign = this == TableAggregate.min ? 1 : -1;
        Object? best;
        for (final v in values) {
          if (_isBlank(v)) continue;
          if (best == null ||
              sign * FilterItemsUseCase.compareCellValues(v, best) < 0) {
            best = v;
          }
        }
        return best;
      case TableAggregate.count:
        return values.where((v) => !_isBlank(v)).length;
    }
  }

  static bool _isBlank(Object? v) =>
      v == null || (v is String && v.trim().isEmpty);
}
