import 'package:flutter/material.dart';
import 'package:flutter_table_layout/flutter_table_layout.dart';
import 'package:intl/intl.dart' hide TextDirection;

import 'demo_data.dart';

final _money = NumberFormat('#,##0.00');
final _day = DateFormat('yyyy-MM-dd');

/// Shared column schema of the employee tabs.
List<AdaptiveTableColumn<Employee>> employeeColumns({
  required bool isArabic,
  required AdaptiveTableTheme theme,
  bool editable = false,
}) {
  String t(String ar, String en) => isArabic ? ar : en;
  final departments = isArabic ? departmentsAr : departmentsEn;
  return [
    AdaptiveTableColumn(
      id: 'id',
      title: t('الرقم', 'ID'),
      width: 80,
      alignment: TableColumnAlignment.center,
      pin: ColumnPin.start,
      isGroupable: false,
    ),
    AdaptiveTableColumn(
      id: 'name',
      title: t('الاسم', 'Name'),
      width: 190,
      pin: ColumnPin.start,
      isGroupable: false,
      isEditable: editable,
      cellValidator: (v) =>
          (v as String? ?? '').trim().isEmpty ? t('مطلوب', 'Required') : null,
    ),
    AdaptiveTableColumn(
      id: 'department',
      title: t('القسم', 'Department'),
      width: 170,
      isEditable: editable,
      editor: CellEditor.dropdown(departments),
    ),
    AdaptiveTableColumn(id: 'city', title: t('المدينة', 'City'), width: 150),
    AdaptiveTableColumn(
      id: 'salary',
      title: t('الراتب', 'Salary'),
      width: 150,
      alignment: TableColumnAlignment.end,
      isGroupable: false,
      isEditable: editable,
      valueFormatter: (v) => _money.format(v),
      // Footer total (live with filters; returned by the server in server mode).
      aggregate: TableAggregate.sum,
      cellValidator: (v) =>
          v is num && v < 0 ? t('قيمة سالبة', 'Must be positive') : null,
    ),
    AdaptiveTableColumn(
      id: 'hiredOn',
      title: t('تاريخ التعيين', 'Hired on'),
      width: 150,
      alignment: TableColumnAlignment.center,
      isGroupable: false,
      isEditable: editable,
      valueFormatter: (v) => _day.format(v as DateTime),
    ),
    AdaptiveTableColumn(
      id: 'active',
      title: t('نشط', 'Active'),
      width: 110,
      alignment: TableColumnAlignment.center,
      isEditable: editable,
      cellBuilder: (context, e) => Icon(
        e.active ? Icons.check_circle : Icons.cancel,
        size: 18,
        color: e.active ? theme.statusPositiveColor : theme.statusNegativeColor,
      ),
    ),
    AdaptiveTableColumn(
      id: 'actions',
      title: t('إجراءات', 'Actions'),
      width: 110,
      alignment: TableColumnAlignment.center,
      pin: ColumnPin.end,
      isSortable: false,
      isSearchable: false,
      isExportable: false,
      isFilterable: false,
      isResizable: false,
      isGroupable: false,
      cellBuilder: (context, e) => IconButton(
        tooltip: t('عرض', 'Open'),
        visualDensity: VisualDensity.compact,
        icon: Icon(Icons.open_in_new, size: 18, color: theme.accentColor),
        onPressed: () => ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('${e.id} · ${e.name}'))),
      ),
    ),
  ];
}

final employeeProviders = <String, dynamic Function(Employee)>{
  'id': (e) => e.id,
  'name': (e) => e.name,
  'department': (e) => e.department,
  'city': (e) => e.city,
  'salary': (e) => e.salary,
  'hiredOn': (e) => e.hiredOn,
  'active': (e) => e.active,
};

/// 2,000 employees in a full-height virtualized grid with frozen columns,
/// per-column filters, grouping, inline editing and permissions.
class EmployeesGridTab extends StatefulWidget {
  const EmployeesGridTab({super.key, required this.theme});
  final AdaptiveTableTheme theme;

  @override
  State<EmployeesGridTab> createState() => _EmployeesGridTabState();
}

class _EmployeesGridTabState extends State<EmployeesGridTab> {
  late List<Employee> _employees;
  bool _ready = false;
  bool _canEdit = true;
  TableDensity _density = TableDensity.standard;

