import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_table_layout/flutter_table_layout.dart';
import 'package:intl/intl.dart' hide TextDirection;

import 'demo_data.dart';

void main() {
  runApp(const ShowcaseApp());
}

enum DemoThemeStyle { modern, glassmorphic, gradient, cozy }

class ShowcaseApp extends StatefulWidget {
  const ShowcaseApp({
    super.key,
    this.initialLocale = const Locale('ar', 'YE'),
    this.initialThemeMode = ThemeMode.light,
    this.initialStyle = DemoThemeStyle.modern,
    this.initialTab = 0,
    this.fontFamily,
  });

  final Locale initialLocale;
  final ThemeMode initialThemeMode;
  final DemoThemeStyle initialStyle;
  final int initialTab;

  /// Only used by the screenshot generator.
  final String? fontFamily;

  @override
  State<ShowcaseApp> createState() => _ShowcaseAppState();
}

class _ShowcaseAppState extends State<ShowcaseApp> {
  late ThemeMode _themeMode = widget.initialThemeMode;
  late Locale _locale = widget.initialLocale;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Table Layout Showcase',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        fontFamily: widget.fontFamily,
        fontFamilyFallback: widget.fontFamily == null ? null : const ['Cairo'],
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          brightness: Brightness.dark,
          seedColor: Colors.blue,
        ),
        fontFamily: widget.fontFamily,
        fontFamilyFallback: widget.fontFamily == null ? null : const ['Cairo'],
      ),
      themeMode: _themeMode,
      locale: _locale,
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      supportedLocales: const [Locale('en', 'US'), Locale('ar', 'YE')],
      home: DashboardHome(
        // A new locale regenerates the demo data in that language.
        key: ValueKey(_locale.languageCode),
        themeMode: _themeMode,
        initialStyle: widget.initialStyle,
        initialTab: widget.initialTab,
        onToggleTheme: () => setState(() {
          _themeMode = _themeMode == ThemeMode.light
              ? ThemeMode.dark
              : ThemeMode.light;
        }),
        onToggleLocale: () => setState(() {
          _locale = _locale.languageCode == 'ar'
              ? const Locale('en', 'US')
              : const Locale('ar', 'YE');
        }),
      ),
    );
  }
}

class DashboardHome extends StatefulWidget {
  const DashboardHome({
    super.key,
    required this.themeMode,
    required this.onToggleTheme,
    required this.onToggleLocale,
    this.initialStyle = DemoThemeStyle.modern,
    this.initialTab = 0,
  });

  final ThemeMode themeMode;
  final VoidCallback onToggleTheme;
  final VoidCallback onToggleLocale;
  final DemoThemeStyle initialStyle;
  final int initialTab;

  @override
  State<DashboardHome> createState() => _DashboardHomeState();
}

