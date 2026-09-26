import 'dart:async';

import 'package:flutter_table_layout/flutter_table_layout.dart';
import 'package:flutter_test/flutter_test.dart';

class Row {
  final int id;
  final String name;
  final String team;
  final double score;
  final DateTime date;
  Row(this.id, this.name, this.team, this.score, this.date);
}

final _rows = [
  Row(1, 'Ali', 'B', 50, DateTime(2026, 1, 5)),
  Row(2, 'Sara', 'A', 90, DateTime(2026, 2, 1)),
  Row(3, 'Omar', 'A', 70, DateTime(2026, 3, 9)),
  Row(4, 'Lina', 'B', 90, DateTime(2026, 4, 1)),
  Row(5, 'Zaid', 'A', 10, DateTime(2026, 5, 2)),
];

const _cols = [
  ColumnDefinition(id: 'id', title: 'ID'),
  ColumnDefinition(id: 'name', title: 'Name'),
  ColumnDefinition(id: 'team', title: 'Team'),
  ColumnDefinition(id: 'score', title: 'Score'),
  ColumnDefinition(id: 'date', title: 'Date'),
];

final _providers = <String, dynamic Function(Row)>{
  'id': (r) => r.id,
  'name': (r) => r.name,
  'team': (r) => r.team,
  'score': (r) => r.score,
  'date': (r) => r.date,
};

TableQueryResult<Row> _apply(TableStateModel s) =>
    const FilterItemsUseCase().apply<Row>(
      items: _rows,
      columns: _cols,
      state: s,
      valueProviders: _providers,
    );

