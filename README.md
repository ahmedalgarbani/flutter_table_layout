# flutter_table_layout

**Adaptive data tables for Flutter.** One widget gives you a dense data grid on desktop and web, and expandable cards on phones. It comes with search, date and custom filters, sorting, pagination, selection, summaries, Excel / Word / PDF export, printing, auto-generated CRUD forms, five themes, and full RTL (Arabic) support.

<p align="center">
  <img src="doc/screenshots/desktop_light.png" alt="Desktop data grid" width="780">
</p>

<p align="center">
  <img src="doc/screenshots/mobile_rtl.png" alt="Mobile cards in Arabic (RTL)" width="250">
  &nbsp;
  <img src="doc/screenshots/mobile_dark.png" alt="Mobile cards, dark cozy theme" width="250">
</p>

---

## Contents

- [Features](#features)
- [Installation](#installation)
- [Quick start](#quick-start)
- [Columns](#columns)
- [Search, filters and sorting](#search-filters-and-sorting)
- [Pagination](#pagination)
- [Selection, row taps and expandable rows](#selection-row-taps-and-expandable-rows)
- [Summary row](#summary-row)
- [Controlling the table from outside](#controlling-the-table-from-outside)
- [Loading and empty states](#loading-and-empty-states)
- [Layout mode (grid or cards)](#layout-mode-grid-or-cards)
- [Export and printing](#export-and-printing)
- [Dynamic forms (CRUD)](#dynamic-forms-crud)
- [Hiding features and permissions](#hiding-features-and-permissions)
- [Themes](#themes)
- [Localization and RTL](#localization-and-rtl)
- [API reference](#api-reference)
- [Using the logic without the UI](#using-the-logic-without-the-ui)
- [Running the example and tests](#running-the-example-and-tests)
- [بالعربية](#بالعربية)

---

## Features

| | |
|---|---|
| 📱 **Adaptive layout** | Data grid above `mobileBreakpoint` (600 px by default). Below it, rows become expandable cards. Horizontal scrolling kicks in when the columns don't fit. |
| 🔎 **Search** | Debounced, case-insensitive search over visible and searchable columns. Dates also match `yyyy-MM-dd`. |
| 📅 **Filters** | Inclusive date range with a "Query" button mode, your own filter widgets (`customFilters`), and a "Clear filters" button. |
| ↕️ **Sorting** | Stable sort. Numbers, strings (case-insensitive), dates and booleans compare naturally, and `null` always sorts last. |
| 📄 **Pagination** | Numbered pages, a rows-per-page menu, "Showing 11–20 of 48". The current page is clamped automatically when data shrinks. |
| ☑️ **Selection** | Row checkboxes, a tri-state *select all*, `onSelectionChanged`, and a selection badge. Exports use only the selected rows when there are any. |
| 🧩 **Expandable rows** | `expandedRowBuilder` adds a details panel on desktop and mobile. |
| 🧮 **Summary row** | `summaryBuilder` receives every filtered row, across all pages. |
| 📤 **Export** | Excel `.xlsx` with typed cells, Word `.doc`, PDF (auto landscape, Arabic font), and system printing. Web downloads the file, mobile opens the share sheet, desktop saves to Downloads. |
| 📝 **Dynamic forms** | Generate add/edit dialogs from your columns, with validation and typed values. |
| 🎨 **Themes** | `adaptive`, `light`, `dark`, `glassmorphic`, `gradient`, `cozy`. It's a `ThemeExtension`, so you can register it once for the whole app. |
| 🌍 **i18n and RTL** | English and Arabic built in, every string can be overridden, and layout, alignment and icons mirror in RTL. |
| 🕹️ **Controller** | `AdaptiveTableController` to search, filter, sort, paginate and select from anywhere. |

## Installation

```yaml
dependencies:
  flutter_table_layout: ^0.1.0
```

```bash
flutter pub get
```

Requires Flutter ≥ 3.35 / Dart ≥ 3.9.

> **Platform notes**
> - **macOS**: printing and saving files need the sandbox entitlements
>   `com.apple.security.print` and `com.apple.security.files.downloads.read-write`.
> - **Android / iOS**: exports open the native share sheet (`share_plus`).
> - **Web**: exports download directly in the browser.

## Quick start

```dart
import 'package:flutter/material.dart';
import 'package:flutter_table_layout/flutter_table_layout.dart';

class Invoice {
  final int id;
  final String customer;
  final double total;
  final DateTime date;
  final bool paid;
  const Invoice(this.id, this.customer, this.total, this.date, this.paid);
}

class InvoicesPage extends StatelessWidget {
  const InvoicesPage({super.key, required this.invoices});
  final List<Invoice> invoices;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        child: AdaptiveTableLayout<Invoice>(
          title: 'Invoices',
          subtitle: 'All invoices of the current year',
          items: invoices,
          columns: [
            AdaptiveTableColumn(id: 'id', title: '#', width: 70),
            AdaptiveTableColumn(id: 'customer', title: 'Customer', flex: 2),
            AdaptiveTableColumn(
              id: 'total',
              title: 'Total',
              alignment: TableColumnAlignment.end,
              valueFormatter: (v) => '\$${(v as double).toStringAsFixed(2)}',
            ),
            AdaptiveTableColumn(id: 'date', title: 'Date', width: 120),
            AdaptiveTableColumn(
              id: 'paid',
              title: 'Status',
              width: 110,
              cellBuilder: (context, inv) => Chip(
                label: Text(inv.paid ? 'Paid' : 'Open'),
              ),
            ),
          ],
          // One extractor per column id. Used for search, sort and export.
          valueProviders: {
            'id': (i) => i.id,
            'customer': (i) => i.customer,
            'total': (i) => i.total,
            'date': (i) => i.date,
            'paid': (i) => i.paid ? 'Paid' : 'Open',
          },
          dateProvider: (i) => i.date, // enables the From / To filter
        ),
      ),
    );
  }
}
```

> 💡 `items` may be a new list or the same list changed in place. Either way the table refreshes on the next rebuild.

## Columns

`AdaptiveTableColumn<T>` describes one column:

| Property | Default | Description |
|---|---|---|
| `id` | *required* | Unique key. It must match the key in `valueProviders`. |
| `title` | *required* | Header text. Single words are never split mid-word, they shrink to fit instead. |
| `fieldName` | `id` | Field name, used by the dynamic form type detection. |
| `width` / `flex` | `null` / `1` | Fixed width, or a flex share of the remaining space. |
| `alignment` | `start` | `start`, `center` or `end`. Direction-aware, so `end` is the left edge in RTL. |
| `cellBuilder` | `null` | Custom cell widget. |
| `headerBuilder` | `null` | Custom header widget. |
| `valueFormatter` | `null` | Formats the raw value for text cells, mobile cards and PDF/Word exports. Excel keeps the raw typed value. |
| `isSortable` | `true` | Tapping the header toggles ascending / descending. |
| `isVisible` | `true` | Initial visibility. Users can still toggle it from the columns menu. |
| `isHideable` | `true` | Whether users may hide the column. The last visible column can never be hidden. |
| `isSearchable` | `true` | Include in global search. |
| `isExportable` | `true` | Include in exports and printing. Set `false` for action columns. |

```dart
AdaptiveTableColumn<Currency>(
  id: 'actions',
  title: 'Actions',
  width: 130,
  isSortable: false,
  isSearchable: false,
  isExportable: false, // not written to Excel / PDF / Word
  cellBuilder: (context, c) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      IconButton(icon: const Icon(Icons.edit), onPressed: () => edit(c)),
      IconButton(icon: const Icon(Icons.delete), onPressed: () => delete(c)),
    ],
  ),
),
```

<p align="center"><img src="doc/screenshots/desktop_dark.png" alt="Columns menu (dark theme)" width="720"></p>

## Search, filters and sorting

```dart
AdaptiveTableLayout<Transaction>(
  // …
  showSearch: true,                          // default
  searchDebounce: const Duration(milliseconds: 250),
  dateProvider: (t) => t.date,               // shows From / To pickers
  firstDate: DateTime(2020), lastDate: DateTime(2030),
  onQueryPressed: () {},                     // optional: apply dates only on "Query"
  initialSortColumnId: 'date',
  initialSortAscending: false,

  // Custom filters: any widget, plus a matcher.
  customFilterMatcher: (t, filters) =>
      filters['currency'] == null || t.currency == filters['currency'],
  customFilters: const [CurrencyFilter()],
)
```

A custom filter widget is built under the table, so it can talk to the table directly:

```dart
class CurrencyFilter extends StatelessWidget {
  const CurrencyFilter({super.key});

  @override
  Widget build(BuildContext context) {
    final cubit = context.watch<TableCubit<Transaction>>();
    final current = cubit.tableState.customFilters['currency'] as String?;
    return SegmentedButton<String>(
      segments: const [
        ButtonSegment(value: 'all', label: Text('All')),
        ButtonSegment(value: 'USD', label: Text('USD')),
        ButtonSegment(value: 'SAR', label: Text('SAR')),
      ],
      selected: {current ?? 'all'},
      onSelectionChanged: (s) =>
          cubit.setCustomFilter('currency', s.first == 'all' ? null : s.first),
    );
  }
}
```

> Value providers whose key doesn't match any column are **search-only keys**. For example, `'tags': (t) => t.tags.join(' ')` makes tags searchable without showing a column.

## Pagination

```dart
AdaptiveTableLayout<T>(
  pageSizes: const [10, 25, 50, 100],
  initialPageSize: 25,
  showPagination: true, // false = render every row, no footer
)
```

## Selection, row taps and expandable rows

```dart
AdaptiveTableLayout<Transaction>(
  showSelection: true,
  onSelectionChanged: (rows) => setState(() => selected = rows),
  onRowTap: (t) => openDetails(t),          // when null, a tap expands the row
  onRowLongPress: (t) => showMenu(t),
  rowColorBuilder: (t) => t.isOverdue ? Colors.red.withValues(alpha: .06) : null,
  expandedRowBuilder: (context, t) => TransactionDetails(t),
  mobileTitleColumnId: 'details',           // card title on phones
  mobileSubtitleColumnId: 'amount',         // card subtitle on phones
)
```

## Summary row

`summaryBuilder` receives **all filtered rows**, not only the current page:

```dart
summaryBuilder: (context, rows) {
  final total = rows.fold<double>(0, (s, r) => s + r.amount);
  return Text('Total: ${total.toStringAsFixed(2)}');
},
```

## Controlling the table from outside

```dart
final controller = AdaptiveTableController<Invoice>();

AdaptiveTableLayout<Invoice>(controller: controller, /* … */);

controller.search('acme');
controller.setDateRange(DateTime(2026, 1, 1), null);
controller.setCustomFilter('status', 'open');
controller.sortBy('total', ascending: false);
controller.goToPage(2);
controller.setColumnVisibility('notes', false);
controller.selectAll();

final rows = controller.filteredItems;   // all pages, filtered and sorted
final picked = controller.selectedItems;
controller.resetFilters();
```

The controller is a `ChangeNotifier`, so `ListenableBuilder(listenable: controller, …)` rebuilds on every table change. Use `onTableStateChanged` to persist the search/sort/page state, or to drive server-side queries.

## Loading and empty states

```dart
AdaptiveTableLayout<T>(
  isLoading: isFetching,            // spinner, or a progress bar over existing rows
  loadingWidget: const MyShimmer(),
  emptyWidget: const MyEmptyState(), // otherwise "No data" / "No results"
)
```

If a value provider throws, the table shows an error message instead of crashing, and recovers on the next change.

## Layout mode (grid or cards)

```dart
AdaptiveTableLayout<T>(
  layoutMode: TableLayoutMode.auto,  // default: cards below mobileBreakpoint
  // layoutMode: TableLayoutMode.table, // always the grid (scrolls horizontally on phones)
  // layoutMode: TableLayoutMode.cards, // always cards, even on desktop
  mobileBreakpoint: 700,             // only used by `auto`
)
```

The toolbar and footer always adapt to the available width, whatever the mode.

## Export and printing

The toolbar has **Excel**, **Word**, **PDF** and **Print** actions. Exports:

- respect the current search, filters and sort order;
- export **only the selected rows** when some are selected (`exportSelectedWhenAny`);
- skip hidden columns and columns with `isExportable: false`;
- escape HTML in the Word output, and use safe file and sheet names, including Arabic titles;
- save the file where it belongs: a browser download on web, the share sheet on mobile, and `~/Downloads` on desktop (with a snackbar showing the path).

```dart
AdaptiveTableLayout<T>(
  exportOptions: TableExportOptions(
    fileName: 'statement_2026',
    formats: {ExportFormat.excel, ExportFormat.pdf},
    pdfFont: myRegularFont,       // pw.Font.ttf(await rootBundle.load('assets/Cairo-Regular.ttf'))
    pdfBoldFont: myBoldFont,
    pdfPageFormat: PdfPageFormat.a4.landscape,
    // Handle the bytes yourself (upload, e-mail…) instead of saving:
    onExport: (format, bytes, fileName) async => upload(bytes, fileName),
  ),
)
```

**Use your own export or print** (for example your company PDF template). The table gives you the rows it would export: the selected rows if any, otherwise all filtered rows, in the current sort order.

```dart
AdaptiveTableLayout<Invoice>(
  onExportRequested: (format, rows) async {
    if (format == ExportFormat.pdf) {
      final bytes = await MyInvoicePdf.build(rows);
      await saveAndShareFile(bytes: bytes, fileName: 'invoices.pdf',
          mimeType: format.mimeType);
    }
  },
  onPrintRequested: (rows) => MyPrinter.print(rows),
)
```

> **Arabic PDFs offline:** by default the Cairo font is downloaded from Google Fonts once, then cached. Offline apps should bundle a font and pass `pdfFont`.

The exporters also work on their own:

```dart
final bytes = await const ExcelExporter().generateExcel<Invoice>(
  sheetName: 'Invoices',
  columns: columns.map((c) => c.definition).toList(),
  items: invoices,
  valueProviders: providers,
);
await saveAndShareFile(bytes: bytes, fileName: 'invoices.xlsx',
    mimeType: ExportFormat.excel.mimeType);
```

## Dynamic forms (CRUD)

<p align="center"><img src="doc/screenshots/dynamic_form.png" alt="Dynamic form dialog" width="720"></p>

Generate a form from your columns and get typed values back:

```dart
final values = await DynamicFormDialog.show(
  context,
  title: 'New transaction',
  fields: DynamicFormField.detectFromColumns(
    columns,
    dropdownItems: {'currency': ['YER', 'SAR', 'USD']},
    excludeIds: {'id', 'actions'},
    initialValues: {'currency': 'USD'},      // e.g. when editing
    fieldTypes: {'status': FieldType.text},  // override the detection
  ),
);
if (values != null) {
  // values['amount'] is num?, values['date'] is DateTime, values['paid'] is bool…
}
```

**Type detection** works on whole words of `fieldName` / `id` (`createdAt`, `created_at` and `Created At` all split into *created* + *at*):

| Detected type | Matches | Widget | Value |
|---|---|---|---|
| `boolean` | starts with `is`/`has`/`can`/`should`/`allow`, or contains `active`, `enabled`, `status`, `visible` | `SwitchListTile` | `bool` |
| `date` | contains `date`, `day`, `time`, `birthday`, `dob`, or ends with `at`/`on` | date picker | `DateTime` |
| `number` | contains `id`, `amount`, `price`, `rate`, `total`, `qty`, `count`, `balance`, `discount`, … | numeric field | `num?` (`null` if left empty) |
| `dropdown` | column listed in `dropdownItems` | `DropdownButtonFormField` | `String?` |
| `text` | anything else | `TextFormField` | `String?` |

Manual fields support `validator` (called for every type), `hint`, `helperText`, `enabled`, `maxLines`, `firstDate` and `lastDate`:

```dart
DynamicFormField(
  id: 'email',
  label: 'E-mail',
  type: FieldType.text,
  isRequired: true,
  hint: 'name@company.com',
  validator: (v) => (v as String?)?.contains('@') == true ? null : 'Invalid e-mail',
),
```

## Hiding features and permissions

Every part of the table can be turned off, and a button whose callback is `null` is not shown. So permissions are just values:

```dart
final canEdit = user.can('invoices.edit');

AdaptiveTableLayout<Invoice>(
  showSearch: true,
  showDateFilter: false,                    // hide the From / To pickers
  showExport: user.can('invoices.export'),
  showPrint: user.can('invoices.print'),
  showSelection: canEdit,
  showColumnsToggle: true,
  showPagination: true,
  showSummary: user.can('invoices.totals'),
  showClearFilters: true,
  onAddNewPressed: user.can('invoices.create') ? openMyAddDialog : null,
  onRefreshPressed: reload,
  exportOptions: const TableExportOptions(formats: {ExportFormat.excel}), // only Excel
  columns: [
    // …
    if (canEdit)
      AdaptiveTableColumn(
        id: 'actions', title: 'Actions', width: 130,
        isSortable: false, isSearchable: false, isExportable: false,
        cellBuilder: (context, inv) => Row(mainAxisSize: MainAxisSize.min, children: [
          IconButton(icon: const Icon(Icons.edit), onPressed: () => openMyEditDialog(inv)),
          if (user.can('invoices.delete'))
            IconButton(icon: const Icon(Icons.delete), onPressed: () => delete(inv)),
        ]),
      ),
  ],
  onRowTap: canEdit ? openMyEditDialog : null,
)
```

- The filter bar disappears when search, the date filter and custom filters are all off.
- The toolbar disappears when there is no title and no action.
- `onAddNewPressed` can open **any** dialog or page, so `DynamicFormDialog` is optional.
- Sensitive columns: include them only when allowed (`if (user.isAdmin) AdaptiveTableColumn(...)`), or use `isHideable: false` / `isExportable: false`.

## Themes

| Glassmorphic | Gradient | Cozy |
|---|---|---|
| ![glass](doc/screenshots/theme_glassmorphic.png) | ![gradient](doc/screenshots/theme_gradient.png) | ![cozy](doc/screenshots/theme_cozy.png) |

```dart
AdaptiveTableTheme.adaptive(context)          // default: follows light/dark + colorScheme.primary
AdaptiveTableTheme.light(context, accentColor: Colors.teal)
AdaptiveTableTheme.dark(context)
AdaptiveTableTheme.glassmorphic(context, isDark: true) // place over an image/gradient
AdaptiveTableTheme.gradient(context, gradient: myGradient)
AdaptiveTableTheme.cozy(context)

// Tweak any preset:
AdaptiveTableTheme.light(context).copyWith(
  borderRadius: BorderRadius.circular(4),
  useAlternateRows: false,
  accentColor: Colors.deepPurple,
)
```

Register a theme once for the whole app. It also animates between light and dark:

```dart
MaterialApp(
  theme: ThemeData(extensions: [myTableTheme]),
)
```

Main theme properties: `cardBackgroundColor`, `borderRadius`, `cardBorder`, `cardShadow`, `cardMargin`, `toolbarBackgroundColor`, `headerBackgroundColor`, `headerTextStyle`, `titleTextStyle`, `rowBackgroundColor`, `alternateRowBackgroundColor`, `useAlternateRows`, `rowTextStyle`, `rowPadding`, `rowHoverColor`, `selectedRowColor`, `dividerColor`, `footerBackgroundColor`, `footerTextStyle`, `summaryBackgroundColor`, `accentColor`, `onAccentColor`, `actionIconColor`, `toolbarIconColor`, `statusPositiveColor`, `statusNegativeColor`, `headerGradient`, `footerGradient`, `enableGlassmorphism`, `blurSigma`.

## Localization and RTL

<p align="center"><img src="doc/screenshots/desktop_rtl.png" alt="Arabic RTL desktop" width="720"></p>

- Labels come from `AdaptiveTableLabels.of(context)`: Arabic when the app locale is `ar`, English otherwise.
- Pass `labels: AdaptiveTableLabels.en.copyWith(search: 'Buscar…', …)` (or a whole new `AdaptiveTableLabels`) for any other language.
- The older `searchHint`, `dateFromLabel`, `dateToLabel` and `queryButtonLabel` parameters still work and override the labels.
- In RTL, the layout, column alignments, pagination arrows and expand icons are mirrored, Excel sheets are right-to-left, and Word/PDF documents use `dir="rtl"`.

## API reference

### `AdaptiveTableLayout<T>`

| Parameter | Type | Default | Description |
|---|---|---|---|
| `items` | `List<T>` | required | Rows. |
| `columns` | `List<AdaptiveTableColumn<T>>` | required | Column schema. |
| `valueProviders` | `Map<String, dynamic Function(T)>` | required | Values per column id (search / sort / export). |
| `dateProvider` | `DateTime? Function(T)?` | `null` | Enables the date filter. |
| `customFilterMatcher` | `bool Function(T, Map<String, dynamic>)?` | `null` | Applies `customFilters` values. |
| `customFilters` | `List<Widget>?` | `null` | Extra filter widgets. |
| `controller` | `AdaptiveTableController<T>?` | `null` | External control. |
| `title` / `subtitle` / `titleIcon` | | `null` | Toolbar header. |
| `toolbarActions` | `List<Widget>?` | `null` | Extra toolbar buttons. |
| `onRefreshPressed` / `onAddNewPressed` / `onQueryPressed` | `VoidCallback?` | `null` | Toolbar callbacks. |
| `showSearch` / `showSelection` / `showExport` / `showPrint` / `showColumnsToggle` / `showPagination` / `showSummary` / `showClearFilters` | `bool` | `true` | Feature switches. |
| `showDateFilter` | `bool?` | `dateProvider != null` | Show the date pickers. |
| `pageSizes` / `initialPageSize` | `List<int>` / `int?` | `[5,10,20,50]` / `10` | Pagination. |
| `initialSortColumnId` / `initialSortAscending` | | `null` / `true` | Initial sort. |
| `summaryBuilder` | `Widget Function(BuildContext, List<T>)?` | `null` | Summary row. |
| `expandedRowBuilder` | `Widget Function(BuildContext, T)?` | `null` | Row details panel. |
| `onRowTap` / `onRowLongPress` | `ValueChanged<T>?` | `null` | Row gestures. |
| `onSelectionChanged` | `ValueChanged<List<T>>?` | `null` | Selection updates. |
| `onTableStateChanged` | `ValueChanged<TableStateModel>?` | `null` | Search / filter / sort / page updates. |
| `rowColorBuilder` | `Color? Function(T)?` | `null` | Per-row background. |
| `layoutMode` | `TableLayoutMode` | `auto` | `auto`, `table` (always grid), `cards` (always cards). |
| `mobileBreakpoint` / `minDesktopWidth` | `double` | `600` / `800` | Layout thresholds. |
| `onExportRequested` / `onPrintRequested` | callbacks | `null` | Replace the built-in export / print with your own. |
| `mobileTitleColumnId` / `mobileSubtitleColumnId` | `String?` | first / second column | Card title and subtitle. |
| `theme` / `labels` | | `AdaptiveTableTheme.of` / `AdaptiveTableLabels.of` | Styling and strings. |
| `searchDebounce` | `Duration` | `250ms` | Search delay. |
| `firstDate` / `lastDate` | `DateTime?` | 1900 / 2200 | Date picker range. |
| `exportOptions` | `TableExportOptions` | defaults | Export configuration. |
| `isLoading` / `loadingWidget` / `emptyWidget` | | `false` / `null` / `null` | States. |

## Using the logic without the UI

The domain layer is plain Dart and can be used anywhere, for example on a server:

```dart
final result = const FilterItemsUseCase().apply<Invoice>(
  items: invoices,
  columns: const [ColumnDefinition(id: 'customer', title: 'Customer')],
  state: const TableStateModel(searchQuery: 'acme', sortByColumnId: 'total',
      sortAscending: false, currentPage: 1, pageSize: 20),
  valueProviders: {'customer': (i) => i.customer, 'total': (i) => i.total},
);
print('${result.totalCount} rows, ${result.totalPages} pages');
```

`TableCubit<T>` holds the reactive state (via `flutter_bloc`) if you want to build your own UI.

## Running the example and tests

```bash
cd example && flutter run            # android / ios / web / windows / macos / linux
flutter test                          # from the package root
```

The screenshots in this README are generated from the example app:

```bash
cd example
flutter test test/screenshots_test.dart --update-goldens \
  --dart-define=SCREENSHOTS=true --dart-define=ARABIC_FONT_DIR=/path/to/cairo
```

---

## بالعربية

**flutter_table_layout** مكتبة جداول ذكية لـ Flutter. تعرض البيانات كجدول كامل على الكمبيوتر والويب، وتحوّلها تلقائياً إلى بطاقات قابلة للتوسيع على الجوال. تدعم العربية واتجاه RTL بالكامل.

**أهم المزايا:**
- بحث فوري، وفلترة بالتاريخ (من / إلى)، وفلاتر مخصصة، وزر لمسح الفلاتر.
- فرز ثابت يفهم الأرقام والنصوص والتواريخ، وترقيم صفحات بأرقام وعدد صفوف قابل للتغيير.
- تحديد الصفوف مع استدعاء `onSelectionChanged`، وصفوف قابلة للتوسيع لعرض التفاصيل، وصف ملخص للإجماليات.
- تصدير إلى Excel وWord وPDF (بخط عربي) وطباعة مباشرة. عند تحديد صفوف يُصدَّر المحدد منها فقط، ولا تُصدَّر الأعمدة المخفية.
- نماذج إضافة وتعديل تُولَّد تلقائياً من الأعمدة مع التحقق من الإدخال.
- ستة أنماط تصميم (تلقائي، فاتح، داكن، زجاجي، متدرج، مريح) قابلة للتعديل بـ `copyWith`.
- نصوص عربية وإنجليزية جاهزة تُختار حسب لغة التطبيق، ويمكن تخصيص أي نص.
- متحكم `AdaptiveTableController` للتحكم بالجدول من خارجه.

**مثال سريع:**

```dart
AdaptiveTableLayout<Transaction>(
  title: 'كشف الحساب',
  items: transactions,
  columns: [
    AdaptiveTableColumn(id: 'date', title: 'التاريخ', width: 120),
    AdaptiveTableColumn(id: 'details', title: 'البيان', flex: 2),
    AdaptiveTableColumn(id: 'amount', title: 'المبلغ',
        alignment: TableColumnAlignment.end),
  ],
  valueProviders: {
    'date': (t) => t.date,
    'details': (t) => t.details,
    'amount': (t) => t.amount,
  },
  dateProvider: (t) => t.date,
  summaryBuilder: (context, rows) =>
      Text('الإجمالي: ${rows.fold<double>(0, (s, t) => s + t.amount)}'),
)
```

لتظهر النصوص بالعربية، اضبط لغة التطبيق على `ar` (مع `flutter_localizations`)، أو مرّر `labels: AdaptiveTableLabels.ar`.

---

## License

MIT. See [LICENSE](LICENSE).