class _DashboardHomeState extends State<DashboardHome>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController = TabController(
    length: 2,
    vsync: this,
    initialIndex: widget.initialTab,
  );
  late DemoThemeStyle _activeStyle = widget.initialStyle;

  final _transactionsController = AdaptiveTableController<AccountTransaction>();

  late List<AccountTransaction> _transactions;
  late List<Currency> _currencies;
  bool _dataReady = false;
  bool _isLoading = false;

  static final _money = NumberFormat('#,##0.00');
  static final _day = DateFormat('yyyy-MM-dd');

  bool get _isArabic => Localizations.localeOf(context).languageCode == 'ar';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_dataReady) return;
    _dataReady = true;
    _transactions = generateTransactions(arabic: _isArabic);
    _currencies = generateCurrencies(arabic: _isArabic);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _transactionsController.dispose();
    super.dispose();
  }

  AdaptiveTableTheme _resolveTheme(BuildContext context) {
    final isDark = widget.themeMode == ThemeMode.dark;
    return switch (_activeStyle) {
      DemoThemeStyle.glassmorphic => AdaptiveTableTheme.glassmorphic(
        context,
        isDark: isDark,
      ),
      DemoThemeStyle.gradient => AdaptiveTableTheme.gradient(
        context,
        isDark: isDark,
      ),
      DemoThemeStyle.cozy => AdaptiveTableTheme.cozy(context, isDark: isDark),
      DemoThemeStyle.modern => AdaptiveTableTheme.adaptive(context),
    };
  }

  String _t(String ar, String en) => _isArabic ? ar : en;

  @override
  Widget build(BuildContext context) {
    final isGlass = _activeStyle == DemoThemeStyle.glassmorphic;
    final isDark = widget.themeMode == ThemeMode.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(_t('لوحة تحكم الجداول التفاعلية', 'Adaptive Tables')),
        actions: [
          PopupMenuButton<DemoThemeStyle>(
            icon: const Icon(Icons.palette_outlined),
            tooltip: _t('ستايل الجدول', 'Table style'),
            initialValue: _activeStyle,
            onSelected: (style) => setState(() => _activeStyle = style),
            itemBuilder: (context) => [
              PopupMenuItem(
                value: DemoThemeStyle.modern,
                child: Text(_t('عصري (افتراضي)', 'Modern (default)')),
              ),
              PopupMenuItem(
                value: DemoThemeStyle.glassmorphic,
                child: Text(_t('زجاجي', 'Glassmorphism')),
              ),
              PopupMenuItem(
                value: DemoThemeStyle.gradient,
                child: Text(_t('متدرج', 'Gradient accents')),
              ),
              PopupMenuItem(
                value: DemoThemeStyle.cozy,
                child: Text(_t('مريح', 'Cozy spacing')),
              ),
            ],
          ),
          IconButton(
            tooltip: _t('الوضع الليلي', 'Dark mode'),
            icon: Icon(isDark ? Icons.light_mode : Icons.dark_mode),
            onPressed: widget.onToggleTheme,
          ),
          TextButton.icon(
            icon: const Icon(Icons.language),
            label: Text(_t('English', 'العربية')),
            onPressed: widget.onToggleLocale,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: _t('تفاصيل الحساب', 'Account details')),
            Tab(text: _t('إدارة العملات', 'Currencies')),
          ],
        ),
      ),
      body: DecoratedBox(
        // A colorful backdrop makes the glassmorphic blur visible.
        decoration: BoxDecoration(
          gradient: isGlass
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isDark
                      ? const [
                          Color(0xFF0F2027),
                          Color(0xFF203A43),
                          Color(0xFF2C5364),
                        ]
                      : const [
                          Color(0xFF89F7FE),
                          Color(0xFF66A6FF),
                          Color(0xFFB721FF),
                        ],
                )
              : null,
        ),
        child: TabBarView(
          controller: _tabController,
          children: [_buildTransactionsTab(), _buildCurrenciesTab()],
        ),
      ),
    );
  }

  // --- Tab 1: Account transactions ---

  Widget _buildTransactionsTab() {
    final theme = _resolveTheme(context);

    final columns = [
      AdaptiveTableColumn<AccountTransaction>(
        id: 'id',
        title: _t('م', 'No.'),
        width: 80,
        alignment: TableColumnAlignment.center,
      ),
      AdaptiveTableColumn<AccountTransaction>(
        id: 'date',
        title: _t('التاريخ', 'Date'),
        width: 120,
        alignment: TableColumnAlignment.center,
        valueFormatter: (v) => _day.format(v as DateTime),
      ),
      AdaptiveTableColumn<AccountTransaction>(
        id: 'details',
        title: _t('البيان', 'Details'),
        flex: 3,
      ),
      AdaptiveTableColumn<AccountTransaction>(
        id: 'amount',
        title: _t('المبلغ', 'Amount'),
        width: 120,
        alignment: TableColumnAlignment.end,
        valueFormatter: (v) => _money.format(v),
      ),
      AdaptiveTableColumn<AccountTransaction>(
        id: 'currency',
        title: _t('العملة', 'Currency'),
        width: 120,
        alignment: TableColumnAlignment.center,
        cellBuilder: (context, t) => _CurrencyChip(code: t.currency),
      ),
      AdaptiveTableColumn<AccountTransaction>(
        id: 'baseEquivalent',
        title: _t('المعادل (ر.ي)', 'Equivalent (YER)'),
        width: 150,
        alignment: TableColumnAlignment.end,
        valueFormatter: (v) => _money.format(v),
      ),
      AdaptiveTableColumn<AccountTransaction>(
        id: 'status',
        title: _t('النوع', 'Type'),
        fieldName: 'isDeposit',
        width: 140,
        alignment: TableColumnAlignment.center,
        cellBuilder: (context, t) => _TypeBadge(
          deposit: t.isDeposit,
          label: t.isDeposit ? _t('إيداع', 'Deposit') : _t('سحب', 'Withdrawal'),
          theme: theme,
        ),
      ),
    ];

    final providers = <String, dynamic Function(AccountTransaction)>{
      'id': (t) => t.id,
      'date': (t) => t.date,
      'details': (t) => t.details,
      'amount': (t) => t.amount,
      'currency': (t) => t.currency,
      'baseEquivalent': (t) => t.baseEquivalent,
      'status': (t) =>
          t.isDeposit ? _t('إيداع', 'Deposit') : _t('سحب', 'Withdrawal'),
    };

    return SingleChildScrollView(
      child: AdaptiveTableLayout<AccountTransaction>(
        controller: _transactionsController,
        title: _t('كشف الحساب', 'Account statement'),
        subtitle: _t(
          'حركة الحساب بعملات متعددة',
          'Multi-currency transactions',
        ),
        titleIcon: Icon(
          Icons.account_balance_wallet_outlined,
          color: theme.effectiveTitleTextStyle.color,
        ),
        items: _transactions,
        columns: columns,
        valueProviders: providers,
        dateProvider: (t) => t.date,
        customFilterMatcher: (t, filters) {
          final currency = filters['currency'];
          return currency == null || t.currency == currency;
        },
        customFilters: [
          _CurrencyFilter<AccountTransaction>(isArabic: _isArabic),
        ],
        initialSortColumnId: 'date',
        initialSortAscending: false,
        isLoading: _isLoading,
        theme: theme,
        mobileTitleColumnId: 'details',
        mobileSubtitleColumnId: 'baseEquivalent',
        expandedRowBuilder: (context, t) =>
            _TransactionDetails(transaction: t, isArabic: _isArabic),
        onRefreshPressed: _simulateRefresh,
        onAddNewPressed: () => _addTransaction(columns, theme),
        summaryBuilder: (context, rows) =>
            _TransactionsSummary(rows: rows, isArabic: _isArabic, theme: theme),
      ),
    );
  }

  Future<void> _simulateRefresh() async {
    setState(() => _isLoading = true);
    await Future<void>.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;
    setState(() {
      _transactions = generateTransactions(arabic: _isArabic);
      _isLoading = false;
    });
  }

  Future<void> _addTransaction(
    List<AdaptiveTableColumn<AccountTransaction>> columns,
    AdaptiveTableTheme theme,
  ) async {
    final values = await DynamicFormDialog.show(
      context,
      title: _t('إضافة عملية مالية', 'New transaction'),
      theme: theme,
      fields: DynamicFormField.detectFromColumns(
        columns,
        dropdownItems: {
          'currency': ['YER', 'SAR', 'USD'],
        },
        // Computed by the app, not typed by the user.
        excludeIds: {'id', 'baseEquivalent'},
      ),
    );
    if (values == null || !mounted) return;

    final nextId =
        _transactions.fold<int>(0, (m, t) => t.id > m ? t.id : m) + 1;
    final currency = values['currency'] as String? ?? 'YER';
    final amount = (values['amount'] as num?)?.toDouble() ?? 0;
    setState(() {
      _transactions = [
        ..._transactions,
        AccountTransaction(
          id: nextId,
          date: values['date'] as DateTime? ?? DateTime.now(),
          amount: amount,
          currency: currency,
          baseEquivalent: amount * rateOf(currency),
          details: values['details'] as String? ?? '',
          isDeposit: values['status'] == true,
        ),
      ];
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(_t('تمت إضافة العملية', 'Transaction added'))),
    );
  }

  // --- Tab 2: Currencies ---

  Widget _buildCurrenciesTab() {
    final theme = _resolveTheme(context);

    late final List<AdaptiveTableColumn<Currency>> columns;
    columns = [
      AdaptiveTableColumn<Currency>(
        id: 'id',
        title: _t('الرقم', 'ID'),
        width: 70,
        alignment: TableColumnAlignment.center,
      ),
      AdaptiveTableColumn<Currency>(
        id: 'name',
        title: _t('اسم العملة', 'Currency'),
        flex: 2,
      ),
      AdaptiveTableColumn<Currency>(
        id: 'code',
        title: _t('الرمز', 'Code'),
        width: 100,
        alignment: TableColumnAlignment.center,
        cellBuilder: (context, c) => _CurrencyChip(code: c.code),
      ),
      AdaptiveTableColumn<Currency>(
        id: 'symbol',
        title: _t('الاختصار', 'Symbol'),
        width: 110,
        alignment: TableColumnAlignment.center,
      ),
      AdaptiveTableColumn<Currency>(
        id: 'subunit',
        title: _t('الفكة', 'Subunit'),
        width: 120,
        alignment: TableColumnAlignment.center,
      ),
      AdaptiveTableColumn<Currency>(
        id: 'rate',
        title: _t('سعر الصرف', 'Rate'),
        width: 110,
        alignment: TableColumnAlignment.end,
        valueFormatter: (v) => _money.format(v),
      ),
      AdaptiveTableColumn<Currency>(
        id: 'minRate',
        title: _t('أقل سعر', 'Min rate'),
        width: 110,
        alignment: TableColumnAlignment.end,
        isVisible: false, // hidden by default, can be shown from the menu
        valueFormatter: (v) => _money.format(v),
      ),
      AdaptiveTableColumn<Currency>(
        id: 'maxRate',
        title: _t('أعلى سعر', 'Max rate'),
        width: 110,
        alignment: TableColumnAlignment.end,
        isVisible: false,
        valueFormatter: (v) => _money.format(v),
      ),
      AdaptiveTableColumn<Currency>(
        id: 'status',
        title: _t('الحالة', 'Active'),
        fieldName: 'isActive',
        width: 110,
        alignment: TableColumnAlignment.center,
        cellBuilder: (context, c) => Switch(
          value: c.isActive,
          activeThumbColor: theme.accentColor,
          onChanged: (val) => setState(() {
            _currencies = [
              for (final e in _currencies)
                e.id == c.id ? e.copyWith(isActive: val) : e,
            ];
          }),
        ),
      ),
      AdaptiveTableColumn<Currency>(
        id: 'actions',
        title: _t('الإجراءات', 'Actions'),
        width: 130,
        alignment: TableColumnAlignment.center,
        isSortable: false,
        isSearchable: false,
        isExportable: false,
        cellBuilder: (context, c) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: _t('تعديل', 'Edit'),
              visualDensity: VisualDensity.compact,
              constraints: const BoxConstraints.tightFor(width: 34, height: 34),
              padding: EdgeInsets.zero,
              icon: Icon(
                Icons.edit_outlined,
                size: 18,
                color: theme.accentColor,
              ),
              onPressed: () => _editCurrency(c, columns, theme),
            ),
            IconButton(
              tooltip: _t('حذف', 'Delete'),
              visualDensity: VisualDensity.compact,
              constraints: const BoxConstraints.tightFor(width: 34, height: 34),
              padding: EdgeInsets.zero,
              icon: Icon(
                Icons.delete_outline,
                size: 18,
                color: theme.statusNegativeColor,
              ),
              onPressed: () => setState(() {
                _currencies = _currencies.where((e) => e.id != c.id).toList();
              }),
            ),
          ],
        ),
      ),
    ];

    final providers = <String, dynamic Function(Currency)>{
      'id': (c) => c.id,
      'name': (c) => c.name,
      'code': (c) => c.code,
      'symbol': (c) => c.symbol,
      'subunit': (c) => c.subunit,
      'rate': (c) => c.rate,
      'minRate': (c) => c.minRate,
      'maxRate': (c) => c.maxRate,
      'status': (c) => c.isActive,
    };

    return SingleChildScrollView(
      child: AdaptiveTableLayout<Currency>(
        title: _t('العملات', 'Currencies'),
        subtitle: _t(
          'قائمة العملات وأسعار صرفها',
          'Currencies and exchange rates',
        ),
        titleIcon: Icon(
          Icons.currency_exchange,
          color: theme.effectiveTitleTextStyle.color,
        ),
        items: _currencies,
        columns: columns,
        valueProviders: providers,
        showSummary: false,
        showSelection: false,
        pageSizes: const [5, 10],
        rowColorBuilder: (c) => c.isActive
            ? null
            : theme.statusNegativeColor.withValues(alpha: 0.06),
        onRefreshPressed: () => setState(() {
          _currencies = generateCurrencies(arabic: _isArabic);
        }),
        onAddNewPressed: () => _addCurrency(columns, theme),
        theme: theme,
      ),
    );
  }

  Future<void> _addCurrency(
    List<AdaptiveTableColumn<Currency>> columns,
    AdaptiveTableTheme theme,
  ) async {
    final values = await DynamicFormDialog.show(
      context,
      title: _t('إضافة عملة', 'New currency'),
      theme: theme,
      fields: DynamicFormField.detectFromColumns(columns, excludeIds: {'id'}),
    );
    if (values == null || !mounted) return;
    final nextId = _currencies.fold<int>(0, (m, c) => c.id > m ? c.id : m) + 1;
    setState(() {
      _currencies = [..._currencies, _currencyFromForm(nextId, values, null)];
    });
  }

  Future<void> _editCurrency(
    Currency item,
    List<AdaptiveTableColumn<Currency>> columns,
    AdaptiveTableTheme theme,
  ) async {
    final values = await DynamicFormDialog.show(
      context,
      title: _t('تعديل العملة', 'Edit currency'),
      theme: theme,
      submitLabel: _t('حفظ', 'Save'),
      fields: DynamicFormField.detectFromColumns(
        columns,
        excludeIds: {'id'},
        initialValues: {
          'name': item.name,
          'code': item.code,
          'symbol': item.symbol,
          'subunit': item.subunit,
          'rate': item.rate,
          'minRate': item.minRate,
          'maxRate': item.maxRate,
          'status': item.isActive,
        },
      ),
    );
    if (values == null || !mounted) return;
    setState(() {
      _currencies = [
        for (final c in _currencies)
          c.id == item.id ? _currencyFromForm(item.id, values, item) : c,
      ];
    });
  }

  Currency _currencyFromForm(int id, Map<String, dynamic> v, Currency? old) {
    double num0(String key, double fallback) =>
        (v[key] as num?)?.toDouble() ?? fallback;
    return Currency(
      id: id,
      name: v['name'] as String? ?? old?.name ?? '',
      code: v['code'] as String? ?? old?.code ?? '',
      symbol: v['symbol'] as String? ?? old?.symbol ?? '',
      subunit: v['subunit'] as String? ?? old?.subunit ?? '',
      rate: num0('rate', old?.rate ?? 1),
      minRate: num0('minRate', old?.minRate ?? 1),
      maxRate: num0('maxRate', old?.maxRate ?? 1),
      isActive: v['status'] == true,
    );
  }
}

