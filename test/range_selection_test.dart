import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_table_layout/flutter_table_layout.dart';
import 'package:flutter_table_layout/src/presentation/widgets/grid/table_grid.dart';
import 'package:flutter_test/flutter_test.dart';

class Emp {
  final int id;
  final String name;
  final double salary;
  final bool active;
  final String dept;
  const Emp(this.id, this.name, this.salary, this.active, this.dept);

  Emp copyWith({String? name, double? salary, bool? active, String? dept}) =>
      Emp(
        id,
        name ?? this.name,
        salary ?? this.salary,
        active ?? this.active,
        dept ?? this.dept,
      );
}

List<Emp> emps() => [
  for (var i = 1; i <= 4; i++) Emp(i, 'Emp $i', 1000.0 * i, true, 'IT'),
];

/// A table whose edits replace rows by new instances, like a real app.
class Host extends StatefulWidget {
  const Host({super.key, this.rowKey = true, this.selection = false});
  final bool rowKey;
  final bool selection;

  @override
  State<Host> createState() => HostState();
}

class HostState extends State<Host> {
  List<Emp> items = emps();
  final edits = <String>[];

  @override
  Widget build(BuildContext context) => AdaptiveTableLayout<Emp>(
    items: items,
    showSelection: widget.selection,
    rowKey: widget.rowKey ? (e) => e.id : null,
    columns: [
      AdaptiveTableColumn(id: 'id', title: 'ID', width: 70),
      AdaptiveTableColumn(
        id: 'name',
        title: 'Name',
        width: 160,
        isEditable: true,
      ),
      AdaptiveTableColumn(
        id: 'salary',
        title: 'Salary',
        width: 140,
        isEditable: true,
        cellValidator: (v) => v is num && v < 0 ? 'negative' : null,
      ),
      AdaptiveTableColumn(
        id: 'active',
        title: 'Active',
        width: 100,
        isEditable: true,
      ),
      AdaptiveTableColumn(
        id: 'dept',
        title: 'Dept',
        width: 120,
        isEditable: true,
        editor: const CellEditor.dropdown(['IT', 'Sales']),
      ),
    ],
    valueProviders: {
      'id': (e) => e.id,
      'name': (e) => e.name,
      'salary': (e) => e.salary,
      'active': (e) => e.active,
      'dept': (e) => e.dept,
    },
    onCellEdited: (e, column, value) {
      edits.add('${e.id}.$column=$value');
      final updated = switch (column) {
        'name' => e.copyWith(name: value as String),
        'salary' => e.copyWith(salary: (value as num).toDouble()),
        'active' => e.copyWith(active: value as bool),
        _ => e.copyWith(dept: value as String),
      };
      setState(() {
        items = [for (final x in items) x.id == e.id ? updated : x];
      });
      return true;
    },
  );
}

