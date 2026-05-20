enum TableColumnAlignment { start, center, end }

/// A pure Dart representation of a table column schema.
/// Holds structure, sorting parameters, and visibility without UI bindings.
class ColumnDefinition {
  /// Unique identifier of the column.
  final String id;

  /// Header text.
  final String title;

  /// Key in the map, or name of the field to map values.
  final String fieldName;

  /// Whether user can sort this column.
  final bool isSortable;

  /// Dynamic visibility of this column.
  final bool isVisible;

  /// Fixed width of this column. If provided, overrides flex sizing.
  final double? width;

  /// Flex coefficient for layout when [width] is not specified.
  final int flex;

  /// Text alignment (start, center, end).
  final TableColumnAlignment alignment;

  const ColumnDefinition({
    required this.id,
    required this.title,
    required this.fieldName,
    this.isSortable = true,
    this.isVisible = true,
    this.width,
    this.flex = 1,
    this.alignment = TableColumnAlignment.start,
  });

  /// Helper to copy column definition with modified properties.
  ColumnDefinition copyWith({
    String? id,
    String? title,
    String? fieldName,
    bool? isSortable,
    bool? isVisible,
    double? width,
    int? flex,
    TableColumnAlignment? alignment,
  }) {
    return ColumnDefinition(
      id: id ?? this.id,
      title: title ?? this.title,
      fieldName: fieldName ?? this.fieldName,
      isSortable: isSortable ?? this.isSortable,
      isVisible: isVisible ?? this.isVisible,
      width: width ?? this.width,
      flex: flex ?? this.flex,
      alignment: alignment ?? this.alignment,
    );
  }
}
