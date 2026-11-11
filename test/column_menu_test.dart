import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_table_layout/flutter_table_layout.dart';
import 'package:flutter_test/flutter_test.dart';

class Doc {
  final String code;
  final String owner;
  final String? level;
  const Doc(this.code, this.owner, [this.level]);
}

const docs = [
  Doc('INV-10', 'A very long owner name that needs room', 'high'),
  Doc('INV-9', 'Bob', 'low'),
  Doc('INV-100', 'Cy', 'medium'),
  Doc('INV-1', 'Di'),
];

final providers = <String, dynamic Function(Doc)>{
  'code': (d) => d.code,
  'owner': (d) => d.owner,
  'level': (d) => d.level,
};

int byLevel(dynamic a, dynamic b) {
  const rank = ['low', 'medium', 'high'];
  return rank.indexOf(a as String).compareTo(rank.indexOf(b as String));
}

void main() {
  test('naturalCompare orders numbers inside text', () {
    final values = ['INV-10', 'inv-9', 'INV-100', 'INV-1', 'INV-01', 'A'];
    values.sort(FilterItemsUseCase.naturalCompare);
    expect(values, ['A', 'INV-01', 'INV-1', 'inv-9', 'INV-10', 'INV-100']);
    expect(FilterItemsUseCase.naturalCompare('v1.9', 'v1.10'), lessThan(0));
    expect(FilterItemsUseCase.naturalCompare(2, 10), lessThan(0));
    expect(FilterItemsUseCase.naturalCompare('a', 'a'), 0);
  });

  test('use case: comparators, both directions, nulls last', () {
    List<String> sorted(String column, bool ascending) =>
        const FilterItemsUseCase()
            .apply<Doc>(
              items: docs,
              columns: const [],
              state: TableStateModel(
                sortByColumnId: column,
                sortAscending: ascending,
                pageSize: 0,
              ),
              valueProviders: providers,
              comparators: {
                'code': FilterItemsUseCase.naturalCompare,
                'level': byLevel,
              },
            )
            .filteredAndSorted
            .map((d) => d.code)
            .toList();
    expect(sorted('code', true), ['INV-1', 'INV-9', 'INV-10', 'INV-100']);
    expect(sorted('code', false), ['INV-100', 'INV-10', 'INV-9', 'INV-1']);
    expect(sorted('level', true), ['INV-9', 'INV-100', 'INV-10', 'INV-1']);
    expect(sorted('level', false), ['INV-10', 'INV-100', 'INV-9', 'INV-1']);
  });

  Future<AdaptiveTableController<Doc>> pumpTable(
    WidgetTester tester, {
    bool menu = true,
    TextDirection direction = TextDirection.ltr,
  }) async {
    final controller = AdaptiveTableController<Doc>();
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Directionality(
          textDirection: direction,
          child: Scaffold(
            body: SingleChildScrollView(
              child: AdaptiveTableLayout<Doc>(
                items: docs,
                controller: controller,
                showColumnMenu: menu,
                showSelection: false,
                columns: [
                  AdaptiveTableColumn(
                    id: 'code',
                    title: 'Code',
                    width: 120,
                    comparator: FilterItemsUseCase.naturalCompare,
                  ),
                  AdaptiveTableColumn(id: 'owner', title: 'Owner', width: 90),
                  AdaptiveTableColumn(
                    id: 'level',
                    title: 'Level',
                    width: 120,
                    comparator: byLevel,
                  ),
                ],
                valueProviders: providers,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return controller;
  }

  Future<void> openMenu(WidgetTester tester, String title) async {
    await tester.tap(find.text(title), buttons: kSecondaryButton);
    await tester.pumpAndSettle();
  }

  Future<void> choose(WidgetTester tester, String entry) async {
    await tester.tap(find.text(entry));
    await tester.pumpAndSettle();
  }

  testWidgets('header click sorts with the column comparator', (tester) async {
    final c = await pumpTable(tester);
    await tester.tap(find.text('Code'));
    await tester.pumpAndSettle();
    expect(c.filteredItems.map((d) => d.code), [
      'INV-1',
      'INV-9',
      'INV-10',
      'INV-100',
    ]);
  });

  testWidgets('menu: sort, clear sort, group, freeze, hide', (tester) async {
    final c = await pumpTable(tester);
    await openMenu(tester, 'Code');
    expect(find.text('Clear sort'), findsNothing);
    await choose(tester, 'Sort descending');
    expect(c.tableState.sorts, [const ColumnSort('code', ascending: false)]);
    expect(c.filteredItems.first.code, 'INV-100');

    await openMenu(tester, 'Code');
    await choose(tester, 'Clear sort');
    expect(c.tableState.sorts, isEmpty);

    await openMenu(tester, 'Level');
    await choose(tester, 'Group by Level');
    expect(c.tableState.groupByColumnId, 'level');
    await openMenu(tester, 'Level');
    await choose(tester, 'No grouping');
    expect(c.tableState.groupByColumnId, isNull);

    await openMenu(tester, 'Owner');
    await choose(tester, 'Freeze at end');
    expect(c.value!.columnPins['owner'], ColumnPin.end);
    await openMenu(tester, 'Owner');
    expect(find.text('Freeze at end'), findsNothing);
    await choose(tester, 'Unfreeze');
    expect(c.value!.columnPins['owner'], ColumnPin.none);

    await openMenu(tester, 'Owner');
    await choose(tester, 'Hide column');
    expect(c.hiddenColumnIds, ['owner']);
    expect(find.text('Owner'), findsNothing);
  });

  testWidgets('menu: auto-fit widens a column to its longest text', (
    tester,
  ) async {
    final c = await pumpTable(tester);
    final before = tester.getSize(find.text(docs.first.owner)).width;
    await openMenu(tester, 'Owner');
    await choose(tester, 'Auto-fit width');
    final width = c.value!.columnWidths['owner']!;
    expect(width, greaterThan(200));
    final text = tester.widget<Text>(find.text(docs.first.owner));
    final box = tester.getSize(find.text(docs.first.owner));
    expect(box.width, greaterThan(before));
    // One line is enough now.
    final painter = TextPainter(
      text: TextSpan(text: docs.first.owner, style: text.style),
      textDirection: TextDirection.ltr,
    )..layout();
    expect(box.width, greaterThanOrEqualTo(painter.width.floor()));
  });

  testWidgets('the ⋮ button appears on hover and opens the menu (RTL)', (
    tester,
  ) async {
    await pumpTable(tester, direction: TextDirection.rtl);
    expect(find.byIcon(Icons.more_vert), findsNothing);
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    addTearDown(mouse.removePointer);
    await mouse.moveTo(tester.getCenter(find.text('Level')));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.more_vert), findsOneWidget);
    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    expect(find.text('Sort ascending'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('showColumnMenu: false has no menu', (tester) async {
    await pumpTable(tester, menu: false);
    await openMenu(tester, 'Code');
    expect(find.text('Sort ascending'), findsNothing);
  });
}
