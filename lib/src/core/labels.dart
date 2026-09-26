import 'package:flutter/widgets.dart';

/// Every user-facing string rendered by the table, the dynamic forms, and the
/// exporters.
///
/// Built-in translations: [AdaptiveTableLabels.en] and [AdaptiveTableLabels.ar].
/// [AdaptiveTableLabels.of] picks one from the ambient locale; pass your own
/// instance (or use [copyWith]) for other languages.
class AdaptiveTableLabels {
  final String search;
  final String dateFrom;
  final String dateTo;
  final String query;
  final String clearFilters;
  final String refresh;
  final String columns;
  final String exportData;
  final String exportExcel;
  final String exportWord;
  final String exportPdf;
  final String print;
  final String addNew;
  final String noData;
  final String noResults;
  final String itemsPerPage;
  final String expand;
  final String collapse;
  final String selectAll;
  final String firstPage;
  final String previousPage;
  final String nextPage;
  final String lastPage;
  final String defaultReportTitle;
  final String exportedOn;
  final String send;
  final String cancel;
  final String fieldRequired;
  final String invalidNumber;
  final String selectionRequired;
  final String filter;
  final String filterHelp;
  final String freezeStart;
  final String freezeEnd;
  final String unfreeze;
  final String resetColumns;
  final String invalidValue;
  final String retry;
  final String groupBy;
  final String noGrouping;
  final String period;
  final String allDates;
  final String today;
  final String yesterday;
  final String last7Days;
  final String last30Days;
  final String thisMonth;
  final String lastMonth;
  final String thisYear;
  final String customRange;
  final String apply;
  final String clear;
  final String previousMonth;
  final String nextMonth;
  final String invalidDate;

  /// `"Page 2 of 5 (48 items)"`.
  final String Function(int page, int totalPages, int totalItems) pageStatus;

  /// `"Showing 11–20 of 48"`.
  final String Function(int from, int to, int total) rangeStatus;

  /// `"3 selected"`.
  final String Function(int count) selectedCount;

  /// Snackbar message when an export fails.
  final String Function(String format, Object error) exportFailed;

  /// Snackbar message after a file was written to disk.
  final String Function(String path) savedTo;

  const AdaptiveTableLabels({
    required this.search,
    required this.dateFrom,
    required this.dateTo,
    required this.query,
    required this.clearFilters,
    required this.refresh,
    required this.columns,
    required this.exportData,
    required this.exportExcel,
    required this.exportWord,
    required this.exportPdf,
    required this.print,
    required this.addNew,
    required this.noData,
    required this.noResults,
    required this.itemsPerPage,
    required this.expand,
    required this.collapse,
    required this.selectAll,
    required this.firstPage,
    required this.previousPage,
    required this.nextPage,
    required this.lastPage,
    required this.defaultReportTitle,
    required this.exportedOn,
    required this.send,
    required this.cancel,
    required this.fieldRequired,
    required this.invalidNumber,
    required this.selectionRequired,
    this.filter = 'Filter…',
    this.filterHelp =
        'Filter this column: text, =exact, !=value, >10, <=5, 10..20, a, b',
    this.freezeStart = 'Freeze at start',
    this.freezeEnd = 'Freeze at end',
    this.unfreeze = 'Unfreeze',
    this.resetColumns = 'Reset columns',
    this.invalidValue = 'Invalid value',
    this.retry = 'Retry',
    this.groupBy = 'Group by',
    this.noGrouping = 'No grouping',
    this.period = 'Period',
    this.allDates = 'All dates',
    this.today = 'Today',
    this.yesterday = 'Yesterday',
    this.last7Days = 'Last 7 days',
    this.last30Days = 'Last 30 days',
    this.thisMonth = 'This month',
    this.lastMonth = 'Last month',
    this.thisYear = 'This year',
    this.customRange = 'Custom range',
    this.apply = 'Apply',
    this.clear = 'Clear',
    this.previousMonth = 'Previous month',
    this.nextMonth = 'Next month',
    this.invalidDate = 'Use yyyy-mm-dd',
    required this.pageStatus,
    required this.rangeStatus,
    required this.selectedCount,
    required this.exportFailed,
    required this.savedTo,
  });

