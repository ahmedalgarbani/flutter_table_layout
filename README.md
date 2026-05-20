# Adaptive Table Layout

A premium, highly-responsive, and adaptive data table package for Flutter. Build stunning dashboards with built-in support for global searching, date-range filtering, column toggling, pagination, and multi-currency aggregate summaries.

Includes a fully-integrated **Dynamic Form Engine** to create, add, or edit records with automatic field type detection. Export data instantly to **Excel (`.xlsx`)**, **Word (`.doc`)**, **PDF (`.pdf`)**, or send it directly to physical printers. Features complete out-of-the-box support for Right-to-Left (RTL) Arabic locales.

---

## 🌟 Key Features

* 📱 **Adaptive Viewports**:
  * **Desktop / Web**: A dense, scrollable tabular grid with customizable column widths, alignments, and alternate row colors.
  * **Mobile**: Automatically collapses rows into beautiful cards. Tapping expands them to reveal details.
* 🎛️ **Advanced Design Styling Presets**:
  * **Modern**: Sleek minimalist borders with clean contrast (light/dark mode support).
  * **Glassmorphic**: Real-time backdrop blur filter overlays (`BackdropFilter`), thin borders, and translucent cards.
  * **Gradient Accents**: Gradient fills across header headers and footer paginators.
  * **Cozy Spacing**: Rounded card curves, softer shadows, and wider cell padding.
* ⚡ **Dynamic Form Generator**:
  * Programmatic schema definitions (`DynamicFormField`) or **automatic type detection** based on table column settings.
  * Automatically handles field widgets based on data type: text, numbers, select dropdowns, toggles, and date-pickers.
  * Form validation, error handling, and structured submission handlers.
* 🌎 **RTL & Arabic Ready**: Handles automatic layout mirroring, flips navigation arrows, and wraps PDFs with shaped Arabic fonts (like Cairo).
* 📥 **One-Click Exports**:
  * **Excel**: Automatic sheets construction mapping data types (numbers, dates, text) dynamically.
  * **Word**: Formatted HTML-table documents ready to edit.
  * **PDF & Printing**: High-resolution layouts featuring page-numbers and print-preview windows.

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
  );
}
```

---

## 📝 Advanced Visual Themes

Toggle styles on the fly using prebuilt themes:

```dart
// Modern Light / Dark
final lightTheme = AdaptiveTableTheme.light(context);
final darkTheme = AdaptiveTableTheme.dark(context);

// Premium Glassmorphism
final glassTheme = AdaptiveTableTheme.glassmorphic(context, isDark: true);

// Color Gradients
final gradientTheme = AdaptiveTableTheme.gradient(context, isDark: false);

