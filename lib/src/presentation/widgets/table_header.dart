import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/theme.dart';
import '../../core/utils/file_saver.dart';
import '../../data/exporters/excel_exporter.dart';
import '../../data/exporters/pdf_exporter.dart';
import '../../data/exporters/word_exporter.dart';
import '../cubit/table_cubit.dart';
import '../cubit/table_cubit_state.dart';
import 'adaptive_table_layout.dart';

/// The top header bar of the table layout.
/// Displays titles, refresh buttons, columns selector, and print/export utilities.
class TableHeader<T> extends StatelessWidget {
  final String? title;
  final String? subtitle;
  final Widget? titleIcon;
  final VoidCallback? onRefreshPressed;
  final VoidCallback? onAddNewPressed;
  final List<AdaptiveTableColumn<T>> columns;
  final Map<String, dynamic Function(T)> valueProviders;
  final bool showExport;
  final bool showPrint;
  final bool showColumnsToggle;
  final AdaptiveTableTheme theme;

  const TableHeader({
    super.key,
    this.title,
    this.subtitle,
    this.titleIcon,
    this.onRefreshPressed,
    this.onAddNewPressed,
    required this.columns,
    required this.valueProviders,
    required this.showExport,
    required this.showPrint,
    required this.showColumnsToggle,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final textDirection = Directionality.of(context);
    final isRtl = textDirection == TextDirection.rtl;

    return BlocBuilder<TableCubit<T>, TableCubitState<T>>(
      builder: (context, state) {
        if (state is! TableLoaded<T>) return const SizedBox.shrink();

        final items = state.filteredAndSortedItems;
        final totalCount = state.totalCount;

        return Container(
          decoration: BoxDecoration(
            color: theme.toolbarBackgroundColor ?? theme.cardBackgroundColor,
            border: Border(
              bottom: BorderSide(color: theme.dividerColor, width: 1.0),
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          child: Row(
            children: [
              // Title / Subtitle Column
              if (title != null) ...[
                if (titleIcon != null) ...[
                  titleIcon!,
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              title!,
                              style: theme.headerTextStyle.copyWith(
                                fontSize: 18,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade500.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '($totalCount)',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue.shade600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle!,
                          style: theme.footerTextStyle.copyWith(fontSize: 12),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
              ] else
                const Spacer(),

              // Action buttons toolbar
              Wrap(
                spacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  // Refresh button
                  if (onRefreshPressed != null)
                    _IconButton(
                      icon: const Icon(Icons.refresh, size: 20),
                      tooltip: isRtl ? 'تحديث' : 'Refresh',
                      onPressed: onRefreshPressed!,
                      theme: theme,
                    ),

                  // Columns Toggle dropdown
                  if (showColumnsToggle)
                    _buildColumnsToggler(context, state, isRtl),

                  // Exports dropdown (Excel, Word, PDF)
                  if (showExport) _buildExportMenu(context, items, isRtl),

                  // Print button
                  if (showPrint)
                    _IconButton(
                      icon: const Icon(Icons.print, size: 20),
                      tooltip: isRtl ? 'طباعة' : 'Print PDF',
                      onPressed: () => _printPdf(context, items, isRtl),
                      theme: theme,
                    ),

                  // Add New button
                  if (onAddNewPressed != null)
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade600,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                      ),
                      icon: const Icon(Icons.add, size: 18),
                      label: Text(
                        isRtl ? 'إضافة' : 'Add New',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      onPressed: onAddNewPressed!,
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildColumnsToggler(
    BuildContext context,
    TableLoaded<T> state,
    bool isRtl,
  ) {
    return PopupMenuButton<String>(
      tooltip: isRtl ? 'الأعمدة' : 'Columns',
      icon: Icon(
        Icons.view_column_outlined,
        color: theme.actionIconColor,
        size: 20,
      ),
      offset: const Offset(0, 40),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      itemBuilder: (context) {
        return columns.map<PopupMenuEntry<String>>((col) {
          final isHidden = state.hiddenColumnIds.contains(col.id);
          return PopupMenuItem<String>(
            value: col.id,
            child: StatefulBuilder(
              builder: (context, setState) {
                return CheckboxListTile(
                  title: Text(
                    col.title,
                    style: theme.rowTextStyle.copyWith(fontSize: 13),
                  ),
                  value: !isHidden,
                  controlAffinity: ListTileControlAffinity.leading,
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  onChanged: (val) {
                    context.read<TableCubit<T>>().toggleColumnVisibility(
                      col.id,
                    );
                    setState(() {});
                  },
                );
              },
            ),
          );
        }).toList();
      },
    );
  }

  Widget _buildExportMenu(BuildContext context, List<T> items, bool isRtl) {
    return PopupMenuButton<String>(
      tooltip: isRtl ? 'تصدير البيانات' : 'Export Data',
      icon: Icon(Icons.download, color: theme.actionIconColor, size: 20),
      offset: const Offset(0, 40),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      onSelected: (val) {
        switch (val) {
          case 'excel':
            _exportExcel(context, items);
            break;
          case 'word':
            _exportWord(context, items, isRtl);
            break;
          case 'pdf':
            _exportPdf(context, items, isRtl);
            break;
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'excel',
          child: Row(
            children: [
              const Icon(Icons.table_view, color: Colors.green, size: 18),
              const SizedBox(width: 8),
              Text(
                isRtl ? 'تصدير Excel' : 'Export Excel',
                style: const TextStyle(fontSize: 13),
              ),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'word',
          child: Row(
            children: [
              const Icon(Icons.description, color: Colors.blue, size: 18),
              const SizedBox(width: 8),
              Text(
                isRtl ? 'تصدير Word' : 'Export Word',
                style: const TextStyle(fontSize: 13),
              ),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'pdf',
          child: Row(
            children: [
              const Icon(Icons.picture_as_pdf, color: Colors.red, size: 18),
              const SizedBox(width: 8),
              Text(
                isRtl ? 'حفظ PDF' : 'Save PDF',
                style: const TextStyle(fontSize: 13),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _exportExcel(BuildContext context, List<T> items) async {
    try {
      final bytes = await ExcelExporter().generateExcel(
        sheetName: title ?? 'TableReport',
        columns: columns.map((c) => c.definition).toList(),
        items: items,
        valueProviders: valueProviders,
      );
      await saveAndShareFile(
        bytes: bytes,
        fileName: '${title?.replaceAll(' ', '_') ?? 'report'}.xlsx',
        mimeType:
            'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      );
    } catch (e) {
      _showSnackbar(context, 'Excel Export Failed: $e');
    }
  }

  Future<void> _exportWord(
    BuildContext context,
    List<T> items,
    bool isRtl,
  ) async {
    try {
      final bytes = await WordExporter().generateWord(
        title: title ?? 'Table Report',
        subtitle: subtitle,
        columns: columns.map((c) => c.definition).toList(),
        items: items,
        valueProviders: valueProviders,
        isRtl: isRtl,
      );
      await saveAndShareFile(
        bytes: bytes,
        fileName: '${title?.replaceAll(' ', '_') ?? 'report'}.doc',
        mimeType: 'application/msword',
      );
    } catch (e) {
      _showSnackbar(context, 'Word Export Failed: $e');
    }
  }

  Future<void> _exportPdf(
    BuildContext context,
    List<T> items,
    bool isRtl,
  ) async {
    try {
      final bytes = await const PdfExporter().generatePdf(
        title: title ?? 'Table Report',
        subtitle: subtitle,
        columns: columns.map((c) => c.definition).toList(),
        items: items,
        valueProviders: valueProviders,
        isRtl: isRtl,
      );
      await saveAndShareFile(
        bytes: bytes,
        fileName: '${title?.replaceAll(' ', '_') ?? 'report'}.pdf',
        mimeType: 'application/pdf',
      );
    } catch (e) {
      _showSnackbar(context, 'PDF Saving Failed: $e');
    }
  }

  Future<void> _printPdf(
    BuildContext context,
    List<T> items,
    bool isRtl,
  ) async {
    try {
      await const PdfExporter().printTable(
        title: title ?? 'Table Report',
        subtitle: subtitle,
        columns: columns.map((c) => c.definition).toList(),
        items: items,
        valueProviders: valueProviders,
        isRtl: isRtl,
      );
    } catch (e) {
      _showSnackbar(context, 'Printing Failed: $e');
    }
  }

  void _showSnackbar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 3)),
    );
  }
}

class _IconButton extends StatelessWidget {
  final Widget icon;
  final String tooltip;
  final VoidCallback onPressed;
  final AdaptiveTableTheme theme;

  const _IconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(8.0),
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: IconTheme(
              data: IconThemeData(color: theme.actionIconColor),
              child: icon,
            ),
          ),
        ),
      ),
    );
  }
}
