import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_table_layout/flutter_table_layout.dart';
import 'package:flutter_test/flutter_test.dart';

class Sale {
  final int id;
  final DateTime date;
  const Sale(this.id, this.date);
}

DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

/// Sales on each of the last 90 days (id 0 = today).
List<Sale> _sales() {
  final today = _day(DateTime.now());
  return [
    for (var i = 0; i < 90; i++) Sale(i, today.subtract(Duration(days: i))),
  ];
}

Widget _table({
  VoidCallback? onQuery,
  DateFilterStyle style = DateFilterStyle.rangePicker,
  List<DateRangePreset>? presets,
  AdaptiveTableController<Sale>? controller,
}) => AdaptiveTableLayout<Sale>(
  items: _sales(),
  controller: controller,
  showPagination: false,
  columns: [
    AdaptiveTableColumn(id: 'id', title: 'ID'),
    AdaptiveTableColumn(id: 'date', title: 'Date'),
  ],
  valueProviders: {'id': (s) => s.id, 'date': (s) => s.date},
  dateProvider: (s) => s.date,
  onQueryPressed: onQuery,
  dateFilterStyle: style,
  datePresets: presets,
);

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  Size size = const Size(1280, 1000),
  Locale locale = const Locale('en'),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      locale: locale,
      supportedLocales: const [Locale('en'), Locale('ar')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: Scaffold(body: SingleChildScrollView(child: child)),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('DateRangePreset', () {
    test('ranges', () {
      final now = DateTime(2026, 1, 15, 13, 30);
      final m = DateRangePreset.thisMonth.range(now)!;
      expect(m.start, DateTime(2026, 1, 1));
      expect(m.end, DateTime(2026, 1, 31));
      final lm = DateRangePreset.lastMonth.range(now)!;
      expect(lm.start, DateTime(2025, 12, 1));
      expect(lm.end, DateTime(2025, 12, 31));
      final w = DateRangePreset.last7Days.range(now)!;
      expect(w.start, DateTime(2026, 1, 9));
      expect(w.end, DateTime(2026, 1, 15));
      expect(DateRangePreset.all.range(now), isNull);
      expect(
        DateRangePreset.today.matches(
          DateTime(2026, 1, 15, 8),
          DateTime(2026, 1, 15),
          now,
        ),
        isTrue,
      );
    });
  });

  testWidgets('one button opens a popover; a preset filters the rows', (
    tester,
  ) async {
    final controller = AdaptiveTableController<Sale>();
    await _pump(tester, _table(controller: controller));
    expect(find.text('All dates'), findsOneWidget);
    expect(controller.filteredItems.length, 90);

    await tester.tap(find.text('All dates'));
    await tester.pumpAndSettle();
    // Presets + two months + typed fields.
    expect(find.text('Last 7 days'), findsOneWidget);
    expect(find.text('Apply'), findsOneWidget);
    expect(find.byType(BottomSheet), findsNothing);

    await tester.tap(find.text('Last 7 days'));
    await tester.tap(find.text('Apply'));
    await tester.pumpAndSettle();
    expect(controller.filteredItems.length, 7);
    // The button shows the preset name and a clear button.
    expect(find.text('Last 7 days'), findsOneWidget);

    await tester.tap(find.byTooltip('Clear').first);
    await tester.pumpAndSettle();
    expect(controller.filteredItems.length, 90);
    expect(find.text('All dates'), findsOneWidget);
  });

  testWidgets('typed dates and custom range label', (tester) async {
    final controller = AdaptiveTableController<Sale>();
    await _pump(tester, _table(controller: controller));
    await tester.tap(find.text('All dates'));
    await tester.pumpAndSettle();

    final today = _day(DateTime.now());
    String f(DateTime d) => ExportUtils.formatDate(d);
    final from = today.subtract(const Duration(days: 20));
    final to = today.subtract(const Duration(days: 11));
    await tester.enterText(find.byKey(const ValueKey('range-from')), f(from));
    await tester.enterText(find.byKey(const ValueKey('range-to')), f(to));
    await tester.pump();
    expect(find.text('Custom range'), findsOneWidget);
    await tester.tap(find.text('Apply'));
    await tester.pumpAndSettle();
    expect(controller.filteredItems.map((s) => s.id).toSet(), {
      for (var i = 11; i <= 20; i++) i,
    });
    expect(find.textContaining('–'), findsOneWidget); // "Sep 6 – Sep 15"

    // Invalid typed date disables Apply.
    await tester.tap(find.textContaining('–'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('range-from')), '2026-99');
    await tester.pump();
    expect(find.text('Use yyyy-mm-dd'), findsOneWidget);
    final apply = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Apply'),
    );
    expect(apply.onPressed, isNull);
  });

  testWidgets('tapping two days in the calendar selects a range', (
    tester,
  ) async {
    final controller = AdaptiveTableController<Sale>();
    await _pump(tester, _table(controller: controller));
    await tester.tap(find.text('All dates'));
    await tester.pumpAndSettle();
    final today = _day(DateTime.now());
    // Two days of the current month (the second visible month).
    final a = today.day > 3 ? today.day - 3 : 1;
    final b = today.day > 3 ? today.day - 1 : 2;
    Finder day(int d) => find.text('$d').last;
    await tester.tap(day(a));
    await tester.pump();
    await tester.tap(day(b));
    await tester.pump();
    await tester.tap(find.text('Apply'));
    await tester.pumpAndSettle();
    expect(
      controller.tableState.startDate,
      DateTime(today.year, today.month, a),
    );
    expect(controller.tableState.endDate, DateTime(today.year, today.month, b));
  });

  testWidgets('with a Query button the range waits for Query', (tester) async {
    var queried = 0;
    final controller = AdaptiveTableController<Sale>();
    await _pump(
      tester,
      _table(controller: controller, onQuery: () => queried++),
    );
    await tester.tap(find.text('All dates'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Today'));
    await tester.tap(find.text('Apply'));
    await tester.pumpAndSettle();
    expect(controller.filteredItems.length, 90);
    await tester.tap(find.text('Query'));
    await tester.pumpAndSettle();
    expect(controller.filteredItems.length, 1);
    expect(queried, 1);
  });

  testWidgets('phones get a bottom sheet with preset chips', (tester) async {
    await _pump(tester, _table(), size: const Size(390, 844));
    await tester.tap(find.text('All dates'));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsOneWidget);
    expect(find.byType(ChoiceChip), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('custom presets', (tester) async {
    await _pump(
      tester,
      _table(
        presets: [
          DateRangePreset.all,
          DateRangePreset(
            id: 'fortnight',
            label: (l) => 'Last 14 days',
            range: (now) => DateTimeRange(
              start: _day(now).subtract(const Duration(days: 13)),
              end: _day(now),
            ),
          ),
        ],
      ),
    );
    await tester.tap(find.text('All dates'));
    await tester.pumpAndSettle();
    expect(find.text('Last 14 days'), findsOneWidget);
    expect(find.text('This month'), findsNothing);
  });

  testWidgets('legacy separate From / To buttons still available', (
    tester,
  ) async {
    await _pump(tester, _table(style: DateFilterStyle.separateFields));
    expect(find.byIcon(Icons.calendar_today), findsNWidgets(2));
    expect(find.byIcon(Icons.date_range_rounded), findsNothing);
  });

  // go_router's ShellRoute puts pages in a nested Navigator while showDialog
  // uses the root one. Applying used to pop the nested navigator's page
  // (go_router: "You have popped the last page off of the stack").
  for (final size in const [Size(1280, 1000), Size(390, 844)]) {
    testWidgets('Apply inside a nested navigator closes only the panel '
        '(${size.width.toInt()}px)', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final controller = AdaptiveTableController<Sale>();
      final nestedKey = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        MaterialApp(
          home: Navigator(
            key: nestedKey,
            onGenerateRoute: (_) => MaterialPageRoute(
              builder: (_) => Scaffold(
                body: SingleChildScrollView(
                  child: _table(controller: controller),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('All dates'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Today'));
      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byType(DateRangePanel), findsNothing);
      expect(find.byType(AdaptiveTableLayout<Sale>), findsOneWidget);
      expect(controller.filteredItems.length, 1);
    });
  }

  for (final width in [390.0, 700.0, 1024.0, 1440.0]) {
    for (final locale in const [Locale('en'), Locale('ar')]) {
      testWidgets('panel fits at ${width.toInt()}px (${locale.languageCode})', (
        tester,
      ) async {
        await _pump(tester, _table(), size: Size(width, 900), locale: locale);
        await tester.tap(find.byIcon(Icons.date_range_rounded));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final apply = find.byType(FilledButton);
        expect(apply, findsOneWidget);
        final rect = tester.getRect(apply);
        expect(rect.left >= 0 && rect.right <= width, isTrue);
      });
    }
  }
}