// --- Small presentational widgets ---

class _CurrencyChip extends StatelessWidget {
  const _CurrencyChip({required this.code});
  final String code;

  @override
  Widget build(BuildContext context) {
    final color = switch (code) {
      'USD' => Colors.green,
      'SAR' => Colors.teal,
      'EUR' => Colors.indigo,
      'AED' => Colors.deepOrange,
      _ => Colors.blue,
    };
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: dark ? 0.2 : 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        code,
        style: TextStyle(
          color: dark ? color.shade200 : color.shade700,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _TypeBadge extends StatelessWidget {
  const _TypeBadge({
    required this.deposit,
    required this.label,
    required this.theme,
  });
  final bool deposit;
  final String label;
  final AdaptiveTableTheme theme;

  @override
  Widget build(BuildContext context) {
    final color = deposit
        ? theme.statusPositiveColor
        : theme.statusNegativeColor;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          deposit ? Icons.south_west : Icons.north_east,
          size: 14,
          color: color,
        ),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            label,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ),
      ],
    );
  }
}

/// A custom filter widget: it reads the table cubit from the context.
class _CurrencyFilter<T> extends StatelessWidget {
  const _CurrencyFilter({required this.isArabic});
  final bool isArabic;

  @override
  Widget build(BuildContext context) {
    final cubit = context.watch<TableCubit<T>>();
    final current = cubit.tableState.customFilters['currency'] as String?;
    return SegmentedButton<String>(
      showSelectedIcon: false,
      style: const ButtonStyle(visualDensity: VisualDensity.compact),
      segments: [
        ButtonSegment(value: 'all', label: Text(isArabic ? 'الكل' : 'All')),
        const ButtonSegment(value: 'YER', label: Text('YER')),
        const ButtonSegment(value: 'SAR', label: Text('SAR')),
        const ButtonSegment(value: 'USD', label: Text('USD')),
      ],
      selected: {current ?? 'all'},
      onSelectionChanged: (s) =>
          cubit.setCustomFilter('currency', s.first == 'all' ? null : s.first),
    );
  }
}

