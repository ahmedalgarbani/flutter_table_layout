import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart';
import 'package:flutter_table_layout/flutter_table_layout.dart';

void main() {
  runApp(const ShowcaseApp());
}

class ShowcaseApp extends StatefulWidget {
  const ShowcaseApp({super.key});

  @override
  State<ShowcaseApp> createState() => _ShowcaseAppState();
}

class _ShowcaseAppState extends State<ShowcaseApp> {
  ThemeMode _themeMode = ThemeMode.light;
  Locale _locale = const Locale(
    'ar',
    'YE',
  ); // Default to Arabic RTL as in images

  void _toggleTheme() {
    setState(() {
      _themeMode = _themeMode == ThemeMode.light
          ? ThemeMode.dark
          : ThemeMode.light;
    });
  }

  void _toggleLocale() {
    setState(() {
      _locale = _locale.languageCode == 'ar'
          ? const Locale('en', 'US')
          : const Locale('ar', 'YE');
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Table Layout Showcase',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          brightness: Brightness.dark,
          seedColor: Colors.blue,
        ),
      ),
      themeMode: _themeMode,
      locale: _locale,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en', 'US'), Locale('ar', 'YE')],
      home: DashboardHome(
        themeMode: _themeMode,
        onToggleTheme: _toggleTheme,
        onToggleLocale: _toggleLocale,
      ),
    );
  }
}

class DashboardHome extends StatefulWidget {
  final ThemeMode themeMode;
  final VoidCallback onToggleTheme;
  final VoidCallback onToggleLocale;

  const DashboardHome({
    super.key,
    required this.themeMode,
    required this.onToggleTheme,
    required this.onToggleLocale,
  });

  @override
  State<DashboardHome> createState() => _DashboardHomeState();
}

