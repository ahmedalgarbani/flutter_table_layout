import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart' hide TextDirection;
import '../../core/theme.dart';
import '../cubit/table_cubit.dart';
import '../cubit/table_cubit_state.dart';

/// The toolbar widget that holds inputs for searching, date ranges,
/// query submissions, and custom search filters.
class TableFilterBar<T> extends StatefulWidget {
  final bool showSearch;
  final List<Widget>? customFilters;
  final String searchHint;
  final String dateFromLabel;
  final String dateToLabel;
  final String queryButtonLabel;
  final VoidCallback? onQueryPressed;
  final AdaptiveTableTheme theme;

  const TableFilterBar({
    super.key,
    required this.showSearch,
    this.customFilters,
    required this.searchHint,
    required this.dateFromLabel,
    required this.dateToLabel,
    required this.queryButtonLabel,
    this.onQueryPressed,
    required this.theme,
  });

  @override
  State<TableFilterBar<T>> createState() => _TableFilterBarState<T>();
}

class _TableFilterBarState<T> extends State<TableFilterBar<T>> {
  late TextEditingController _searchController;
  DateTime? _startDate;
  DateTime? _endDate;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textDirection = Directionality.of(context);
    final isRtl = textDirection == TextDirection.rtl;

    return BlocConsumer<TableCubit<T>, TableCubitState<T>>(
      listener: (context, state) {
        if (state is TableLoaded<T>) {
          // Sync dates if they change externally (e.g. state reset)
          if (state.tableState.startDate != _startDate) {
            setState(() {
              _startDate = state.tableState.startDate;
            });
          }
          if (state.tableState.endDate != _endDate) {
            setState(() {
              _endDate = state.tableState.endDate;
            });
          }
        }
      },
      builder: (context, state) {
        if (state is! TableLoaded<T>) return const SizedBox.shrink();

        return Container(
          decoration: BoxDecoration(
            color: widget.theme.cardBackgroundColor,
            border: Border(
              bottom: BorderSide(color: widget.theme.dividerColor, width: 1.0),
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
          child: Wrap(
            spacing: 12,
            runSpacing: 10,
            alignment: isRtl ? WrapAlignment.end : WrapAlignment.start,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              // Search Input Field
              if (widget.showSearch)
                SizedBox(
                  width: 260,
                  height: 40,
                  child: TextField(
                    controller: _searchController,
                    onChanged: (val) {
                      context.read<TableCubit<T>>().updateSearchQuery(val);
                    },
                    style: widget.theme.rowTextStyle.copyWith(fontSize: 13),
                    decoration: InputDecoration(
                      hintText: widget.searchHint,
                      hintStyle: widget.theme.footerTextStyle.copyWith(
                        fontSize: 12,
                      ),
                      prefixIcon: const Icon(Icons.search, size: 18),
                      contentPadding: const EdgeInsets.symmetric(
                        vertical: 0,
                        horizontal: 10,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8.0),
                        borderSide: BorderSide(
                          color: widget.theme.dividerColor,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8.0),
                        borderSide: BorderSide(
                          color: widget.theme.dividerColor,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8.0),
                        borderSide: BorderSide(color: Colors.blue.shade500),
                      ),
                    ),
                  ),
                ),

              // Date Selectors: From Date / To Date
              _buildDatePicker(
                label: widget.dateFromLabel,
                selectedDate: _startDate,
                onDatePicked: (date) {
                  setState(() {
                    _startDate = date;
                  });
                  // If no query button is registered, apply updates instantly
                  if (widget.onQueryPressed == null) {
                    context.read<TableCubit<T>>().updateDateRange(
                      _startDate,
                      _endDate,
                    );
                  }
                },
              ),

              _buildDatePicker(
                label: widget.dateToLabel,
                selectedDate: _endDate,
                onDatePicked: (date) {
                  setState(() {
                    _endDate = date;
                  });
                  // If no query button is registered, apply updates instantly
                  if (widget.onQueryPressed == null) {
                    context.read<TableCubit<T>>().updateDateRange(
                      _startDate,
                      _endDate,
                    );
                  }
                },
              ),

              // Custom user-defined filters
              if (widget.customFilters != null) ...widget.customFilters!,

              // Query trigger button
              if (widget.onQueryPressed != null)
                SizedBox(
                  height: 40,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal.shade700,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                    ),
                    onPressed: () {
                      // Apply date range filters to cubit
                      context.read<TableCubit<T>>().updateDateRange(
                        _startDate,
                        _endDate,
                      );
                      // Trigger callback
                      widget.onQueryPressed!();
                    },
                    child: Text(
                      widget.queryButtonLabel,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDatePicker({
    required String label,
    required DateTime? selectedDate,
    required ValueChanged<DateTime?> onDatePicked,
  }) {
    final dateFormat = DateFormat('yyyy-MM-dd');
    final formattedDate = selectedDate != null
        ? dateFormat.format(selectedDate)
        : '';

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$label ',
          style: widget.theme.rowTextStyle.copyWith(
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
        InkWell(
          onTap: () async {
            final now = DateTime.now();
            final date = await showDatePicker(
              context: context,
              initialDate: selectedDate ?? now,
              firstDate: DateTime(2000),
              lastDate: DateTime(2100),
            );
            if (date != null) {
              onDatePicked(date);
            }
          },
          child: Container(
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: widget.theme.dividerColor),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  formattedDate.isNotEmpty ? formattedDate : '----/--/--',
                  style: widget.theme.rowTextStyle.copyWith(fontSize: 12),
                ),
                const SizedBox(width: 6),
                Icon(
                  Icons.calendar_today,
                  size: 14,
                  color: widget.theme.actionIconColor,
                ),
                if (selectedDate != null) ...[
                  const SizedBox(width: 4),
                  GestureDetector(
                    onTap: () => onDatePicked(null),
                    child: Icon(
                      Icons.close,
                      size: 12,
                      color: Colors.red.shade400,
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
