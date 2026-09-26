import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_table_layout/flutter_table_layout.dart';
import 'package:flutter_test/flutter_test.dart';

class Emp {
  final int id;
  final String name;
  final String dept;
  final double salary;
  final bool active;
  const Emp(this.id, this.name, this.dept, this.salary, this.active);

  Emp copyWith({String? name, double? salary, bool? active}) => Emp(
    id,
    name ?? this.name,
    dept,
    salary ?? this.salary,
    active ?? this.active,
  );
}

List<Emp> emps(int n) => [
  for (var i = 1; i <= n; i++)
    Emp(i, 'Emp $i', i.isEven ? 'Sales' : 'IT', 1000.0 * i, i % 3 != 0),
];

final providers = <String, dynamic Function(Emp)>{
  'id': (e) => e.id,
  'name': (e) => e.name,
  'dept': (e) => e.dept,
  'salary': (e) => e.salary,
  'active': (e) => e.active,
};

List<AdaptiveTableColumn<Emp>> cols({
  ColumnPin namePin = ColumnPin.none,
  bool editable = false,
  int extra = 0,
}) => [
  AdaptiveTableColumn(id: 'id', title: 'ID', width: 70),
  AdaptiveTableColumn(
    id: 'name',
    title: 'Name',
    width: 160,
    pin: namePin,
    isEditable: editable,
    cellValidator: (v) => (v as String).isEmpty ? 'Required' : null,
  ),
  AdaptiveTableColumn(id: 'dept', title: 'Dept', width: 120),
  AdaptiveTableColumn(
    id: 'salary',
    title: 'Salary',
    width: 140,
    isEditable: editable,
  ),
  AdaptiveTableColumn(
    id: 'active',
    title: 'Active',
    width: 100,
    isEditable: editable,
  ),
  for (var i = 0; i < extra; i++)
    AdaptiveTableColumn(id: 'x$i', title: 'Extra $i', width: 150),
];

