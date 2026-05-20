import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../domain/models/column_definition.dart';

/// Exporter responsible for producing stylized PDF documents of the table.
/// Fully supports RTL locales (like Arabic) and custom font fallbacks.
class PdfExporter {
  const PdfExporter();

  /// Generates the raw PDF document bytes.
  Future<Uint8List> generatePdf<T>({
    required String title,
    String? subtitle,
    required List<ColumnDefinition> columns,
    required List<T> items,
    required Map<String, dynamic Function(T)> valueProviders,
    bool isRtl = false,
  }) async {
    final pdf = pw.Document();

    // Try to load Cairo font for Arabic/RTL. Fallback to Helvetica if offline or failed.
    pw.Font font;
    try {
      font = await PdfGoogleFonts.cairoRegular();
    } catch (_) {
      font = pw.Font.helvetica();
    }

    // Filter visible columns
    final visibleCols = columns.where((c) => c.isVisible).toList();

    // Table headers
    final headers = visibleCols.map((c) => c.title).toList();

    // Table rows
    final rows = items.map((item) {
      return visibleCols.map((col) {
        final extractor = valueProviders[col.id];
        final val = extractor != null ? extractor(item) : '';
        return val?.toString() ?? '';
      }).toList();
    }).toList();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        textDirection: isRtl ? pw.TextDirection.rtl : pw.TextDirection.ltr,
        theme: pw.ThemeData.withFont(base: font, bold: font),
        build: (context) {
          return [
            // Report Header
            pw.Container(
              margin: const pw.EdgeInsets.only(bottom: 20),
              decoration: const pw.BoxDecoration(
                border: pw.Border(
                  bottom: pw.BorderSide(color: PdfColors.grey300, width: 1),
                ),
              ),
              padding: const pw.EdgeInsets.only(bottom: 10),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: isRtl
                        ? pw.CrossAxisAlignment.end
                        : pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        title,
                        style: pw.TextStyle(
                          fontSize: 22,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.blue800,
                        ),
                      ),
                      if (subtitle != null) ...[
                        pw.SizedBox(height: 4),
                        pw.Text(
                          subtitle,
                          style: const pw.TextStyle(
                            fontSize: 12,
                            color: PdfColors.grey600,
                          ),
                        ),
                      ],
                    ],
                  ),
                  pw.Text(
                    DateTime.now().toString().split(' ').first,
                    style: const pw.TextStyle(
                      fontSize: 10,
                      color: PdfColors.grey500,
                    ),
                  ),
                ],
              ),
            ),

            // Table body
            pw.TableHelper.fromTextArray(
              headers: headers,
              data: rows,
              border: pw.TableBorder.all(color: PdfColors.grey200, width: 0.5),
              headerStyle: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.white,
              ),
              headerDecoration: const pw.BoxDecoration(
                color: PdfColors.blue800,
              ),
              rowDecoration: const pw.BoxDecoration(color: PdfColors.white),
              oddRowDecoration: const pw.BoxDecoration(color: PdfColors.grey50),
              cellAlignment: isRtl
                  ? pw.Alignment.centerRight
                  : pw.Alignment.centerLeft,
              headerAlignment: isRtl
                  ? pw.Alignment.centerRight
                  : pw.Alignment.centerLeft,
              cellPadding: const pw.EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 8,
              ),
            ),
          ];
        },
        footer: (context) {
          return pw.Container(
            alignment: isRtl
                ? pw.Alignment.centerLeft
                : pw.Alignment.centerRight,
            margin: const pw.EdgeInsets.only(top: 15),
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

  /// Direct system printing action.
  Future<void> printTable<T>({
    required String title,
    String? subtitle,
    required List<ColumnDefinition> columns,
    required List<T> items,
    required Map<String, dynamic Function(T)> valueProviders,
    bool isRtl = false,
  }) async {
    final pdfBytes = await generatePdf(
      title: title,
      subtitle: subtitle,
      columns: columns,
      items: items,
      valueProviders: valueProviders,
      isRtl: isRtl,
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdfBytes,
      name: '${title.replaceAll(' ', '_')}.pdf',
    );
  }
}
