import 'package:flutter_table_layout/flutter_table_layout.dart';
import 'package:flutter_test/flutter_test.dart';

class TestItem {
  final int id;
  final String name;
  final double amount;
  final DateTime date;

  TestItem({
    required this.id,
    required this.name,
    required this.amount,
    required this.date,
  });
}

void main() {
  group('FilterItemsUseCase Tests', () {
    const useCase = FilterItemsUseCase();

    final testItems = [
      TestItem(
        id: 1,
        name: 'Item Alpha',
        amount: 150.0,
        date: DateTime(2026, 5, 10),
      ),
      TestItem(
        id: 2,
        name: 'Item Beta',
        amount: 50.0,
        date: DateTime(2026, 5, 15),
      ),
      TestItem(
        id: 3,
        name: 'Item Gamma',
        amount: 300.0,
        date: DateTime(2026, 5, 20),
      ),
    ];

    final columns = [
      const ColumnDefinition(id: 'id', title: 'ID', fieldName: 'id'),
      const ColumnDefinition(id: 'name', title: 'Name', fieldName: 'name'),
      const ColumnDefinition(
        id: 'amount',
        title: 'Amount',
        fieldName: 'amount',
      ),
    ];

    final valueProviders = <String, dynamic Function(TestItem)>{
      'id': (item) => item.id,
      'name': (item) => item.name,
      'amount': (item) => item.amount,
    };

    test('should slice items according to pagination', () {
      const state = TableStateModel(currentPage: 1, pageSize: 2);

      final (_, paginated, total) = useCase.run<TestItem>(
        items: testItems,
        columns: columns,
        state: state,
        valueProviders: valueProviders,
      );

      expect(total, 3);
      expect(paginated.length, 2);
      expect(paginated[0].id, 1);
      expect(paginated[1].id, 2);
    });

    test('should filter items by date range (inclusive, by day)', () {
      final state = TableStateModel(
        startDate: DateTime(2026, 5, 15, 23, 59),
        endDate: DateTime(2026, 5, 20),
      );

      final (filtered, _, total) = useCase.run<TestItem>(
        items: testItems,
        columns: columns,
        state: state,
        dateProvider: (item) => item.date,
        valueProviders: valueProviders,
      );

      expect(total, 2);
      expect(filtered.map((e) => e.id), [2, 3]);
    });

    test('should sort items ascending and descending', () {
      final (asc, _, _) = useCase.run<TestItem>(
        items: testItems,
        columns: columns,
        state: const TableStateModel(sortByColumnId: 'amount'),
        valueProviders: valueProviders,
      );
      expect(asc.map((e) => e.id), [2, 1, 3]);

      final (desc, _, _) = useCase.run<TestItem>(
        items: testItems,
        columns: columns,
        state: const TableStateModel(
          sortByColumnId: 'amount',
          sortAscending: false,
        ),
        valueProviders: valueProviders,
      );
      expect(desc.map((e) => e.id), [3, 1, 2]);
    });

    test('should search globally matching text queries', () {
      final (filtered, _, total) = useCase.run<TestItem>(
        items: testItems,
        columns: columns,
        state: const TableStateModel(searchQuery: 'beta'),
        valueProviders: valueProviders,
      );

      expect(total, 1);
      expect(filtered.first.name, 'Item Beta');
    });

    test('execute() works without value providers (Map items)', () {
      final maps = [
        {'name': 'Tea', 'qty': 2},
        {'name': 'Coffee', 'qty': 5},
      ];
      final (filtered, paginated, total) = useCase.execute<Map<String, Object>>(
        items: maps,
        columns: const [ColumnDefinition(id: 'name', title: 'Name')],
        state: const TableStateModel(searchQuery: 'cof'),
      );
      expect(total, 1);
      expect(filtered.single['name'], 'Coffee');
      expect(paginated.single['name'], 'Coffee');
    });

    test('execute() sorts when value providers are given', () {
      final (sorted, _, _) = useCase.execute<TestItem>(
        items: testItems,
        columns: columns,
        state: const TableStateModel(sortByColumnId: 'amount'),
        valueProviders: valueProviders,
      );
      expect(sorted.map((e) => e.id), [2, 1, 3]);
    });

    test('hidden columns are excluded from search', () {
      final r = useCase.apply<TestItem>(
        items: testItems,
        columns: columns,
        state: const TableStateModel(searchQuery: 'alpha'),
        valueProviders: valueProviders,
        hiddenColumnIds: {'name'},
      );
      expect(r.totalCount, 0);
    });

    test('non-searchable columns are excluded, search-only keys included', () {
      final r = useCase.apply<TestItem>(
        items: testItems,
        columns: [
          const ColumnDefinition(
            id: 'name',
            title: 'Name',
            isSearchable: false,
          ),
        ],
        state: const TableStateModel(searchQuery: 'gamma'),
        valueProviders: {
          'name': (i) => i.name,
          'tags': (i) => i.id == 1 ? 'gamma-tag' : '',
        },
      );
      expect(r.filteredAndSorted.map((e) => e.id), [1]);
    });

    test('mixed types and nulls sort without throwing, nulls last', () {
      final values = <Object?>[3, 'b', null, 1.5, 'A', null, true];
      final r = useCase.apply<Object?>(
        items: values,
        columns: const [ColumnDefinition(id: 'v', title: 'V')],
        state: const TableStateModel(sortByColumnId: 'v', pageSize: 0),
        valueProviders: {'v': (x) => x},
      );
      expect(r.filteredAndSorted.length, values.length);
      expect(r.filteredAndSorted.sublist(5), [null, null]);

      final desc = useCase.apply<Object?>(
        items: values,
        columns: const [ColumnDefinition(id: 'v', title: 'V')],
        state: const TableStateModel(
          sortByColumnId: 'v',
          sortAscending: false,
          pageSize: 0,
        ),
        valueProviders: {'v': (x) => x},
      );
      expect(desc.filteredAndSorted.sublist(5), [null, null]);
    });

    test('strings sort case-insensitively', () {
      final r = useCase.apply<String>(
        items: ['banana', 'Apple', 'cherry'],
        columns: const [ColumnDefinition(id: 's', title: 'S')],
        state: const TableStateModel(sortByColumnId: 's'),
        valueProviders: {'s': (x) => x},
      );
      expect(r.filteredAndSorted, ['Apple', 'banana', 'cherry']);
    });

    test('sorting is stable', () {
      final items = List.generate(50, (i) => (i, i % 3));
      final r = useCase.apply<(int, int)>(
        items: items,
        columns: const [ColumnDefinition(id: 'g', title: 'G')],
        state: const TableStateModel(sortByColumnId: 'g', pageSize: 0),
        valueProviders: {'g': (x) => x.$2},
      );
      for (var i = 1; i < r.filteredAndSorted.length; i++) {
        final a = r.filteredAndSorted[i - 1];
        final b = r.filteredAndSorted[i];
        if (a.$2 == b.$2) expect(a.$1 < b.$1, isTrue);
      }
    });

    test('out-of-range page is clamped to the last page', () {
      final r = useCase.apply<TestItem>(
        items: testItems,
        columns: columns,
        state: const TableStateModel(currentPage: 9, pageSize: 2),
        valueProviders: valueProviders,
      );
      expect(r.totalPages, 2);
      expect(r.effectivePage, 2);
      expect(r.paginated.single.id, 3);
    });

    test('pageSize <= 0 disables pagination', () {
      final r = useCase.apply<TestItem>(
        items: testItems,
        columns: columns,
        state: const TableStateModel(pageSize: 0),
        valueProviders: valueProviders,
      );
      expect(r.paginated.length, 3);
      expect(r.totalPages, 1);
    });

    test('empty input yields one empty page', () {
      final r = useCase.apply<TestItem>(
        items: const [],
        columns: columns,
        state: const TableStateModel(currentPage: 3),
        valueProviders: valueProviders,
      );
      expect(r.totalPages, 1);
      expect(r.effectivePage, 1);
      expect(r.paginated, isEmpty);
    });

    test('dates are searchable as yyyy-MM-dd', () {
      final r = useCase.apply<TestItem>(
        items: testItems,
        columns: const [ColumnDefinition(id: 'date', title: 'Date')],
        state: const TableStateModel(searchQuery: '2026-05-15'),
        valueProviders: {'date': (i) => i.date},
      );
      expect(r.filteredAndSorted.single.id, 2);
    });

    test('custom filter matcher', () {
      final r = useCase.apply<TestItem>(
        items: testItems,
        columns: columns,
        state: const TableStateModel(customFilters: {'min': 100}),
        valueProviders: valueProviders,
        customFilterMatcher: (item, f) => item.amount >= (f['min'] as num),
      );
      expect(r.filteredAndSorted.map((e) => e.id), [1, 3]);
    });
  });
}
