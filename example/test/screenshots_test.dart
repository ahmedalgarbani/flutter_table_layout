// Generates the README screenshots in ../doc/screenshots.
//
// Skipped by default. Run from the example folder with:
//
//   flutter test test/screenshots_test.dart --update-goldens \
//     --dart-define=SCREENSHOTS=true \
//     --dart-define=ARABIC_FONT_DIR=/path/to/folder/with/cairo/ttf
//
// The Arabic font folder must contain cairoRegular.ttf, cairoSemiBold.ttf and
// cairoBold.ttf (the Cairo family from Google Fonts).
import 'dart:io';

import 'package:example/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _enabled = bool.fromEnvironment('SCREENSHOTS');
const _arabicFontDir = String.fromEnvironment('ARABIC_FONT_DIR');

Future<void> _loadFont(String family, List<String> paths) async {
  final loader = FontLoader(family);
  for (final p in paths) {
    final bytes = File(p).readAsBytesSync();
    loader.addFont(Future.value(ByteData.sublistView(bytes)));
  }
  await loader.load();
}

Future<void> _loadFonts() async {
  final flutterRoot =
      Platform.environment['FLUTTER_ROOT'] ??
      File(Platform.resolvedExecutable).parent.parent.parent.parent.parent.path;
  final material = '$flutterRoot/bin/cache/artifacts/material_fonts';
  await _loadFont('Roboto', [
    for (final w in ['Regular', 'Medium', 'Bold']) '$material/Roboto-$w.ttf',
  ]);
  await _loadFont('MaterialIcons', ['$material/MaterialIcons-Regular.otf']);
  if (_arabicFontDir.isNotEmpty) {
    await _loadFont('Cairo', [
      for (final w in ['Regular', 'SemiBold', 'Bold'])
        '$_arabicFontDir/cairo$w.ttf',
    ]);
  }
}

Future<void> _shoot(
  WidgetTester tester,
  String name, {
  required Size size,
  double pixelRatio = 1.5,
  Locale locale = const Locale('en', 'US'),
  ThemeMode themeMode = ThemeMode.light,
  DemoThemeStyle style = DemoThemeStyle.modern,
  int tab = 0,
  Future<void> Function(WidgetTester tester)? interact,
}) async {
  tester.view.physicalSize = size * pixelRatio;
  tester.view.devicePixelRatio = pixelRatio;
  addTearDown(tester.view.reset);
  debugDisableShadows = false;

  await tester.pumpWidget(
    ShowcaseApp(
      key: UniqueKey(),
      initialLocale: locale,
      initialThemeMode: themeMode,
      initialStyle: style,
      initialTab: tab,
      fontFamily: locale.languageCode == 'ar' ? 'Cairo' : 'Roboto',
    ),
  );
  await tester.pumpAndSettle();
  if (interact != null) {
    await interact(tester);
    await tester.pumpAndSettle();
  }
  // Hide the hover/focus effects left by taps.
  await tester.pump(const Duration(seconds: 1));

  await expectLater(
    find.byType(ShowcaseApp),
    matchesGoldenFile('../../doc/screenshots/$name.png'),
  );
  debugDisableShadows = true;
}

Future<void> _selectAndExpand(WidgetTester tester) async {
  final checkboxes = find.byType(Checkbox);
  await tester.tap(checkboxes.at(2));
  await tester.tap(checkboxes.at(4));
  await tester.pumpAndSettle();
  await tester.tap(find.byIcon(Icons.chevron_right).first);
}

