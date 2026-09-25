/// Horizontal alignment of a column's header and cells.
///
/// `start` and `end` are direction-aware: in a right-to-left locale `start`
/// aligns to the right edge.
enum TableColumnAlignment { start, center, end }

/// A pure Dart representation of a table column schema.
/// Holds structure, sorting parameters, and visibility without UI bindings.
class ColumnDefinition {
  /// Unique identifier of the column. Also the key used in `valueProviders`.
  final String id;

  /// Header text.
  final String title;

  /// Key in the map, or name of the field to map values.
  final String fieldName;

  /// Whether user can sort this column.
  final bool isSortable;

  /// Initial visibility of this column. Users can still toggle it from the
  /// columns menu.
  final bool isVisible;

  /// Whether the global search looks into this column's values.
  final bool isSearchable;

  /// Whether this column is included in Excel / Word / PDF exports and prints.
  /// Set it to `false` for action columns (edit / delete buttons…).
  final bool isExportable;

  /// Whether the user may hide this column from the columns menu.
  final bool isHideable;

  /// Fixed width of this column. If provided, overrides flex sizing.
  final double? width;

  /// Flex coefficient for layout when [width] is not specified.
  final int flex;

  /// Text alignment (start, center, end).
  final TableColumnAlignment alignment;

  const ColumnDefinition({
    required this.id,
    required this.title,
    String? fieldName,
    this.isSortable = true,
    this.isVisible = true,
    this.isSearchable = true,
    this.isExportable = true,
    this.isHideable = true,
    this.width,
    this.flex = 1,
    this.alignment = TableColumnAlignment.start,
  }) : fieldName = fieldName ?? id,
       assert(flex > 0, 'flex must be greater than zero');

  /// Helper to copy column definition with modified properties.
  ///
  /// Pass `clearWidth: true` to remove a fixed [width] and fall back to [flex].
  ColumnDefinition copyWith({
    String? id,
    String? title,
    String? fieldName,
    bool? isSortable,
    bool? isVisible,
    bool? isSearchable,
    bool? isExportable,
    bool? isHideable,
    double? width,
    bool clearWidth = false,
    int? flex,
    TableColumnAlignment? alignment,
  }) {
    return ColumnDefinition(
      id: id ?? this.id,
      title: title ?? this.title,
      fieldName: fieldName ?? this.fieldName,
      isSortable: isSortable ?? this.isSortable,
      isVisible: isVisible ?? this.isVisible,
      isSearchable: isSearchable ?? this.isSearchable,
      isExportable: isExportable ?? this.isExportable,
      isHideable: isHideable ?? this.isHideable,
      width: clearWidth ? null : (width ?? this.width),
      flex: flex ?? this.flex,
      alignment: alignment ?? this.alignment,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ColumnDefinition &&
          other.id == id &&
          other.title == title &&
          other.fieldName == fieldName &&
          other.isSortable == isSortable &&
          other.isVisible == isVisible &&
          other.isSearchable == isSearchable &&
          other.isExportable == isExportable &&
          other.isHideable == isHideable &&
          other.width == width &&
          other.flex == flex &&
          other.alignment == alignment;

  @override
  int get hashCode => Object.hash(
    id,
    title,
    fieldName,
    isSortable,
    isVisible,
    isSearchable,
    isExportable,
    isHideable,
    width,
    flex,
    alignment,
  );

  @override
  String toString() => 'ColumnDefinition(id: $id, title: $title)';
}
