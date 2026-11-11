import 'package:flutter/material.dart';
import 'package:flutter_table_layout/flutter_table_layout.dart';
import 'package:flutter_test/flutter_test.dart';

class Row4 {
  final String name;
  final int debit;
  final int credit;
  const Row4(this.name, this.debit, this.credit);
}

const rows = [
  Row4('A', 1, 10),
  Row4('B', 2, 20),
  Row4('C', 3, 30),
  Row4('D', 4, 40),
];

class Host extends StatefulWidget {
  const Host({super.key, this.direction = TextDirection.ltr});
  final TextDirection direction;

  @override
  State<Host> createState() => HostState();
}

class HostState extends State<Host> {
  List<Row4> items = rows;
  final controller = AdaptiveTableController<Row4>();

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: widget.direction,
    child: AdaptiveTableLayout<Row4>(
      items: items,
      controller: controller,
      rowKey: (r) => r.name,
      columnGroups: const [
        TableColumnGroup(title: 'Amounts', columnIds: ['debit', 'credit']),
      ],
      columns: [
        AdaptiveTableColumn(id: 'name', title: 'Name', width: 200),
        AdaptiveTableColumn(id: 'debit', title: 'Debit', width: 120),
        AdaptiveTableColumn(id: 'credit', title: 'Credit', width: 140),
        AdaptiveTableColumn(id: 'note', title: 'Note', width: 100),
      ],
      valueProviders: {
        'name': (r) => r.name,
        'debit': (r) => r.debit,
        'credit': (r) => r.credit,
      },
      onRowReorder: (row, before) => setState(() {
        final next = [...items]..remove(row);
        next.insert(before == null ? next.length : next.indexOf(before), row);
        items = next;
      }),
    ),
  );
}

void main() {
  Future<HostState> pump(
    WidgetTester tester, {
    TextDirection direction = TextDirection.ltr,
  }) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(child: Host(direction: direction)),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return tester.state<HostState>(find.byType(Host));
  }

  for (final direction in TextDirection.values) {
    testWidgets('a group band spans its columns ($direction)', (tester) async {
      await pump(tester, direction: direction);
      final band = tester.getRect(find.text('Amounts'));
      final debit = tester.getRect(find.text('Debit'));
      final credit = tester.getRect(find.text('Credit'));
      expect(band.bottom, lessThanOrEqualTo(debit.top));
      final left = direction == TextDirection.ltr ? debit : credit;
      final right = direction == TextDirection.ltr ? credit : debit;
      // Centered over the two member columns (120 + 140 px).
      expect(band.center.dx, greaterThan(left.left));
      expect(band.center.dx, lessThan(right.right));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('members split by another column get one band each', (
    tester,
  ) async {
    final host = await pump(tester);
    host.controller.moveColumn('name', beforeColumnId: 'credit');
    await tester.pumpAndSettle();
    expect(find.text('Amounts'), findsNWidgets(2));
    host.controller.setColumnVisibility('debit', false);
    host.controller.setColumnVisibility('credit', false);
    await tester.pumpAndSettle();
    expect(find.text('Amounts'), findsNothing);
  });

  testWidgets('rows are reordered by dragging the handle', (tester) async {
    final host = await pump(tester);
    final handles = find.byIcon(Icons.drag_indicator);
    expect(handles, findsNWidgets(4));

    Future<void> drag(int from, Offset to) async {
      final gesture = await tester.startGesture(
        tester.getCenter(handles.at(from)),
      );
      await tester.pump(const Duration(milliseconds: 20));
      await gesture.moveBy(const Offset(0, 12));
      await tester.pump();
      await gesture.moveTo(to);
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();
    }

    // D before B.
    await drag(3, tester.getCenter(handles.at(1)));
    expect(host.items.map((r) => r.name), ['A', 'D', 'B', 'C']);
    // A onto the lower half of the last row: to the end.
    final last = tester.getRect(find.text('C'));
    await drag(0, Offset(tester.getCenter(handles.at(3)).dx, last.bottom + 6));
    expect(host.items.map((r) => r.name), ['D', 'B', 'C', 'A']);
  });

  testWidgets('handles are disabled while sorted or grouped', (tester) async {
    final host = await pump(tester);
    host.controller.sortBy('debit', ascending: false);
    await tester.pumpAndSettle();
    expect(find.byType(Draggable<Object>), findsNothing);
    expect(
      find.byTooltip('Clear the sort and grouping to reorder rows'),
      findsNWidgets(4),
    );
    host.controller.clearSort();
    await tester.pumpAndSettle();
    expect(find.byTooltip('Drag to reorder'), findsNWidgets(4));
  });
}
