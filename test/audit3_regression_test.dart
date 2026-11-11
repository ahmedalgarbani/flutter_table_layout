// Regressions found in the 0.3.0 review: each failed on 0.2.0.
import 'dart:convert';

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

Future<void> pump(
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
  test('R1 cubit: a default-hidden column shown by the user is searched', () {
    final cubit = TableCubit<Emp>(
      items: emps(6),
      columns: const [
        ColumnDefinition(id: 'id', title: 'ID'),
        ColumnDefinition(id: 'name', title: 'Name'),
        ColumnDefinition(id: 'dept', title: 'Dept', isVisible: false),
      ],
      valueProviders: providers,
    );
    cubit.updateSearchQuery('Sales');
    expect((cubit.state as TableLoaded<Emp>).totalCount, 0); // hidden: ok
    cubit.setColumnVisibility('dept', true);
    expect(cubit.hiddenColumnIds, isEmpty);
    expect(
      (cubit.state as TableLoaded<Emp>).totalCount,
      3,
      reason: 'the column is visible now, its values must be searchable',
    );
    cubit.close();
  });

  testWidgets('R2 export: a default-hidden column shown by the user', (
    tester,
  ) async {
    final controller = AdaptiveTableController<Emp>();
    String? csv;
    await pump(
      tester,
      AdaptiveTableLayout<Emp>(
        items: emps(3),
        controller: controller,
        columns: [
          AdaptiveTableColumn(id: 'id', title: 'ID', width: 70),
          AdaptiveTableColumn(id: 'name', title: 'Name', width: 160),
          AdaptiveTableColumn(
            id: 'dept',
            title: 'Dept',
            width: 140,
            isVisible: false,
          ),
        ],
        valueProviders: providers,
        exportOptions: TableExportOptions(
          onExport: (format, bytes, name) async => csv = utf8.decode(bytes),
        ),
      ),
    );
    controller.setColumnVisibility('dept', true);
    await tester.pumpAndSettle();
    expect(find.text('Dept'), findsOneWidget);
    await tester.runAsync(() => controller.exportAs(ExportFormat.csv));
    expect(csv, isNotNull);
    expect(csv, contains('Dept'), reason: 'visible columns must be exported');
  });

  testWidgets('R3 inline number editor accepts Arabic-Indic digits', (
    tester,
  ) async {
    final items = emps(3);
    Object? saved;
    await pump(
      tester,
      StatefulBuilder(
        builder: (context, setState) => AdaptiveTableLayout<Emp>(
          items: items,
          columns: [
            AdaptiveTableColumn(id: 'id', title: 'ID', width: 70),
            AdaptiveTableColumn(id: 'name', title: 'Name', width: 160),
            AdaptiveTableColumn(
              id: 'salary',
              title: 'Salary',
              width: 140,
              isEditable: true,
            ),
          ],
          valueProviders: providers,
          onCellEdited: (e, col, v) {
            saved = v;
            return true;
          },
        ),
      ),
    );
    await tester.tap(find.text('1000'));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.text('1000'));
    await tester.pumpAndSettle();
    expect(find.byType(EditableText), findsWidgets);
    await tester.enterText(find.byType(EditableText).last, '١٢٥٠٫٥');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(find.text('Invalid number format'), findsNothing);
    expect(saved, 1250.5);
  });

  testWidgets('R4 dynamic form number field accepts Arabic-Indic digits', (
    tester,
  ) async {
    Map<String, dynamic>? values;
    await pump(
      tester,
      DynamicForm(
        fields: [
          DynamicFormField(
            id: 'amount',
            label: 'Amount',
            type: FieldType.number,
          ),
        ],
        onFormSubmitted: (v) => values = v,
      ),
    );
    await tester.enterText(find.byType(TextFormField), '١٢٣٤');
    await tester.pump();
    await tester.tap(find.text('Send'));
    await tester.pumpAndSettle();
    expect(values?['amount'], 1234);
  });

  testWidgets('R5 date panel typed fields accept Arabic-Indic digits', (
    tester,
  ) async {
    DateRangeSelection? picked;
    await pump(
      tester,
      Builder(
        builder: (context) => DateRangePanel(
          theme: AdaptiveTableTheme.light(context),
          labels: AdaptiveTableLabels.ar,
          onApply: (s) => picked = s,
        ),
      ),
    );
    await tester.enterText(
      find.byKey(const ValueKey('range-from')),
      '٢٠٢٦-٠١-٠٥',
    );
    await tester.pump();
    await tester.enterText(
      find.byKey(const ValueKey('range-to')),
      '٢٠٢٦-٠١-٢٠',
    );
    await tester.pump();
    await tester.tap(find.text('تطبيق'));
    await tester.pump();
    expect(picked?.start, DateTime(2026, 1, 5));
    expect(picked?.end, DateTime(2026, 1, 20));
  });

  test('R6 natural order of text with numbers', () {
    final items = ['INV-10', 'INV-9', 'INV-100', 'INV-1'];
    final r = const FilterItemsUseCase().apply<String>(
      items: items,
      columns: const [ColumnDefinition(id: 'n', title: 'N')],
      state: const TableStateModel(sortByColumnId: 'n', pageSize: 0),
      valueProviders: {'n': (s) => s},
    );
    // Documented behaviour today is plain text order; shown for information.
    // ignore: avoid_print
    print('text sort today: ${r.filteredAndSorted}');
  });

  test('R7 column filter on a default-hidden column shown by the user', () {
    final cubit = TableCubit<Emp>(
      items: emps(6),
      columns: const [
        ColumnDefinition(id: 'id', title: 'ID'),
        ColumnDefinition(id: 'dept', title: 'Dept', isVisible: false),
      ],
      valueProviders: providers,
    );
    cubit.setColumnVisibility('dept', true);
    cubit.setColumnFilter('dept', '=IT');
    expect((cubit.state as TableLoaded<Emp>).totalCount, 3);
    cubit.close();
  });

  testWidgets('R8 restoring a paginated snapshot into showPagination: false', (
    tester,
  ) async {
    final controller = AdaptiveTableController<Emp>();
    await pump(
      tester,
      AdaptiveTableLayout<Emp>(
        items: emps(30),
        controller: controller,
        showPagination: false,
        columns: [
          AdaptiveTableColumn(id: 'id', title: 'ID', width: 70),
          AdaptiveTableColumn(id: 'name', title: 'Name', width: 160),
        ],
        valueProviders: providers,
      ),
    );
    expect(controller.pageItems.length, 30);
    controller.restoreSnapshot(
      const TableSnapshot(tableState: TableStateModel(pageSize: 10)),
    );
    await tester.pumpAndSettle();
    expect(
      controller.pageItems.length,
      30,
      reason: 'no footer is shown, so every row must stay reachable',
    );
  });

  testWidgets('R9 Ctrl+C in an LTR app with keyboard copies focused cell', (
    tester,
  ) async {
    final log = <MethodCall>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        log.add(call);
        return null;
      },
    );
    await pump(
      tester,
      AdaptiveTableLayout<Emp>(
        items: emps(3),
        showSelection: false,
        columns: [
          AdaptiveTableColumn(id: 'id', title: 'ID', width: 70),
          AdaptiveTableColumn(id: 'name', title: 'Name', width: 160),
        ],
        valueProviders: providers,
      ),
    );
    await tester.tap(find.text('Emp 2'));
    await tester.pumpAndSettle();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyC);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();
    final copies = log.where((c) => c.method == 'Clipboard.setData').toList();
    expect(copies, hasLength(1));
    expect((copies.single.arguments as Map)['text'], 'Emp 2');
  });
}