  bool get _isArabic => Localizations.localeOf(context).languageCode == 'ar';
  String _t(String ar, String en) => _isArabic ? ar : en;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_ready) return;
    _ready = true;
    _employees = generateEmployees(2000, arabic: _isArabic);
  }

  bool _onEdit(Employee e, String column, dynamic value) {
    final updated = switch (column) {
      'name' => e.copyWith(name: value as String),
      'department' => e.copyWith(department: value as String),
      'salary' => e.copyWith(salary: (value as num?)?.toDouble() ?? 0),
      'hiredOn' => e.copyWith(hiredOn: value as DateTime),
      'active' => e.copyWith(active: value as bool),
      _ => e,
    };
    setState(() {
      _employees = [for (final x in _employees) x.id == e.id ? updated : x];
    });
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    final (densityIcon, densityLabel) = switch (_density) {
      TableDensity.compact => (Icons.density_small, _t('مضغوط', 'Compact')),
      TableDensity.standard => (Icons.density_medium, _t('عادي', 'Standard')),
      TableDensity.comfortable => (
        Icons.density_large,
        _t('مريح', 'Comfortable'),
      ),
    };
    return AdaptiveTableLayout<Employee>(
      title: _t('الموظفون', 'Employees'),
      subtitle: _t(
        '2000 صف · أعمدة مثبتة · فلترة لكل عمود · تعديل مباشر · إجماليات',
        '2,000 rows · frozen columns · column filters · inline editing · totals',
      ),
      titleIcon: Icon(Icons.badge_outlined, color: theme.accentColor),
      items: _employees,
      columns: employeeColumns(
        isArabic: _isArabic,
        theme: theme,
        editable: true,
      ),
      valueProviders: employeeProviders,
      // Edits replace rows with new instances: the id keeps them selected.
      rowKey: (e) => e.id,
      fillHeight: true,
      showPagination: false,
      showColumnFilters: true,
      showGroupingMenu: true,
      tristateSort: true,
      density: _density,
      groupHeaderBuilder: (context, g) => Text(
        '${_t('متوسط الراتب', 'Avg salary')}: '
        '${_money.format(g.rows.fold<double>(0, (s, e) => s + e.salary) / g.rows.length)}',
        style: theme.footerTextStyle,
      ),
      onCellEdited: _onEdit,
      canEditCell: (e, column) => _canEdit && e.active,
      rowColorBuilder: (e) =>
          e.active ? null : theme.statusNegativeColor.withValues(alpha: 0.05),
      mobileTitleColumnId: 'name',
      mobileSubtitleColumnId: 'department',
      theme: theme,
      toolbarActions: [
        IconButton(
          tooltip: '${_t('الكثافة', 'Density')}: $densityLabel',
          visualDensity: VisualDensity.compact,
          icon: Icon(
            densityIcon,
            size: 20,
            color: theme.effectiveToolbarIconColor,
          ),
          onPressed: () => setState(() {
            _density = TableDensity
                .values[(_density.index + 1) % TableDensity.values.length];
          }),
        ),
        Tooltip(
          message: _t('صلاحية التعديل', 'Edit permission'),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _canEdit ? Icons.lock_open : Icons.lock_outline,
                size: 18,
                color: theme.effectiveToolbarIconColor,
              ),
              Switch(
                value: _canEdit,
                activeThumbColor: theme.accentColor,
                onChanged: (v) => setState(() => _canEdit = v),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Server-side mode: a fake API with latency filters / sorts / paginates
/// 10,000 rows; the table only shows what the "server" returns.
class ServerDataTab extends StatefulWidget {
  const ServerDataTab({super.key, required this.theme});
  final AdaptiveTableTheme theme;

  @override
  State<ServerDataTab> createState() => _ServerDataTabState();
}

class _ServerDataTabState extends State<ServerDataTab> {
  AdaptiveTableDataSource<Employee>? _source;
  late List<Employee> _database;

  bool get _isArabic => Localizations.localeOf(context).languageCode == 'ar';
  String _t(String ar, String en) => _isArabic ? ar : en;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_source != null) return;
    _database = generateEmployees(10000, arabic: _isArabic);
    // Created once, not in build().
    _source = AdaptiveTableDataSource.fromCallback(_fakeApi);
  }

  /// Stand-in for an HTTP call such as
  /// `GET /employees?page=2&size=25&q=ali&sort=salary:desc`.
  Future<TableDataPage<Employee>> _fakeApi(TableStateModel query) async {
    await Future<void>.delayed(const Duration(milliseconds: 450));
    final result = const FilterItemsUseCase().apply<Employee>(
      items: _database,
      columns: [
        for (final c in employeeColumns(
          isArabic: _isArabic,
          theme: widget.theme,
        ))
          c.definition,
      ],
      state: query,
      valueProviders: employeeProviders,
    );
    return TableDataPage(
      items: result.paginated,
      totalCount: result.totalCount,
      // Totals over every matching row, not just this page.
      aggregates: {
        'salary': result.filteredAndSorted.fold<double>(
          0,
          (sum, e) => sum + e.salary,
        ),
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    return AdaptiveTableLayout<Employee>(
      title: _t('بيانات من السيرفر', 'Server-side data'),
      subtitle: _t(
        '10,000 صف · البحث والفرز والصفحات تتم على السيرفر',
        '10,000 rows · search, sort and paging run on the server',
      ),
      titleIcon: Icon(Icons.cloud_outlined, color: theme.accentColor),
      dataSource: _source,
      columns: employeeColumns(isArabic: _isArabic, theme: theme),
      valueProviders: employeeProviders,
      rowKey: (e) => e.id,
      fillHeight: true,
      pageSizes: const [25, 50, 100],
      initialPageSize: 25,
      showColumnFilters: true,
      showSelection: false,
      mobileTitleColumnId: 'name',
      mobileSubtitleColumnId: 'department',
      theme: theme,
    );
  }
}
