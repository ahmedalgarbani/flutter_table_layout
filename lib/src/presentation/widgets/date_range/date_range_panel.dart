import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/labels.dart';
import '../../../core/theme.dart';
import '../../../data/exporters/export_utils.dart';
import 'date_range_preset.dart';

/// Opens the date range panel: a popover anchored to [anchor] on wide
/// screens, a bottom sheet on phones (< 600 px).
///
/// Completes with the chosen range (both `null` = all dates), or `null` when
/// dismissed.
Future<DateRangeSelection?> showTableDateRangePicker({
  required BuildContext context,
  required DateTime? start,
  required DateTime? end,
  required AdaptiveTableTheme theme,
  required AdaptiveTableLabels labels,
  List<DateRangePreset> presets = DateRangePreset.defaults,
  DateTime? firstDate,
  DateTime? lastDate,
  Rect? anchor,
}) {
  final size = MediaQuery.sizeOf(context);
  // [routeContext] must be the context of the dialog / sheet route itself.
  // Popping with the caller's [context] targets the caller's nearest
  // navigator, which is not always the one hosting the popup (e.g. a
  // go_router ShellRoute navigator vs. the root navigator used by
  // showDialog) — that pops the page underneath instead of the panel.
  Widget panel(
    BuildContext routeContext, {
    required bool compact,
    int months = 2,
  }) => DateRangePanel(
    months: months,
    initialStart: start,
    initialEnd: end,
    presets: presets,
    firstDate: firstDate,
    lastDate: lastDate,
    theme: theme,
    labels: labels,
    compact: compact,
    onApply: (s) => Navigator.of(routeContext).pop(s),
  );

  if (size.width < 600) {
    return showModalBottomSheet<DateRangeSelection>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => panel(sheetContext, compact: true),
    );
  }
  return showDialog<DateRangeSelection>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.08),
    builder: (dialogContext) => _AnchoredPopover(
      anchor: anchor,
      textDirection: Directionality.of(context),
      child: panel(
        dialogContext,
        compact: false,
        months: size.width < 820 ? 1 : 2,
      ),
    ),
  );
}

/// Places the panel under (or above) the anchor, aligned to its start edge
/// and kept inside the screen.
class _AnchoredPopover extends StatelessWidget {
  final Rect? anchor;
  final TextDirection textDirection;
  final Widget child;

  const _AnchoredPopover({
    required this.anchor,
    required this.textDirection,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    if (anchor == null) return Center(child: child);
    return CustomSingleChildLayout(
      delegate: _PopoverLayout(anchor!, textDirection),
      child: child,
    );
  }
}

class _PopoverLayout extends SingleChildLayoutDelegate {
  final Rect anchor;
  final TextDirection direction;
  static const double _margin = 8;

  _PopoverLayout(this.anchor, this.direction);

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) {
    final below = constraints.maxHeight - anchor.bottom - _margin * 2;
    final above = anchor.top - _margin * 2;
    return BoxConstraints(
      maxWidth: constraints.maxWidth - _margin * 2,
      maxHeight: math.max(below, above).clamp(200, constraints.maxHeight),
    );
  }

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    var x = direction == TextDirection.rtl
        ? anchor.right - childSize.width
        : anchor.left;
    x = x.clamp(
      _margin,
      math.max(_margin, size.width - childSize.width - _margin),
    );
    var y = anchor.bottom + 6;
    if (y + childSize.height > size.height - _margin) {
      y = math.max(_margin, anchor.top - 6 - childSize.height);
    }
    return Offset(x, y);
  }

  @override
  bool shouldRelayout(_PopoverLayout old) =>
      old.anchor != anchor || old.direction != direction;
}

/// The date range panel: quick presets, a one- or two-month calendar and
/// typed From / To fields.
class DateRangePanel extends StatefulWidget {
  final DateTime? initialStart;
  final DateTime? initialEnd;
  final List<DateRangePreset> presets;
  final DateTime? firstDate;
  final DateTime? lastDate;
  final AdaptiveTableTheme theme;
  final AdaptiveTableLabels labels;

  /// Phone layout: preset chips, one month, full-width actions.
  final bool compact;

