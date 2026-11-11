import 'package:flutter/material.dart';

import '../../../core/theme.dart';
import '../../../data/exporters/export_utils.dart';
import '../../../domain/models/column_definition.dart';
import '../../../domain/utils/table_text_normalizer.dart';
import '../adaptive_table_layout.dart';

/// Shared cell helpers of the desktop grid and the mobile cards.
class CellRenderer<T> {
  final Map<String, dynamic Function(T)> valueProviders;
  final AdaptiveTableTheme theme;
  final Color? Function(T item)? rowColorBuilder;

  /// Search text whose matches are highlighted in text cells (empty = none).
  final String highlightQuery;

  /// How [highlightQuery] is matched (the table's `textNormalizer`).
  final TextNormalizer textNormalizer;

  const CellRenderer({
    required this.valueProviders,
    required this.theme,
    this.rowColorBuilder,
    this.highlightQuery = '',
    this.textNormalizer = TableTextNormalizer.normalize,
  });

  /// [text] with the matches of [highlightQuery] marked, or `null` when
  /// there is nothing to highlight.
  TextSpan? highlighted(String text) {
    if (highlightQuery.trim().isEmpty) return null;
    final ranges = TableTextNormalizer.matchRanges(
      text,
      highlightQuery,
      normalize: textNormalizer,
    );
    if (ranges.isEmpty) return null;
    final mark = TextStyle(
      backgroundColor: theme.effectiveSearchHighlightColor,
      fontWeight: FontWeight.w600,
    );
    final spans = <TextSpan>[];
    var at = 0;
    for (final r in ranges) {
      if (r.start > at) spans.add(TextSpan(text: text.substring(at, r.start)));
      spans.add(TextSpan(text: text.substring(r.start, r.end), style: mark));
      at = r.end;
    }
    if (at < text.length) spans.add(TextSpan(text: text.substring(at)));
    return TextSpan(children: spans);
  }

  /// A text widget for [text], with the search matches highlighted when the
  /// column is searchable.
  Widget textWidget(
    String text, {
    required TextStyle style,
    required int maxLines,
    TextAlign? textAlign,
    bool highlight = true,
  }) {
    final span = highlight ? highlighted(text) : null;
    if (span == null) {
      return Text(
        text,
        style: style,
        overflow: TextOverflow.ellipsis,
        maxLines: maxLines,
        textAlign: textAlign,
      );
    }
    return Text.rich(
      span,
      style: style,
      overflow: TextOverflow.ellipsis,
      maxLines: maxLines,
      textAlign: textAlign,
    );
  }

  Object? rawValue(AdaptiveTableColumn<T> col, T item) =>
      valueProviders[col.id]?.call(item) as Object?;

  String textFor(AdaptiveTableColumn<T> col, T item) =>
      (col.valueFormatter ?? ExportUtils.formatValue)(rawValue(col, item));

  Widget cellFor(BuildContext context, AdaptiveTableColumn<T> col, T item) {
    if (col.cellBuilder != null) return col.cellBuilder!(context, item);
    return textWidget(
      textFor(col, item),
      style: theme.rowTextStyle,
      maxLines: 2,
      textAlign: textAlign(col.alignment),
      highlight: col.isSearchable,
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
