import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// File formats produced by the toolbar export menu.
enum ExportFormat {
  excel(
    'xlsx',
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
  ),
  word('doc', 'application/msword'),
  pdf('pdf', 'application/pdf');

  const ExportFormat(this.extension, this.mimeType);

  /// File extension without the dot.
  final String extension;

  /// MIME type of the produced file.
  final String mimeType;
}

/// Custom handler for exported files (upload them, save them somewhere
/// specific, attach them to an e-mail…). Replaces the default save / share.
typedef ExportHandler =
    Future<void> Function(
      ExportFormat format,
      Uint8List bytes,
      String fileName,
    );

/// Options for the export / print actions of `AdaptiveTableLayout`.
class TableExportOptions {
  /// Base file name (without extension). Defaults to the table title.
  final String? fileName;

  /// Which formats appear in the export menu.
  final Set<ExportFormat> formats;

  /// When `true` (default) and some rows are selected, only the selected rows
  /// are exported / printed. Otherwise all filtered rows are used.
  final bool exportSelectedWhenAny;

  /// Regular font embedded in PDFs (recommended for offline Arabic support).
  final pw.Font? pdfFont;

  /// Bold font embedded in PDFs.
  final pw.Font? pdfBoldFont;

  /// Page format of PDFs. `null` = A4, landscape when more than 6 columns.
  final PdfPageFormat? pdfPageFormat;

  /// Replaces the default "save / share / download" behaviour.
  final ExportHandler? onExport;

  const TableExportOptions({
    this.fileName,
    this.formats = const {
      ExportFormat.excel,
      ExportFormat.word,
      ExportFormat.pdf,
    },
    this.exportSelectedWhenAny = true,
    this.pdfFont,
    this.pdfBoldFont,
    this.pdfPageFormat,
    this.onExport,
  });
}
