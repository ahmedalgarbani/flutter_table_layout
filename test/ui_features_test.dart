import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_table_layout/flutter_table_layout.dart';
import 'package:flutter_test/flutter_test.dart';

class Emp {
  final int id;
  final String name;
  final String dept;
  final double salary;
  const Emp(this.id, this.name, this.dept, this.salary);
}

List<Emp> emps(int n) => [
  for (var i = 1; i <= n; i++)
    Emp(i, 'Emp $i', i.isEven ? 'Sales' : 'IT', 1000.0 * i),
];

final providers = <String, dynamic Function(Emp)>{
  'id': (e) => e.id,
  'name': (e) => e.name,
  'dept': (e) => e.dept,
  'salary': (e) => e.salary,
};

List<AdaptiveTableColumn<Emp>> cols() => [
  AdaptiveTableColumn(id: 'id', title: 'ID', width: 70, isGroupable: false),
  AdaptiveTableColumn(id: 'name', title: 'Name', width: 160),
  AdaptiveTableColumn(id: 'dept', title: 'Dept', width: 140),
  AdaptiveTableColumn(id: 'salary', title: 'Salary', width: 140),
];

Future<void> pump(
  WidgetTester tester,
  Widget child, {
  Size size = const Size(1200, 1000),
  ThemeData? theme,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: theme,
      home: Scaffold(body: SingleChildScrollView(child: child)),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('group-by menu groups and ungroups', (tester) async {
    final controller = AdaptiveTableController<Emp>();
    await pump(
      tester,
      AdaptiveTableLayout<Emp>(
        items: emps(6),
        columns: cols(),
        valueProviders: providers,
        controller: controller,
        showGroupingMenu: true,
      ),
    );
    await tester.tap(find.byTooltip('Group by'));
    await tester.pumpAndSettle();
    expect(find.text('No grouping'), findsOneWidget);
    expect(find.text('ID'), findsOneWidget); // header only: not groupable
    await tester.tap(find.text('Dept').last);
    await tester.pumpAndSettle();
    expect(controller.tableState.groupByColumnId, 'dept');
    expect(find.text('IT'), findsWidgets);

    await tester.tap(find.byTooltip('Group by'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('No grouping'));
    await tester.pumpAndSettle();
    expect(controller.tableState.groupByColumnId, isNull);
  });

  testWidgets('cards: sort bar sorts and flips the direction', (tester) async {
    final controller = AdaptiveTableController<Emp>();
    await pump(
      tester,
      AdaptiveTableLayout<Emp>(
        items: emps(3),
        columns: cols(),
        valueProviders: providers,
        controller: controller,
        showSelection: false,
      ),
      size: const Size(390, 1400),
    );
    expect(find.text('Default order'), findsOneWidget);
    await tester.tap(find.text('Default order'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Salary').last);
    await tester.pumpAndSettle();
    expect(controller.tableState.sortByColumnId, 'salary');
    expect(controller.pageItems.first.id, 1);
    await tester.tap(find.byTooltip('Ascending'));
    await tester.pumpAndSettle();
    expect(controller.tableState.sortAscending, isFalse);
    expect(controller.pageItems.first.id, 3);
  });

  testWidgets('showCardSortBar: false hides it', (tester) async {
    await pump(
      tester,
      AdaptiveTableLayout<Emp>(
        items: emps(3),
        columns: cols(),
        valueProviders: providers,
        showCardSortBar: false,
      ),
      size: const Size(390, 1400),
    );
    expect(find.text('Default order'), findsNothing);
  });

  testWidgets('density changes the row height', (tester) async {
    Future<double> rowHeight(TableDensity density) async {
      await pump(
        tester,
        AdaptiveTableLayout<Emp>(
          key: ValueKey(density),
          items: emps(2),
          columns: cols(),
          valueProviders: providers,
          density: density,
          showSelection: false,
        ),
      );
      return tester.getTopLeft(find.text('Emp 2')).dy -
          tester.getTopLeft(find.text('Emp 1')).dy;
    }

    final compact = await rowHeight(TableDensity.compact);
    final standard = await rowHeight(TableDensity.standard);
    final comfortable = await rowHeight(TableDensity.comfortable);
    expect(compact, lessThan(standard));
    expect(comfortable, greaterThan(standard));
  });

  testWidgets('"All" rows-per-page option', (tester) async {
    await pump(
      tester,
      AdaptiveTableLayout<Emp>(
        items: emps(12),
        columns: cols(),
        valueProviders: providers,
        pageSizes: const [5, 0],
      ),
    );
    expect(find.text('Showing 1–5 of 12'), findsOneWidget);
    await tester.tap(find.text('5').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('All').last);
    await tester.pumpAndSettle();
    expect(find.text('Showing 1–12 of 12'), findsOneWidget);
    expect(find.text('Emp 12'), findsOneWidget);
  });

  testWidgets('an empty table keeps its column headers (desktop)', (
    tester,
  ) async {
    await pump(
      tester,
      AdaptiveTableLayout<Emp>(
        items: const [],
        columns: cols(),
        valueProviders: providers,
      ),
    );
    expect(find.text('No data available'), findsOneWidget);
    expect(find.text('Salary'), findsOneWidget);
  });

  testWidgets('a server error keeps the toolbar and the search box', (
    tester,
  ) async {
    var fail = true;
    final source = AdaptiveTableDataSource<Emp>.fromCallback((q) async {
      if (fail) throw StateError('offline');
      return TableDataPage(items: emps(2), totalCount: 2);
    });
    await pump(
      tester,
      AdaptiveTableLayout<Emp>(
        title: 'Employees',
        dataSource: source,
        columns: cols(),
        valueProviders: providers,
      ),
    );
    expect(find.text('Retry'), findsOneWidget);
    expect(find.text('Employees'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget); // search box
    fail = false;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('Emp 2'), findsOneWidget);
  });

  testWidgets('controller listeners see the first state', (tester) async {
    final controller = AdaptiveTableController<Emp>();
    await pump(
      tester,
      Column(
        children: [
          ListenableBuilder(
            listenable: controller,
            builder: (context, _) =>
                Text('rows: ${controller.filteredItems.length}'),
          ),
          AdaptiveTableLayout<Emp>(
            items: emps(4),
            columns: cols(),
            valueProviders: providers,
            controller: controller,
          ),
        ],
      ),
    );
    expect(find.text('rows: 4'), findsOneWidget);
  });

  testWidgets('controller export / print / copy use the table actions', (
    tester,
  ) async {
    final controller = AdaptiveTableController<Emp>();
    final exported = <(ExportFormat, List<int>)>[];
    final printed = <List<int>>[];
    final copied = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied.add((call.arguments as Map)['text'] as String);
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await pump(
      tester,
      AdaptiveTableLayout<Emp>(
        items: emps(3),
        columns: cols(),
        valueProviders: providers,
        controller: controller,
        onExportRequested: (f, rows) async =>
            exported.add((f, [for (final r in rows) r.id])),
        onPrintRequested: (rows) async =>
            printed.add([for (final r in rows) r.id]),
      ),
    );
    await controller.exportAs(ExportFormat.csv);
    controller.setSelection([emps(3)[1]]);
    await tester.pumpAndSettle();
    await controller.printTable();
    final count = await controller.copyToClipboard(
      rows: emps(3).take(2).toList(),
    );
    await tester.pumpAndSettle();
    expect(exported.single.$1, ExportFormat.csv);
    expect(exported.single.$2, [1, 2, 3]);
    expect(printed.single, isEmpty); // emps(3)[1] is a new instance (no ==)
    expect(count, 2);
    expect(copied.single.split('\n').length, 3);
  });

  testWidgets('onSelectionChanged does not fire when the data refreshes', (
    tester,
  ) async {
    var calls = 0;
    var data = emps(3);
    late StateSetter setOuter;
    await pump(
      tester,
      StatefulBuilder(
        builder: (context, setState) {
          setOuter = setState;
          return AdaptiveTableLayout<Emp>(
            items: data,
            columns: cols(),
            valueProviders: providers,
            onSelectionChanged: (_) => calls++,
          );
        },
      ),
    );
    await tester.tap(find.byType(Checkbox).at(1));
    await tester.pumpAndSettle();
    expect(calls, 1);
    setOuter(() => data = [...data, const Emp(9, 'Emp 9', 'IT', 1)]);
    await tester.pumpAndSettle();
    expect(calls, 1);
  });

  testWidgets('Material 3 preset follows the color scheme', (tester) async {
    late AdaptiveTableTheme theme;
    final scheme = ColorScheme.fromSeed(seedColor: Colors.teal);
    await pump(
      tester,
      Builder(
        builder: (context) {
          theme = AdaptiveTableTheme.material(context);
          return AdaptiveTableLayout<Emp>(
            items: emps(2),
            columns: cols(),
            valueProviders: providers,
            theme: theme,
          );
        },
      ),
      theme: ThemeData(colorScheme: scheme),
    );
    expect(tester.takeException(), isNull);
    expect(theme.accentColor, scheme.primary);
    expect(theme.headerBackgroundColor, scheme.surfaceContainer);
    final compact = theme.withDensity(TableDensity.compact);
    expect(
      (compact.rowPadding as EdgeInsets).top,
      (theme.rowPadding as EdgeInsets).top / 2,
    );
  });

  group('cubit', () {
    TableCubit<Emp> cubit() => TableCubit<Emp>(
      items: emps(5),
      columns: [for (final c in cols()) c.definition],
      valueProviders: providers,
    );

    test('unchanged configuration emits nothing', () async {
      final c = cubit();
      final states = <TableCubitState<Emp>>[];
      final sub = c.stream.listen(states.add);
      // New Emp instances (no ==): the content changed, one recomputation.
      c.updateConfiguration(
        items: emps(5),
        columns: [for (final c in cols()) c.definition],
        valueProviders: providers,
      );
      await pumpEventQueue();
      expect(states.length, 1);
      // Same items (a new list), equal columns, identical providers: a
      // parent rebuild like this costs nothing.
      c.updateConfiguration(
        items: c.items.toList(),
        columns: [for (final c in cols()) c.definition],
        valueProviders: providers,
      );
      await pumpEventQueue();
      expect(states.length, 1);
      await sub.cancel();
      await c.close();
    });

    test('removing a column drops its sort, filter and grouping', () {
      final c = cubit();
      c.sortBy('dept');
      c.sortBy('salary', additive: true);
      c.setColumnFilter('dept', 'IT');
      c.groupBy('dept');
      c.setColumnWidth('dept', 300);
      c.updateConfiguration(
        columns: [
          for (final col in cols())
            if (col.id != 'dept') col.definition,
        ],
      );
      final s = c.state as TableLoaded<Emp>;
      expect(s.tableState.sorts, [const ColumnSort('salary')]);
      expect(s.tableState.columnFilters, isEmpty);
      expect(s.tableState.groupByColumnId, isNull);
      expect(s.columnWidths, isEmpty);
      expect(s.totalCount, 5);
      c.close();
    });

    test('setColumnWidth on an unknown column does not throw', () {
      final c = cubit();
      c.setColumnWidth('nope', -5);
      c.setColumnWidths({'nope': -1, 'name': 10});
      expect((c.state as TableLoaded<Emp>).columnWidths['name'], 60);
      c.close();
    });

    test('next / previous page stop at the edges', () async {
      final c = cubit();
      c.setPageSize(2);
      final states = <TableCubitState<Emp>>[];
      final sub = c.stream.listen(states.add);
      c.previousPage();
      c.setPage(3);
      c.nextPage();
      await pumpEventQueue();
      expect(c.tableState.currentPage, 3);
      expect(states.length, 1); // only setPage(3) emitted
      await sub.cancel();
      await c.close();
    });
  });

  test('date presets use calendar days (DST-safe)', () {
    final now = DateTime(2026, 3, 10, 12);
    expect(DateRangePreset.last7Days.range(now)!.start, DateTime(2026, 3, 4));
    expect(DateRangePreset.last30Days.range(now)!.start, DateTime(2026, 2, 9));
    expect(DateRangePreset.yesterday.range(now)!.start, DateTime(2026, 3, 9));
  });
}
