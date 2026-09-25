/// Horizontal alignment of a column's header and cells.
///
/// `start` and `end` are direction-aware: in a right-to-left locale `start`
/// aligns to the right edge.
enum TableColumnAlignment { start, center, end }

/// Frozen (pinned) position of a column in the desktop grid.
///
/// Pinned columns stay visible while the other columns scroll horizontally.
/// `start` / `end` are direction-aware (in RTL `start` is the right edge).
enum ColumnPin { none, start, end }

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

  /// Whether the column gets a field in the per-column filter row.
  final bool isFilterable;

  /// Whether the user can resize the column by dragging its header edge.
  final bool isResizable;

  /// Whether cells of this column can be edited inline (desktop grid).
  final bool isEditable;

  /// Initial frozen position.
  final ColumnPin pin;

  /// Fixed width of this column. If provided, overrides flex sizing.
  final double? width;

  /// Smallest width the column can be resized / squeezed to.
  final double minWidth;

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
    this.isFilterable = true,
    this.isResizable = true,
    this.isEditable = false,
    this.pin = ColumnPin.none,
    this.width,
    this.minWidth = 60,
    this.flex = 1,
    this.alignment = TableColumnAlignment.start,
  }) : fieldName = fieldName ?? id,
       assert(flex > 0, 'flex must be greater than zero'),
       assert(minWidth >= 0, 'minWidth must not be negative');

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
    bool? isFilterable,
    bool? isResizable,
    bool? isEditable,
    ColumnPin? pin,
    double? width,
    bool clearWidth = false,
    double? minWidth,
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
      isFilterable: isFilterable ?? this.isFilterable,
      isResizable: isResizable ?? this.isResizable,
      isEditable: isEditable ?? this.isEditable,
      pin: pin ?? this.pin,
      width: clearWidth ? null : (width ?? this.width),
      minWidth: minWidth ?? this.minWidth,
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
          other.isFilterable == isFilterable &&
          other.isResizable == isResizable &&
          other.isEditable == isEditable &&
          other.pin == pin &&
          other.width == width &&
          other.minWidth == minWidth &&
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
    isFilterable,
    isResizable,
    isEditable,
    pin,
    width,
    minWidth,
    flex,
    alignment,
  );

  @override
  String toString() => 'ColumnDefinition(id: $id, title: $title)';
}
