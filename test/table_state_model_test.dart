import 'package:flutter_table_layout/flutter_table_layout.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TableStateModel', () {
    test('copyWith keeps values when nothing is passed', () {
      final s = TableStateModel(
        searchQuery: 'a',
        sortByColumnId: 'x',
        startDate: DateTime(2026),
        endDate: DateTime(2027),
      );
      final c = s.copyWith();
      expect(c, equals(s));
      expect(c.hashCode, equals(s.hashCode));
    });

    test('clear flags reset nullable fields', () {
      final s = TableStateModel(
        sortByColumnId: 'x',
        startDate: DateTime(2026),
        endDate: DateTime(2027),
      );
      final c = s.copyWith(
        clearSort: true,
        clearStartDate: true,
        clearEndDate: true,
      );
      expect(c.sortByColumnId, isNull);
      expect(c.startDate, isNull);
      expect(c.endDate, isNull);
    });

    test('hasActiveFilters and isPaginated', () {
      expect(const TableStateModel().hasActiveFilters, isFalse);
      expect(
        const TableStateModel(searchQuery: ' x ').hasActiveFilters,
        isTrue,
      );
      expect(
        const TableStateModel(customFilters: {'a': 1}).hasActiveFilters,
        isTrue,
      );
      expect(const TableStateModel(pageSize: 0).isPaginated, isFalse);
    });

    test('customFilters from copyWith are unmodifiable copies', () {
      final source = <String, dynamic>{'a': 1};
      final s = const TableStateModel().copyWith(customFilters: source);
      source['b'] = 2;
      expect(s.customFilters.length, 1);
      expect(() => s.customFilters['c'] = 3, throwsUnsupportedError);
    });
  });
}
