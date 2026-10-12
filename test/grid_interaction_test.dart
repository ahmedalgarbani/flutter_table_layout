import 'package:flutter/gestures.dart';
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

List<AdaptiveTableColumn<Emp>> cols({bool editable = false}) => [
  AdaptiveTableColumn(id: 'id', title: 'ID', width: 70),
  AdaptiveTableColumn(
    id: 'name',
    title: 'Name',
    width: 160,
    isEditable: editable,
  ),
  AdaptiveTableColumn(
    id: 'dept',
    title: 'Dept',
    width: 140,
    isEditable: editable,
    editor: const CellEditor.dropdown(['IT', 'Sales', 'HR']),
  ),
  AdaptiveTableColumn(
    id: 'salary',
    title: 'Salary',
    width: 140,
    isEditable: editable,
  ),
];

Future<void> pump(
  WidgetTester tester,
  Widget child, {
  Size size = const Size(1200, 900),
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

FocusNode gridNode(WidgetTester tester) => tester
    .widget<Focus>(
      find.byWidgetPredicate(
        (w) => w is Focus && w.focusNode?.debugLabel == 'TableGrid',
      ),
    )
    .focusNode!;

/// Captures `Clipboard.setData`.
List<String> mockClipboard(WidgetTester tester) {
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
  return copied;
}

void main() {
  group('keyboard', () {
    testWidgets('Tab moves through the cells, then leaves the grid', (
      tester,
    ) async {
      final after = FocusNode(debugLabel: 'after');
      addTearDown(after.dispose);
      await pump(
        tester,
        Column(
          children: [
            AdaptiveTableLayout<Emp>(
              items: emps(1),
              columns: [
                AdaptiveTableColumn(id: 'id', title: 'ID', width: 70),
                AdaptiveTableColumn(id: 'name', title: 'Name', width: 160),
              ],
              valueProviders: providers,
              showSelection: false,
              showSearch: false,
              showPagination: false,
              showExport: false,
              showPrint: false,
              showColumnsToggle: false,
            ),
            TextButton(
              focusNode: after,
              onPressed: () {},
              child: const Text('After'),
            ),
          ],
        ),
      );
      await tester.tap(find.text('1')); // focuses the first cell
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.tab); // → Name cell
      await tester.pumpAndSettle();
      expect(after.hasFocus, isFalse);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab); // past the last cell
      await tester.pumpAndSettle();
      expect(after.hasFocus, isTrue);
    });

    testWidgets('keyboard focus starts on the first cell', (tester) async {
      List<Emp> selected = const [];
      await pump(
        tester,
        AdaptiveTableLayout<Emp>(
          items: emps(5),
          columns: cols(),
          valueProviders: providers,
          onSelectionChanged: (s) => selected = s,
        ),
      );
      // Reaching the rows (e.g. with Tab) focuses the first cell.
      gridNode(tester).requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pumpAndSettle();
      expect(selected.map((e) => e.id), [1]);

      // After Escape, the first arrow press focuses the first cell again
      // instead of skipping it.
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pumpAndSettle();
      expect(selected, isEmpty); // row 1 toggled off, not row 2 on
    });

    testWidgets('typing in a column filter is not grid navigation', (
      tester,
    ) async {
      List<Emp> selected = const [];
      await pump(
        tester,
        AdaptiveTableLayout<Emp>(
          items: emps(5),
          columns: cols(),
          valueProviders: providers,
          showColumnFilters: true,
          onSelectionChanged: (s) => selected = s,
        ),
      );
      await tester.tap(find.text('Emp 2')); // a focused cell…
      await tester.pumpAndSettle();
      final nameFilter = find.byType(TextField).at(2); // search, id, name
      await tester.tap(nameFilter); // …then the filter field
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pumpAndSettle();
      expect(selected, isEmpty); // Space did not toggle the focused row
    });

    testWidgets('Page Down without pagination jumps 10 rows', (tester) async {
      List<Emp> selected = const [];
      await pump(
        tester,
        AdaptiveTableLayout<Emp>(
          items: emps(30),
          columns: cols(),
          valueProviders: providers,
          showPagination: false,
          onSelectionChanged: (s) => selected = s,
        ),
      );
      await tester.tap(find.text('Emp 1'));
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.pageDown);
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pumpAndSettle();
      expect(selected.map((e) => e.id), [11]);
    });
  });

  group('copy', () {
    testWidgets('Ctrl + C copies the selected rows as TSV', (tester) async {
      final copied = mockClipboard(tester);
      await pump(
        tester,
        AdaptiveTableLayout<Emp>(
          items: emps(4),
          columns: [
            ...cols(),
            AdaptiveTableColumn(
              id: 'actions',
              title: 'Actions',
              width: 90,
              isExportable: false,
              cellBuilder: (context, e) => const Icon(Icons.edit),
            ),
          ],
          valueProviders: providers,
        ),
      );
      await tester.tap(find.byType(Checkbox).at(3)); // Emp 3
      await tester.tap(find.byType(Checkbox).at(1)); // Emp 1
      await tester.pumpAndSettle();
      await tester.tap(find.text('Emp 2')); // focus the grid
      await tester.pumpAndSettle();
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyC);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();
      // Display order (not selection order), exportable columns only.
      expect(
        copied.single,
        'ID\tName\tDept\tSalary\n1\tEmp 1\tIT\t1000\n3\tEmp 3\tIT\t3000',
      );
      expect(find.text('2 rows copied'), findsOneWidget);
    });

    testWidgets('without a selection Ctrl + C copies the focused cell', (
      tester,
    ) async {
      final copied = mockClipboard(tester);
      await pump(
        tester,
        AdaptiveTableLayout<Emp>(
          items: emps(3),
          columns: cols(),
          valueProviders: providers,
        ),
      );
      await tester.tap(find.text('Emp 2'));
      await tester.pumpAndSettle();
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyC);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();
      expect(copied, ['Emp 2']);
      expect(find.text('Copied to clipboard'), findsOneWidget);
    });
  });

  group('editing', () {
    testWidgets('Tab in an editor jumps to the next editable cell', (
      tester,
    ) async {
      var data = emps(2);
      final edits = <String>[];
      late StateSetter setOuter;
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                setOuter = setState;
                return SingleChildScrollView(
                  child: AdaptiveTableLayout<Emp>(
                    items: data,
                    columns: [
                      AdaptiveTableColumn(id: 'id', title: 'ID', width: 70),
                      AdaptiveTableColumn(
                        id: 'name',
                        title: 'Name',
                        width: 160,
                        isEditable: true,
                      ),
                      AdaptiveTableColumn(
                        id: 'dept',
                        title: 'Dept',
                        width: 120,
                      ),
                      AdaptiveTableColumn(
                        id: 'salary',
                        title: 'Salary',
                        width: 140,
                        isEditable: true,
                      ),
                    ],
                    valueProviders: providers,
                    onCellEdited: (e, col, v) {
                      edits.add('$col=$v');
                      // Immutable update: a new instance replaces the row.
                      setOuter(() {
                        data = [
                          for (final x in data)
                            x.id == e.id && col == 'name'
                                ? Emp(x.id, v as String, x.dept, x.salary)
                                : x,
                        ];
                      });
                      return true;
                    },
                  ),
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Emp 1'));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(find.text('Emp 1'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, 'Ann');
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      expect(edits, ['name=Ann']);
      expect(find.text('Ann'), findsOneWidget);
      // The salary editor of the same row is open (Dept is skipped).
      final editor = tester.widget<TextField>(find.byType(TextField).last);
      expect(editor.controller!.text, '1000');
    });

    testWidgets('a dropdown editor closes when another cell is clicked', (
      tester,
    ) async {
      await pump(
        tester,
        AdaptiveTableLayout<Emp>(
          items: emps(3),
          columns: cols(editable: true),
          valueProviders: providers,
          onCellEdited: (_, _, _) => true,
        ),
      );
      final dept = find.text('Sales').first;
      await tester.tap(dept);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(dept);
      await tester.pumpAndSettle();
      expect(find.byType(DropdownButtonFormField<int>), findsOneWidget);
      await tester.tap(find.text('Emp 3'));
      await tester.pumpAndSettle();
      expect(find.byType(DropdownButtonFormField<int>), findsNothing);
    });
  });

  group('header', () {
    double opacityOf(WidgetTester tester, String title) {
      final opacity = find.descendant(
        of: find
            .ancestor(of: find.text(title), matching: find.byType(InkWell))
            .first,
        matching: find.byType(AnimatedOpacity),
      );
      return tester.widget<AnimatedOpacity>(opacity).opacity;
    }

    testWidgets('sort arrows: sorted columns only, others on hover', (
      tester,
    ) async {
      await pump(
        tester,
        AdaptiveTableLayout<Emp>(
          items: emps(3),
          columns: cols(),
          valueProviders: providers,
        ),
      );
      expect(opacityOf(tester, 'Name'), 0);
      await tester.tap(find.text('Name'));
      await tester.pumpAndSettle();
      expect(opacityOf(tester, 'Name'), 1);
      expect(opacityOf(tester, 'Dept'), 0);

      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      addTearDown(mouse.removePointer);
      await mouse.addPointer(location: Offset.zero);
      await mouse.moveTo(tester.getCenter(find.text('Dept')));
      await tester.pumpAndSettle();
      expect(opacityOf(tester, 'Dept'), greaterThan(0));
    });

    testWidgets('tristateSort: the third click removes the sort', (
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
          tristateSort: true,
        ),
      );
      await tester.tap(find.text('Salary'));
      await tester.pumpAndSettle();
      expect(controller.tableState.sortAscending, isTrue);
      await tester.tap(find.text('Salary'));
      await tester.pumpAndSettle();
      expect(controller.tableState.sortAscending, isFalse);
      await tester.tap(find.text('Salary'));
      await tester.pumpAndSettle();
      expect(controller.tableState.sorts, isEmpty);
    });
  });
}