class _DashboardHomeState extends State<DashboardHome>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // --- Mock Datasets ---
  late List<AccountTransaction> _transactions;
  late List<Currency> _currencies;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _transactions = _generateTransactions();
    _currencies = _generateCurrencies();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isRtl = Directionality.of(context) == TextDirection.RTL;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isRtl ? 'لوحة تحكم الجداول التفاعلية' : 'Adaptive Tables Dashboard',
        ),
        actions: [
          IconButton(
            icon: Icon(
              widget.themeMode == ThemeMode.light
                  ? Icons.dark_mode
                  : Icons.light_mode,
            ),
            onPressed: widget.onToggleTheme,
          ),
          TextButton.icon(
            icon: const Icon(Icons.language),
            label: Text(isRtl ? 'English' : 'العربية'),
            onPressed: widget.onToggleLocale,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: isRtl ? 'تفاصيل الحساب' : 'Account Details'),
            Tab(text: isRtl ? 'إدارة العملات' : 'Currencies Grid'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildAccountDetailsTab(isRtl), _buildCurrenciesTab(isRtl)],
      ),
    );
  }

  // --- View: Account Details (Image 1 Layout) ---

  Widget _buildAccountDetailsTab(bool isRtl) {
    final textTheme = Theme.of(context).textTheme;

    // Define table columns
    final tableColumns = [
      AdaptiveTableColumn<AccountTransaction>(
        id: 'id',
        title: isRtl ? '# م' : 'No.',
        fieldName: 'id',
        width: 60,
        alignment: TableColumnAlignment.center,
      ),
      AdaptiveTableColumn<AccountTransaction>(
        id: 'date',
        title: isRtl ? 'التاريخ' : 'Date',
        fieldName: 'date',
        width: 120,
        alignment: TableColumnAlignment.center,
        cellBuilder: (context, item) => Text(
          DateFormat('yyyy-MM-dd').format(item.date),
          style: const TextStyle(fontSize: 13),
        ),
      ),
      AdaptiveTableColumn<AccountTransaction>(
        id: 'amount',
        title: isRtl ? 'المبلغ' : 'Amount',
        fieldName: 'amount',
        width: 100,
        alignment: TableColumnAlignment.end,
        cellBuilder: (context, item) => Text(
          NumberFormat('#,##0.00').format(item.amount),
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
      ),
      AdaptiveTableColumn<AccountTransaction>(
        id: 'currency',
        title: isRtl ? 'العملة' : 'Currency',
        fieldName: 'currency',
        width: 80,
        alignment: TableColumnAlignment.center,
        cellBuilder: (context, item) => Text(
          item.currency,
          style: const TextStyle(
            color: Colors.teal,
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
      ),
      AdaptiveTableColumn<AccountTransaction>(
        id: 'baseEquivalent',
        title: isRtl ? 'ما يعادل العملة الأساسية' : 'Equivalent Base',
        fieldName: 'baseEquivalent',
        width: 150,
        alignment: TableColumnAlignment.end,
        cellBuilder: (context, item) => Text(
          NumberFormat('#,##0.00').format(item.baseEquivalent),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      AdaptiveTableColumn<AccountTransaction>(
        id: 'details',
        title: isRtl ? 'التفاصيل' : 'Details',
        fieldName: 'details',
        flex: 2,
        alignment: TableColumnAlignment.start,
        cellBuilder: (context, item) => Text(
          item.details,
          style: const TextStyle(fontSize: 13),
          overflow: TextOverflow.ellipsis,
        ),
      ),
      AdaptiveTableColumn<AccountTransaction>(
        id: 'status',
        title: isRtl ? 'الحالة' : 'Status',
        fieldName: 'isDeposit',
        width: 80,
        alignment: TableColumnAlignment.center,
        cellBuilder: (context, item) {
          return Icon(
            item.isDeposit ? Icons.arrow_upward : Icons.arrow_downward,
            color: item.isDeposit ? Colors.green.shade700 : Colors.red.shade700,
            size: 20,
          );
        },
      ),
    ];

    // Extraction map for search/sort/exports
    final providers = <String, dynamic Function(AccountTransaction)>{
      'id': (t) => t.id,
      'date': (t) => t.date,
      'amount': (t) => t.amount,
      'currency': (t) => t.currency,
      'baseEquivalent': (t) => t.baseEquivalent,
      'details': (t) => t.details,
      'status': (t) => t.isDeposit ? 'Deposit' : 'Withdrawal',
    };

    return SingleChildScrollView(
      child: Column(
        children: [
          AdaptiveTableLayout<AccountTransaction>(
            title: isRtl ? 'تفاصيل الحساب' : 'Account Details',
            subtitle: isRtl
                ? 'كشف حركة حساب العملات والمدفوعات'
                : 'Statement of multi-currency transactions',
            titleIcon: Icon(
              Icons.account_balance_wallet,
              color: Colors.blue.shade800,
            ),
            items: _transactions,
            columns: tableColumns,
            valueProviders: providers,
            dateProvider: (item) => item.date,
            showSelection: false,
            searchHint: isRtl ? 'البحث عن عملية...' : 'Search transaction...',
            dateFromLabel: isRtl ? 'من تاريخ *' : 'From Date *',
            dateToLabel: isRtl ? 'إلى تاريخ *' : 'To Date *',
            queryButtonLabel: isRtl ? 'إستعلام' : 'Query',
            onQueryPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    isRtl
                        ? 'تم تطبيق من تصفية التاريخ'
                        : 'Date filter queried successfully!',
                  ),
                  duration: const Duration(seconds: 1),
                ),
              );
            },
            onRefreshPressed: () {
              setState(() {
                _transactions = _generateTransactions();
              });
            },
            theme: widget.themeMode == ThemeMode.light
                ? AdaptiveTableTheme.light(context)
                : AdaptiveTableTheme.dark(context),
            // Custom summary aggregate row (Image 1 Bottom banner)
            summaryBuilder: (context, visibleItems) {
              final count = visibleItems.length;
              double totalDeposit = 0;
              double totalWithdraw = 0;

              for (final item in visibleItems) {
                if (item.isDeposit) {
                  totalDeposit += item.amount;
                } else {
                  totalWithdraw += item.amount;
                }
              }

              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    isRtl ? '# العدد: $count' : '# Count: $count',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  Wrap(
                    spacing: 16,
                    children: [
                      Text(
                        isRtl
                            ? 'إجمالي العمليات (YER): له: ${NumberFormat('#,##0.00').format(totalDeposit)}'
                            : 'Operations YER: Deposit: ${NumberFormat('#,##0.00').format(totalDeposit)}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.green.shade700,
                          fontSize: 13,
                        ),
                      ),
                      Text(
                        isRtl
                            ? 'عليه: ${NumberFormat('#,##0.00').format(totalWithdraw)}'
                            : 'Withdraw: ${NumberFormat('#,##0.00').format(totalWithdraw)}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.red.shade700,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  // --- View: Currencies Grid (Image 2 Layout) ---

  Widget _buildCurrenciesTab(bool isRtl) {
    // Define columns
    final tableColumns = [
      AdaptiveTableColumn<Currency>(
        id: 'id',
        title: isRtl ? 'الرقم' : 'ID',
        fieldName: 'id',
        width: 60,
        alignment: TableColumnAlignment.center,
      ),
      AdaptiveTableColumn<Currency>(
        id: 'name',
        title: isRtl ? 'اسم العملة' : 'Currency Name',
        fieldName: 'name',
        flex: 2,
        alignment: TableColumnAlignment.start,
      ),
      AdaptiveTableColumn<Currency>(
        id: 'code',
        title: isRtl ? 'رمز العملة' : 'Symbol',
        fieldName: 'code',
        width: 100,
        alignment: TableColumnAlignment.center,
        cellBuilder: (context, item) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            item.code,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.blue,
              fontSize: 12,
            ),
          ),
        ),
      ),
      AdaptiveTableColumn<Currency>(
        id: 'symbol',
        title: isRtl ? 'اختصار العملة' : 'Abbr.',
        fieldName: 'symbol',
        width: 80,
        alignment: TableColumnAlignment.center,
      ),
      AdaptiveTableColumn<Currency>(
        id: 'subunit',
        title: isRtl ? 'فكة العملة' : 'Subunit',
        fieldName: 'subunit',
        width: 100,
        alignment: TableColumnAlignment.center,
      ),
      AdaptiveTableColumn<Currency>(
        id: 'rate',
        title: isRtl ? 'سعر الصرف' : 'Rate',
        fieldName: 'rate',
        width: 110,
        alignment: TableColumnAlignment.end,
        cellBuilder: (context, item) => Text(
          NumberFormat('#,##0.00').format(item.rate),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      AdaptiveTableColumn<Currency>(
        id: 'minRate',
        title: isRtl ? 'اقل سعر' : 'Min Rate',
        fieldName: 'minRate',
        width: 110,
        alignment: TableColumnAlignment.end,
        cellBuilder: (context, item) =>
            Text(NumberFormat('#,##0.00').format(item.minRate)),
      ),
      AdaptiveTableColumn<Currency>(
        id: 'maxRate',
        title: isRtl ? 'اعلى سعر' : 'Max Rate',
        fieldName: 'maxRate',
        width: 110,
        alignment: TableColumnAlignment.end,
        cellBuilder: (context, item) =>
            Text(NumberFormat('#,##0.00').format(item.maxRate)),
      ),
      AdaptiveTableColumn<Currency>(
        id: 'status',
        title: isRtl ? 'الحالة' : 'Status',
        fieldName: 'isActive',
        width: 90,
        alignment: TableColumnAlignment.center,
        cellBuilder: (context, item) {
          return Switch(
            value: item.isActive,
            activeThumbColor: Colors.teal.shade400,
            onChanged: (val) {
              setState(() {
                item.isActive = val;
              });
            },
          );
        },
      ),
      AdaptiveTableColumn<Currency>(
        id: 'actions',
        title: isRtl ? 'الاجراءات' : 'Actions',
        fieldName: 'actions',
        width: 100,
        alignment: TableColumnAlignment.center,
        cellBuilder: (context, item) {
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.edit, size: 18, color: Colors.blue),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () => _editCurrency(item),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.delete, size: 18, color: Colors.red),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () => _deleteCurrency(item),
              ),
            ],
          );
        },
      ),
    ];

    // Data extractor map
    final providers = <String, dynamic Function(Currency)>{
      'id': (c) => c.id,
      'name': (c) => c.name,
      'code': (c) => c.code,
      'symbol': (c) => c.symbol,
      'subunit': (c) => c.subunit,
      'rate': (c) => c.rate,
      'minRate': (c) => c.minRate,
      'maxRate': (c) => c.maxRate,
      'status': (c) => c.isActive ? 'Active' : 'Inactive',
    };

    return SingleChildScrollView(
      child: Column(
        children: [
          AdaptiveTableLayout<Currency>(
            title: isRtl ? 'العملات' : 'Currencies',
            subtitle: isRtl
                ? 'قائمة العملات المتاحة وأسعار صرفها'
                : 'List of currencies and their exchange rates',
            titleIcon: Icon(Icons.monetization_on, color: Colors.teal.shade700),
            items: _currencies,
            columns: tableColumns,
            valueProviders: providers,
            showSummary: false,
            searchHint: isRtl ? 'بحث...' : 'Search currency...',
            onRefreshPressed: () {
              setState(() {
                _currencies = _generateCurrencies();
              });
            },
            onAddNewPressed: () {
              _addNewCurrency();
            },
            theme: widget.themeMode == ThemeMode.light
                ? AdaptiveTableTheme.light(context)
                : AdaptiveTableTheme.dark(context),
          ),
        ],
      ),
    );
  }

  // --- Action Handlers ---

  void _editCurrency(Currency item) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Edit currency: ${item.name}')));
  }

  void _deleteCurrency(Currency item) {
    setState(() {
      _currencies.removeWhere((c) => c.id == item.id);
    });
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Deleted currency: ${item.name}')));
  }

  void _addNewCurrency() {
    final nextId =
        _currencies.map((c) => c.id).fold(0, (max, id) => id > max ? id : max) +
        1;
    setState(() {
      _currencies.add(
        Currency(
          id: nextId,
          name: 'New Currency $nextId',
          code: 'NEW',
          symbol: 'N',
          subunit: 'cent',
          rate: 1.0,
          minRate: 1.0,
          maxRate: 1.0,
          isActive: true,
        ),
      );
    });
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Added new currency ID: $nextId')));
  }

  // --- Data Generators ---

  List<AccountTransaction> _generateTransactions() {
    return [
      AccountTransaction(
        id: 1,
        date: DateTime(2026, 4, 22),
        amount: 5300.0,
        currency: 'YER',
        baseEquivalent: 5300.0,
        details: 'مقابل خدمات استشارية',
        isDeposit: true,
      ),
      AccountTransaction(
        id: 2,
        date: DateTime(2026, 4, 25),
        amount: 4580.0,
        currency: 'YER',
        baseEquivalent: 4580.0,
        details: 'تجربه',
        isDeposit: true,
      ),
      AccountTransaction(
        id: 3,
        date: DateTime(2026, 4, 29),
        amount: 1.0,
        currency: 'YER',
        baseEquivalent: 1.0,
        details: 'سيبسي',
        isDeposit: true,
      ),
      AccountTransaction(
        id: 4,
        date: DateTime(2026, 4, 29),
        amount: 3200.0,
        currency: 'YER',
        baseEquivalent: 3200.0,
        details: 'للل',
        isDeposit: true,
      ),
      AccountTransaction(
        id: 5,
        date: DateTime(2026, 5, 4),
        amount: 22000.0,
        currency: 'YER',
        baseEquivalent: 22000.0,
        details: 'سند صرف من فاتورة مشتريات رقم 4',
        isDeposit: false,
      ),
      AccountTransaction(
        id: 6,
        date: DateTime(2026, 5, 4),
        amount: 22000.0,
        currency: 'YER',
        baseEquivalent: 22000.0,
        details: 'مقابل فاتورة مشتريات',
        isDeposit: true,
      ),
      AccountTransaction(
        id: 7,
        date: DateTime(2026, 5, 10),
        amount: 15000.0,
        currency: 'YER',
        baseEquivalent: 15000.0,
        details: 'دفعة سداد حساب العميل',
        isDeposit: false,
      ),
      AccountTransaction(
        id: 8,
        date: DateTime(2026, 5, 15),
        amount: 30000.0,
        currency: 'YER',
        baseEquivalent: 30000.0,
        details: 'إيداع نقدي مباشر',
        isDeposit: true,
      ),
    ];
  }

  List<Currency> _generateCurrencies() {
    return [
      Currency(
        id: 4,
        name: 'ريال يمني',
        code: 'YER',
        symbol: 'ر.ي',
        subunit: 'فلس',
        rate: 1.0,
        minRate: 1.0,
        maxRate: 1.0,
        isActive: true,
      ),
      Currency(
        id: 5,
        name: 'ريال سعودي',
        code: 'SAR',
        symbol: 'ر.س',
        subunit: 'هللة',
        rate: 0.0,
        minRate: 0.0,
        maxRate: 0.0,
        isActive: true,
      ),
      Currency(
        id: 6,
        name: 'دولار أمريكي',
        code: 'USD',
        symbol: '\$',
        subunit: 'سنت',
        rate: 0.0,
        minRate: 0.0,
        maxRate: 0.0,
        isActive: true,
      ),
      Currency(
        id: 80,
        name: 'sdfsd',
        code: 'sdfs',
        symbol: 'sdfsd',
        subunit: 'sdfds',
        rate: 500.0,
        minRate: 520.0,
        maxRate: 530.0,
        isActive: true,
      ),
    ];
  }
}

class AccountTransaction {
  final int id;
  final DateTime date;
  final double amount;
  final String currency;
  final double baseEquivalent;
  final String details;
  final bool isDeposit;

  AccountTransaction({
    required this.id,
    required this.date,
    required this.amount,
    required this.currency,
    required this.baseEquivalent,
    required this.details,
    required this.isDeposit,
  });
}

class Currency {
  final int id;
  final String name;
  final String code;
  final String symbol;
  final String subunit;
  final double rate;
  final double minRate;
  final double maxRate;
  bool isActive;

  Currency({
    required this.id,
    required this.name,
    required this.code,
    required this.symbol,
    required this.subunit,
    required this.rate,
    required this.minRate,
    required this.maxRate,
    required this.isActive,
  });
}
