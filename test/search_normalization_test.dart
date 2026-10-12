import 'package:flutter_table_layout/flutter_table_layout.dart';
import 'package:flutter_test/flutter_test.dart';

class Customer {
  final int id;
  final String name;
  final double balance;
  final DateTime since;
  const Customer(this.id, this.name, this.balance, this.since);
}

final _customers = [
  Customer(1, 'أحمد علي', 1500, DateTime(2026, 1, 5)),
  Customer(2, 'مدرسة النور', 250.5, DateTime(2026, 2, 7)),
  Customer(3, 'مُحَمَّد', -40, DateTime(2026, 3, 9)),
  Customer(4, 'Zainab', 12000, DateTime(2026, 4, 11)),
];

const _columns = [
  ColumnDefinition(id: 'id', title: 'ID'),
  ColumnDefinition(id: 'name', title: 'Name'),
  ColumnDefinition(id: 'balance', title: 'Balance'),
  ColumnDefinition(id: 'since', title: 'Since'),
];

final _providers = <String, dynamic Function(Customer)>{
  'id': (c) => c.id,
  'name': (c) => c.name,
  'balance': (c) => c.balance,
  'since': (c) => c.since,
};

String _money(dynamic v) {
  final n = (v as num).toStringAsFixed(2);
  final parts = n.split('.');
  final whole = parts[0].replaceAllMapped(
    RegExp(r'(\d)(?=(\d{3})+$)'),
    (m) => '${m[1]},',
  );
  return '$whole.${parts[1]}';
}

String _day(dynamic v) {
  final d = v as DateTime;
  return '${d.day.toString().padLeft(2, '0')}/'
      '${d.month.toString().padLeft(2, '0')}/${d.year}';
}

List<int> _search(
  String query, {
  FilterItemsUseCase useCase = const FilterItemsUseCase(),
  Map<String, DisplayFormatter>? formatters,
}) {
  return useCase
      .apply<Customer>(
        items: _customers,
        columns: _columns,
        state: TableStateModel(searchQuery: query, pageSize: 0),
        valueProviders: _providers,
        displayFormatters: formatters,
      )
      .filteredAndSorted
      .map((c) => c.id)
      .toList();
}

