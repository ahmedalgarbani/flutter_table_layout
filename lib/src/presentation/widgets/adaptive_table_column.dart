import 'package:flutter/widgets.dart';

import '../../data/exporters/export_utils.dart';
import '../../domain/models/column_definition.dart';
import '../../domain/models/table_aggregate.dart';
import 'grid/cell_editor.dart';

/// Alignment helper maps.
typedef AdaptiveTableColumnAlignment = TableColumnAlignment;

/// Converts a raw cell value into the text shown in the table and written to
/// PDF / Word exports.
typedef CellValueFormatter = String Function(dynamic value);

/// Column configuration combining structural definitions and Flutter widget builders.
class AdaptiveTableColumn<T> {
  final ColumnDefinition definition;

  /// Custom cell widget. When `null`, the column's `valueProvider` value is
  /// shown as text (formatted by [valueFormatter]).
  final Widget Function(BuildContext context, T item)? cellBuilder;

  /// Custom header widget replacing the [title] text.
  final Widget Function(BuildContext context)? headerBuilder;

  /// Formats the raw value for the default text cell, mobile cards, and
  /// PDF / Word exports (Excel keeps the raw typed value). The search and the
  /// column filters also match this text.
  final CellValueFormatter? valueFormatter;

  /// Inline editor of this column (when `isEditable`). Inferred from the
  /// value type when `null`.
  final CellEditor? editor;

  /// Validates an inline edit before `onCellEdited` is called. Return an
  /// error message to keep the editor open.
  final String? Function(dynamic value)? cellValidator;

  /// Footer total of this column (sum, average…). Columns with a total get
  /// a totals row under the grid (at the end of the cards on phones), and
  /// the total is written to exports.
  final TableAggregate? aggregate;

  /// Custom footer total computed from the filtered rows (e.g. a balance).
  /// Wins over [aggregate].
  final Object? Function(List<T> rows)? aggregator;

  /// Formats the footer total. Defaults to [valueFormatter], except for
  /// [TableAggregate.count].
  final CellValueFormatter? aggregateFormatter;

  /// Custom sort order of this column's (non-null) values, e.g.
  /// `FilterItemsUseCase.naturalCompare` so `INV-9` comes before `INV-10`,
  /// or your own ranking (`low < medium < high`). `null` values always sort
  /// last. Pass a top-level or static function (not a new closure on every
  /// build), otherwise sorted tables re-sort on each rebuild.
  final int Function(dynamic a, dynamic b)? comparator;

  AdaptiveTableColumn({
    required String id,
    required String title,
    String? fieldName,
    bool isSortable = true,
    bool isVisible = true,
    bool isSearchable = true,
    bool isExportable = true,
    bool isHideable = true,
    bool isFilterable = true,
    bool isResizable = true,
    bool isEditable = false,
    bool isGroupable = true,
    ColumnPin pin = ColumnPin.none,
    double? width,
    double minWidth = 60,
    int flex = 1,
    AdaptiveTableColumnAlignment alignment = AdaptiveTableColumnAlignment.start,
    this.cellBuilder,
    this.headerBuilder,
    this.valueFormatter,
    this.editor,
    this.cellValidator,
    this.aggregate,
    this.aggregator,
    this.aggregateFormatter,
    this.comparator,
  }) : definition = ColumnDefinition(
         id: id,
         title: title,
         fieldName: fieldName,
         isSortable: isSortable,
         isVisible: isVisible,
         isSearchable: isSearchable,
         isExportable: isExportable,
         isHideable: isHideable,
         isFilterable: isFilterable,
         isResizable: isResizable,
         isEditable: isEditable,
         isGroupable: isGroupable,
         pin: pin,
         width: width,
         minWidth: minWidth,
         flex: flex,
         alignment: alignment,
       );

  String get id => definition.id;
  String get title => definition.title;
  String get fieldName => definition.fieldName;
  bool get isSortable => definition.isSortable;
  bool get isVisible => definition.isVisible;
  bool get isSearchable => definition.isSearchable;
  bool get isExportable => definition.isExportable;
  bool get isHideable => definition.isHideable;
  bool get isFilterable => definition.isFilterable;
  bool get isResizable => definition.isResizable;
  bool get isEditable => definition.isEditable;
  bool get isGroupable => definition.isGroupable;
  ColumnPin get pin => definition.pin;
  double get minWidth => definition.minWidth;
  double? get width => definition.width;
  int get flex => definition.flex;
  AdaptiveTableColumnAlignment get alignment => definition.alignment;

  /// Whether the column shows a footer total.
  bool get hasAggregate => aggregate != null || aggregator != null;

  /// The text of [value] (this column's total) in the totals row and exports.
  String aggregateText(Object? value) {
    if (value == null) return '';
    final custom = aggregateFormatter;
    if (custom != null) return custom(value);
    final formatter = valueFormatter;
    if (formatter != null && aggregate != TableAggregate.count) {
      try {
        return formatter(value);
      } catch (_) {
        // e.g. a formatter casting to int, given an average.
      }
    }
    if (value is double && value != value.roundToDouble()) {
      final fixed = value.toStringAsFixed(2);
      return fixed.endsWith('0') ? fixed.substring(0, fixed.length - 1) : fixed;
    }
    return ExportUtils.formatValue(value);
  }
}