void main() {
  group('ColumnFilterMatcher', () {
    test('text operators', () {
      expect(ColumnFilterMatcher.matches('Hello', 'ell'), isTrue);
      expect(ColumnFilterMatcher.matches('Hello', '=hello'), isTrue);
      expect(ColumnFilterMatcher.matches('Hello', '=hell'), isFalse);
      expect(ColumnFilterMatcher.matches('Hello', '!=hello'), isFalse);
      expect(ColumnFilterMatcher.matches('Hello', '!xyz'), isTrue);
      expect(ColumnFilterMatcher.matches('Hello', ''), isTrue);
      expect(ColumnFilterMatcher.matches(null, 'x'), isFalse);
    });

    test('numeric comparisons and ranges', () {
      expect(ColumnFilterMatcher.matches(50, '>10'), isTrue);
      expect(ColumnFilterMatcher.matches(50, '>=50'), isTrue);
      expect(ColumnFilterMatcher.matches(50, '<50'), isFalse);
      expect(ColumnFilterMatcher.matches(50, '<= 50'), isTrue);
      expect(ColumnFilterMatcher.matches(50, '10..60'), isTrue);
      expect(ColumnFilterMatcher.matches(70, '10..60'), isFalse);
      expect(ColumnFilterMatcher.matches(1500.5, '>1,000'), isTrue);
      expect(ColumnFilterMatcher.matches(null, '>1'), isFalse);
    });

    test('dates, booleans and OR lists', () {
      final d = DateTime(2026, 3, 9, 14);
      expect(ColumnFilterMatcher.matches(d, '>=2026-03-09'), isTrue);
      expect(ColumnFilterMatcher.matches(d, '=2026-03-09'), isTrue);
      expect(ColumnFilterMatcher.matches(d, '2026-01-01..2026-02-01'), isFalse);
      expect(ColumnFilterMatcher.matches(true, '=yes'), isTrue);
      expect(ColumnFilterMatcher.matches('A', 'x, a'), isTrue);
      expect(ColumnFilterMatcher.matches(5, '>10 | <6'), isTrue);
    });
  });

  group('FilterItemsUseCase advanced', () {
    test('column filters combine with AND', () {
      final r = _apply(
        const TableStateModel(columnFilters: {'team': '=a', 'score': '>=70'}),
      );
      expect(r.filteredAndSorted.map((e) => e.id), [2, 3]);
    });

    test('multi-level sort', () {
      final r = _apply(
        const TableStateModel(
          sortByColumnId: 'score',
          sortAscending: false,
          additionalSorts: [ColumnSort('name')],
        ),
      );
      // 90 (Lina, Sara), 70, 50, 10
      expect(r.filteredAndSorted.map((e) => e.name), [
        'Lina',
        'Sara',
        'Omar',
        'Ali',
        'Zaid',
      ]);
    });

    test('grouping sorts by the group column first', () {
      final r = _apply(
        const TableStateModel(groupByColumnId: 'team', sortByColumnId: 'score'),
      );
      expect(r.filteredAndSorted.map((e) => e.team), ['A', 'A', 'A', 'B', 'B']);
      expect(r.filteredAndSorted.first.name, 'Zaid'); // lowest score in A
    });

    test('TableStateModel equality covers new fields', () {
      const a = TableStateModel(columnFilters: {'x': '1'});
      const b = TableStateModel(columnFilters: {'x': '1'});
      expect(a, b);
      expect(a.hasActiveFilters, isTrue);
      expect(a == const TableStateModel(), isFalse);
      expect(
        const TableStateModel(
          groupByColumnId: 'a',
        ).copyWith(clearGroup: true).groupByColumnId,
        isNull,
      );
      expect(
        const TableStateModel(
          sortByColumnId: 'a',
          additionalSorts: [ColumnSort('b')],
        ).copyWith(clearSort: true).sorts,
        isEmpty,
      );
    });
  });

  group('TableCubit advanced', () {
    TableCubit<Row> cubit() => TableCubit<Row>(
      items: _rows,
      columns: _cols,
      valueProviders: _providers,
    );
    TableLoaded<Row> loaded(TableCubit<Row> c) => c.state as TableLoaded<Row>;

    test('additive sort adds and toggles levels', () {
      final c = cubit();
      c.toggleSort('team');
      c.toggleSort('score', additive: true);
      expect(c.tableState.sorts, [
        const ColumnSort('team'),
        const ColumnSort('score'),
      ]);
      c.toggleSort('score', additive: true);
      expect(c.tableState.sorts.last.ascending, isFalse);
      c.toggleSort('name'); // plain click replaces everything
      expect(c.tableState.sorts, [const ColumnSort('name')]);
      c.close();
    });

    test('column filters, reset and grouping collapse', () {
      final c = cubit();
      c.setColumnFilter('team', 'b');
      expect(loaded(c).totalCount, 2);
      c.resetFilters();
      expect(loaded(c).totalCount, 5);
      c.groupBy('team');
      c.toggleGroupCollapsed('A');
      expect(loaded(c).collapsedGroups, {'A'});
      c.groupBy(null);
      expect(loaded(c).collapsedGroups, isEmpty);
      c.close();
    });

    test('column layout: width clamp, order, pins, arrange and reset', () {
      final c = TableCubit<Row>(
        items: _rows,
        columns: [
          ..._cols.take(4),
          const ColumnDefinition(id: 'date', title: 'Date', minWidth: 90),
        ],
        valueProviders: _providers,
      );
      c.setColumnWidth('date', 10);
      expect(loaded(c).columnWidths['date'], 90);
      c.moveColumn('score', beforeColumnId: 'id');
      c.setColumnPin('date', ColumnPin.start);
      final ids = loaded(c).arrange(c.columns, (d) => d).map((d) => d.id);
      expect(ids, ['date', 'score', 'id', 'name', 'team']);
      c.resetColumnLayout();
      expect(loaded(c).arrange(c.columns, (d) => d).map((d) => d.id), [
        'id',
        'name',
        'team',
        'score',
        'date',
      ]);
      c.close();
    });
  });

  group('Server-side data source', () {
    test('fetches pages with the query and reports totals', () async {
      final queries = <TableStateModel>[];
      final c = TableCubit<int>(
        items: const [],
        columns: const [ColumnDefinition(id: 'n', title: 'N')],
        valueProviders: {'n': (i) => i},
        dataSource: AdaptiveTableDataSource.fromCallback((q) async {
          queries.add(q);
          final start = (q.currentPage - 1) * q.pageSize;
          return TableDataPage(
            items: [for (var i = start; i < start + q.pageSize; i++) i],
            totalCount: 95,
          );
        }),
      );
      expect((c.state as TableLoaded<int>).isFetching, isTrue);
      await pumpEventQueue();
      final s = c.state as TableLoaded<int>;
      expect(s.isFetching, isFalse);
      expect(s.paginatedItems.first, 0);
      expect(s.totalCount, 95);
      expect(s.totalPages, 10);

      c.setPage(3);
      await pumpEventQueue();
      expect((c.state as TableLoaded<int>).paginatedItems.first, 20);
      c.updateSearchQuery('x');
      await pumpEventQueue();
      expect(queries.last.searchQuery, 'x');
      expect(queries.last.currentPage, 1);
      await c.close();
    });

    test('ignores stale responses', () async {
      final completers = <Completer<TableDataPage<int>>>[];
      final c = TableCubit<int>(
        items: const [],
        columns: const [ColumnDefinition(id: 'n', title: 'N')],
        valueProviders: {'n': (i) => i},
        dataSource: AdaptiveTableDataSource.fromCallback((q) {
          final completer = Completer<TableDataPage<int>>();
          completers.add(completer);
          return completer.future;
        }),
      );
      c.updateSearchQuery('new');
      completers[1].complete(const TableDataPage(items: [2], totalCount: 1));
      await pumpEventQueue();
      completers[0].complete(const TableDataPage(items: [1], totalCount: 1));
      await pumpEventQueue();
      expect((c.state as TableLoaded<int>).paginatedItems, [2]);
      await c.close();
    });

    test('clamps to the last page and recovers from errors', () async {
      var fail = true;
      final c = TableCubit<int>(
        items: const [],
        columns: const [ColumnDefinition(id: 'n', title: 'N')],
        valueProviders: {'n': (i) => i},
        initialTableState: const TableStateModel(currentPage: 9),
        dataSource: AdaptiveTableDataSource.fromCallback((q) async {
          if (fail) throw StateError('offline');
          return TableDataPage(items: [q.currentPage], totalCount: 25);
        }),
      );
      await pumpEventQueue();
      expect(c.state, isA<TableError<int>>());
      fail = false;
      c.refresh();
      await pumpEventQueue();
      final s = c.state as TableLoaded<int>;
      expect(s.tableState.currentPage, 3);
      expect(s.paginatedItems, [3]);
      await c.close();
    });
  });
}
