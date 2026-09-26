import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../domain/models/column_definition.dart';
import 'export_utils.dart';

/// Exporter responsible for producing stylized PDF documents of the table.
/// Fully supports RTL locales (like Arabic) and custom font fallbacks.
///
/// Fonts: pass [font] / [boldFont] (e.g. `pw.Font.ttf(await rootBundle.load(...))`)
/// for offline apps. Otherwise the Cairo Google Font is downloaded once
/// (cached for the app lifetime, 10s timeout) and Helvetica is used as the
/// last resort (Helvetica can't render Arabic).
class PdfExporter {
  /// Regular font used for the whole document.
  final pw.Font? font;

  /// Bold font used for titles and header cells.
  final pw.Font? boldFont;

  const PdfExporter({this.font, this.boldFont});

  static Future<(pw.Font, pw.Font)>? _cachedCairo;

  /// Generates the raw PDF document bytes.
  ///
  /// When [pageFormat] is `null`, A4 is used, switched to landscape when more
  /// than 6 columns are exported.
  Future<Uint8List> generatePdf<T>({
    required String title,
    String? subtitle,
    required List<ColumnDefinition> columns,
    required List<T> items,
    required Map<String, dynamic Function(T)> valueProviders,
    bool isRtl = false,
    Iterable<String> hiddenColumnIds = const [],
    Map<String, ExportValueFormatter>? formatters,
    PdfPageFormat? pageFormat,
    PdfColor accentColor = PdfColors.blue800,
  }) async {
    final (regular, bold) = await _resolveFonts();
    final pdf = pw.Document(title: title);

    final visibleCols = ExportUtils.exportableColumns(
      columns,
      hiddenColumnIds: hiddenColumnIds,
    );
    final headers = visibleCols.map((c) => c.title).toList();
    final rows = items.map((item) {
      return visibleCols.map((col) {
        final raw = valueProviders[col.id]?.call(item);
        return (formatters?[col.id] ?? ExportUtils.formatValue)(raw);
      }).toList();
    }).toList();

    final format =
        pageFormat ??
        (visibleCols.length > 6
            ? PdfPageFormat.a4.landscape
            : PdfPageFormat.a4);

    pw.Alignment cellAlignment(TableColumnAlignment a) => switch (a) {
      TableColumnAlignment.center => pw.Alignment.center,
      TableColumnAlignment.start =>
        isRtl ? pw.Alignment.centerRight : pw.Alignment.centerLeft,
      TableColumnAlignment.end =>
        isRtl ? pw.Alignment.centerLeft : pw.Alignment.centerRight,
    };

    pdf.addPage(
      pw.MultiPage(
        pageFormat: format,
        margin: const pw.EdgeInsets.all(28),
        textDirection: isRtl ? pw.TextDirection.rtl : pw.TextDirection.ltr,
        theme: pw.ThemeData.withFont(base: regular, bold: bold),
        build: (context) {
          return [
            // Report Header
            pw.Container(
              margin: const pw.EdgeInsets.only(bottom: 16),
              decoration: const pw.BoxDecoration(
                border: pw.Border(
                  bottom: pw.BorderSide(color: PdfColors.grey300, width: 1),
                ),
              ),
              padding: const pw.EdgeInsets.only(bottom: 10),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          title,
                          style: pw.TextStyle(
                            fontSize: 20,
                            fontWeight: pw.FontWeight.bold,
                            color: accentColor,
                          ),
                        ),
                        if (subtitle != null && subtitle.isNotEmpty) ...[
                          pw.SizedBox(height: 4),
                          pw.Text(
                            subtitle,
                            style: const pw.TextStyle(
                              fontSize: 11,
                              color: PdfColors.grey600,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  pw.Text(
                    ExportUtils.formatDate(DateTime.now()),
                    style: const pw.TextStyle(
                      fontSize: 9,
                      color: PdfColors.grey500,
                    ),
                  ),
                ],
              ),
            ),

            // Table body
            if (visibleCols.isNotEmpty)
              pw.TableHelper.fromTextArray(
                headers: headers,
                data: rows,
                border: pw.TableBorder.all(
                  color: PdfColors.grey300,
                  width: 0.5,
                ),
                headerStyle: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.white,
                  fontSize: 10,
                ),
                cellStyle: const pw.TextStyle(fontSize: 9.5),
                headerDecoration: pw.BoxDecoration(color: accentColor),
                rowDecoration: const pw.BoxDecoration(color: PdfColors.white),
                oddRowDecoration: const pw.BoxDecoration(
                  color: PdfColors.grey100,
                ),
                columnWidths: {
                  for (var i = 0; i < visibleCols.length; i++)
                    i: visibleCols[i].width != null
                        ? pw.FlexColumnWidth(visibleCols[i].width! / 80)
                        : pw.FlexColumnWidth(visibleCols[i].flex.toDouble()),
                },
                cellAlignments: {
                  for (var i = 0; i < visibleCols.length; i++)
                    i: cellAlignment(visibleCols[i].alignment),
                },
                headerAlignments: {
                  for (var i = 0; i < visibleCols.length; i++)
                    i: cellAlignment(visibleCols[i].alignment),
                },
                cellPadding: const pw.EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 6,
                ),
              ),
          ];
        },
        footer: (context) {
          return pw.Container(
            alignment: pw.Alignment.center,
            margin: const pw.EdgeInsets.only(top: 12),
            child: pw.Text(
              '${context.pageNumber} / ${context.pagesCount}',
              style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey500),
            ),
          );
        },
      ),
    );

    return pdf.save();
  }

  /// Direct system printing action (opens the platform print dialog).
  Future<void> printTable<T>({
    required String title,
    String? subtitle,
    required List<ColumnDefinition> columns,
    required List<T> items,
    required Map<String, dynamic Function(T)> valueProviders,
    bool isRtl = false,
    Iterable<String> hiddenColumnIds = const [],
    Map<String, ExportValueFormatter>? formatters,
    PdfPageFormat? pageFormat,
    PdfColor accentColor = PdfColors.blue800,
  }) async {
    final pdfBytes = await generatePdf<T>(
      title: title,
      subtitle: subtitle,
      columns: columns,
      items: items,
      valueProviders: valueProviders,
      isRtl: isRtl,
      hiddenColumnIds: hiddenColumnIds,
      formatters: formatters,
      pageFormat: pageFormat,
      accentColor: accentColor,
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdfBytes,
      name: ExportUtils.sanitizeFileName(title, extension: 'pdf'),
    );
  }

  Future<(pw.Font, pw.Font)> _resolveFonts() async {
    if (font != null) return (font!, boldFont ?? font!);
    try {
      final (regular, bold) = await (_cachedCairo ??= _loadCairo());
      return (regular, boldFont ?? bold);
    } catch (_) {
      _cachedCairo = null; // retry on the next export
      return (pw.Font.helvetica(), boldFont ?? pw.Font.helveticaBold());
    }
  }

  static Future<(pw.Font, pw.Font)> _loadCairo() async {
    const timeout = Duration(seconds: 10);
    final regular = await PdfGoogleFonts.cairoRegular().timeout(timeout);
    final bold = await PdfGoogleFonts.cairoBold().timeout(timeout);
    return (regular, bold);
  }
}
