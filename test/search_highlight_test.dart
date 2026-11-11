import 'package:flutter/material.dart';
import 'package:flutter_table_layout/flutter_table_layout.dart';
import 'package:flutter_test/flutter_test.dart';

List<String> marked(String text, String query, {TextNormalizer? normalize}) => [
  for (final r in TableTextNormalizer.matchRanges(
    text,
    query,
    normalize: normalize ?? TableTextNormalizer.normalize,
  ))
    text.substring(r.start, r.end),
];

void main() {
  group('TableTextNormalizer.matchRanges', () {
    test('case-insensitive, every occurrence', () {
      expect(marked('Banana BANANA', 'an'), ['anan', 'ANAN']);
      expect(marked('Hello', 'xyz'), isEmpty);
      expect(marked('Hello', '  '), isEmpty);
      expect(marked('', 'a'), isEmpty);
    });

    test('maps Arabic variants back to the original text', () {
      expect(marked('أحمد علي', 'احمد'), ['أحمد']);
      expect(marked('مدرسة النور', 'مدرسه'), ['مدرسة']);
      // Diacritics inside and after the match are part of it.
      expect(marked('مُحَمَّدٌ صالح', 'محمد'), ['مُحَمَّدٌ']);
      expect(marked('كتـــاب', 'كتاب'), ['كتـــاب']);
      expect(marked('الرقم ١٥٠٠ ريال', '1500'), ['١٥٠٠']);
      expect(marked('1500', '١٥'), ['15']);
    });

    test('adjacent matches are merged', () {
      expect(marked('aaaa', 'aa'), ['aaaa']);
    });

    test('a normalizer that is not per character gives no ranges', () {
      String reversed(String s) => s.split('').reversed.join();
      expect(marked('abc', 'cb', normalize: reversed), isEmpty);
    });
  });

  Future<void> pumpTable(
    WidgetTester tester, {
    bool highlight = true,
    Size size = const Size(1200, 800),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: AdaptiveTableLayout<String>(
              items: const ['أحمد علي', 'سارة محمد', 'Ahmad'],
              searchDebounce: Duration.zero,
              highlightSearchMatches: highlight,
              columns: [
                AdaptiveTableColumn(id: 'name', title: 'Name'),
                AdaptiveTableColumn(
                  id: 'code',
                  title: 'Code',
                  isSearchable: false,
                ),
              ],
              valueProviders: {'name': (s) => s, 'code': (s) => 'احمد-x'},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  List<String> highlightedParts(WidgetTester tester, String plain) {
    final text = tester.widget<Text>(find.text(plain).first);
    final parts = <String>[];
    text.textSpan?.visitChildren((span) {
      if (span is TextSpan &&
          span.style?.backgroundColor != null &&
          span.text != null) {
        parts.add(span.text!);
      }
      return true;
    });
    return parts;
  }

  testWidgets('grid cells highlight the search text', (tester) async {
    await pumpTable(tester);
    expect(highlightedParts(tester, 'أحمد علي'), isEmpty);
    await tester.enterText(find.byType(TextField).first, 'احمد');
    await tester.pumpAndSettle();
    expect(highlightedParts(tester, 'أحمد علي'), ['أحمد']);
    // Not searched, so not highlighted.
    expect(highlightedParts(tester, 'احمد-x'), isEmpty);
    expect(find.text('سارة محمد'), findsNothing);
  });

  testWidgets('cards highlight too, and the option turns it off', (
    tester,
  ) async {
    await pumpTable(tester, size: const Size(390, 800));
    await tester.enterText(find.byType(TextField).first, 'ahm');
    await tester.pumpAndSettle();
    expect(highlightedParts(tester, 'Ahmad'), ['Ahm']);

    await pumpTable(tester, highlight: false);
    await tester.enterText(find.byType(TextField).first, 'ahm');
    await tester.pumpAndSettle();
    expect(highlightedParts(tester, 'Ahmad'), isEmpty);
  });
}