void main() {
  group('TableTextNormalizer', () {
    test('folds Arabic spelling variants, diacritics, tatweel and digits', () {
      const n = TableTextNormalizer.normalize;
      expect(n('أحمد'), n('احمد'));
      expect(n('إيمان'), n('ايمان'));
      expect(n('آمال'), n('امال'));
      expect(n('مدرسة'), n('مدرسه'));
      expect(n('مصطفى'), n('مصطفي'));
      expect(n('مُحَمَّد'), 'محمد');
      expect(n('كتـــاب'), 'كتاب');
      expect(n('مسؤول'), n('مسوول'));
      expect(n('١٢٣٤'), '1234');
      expect(n('۱۲۳'), '123');
      expect(n('١٬٥٠٠٫٥'), '1,500.5');
      expect(n('Hello World'), 'hello world');
    });

    test('caseInsensitive and digitsToAscii', () {
      expect(TableTextNormalizer.caseInsensitive('أحمد ABC'), 'أحمد abc');
      expect(TableTextNormalizer.digitsToAscii('>= ١٠٠'), '>= 100');
      expect(TableTextNormalizer.digitsToAscii('plain'), 'plain');
    });
  });

  group('Global search', () {
    test('matches Arabic text regardless of hamza / ta marbuta / tashkeel', () {
      expect(_search('احمد'), [1]);
      expect(_search('مدرسه'), [2]);
      expect(_search('محمد'), [3]);
      expect(_search('ZAINAB'), [4]);
    });

    test('Arabic-Indic digits find ASCII numbers', () {
      expect(_search('١٢٠٠٠'), [4]);
    });

    test('also matches the displayed (formatted) text', () {
      // Raw 1500.0 is "1500.0"; the cell shows "1,500.00".
      expect(_search('1,500.00'), isEmpty);
      expect(_search('1,500.00', formatters: {'balance': _money}), [1]);
      expect(_search('07/02/2026', formatters: {'since': _day}), [2]);
    });

    test('a throwing formatter never breaks the search', () {
      expect(
        _search('x', formatters: {'balance': (v) => throw StateError('bad')}),
        isEmpty,
      );
    });

    test('a custom normalizer can turn the folding off', () {
      const plain = FilterItemsUseCase(
        textNormalizer: TableTextNormalizer.caseInsensitive,
      );
      expect(_search('احمد', useCase: plain), isEmpty);
      expect(_search('أحمد', useCase: plain), [1]);
    });

    test('text sorting uses the normalized form', () {
      final r = const FilterItemsUseCase().apply<String>(
        items: const ['إياد', 'باسل', 'ابراهيم', 'أحمد'],
        columns: const [ColumnDefinition(id: 'n', title: 'N')],
        state: const TableStateModel(sortByColumnId: 'n', pageSize: 0),
        valueProviders: {'n': (s) => s},
      );
      // Alef variants sort together, before ب.
      expect(r.filteredAndSorted.last, 'باسل');
    });
  });

  group('ColumnFilterMatcher', () {
    test('thousands separators are part of numbers', () {
      expect(ColumnFilterMatcher.matches(1500, '>=1,500'), isTrue);
      expect(ColumnFilterMatcher.matches(1499, '>=1,500'), isFalse);
      expect(ColumnFilterMatcher.matches(1200000, '>1,000,000'), isTrue);
      expect(ColumnFilterMatcher.matches(1500, '1,000..2,000'), isTrue);
    });

    test('commas, | and the Arabic comma still separate alternatives', () {
      expect(ColumnFilterMatcher.matches('b', 'a,b'), isTrue);
      expect(ColumnFilterMatcher.matches(2, '1, 2'), isTrue);
      // Not split into "1" or "000": the value 1 does not contain "1,000".
      expect(ColumnFilterMatcher.matches(1, '1,000'), isFalse);
      expect(ColumnFilterMatcher.matches(2, '=1, =2'), isTrue);
      expect(ColumnFilterMatcher.matches(2, '=1,=2'), isTrue);
      expect(ColumnFilterMatcher.matches('ب', 'أ، ب'), isTrue);
      expect(ColumnFilterMatcher.matches(5, '>10 | <6'), isTrue);
    });

    test('Arabic-Indic digits and Arabic folding', () {
      expect(ColumnFilterMatcher.matches(150, '>١٠٠'), isTrue);
      expect(ColumnFilterMatcher.matches('أحمد', '=احمد'), isTrue);
      expect(ColumnFilterMatcher.matches('مدرسة', 'مدرسه'), isTrue);
      expect(
        ColumnFilterMatcher.matches(DateTime(2026, 3, 9), '=٢٠٢٦-٠٣-٠٩'),
        isTrue,
      );
    });

    test('contains / equals also look at the displayed text', () {
      expect(
        ColumnFilterMatcher.matches(1500, '1,500', displayText: '1,500.00'),
        isTrue,
      );
      expect(
        ColumnFilterMatcher.matches(
          DateTime(2026, 2, 7),
          '=07/02/2026',
          displayText: '07/02/2026',
        ),
        isTrue,
      );
      expect(
        ColumnFilterMatcher.matches(
          DateTime(2026, 2, 7),
          '!=07/02/2026',
          displayText: '07/02/2026',
        ),
        isFalse,
      );
    });

    test('a parsed matcher can be reused and is lazy about display text', () {
      final m = ColumnFilterMatcher.parse('>=100');
      var formatted = 0;
      String? display() {
        formatted++;
        return '';
      }

      expect(m.test(150, display), isTrue);
      expect(m.test(50, display), isFalse);
      expect(formatted, 0); // numeric comparisons never format
      expect(ColumnFilterMatcher.parse('  ').isEmpty, isTrue);
    });

    test('column filters in the use case use formatters and folding', () {
      final r = const FilterItemsUseCase().apply<Customer>(
        items: _customers,
        columns: _columns,
        state: const TableStateModel(
          columnFilters: {'name': 'احمد', 'balance': '1,500.00'},
          pageSize: 0,
        ),
        valueProviders: _providers,
        displayFormatters: {'balance': _money},
      );
      expect(r.filteredAndSorted.map((c) => c.id), [1]);
    });
  });
}
