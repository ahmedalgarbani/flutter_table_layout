import 'package:flutter/material.dart';
import 'package:flutter_table_layout/flutter_table_layout.dart';
import 'package:flutter_test/flutter_test.dart';

class Txn {
  final int id;
  final String details;
  final double amount;
  final DateTime date;
  const Txn(this.id, this.details, this.amount, this.date);
}

final _txns = [
  Txn(1, 'Rent', 1200, DateTime(2026, 1, 3)),
  Txn(2, 'Salary', 5000, DateTime(2026, 1, 25)),
  Txn(3, 'Food', 300.5, DateTime(2026, 2, 2)),
  Txn(4, 'Fuel', 99.5, DateTime(2026, 2, 9)),
];

final _providers = <String, dynamic Function(Txn)>{
  'id': (t) => t.id,
  'details': (t) => t.details,
  'amount': (t) => t.amount,
  'date': (t) => t.date,
};

String _money(dynamic v) => '\$${(v as num).toStringAsFixed(2)}';

List<AdaptiveTableColumn<Txn>> _columns({bool idCount = false}) => [
  AdaptiveTableColumn(
    id: 'id',
    title: 'No.',
    width: 70,
    aggregate: idCount ? TableAggregate.count : null,
  ),
  AdaptiveTableColumn(id: 'details', title: 'Details', flex: 2),
  AdaptiveTableColumn(
    id: 'amount',
    title: 'Amount',
    width: 140,
    alignment: TableColumnAlignment.end,
    valueFormatter: _money,
    aggregate: TableAggregate.sum,
  ),
  AdaptiveTableColumn(
    id: 'date',
    title: 'Date',
    width: 130,
    aggregate: TableAggregate.max,
    valueFormatter: (v) => ExportUtils.formatDate(v as DateTime),
  ),
];

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  Size size = const Size(1200, 1000),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(body: SingleChildScrollView(child: child)),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('TableAggregate.compute', () {
    test('sum, average, min, max, count', () {
      final values = <Object?>[3, null, 1.5, 'x', 5];
      expect(TableAggregate.sum.compute(values), 9.5);
      expect(TableAggregate.average.compute(values), closeTo(3.1667, 1e-3));
      expect(TableAggregate.min.compute([3, null, 1, 5]), 1);
      expect(TableAggregate.max.compute([3, null, 1, 5]), 5);
      expect(TableAggregate.count.compute(['a', '', null, '  ', 'b']), 2);
    });

    test('empty input', () {
      expect(TableAggregate.sum.compute(const []), 0);
      expect(TableAggregate.average.compute(const []), isNull);
      expect(TableAggregate.min.compute(const [null]), isNull);
      expect(TableAggregate.count.compute(const []), 0);
    });

    test('min / max work on dates and text', () {
      expect(
        TableAggregate.max.compute([DateTime(2026), DateTime(2027)]),
        DateTime(2027),
      );
      expect(TableAggregate.min.compute(['b', 'A', 'c']), 'A');
    });
  });

  group('TableCubit aggregates', () {
    TableCubit<Txn> cubit() => TableCubit<Txn>(
      items: _txns,
      columns: [for (final c in _columns()) c.definition],
      valueProviders: _providers,
      aggregators: {
        'amount': (rows) =>
            TableAggregate.sum.compute(rows.map((r) => r.amount)),
      },
    );

    test('follow the filters (all pages, not only the current one)', () {
      final c = cubit();
      final s = c.state as TableLoaded<Txn>;
      expect(s.aggregates['amount'], 6600);
      c.setPageSize(1);
      expect((c.state as TableLoaded<Txn>).aggregates['amount'], 6600);
      c.updateSearchQuery('f'); // Food, Fuel
      expect((c.state as TableLoaded<Txn>).aggregates['amount'], 400);
      c.close();
    });

    test('a throwing aggregator does not break the table', () {
      final c = TableCubit<Txn>(
        items: _txns,
        columns: [for (final c in _columns()) c.definition],
        valueProviders: _providers,
        aggregators: {'amount': (rows) => throw StateError('boom')},
      );
      final s = c.state as TableLoaded<Txn>;
      expect(s.paginatedItems, isNotEmpty);
      expect(s.aggregates, isEmpty);
      c.close();
    });

    test('server mode uses the totals returned by the server', () async {
      final c = TableCubit<Txn>(
        items: const [],
        columns: [for (final c in _columns()) c.definition],
        valueProviders: _providers,
        aggregators: {
          'amount': (rows) =>
              TableAggregate.sum.compute(rows.map((r) => r.amount)),
        },
        dataSource: AdaptiveTableDataSource.fromCallback(
          (q) async => TableDataPage(
            items: _txns.take(2).toList(),
            totalCount: 40,
            aggregates: const {'amount': 123456},
          ),
        ),
      );
      await pumpEventQueue();
      expect((c.state as TableLoaded<Txn>).aggregates['amount'], 123456);
      await c.close();
    });

    test('server mode without totals aggregates the current page', () async {
      final c = TableCubit<Txn>(
        items: const [],
        columns: [for (final c in _columns()) c.definition],
        valueProviders: _providers,
        aggregators: {
          'amount': (rows) =>
              TableAggregate.sum.compute(rows.map((r) => r.amount)),
        },
        dataSource: AdaptiveTableDataSource.fromCallback(
          (q) async =>
              TableDataPage(items: _txns.take(2).toList(), totalCount: 40),
        ),
      );
      await pumpEventQueue();
      expect((c.state as TableLoaded<Txn>).aggregates['amount'], 6200);
      await c.close();
    });
  });

  group('Totals row', () {
    testWidgets('desktop: aligned, formatted, labelled and live', (
      tester,
    ) async {
      final controller = AdaptiveTableController<Txn>();
      await _pump(
        tester,
        AdaptiveTableLayout<Txn>(
          items: _txns,
          columns: _columns(),
          valueProviders: _providers,
          controller: controller,
        ),
      );
      expect(find.text('Total'), findsOneWidget); // first column has no total
      expect(find.text(r'$6600.00'), findsOneWidget);
      expect(find.text('2026-02-09'), findsNWidgets(2)); // max date + its row
      // Aligned with the column.
      expect(
        tester.getTopRight(find.text(r'$6600.00')).dx,
        closeTo(tester.getTopRight(find.text(r'$5000.00')).dx, 1),
      );
      expect(find.byTooltip('Sum'), findsOneWidget);
      expect(find.byTooltip('Maximum'), findsOneWidget);

      controller.search('food');
      await tester.pumpAndSettle();
      expect(find.text(r'$300.50'), findsNWidgets(2)); // row + total
      expect(controller.aggregates['amount'], 300.5);
    });

    testWidgets('a total in the first column leaves no room for the label', (
      tester,
    ) async {
      await _pump(
        tester,
        AdaptiveTableLayout<Txn>(
          items: _txns,
          columns: _columns(idCount: true),
          valueProviders: _providers,
        ),
      );
      expect(find.text('Total'), findsNothing);
      expect(find.byTooltip('Count'), findsOneWidget);
    });

    testWidgets('no totals row without aggregates or rows', (tester) async {
      await _pump(
        tester,
        AdaptiveTableLayout<Txn>(
          items: const [],
          columns: _columns(),
          valueProviders: _providers,
        ),
      );
      expect(find.text('Total'), findsNothing);
      expect(find.text('No data available'), findsOneWidget);
    });

    testWidgets('sticky under virtualized rows (bodyHeight)', (tester) async {
      await _pump(
        tester,
        AdaptiveTableLayout<Txn>(
          items: [
            for (var i = 0; i < 500; i++)
              Txn(i, 'Row $i', 1, DateTime(2026, 1, 1)),
          ],
          columns: _columns(),
          valueProviders: _providers,
          showPagination: false,
          bodyHeight: 300,
        ),
      );
      expect(find.text(r'$500.00'), findsOneWidget);
      expect(find.text('Row 499'), findsNothing); // virtualized
    });

    testWidgets('phones: a totals panel under the cards', (tester) async {
      await _pump(
        tester,
        AdaptiveTableLayout<Txn>(
          items: _txns,
          columns: _columns(),
          valueProviders: _providers,
        ),
        size: const Size(390, 1600),
      );
      expect(tester.takeException(), isNull);
      expect(find.text('Total'), findsOneWidget);
      expect(find.text(r'$6600.00'), findsOneWidget);
    });

    testWidgets('custom aggregator and aggregateFormatter', (tester) async {
      await _pump(
        tester,
        AdaptiveTableLayout<Txn>(
          items: _txns,
          columns: [
            AdaptiveTableColumn(id: 'details', title: 'Details'),
            AdaptiveTableColumn(
              id: 'amount',
              title: 'Amount',
              aggregator: (rows) => rows.where((r) => r.amount > 1000).length,
              aggregateFormatter: (v) => '$v large',
            ),
          ],
          valueProviders: _providers,
        ),
      );
      expect(find.text('2 large'), findsOneWidget);
    });
  });
}
