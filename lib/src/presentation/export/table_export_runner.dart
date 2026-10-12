import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';

import '../../core/labels.dart';
import '../../core/theme.dart';
import '../../core/utils/file_saver.dart';
import '../../data/exporters/csv_exporter.dart';
import '../../data/exporters/excel_exporter.dart';
import '../../data/exporters/export_utils.dart';
import '../../data/exporters/pdf_exporter.dart';
import '../../data/exporters/table_export_options.dart';
import '../../data/exporters/word_exporter.dart';
import '../../domain/models/column_definition.dart';
import '../cubit/table_cubit_state.dart';
import '../widgets/adaptive_table_column.dart';

/// Replaces the built-in export for a format. Receives the rows the table
/// would export (selected rows if any, otherwise all filtered rows, in the
/// current sort order).
typedef TableExportCallback<T> =
    Future<void> Function(ExportFormat format, List<T> rows);

/// Replaces the built-in print action.
typedef TablePrintCallback<T> = Future<void> Function(List<T> rows);

/// Runs the export, print and copy actions of a table. Shared by the
/// toolbar, the keyboard shortcuts of the grid and `AdaptiveTableController`.
class TableExportRunner<T> {
  final List<AdaptiveTableColumn<T>> columns;
  final Map<String, dynamic Function(T)> valueProviders;
  final Map<String, TableAggregator<T>> aggregators;
  final TableExportOptions options;
  final AdaptiveTableTheme theme;
  final AdaptiveTableLabels labels;
  final String? title;
  final String? subtitle;
  final TableExportCallback<T>? onExportRequested;
  final TablePrintCallback<T>? onPrintRequested;

  /// Server mode: selected rows may live on other pages.
  final bool isRemote;

  const TableExportRunner({
    required this.columns,
    required this.valueProviders,
    required this.options,
    required this.theme,
    required this.labels,
    this.aggregators = const {},
    this.title,
    this.subtitle,
    this.onExportRequested,
    this.onPrintRequested,
    this.isRemote = false,
  });

  String get reportTitle => title ?? labels.defaultReportTitle;

  /// Rows to export: the selected ones (if any and enabled) otherwise every
  /// filtered row, in the current sort order.
  List<T> rowsToExport(TableLoaded<T> state) {
    if (options.exportSelectedWhenAny && state.selectedItems.isNotEmpty) {
      return selectedRows(state);
    }
    return state.filteredAndSortedItems;
  }

  /// The selected rows in the current sort order. In server mode the
  /// selected rows of other pages follow.
  List<T> selectedRows(TableLoaded<T> state) {
    final selected = state.selectedKeys;
    final onPage = state.filteredAndSortedItems
        .where((i) => selected.contains(state.keyOf(i)))
        .toList();
    if (!isRemote || onPage.length == state.selectedItems.length) {
      return onPage;
    }
    final listed = {for (final i in onPage) state.keyOf(i)};
    return [
      ...onPage,
      ...state.selectedItems.where((s) => !listed.contains(state.keyOf(s))),
    ];
  }

  /// Column definitions in the user's display order (drag & drop / pins).
  List<ColumnDefinition> orderedDefinitions(TableLoaded<T> state) {
    final visible = state.arrange(columns, (c) => c.definition);
    return [
      ...visible.map((c) => c.definition),
      // Hidden columns are skipped by the exporters anyway.
      ...columns.where((c) => !visible.contains(c)).map((c) => c.definition),
    ];
  }

  Map<String, ExportValueFormatter> get _formatters => {
    for (final c in columns)
      if (c.valueFormatter != null) c.id: c.valueFormatter!,
  };

  AdaptiveTableColumn<T>? _column(String id) =>
      columns.where((c) => c.id == id).firstOrNull;

  /// Raw totals of [rows] (empty when disabled or an aggregator throws).
  Map<String, Object?> totalsOf(List<T> rows) {
    if (!options.includeTotals || aggregators.isEmpty) return const {};
    try {
      return {for (final e in aggregators.entries) e.key: e.value(rows)};
    } catch (_) {
      return const {};
    }
  }

  Map<String, Object?> _textTotals(Map<String, Object?> totals) => {
    for (final e in totals.entries)
      e.key: _column(e.key)?.aggregateText(e.value) ?? e.value,
  };

  PdfColor get _pdfAccent => PdfColor.fromInt(theme.accentColor.toARGB32());

  String get _hexAccent =>
      '#${(theme.accentColor.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';

  String _formatLabel(ExportFormat format) => switch (format) {
    ExportFormat.excel => 'Excel',
    ExportFormat.word => 'Word',
    ExportFormat.pdf => 'PDF',
    ExportFormat.csv => 'CSV',
  };