  /// Months shown side by side in the wide layout (1 or 2).
  final int months;
  final ValueChanged<DateRangeSelection> onApply;

  const DateRangePanel({
    super.key,
    this.initialStart,
    this.initialEnd,
    this.presets = DateRangePreset.defaults,
    this.firstDate,
    this.lastDate,
    required this.theme,
    required this.labels,
    this.compact = false,
    this.months = 2,
    required this.onApply,
  }) : assert(months == 1 || months == 2);

  @override
  State<DateRangePanel> createState() => _DateRangePanelState();
}

class _DateRangePanelState extends State<DateRangePanel> {
  DateTime? _start;
  DateTime? _end;
  late DateTime _month; // first visible month

  int get _shownMonths => widget.compact ? 1 : widget.months;
  late final TextEditingController _fromCtrl;
  late final TextEditingController _toCtrl;
  String? _fromError;
  String? _toError;
  final DateTime _now = DateTime.now();

  AdaptiveTableTheme get theme => widget.theme;
  AdaptiveTableLabels get labels => widget.labels;
  DateTime get _first => widget.firstDate ?? DateTime(1900);
  DateTime get _last => widget.lastDate ?? DateTime(2200);

  static DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

  @override
  void initState() {
    super.initState();
    _start = widget.initialStart == null ? null : _day(widget.initialStart!);
    _end = widget.initialEnd == null ? null : _day(widget.initialEnd!);
    final focus = _end ?? _start ?? _now;
    // With two months, show the selection's end month on the second one.
    _month = DateTime(focus.year, focus.month - (_shownMonths - 1));
    if (_shownMonths == 2 && _start != null && _end != null) {
      if (_start!.year == _end!.year && _start!.month == _end!.month) {
        _month = DateTime(_end!.year, _end!.month - 1);
      } else {
        _month = DateTime(_start!.year, _start!.month);
      }
    }
    _fromCtrl = TextEditingController(text: _fmt(_start));
    _toCtrl = TextEditingController(text: _fmt(_end));
  }

  @override
  void dispose() {
    _fromCtrl.dispose();
    _toCtrl.dispose();
    super.dispose();
  }

  String _fmt(DateTime? d) => d == null ? '' : ExportUtils.formatDate(d);

  DateRangePreset? get _activePreset {
    for (final p in widget.presets) {
      if (p.matches(_start, _end, _now)) return p;
    }
    return null;
  }

  void _setRange(DateTime? start, DateTime? end, {bool syncText = true}) {
    setState(() {
      _start = start;
      _end = end;
      if (syncText) {
        _fromCtrl.text = _fmt(start);
        _toCtrl.text = _fmt(end);
        _fromError = null;
        _toError = null;
      }
    });
  }

  void _pickPreset(DateRangePreset p) {
    final r = p.range(_now);
    _setRange(r == null ? null : _day(r.start), r == null ? null : _day(r.end));
    if (r != null) {
      final target = DateTime(r.end.year, r.end.month - (_shownMonths - 1));
      setState(() => _month = target);
    }
  }

  void _tapDay(DateTime d) {
    if (_start == null || _end != null || d.isBefore(_start!)) {
      _setRange(d, null);
    } else {
      _setRange(_start, d);
    }
  }

  void _typed(String text, {required bool isStart}) {
    final t = text.trim();
    final parsed = t.isEmpty ? null : DateTime.tryParse(t);
    final valid = t.isEmpty || parsed != null;
    setState(() {
      if (isStart) {
        _fromError = valid ? null : labels.invalidDate;
      } else {
        _toError = valid ? null : labels.invalidDate;
      }
    });
    if (!valid) return;
    final d = parsed == null ? null : _day(parsed);
    if (isStart) {
      _setRange(d, _end, syncText: false);
    } else {
      _setRange(_start, d, syncText: false);
    }
    if (d != null) {
      setState(
        () => _month = DateTime(
          d.year,
          d.month - (isStart ? 0 : _shownMonths - 1),
        ),
      );
    }
  }

  void _apply() {
    if (_fromError != null || _toError != null) return;
    var s = _start;
    var e = _end;
    if (s != null && e == null) e = s;
    if (s == null && e != null) s = e;
    if (s != null && e != null && e.isBefore(s)) {
      final tmp = s;
      s = e;
      e = tmp;
    }
    widget.onApply(DateRangeSelection(s, e));
  }