  /// English labels.
  static const AdaptiveTableLabels en = AdaptiveTableLabels(
    search: 'Search...',
    dateFrom: 'From',
    dateTo: 'To',
    query: 'Query',
    clearFilters: 'Clear filters',
    refresh: 'Refresh',
    columns: 'Columns',
    exportData: 'Export data',
    exportExcel: 'Export Excel',
    exportWord: 'Export Word',
    exportPdf: 'Save PDF',
    print: 'Print',
    addNew: 'Add New',
    noData: 'No data available',
    noResults: 'No results match your filters',
    itemsPerPage: 'Rows per page:',
    expand: 'Expand',
    collapse: 'Collapse',
    selectAll: 'Select all',
    firstPage: 'First page',
    previousPage: 'Previous page',
    nextPage: 'Next page',
    lastPage: 'Last page',
    defaultReportTitle: 'Table Report',
    exportedOn: 'Exported',
    send: 'Send',
    cancel: 'Cancel',
    fieldRequired: 'Field is required',
    invalidNumber: 'Invalid number format',
    selectionRequired: 'Selection required',
    filter: 'Filter…',
    filterHelp:
        'Filter this column: text, =exact, !=value, >10, <=5, 10..20, a, b',
    freezeStart: 'Freeze at start',
    freezeEnd: 'Freeze at end',
    unfreeze: 'Unfreeze',
    resetColumns: 'Reset columns',
    invalidValue: 'Invalid value',
    retry: 'Retry',
    groupBy: 'Group by',
    noGrouping: 'No grouping',
    period: 'Period',
    allDates: 'All dates',
    today: 'Today',
    yesterday: 'Yesterday',
    last7Days: 'Last 7 days',
    last30Days: 'Last 30 days',
    thisMonth: 'This month',
    lastMonth: 'Last month',
    thisYear: 'This year',
    customRange: 'Custom range',
    apply: 'Apply',
    clear: 'Clear',
    previousMonth: 'Previous month',
    nextMonth: 'Next month',
    invalidDate: 'Use yyyy-mm-dd',
    pageStatus: _enPageStatus,
    rangeStatus: _enRangeStatus,
    selectedCount: _enSelectedCount,
    exportFailed: _enExportFailed,
    savedTo: _enSavedTo,
  );

  /// Arabic labels.
  static const AdaptiveTableLabels ar = AdaptiveTableLabels(
    search: 'بحث...',
    dateFrom: 'من تاريخ',
    dateTo: 'إلى تاريخ',
    query: 'استعلام',
    clearFilters: 'مسح الفلاتر',
    refresh: 'تحديث',
    columns: 'الأعمدة',
    exportData: 'تصدير البيانات',
    exportExcel: 'تصدير Excel',
    exportWord: 'تصدير Word',
    exportPdf: 'حفظ PDF',
    print: 'طباعة',
    addNew: 'إضافة',
    noData: 'لا توجد بيانات متاحة',
    noResults: 'لا توجد نتائج مطابقة',
    itemsPerPage: 'عدد الصفوف:',
    expand: 'توسيع',
    collapse: 'طي',
    selectAll: 'تحديد الكل',
    firstPage: 'الصفحة الأولى',
    previousPage: 'الصفحة السابقة',
    nextPage: 'الصفحة التالية',
    lastPage: 'الصفحة الأخيرة',
    defaultReportTitle: 'تقرير',
    exportedOn: 'تاريخ التصدير',
    send: 'إرسال',
    cancel: 'إلغاء',
    fieldRequired: 'هذا الحقل مطلوب',
    invalidNumber: 'صيغة الرقم غير صحيحة',
    selectionRequired: 'يرجى الاختيار',
    filter: 'تصفية…',
    filterHelp: 'تصفية هذا العمود: نص، =مطابق، !=قيمة، >10، <=5، 10..20، أ, ب',
    freezeStart: 'تثبيت في البداية',
    freezeEnd: 'تثبيت في النهاية',
    unfreeze: 'إلغاء التثبيت',
    resetColumns: 'إعادة ضبط الأعمدة',
    invalidValue: 'قيمة غير صالحة',
    retry: 'إعادة المحاولة',
    groupBy: 'تجميع حسب',
    noGrouping: 'بدون تجميع',
    period: 'الفترة',
    allDates: 'كل التواريخ',
    today: 'اليوم',
    yesterday: 'أمس',
    last7Days: 'آخر 7 أيام',
    last30Days: 'آخر 30 يوماً',
    thisMonth: 'هذا الشهر',
    lastMonth: 'الشهر الماضي',
    thisYear: 'هذه السنة',
    customRange: 'فترة مخصصة',
    apply: 'تطبيق',
    clear: 'مسح',
    previousMonth: 'الشهر السابق',
    nextMonth: 'الشهر التالي',
    invalidDate: 'اكتب التاريخ بصيغة yyyy-mm-dd',
    pageStatus: _arPageStatus,
    rangeStatus: _arRangeStatus,
    selectedCount: _arSelectedCount,
    exportFailed: _arExportFailed,
    savedTo: _arSavedTo,
  );

  /// Resolves labels from the ambient [Locale]: Arabic for `ar`, English
  /// otherwise.
  static AdaptiveTableLabels of(BuildContext context) {
    final locale = Localizations.maybeLocaleOf(context);
    return forLocale(locale);
  }

  /// Resolves the built-in labels for [locale].
  static AdaptiveTableLabels forLocale(Locale? locale) {
    return locale?.languageCode == 'ar' ? ar : en;
  }

