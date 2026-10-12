import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_table_layout/flutter_table_layout.dart';
import 'package:flutter_test/flutter_test.dart';

/// An immutable model without `==`: every edit creates a new instance.
class Doc {
  final int id;
  final String title;
  const Doc(this.id, this.title);
  Doc rename(String t) => Doc(id, t);
}

List<Doc> _docs(int n) => [for (var i = 1; i <= n; i++) Doc(i, 'Doc $i')];

const _columns = [
  ColumnDefinition(id: 'id', title: 'ID'),
  ColumnDefinition(id: 'title', title: 'Title'),
  ColumnDefinition(id: 'notes', title: 'Notes', isHideable: false),
];

final _providers = <String, dynamic Function(Doc)>{
  'id': (d) => d.id,
  'title': (d) => d.title,
  'notes': (d) => '',
};

TableLoaded<Doc> _loaded(TableCubit<Doc> c) => c.state as TableLoaded<Doc>;

void main() {
  group('JSON', () {
    test('TableStateModel round-trips', () {
      final state = TableStateModel(
        searchQuery: 'abc',
        sortByColumnId: 'title',
        sortAscending: false,
        additionalSorts: const [ColumnSort('id')],
        currentPage: 3,
        pageSize: 25,
        startDate: DateTime(2026, 1, 1),
        endDate: DateTime(2026, 1, 31),
        customFilters: const {'status': 'open', 'min': 5},
        columnFilters: const {'title': '>a'},
        groupByColumnId: 'id',
      );
      final copy = TableStateModel.fromJson(
        jsonDecode(jsonEncode(state.toJson())) as Map<String, Object?>,
      );
      expect(copy, state);
      expect(copy.sorts, state.sorts);
    });

    test('fromJson ignores malformed entries', () {
      final s = TableStateModel.fromJson({
        'search': 12,
        'sorts': [
          'x',
          {'column': 'id'},
          {'ascending': false},
        ],
        'page': 'two',
        'startDate': 'not a date',
        'columnFilters': {'a': 1, 'b': 'x'},
      });
      expect(s.searchQuery, '');
      expect(s.sorts, [const ColumnSort('id')]);
      expect(s.currentPage, 1);
      expect(s.startDate, isNull);
      expect(s.columnFilters, {'b': 'x'});
    });

    test('TableSnapshot encode / tryDecode', () {
      const snapshot = TableSnapshot(
        tableState: TableStateModel(searchQuery: 'q', pageSize: 50),
        hiddenColumnIds: ['notes'],
        columnWidths: {'title': 240},
        columnOrder: ['title', 'id'],
        columnPins: {'id': ColumnPin.start},
      );
      final decoded = TableSnapshot.tryDecode(snapshot.encode());
      expect(decoded, snapshot);
      expect(decoded.hashCode, snapshot.hashCode);
      expect(TableSnapshot.tryDecode(null), isNull);
      expect(TableSnapshot.tryDecode('{oops'), isNull);
      expect(TableSnapshot.tryDecode('[1, 2]'), isNull);
      expect(
        TableSnapshot.tryDecode('{"pins": {"id": "sideways"}}')!.columnPins,
        isEmpty,
      );
    });
  });

  group('TableCubit snapshots', () {
    test('snapshot / restoreSnapshot with unknown columns ignored', () {
      final c = TableCubit<Doc>(
        items: _docs(30),
        columns: _columns,
        valueProviders: _providers,
      );
      c.restoreSnapshot(
        const TableSnapshot(
          tableState: TableStateModel(
            sortByColumnId: 'gone',
            additionalSorts: [ColumnSort('title', ascending: false)],
            columnFilters: {'gone': 'x', 'title': 'Doc 1'},
            groupByColumnId: 'gone',
            pageSize: 5,
          ),
          hiddenColumnIds: ['id', 'notes', 'gone'],
          columnWidths: {'title': 10, 'gone': 300},
          columnOrder: ['gone', 'title'],
          columnPins: {'title': ColumnPin.end, 'gone': ColumnPin.start},
        ),
      );
      final s = _loaded(c);
      expect(s.tableState.sorts, [const ColumnSort('title', ascending: false)]);
      expect(s.tableState.columnFilters, {'title': 'Doc 1'});
      expect(s.tableState.groupByColumnId, isNull);
      expect(s.hiddenColumnIds, ['id']); // notes is not hideable
      expect(s.columnWidths, {'title': 60}); // clamped to minWidth
      expect(s.columnOrder, ['title']);
      expect(s.columnPins, {'title': ColumnPin.end});
      expect(c.snapshot, s.snapshot);
      c.close();
    });

    test('initialSnapshot is applied before the first computation', () {
      final c = TableCubit<Doc>(
        items: _docs(30),
        columns: _columns,
        valueProviders: _providers,
        initialSnapshot: const TableSnapshot(
          tableState: TableStateModel(pageSize: 10, currentPage: 3),
        ),
      );
      expect(_loaded(c).paginatedItems.first.id, 21);
      c.close();
    });

    test('a snapshot cannot hide every column', () {
      final c = TableCubit<Doc>(
        items: _docs(3),
        columns: const [
          ColumnDefinition(id: 'id', title: 'ID'),
          ColumnDefinition(id: 'title', title: 'Title'),
        ],
        valueProviders: _providers,
      );
      c.restoreSnapshot(const TableSnapshot(hiddenColumnIds: ['id', 'title']));
      expect(_loaded(c).hiddenColumnIds, isEmpty);
      c.close();
    });
  });

  group('Layout persistence', () {
    testWidgets('onSnapshotChanged reports changes; initialSnapshot restores', (
      tester,
    ) async {
      final snapshots = <TableSnapshot>[];
      final controller = AdaptiveTableController<Doc>();
      Widget table(TableSnapshot? initial) => MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: AdaptiveTableLayout<Doc>(
              key: ValueKey(initial),
              items: _docs(40),
              columns: [
                AdaptiveTableColumn(id: 'id', title: 'ID', width: 80),
                AdaptiveTableColumn(id: 'title', title: 'Title'),
              ],
              valueProviders: _providers,
              controller: controller,
              initialSnapshot: initial,
              onSnapshotChanged: snapshots.add,
            ),
          ),
        ),
      );
      tester.view.physicalSize = const Size(1200, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(table(null));
      await tester.pumpAndSettle();
      expect(snapshots, isEmpty); // nothing changed yet

      controller.sortBy('id', ascending: false);
      controller.setColumnWidth('title', 300);
      controller.goToPage(2);
      await tester.pumpAndSettle();
      expect(snapshots, isNotEmpty);
      final saved = snapshots.last.encode();

      // "Next visit".
      await tester.pumpWidget(table(TableSnapshot.tryDecode(saved)));
      await tester.pumpAndSettle();
      expect(controller.tableState.sortByColumnId, 'id');
      expect(controller.tableState.sortAscending, isFalse);
      expect(controller.tableState.currentPage, 2);
      expect(controller.value!.columnWidths['title'], 300);
      expect(find.text('Doc 30'), findsOneWidget); // 40..31 on page 1
    });
  });

  group('rowKey', () {
    test('selection and expansion survive new instances', () {
      var docs = _docs(5);
      final c = TableCubit<Doc>(
        items: docs,
        columns: _columns,
        valueProviders: _providers,
        rowKey: (d) => d.id,
      );
      c.toggleRowSelection(docs[1]);
      c.toggleRowExpansion(docs[2]);
      docs = [for (final d in docs) d.rename('${d.title}!')];
      c.setItems(docs);
      final s = _loaded(c);
      expect(s.selectedItems.single.title, 'Doc 2!'); // fresh instance
      expect(s.expandedItems.single.title, 'Doc 3!');
      expect(s.isSelected(docs[1]), isTrue);
      expect(s.selectAllValue, isNull);
      // Toggling a new instance of a selected row deselects it.
      c.toggleRowSelection(docs[1].rename('again'));
      expect(_loaded(c).selectedItems, isEmpty);
      c.close();
    });

    test('without rowKey new instances lose the selection (by design)', () {
      var docs = _docs(3);
      final c = TableCubit<Doc>(
        items: docs,
        columns: _columns,
        valueProviders: _providers,
      );
      c.toggleRowSelection(docs[0]);
      docs = [for (final d in docs) d.rename(d.title)];
      c.setItems(docs);
      expect(_loaded(c).selectedItems, isEmpty);
      c.close();
    });

    test('server pages keep the selection of other pages', () async {
      final c = TableCubit<Doc>(
        items: const [],
        columns: _columns,
        valueProviders: _providers,
        rowKey: (d) => d.id,
        initialTableState: const TableStateModel(pageSize: 2),
        dataSource: AdaptiveTableDataSource.fromCallback((q) async {
          final start = (q.currentPage - 1) * q.pageSize;
          // New instances on every request.
          return TableDataPage(
            items: _docs(6).skip(start).take(q.pageSize).toList(),
            totalCount: 6,
          );
        }),
      );
      await pumpEventQueue();
      c.toggleSelectAll(true); // page 1: docs 1, 2
      c.setPage(2);
      await pumpEventQueue();
      c.toggleRowSelection(_loaded(c).paginatedItems.first); // doc 3
      expect(_loaded(c).selectedItems.map((d) => d.id), [1, 2, 3]);
      c.setPage(1);
      await pumpEventQueue();
      final s = _loaded(c);
      expect(s.selectAllValue, isTrue);
      expect(s.selectedItems.map((d) => d.id), [1, 2, 3]);
      await c.close();
    });

    testWidgets('grid keeps the checkbox ticked after an immutable edit', (
      tester,
    ) async {
      var docs = _docs(3);
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
                  child: AdaptiveTableLayout<Doc>(
                    items: docs,
                    columns: [
                      AdaptiveTableColumn(id: 'id', title: 'ID', width: 80),
                      AdaptiveTableColumn(id: 'title', title: 'Title'),
                    ],
                    valueProviders: _providers,
                    rowKey: (d) => d.id,
                  ),
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(Checkbox).at(2)); // Doc 2
      await tester.pumpAndSettle();
      setOuter(() => docs = [for (final d in docs) d.rename('${d.title}*')]);
      await tester.pumpAndSettle();
      final boxes = tester.widgetList<Checkbox>(find.byType(Checkbox)).toList();
      expect(boxes[2].value, isTrue);
      expect(find.text('Doc 2*'), findsOneWidget);
    });
  });
}