void main() {
  setUpAll(() async {
    if (_enabled) await _loadFonts();
  });

  const desktop = Size(1280, 1080);
  const mobile = Size(390, 844);

  testWidgets('desktop light', skip: !_enabled, (t) async {
    await _shoot(t, 'desktop_light', size: desktop, interact: _selectAndExpand);
  });

  testWidgets('desktop dark', skip: !_enabled, (t) async {
    await _shoot(
      t,
      'desktop_dark',
      size: const Size(1280, 700),
      themeMode: ThemeMode.dark,
      tab: 1,
      interact: (t) async {
        await t.tap(find.byTooltip('Columns'));
        await t.pumpAndSettle();
      },
    );
  });

  testWidgets('desktop rtl', skip: !_enabled, (t) async {
    await _shoot(
      t,
      'desktop_rtl',
      size: desktop,
      locale: const Locale('ar', 'YE'),
    );
  });

  testWidgets('mobile rtl', skip: !_enabled, (t) async {
    await _shoot(
      t,
      'mobile_rtl',
      size: mobile,
      pixelRatio: 2,
      locale: const Locale('ar', 'YE'),
      interact: (t) async {
        await t.tap(find.byIcon(Icons.expand_more).first);
      },
    );
  });

  testWidgets('mobile dark', skip: !_enabled, (t) async {
    await _shoot(
      t,
      'mobile_dark',
      size: mobile,
      pixelRatio: 2,
      themeMode: ThemeMode.dark,
      style: DemoThemeStyle.cozy,
      tab: 1,
    );
  });

  for (final style in [
    DemoThemeStyle.glassmorphic,
    DemoThemeStyle.gradient,
    DemoThemeStyle.cozy,
  ]) {
    testWidgets('theme ${style.name}', skip: !_enabled, (t) async {
      await _shoot(
        t,
        'theme_${style.name}',
        size: const Size(1280, 800),
        style: style,
        tab: 1,
      );
    });
  }

  testWidgets('dynamic form', skip: !_enabled, (t) async {
    await _shoot(
      t,
      'dynamic_form',
      size: const Size(1280, 860),
      interact: (t) async {
        await t.tap(find.text('Add New'));
      },
    );
  });

  testWidgets('advanced grid: frozen columns + filters', skip: !_enabled, (
    t,
  ) async {
    await _shoot(
      t,
      'grid_frozen',
      size: const Size(1100, 760),
      tab: 2,
      interact: (t) async {
        // Filter + scroll horizontally: ID / Name stay frozen at the start,
        // Actions at the end.
        await t.enterText(find.byType(TextField).at(5), '>=3000');
        await t.pump(const Duration(milliseconds: 400));
        await t.pumpAndSettle();
        await t.drag(find.text('City').first, const Offset(-260, 0));
      },
    );
  });

  testWidgets('advanced grid: grouping + inline editing', skip: !_enabled, (
    t,
  ) async {
    await _shoot(
      t,
      'grid_grouping_editing',
      size: const Size(1280, 760),
      tab: 2,
      interact: (t) async {
        await t.tap(find.byTooltip('Group by'));
        await t.pumpAndSettle();
        await t.tap(find.text('Department').last);
        await t.pumpAndSettle();
        final salary = find
            .byWidgetPredicate(
              (w) =>
                  w is Text &&
                  RegExp(r'^\d{1,3}(,\d{3})*\.00$').hasMatch(w.data ?? ''),
            )
            .at(1);
        await t.tap(salary);
        await t.pump(const Duration(milliseconds: 50));
        await t.tap(salary);
        await t.pumpAndSettle();
      },
    );
  });

  testWidgets('server data', skip: !_enabled, (t) async {
    await _shoot(
      t,
      'server_data',
      size: const Size(1280, 700),
      tab: 3,
      interact: (t) async {
        await t.pump(const Duration(milliseconds: 600));
        await t.pumpAndSettle();
        await t.tap(find.text('Salary'));
        await t.pump(const Duration(milliseconds: 600));
      },
    );
  });

  testWidgets('mobile grouped rtl', skip: !_enabled, (t) async {
    await _shoot(
      t,
      'mobile_grouped_rtl',
      size: const Size(390, 844),
      pixelRatio: 2,
      locale: const Locale('ar', 'YE'),
      tab: 2,
      interact: (t) async {
        await t.tap(find.byTooltip('تجميع حسب'));
        await t.pumpAndSettle();
        await t.tap(find.text('القسم').last);
      },
    );
  });
}