  AdaptiveTableLabels copyWith({
    String? search,
    String? dateFrom,
    String? dateTo,
    String? query,
    String? clearFilters,
    String? refresh,
    String? columns,
    String? exportData,
    String? exportExcel,
    String? exportWord,
    String? exportPdf,
    String? print,
    String? addNew,
    String? noData,
    String? noResults,
    String? itemsPerPage,
    String? expand,
    String? collapse,
    String? selectAll,
    String? firstPage,
    String? previousPage,
    String? nextPage,
    String? lastPage,
    String? defaultReportTitle,
    String? exportedOn,
    String? send,
    String? cancel,
    String? fieldRequired,
    String? invalidNumber,
    String? selectionRequired,
    String? filter,
    String? filterHelp,
    String? freezeStart,
    String? freezeEnd,
    String? unfreeze,
    String? resetColumns,
    String? invalidValue,
    String? retry,
    String? groupBy,
    String? noGrouping,
    String? period,
    String? allDates,
    String? today,
    String? yesterday,
    String? last7Days,
    String? last30Days,
    String? thisMonth,
    String? lastMonth,
    String? thisYear,
    String? customRange,
    String? apply,
    String? clear,
    String? previousMonth,
    String? nextMonth,
    String? invalidDate,
    String Function(int page, int totalPages, int totalItems)? pageStatus,
    String Function(int from, int to, int total)? rangeStatus,
    String Function(int count)? selectedCount,
    String Function(String format, Object error)? exportFailed,
    String Function(String path)? savedTo,
  }) {
    return AdaptiveTableLabels(
      search: search ?? this.search,
      dateFrom: dateFrom ?? this.dateFrom,
      dateTo: dateTo ?? this.dateTo,
      query: query ?? this.query,
      clearFilters: clearFilters ?? this.clearFilters,
      refresh: refresh ?? this.refresh,
      columns: columns ?? this.columns,
      exportData: exportData ?? this.exportData,
      exportExcel: exportExcel ?? this.exportExcel,
      exportWord: exportWord ?? this.exportWord,
      exportPdf: exportPdf ?? this.exportPdf,
      print: print ?? this.print,
      addNew: addNew ?? this.addNew,
      noData: noData ?? this.noData,
      noResults: noResults ?? this.noResults,
      itemsPerPage: itemsPerPage ?? this.itemsPerPage,
      expand: expand ?? this.expand,
      collapse: collapse ?? this.collapse,
      selectAll: selectAll ?? this.selectAll,
      firstPage: firstPage ?? this.firstPage,
      previousPage: previousPage ?? this.previousPage,
      nextPage: nextPage ?? this.nextPage,
      lastPage: lastPage ?? this.lastPage,
      defaultReportTitle: defaultReportTitle ?? this.defaultReportTitle,
      exportedOn: exportedOn ?? this.exportedOn,
      send: send ?? this.send,
      cancel: cancel ?? this.cancel,
      fieldRequired: fieldRequired ?? this.fieldRequired,
      invalidNumber: invalidNumber ?? this.invalidNumber,
      selectionRequired: selectionRequired ?? this.selectionRequired,
      filter: filter ?? this.filter,
      filterHelp: filterHelp ?? this.filterHelp,
      freezeStart: freezeStart ?? this.freezeStart,
      freezeEnd: freezeEnd ?? this.freezeEnd,
      unfreeze: unfreeze ?? this.unfreeze,
      resetColumns: resetColumns ?? this.resetColumns,
      invalidValue: invalidValue ?? this.invalidValue,
      retry: retry ?? this.retry,
      groupBy: groupBy ?? this.groupBy,
      noGrouping: noGrouping ?? this.noGrouping,
      period: period ?? this.period,
      allDates: allDates ?? this.allDates,
      today: today ?? this.today,
      yesterday: yesterday ?? this.yesterday,
      last7Days: last7Days ?? this.last7Days,
      last30Days: last30Days ?? this.last30Days,
      thisMonth: thisMonth ?? this.thisMonth,
      lastMonth: lastMonth ?? this.lastMonth,
      thisYear: thisYear ?? this.thisYear,
      customRange: customRange ?? this.customRange,
      apply: apply ?? this.apply,
      clear: clear ?? this.clear,
      previousMonth: previousMonth ?? this.previousMonth,
      nextMonth: nextMonth ?? this.nextMonth,
      invalidDate: invalidDate ?? this.invalidDate,
      pageStatus: pageStatus ?? this.pageStatus,
      rangeStatus: rangeStatus ?? this.rangeStatus,
      selectedCount: selectedCount ?? this.selectedCount,
      exportFailed: exportFailed ?? this.exportFailed,
      savedTo: savedTo ?? this.savedTo,
    );
  }
}

String _enPageStatus(int page, int totalPages, int totalItems) =>
    'Page $page of $totalPages ($totalItems items)';
String _enRangeStatus(int from, int to, int total) =>
    'Showing $from–$to of $total';
String _enSelectedCount(int count) => '$count selected';
String _enExportFailed(String format, Object error) =>
    '$format export failed: $error';
String _enSavedTo(String path) => 'Saved to $path';

String _arPageStatus(int page, int totalPages, int totalItems) =>
    'صفحة $page من $totalPages ($totalItems عنصر)';
String _arRangeStatus(int from, int to, int total) => 'عرض $from–$to من $total';
String _arSelectedCount(int count) => 'تم تحديد $count';
String _arExportFailed(String format, Object error) =>
    'فشل تصدير $format: $error';
String _arSavedTo(String path) => 'تم الحفظ في $path';