  // ---------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    return widget.compact ? _buildCompact(context) : _buildWide(context);
  }

  Widget _surface({required Widget child, BorderRadius? radius}) {
    return Material(
      color: theme.cardBackgroundColor.withValues(alpha: 1),
      elevation: 12,
      shadowColor: Colors.black26,
      borderRadius: radius ?? BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }

  Widget _buildWide(BuildContext context) {
    final hasPresets = widget.presets.isNotEmpty;
    return _surface(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: IntrinsicWidth(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (hasPresets) ...[
                      SizedBox(width: 160, child: _presetList()),
                      Container(
                        width: 1,
                        height: 320,
                        margin: const EdgeInsets.symmetric(horizontal: 16),
                        color: theme.dividerColor,
                      ),
                    ],
                    _calendars(months: _shownMonths),
                  ],
                ),
                Divider(height: 24, color: theme.dividerColor),
                Row(
                  children: [
                    SizedBox(width: 170, child: _dateField(isStart: true)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Icon(
                        Icons.arrow_forward,
                        size: 18,
                        color: theme.actionIconColor,
                      ),
                    ),
                    SizedBox(width: 170, child: _dateField(isStart: false)),
                    const Spacer(),
                    TextButton(
                      onPressed: () =>
                          widget.onApply(const DateRangeSelection(null, null)),
                      style: TextButton.styleFrom(
                        foregroundColor: theme.statusNegativeColor,
                      ),
                      child: Text(labels.clear),
                    ),
                    const SizedBox(width: 8),
                    _applyButton(),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCompact(BuildContext context) {
    return _surface(
      radius: const BorderRadius.vertical(top: Radius.circular(20)),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            16,
            10,
            16,
            16 + MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.dividerColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                labels.period,
                style: theme.headerTextStyle.copyWith(fontSize: 16),
              ),
              const SizedBox(height: 10),
              if (widget.presets.isNotEmpty) ...[
                SizedBox(height: 40, child: _presetChips()),
                const SizedBox(height: 12),
              ],
              Center(child: _calendars(months: 1)),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _dateField(isStart: true)),
                  const SizedBox(width: 8),
                  Expanded(child: _dateField(isStart: false)),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  TextButton(
                    onPressed: () =>
                        widget.onApply(const DateRangeSelection(null, null)),
                    style: TextButton.styleFrom(
                      foregroundColor: theme.statusNegativeColor,
                    ),
                    child: Text(labels.clear),
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: _applyButton()),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _applyButton() => FilledButton(
    style: FilledButton.styleFrom(
      backgroundColor: theme.accentColor,
      foregroundColor: theme.onAccentColor,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ),
    onPressed: _fromError == null && _toError == null ? _apply : null,
    child: Text(labels.apply),
  );

  Widget _presetList() {
    final active = _activePreset;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final p in widget.presets)
          _PresetTile(
            label: p.label(labels),
            selected: p == active,
            theme: theme,
            onTap: () => _pickPreset(p),
          ),
        if (active == null && (_start != null || _end != null))
          _PresetTile(
            label: labels.customRange,
            selected: true,
            theme: theme,
            onTap: () {},
          ),
      ],
    );
  }

  Widget _presetChips() {
    final active = _activePreset;
    return ListView(
      scrollDirection: Axis.horizontal,
      children: [
        for (final p in widget.presets)
          Padding(
            padding: const EdgeInsetsDirectional.only(end: 6),
            child: ChoiceChip(
              label: Text(p.label(labels)),
              selected: p == active,
              showCheckmark: false,
              selectedColor: theme.accentColor.withValues(alpha: 0.16),
              labelStyle: theme.rowTextStyle.copyWith(
                fontSize: 13,
                color: p == active ? theme.accentColor : null,
                fontWeight: p == active ? FontWeight.bold : null,
              ),
              side: BorderSide(
                color: p == active ? theme.accentColor : theme.dividerColor,
              ),
              onSelected: (_) => _pickPreset(p),
            ),
          ),
      ],
    );
  }

  Widget _calendars({required int months}) {
    final loc = MaterialLocalizations.of(context);
    final canPrev = !DateTime(
      _month.year,
      _month.month,
    ).isBefore(DateTime(_first.year, _first.month + 1));
    final lastShown = DateTime(_month.year, _month.month + months - 1);
    final canNext = lastShown.isBefore(DateTime(_last.year, _last.month));
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < months; i++) ...[
              if (i > 0) const SizedBox(width: 24),
              _MonthGrid(
                month: DateTime(_month.year, _month.month + i),
                start: _start,
                end: _end,
                first: _day(_first),
                last: _day(_last),
                today: _day(_now),
                theme: theme,
                onTap: _tapDay,
                leading: i == 0
                    ? _NavButton(
                        icon: Icons.chevron_left,
                        tooltip: labels.previousMonth,
                        enabled: canPrev,
                        color: theme.actionIconColor,
                        onPressed: () => setState(
                          () =>
                              _month = DateTime(_month.year, _month.month - 1),
                        ),
                      )
                    : null,
                trailing: i == months - 1
                    ? _NavButton(
                        icon: Icons.chevron_right,
                        tooltip: labels.nextMonth,
                        enabled: canNext,
                        color: theme.actionIconColor,
                        onPressed: () => setState(
                          () =>
                              _month = DateTime(_month.year, _month.month + 1),
                        ),
                      )
                    : null,
                localizations: loc,
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _dateField({required bool isStart}) {
    OutlineInputBorder border(Color c, [double w = 1]) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(color: c, width: w),
    );
    return TextField(
      key: ValueKey(isStart ? 'range-from' : 'range-to'),
      controller: isStart ? _fromCtrl : _toCtrl,
      onChanged: (t) => _typed(t, isStart: isStart),
      onSubmitted: (_) => _apply(),
      style: theme.rowTextStyle.copyWith(fontSize: 13),
      cursorColor: theme.accentColor,
      keyboardType: TextInputType.datetime,
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9\-]'))],
      decoration: InputDecoration(
        isDense: true,
        prefixText: '${isStart ? labels.dateFrom : labels.dateTo}  ',
        prefixStyle: theme.footerTextStyle.copyWith(fontSize: 12),
        hintText: 'yyyy-mm-dd',
        hintStyle: theme.footerTextStyle.copyWith(fontSize: 12),
        errorText: isStart ? _fromError : _toError,
        errorStyle: const TextStyle(fontSize: 10),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 10,
          vertical: 10,
        ),
        border: border(theme.dividerColor),
        enabledBorder: border(theme.dividerColor),
        focusedBorder: border(theme.accentColor, 1.5),
      ),
    );
  }
}

