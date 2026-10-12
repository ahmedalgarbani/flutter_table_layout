import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/labels.dart';
import '../../core/theme.dart';
import '../../data/exporters/table_export_options.dart';
import '../../domain/models/column_definition.dart';
import '../cubit/table_cubit.dart';
import '../cubit/table_cubit_state.dart';
import '../export/table_export_runner.dart';
import 'adaptive_table_column.dart';

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
  final bool showGroupingMenu;
  final List<Widget>? toolbarActions;
  final TableExportRunner<T> exportRunner;
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
    this.showGroupingMenu = false,
    this.toolbarActions,
    required this.exportRunner,
    this.mobileBreakpoint = 600,
    required this.theme,
    this.labels = AdaptiveTableLabels.en,
  });

  TableExportOptions get _exportOptions => exportRunner.options;

  List<AdaptiveTableColumn<T>> get _groupableColumns => [
    for (final c in columns)
      if (c.isGroupable && valueProviders.containsKey(c.id)) c,
  ];

  bool get _hasActions =>
      onRefreshPressed != null ||
      showColumnsToggle ||
      (showGroupingMenu && _groupableColumns.isNotEmpty) ||
      (showExport && _exportOptions.formats.isNotEmpty) ||
      showPrint ||
      onAddNewPressed != null ||
      (toolbarActions?.isNotEmpty ?? false);

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TableCubit<T>, TableCubitState<T>>(
      // Errors and loading states keep the last toolbar (and its actions).
      buildWhen: (prev, next) {
        if (next is! TableLoaded<T>) return false;
        if (prev is! TableLoaded<T>) return true;
        return prev.totalCount != next.totalCount ||
            !identical(prev.hiddenColumnIds, next.hiddenColumnIds) ||
            prev.selectedItems.length != next.selectedItems.length ||
            prev.tableState.groupByColumnId != next.tableState.groupByColumnId;
      },
      builder: (context, state) {
        final loaded = state is TableLoaded<T> ? state : null;
        if (title == null && !_hasActions) return const SizedBox.shrink();

        final titleBlock = title != null ? _buildTitle(loaded) : null;
        final actions = _hasActions ? _buildActions(context, loaded) : null;

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
                    ?titleBlock,
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

  Widget _buildTitle(TableLoaded<T>? state) {
    final selectedCount = state?.selectedItems.length ?? 0;
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
                  if (state != null) ...[
                    const SizedBox(width: 8),
                    _Badge(text: '${state.totalCount}', theme: theme),
                  ],
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

  Widget _buildActions(BuildContext context, TableLoaded<T>? state) {
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
        if (showGroupingMenu && _groupableColumns.isNotEmpty)
          _buildGroupingMenu(context, state, iconColor),
        if (showColumnsToggle) _buildColumnsToggler(context, iconColor),
        if (showExport && _exportOptions.formats.isNotEmpty)
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

  /// "Group by" menu: no grouping, or one of the groupable columns.
  Widget _buildGroupingMenu(
    BuildContext context,
    TableLoaded<T>? state,
    Color iconColor,
  ) {
    // The popup lives in the Navigator overlay, outside the BlocProvider.
    final cubit = context.read<TableCubit<T>>();
    final current = state?.tableState.groupByColumnId;
    PopupMenuItem<String> item(String value, String text, bool selected) {
      return PopupMenuItem<String>(
        value: value,
        height: 40,
        child: Row(
          children: [
            SizedBox(
              width: 24,
              child: selected
                  ? Icon(Icons.check, size: 18, color: theme.accentColor)
                  : null,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                text,
                overflow: TextOverflow.ellipsis,
                style: theme.rowTextStyle.copyWith(
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.w600 : null,
                  color: selected ? theme.accentColor : null,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return PopupMenuButton<String>(
      tooltip: labels.groupBy,
      icon: Icon(
        Icons.account_tree_outlined,
        size: 20,
        color: current == null ? iconColor : theme.accentColor,
      ),
      position: PopupMenuPosition.under,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      color: theme.cardBackgroundColor.withValues(alpha: 1),
      onSelected: (id) => cubit.groupBy(id.isEmpty ? null : id),
      itemBuilder: (_) => [
        item('', labels.noGrouping, current == null),
        const PopupMenuDivider(),
        for (final c in _groupableColumns) item(c.id, c.title, current == c.id),
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
      // The checkbox tiles have no intrinsic width of their own: without a
      // minimum the titles wrap mid-word ("Curren / cy").
      constraints: const BoxConstraints(minWidth: 240, maxWidth: 320),
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
                      : cubit.hiddenColumnIds;
                  final isVisible = !hidden.contains(col.id);
                  final visibleCount = columns.length - hidden.length;
                  final canToggle =
                      col.isHideable && (!isVisible || visibleCount > 1);
                  return CheckboxListTile(
                    title: Text(
                      col.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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
                    secondary: state is TableLoaded<T>
                        ? _pinButton(cubit, state, col)
                        : null,
                  );
                },
              ),
            );
          }).toList()
          ..add(const PopupMenuDivider())
          ..add(
            PopupMenuItem<String>(
              height: 40,
              onTap: cubit.resetColumnLayout,
              child: Row(
                children: [
                  Icon(
                    Icons.restart_alt,
                    size: 18,
                    color: theme.actionIconColor,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    labels.resetColumns,
                    style: theme.rowTextStyle.copyWith(fontSize: 13),
                  ),
                ],
              ),
            ),
          );
      },
    );
  }

  /// Cycles unfrozen → frozen at start → frozen at end → unfrozen.
  Widget _pinButton(
    TableCubit<T> cubit,
    TableLoaded<T> state,
    AdaptiveTableColumn<T> col,
  ) {
    final pin = state.pinOf(col.definition);
    final (next, tooltip) = switch (pin) {
      ColumnPin.none => (ColumnPin.start, labels.freezeStart),
      ColumnPin.start => (ColumnPin.end, labels.freezeEnd),
      ColumnPin.end => (ColumnPin.none, labels.unfreeze),
    };
    return IconButton(
      tooltip: tooltip,
      visualDensity: VisualDensity.compact,
      icon: Icon(
        pin == ColumnPin.none ? Icons.push_pin_outlined : Icons.push_pin,
        size: 18,
        color: pin == ColumnPin.none
            ? theme.actionIconColor.withValues(alpha: 0.6)
            : theme.accentColor,
      ),
      onPressed: () => cubit.setColumnPin(col.id, next),
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

    final formats = _exportOptions.formats;
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
        if (formats.contains(ExportFormat.csv))
          item(
            ExportFormat.csv,
            Icons.grid_on_outlined,
            Colors.teal.shade600,
            labels.exportCsv,
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

  Future<void> _export(BuildContext context, ExportFormat format) async {
    final state = context.read<TableCubit<T>>().state;
    if (state is! TableLoaded<T>) return;
    await exportRunner.export(
      format,
      state: state,
      isRtl: Directionality.of(context) == TextDirection.rtl,
      messenger: ScaffoldMessenger.maybeOf(context),
    );
  }

  Future<void> _printPdf(BuildContext context) async {
    final state = context.read<TableCubit<T>>().state;
    if (state is! TableLoaded<T>) return;
    await exportRunner.printTable(
      state: state,
      isRtl: Directionality.of(context) == TextDirection.rtl,
      messenger: ScaffoldMessenger.maybeOf(context),
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
