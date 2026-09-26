import 'package:flutter_table_layout/flutter_table_layout.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('verify package exports compile', () {
    const col = ColumnDefinition(id: 'test', title: 'Test', fieldName: 'test');
    expect(col.id, 'test');
    expect(col.title, 'Test');
  });
}
