import 'package:flutter/material.dart';

import '../../../core/theme.dart';
import '../../../data/exporters/export_utils.dart';
import '../../../domain/models/column_definition.dart';
import '../adaptive_table_layout.dart';

/// Shared cell helpers of the desktop grid and the mobile cards.
class CellRenderer<T> {
  final Map<String, dynamic Function(T)> valueProviders;
  final AdaptiveTableTheme theme;
  final Color? Function(T item)? rowColorBuilder;

  const CellRenderer({
    required this.valueProviders,
    required this.theme,
    this.rowColorBuilder,
  });

  Object? rawValue(AdaptiveTableColumn<T> col, T item) =>
      valueProviders[col.id]?.call(item) as Object?;

  String textFor(AdaptiveTableColumn<T> col, T item) =>
      (col.valueFormatter ?? ExportUtils.formatValue)(rawValue(col, item));

  Widget cellFor(BuildContext context, AdaptiveTableColumn<T> col, T item) {
    if (col.cellBuilder != null) return col.cellBuilder!(context, item);
    return Text(
      textFor(col, item),
      style: theme.rowTextStyle,
      overflow: TextOverflow.ellipsis,
      maxLines: 2,
      textAlign: textAlign(col.alignment),
    );
  }

  Color rowColor(T item, {required bool selected, required bool alternate}) {
    if (selected) {
      return Color.alphaBlend(
        theme.effectiveSelectedRowColor,
        theme.rowBackgroundColor,
      );
    }
    final custom = rowColorBuilder?.call(item);
    if (custom != null) return custom;
    return alternate
        ? theme.alternateRowBackgroundColor
        : theme.rowBackgroundColor;
  }

  /// An opaque version of [color], used behind frozen cells.
  Color opaque(Color color) {
    final base = theme.cardBackgroundColor.withValues(alpha: 1);
    return Color.alphaBlend(color, base);
  }

  static MainAxisAlignment mainAxisAlignment(TableColumnAlignment a) =>
      switch (a) {
        TableColumnAlignment.start => MainAxisAlignment.start,
        TableColumnAlignment.center => MainAxisAlignment.center,
        TableColumnAlignment.end => MainAxisAlignment.end,
      };

  static AlignmentDirectional alignment(TableColumnAlignment a) => switch (a) {
    TableColumnAlignment.start => AlignmentDirectional.centerStart,
    TableColumnAlignment.center => AlignmentDirectional.center,
    TableColumnAlignment.end => AlignmentDirectional.centerEnd,
  };

  static TextAlign textAlign(TableColumnAlignment a) => switch (a) {
    TableColumnAlignment.start => TextAlign.start,
    TableColumnAlignment.center => TextAlign.center,
    TableColumnAlignment.end => TextAlign.end,
  };
}