class _PresetTile extends StatelessWidget {
  final String label;
  final bool selected;
  final AdaptiveTableTheme theme;
  final VoidCallback onTap;

  const _PresetTile({
    required this.label,
    required this.selected,
    required this.theme,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Material(
        color: selected
            ? theme.accentColor.withValues(alpha: 0.12)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            child: Text(
              label,
              style: theme.rowTextStyle.copyWith(
                fontSize: 13,
                fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                color: selected ? theme.accentColor : null,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final bool enabled;
  final Color color;
  final VoidCallback onPressed;

  const _NavButton({
    required this.icon,
    required this.tooltip,
    required this.enabled,
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: tooltip,
    visualDensity: VisualDensity.compact,
    iconSize: 20,
    color: color,
    onPressed: enabled ? onPressed : null,
    icon: Icon(icon),
  );
}

/// One month of the range calendar.
class _MonthGrid extends StatelessWidget {
  final DateTime month;
  final DateTime? start;
  final DateTime? end;
  final DateTime first;
  final DateTime last;
  final DateTime today;
  final AdaptiveTableTheme theme;
  final ValueChanged<DateTime> onTap;
  final Widget? leading;
  final Widget? trailing;
  final MaterialLocalizations localizations;

  const _MonthGrid({
    required this.month,
    required this.start,
    required this.end,
    required this.first,
    required this.last,
    required this.today,
    required this.theme,
    required this.onTap,
    required this.localizations,
    this.leading,
    this.trailing,
  });

  static const double _cell = 38;

  @override
  Widget build(BuildContext context) {
    final loc = localizations;
    final firstWeekday = loc.firstDayOfWeekIndex; // 0 = Sunday
    final daysIn = DateTime(month.year, month.month + 1, 0).day;
    final lead =
        (DateTime(month.year, month.month).weekday % 7 - firstWeekday + 7) % 7;
    final cells = <DateTime?>[
      for (var i = 0; i < lead; i++) null,
      for (var d = 1; d <= daysIn; d++) DateTime(month.year, month.month, d),
    ];
    while (cells.length % 7 != 0) {
      cells.add(null);
    }
    final weekdays = [
      for (var i = 0; i < 7; i++) loc.narrowWeekdays[(firstWeekday + i) % 7],
    ];
    final accent = theme.accentColor;
    final hasRange = start != null && end != null;

    return SizedBox(
      width: _cell * 7,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 40,
            child: Row(
              children: [
                SizedBox(width: 40, child: leading),
                Expanded(
                  child: Text(
                    loc.formatMonthYear(month),
                    textAlign: TextAlign.center,
                    style: theme.headerTextStyle.copyWith(fontSize: 14),
                  ),
                ),
                SizedBox(width: 40, child: trailing),
              ],
            ),
          ),
          Row(
            children: [
              for (final w in weekdays)
                SizedBox(
                  width: _cell,
                  height: 28,
                  child: Center(
                    child: Text(
                      w,
                      style: theme.footerTextStyle.copyWith(fontSize: 12),
                    ),
                  ),
                ),
            ],
          ),
          for (var r = 0; r < cells.length ~/ 7; r++)
            Row(
              children: [
                for (var c = 0; c < 7; c++)
                  _dayCell(context, cells[r * 7 + c], accent, hasRange),
              ],
            ),
          // Keep every month the same height (6 rows).
          for (var r = cells.length ~/ 7; r < 6; r++)
            const SizedBox(height: _cell),
        ],
      ),
    );
  }

  Widget _dayCell(
    BuildContext context,
    DateTime? d,
    Color accent,
    bool hasRange,
  ) {
    if (d == null) return const SizedBox(width: _cell, height: _cell);
    final disabled = d.isBefore(first) || d.isAfter(last);
    final isStart = d == start;
    final isEnd = d == end;
    final isEdge = isStart || isEnd;
    final inRange =
        hasRange && !d.isBefore(start!) && !d.isAfter(end!) && start != end;
    final rtl = Directionality.of(context) == TextDirection.rtl;

    // Range band: full between the ends, half on the start / end cells.
    Widget band = const SizedBox.expand();
    if (inRange) {
      final color = accent.withValues(alpha: 0.12);
      if (isStart || isEnd) {
        final towardsEnd = isStart; // start: band continues to the "end" side
        final alignRight = towardsEnd != rtl;
        band = Align(
          alignment: alignRight ? Alignment.centerRight : Alignment.centerLeft,
          child: FractionallySizedBox(
            widthFactor: 0.5,
            heightFactor: 0.84,
            child: ColoredBox(color: color),
          ),
        );
      } else {
        band = FractionallySizedBox(
          heightFactor: 0.84,
          child: ColoredBox(color: color),
        );
      }
    }

    final isToday = d == today;
    final label = localizations.formatDecimal(d.day);
    return SizedBox(
      width: _cell,
      height: _cell,
      child: Stack(
        fit: StackFit.expand,
        children: [
          band,
          Center(
            child: Semantics(
              button: !disabled,
              selected: isEdge,
              label: localizations.formatFullDate(d),
              excludeSemantics: true,
              child: InkResponse(
                radius: 18,
                onTap: disabled ? null : () => onTap(d),
                child: Container(
                  width: 34,
                  height: 34,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: isEdge ? accent : null,
                    shape: BoxShape.circle,
                    border: isToday && !isEdge
                        ? Border.all(color: accent, width: 1.2)
                        : null,
                  ),
                  child: Text(
                    label,
                    style: theme.rowTextStyle.copyWith(
                      fontSize: 13,
                      fontWeight: isEdge ? FontWeight.bold : null,
                      color: disabled
                          ? theme.actionIconColor.withValues(alpha: 0.3)
                          : isEdge
                          ? theme.onAccentColor
                          : (inRange ? accent : null),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