class _TransactionsSummary extends StatelessWidget {
  const _TransactionsSummary({
    required this.rows,
    required this.isArabic,
    required this.theme,
  });
  final List<AccountTransaction> rows;
  final bool isArabic;
  final AdaptiveTableTheme theme;

  @override
  Widget build(BuildContext context) {
    final money = NumberFormat('#,##0.00');
    var deposits = 0.0;
    var withdrawals = 0.0;
    for (final r in rows) {
      if (r.isDeposit) {
        deposits += r.baseEquivalent;
      } else {
        withdrawals += r.baseEquivalent;
      }
    }
    final balance = deposits - withdrawals;
    TextStyle style(Color c) =>
        TextStyle(fontWeight: FontWeight.bold, color: c, fontSize: 13);

    return Wrap(
      spacing: 24,
      runSpacing: 6,
      alignment: WrapAlignment.spaceBetween,
      children: [
        Text(
          isArabic
              ? 'عدد العمليات: ${rows.length}'
              : 'Transactions: ${rows.length}',
          style: style(theme.rowTextStyle.color ?? Colors.black87),
        ),
        Text(
          '${isArabic ? 'له' : 'Deposits'}: ${money.format(deposits)}',
          style: style(theme.statusPositiveColor),
        ),
        Text(
          '${isArabic ? 'عليه' : 'Withdrawals'}: ${money.format(withdrawals)}',
          style: style(theme.statusNegativeColor),
        ),
        Text(
          '${isArabic ? 'الرصيد' : 'Balance'}: ${money.format(balance)}',
          style: style(theme.accentColor),
        ),
      ],
    );
  }
}

class _TransactionDetails extends StatelessWidget {
  const _TransactionDetails({
    required this.transaction,
    required this.isArabic,
  });
  final AccountTransaction transaction;
  final bool isArabic;

  @override
  Widget build(BuildContext context) {
    final t = transaction;
    final rate = rateOf(t.currency);
    return Wrap(
      spacing: 32,
      runSpacing: 8,
      children: [
        _kv(
          isArabic ? 'رقم السند' : 'Voucher',
          'TX-${t.id.toString().padLeft(5, '0')}',
        ),
        _kv(isArabic ? 'سعر الصرف' : 'Exchange rate', rate.toStringAsFixed(2)),
        _kv(isArabic ? 'البيان' : 'Details', t.details),
      ],
    );
  }

  Widget _kv(String k, String v) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(k, style: const TextStyle(fontSize: 11, color: Colors.grey)),
      const SizedBox(height: 2),
      Text(v, style: const TextStyle(fontWeight: FontWeight.w600)),
    ],
  );
}
