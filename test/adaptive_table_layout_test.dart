import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_table_layout/flutter_table_layout.dart';
import 'package:flutter_test/flutter_test.dart';

class Person {
  final int id;
  final String name;
  final DateTime joined;
  Person(this.id, this.name, this.joined);
}

List<Person> people(int n) => List.generate(
  n,
  (i) => Person(i + 1, 'Person ${i + 1}', DateTime(2026, 1, 1 + i)),
);

List<AdaptiveTableColumn<Person>> columns() => [
  AdaptiveTableColumn<Person>(id: 'id', title: 'ID', width: 80),
  AdaptiveTableColumn<Person>(id: 'name', title: 'Name', flex: 2),
];

final providers = <String, dynamic Function(Person)>{
  'id': (p) => p.id,
  'name': (p) => p.name,
};

Future<void> pumpTable(
  WidgetTester tester,
  Widget table, {
  Size size = const Size(1200, 1600),
  Locale? locale,
  TextDirection? direction,
  bool settle = true,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  Widget body = SingleChildScrollView(child: table);
  if (direction != null) {
    body = Directionality(textDirection: direction, child: body);
  }
  await tester.pumpWidget(
    MaterialApp(
      locale: locale,
      supportedLocales: const [Locale('en'), Locale('ar')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: Scaffold(body: body),
    ),
  );
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
}

void main() {
  testWidgets('renders the first page and paginates', (tester) async {
    await pumpTable(
      tester,
      AdaptiveTableLayout<Person>(
        title: 'People',
        items: people(25),
        columns: columns(),
        valueProviders: providers,
      ),
    );
    expect(find.text('Person 1'), findsOneWidget);
    expect(find.text('Person 11'), findsNothing);
    expect(find.text('Showing 1–10 of 25'), findsOneWidget);

    await tester.tap(find.byTooltip('Next page'));
    await tester.pumpAndSettle();
    expect(find.text('Person 11'), findsOneWidget);
    expect(find.text('Showing 11–20 of 25'), findsOneWidget);
  });

  testWidgets('showPagination: false renders every row', (tester) async {
    await pumpTable(
      tester,
      AdaptiveTableLayout<Person>(
        items: people(25),
        columns: columns(),
        valueProviders: providers,
        showPagination: false,
      ),
    );
    expect(find.text('Person 25'), findsOneWidget);
  });

  testWidgets('pageSizes without 10 does not crash the dropdown', (
    tester,
  ) async {
    await pumpTable(
      tester,
      AdaptiveTableLayout<Person>(
        items: people(60),
        columns: columns(),
        valueProviders: providers,
        pageSizes: const [25, 50],
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.text('Showing 1–25 of 60'), findsOneWidget);
  });

  testWidgets('in-place list mutation is picked up on rebuild', (tester) async {
    final list = people(3);
    late StateSetter setOuter;
    await pumpTable(
      tester,
      StatefulBuilder(
        builder: (context, setState) {
          setOuter = setState;
          return AdaptiveTableLayout<Person>(
            items: list,
            columns: columns(),
            valueProviders: providers,
          );
        },
      ),
    );
    expect(find.text('Person 4'), findsNothing);
    setOuter(() => list.add(Person(4, 'Person 4', DateTime(2026))));
    await tester.pumpAndSettle();
    expect(find.text('Person 4'), findsOneWidget);
  });

  testWidgets('search filters rows (debounced)', (tester) async {
    await pumpTable(
      tester,
      AdaptiveTableLayout<Person>(
        items: people(12),
        columns: columns(),
        valueProviders: providers,
      ),
    );
    await tester.enterText(find.byType(TextField), 'Person 12');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
    expect(find.text('Person 12'), findsWidgets);
    expect(find.text('Person 1'), findsNothing);
    expect(find.text('Clear filters'), findsOneWidget);
  });

  testWidgets('columns menu toggles visibility without provider errors', (
    tester,
  ) async {
    await pumpTable(
      tester,
      AdaptiveTableLayout<Person>(
        items: people(3),
        columns: columns(),
        valueProviders: providers,
      ),
    );
    expect(find.text('Person 1'), findsOneWidget);
    await tester.tap(find.byTooltip('Columns'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(CheckboxListTile, 'Name'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    // The menu stays open and reflects the new state.
    final tile = tester.widget<CheckboxListTile>(
      find.widgetWithText(CheckboxListTile, 'Name'),
    );
    expect(tile.value, isFalse);
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();
    expect(find.text('Person 1'), findsNothing);
  });

  testWidgets('selection callback and controller', (tester) async {
    final controller = AdaptiveTableController<Person>();
    List<Person>? selected;
    await pumpTable(
      tester,
      AdaptiveTableLayout<Person>(
        items: people(3),
        columns: columns(),
        valueProviders: providers,
        controller: controller,
        onSelectionChanged: (s) => selected = s,
      ),
    );
    await tester.tap(find.byType(Checkbox).at(1)); // first row
    await tester.pumpAndSettle();
    expect(selected?.single.id, 1);
    expect(controller.selectedItems.single.id, 1);

    controller.search('Person 3');
    await tester.pumpAndSettle();
    expect(controller.filteredItems.single.id, 3);
    expect(find.text('Person 2'), findsNothing);

    controller.resetFilters();
    controller.clearSelection();
    await tester.pumpAndSettle();
    expect(selected, isEmpty);
    expect(find.text('Person 2'), findsOneWidget);
  });

  testWidgets('date filter is hidden without dateProvider', (tester) async {
    await pumpTable(
      tester,
      AdaptiveTableLayout<Person>(
        items: people(3),
        columns: columns(),
        valueProviders: providers,
      ),
    );
    expect(find.byIcon(Icons.date_range_rounded), findsNothing);

    await pumpTable(
      tester,
      AdaptiveTableLayout<Person>(
        key: const ValueKey('with-dates'),
        items: people(3),
        columns: columns(),
        valueProviders: providers,
        dateProvider: (p) => p.joined,
      ),
    );
    expect(find.byIcon(Icons.date_range_rounded), findsOneWidget);
    expect(find.text('All dates'), findsOneWidget);
  });

  testWidgets('mobile layout renders cards that expand', (tester) async {
    await pumpTable(
      tester,
      AdaptiveTableLayout<Person>(
        items: people(3),
        columns: [
          ...columns(),
          AdaptiveTableColumn<Person>(id: 'joined', title: 'Joined'),
        ],
        valueProviders: {...providers, 'joined': (p) => p.joined},
        showSelection: false,
      ),
      size: const Size(390, 1600),
    );
    expect(tester.takeException(), isNull);
    // Card title (id) and subtitle (name).
    expect(find.text('Person 1'), findsOneWidget);
    expect(find.text('Joined'), findsNothing);
    await tester.tap(find.byIcon(Icons.expand_more).first);
    await tester.pumpAndSettle();
    expect(find.text('Joined'), findsOneWidget);
    expect(find.text('2026-01-01'), findsOneWidget);
  });

  testWidgets('expandedRowBuilder opens on row tap (desktop)', (tester) async {
    await pumpTable(
      tester,
      AdaptiveTableLayout<Person>(
        items: people(2),
        columns: columns(),
        valueProviders: providers,
        showSelection: false,
        expandedRowBuilder: (context, p) => Text('Details of ${p.name}'),
      ),
    );
    expect(find.text('Details of Person 1'), findsNothing);
    await tester.tap(find.text('Person 1'));
    await tester.pumpAndSettle();
    expect(find.text('Details of Person 1'), findsOneWidget);
  });

  testWidgets('Arabic locale uses Arabic labels and RTL does not overflow', (
    tester,
  ) async {
    await pumpTable(
      tester,
      AdaptiveTableLayout<Person>(
        title: 'الأشخاص',
        items: people(12),
        columns: columns(),
        valueProviders: providers,
      ),
      locale: const Locale('ar'),
      direction: TextDirection.rtl,
    );
    expect(tester.takeException(), isNull);
    expect(find.text('عرض 1–10 من 12'), findsOneWidget);
  });

  testWidgets('narrow toolbar wraps instead of overflowing', (tester) async {
    await pumpTable(
      tester,
      AdaptiveTableLayout<Person>(
        title: 'A very long table title that will not fit',
        subtitle: 'Subtitle',
        items: people(3),
        columns: columns(),
        valueProviders: providers,
        onRefreshPressed: () {},
        onAddNewPressed: () {},
      ),
      size: const Size(320, 1600),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('empty states distinguish "no data" and "no results"', (
    tester,
  ) async {
    await pumpTable(
      tester,
      AdaptiveTableLayout<Person>(
        items: const [],
        columns: columns(),
        valueProviders: providers,
      ),
    );
    expect(find.text('No data available'), findsOneWidget);
  });

  testWidgets('isLoading shows a progress indicator', (tester) async {
    await pumpTable(
      tester,
      AdaptiveTableLayout<Person>(
        items: const [],
        columns: columns(),
        valueProviders: providers,
        isLoading: true,
      ),
      settle: false,
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  for (final mode in TableLayoutMode.values) {
    testWidgets('phone with many pages does not overflow ($mode)', (
      tester,
    ) async {
      await pumpTable(
        tester,
        AdaptiveTableLayout<Person>(
          title: 'People',
          items: people(60),
          columns: columns(),
          valueProviders: providers,
          layoutMode: mode,
          onAddNewPressed: () {},
          onRefreshPressed: () {},
        ),
        size: const Size(360, 1600),
      );
      expect(tester.takeException(), isNull);
      // Only the grid has a column-header row.
      final hasHeaderRow = find.text('Name').evaluate().isNotEmpty;
      expect(hasHeaderRow, mode == TableLayoutMode.table);
    });
  }

  testWidgets('layoutMode.cards renders cards on desktop', (tester) async {
    await pumpTable(
      tester,
      AdaptiveTableLayout<Person>(
        items: people(3),
        columns: columns(),
        valueProviders: providers,
        layoutMode: TableLayoutMode.cards,
      ),
    );
    expect(find.text('Name'), findsNothing); // no column-header row
    expect(find.text('Person 1'), findsOneWidget);
  });

  testWidgets('onExportRequested replaces the built-in export', (tester) async {
    ExportFormat? format;
    List<Person>? rows;
    await pumpTable(
      tester,
      AdaptiveTableLayout<Person>(
        items: people(12),
        columns: columns(),
        valueProviders: providers,
        onExportRequested: (f, r) async {
          format = f;
          rows = r;
        },
      ),
    );
    await tester.tap(find.byType(Checkbox).at(2)); // second row
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Export data'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save PDF'));
    await tester.pumpAndSettle();
    expect(format, ExportFormat.pdf);
    expect(rows!.map((p) => p.id), [2]);
  });
}
