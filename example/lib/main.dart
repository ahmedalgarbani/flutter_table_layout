import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' hide TextDirection;
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
  Locale _locale = const Locale('ar', 'YE'); // Default to Arabic RTL as in screenshots

  void _toggleTheme() {
    setState(() {
      _themeMode = _themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    });
  }

  void _toggleLocale() {
    setState(() {
      _locale = _locale.languageCode == 'ar' ? const Locale('en', 'US') : const Locale('ar', 'YE');
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

enum DemoThemeStyle {
  modern,
  glassmorphic,
  gradient,
  cozy,
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

class _DashboardHomeState extends State<DashboardHome> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  DemoThemeStyle _activeStyle = DemoThemeStyle.modern;

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

  AdaptiveTableTheme _resolveTheme(BuildContext context) {
    final isDark = widget.themeMode == ThemeMode.dark;
    return switch (_activeStyle) {
      DemoThemeStyle.glassmorphic => AdaptiveTableTheme.glassmorphic(context, isDark: isDark),
      DemoThemeStyle.gradient => AdaptiveTableTheme.gradient(context, isDark: isDark),
      DemoThemeStyle.cozy => AdaptiveTableTheme.cozy(context, isDark: isDark),
      _ => isDark ? AdaptiveTableTheme.dark(context) : AdaptiveTableTheme.light(context),
    };
  }

  @override
  Widget build(BuildContext context) {
    final isRtl = Directionality.of(context) == TextDirection.rtl;

    return Scaffold(
      appBar: AppBar(
        title: Text(isRtl ? 'لوحة تحكم الجداول التفاعلية' : 'Adaptive Tables Dashboard'),
        actions: [
          // Theme preset selector
          PopupMenuButton<DemoThemeStyle>(
            icon: const Icon(Icons.palette_outlined),
            tooltip: isRtl ? 'ستايل الجدول' : 'Table Style',
            onSelected: (style) {
              setState(() {
                _activeStyle = style;
              });
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: DemoThemeStyle.modern,
                child: Text(isRtl ? 'ستايل عصري (افتراضي)' : 'Modern Style (Default)'),
              ),
              PopupMenuItem(
                value: DemoThemeStyle.glassmorphic,
                child: Text(isRtl ? 'تأثير زجاجي (Glassmorphism)' : 'Glassmorphism'),
              ),
              PopupMenuItem(
                value: DemoThemeStyle.gradient,
                child: Text(isRtl ? 'ستايل متدرج (Gradients)' : 'Gradient Accents'),
              ),
              PopupMenuItem(
                value: DemoThemeStyle.cozy,
                child: Text(isRtl ? 'ستايل مريح (Cozy Spaced)' : 'Cozy Spacing'),
              ),
            ],
          ),
          IconButton(
            icon: Icon(widget.themeMode == ThemeMode.light ? Icons.dark_mode : Icons.light_mode),
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
        children: [
          _buildAccountDetailsTab(isRtl),
          _buildCurrenciesTab(isRtl),
        ],
      ),
    );
  }

  // --- View: Account Details ---

  Widget _buildAccountDetailsTab(bool isRtl) {
    final currentTheme = _resolveTheme(context);

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
            subtitle: isRtl ? 'كشف حركة حساب العملات والمدفوعات' : 'Statement of multi-currency transactions',
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
                  content: Text(isRtl ? 'تم تطبيق تصفية التاريخ' : 'Date filter queried successfully!'),
                  duration: const Duration(seconds: 1),
                ),
              );
            },
            onRefreshPressed: () {
              setState(() {
                _transactions = _generateTransactions();
              });
            },
            onAddNewPressed: () => _addNewTransaction(isRtl, tableColumns, currentTheme),
            theme: currentTheme,
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
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  Wrap(
                    spacing: 16,
                    children: [
                      Text(
                        isRtl
                            ? 'له (YER): ${NumberFormat('#,##0.00').format(totalDeposit)}'
                            : 'Deposit (YER): ${NumberFormat('#,##0.00').format(totalDeposit)}',
                        style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green.shade700, fontSize: 13),
                      ),
                      Text(
                        isRtl
                            ? 'عليه (YER): ${NumberFormat('#,##0.00').format(totalWithdraw)}'
                            : 'Withdraw (YER): ${NumberFormat('#,##0.00').format(totalWithdraw)}',
                        style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red.shade700, fontSize: 13),
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

  // --- View: Currencies Grid ---

  Widget _buildCurrenciesTab(bool isRtl) {
    final currentTheme = _resolveTheme(context);

    // Define columns
    late final List<AdaptiveTableColumn<Currency>> tableColumns;
    tableColumns = [
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
            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue, fontSize: 12),
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
        cellBuilder: (context, item) => Text(NumberFormat('#,##0.00').format(item.minRate)),
      ),
      AdaptiveTableColumn<Currency>(
        id: 'maxRate',
        title: isRtl ? 'اعلى سعر' : 'Max Rate',
        fieldName: 'maxRate',
        width: 110,
        alignment: TableColumnAlignment.end,
        cellBuilder: (context, item) => Text(NumberFormat('#,##0.00').format(item.maxRate)),
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
                onPressed: () => _editCurrency(isRtl, item, tableColumns, currentTheme),
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
            subtitle: isRtl ? 'قائمة العملات المتاحة وأسعار صرفها' : 'List of currencies and their exchange rates',
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
            onAddNewPressed: () => _addNewCurrency(isRtl, tableColumns, currentTheme),
            theme: currentTheme,
          ),
        ],
      ),
    );
  }

  // --- Action Handlers (Dynamic Forms) ---

  void _addNewTransaction(
    bool isRtl,
    List<AdaptiveTableColumn<AccountTransaction>> columns,
    AdaptiveTableTheme theme,
  ) {
    // Generate dynamic form schema
    final fields = DynamicFormField.detectFromColumns(
      columns,
      dropdownItems: {
        'currency': ['YER', 'SAR', 'USD'],
      },
    );

    DynamicFormDialog.show(
      context,
      title: isRtl ? 'إضافة عملية مالية جديدة' : 'Add New Transaction',
      fields: fields,
      theme: theme,
      submitLabel: isRtl ? 'إرسال' : 'Send',
      cancelLabel: isRtl ? 'إلغاء' : 'Cancel',
      onSubmitted: (values) {
        final nextId = _transactions.map((t) => t.id).fold(0, (max, id) => id > max ? id : max) + 1;
        setState(() {
          _transactions.add(
            AccountTransaction(
              id: nextId,
              date: values['date'] as DateTime? ?? DateTime.now(),
              amount: (values['amount'] as num?)?.toDouble() ?? 0.0,
              currency: values['currency']?.toString() ?? 'YER',
              baseEquivalent: (values['baseEquivalent'] as num?)?.toDouble() ?? 0.0,
              details: values['details']?.toString() ?? '',
              isDeposit: values['status'] == true,
            ),
          );
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(isRtl ? 'تم إضافة العملية بنجاح!' : 'Transaction added successfully!')),
        );
      },
    );
  }

  void _addNewCurrency(
    bool isRtl,
    List<AdaptiveTableColumn<Currency>> columns,
    AdaptiveTableTheme theme,
  ) {
    final fields = DynamicFormField.detectFromColumns(
      columns,
      dropdownItems: {
        'subunit': ['فلوس', 'هللة', 'سنت'],
      },
    );

    DynamicFormDialog.show(
      context,
      title: isRtl ? 'إضافة عملة جديدة' : 'Add New Currency',
      fields: fields,
      theme: theme,
      submitLabel: isRtl ? 'إرسال' : 'Send',
      cancelLabel: isRtl ? 'إلغاء' : 'Cancel',
      onSubmitted: (values) {
        final nextId = _currencies.map((c) => c.id).fold(0, (max, id) => id > max ? id : max) + 1;
        setState(() {
          _currencies.add(
            Currency(
              id: nextId,
              name: values['name']?.toString() ?? 'New Currency',
              code: values['code']?.toString() ?? 'NEW',
              symbol: values['symbol']?.toString() ?? 'N',
              subunit: values['subunit']?.toString() ?? 'cent',
              rate: (values['rate'] as num?)?.toDouble() ?? 1.0,
              minRate: (values['minRate'] as num?)?.toDouble() ?? 1.0,
              maxRate: (values['maxRate'] as num?)?.toDouble() ?? 1.0,
              isActive: values['status'] == true,
            ),
          );
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(isRtl ? 'تم إضافة العملة بنجاح!' : 'Currency added successfully!')),
        );
      },
    );
  }

  void _editCurrency(
    bool isRtl,
    Currency item,
    List<AdaptiveTableColumn<Currency>> columns,
    AdaptiveTableTheme theme,
  ) {
    // Fill initial values for editing
    final fields = DynamicFormField.detectFromColumns(
      columns,
      dropdownItems: {
        'subunit': ['فلوس', 'هللة', 'سنت'],
      },
      initialValues: {
        'id': item.id,
        'name': item.name,
        'code': item.code,
        'symbol': item.symbol,
        'subunit': item.subunit,
        'rate': item.rate,
        'minRate': item.minRate,
        'maxRate': item.maxRate,
        'status': item.isActive,
      },
    );

    DynamicFormDialog.show(
      context,
      title: isRtl ? 'تعديل العملة' : 'Edit Currency',
      fields: fields,
      theme: theme,
      submitLabel: isRtl ? 'حفظ' : 'Save',
      cancelLabel: isRtl ? 'إلغاء' : 'Cancel',
      onSubmitted: (values) {
        setState(() {
          final index = _currencies.indexWhere((c) => c.id == item.id);
          if (index != -1) {
            _currencies[index] = Currency(
              id: item.id,
              name: values['name']?.toString() ?? item.name,
              code: values['code']?.toString() ?? item.code,
              symbol: values['symbol']?.toString() ?? item.symbol,
              subunit: values['subunit']?.toString() ?? item.subunit,
              rate: (values['rate'] as num?)?.toDouble() ?? item.rate,
              minRate: (values['minRate'] as num?)?.toDouble() ?? item.minRate,
              maxRate: (values['maxRate'] as num?)?.toDouble() ?? item.maxRate,
              isActive: values['status'] == true,
            );
          }
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(isRtl ? 'تم حفظ التعديلات!' : 'Currency updated successfully!')),
        );
      },
    );
  }

  void _deleteCurrency(Currency item) {
    setState(() {
      _currencies.removeWhere((c) => c.id == item.id);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Deleted currency: ${item.name}')),
    );
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
        subunit: 'فلوس',
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
        rate: 250.0,
        minRate: 248.0,
        maxRate: 252.0,
        isActive: true,
      ),
      Currency(
        id: 6,
        name: 'دولار أمريكي',
        code: 'USD',
        symbol: '\$',
        subunit: 'سنت',
        rate: 930.0,
        minRate: 928.0,
        maxRate: 935.0,
        isActive: true,
      ),
      Currency(
        id: 80,
        name: 'يورو أوروبي',
        code: 'EUR',
        symbol: '€',
        subunit: 'سنت',
        rate: 1010.0,
        minRate: 1000.0,
        maxRate: 1020.0,
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
