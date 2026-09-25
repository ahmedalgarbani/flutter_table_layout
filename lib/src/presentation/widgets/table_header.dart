import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pdf/pdf.dart';

import '../../core/labels.dart';
import '../../core/theme.dart';
import '../../core/utils/file_saver.dart';
import '../../data/exporters/excel_exporter.dart';
import '../../data/exporters/export_utils.dart';
import '../../data/exporters/pdf_exporter.dart';
import '../../data/exporters/table_export_options.dart';
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
  final List<Widget>? toolbarActions;
  final TableExportOptions exportOptions;
  final double mobileBreakpoint;
  final AdaptiveTableTheme theme;
  final AdaptiveTableLabels labels;

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
    this.toolbarActions,
    this.exportOptions = const TableExportOptions(),
    this.mobileBreakpoint = 600,
    required this.theme,
    this.labels = AdaptiveTableLabels.en,
  });

  bool get _hasActions =>
      onRefreshPressed != null ||
      showColumnsToggle ||
      (showExport && exportOptions.formats.isNotEmpty) ||
      showPrint ||
      onAddNewPressed != null ||
      (toolbarActions?.isNotEmpty ?? false);

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TableCubit<T>, TableCubitState<T>>(
      buildWhen: (prev, next) {
        if (prev is! TableLoaded<T> || next is! TableLoaded<T>) return true;
        return prev.totalCount != next.totalCount ||
            !identical(prev.hiddenColumnIds, next.hiddenColumnIds) ||
            prev.selectedItems.length != next.selectedItems.length;
      },
      builder: (context, state) {
        if (state is! TableLoaded<T>) return const SizedBox.shrink();
        if (title == null && !_hasActions) return const SizedBox.shrink();

        final titleBlock = title != null ? _buildTitle(state) : null;
        final actions = _hasActions ? _buildActions(context, state) : null;

        return Container(
          decoration: BoxDecoration(
            color: theme.headerGradient != null
                ? null
                : (theme.toolbarBackgroundColor ?? theme.cardBackgroundColor),
            gradient: theme.headerGradient,
            border: Border(
              bottom: BorderSide(color: theme.dividerColor, width: 1.0),
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final narrow = constraints.maxWidth < mobileBreakpoint;
              if (narrow) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (titleBlock != null) titleBlock,
                    if (titleBlock != null && actions != null)
                      const SizedBox(height: 8),
                    if (actions != null)
                      Align(
                        alignment: AlignmentDirectional.centerEnd,
                        child: actions,
                      ),
                  ],
                );
              }
              return Row(
                children: [
                  if (titleBlock != null)
                    Expanded(child: titleBlock)
                  else
                    const Spacer(),
                  if (actions != null) ...[
                    const SizedBox(width: 12),
                    Flexible(
                      child: Align(
                        alignment: AlignmentDirectional.centerEnd,
                        child: actions,
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildTitle(TableLoaded<T> state) {
    final selectedCount = state.selectedItems.length;
    return Row(
      children: [
        if (titleIcon != null) ...[titleIcon!, const SizedBox(width: 10)],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      title!,
                      style: theme.effectiveTitleTextStyle,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  _Badge(text: '${state.totalCount}', theme: theme),
                  if (selectedCount > 0) ...[
                    const SizedBox(width: 6),
                    _Badge(
                      text: labels.selectedCount(selectedCount),
                      theme: theme,
                      filled: true,
                    ),
                  ],
                ],
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle!,
                  style: theme.footerTextStyle.copyWith(
                    fontSize: 12,
                    color: theme.headerGradient != null
                        ? theme.effectiveTitleTextStyle.color?.withValues(
                            alpha: 0.8,
                          )
                        : null,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActions(BuildContext context, TableLoaded<T> state) {
    final iconColor = theme.effectiveToolbarIconColor;
    return Wrap(
      spacing: 4,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (onRefreshPressed != null)
          _ToolbarIconButton(
            icon: Icons.refresh,
            tooltip: labels.refresh,
            color: iconColor,
            onPressed: onRefreshPressed!,
          ),
        if (showColumnsToggle) _buildColumnsToggler(context, iconColor),
        if (showExport && exportOptions.formats.isNotEmpty)
          _buildExportMenu(context, iconColor),
        if (showPrint)
          _ToolbarIconButton(
            icon: Icons.print_outlined,
            tooltip: labels.print,
            color: iconColor,
            onPressed: () => _printPdf(context),
          ),
        ...?toolbarActions,
        if (onAddNewPressed != null)
          Padding(
            padding: const EdgeInsetsDirectional.only(start: 4),
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.accentColor,
                foregroundColor: theme.onAccentColor,
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
                labels.addNew,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
              onPressed: onAddNewPressed,
            ),
          ),
      ],
    );
  }

  Widget _buildColumnsToggler(BuildContext context, Color iconColor) {
    // The popup lives in the Navigator overlay, outside the BlocProvider, so
    // the cubit is captured here and passed explicitly.
    final cubit = context.read<TableCubit<T>>();
    return PopupMenuButton<String>(
      tooltip: labels.columns,
      icon: Icon(Icons.view_column_outlined, color: iconColor, size: 20),
      position: PopupMenuPosition.under,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      color: theme.cardBackgroundColor.withValues(alpha: 1),
      itemBuilder: (_) {
        return columns.map<PopupMenuEntry<String>>((col) {
          return PopupMenuItem<String>(
            enabled: false,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: BlocBuilder<TableCubit<T>, TableCubitState<T>>(
              bloc: cubit,
              builder: (context, state) {
                final hidden = state is TableLoaded<T>
                    ? state.hiddenColumnIds
                    : const <String>[];
                final isVisible = !hidden.contains(col.id);
                final visibleCount = columns.length - hidden.length;
                final canToggle =
                    col.isHideable && (!isVisible || visibleCount > 1);
                return CheckboxListTile(
                  title: Text(
                    col.title,
                    style: theme.rowTextStyle.copyWith(fontSize: 13),
                  ),
                  value: isVisible,
                  activeColor: theme.accentColor,
                  checkColor: theme.onAccentColor,
                  controlAffinity: ListTileControlAffinity.leading,
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  onChanged: canToggle
                      ? (_) => cubit.toggleColumnVisibility(col.id)
                      : null,
                );
              },
            ),
          );
        }).toList();
      },
    );
  }

  Widget _buildExportMenu(BuildContext context, Color iconColor) {
    PopupMenuItem<ExportFormat> item(
      ExportFormat format,
      IconData icon,
      Color color,
      String text,
    ) {
      return PopupMenuItem(
        value: format,
        child: Row(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 8),
            Text(text, style: theme.rowTextStyle.copyWith(fontSize: 13)),
          ],
        ),
      );
    }

    final formats = exportOptions.formats;
    return PopupMenuButton<ExportFormat>(
      tooltip: labels.exportData,
      icon: Icon(Icons.download_outlined, color: iconColor, size: 20),
      position: PopupMenuPosition.under,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      color: theme.cardBackgroundColor.withValues(alpha: 1),
      onSelected: (format) => _export(context, format),
      itemBuilder: (_) => [
        if (formats.contains(ExportFormat.excel))
          item(
            ExportFormat.excel,
            Icons.table_view,
            Colors.green.shade600,
            labels.exportExcel,
          ),
        if (formats.contains(ExportFormat.word))
          item(
            ExportFormat.word,
            Icons.description,
            Colors.blue.shade600,
            labels.exportWord,
          ),
        if (formats.contains(ExportFormat.pdf))
          item(
            ExportFormat.pdf,
            Icons.picture_as_pdf,
            Colors.red.shade600,
            labels.exportPdf,
          ),
      ],
    );
  }

  // --- Export helpers ---

  /// Rows to export: the selected ones (if any and enabled) otherwise every
  /// filtered row, in the current sort order.
  List<T> _rowsToExport(TableLoaded<T> state) {
    if (exportOptions.exportSelectedWhenAny && state.selectedItems.isNotEmpty) {
      final selected = state.selectedItems.toSet();
      return state.filteredAndSortedItems.where(selected.contains).toList();
    }
    return state.filteredAndSortedItems;
  }

  Map<String, ExportValueFormatter> get _formatters => {
    for (final c in columns)
      if (c.valueFormatter != null) c.id: c.valueFormatter!,
  };

  String get _reportTitle => title ?? labels.defaultReportTitle;

  PdfColor get _pdfAccent => PdfColor.fromInt(theme.accentColor.toARGB32());

  String get _hexAccent =>
      '#${(theme.accentColor.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';

  Future<void> _export(BuildContext context, ExportFormat format) async {
    final cubit = context.read<TableCubit<T>>();
    final state = cubit.state;
    if (state is! TableLoaded<T>) return;

    final messenger = ScaffoldMessenger.maybeOf(context);
    final isRtl = Directionality.of(context) == TextDirection.rtl;
    final rows = _rowsToExport(state);
    final definitions = columns.map((c) => c.definition).toList();
    final hidden = state.hiddenColumnIds;
    final formatLabel = switch (format) {
      ExportFormat.excel => 'Excel',
      ExportFormat.word => 'Word',
      ExportFormat.pdf => 'PDF',
    };

    try {
      final Uint8List bytes = switch (format) {
        ExportFormat.excel => await const ExcelExporter().generateExcel<T>(
          sheetName: _reportTitle,
          columns: definitions,
          items: rows,
          valueProviders: valueProviders,
          hiddenColumnIds: hidden,
          isRtl: isRtl,
          headerColor: _hexAccent,
        ),
        ExportFormat.word => await const WordExporter().generateWord<T>(
          title: _reportTitle,
          subtitle: subtitle,
          columns: definitions,
          items: rows,
          valueProviders: valueProviders,
          isRtl: isRtl,
          hiddenColumnIds: hidden,
          formatters: _formatters,
          exportedOnLabel: labels.exportedOn,
          accentColor: _hexAccent,
        ),
        ExportFormat.pdf =>
          await PdfExporter(
            font: exportOptions.pdfFont,
            boldFont: exportOptions.pdfBoldFont,
          ).generatePdf<T>(
            title: _reportTitle,
            subtitle: subtitle,
            columns: definitions,
            items: rows,
            valueProviders: valueProviders,
            isRtl: isRtl,
            hiddenColumnIds: hidden,
            formatters: _formatters,
            pageFormat: exportOptions.pdfPageFormat,
            accentColor: _pdfAccent,
          ),
      };

      final fileName = ExportUtils.sanitizeFileName(
        exportOptions.fileName ?? _reportTitle,
        extension: format.extension,
      );

      if (exportOptions.onExport != null) {
        await exportOptions.onExport!(format, bytes, fileName);
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
      _showSnackbar(messenger, labels.exportFailed(formatLabel, e));
    }
  }

  Future<void> _printPdf(BuildContext context) async {
    final state = context.read<TableCubit<T>>().state;
    if (state is! TableLoaded<T>) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    final isRtl = Directionality.of(context) == TextDirection.rtl;
    try {
      await PdfExporter(
        font: exportOptions.pdfFont,
        boldFont: exportOptions.pdfBoldFont,
      ).printTable<T>(
        title: _reportTitle,
        subtitle: subtitle,
        columns: columns.map((c) => c.definition).toList(),
        items: _rowsToExport(state),
        valueProviders: valueProviders,
        isRtl: isRtl,
        hiddenColumnIds: state.hiddenColumnIds,
        formatters: _formatters,
        pageFormat: exportOptions.pdfPageFormat,
        accentColor: _pdfAccent,
      );
    } catch (e) {
      _showSnackbar(messenger, labels.exportFailed(labels.print, e));
    }
  }

  void _showSnackbar(ScaffoldMessengerState? messenger, String message) {
    if (messenger == null || !messenger.mounted) return;
    messenger.showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 3)),
    );
  }
}

class _Badge extends StatelessWidget {
  final String text;
  final AdaptiveTableTheme theme;
  final bool filled;

  const _Badge({required this.text, required this.theme, this.filled = false});

  @override
  Widget build(BuildContext context) {
    final onGradient = theme.headerGradient != null;
    final bg = filled
        ? theme.accentColor
        : (onGradient
              ? Colors.white.withValues(alpha: 0.2)
              : theme.accentColor.withValues(alpha: 0.12));
    final fg = filled
        ? theme.onAccentColor
        : (onGradient ? Colors.white : theme.accentColor);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: fg),
      ),
    );
  }
}

class _ToolbarIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final Color color;
  final VoidCallback onPressed;

  const _ToolbarIconButton({
    required this.icon,
    required this.tooltip,
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon, size: 20, color: color),
      tooltip: tooltip,
      onPressed: onPressed,
      visualDensity: VisualDensity.compact,
    );
  }
}