void main() {
  String? clipboard;

  Future<HostState> pump(
    WidgetTester tester, {
    bool rowKey = true,
    bool selection = false,
  }) async {
    clipboard = null;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          clipboard = (call.arguments as Map)['text'] as String?;
        } else if (call.method == 'Clipboard.getData') {
          return {'text': clipboard};
        }
        return null;
      },
    );
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: Host(rowKey: rowKey, selection: selection),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return tester.state<HostState>(find.byType(Host));
  }

  Future<void> chord(
    WidgetTester tester,
    LogicalKeyboardKey modifier,
    LogicalKeyboardKey key,
  ) async {
    await tester.sendKeyDownEvent(modifier);
    await tester.sendKeyEvent(key);
    await tester.sendKeyUpEvent(modifier);
    await tester.pumpAndSettle();
  }

  const ctrl = LogicalKeyboardKey.controlLeft;
  const shift = LogicalKeyboardKey.shiftLeft;

  test('parseClipboard handles tabs, quotes and line endings', () {
    expect(TableGrid.parseClipboard('a\tb\r\nc\td\n'), [
      ['a', 'b'],
      ['c', 'd'],
    ]);
    expect(TableGrid.parseClipboard('"multi\nline"\t"say ""hi"""\tx'), [
      ['multi\nline', 'say "hi"', 'x'],
    ]);
    expect(TableGrid.parseClipboard('a\t\tb'), [
      ['a', '', 'b'],
    ]);
    expect(TableGrid.parseClipboard('5" pipe'), [
      ['5" pipe'],
    ]);
    expect(TableGrid.parseClipboard(''), isEmpty);
  });

  testWidgets('Shift + arrows select a range and Ctrl + C copies it', (
    tester,
  ) async {
    await pump(tester);
    await tester.tap(find.text('Emp 2'));
    await tester.pumpAndSettle();
    await chord(tester, shift, LogicalKeyboardKey.arrowDown);
    await chord(tester, shift, LogicalKeyboardKey.arrowRight);
    await chord(tester, ctrl, LogicalKeyboardKey.keyC);
    expect(clipboard, 'Emp 2\t2000\nEmp 3\t3000');
    expect(find.text('2 rows copied'), findsOneWidget);

    // A plain arrow collapses the range: one cell is copied again.
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pumpAndSettle();
    await chord(tester, ctrl, LogicalKeyboardKey.keyC);
    expect(clipboard, 'Emp 3');
  });

  testWidgets('Shift + click and mouse drag extend the range', (tester) async {
    await pump(tester);
    await tester.tap(find.text('Emp 1'));
    await tester.pumpAndSettle();
    await tester.sendKeyDownEvent(shift);
    await tester.tap(find.text('3000'));
    await tester.sendKeyUpEvent(shift);
    await tester.pumpAndSettle();
    await chord(tester, ctrl, LogicalKeyboardKey.keyC);
    expect(clipboard, 'Emp 1\t1000\nEmp 2\t2000\nEmp 3\t3000');

    final mouse = await tester.startGesture(
      tester.getCenter(find.text('2')),
      kind: PointerDeviceKind.mouse,
    );
    await tester.pump();
    await mouse.moveTo(tester.getCenter(find.text('Emp 3')));
    await tester.pump();
    await mouse.up();
    await tester.pumpAndSettle();
    await chord(tester, ctrl, LogicalKeyboardKey.keyC);
    expect(clipboard, '2\tEmp 2\n3\tEmp 3');

    // Escape drops the range first.
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    await chord(tester, ctrl, LogicalKeyboardKey.keyC);
    expect(clipboard, 'Emp 3');
  });

  testWidgets('Ctrl + A selects every cell without row checkboxes', (
    tester,
  ) async {
    await pump(tester);
    await tester.tap(find.text('Emp 1'));
    await tester.pumpAndSettle();
    await chord(tester, ctrl, LogicalKeyboardKey.keyA);
    await chord(tester, ctrl, LogicalKeyboardKey.keyC);
    expect(clipboard!.split('\n'), hasLength(4));
    expect(clipboard, startsWith('1\tEmp 1\t1000\t✓\tIT\n'));
  });

  for (final rowKey in [true, false]) {
    testWidgets('Ctrl + V pastes typed cells (rowKey: $rowKey)', (
      tester,
    ) async {
      final host = await pump(tester, rowKey: rowKey);
      // Two rows from a spreadsheet: name, salary, active, dept. The id
      // column is not editable, bad values are skipped.
      clipboard =
          'Sara\t١٬٥٠٠٫٥\tno\tSales\r\n'
          'Omar\tabc\tmaybe\tHR\r\n';
      await tester.tap(find.text('Emp 2'));
      await tester.pumpAndSettle();
      await chord(tester, ctrl, LogicalKeyboardKey.keyV);
      expect(host.edits, [
        '2.name=Sara',
        '2.salary=1500.5',
        '2.active=false',
        '2.dept=Sales',
        '3.name=Omar',
      ]);
      final row2 = host.items[1];
      expect(
        [row2.name, row2.salary, row2.active, row2.dept],
        ['Sara', 1500.5, false, 'Sales'],
        reason: 'each edit must build on the previous one',
      );
      expect(host.items[2].name, 'Omar');
      expect(host.items[2].salary, 3000);
      expect(find.text('5 cells pasted'), findsOneWidget);
    });
  }

  testWidgets('one copied value fills the selected range', (tester) async {
    final host = await pump(tester);
    clipboard = '-5';
    await tester.tap(find.text('1000'));
    await tester.pumpAndSettle();
    await chord(tester, shift, LogicalKeyboardKey.arrowDown);
    await chord(tester, ctrl, LogicalKeyboardKey.keyV);
    expect(host.edits, isEmpty, reason: 'rejected by the validator');
    expect(find.text('Nothing to paste here'), findsOneWidget);

    clipboard = '750';
    await chord(tester, ctrl, LogicalKeyboardKey.keyV);
    expect(host.edits, ['1.salary=750', '2.salary=750']);
  });

  testWidgets('with row checkboxes Ctrl + A still selects rows', (
    tester,
  ) async {
    await pump(tester, selection: true);
    await tester.tap(find.text('Emp 1'));
    await tester.pumpAndSettle();
    await chord(tester, ctrl, LogicalKeyboardKey.keyA);
    expect(find.text('4 selected'), findsNothing); // no title, no badge
    await chord(tester, ctrl, LogicalKeyboardKey.keyC);
    expect(clipboard!.split('\n'), hasLength(5)); // header + 4 rows
  });
}
