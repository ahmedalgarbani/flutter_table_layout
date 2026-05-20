import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_table_layout/flutter_table_layout.dart';

void main() {
  test('verify package exports compile', () {
    const col = ColumnDefinition(id: 'test', title: 'Test', fieldName: 'test');
    expect(col.id, 'test');
    expect(col.title, 'Test');
  });
}
