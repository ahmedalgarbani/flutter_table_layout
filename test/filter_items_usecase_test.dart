import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_table_layout/src/domain/models/column_definition.dart';
import 'package:flutter_table_layout/src/domain/models/table_state_model.dart';
import 'package:flutter_table_layout/src/domain/usecases/filter_items_usecase.dart';

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
    final useCase = const FilterItemsUseCase();

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

    test('should filter items by date range', () {
      final state = TableStateModel(
        startDate: DateTime(2026, 5, 12),
        endDate: DateTime(2026, 5, 18),
      );

      final (filtered, _, total) = useCase.run<TestItem>(
        items: testItems,
        columns: columns,
        state: state,
        dateProvider: (item) => item.date,
        valueProviders: valueProviders,
      );

      expect(total, 1);
      expect(filtered.first.name, 'Item Beta');
    });

    test('should sort items ascending and descending', () {
      // Ascending sort by amount
      const stateAsc = TableStateModel(
        sortByColumnId: 'amount',
        sortAscending: true,
      );

      final (filteredAsc, _, _) = useCase.run<TestItem>(
        items: testItems,
        columns: columns,
        state: stateAsc,
        valueProviders: valueProviders,
      );

      expect(filteredAsc[0].id, 2); // 50.0
      expect(filteredAsc[1].id, 1); // 150.0
      expect(filteredAsc[2].id, 3); // 300.0

      // Descending sort by amount
      const stateDesc = TableStateModel(
        sortByColumnId: 'amount',
        sortAscending: false,
      );

      final (filteredDesc, _, _) = useCase.run<TestItem>(
        items: testItems,
        columns: columns,
        state: stateDesc,
        valueProviders: valueProviders,
      );

      expect(filteredDesc[0].id, 3); // 300.0
      expect(filteredDesc[1].id, 1); // 150.0
      expect(filteredDesc[2].id, 2); // 50.0
    });

    test('should search globally matching text queries', () {
      const state = TableStateModel(searchQuery: 'beta');

      final (filtered, _, total) = useCase.run<TestItem>(
        items: testItems,
        columns: columns,
        state: state,
        valueProviders: valueProviders,
      );

      expect(total, 1);
      expect(filtered.first.name, 'Item Beta');
    });
  });
}
