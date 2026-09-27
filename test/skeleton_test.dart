import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_table_layout/flutter_table_layout.dart';
import 'package:flutter_test/flutter_test.dart';

class Row3 {
  final int id;
  const Row3(this.id);
}

final _columns = [
  AdaptiveTableColumn<Row3>(id: 'id', title: 'ID', width: 80),
  AdaptiveTableColumn<Row3>(id: 'name', title: 'Name', flex: 2),
  AdaptiveTableColumn<Row3>(id: 'qty', title: 'Qty'),
];
final _providers = <String, dynamic Function(Row3)>{
  'id': (r) => r.id,
  'name': (r) => 'Item ${r.id}',
  'qty': (r) => r.id * 2,
};

AdaptiveTableLayout<Row3> _table({
  List<Row3> items = const [],
  bool isLoading = true,
  TableLoadingStyle style = TableLoadingStyle.skeleton,
  Widget? loadingWidget,
  bool showColumnFilters = false,
  int? skeletonRowCount,
  double? bodyHeight,
  AdaptiveTableDataSource<Row3>? dataSource,
}) => AdaptiveTableLayout<Row3>(
  items: items,
  columns: _columns,
  valueProviders: _providers,
  isLoading: isLoading,
  loadingStyle: style,
  loadingWidget: loadingWidget,
  showColumnFilters: showColumnFilters,
  skeletonRowCount: skeletonRowCount,
  bodyHeight: bodyHeight,
  dataSource: dataSource,
);

Future<void> _pump(
  WidgetTester tester,
  Widget table, {
  Size size = const Size(1200, 1400),
  TextDirection direction = TextDirection.ltr,
  bool disableAnimations = false,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(disableAnimations: disableAnimations),
          child: Directionality(
            textDirection: direction,
            child: Scaffold(body: SingleChildScrollView(child: table)),
          ),
        ),
      ),
    ),
  );
  // The shimmer repeats forever, so pumpAndSettle would time out.
  await tester.pump(const Duration(milliseconds: 300));
}

TableSkeleton _skeleton(WidgetTester tester) =>
    tester.widget<TableSkeleton>(find.byType(TableSkeleton));

