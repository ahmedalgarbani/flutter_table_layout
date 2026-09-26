import 'package:flutter_table_layout/flutter_table_layout.dart';
import 'package:flutter_test/flutter_test.dart';

class Row {
  final int id;
  final String name;
  final DateTime date;
  Row(this.id, this.name, this.date);
}

List<Row> _rows(int n) => List.generate(
  n,
  (i) => Row(i + 1, 'Row ${i + 1}', DateTime(2026, 1, i + 1)),
);

const _columns = [
  ColumnDefinition(id: 'id', title: 'ID'),
  ColumnDefinition(id: 'name', title: 'Name'),
];

final _providers = <String, dynamic Function(Row)>{
  'id': (r) => r.id,
  'name': (r) => r.name,
};

TableCubit<Row> _cubit(List<Row> rows, {List<ColumnDefinition>? columns}) =>
    TableCubit<Row>(
      items: rows,
      columns: columns ?? _columns,
      valueProviders: _providers,
      dateProvider: (r) => r.date,
    );

TableLoaded<Row> _loaded(TableCubit<Row> c) => c.state as TableLoaded<Row>;

void main() {
  group('TableCubit', () {
    test('works with a const column list (no mutation of input)', () {
      final c = _cubit(_rows(3));
      c.toggleColumnVisibility('name');
      expect(_loaded(c).hiddenColumnIds, ['name']);
      expect(_columns[1].isVisible, isTrue);
      c.close();
    });

    test('columns with isVisible:false start hidden', () {
      final c = _cubit(
        _rows(3),
        columns: const [
          ColumnDefinition(id: 'id', title: 'ID'),
          ColumnDefinition(id: 'name', title: 'Name', isVisible: false),
        ],
      );
      expect(_loaded(c).hiddenColumnIds, ['name']);
      c.close();
    });

    test('the last visible column cannot be hidden', () {
      final c = _cubit(_rows(3));
      c.toggleColumnVisibility('name');
      c.toggleColumnVisibility('id');
      expect(_loaded(c).hiddenColumnIds, ['name']);
      c.close();
    });

    test('non-hideable columns cannot be hidden', () {
      final c = _cubit(
        _rows(3),
        columns: const [
          ColumnDefinition(id: 'id', title: 'ID', isHideable: false),
          ColumnDefinition(id: 'name', title: 'Name'),
        ],
      );
      c.toggleColumnVisibility('id');
      expect(_loaded(c).hiddenColumnIds, isEmpty);
      c.close();
    });

    test('date boundaries can be cleared one at a time', () {
      final c = _cubit(_rows(20));
      c.updateDateRange(DateTime(2026, 1, 5), DateTime(2026, 1, 10));
      expect(_loaded(c).totalCount, 6);

      c.updateDateRange(null, DateTime(2026, 1, 10));
      expect(_loaded(c).tableState.startDate, isNull);
      expect(_loaded(c).totalCount, 10);

      c.clearDateRange();
      expect(_loaded(c).tableState.endDate, isNull);
      expect(_loaded(c).totalCount, 20);
      c.close();
    });

    test('reversed date range is swapped', () {
      final c = _cubit(_rows(20));
      c.updateDateRange(DateTime(2026, 1, 10), DateTime(2026, 1, 5));
      expect(_loaded(c).totalCount, 6);
      c.close();
    });

    test('page is clamped when items shrink', () {
      final c = _cubit(_rows(25));
      c.setPage(3);
      expect(_loaded(c).paginatedItems.length, 5);
      c.setItems(_rows(12));
      expect(_loaded(c).tableState.currentPage, 2);
      expect(_loaded(c).paginatedItems.length, 2);
      c.close();
    });

    test('selection drops items that disappeared', () {
      final rows = _rows(5);
      final c = _cubit(rows);
      c.toggleRowSelection(rows[0]);
      c.toggleRowSelection(rows[1]);
      c.setItems(rows.sublist(1));
      expect(_loaded(c).selectedItems, [rows[1]]);
      c.close();
    });

    test('select all toggles only filtered rows and reports tristate', () {
      final rows = _rows(5);
      final c = _cubit(rows);
      c.updateSearchQuery('Row 1');
      c.toggleSelectAll(true);
      expect(_loaded(c).selectedItems, [rows[0]]);
      expect(_loaded(c).selectAllValue, isTrue);
      c.updateSearchQuery('');
      expect(_loaded(c).selectAllValue, isNull);
      c.toggleSelectAll(false);
      expect(_loaded(c).selectedItems, isEmpty);
      c.close();
    });

    test('sort toggles, sortBy and clearSort', () {
      final c = _cubit(_rows(3));
      c.toggleSort('id');
      expect(_loaded(c).paginatedItems.first.id, 1);
      c.toggleSort('id');
      expect(_loaded(c).paginatedItems.first.id, 3);
      c.clearSort();
      expect(_loaded(c).tableState.sortByColumnId, isNull);
      expect(_loaded(c).paginatedItems.first.id, 1);
      c.close();
    });

    test('custom filters can be set and removed', () {
      final c = TableCubit<Row>(
        items: _rows(10),
        columns: _columns,
        valueProviders: _providers,
        customFilterMatcher: (r, f) => r.id.isEven == f['even'],
      );
      c.setCustomFilter('even', true);
      expect(_loaded(c).totalCount, 5);
      c.setCustomFilter('even', null);
      expect(_loaded(c).totalCount, 10);
      c.close();
    });

    test('resetFilters clears search, dates and custom filters', () {
      final c = _cubit(_rows(10));
      c.updateSearchQuery('Row 1');
      c.updateDateRange(DateTime(2026, 1, 1), null);
      c.updateCustomFilters({'x': 1});
      c.resetFilters();
      expect(_loaded(c).tableState.hasActiveFilters, isFalse);
      c.close();
    });

    test('a throwing value provider emits TableError, then recovers', () {
      var fail = true;
      final c = TableCubit<Row>(
        items: _rows(3),
        columns: _columns,
        valueProviders: {'id': (r) => fail ? throw StateError('boom') : r.id},
        initialTableState: const TableStateModel(sortByColumnId: 'id'),
      );
      expect(c.state, isA<TableError<Row>>());
      fail = false;
      c.setPage(1);
      expect(c.state, isA<TableLoaded<Row>>());
      c.close();
    });

    test('row expansion toggles', () {
      final rows = _rows(2);
      final c = _cubit(rows);
      c.toggleRowExpansion(rows[0]);
      expect(_loaded(c).expandedItems, [rows[0]]);
      c.collapseAll();
      expect(_loaded(c).expandedItems, isEmpty);
      c.close();
    });

    test('updateConfiguration drops sort on removed column', () {
      final c = _cubit(_rows(3));
      c.sortBy('name');
      c.updateConfiguration(
        columns: const [ColumnDefinition(id: 'id', title: 'ID')],
      );
      expect(_loaded(c).tableState.sortByColumnId, isNull);
      c.close();
    });
  });
}