Future<void> pump(
  WidgetTester tester,
  Widget table, {
  Size size = const Size(1200, 900),
  TextDirection direction = TextDirection.ltr,
  bool scroll = true,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: Directionality(
        textDirection: direction,
        child: Scaffold(
          body: scroll ? SingleChildScrollView(child: table) : table,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('bodyHeight virtualizes rows and keeps the header sticky', (
    tester,
  ) async {
    await pump(
      tester,
      AdaptiveTableLayout<Emp>(
        items: emps(5000),
        columns: cols(),
        valueProviders: providers,
        showPagination: false,
        bodyHeight: 400,
      ),
    );
    expect(find.text('Emp 1'), findsOneWidget);
    expect(find.text('Emp 5000'), findsNothing);
    // Far fewer than 5000 rows are built.
    expect(find.byType(Checkbox).evaluate().length, lessThan(40));

    await tester.drag(find.text('Emp 3'), const Offset(0, -3000));
    await tester.pumpAndSettle();
    expect(find.text('Emp 1'), findsNothing);
    expect(find.text('Salary'), findsOneWidget); // header still visible
  });

  testWidgets('fillHeight fills a bounded parent and ignores unbounded ones', (
    tester,
  ) async {
    await pump(
      tester,
      SizedBox(
        height: 700,
        child: AdaptiveTableLayout<Emp>(
          items: emps(300),
          columns: cols(),
          valueProviders: providers,
          showPagination: false,
          fillHeight: true,
        ),
      ),
      scroll: false,
    );
    expect(tester.takeException(), isNull);
    expect(find.text('Emp 300'), findsNothing);

    await pump(
      tester,
      AdaptiveTableLayout<Emp>(
        key: const ValueKey('unbounded'),
        items: emps(3),
        columns: cols(),
        valueProviders: providers,
        fillHeight: true,
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.text('Emp 3'), findsOneWidget);
  });

  for (final direction in TextDirection.values) {
    testWidgets('frozen columns stay in place while scrolling ($direction)', (
      tester,
    ) async {
      await pump(
        tester,
        AdaptiveTableLayout<Emp>(
          items: emps(3),
          columns: cols(namePin: ColumnPin.start, extra: 6),
          valueProviders: providers,
          showSelection: false,
        ),
        size: const Size(800, 900),
        direction: direction,
      );
      final pinnedBefore = tester.getTopLeft(find.text('Emp 1'));
      final movingBefore = tester.getTopLeft(find.text('IT').first);
      final dx = direction == TextDirection.ltr ? -400.0 : 400.0;
      await tester.drag(find.text('IT').first, Offset(dx, 0));
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(find.text('Emp 1')), pinnedBefore);
      expect(tester.getTopLeft(find.text('IT').first), isNot(movingBefore));
      // Pinned cells still receive taps at their painted position.
      expect(
        tester
            .hitTestOnBinding(tester.getCenter(find.text('Emp 1')))
            .path
            .any(
              (e) =>
                  e.target is RenderParagraph &&
                  (e.target as RenderParagraph).text.toPlainText() == 'Emp 1',
            ),
        isTrue,
      );
    });
  }

  testWidgets('columns can be resized by dragging the header edge', (
    tester,
  ) async {
    final controller = AdaptiveTableController<Emp>();
    await pump(
      tester,
      AdaptiveTableLayout<Emp>(
        items: emps(3),
        columns: cols(),
        valueProviders: providers,
        controller: controller,
      ),
    );
    final handles = find.byWidgetPredicate(
      (w) => w is MouseRegion && w.cursor == SystemMouseCursors.resizeColumn,
    );
    expect(handles, findsWidgets);
    // Second handle = "Name" (160 px).
    await tester.drag(handles.at(1), const Offset(60, 0));
    await tester.pumpAndSettle();
    expect(controller.value!.columnWidths['name'], closeTo(220, 20));

    await tester.tap(handles.at(1));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(handles.at(1));
    await tester.pumpAndSettle();
    expect(controller.value!.columnWidths.containsKey('name'), isFalse);
  });

  testWidgets('columns can be reordered by long-press drag', (tester) async {
    final controller = AdaptiveTableController<Emp>();
    await pump(
      tester,
      AdaptiveTableLayout<Emp>(
        items: emps(2),
        columns: cols(),
        valueProviders: providers,
        controller: controller,
      ),
    );
    final gesture = await tester.startGesture(
      tester.getCenter(find.text('Salary')),
    );
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 100));
    await gesture.moveTo(tester.getCenter(find.text('ID')));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();
    expect(controller.value!.columnOrder.first, 'salary');
    expect(
      tester.getTopLeft(find.text('Salary')).dx,
      lessThan(tester.getTopLeft(find.text('ID')).dx),
    );
  });

  testWidgets('per-column filter row filters rows', (tester) async {
    await pump(
      tester,
      AdaptiveTableLayout<Emp>(
        items: emps(12),
        columns: cols(),
        valueProviders: providers,
        showColumnFilters: true,
      ),
    );
    final salaryFilter = find.byType(TextField).at(4); // search + 3 before
    await tester.enterText(salaryFilter, '>=11000');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(find.text('Emp 11'), findsOneWidget);
    expect(find.text('Emp 1'), findsNothing);

    // No result: the header and filters stay so the filter can be changed.
    await tester.enterText(salaryFilter, '>99999');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(find.text('No results match your filters'), findsOneWidget);
    expect(find.text('Salary'), findsOneWidget);
  });

  testWidgets('shift + click adds a secondary sort', (tester) async {
    final controller = AdaptiveTableController<Emp>();
    await pump(
      tester,
      AdaptiveTableLayout<Emp>(
        items: emps(6),
        columns: cols(),
        valueProviders: providers,
        controller: controller,
      ),
    );
    await tester.tap(find.text('Dept'));
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.tap(find.text('Salary'));
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pumpAndSettle();
    expect(controller.tableState.sorts.map((s) => s.columnId), [
      'dept',
      'salary',
    ]);
    expect(find.text('2'), findsWidgets); // sort level badge
  });

  testWidgets('grouping shows collapsible group headers', (tester) async {
    await pump(
      tester,
      AdaptiveTableLayout<Emp>(
        items: emps(6),
        columns: cols(),
        valueProviders: providers,
        groupByColumnId: 'dept',
        groupHeaderBuilder: (context, g) =>
            Text('Total ${g.rows.fold<double>(0, (s, e) => s + e.salary)}'),
      ),
    );
    expect(find.text('Total 9000.0'), findsOneWidget); // IT: 1+3+5
    expect(find.text('Emp 1'), findsOneWidget);
    await tester.tap(find.text('Total 9000.0'));
    await tester.pumpAndSettle();
    expect(find.text('Emp 1'), findsNothing);
    expect(find.text('Emp 2'), findsOneWidget);
  });

  group('inline editing', () {
    Widget editable({
      required List<Emp> data,
      required void Function(Emp, String, dynamic) onEdit,
      CanEditCell<Emp>? canEdit,
      bool reject = false,
    }) {
      return AdaptiveTableLayout<Emp>(
        items: data,
        columns: cols(editable: true),
        valueProviders: providers,
        canEditCell: canEdit,
        onCellEdited: (item, col, value) {
          onEdit(item, col, value);
          return !reject;
        },
      );
    }

    testWidgets('double tap edits text and numbers', (tester) async {
      final edits = <(int, String, dynamic)>[];
      await pump(
        tester,
        editable(data: emps(2), onEdit: (e, c, v) => edits.add((e.id, c, v))),
      );
      await tester.tap(find.text('Emp 1'));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(find.text('Emp 1'));
      await tester.pumpAndSettle();
      // The search box is the first TextField, the inline editor the last.
      final editor = find.byType(TextField).at(1);
      expect(find.byType(TextField), findsNWidgets(2));
      await tester.enterText(editor, 'Renamed');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(edits, [(1, 'name', 'Renamed')]);
      expect(find.byType(TextField), findsOneWidget);

      await tester.tap(find.text('2000'));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(find.text('2000'));
      await tester.pumpAndSettle();
      await tester.enterText(editor, 'abc');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(find.text('Invalid number format'), findsOneWidget);
      await tester.enterText(editor, '2,500.5');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(edits.last, (2, 'salary', 2500.5));
    });

    testWidgets('validator and rejected edits keep the editor open', (
      tester,
    ) async {
      var calls = 0;
      await pump(
        tester,
        editable(data: emps(1), onEdit: (_, _, _) => calls++, reject: true),
      );
      await tester.tap(find.text('Emp 1'));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(find.text('Emp 1'));
      await tester.pumpAndSettle();
      final editor = find.byType(TextField).last;
      await tester.enterText(editor, '');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(find.text('Required'), findsOneWidget);
      expect(calls, 0);
      await tester.enterText(editor, 'X');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(calls, 1);
      expect(find.text('Invalid value'), findsOneWidget);
      // Escape cancels.
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.text('Invalid value'), findsNothing);
    });

    testWidgets('booleans toggle immediately; permissions are respected', (
      tester,
    ) async {
      final edits = <(int, String, dynamic)>[];
      await pump(
        tester,
        editable(
          data: emps(2),
          onEdit: (e, c, v) => edits.add((e.id, c, v)),
          canEdit: (e, c) => e.id == 1,
        ),
      );
      await tester.tap(find.text('✓').first);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(find.text('✓').first);
      await tester.pumpAndSettle();
      expect(edits, [(1, 'active', false)]);

      await tester.tap(find.text('Emp 2'));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(find.text('Emp 2'));
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsOneWidget); // only the search box
    });
  });

  testWidgets('keyboard navigation moves focus, selects and edits', (
    tester,
  ) async {
    List<Emp> selected = const [];
    final edits = <String>[];
    await pump(
      tester,
      AdaptiveTableLayout<Emp>(
        items: emps(4),
        columns: cols(editable: true),
        valueProviders: providers,
        onSelectionChanged: (s) => selected = s,
        onCellEdited: (item, col, v) {
          edits.add('$col=${item.id}');
          return true;
        },
      ),
    );
    await tester.tap(find.text('Emp 1'));
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pumpAndSettle();
    expect(selected.map((e) => e.id), [2]);

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsNWidgets(2)); // search + editor
    await tester.enterText(find.byType(TextField).last, 'Bob');
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();
    expect(edits, ['name=2']);
  });

  testWidgets('server-side data source drives the table', (tester) async {
    final queries = <TableStateModel>[];
    final source = AdaptiveTableDataSource<Emp>.fromCallback((q) async {
      queries.add(q);
      await Future<void>.delayed(const Duration(milliseconds: 100));
      final all = emps(95);
      final start = (q.currentPage - 1) * q.pageSize;
      return TableDataPage(
        items: all.skip(start).take(q.pageSize).toList(),
        totalCount: all.length,
      );
    });
    await pump(
      tester,
      AdaptiveTableLayout<Emp>(
        dataSource: source,
        columns: cols(),
        valueProviders: providers,
      ),
    );
    expect(find.text('Showing 1–10 of 95'), findsOneWidget);
    await tester.tap(find.byTooltip('Next page'));
    await tester.pump();
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.text('Emp 11'), findsOneWidget);
    expect(queries.last.currentPage, 2);
  });

  const sizes = [
    Size(320, 900),
    Size(390, 900),
    Size(768, 1000),
    Size(1024, 900),
    Size(1440, 900),
  ];
  for (final size in sizes) {
    for (final direction in TextDirection.values) {
      testWidgets('all features render without overflow at '
          '${size.width.toInt()}px ($direction)', (tester) async {
        await pump(
          tester,
          AdaptiveTableLayout<Emp>(
            title: 'Employees',
            items: emps(40),
            columns: cols(namePin: ColumnPin.start, editable: true, extra: 3),
            valueProviders: providers,
            showColumnFilters: true,
            groupByColumnId: 'dept',
            bodyHeight: 420,
            expandedRowBuilder: (context, e) => Text('Details ${e.id}'),
            onCellEdited: (_, _, _) => true,
            onAddNewPressed: () {},
            onRefreshPressed: () {},
            summaryBuilder: (context, rows) => Text('Rows ${rows.length}'),
          ),
          size: size,
          direction: direction,
        );
        expect(tester.takeException(), isNull);
        expect(find.text('Employees'), findsOneWidget);
      });
    }
  }
}