  /// Generates the file of [format] for [state] and saves / shares /
  /// downloads it (or hands it to `TableExportOptions.onExport`).
  Future<void> export(
    ExportFormat format, {
    required TableLoaded<T> state,
    required bool isRtl,
    ScaffoldMessengerState? messenger,
    List<T>? rows,
  }) async {
    final exported = rows ?? rowsToExport(state);
    if (onExportRequested != null) {
      try {
        await onExportRequested!(format, exported);
      } catch (e) {
        _showSnackbar(messenger, labels.exportFailed(_formatLabel(format), e));
      }
      return;
    }
    final definitions = orderedDefinitions(state);
    final hidden = state.hiddenColumnIds;
    final totals = totalsOf(exported);

    try {
      final Uint8List bytes = switch (format) {
        ExportFormat.excel => await const ExcelExporter().generateExcel<T>(
          sheetName: reportTitle,
          columns: definitions,
          items: exported,
          valueProviders: valueProviders,
          hiddenColumnIds: hidden,
          isRtl: isRtl,
          headerColor: _hexAccent,
          totals: totals,
          totalsLabel: labels.total,
        ),
        ExportFormat.csv => await const CsvExporter().generateCsv<T>(
          columns: definitions,
          items: exported,
          valueProviders: valueProviders,
          hiddenColumnIds: hidden,
          totals: totals,
          totalsLabel: labels.total,
          delimiter: options.csvDelimiter,
        ),
        ExportFormat.word => await const WordExporter().generateWord<T>(
          title: reportTitle,
          subtitle: subtitle,
          columns: definitions,
          items: exported,
          valueProviders: valueProviders,
          isRtl: isRtl,
          hiddenColumnIds: hidden,
          formatters: _formatters,
          exportedOnLabel: labels.exportedOn,
          accentColor: _hexAccent,
          totals: _textTotals(totals),
          totalsLabel: labels.total,
        ),
        ExportFormat.pdf =>
          await PdfExporter(
            font: options.pdfFont,
            boldFont: options.pdfBoldFont,
          ).generatePdf<T>(
            title: reportTitle,
            subtitle: subtitle,
            columns: definitions,
            items: exported,
            valueProviders: valueProviders,
            isRtl: isRtl,
            hiddenColumnIds: hidden,
            formatters: _formatters,
            pageFormat: options.pdfPageFormat,
            accentColor: _pdfAccent,
            totals: _textTotals(totals),
            totalsLabel: labels.total,
          ),
      };

      final fileName = ExportUtils.sanitizeFileName(
        options.fileName ?? reportTitle,
        extension: format.extension,
      );

      if (options.onExport != null) {
        await options.onExport!(format, bytes, fileName);
        return;
      }

      final savedPath = await saveAndShareFile(
        bytes: bytes,
        fileName: fileName,
        mimeType: format.mimeType,
      );
      final isDesktop =
          !kIsWeb &&
          (defaultTargetPlatform == TargetPlatform.windows ||
              defaultTargetPlatform == TargetPlatform.macOS ||
              defaultTargetPlatform == TargetPlatform.linux);
      if (isDesktop && savedPath != null) {
        _showSnackbar(messenger, labels.savedTo(savedPath));
      }
    } catch (e) {
      _showSnackbar(messenger, labels.exportFailed(_formatLabel(format), e));
    }
  }

  /// Opens the platform print dialog (or calls `onPrintRequested`).
  Future<void> printTable({
    required TableLoaded<T> state,
    required bool isRtl,
    ScaffoldMessengerState? messenger,
    List<T>? rows,
  }) async {
    final printed = rows ?? rowsToExport(state);
    try {
      if (onPrintRequested != null) {
        await onPrintRequested!(printed);
        return;
      }
      await PdfExporter(
        font: options.pdfFont,
        boldFont: options.pdfBoldFont,
      ).printTable<T>(
        title: reportTitle,
        subtitle: subtitle,
        columns: orderedDefinitions(state),
        items: printed,
        valueProviders: valueProviders,
        isRtl: isRtl,
        hiddenColumnIds: state.hiddenColumnIds,
        formatters: _formatters,
        pageFormat: options.pdfPageFormat,
        accentColor: _pdfAccent,
        totals: _textTotals(totalsOf(printed)),
        totalsLabel: labels.total,
      );
    } catch (e) {
      _showSnackbar(messenger, labels.exportFailed(labels.print, e));
    }
  }

  /// [rows] as tab-separated text with a header line (pastes into Excel or
  /// Google Sheets as cells), using the displayed text of the visible,
  /// exportable columns in display order.
  String rowsToTsv(List<T> rows, TableLoaded<T> state) {
    final cols = state
        .arrange(columns, (c) => c.definition)
        .where((c) => c.isExportable && valueProviders.containsKey(c.id))
        .toList();
    String clean(String s) => s.replaceAll(RegExp(r'[\t\r\n]+'), ' ');
    String text(AdaptiveTableColumn<T> c, T row) {
      final raw = valueProviders[c.id]!(row);
      return clean((c.valueFormatter ?? ExportUtils.formatValue)(raw));
    }

    return [
      cols.map((c) => clean(c.title)).join('\t'),
      for (final row in rows) cols.map((c) => text(c, row)).join('\t'),
    ].join('\n');
  }

  /// Copies [rows] (default: the rows that would be exported) to the
  /// clipboard as tab-separated text. Returns the number of copied rows.
  Future<int> copyRows({
    required TableLoaded<T> state,
    ScaffoldMessengerState? messenger,
    List<T>? rows,
  }) async {
    final copied = rows ?? rowsToExport(state);
    if (copied.isEmpty) return 0;
    await Clipboard.setData(ClipboardData(text: rowsToTsv(copied, state)));
    _showSnackbar(messenger, labels.copied(copied.length));
    return copied.length;
  }

  /// Copies one cell's text.
  Future<void> copyText(
    String text, {
    ScaffoldMessengerState? messenger,
  }) async {
    await Clipboard.setData(ClipboardData(text: text));
    _showSnackbar(messenger, labels.copied(1));
  }

  void _showSnackbar(ScaffoldMessengerState? messenger, String message) {
    if (messenger == null || !messenger.mounted) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), duration: const Duration(seconds: 3)),
      );
  }
}
