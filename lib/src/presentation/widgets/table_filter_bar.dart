import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../../core/labels.dart';
import '../../core/theme.dart';
import '../cubit/table_cubit.dart';
import '../cubit/table_cubit_state.dart';

/// The toolbar widget that holds inputs for searching, date ranges,
/// query submissions, and custom search filters.
class TableFilterBar<T> extends StatefulWidget {
  final bool showSearch;
  final bool showDateFilter;
  final bool showClearFilters;
  final List<Widget>? customFilters;
  final VoidCallback? onQueryPressed;
  final Duration searchDebounce;
  final DateTime? firstDate;
  final DateTime? lastDate;
  final AdaptiveTableTheme theme;
  final AdaptiveTableLabels labels;

  const TableFilterBar({
    super.key,
    required this.showSearch,
    this.showDateFilter = true,
    this.showClearFilters = true,
    this.customFilters,
    this.onQueryPressed,
    this.searchDebounce = const Duration(milliseconds: 250),
    this.firstDate,
    this.lastDate,
    required this.theme,
    this.labels = AdaptiveTableLabels.en,
  });

  @override
  State<TableFilterBar<T>> createState() => _TableFilterBarState<T>();
}

class _TableFilterBarState<T> extends State<TableFilterBar<T>> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;
  DateTime? _startDate;
  DateTime? _endDate;

  @override
  void initState() {
    super.initState();
    final s = context.read<TableCubit<T>>().tableState;
    _searchController.text = s.searchQuery;
    _startDate = s.startDate;
    _endDate = s.endDate;
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    if (widget.searchDebounce == Duration.zero) {
      context.read<TableCubit<T>>().updateSearchQuery(value);
      return;
    }
    _debounce = Timer(widget.searchDebounce, () {
      if (mounted) context.read<TableCubit<T>>().updateSearchQuery(value);
    });
  }

  void _clearSearch() {
    _debounce?.cancel();
    _searchController.clear();
    context.read<TableCubit<T>>().updateSearchQuery('');
  }

  void _applyDates() {
    context.read<TableCubit<T>>().updateDateRange(_startDate, _endDate);
  }

  bool get _hasContent =>
      widget.showSearch ||
      widget.showDateFilter ||
      (widget.customFilters?.isNotEmpty ?? false);

  @override
  Widget build(BuildContext context) {
    if (!_hasContent) return const SizedBox.shrink();
    final theme = widget.theme;

    return BlocConsumer<TableCubit<T>, TableCubitState<T>>(
      listenWhen: (prev, next) => next is TableLoaded<T>,
      listener: (context, state) {
        if (state is! TableLoaded<T>) return;
        final s = state.tableState;
        // Sync with external changes (controller, resetFilters…).
        if (s.searchQuery != _searchController.text &&
            !(_debounce?.isActive ?? false)) {
          _searchController.text = s.searchQuery;
        }
        // With a query button the pickers hold pending (unapplied) values.
        final pending = widget.onQueryPressed != null;
        if (!pending && (s.startDate != _startDate || s.endDate != _endDate)) {
          setState(() {
            _startDate = s.startDate;
            _endDate = s.endDate;
          });
        }
      },
      buildWhen: (prev, next) =>
          prev.runtimeType != next.runtimeType ||
          (prev is TableLoaded<T> &&
              next is TableLoaded<T> &&
              prev.tableState.hasActiveFilters !=
                  next.tableState.hasActiveFilters),
      builder: (context, state) {
        if (state is! TableLoaded<T>) return const SizedBox.shrink();
        final hasActiveFilters =
            state.tableState.hasActiveFilters ||
            _startDate != null ||
            _endDate != null;

        return Container(
          decoration: BoxDecoration(
            color: theme.enableGlassmorphism
                ? Colors.transparent
                : theme.cardBackgroundColor,
            border: Border(
              bottom: BorderSide(color: theme.dividerColor, width: 1.0),
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
          child: LayoutBuilder(
            builder: (context, constraints) {
              return Wrap(
                spacing: 12,
                runSpacing: 10,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (widget.showSearch)
                    _buildSearchField(math.min(280, constraints.maxWidth)),
                  if (widget.showDateFilter) ...[
                    _buildDatePicker(
                      label: widget.labels.dateFrom,
                      selectedDate: _startDate,
                      onDatePicked: (date) {
                        setState(() => _startDate = date);
                        if (widget.onQueryPressed == null) _applyDates();
                      },
                    ),
                    _buildDatePicker(
                      label: widget.labels.dateTo,
                      selectedDate: _endDate,
                      onDatePicked: (date) {
                        setState(() => _endDate = date);
                        if (widget.onQueryPressed == null) _applyDates();
                      },
                    ),
                  ],
                  ...?widget.customFilters,
                  if (widget.onQueryPressed != null)
                    SizedBox(
                      height: 40,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.accentColor,
                          foregroundColor: theme.onAccentColor,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8.0),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                        ),
                        onPressed: () {
                          _applyDates();
                          widget.onQueryPressed!();
                        },
                        child: Text(
                          widget.labels.query,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  if (widget.showClearFilters && hasActiveFilters)
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        foregroundColor: theme.statusNegativeColor,
                      ),
                      icon: const Icon(Icons.filter_alt_off_outlined, size: 18),
                      label: Text(
                        widget.labels.clearFilters,
                        style: const TextStyle(fontSize: 12),
                      ),
                      onPressed: () {
                        _debounce?.cancel();
                        _searchController.clear();
                        setState(() {
                          _startDate = null;
                          _endDate = null;
                        });
                        context.read<TableCubit<T>>().resetFilters();
                      },
                    ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildSearchField(double width) {
    final theme = widget.theme;
    OutlineInputBorder border(Color color, [double w = 1]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.0),
          borderSide: BorderSide(color: color, width: w),
        );

    return SizedBox(
      width: width,
      height: 40,
      child: ValueListenableBuilder<TextEditingValue>(
        valueListenable: _searchController,
        builder: (context, value, _) {
          return TextField(
            controller: _searchController,
            onChanged: _onSearchChanged,
            style: theme.rowTextStyle.copyWith(fontSize: 13),
            cursorColor: theme.accentColor,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: widget.labels.search,
              hintStyle: theme.footerTextStyle.copyWith(fontSize: 12),
              prefixIcon: Icon(
                Icons.search,
                size: 18,
                color: theme.actionIconColor,
              ),
              suffixIcon: value.text.isEmpty
                  ? null
                  : IconButton(
                      icon: Icon(
                        Icons.close,
                        size: 16,
                        color: theme.actionIconColor,
                      ),
                      onPressed: _clearSearch,
                    ),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                vertical: 0,
                horizontal: 10,
              ),
              border: border(theme.dividerColor),
              enabledBorder: border(theme.dividerColor),
              focusedBorder: border(theme.accentColor, 1.5),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDatePicker({
    required String label,
    required DateTime? selectedDate,
    required ValueChanged<DateTime?> onDatePicked,
  }) {
    final theme = widget.theme;
    final formattedDate = selectedDate != null
        ? DateFormat('yyyy-MM-dd').format(selectedDate)
        : '----/--/--';

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$label ',
          style: theme.rowTextStyle.copyWith(
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
        InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () async {
            final first = widget.firstDate ?? DateTime(1900);
            final last = widget.lastDate ?? DateTime(2200);
            var initial = selectedDate ?? DateTime.now();
            if (initial.isBefore(first)) initial = first;
            if (initial.isAfter(last)) initial = last;
            final date = await showDatePicker(
              context: context,
              initialDate: initial,
              firstDate: first,
              lastDate: last,
            );
            if (date != null) onDatePicked(date);
          },
          child: Container(
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: theme.dividerColor),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  formattedDate,
                  style: theme.rowTextStyle.copyWith(fontSize: 12),
                ),
                const SizedBox(width: 6),
                Icon(
                  Icons.calendar_today,
                  size: 14,
                  color: theme.actionIconColor,
                ),
                if (selectedDate != null) ...[
                  const SizedBox(width: 2),
                  InkResponse(
                    radius: 14,
                    onTap: () => onDatePicked(null),
                    child: Padding(
                      padding: const EdgeInsets.all(2),
                      child: Icon(
                        Icons.close,
                        size: 14,
                        color: theme.statusNegativeColor,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}