void main() {
  testWidgets('desktop: skeleton rows with shimmer instead of a spinner', (
    tester,
  ) async {
    await _pump(tester, _table());
    expect(tester.takeException(), isNull);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.byType(TableSkeleton), findsOneWidget);
    expect(find.byType(TableShimmer), findsWidgets);
    final s = _skeleton(tester);
    expect(s.compact, isFalse);
    expect(s.showHeader, isTrue);
    expect(s.columns!.map((c) => c.id), ['id', 'name', 'qty']);
    // No dimmed overlay / progress bar on top of the skeleton.
    expect(find.byType(LinearProgressIndicator), findsNothing);
  });

  testWidgets('phone: skeleton cards', (tester) async {
    await _pump(
      tester,
      _table(skeletonRowCount: 6),
      size: const Size(390, 800),
    );
    expect(tester.takeException(), isNull);
    final s = _skeleton(tester);
    expect(s.compact, isTrue);
    expect(s.rowCount, 3);
  });

  testWidgets('many fixed-width columns on a narrow grid do not overflow', (
    tester,
  ) async {
    await _pump(
      tester,
      Builder(
        builder: (_) => AdaptiveTableLayout<Row3>(
          items: const [],
          isLoading: true,
          loadingStyle: TableLoadingStyle.skeleton,
          columns: [
            for (var i = 0; i < 12; i++)
              AdaptiveTableColumn<Row3>(id: 'c$i', title: 'C$i', width: 160),
          ],
          valueProviders: {for (var i = 0; i < 12; i++) 'c$i': (r) => r.id},
        ),
      ),
      size: const Size(700, 1000),
    );
    expect(tester.takeException(), isNull);
    expect(find.byType(TableSkeleton), findsOneWidget);
  });

  testWidgets('RTL renders without errors', (tester) async {
    await _pump(tester, _table(), direction: TextDirection.rtl);
    expect(tester.takeException(), isNull);
    expect(find.byType(TableSkeleton), findsOneWidget);
  });

  testWidgets('with column filters the real header stays, rows are skeleton', (
    tester,
  ) async {
    await _pump(tester, _table(showColumnFilters: true));
    expect(tester.takeException(), isNull);
    expect(find.text('Name'), findsWidgets);
    expect(_skeleton(tester).showHeader, isFalse);
  });

  testWidgets('loadingWidget takes precedence', (tester) async {
    await _pump(tester, _table(loadingWidget: const Text('Loading…')));
    expect(find.text('Loading…'), findsOneWidget);
    expect(find.byType(TableSkeleton), findsNothing);
  });

  testWidgets('spinner style is unchanged', (tester) async {
    await _pump(tester, _table(style: TableLoadingStyle.spinner));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byType(TableSkeleton), findsNothing);
  });

  testWidgets('refreshing existing rows keeps them with a progress bar', (
    tester,
  ) async {
    await _pump(tester, _table(items: const [Row3(1), Row3(2)]));
    expect(find.byType(TableSkeleton), findsNothing);
    expect(find.text('Item 1'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
  });

  testWidgets('short fixed body height clips instead of overflowing', (
    tester,
  ) async {
    await _pump(tester, _table(bodyHeight: 120, skeletonRowCount: 10));
    expect(tester.takeException(), isNull);
    expect(find.byType(TableSkeleton), findsOneWidget);
  });

  testWidgets('server-side data source: skeleton until the page arrives', (
    tester,
  ) async {
    final page = Completer<TableDataPage<Row3>>();
    await _pump(
      tester,
      _table(
        isLoading: false,
        dataSource: AdaptiveTableDataSource.fromCallback((_) => page.future),
      ),
    );
    expect(find.byType(TableSkeleton), findsOneWidget);
    page.complete(const TableDataPage(items: [Row3(7)], totalCount: 1));
    await tester.pumpAndSettle();
    expect(find.byType(TableSkeleton), findsNothing);
    expect(find.text('Item 7'), findsOneWidget);
  });

  testWidgets('reduced motion: static placeholders, no running animation', (
    tester,
  ) async {
    await _pump(tester, _table(), disableAnimations: true);
    expect(find.byType(TableSkeleton), findsOneWidget);
    // Would time out if the shimmer were still animating.
    await tester.pumpAndSettle();
    expect(find.byType(ShaderMask), findsNothing);
  });

  testWidgets('shimmer can be used standalone', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: TableShimmer(
          baseColor: Colors.grey,
          highlightColor: Colors.white,
          child: SkeletonBox(width: 100),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 700));
    expect(find.byType(ShaderMask), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('theme skeleton colors: defaults, copyWith, lerp', () {
    const theme = AdaptiveTableTheme(
      cardBackgroundColor: Colors.white,
      borderRadius: BorderRadius.zero,
      headerBackgroundColor: Colors.white,
      headerTextStyle: TextStyle(),
      rowBackgroundColor: Colors.white,
      alternateRowBackgroundColor: Colors.white,
      rowTextStyle: TextStyle(color: Colors.black),
      rowHoverColor: Colors.white,
      dividerColor: Colors.black12,
      footerBackgroundColor: Colors.white,
      footerTextStyle: TextStyle(),
    );
    expect(
      theme.effectiveSkeletonBaseColor,
      Colors.black.withValues(alpha: 0.12),
    );
    final custom = theme.copyWith(
      skeletonBaseColor: Colors.red,
      skeletonHighlightColor: Colors.blue,
    );
    expect(custom.effectiveSkeletonBaseColor, Colors.red);
    expect(custom.effectiveSkeletonHighlightColor, Colors.blue);
    final mid = custom.lerp(
      theme.copyWith(
        skeletonBaseColor: Colors.green,
        skeletonHighlightColor: Colors.blue,
      ),
      0.5,
    );
    expect(mid.skeletonBaseColor, Color.lerp(Colors.red, Colors.green, 0.5));
  });
}