// Cozy Spaced
final cozyTheme = AdaptiveTableTheme.cozy(context, isDark: false);
```

---

## ⚡ Using the Dynamic Form Generator

You can show a fully functional add/edit dialog containing inputs generated directly from your table columns:

```dart
void showAddForm(BuildContext context, List<AdaptiveTableColumn<Transaction>> columns, AdaptiveTableTheme theme) {
  // 1. Auto-detect fields from columns
  final fields = DynamicFormField.detectFromColumns(
    columns,
    dropdownItems: {
      'currency': ['USD', 'EUR', 'YER'], // optional: renders dropdown instead of text field
    },
  );

  // 2. Open the Dialog modal
  DynamicFormDialog.show(
    context,
    title: 'Add New Record',
    fields: fields,
    theme: theme,
    onSubmitted: (Map<String, dynamic> values) {
      // Access values compiled as primitive Dart types
      final newTransaction = Transaction(
        id: (values['id'] as num).toInt(),
        description: values['description']?.toString() ?? '',
        amount: (values['amount'] as num).toDouble(),
        date: values['date'] as DateTime? ?? DateTime.now(),
      );
      
      // Update your datasets...
    },
  );
}
```

---

## 📖 In-Depth Component Details

### 1. Dynamic Form Fields Auto-Detection Rules
When using `DynamicFormField.detectFromColumns(columns)`, the engine evaluates column IDs and `fieldName` properties to infer the input field widget types.

| Column Pattern Match | Detected Type | Rendered Input Widget | Saved Value Data Type |
|---|---|---|---|
| Matches `'id'`, `'index'`, `'num'`, or ends in `'rate'`, `'amount'`, `'price'`, `'equivalent'` | `FieldType.number` | `TextFormField` with numeric keyboard input | `num` (integer or double) |
| Matches `'date'` (case insensitive) | `FieldType.date` | Custom date row picker button spawning calendar | `DateTime` |
| Contains `'is'`, `'active'`, `'status'` | `FieldType.boolean` | Styled switch toggle row (`SwitchListTile`) | `bool` |
| Explicitly provided in the `dropdownItems` mapping parameter | `FieldType.dropdown` | Form dropdown selector list (`DropdownButtonFormField`) | `String` |
| Matches any other pattern | `FieldType.text` | Standard text input field (`TextFormField`) | `String` |

---

### 2. Manual DynamicFormField Construction
If you have custom forms or want to override the default column-detection styles, you can construct `DynamicFormField` elements manually. This allows you to append custom validation constraints or provide localized placeholders.

```dart
final customFields = [
  DynamicFormField(
    id: 'email',
    label: 'Email Address',
    type: FieldType.text,
    isRequired: true,
    validator: (value) {
      if (value == null || !value.contains('@')) {
        return 'Enter a valid email address';
      }
      return null;
    },
  ),
  DynamicFormField(
    id: 'user_role',
    label: 'User Role',
    type: FieldType.dropdown,
    dropdownItems: ['Administrator', 'Editor', 'Viewer'],
    initialValue: 'Viewer',
  ),
  DynamicFormField(
    id: 'salary',
    label: 'Expected Salary',
    type: FieldType.number,
    isRequired: true,
    validator: (value) {
      final salary = num.tryParse(value ?? '');
      if (salary == null || salary <= 0) {
        return 'Salary must be greater than 0';
      }
      return null;
    },
  ),
];
```

---

### 3. Localization & RTL (Right-to-Left) Dynamics
The layout engine listens dynamically to the ambient text directionality of the context (`Directionality.of(context)`).
* **Column Alignments**: Mirror automatically (e.g. a column with alignment `TableColumnAlignment.start` aligns text to the left in LTR and to the right in RTL environments).
* **Pagination Controllers**: Pagination buttons and indicators automatically reverse position when RTL is active.
* **Arabic PDF Exports**: Translates system texts into Arabic and utilizes the shaped **Cairo Regular** Google Font to prevent raw Arabic glyph detachment.

---

### 4. Printing & Export Engines
* **System Printing**: Integrates `printing` package previews directly. Works across iOS, Android, macOS, Web, and Windows.
* **Excel Exporter**: Compiles numerical records into binary spreadsheet formats (`IntCellValue` & `DoubleCellValue`) so calculations run natively in spreadsheets.
* **Word Exporter**: Packs data in standard clean HTML tables mapping borders and typography directly to Microsoft Word layouts.

---

## 🔧 Parameters Reference

### AdaptiveTableLayout Parameters
| Property | Type | Default Value | Description |
|---|---|---|---|
| `items` | `List<T>` | *Required* | Raw list of models to display. |
| `columns` | `List<AdaptiveTableColumn<T>>` | *Required* | Schema matching columns headers and alignments. |
| `valueProviders` | `Map<String, dynamic Function(T)>` | *Required* | Extraction closures mapping headers to cell values. |
| `dateProvider` | `DateTime? Function(T)?` | `null` | Optional date accessor enabling calendar filter bar. |
| `theme` | `AdaptiveTableTheme?` | `null` | Color, typography, and border styling configuration. |
| `showSearch` | `bool` | `true` | Toggles search input field. |
| `showSelection` | `bool` | `true` | Toggles row checkboxes column. |
| `showExport` | `bool` | `true` | Toggles Excel, Word, and PDF download buttons. |
| `showPrint` | `bool` | `true` | Toggles system print action button. |
| `showColumnsToggle` | `bool` | `true` | Toggles columns visibility checkbox list. |
| `showPagination` | `bool` | `true` | Toggles paging footer controls. |
| `pageSizes` | `List<int>` | `[5, 10, 20, 50]` | Available page limits. |
| `minDesktopWidth` | `double` | `800` | Width below which the desktop grid wraps in a horizontal scroll. |
| `summaryBuilder` | `Widget Function(...)` | `null` | Section above paging controls showing custom computed averages or totals. |
| `expandedRowBuilder` | `Widget Function(...)` | `null` | Custom widget layout shown when row selection expands. |

### AdaptiveTableTheme Customizations
| Property | Type | Description |
|---|---|---|
| `cardBackgroundColor` | `Color` | Background color of the table card/container. |
| `borderRadius` | `BorderRadius` | Corner radius of the table container. |
| `cardBorder` | `BoxBorder?` | Borders of the table container. |
| `cardShadow` | `List<BoxShadow>?` | Shadow decorations for the table container. |
| `headerBackgroundColor` | `Color` | Background color of the column header row. |
| `headerTextStyle` | `TextStyle` | Text style of the column header cells. |
| `rowBackgroundColor` | `Color` | Base background color of data rows. |
| `alternateRowBackgroundColor` | `Color` | Alternate background color for zebra striping. |
| `useAlternateRows` | `bool` | Whether to use alternate row backgrounds. |
| `rowTextStyle` | `TextStyle` | Text style for cell text. |
| `rowHoverColor` | `Color` | Background color when a row is hovered on Web/Desktop. |
| `dividerColor` | `Color` | Divider/border color between cells and rows. |
| `footerBackgroundColor` | `Color` | Background color of the footer/pagination section. |
| `footerTextStyle` | `TextStyle` | Text style for footer texts. |
| `headerGradient` | `Gradient?` | Custom linear/radial gradient decoration overriding header background. |
| `footerGradient` | `Gradient?` | Custom linear/radial gradient decoration overriding footer background. |
| `enableGlassmorphism` | `bool` | Flags whether backdrop blur filters should apply to cards. |

---

## 📝 License

This project is licensed under the MIT License - see the LICENSE file for details.
