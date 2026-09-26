import 'package:flutter/material.dart';

import '../../../core/labels.dart';

/// How the date filter is shown in the filter bar.
enum DateFilterStyle {
  /// One "Period" button opening a panel with presets, a calendar and typed
  /// From / To fields (a bottom sheet on phones). Default.
  rangePicker,

  /// The legacy two separate From / To date buttons.
  separateFields,
}

/// A date range chosen in the date panel. Both `null` means "all dates".
@immutable
class DateRangeSelection {
  final DateTime? start;
  final DateTime? end;
  const DateRangeSelection(this.start, this.end);

  bool get isEmpty => start == null && end == null;
}

/// A quick period in the date panel ("Today", "This month"…).
///
/// ```dart
/// DateRangePreset(
///   id: 'quarter',
///   label: (l) => 'This quarter',
///   range: (now) {
///     final q = (now.month - 1) ~/ 3;
///     return DateTimeRange(
///       start: DateTime(now.year, q * 3 + 1),
///       end: DateTime(now.year, q * 3 + 4, 0),
///     );
///   },
/// )
/// ```
@immutable
class DateRangePreset {
  /// Unique id of the preset.
  final String id;

  /// Label shown in the panel and on the button.
  final String Function(AdaptiveTableLabels labels) label;

  /// Range for "now". `null` means all dates (no filter).
  final DateTimeRange? Function(DateTime now) range;

  const DateRangePreset({
    required this.id,
    required this.label,
    required this.range,
  });

  static DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

  static const DateRangePreset all = DateRangePreset(
    id: 'all',
    label: _allLabel,
    range: _allRange,
  );
  static const DateRangePreset today = DateRangePreset(
    id: 'today',
    label: _todayLabel,
    range: _todayRange,
  );
  static const DateRangePreset yesterday = DateRangePreset(
    id: 'yesterday',
    label: _yesterdayLabel,
    range: _yesterdayRange,
  );
  static const DateRangePreset last7Days = DateRangePreset(
    id: 'last7Days',
    label: _last7Label,
    range: _last7Range,
  );
  static const DateRangePreset last30Days = DateRangePreset(
    id: 'last30Days',
    label: _last30Label,
    range: _last30Range,
  );
  static const DateRangePreset thisMonth = DateRangePreset(
    id: 'thisMonth',
    label: _thisMonthLabel,
    range: _thisMonthRange,
  );
  static const DateRangePreset lastMonth = DateRangePreset(
    id: 'lastMonth',
    label: _lastMonthLabel,
    range: _lastMonthRange,
  );
  static const DateRangePreset thisYear = DateRangePreset(
    id: 'thisYear',
    label: _thisYearLabel,
    range: _thisYearRange,
  );

  /// The presets shown when `datePresets` is not set.
  static const List<DateRangePreset> defaults = [
    all,
    today,
    yesterday,
    last7Days,
    last30Days,
    thisMonth,
    lastMonth,
    thisYear,
  ];

  /// Whether this preset currently equals [start]..[end] (by calendar day).
  bool matches(DateTime? start, DateTime? end, DateTime now) {
    final r = range(now);
    if (r == null) return start == null && end == null;
    if (start == null || end == null) return false;
    return _day(r.start) == _day(start) && _day(r.end) == _day(end);
  }

  static String _allLabel(AdaptiveTableLabels l) => l.allDates;
  static String _todayLabel(AdaptiveTableLabels l) => l.today;
  static String _yesterdayLabel(AdaptiveTableLabels l) => l.yesterday;
  static String _last7Label(AdaptiveTableLabels l) => l.last7Days;
  static String _last30Label(AdaptiveTableLabels l) => l.last30Days;
  static String _thisMonthLabel(AdaptiveTableLabels l) => l.thisMonth;
  static String _lastMonthLabel(AdaptiveTableLabels l) => l.lastMonth;
  static String _thisYearLabel(AdaptiveTableLabels l) => l.thisYear;

  static DateTimeRange? _allRange(DateTime now) => null;
  static DateTimeRange _todayRange(DateTime now) =>
      DateTimeRange(start: _day(now), end: _day(now));
  static DateTimeRange _yesterdayRange(DateTime now) {
    final d = _day(now).subtract(const Duration(days: 1));
    return DateTimeRange(start: d, end: d);
  }

  static DateTimeRange _last7Range(DateTime now) => DateTimeRange(
    start: _day(now).subtract(const Duration(days: 6)),
    end: _day(now),
  );
  static DateTimeRange _last30Range(DateTime now) => DateTimeRange(
    start: _day(now).subtract(const Duration(days: 29)),
    end: _day(now),
  );
  static DateTimeRange _thisMonthRange(DateTime now) => DateTimeRange(
    start: DateTime(now.year, now.month),
    end: DateTime(now.year, now.month + 1, 0),
  );
  static DateTimeRange _lastMonthRange(DateTime now) => DateTimeRange(
    start: DateTime(now.year, now.month - 1),
    end: DateTime(now.year, now.month, 0),
  );
  static DateTimeRange _thisYearRange(DateTime now) =>
      DateTimeRange(start: DateTime(now.year), end: DateTime(now.year, 12, 31));
}
