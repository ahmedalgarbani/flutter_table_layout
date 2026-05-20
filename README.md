# Adaptive Table Layout

A premium, highly-responsive, and adaptive data table package for Flutter. Build stunning dashboards with built-in support for global searching, date-range filtering, column toggling, pagination, and multi-currency aggregate summaries.

Export data instantly to **Excel (`.xlsx`)**, **Word (`.doc`)**, **PDF (`.pdf`)**, or send it directly to physical printers. Features complete out-of-the-box support for Right-to-Left (RTL) Arabic locales and premium dark/light styling.

---

## 🌟 Key Features

* 📱 **Adaptive Viewports**:
  * **Desktop / Web**: A dense, scrollable tabular grid with customizable column widths, alignments, and alternate row colors.
  * **Mobile**: Automatically collapses rows into beautiful cards. Tapping expands them to reveal details.
* 🌎 **RTL & Arabic Ready**: Handles automatic layout mirroring, flips navigation arrows, and wraps PDFs with shaped Arabic fonts (like Cairo).
* 📥 **One-Click Exports**:
  * **Excel**: Automatic sheets construction mapping data types (numbers, dates, text) dynamically.
  * **Word**: Formatted HTML-table documents ready to edit.
  * **PDF & Printing**: High-resolution layouts featuring page-numbers and print-preview windows.
* 🔍 **Advanced Filtering**: Prebuilt text searches, date range limits with date-picker dialogs, and support for custom drop-down filters.
* 🎛️ **Column Visibility**: Built-in dropdown checkbox toggler to show/hide columns at runtime.
* 📊 **Footer Summaries**: Dedicated slot to calculate and display running totals (e.g. credit/debit aggregates) directly above the page controllers.
* 🎨 **Premium Aesthetics**: Styled according to modern visual rules. Supports light and premium dark themes natively.

---

## 📦 Getting Started

Add the package to your `pubspec.yaml` file:

```yaml
dependencies:
  flutter_table_layout:
    path: # path to package or version reference
```

Run dependencies update:

```bash
flutter pub get
```

---

## 🚀 Quick Usage

Define your data model and column configurations. Bridge your widgets easily using `AdaptiveTableLayout`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_table_layout/flutter_table_layout.dart';

// 1. Define your data class
class Transaction {
  final int id;
  final String description;
  final double amount;
  final DateTime date;

  Transaction({
    required this.id,
    required this.description,
    required this.amount,
    required this.date,
  });
}

// 2. Set up the table widget in your Page build method
Widget buildTable(BuildContext context, List<Transaction> transactions) {
  return AdaptiveTableLayout<Transaction>(
    title: 'Statement Details',
    subtitle: 'Track your payments and transfers',
    items: transactions,
    
    // Define columns schema
    columns: [
      AdaptiveTableColumn<Transaction>(
        id: 'id',
        title: 'ID',
        fieldName: 'id',
        width: 60,
        alignment: TableColumnAlignment.center,
      ),
      AdaptiveTableColumn<Transaction>(
        id: 'description',
        title: 'Description',
        fieldName: 'description',
        flex: 2,
      ),
      AdaptiveTableColumn<Transaction>(
        id: 'amount',
        title: 'Amount',
        fieldName: 'amount',
        width: 100,
        alignment: TableColumnAlignment.end,
        cellBuilder: (context, item) => Text('\$${item.amount.toStringAsFixed(2)}'),
      ),
    ],

    // Provide values extraction map for search/sort/exports
    valueProviders: {
      'id': (t) => t.id,
      'description': (t) => t.description,
      'amount': (t) => t.amount,
    },
    
    // Support running totals/aggregations in footer
    showSummary: true,
    summaryBuilder: (context, visibleItems) {
      final total = visibleItems.fold<double>(0, (sum, item) => sum + item.amount);
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('Total Items: ${visibleItems.length}', style: TextStyle(fontWeight: FontWeight.bold)),
          Text('Sum: \$${total.toStringAsFixed(2)}', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
        ],
      );
    },
  );
}
```

---

## 🎨 Theme Customization

Use `AdaptiveTableTheme` to overwrite paddings, hover highlights, borders, and typography:

```dart
final customTheme = AdaptiveTableTheme.light(context).copyWith(
  cardBackgroundColor: Colors.white,
  dividerColor: Colors.blue.shade50,
  rowHoverColor: Colors.blue.shade50.withOpacity(0.2),
);

// Inject inside layout:
AdaptiveTableLayout(
  theme: customTheme,
  ...
)
```

---

## 🔧 Parameters Reference

| Property | Type | Description |
|---|---|---|
| `items` | `List<T>` | Raw list of models to display. |
| `columns` | `List<AdaptiveTableColumn<T>>` | Schema matching columns headers and alignments. |
| `valueProviders` | `Map<String, dynamic Function(T)>` | Extraction closures mapping headers to comparable cell values. |
| `dateProvider` | `DateTime? Function(T)?` | Optional date accessor enabling calendar filter bar. |
| `theme` | `AdaptiveTableTheme?` | Color, typography, and border styling configuration. |
| `showSearch` | `bool` | Toggles search input field (default: `true`). |
| `showSelection` | `bool` | Toggles row checkboxes column (default: `true`). |
| `showExport` | `bool` | Toggles Excel, Word, and PDF download buttons (default: `true`). |
| `showPrint` | `bool` | Toggles system print action button (default: `true`). |
| `showColumnsToggle` | `bool` | Toggles columns visibility checkbox list (default: `true`). |
| `showPagination` | `bool` | Toggles paging footer controls (default: `true`). |
| `pageSizes` | `List<int>` | Available page limits, defaults to `[5, 10, 20, 50]`. |
| `minDesktopWidth` | `double` | Width below which the desktop grid wraps in a horizontal scroll (default: `800`). |
| `summaryBuilder` | `Widget Function(...)` | Section above paging controls showing custom computed averages or totals. |
| `expandedRowBuilder` | `Widget Function(...)` | Custom widget layout shown when row selection expands. |

---

## 📝 License

This project is licensed under the MIT License - see the LICENSE file for details.
