import 'package:example/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Opens every tab of the showcase at phone, tablet and desktop sizes, in
/// English and Arabic, and checks that nothing throws or overflows.
void main() {
  const sizes = {
    'phone': Size(375, 812),
    'tablet': Size(820, 1180),
    'desktop': Size(1440, 900),
  };
  for (final entry in sizes.entries) {
    for (final locale in const [Locale('en', 'US'), Locale('ar', 'YE')]) {
      testWidgets('${entry.key} ${locale.languageCode}: all tabs render', (
        tester,
      ) async {
        tester.view.physicalSize = entry.value;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(ShowcaseApp(initialLocale: locale));
        await tester.pumpAndSettle();

        for (var tab = 0; tab < 4; tab++) {
          final tabs = find.byType(Tab);
          await tester.tap(tabs.at(tab));
          await tester.pumpAndSettle();
          // Server tab: wait for the fake API.
          await tester.pump(const Duration(milliseconds: 600));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull, reason: 'tab $tab');
        }
      });
    }
  }
}
