# Changelog

## 0.2.0

A full review of 0.1.4: every bug below was first reproduced on 0.1.4, then fixed and covered by a test (226 tests, up from 153).

### Fixes
* **Keyboard focus was trapped in the grid:** Tab always moved to the next cell, so keyboard users could never leave the table. The rows are now one Tab stop: Tab / Shift+Tab move through the cells and leave the grid after the last one. Reaching the rows with Tab focuses the first cell, and the first arrow press no longer skips it.
* **Typing in a column filter could change the selection:** once a cell had been clicked, Space, the arrows, Home / End and Ctrl + A typed in a filter field were handled by the grid (Space toggled the row's selection instead of typing a space). Grid shortcuts now only apply while the grid itself has the focus.
* **An error hid the toolbar and the search box:** after a server (or value provider) error only the Retry button was left, so a search that caused the error could not even be changed. The toolbar, filter bar and footer now stay.
* **Date presets across daylight-saving changes:** "Yesterday", "Last 7 days" and "Last 30 days" subtracted 24-hour days from local midnight and could start on the wrong day (e.g. 2026-03-03 23:00 instead of 2026-03-04 in New York). They now use calendar days.
* **"Showing 1–0 of N"** in the footer when every row is shown on one page.
* **`onSelectionChanged` fired on every data refresh**, even when the selection did not change.
* **Removed columns kept filtering:** when a column disappeared from `columns`, its column filter, sort level and grouping stayed active, invisibly. They are now dropped (with its width and pin).
* **`setColumnWidth` / `setColumnWidths` threw** a null check error for an unknown column id.
* **`AdaptiveTableController` listeners** built before the table showed an empty state until the first change.
* **Inline editing:** Tab in an editor now jumps to the next *editable* cell (it re-opened the same cell at the end of a row); the editor follows its row when the edited item is replaced by a new instance; a dropdown editor closes when another cell is clicked.
* **Columns menu:** titles wrapped mid-word ("Curren / cy").
* **Dynamic forms:** the search dialog of multi-select / relationship fields had English-only texts ("Search...", "No items found", "Cancel", "Save", "Select …") and hard-coded blue colors; it now uses the labels (Arabic included) and the theme accent. It no longer calls `Navigator.pop` inside `setState`.
* **Exports:** the header text was always white, unreadable on light accent colors (e.g. the dark theme's accent); it is now black or white depending on the color. Word cells follow the column alignment.
* **Performance:** selection checks were O(rows × selected) on every frame; a parent rebuild re-ran the whole filter / sort pipeline even when nothing had changed (now skipped when the items, columns and functions are unchanged); column filter expressions were re-parsed for every row (now compiled once); Page Up / Down at the first / last page recomputed for nothing.
* The focus border of a cell stayed after the grid lost focus, and selecting a card changed its border width (a small layout shift).

### New
* **Arabic-aware search:** `احمد` finds `أحمد`, `مدرسه` finds `مدرسة`, diacritics and tatweel are ignored, `١٢٣` = `123` — in the search box, the column filters and the order of text values. `TableTextNormalizer`, and `textNormalizer` to change it.
* **The search also matches the displayed text** (`valueFormatter`): `1,500.00`, `05/01/2026`…
* **Totals row:** `AdaptiveTableColumn.aggregate` (`TableAggregate.sum / average / min / max / count`), `aggregator` for custom totals and `aggregateFormatter`. A sticky row aligned with the columns (frozen ones included), live with the filters, as a panel on phones, and at the end of every export. Server pages can return their totals in `TableDataPage.aggregates`. Also `TableLoaded.aggregates` and `controller.aggregates`.
* **CSV export:** `ExportFormat.csv` / `CsvExporter` — UTF-8 with BOM (Arabic opens correctly in Excel), RFC 4180 quoting, formula-injection protection, `TableExportOptions.csvDelimiter`.
* **Copy to clipboard:** Ctrl / Cmd + C copies the selected rows (or the focused cell) as tab-separated text; `controller.copyToClipboard()`.
* **Row identity:** `rowKey: (row) => row.id` keeps selected and expanded rows across new instances (immutable updates, server reloads) and across server pages.
* **Save / restore the table state:** `TableSnapshot` (query + hidden / widths / order / frozen columns) with `toJson`, `encode`, `tryDecode`; `initialSnapshot` and `onSnapshotChanged` on the table; `controller.snapshot` / `restoreSnapshot`; `TableStateModel.toJson` / `fromJson`.
* **"Group by" toolbar menu:** `showGroupingMenu: true`, with `isGroupable` per column.
* **"Sort by" bar on phones** (cards have no headers): `showCardSortBar`.
* `tristateSort`: a third header click removes the sort.
* `density: TableDensity.compact / standard / comfortable` and `AdaptiveTableTheme.withDensity`.
* `AdaptiveTableTheme.material(context)`: a Material 3 look from the app's `ColorScheme`.
* An **"All"** rows-per-page option: put `0` in `pageSizes`.
* Column filters accept thousands separators (`>=1,500`), the Arabic comma `،` and Arabic-Indic digits. `ColumnFilterMatcher.parse` compiles an expression for reuse.
* Controller: `exportAs`, `printTable`, `copyToClipboard`, `toggleSort`, `resetAll`, `setCollapsedGroups`, `collapseAllRows`, `snapshot`, `restoreSnapshot`, `aggregates`.
* `TableExportOptions.includeTotals`; new labels (`exportCsv`, `sortBy`, `ascending`, `descending`, `noSorting`, `total`, `sum`, `average`, `minimum`, `maximum`, `count`, `allRows`, `save`, `noMatches`, `selectPlaceholder`, `copied`) in English and Arabic.

### Design
* Column headers stay on empty desktop tables (with the filter row), and loading skeleton rows sit under the real headers, aligned with the column widths.
* Sort arrows only show on sorted columns; the others appear on hover.
* Cards: the title is the first column showing text (no more "1" as a card title) and the subtitle the next column.
* The example app shows every new feature (totals, group-by menu, density, Material 3, persistence across a language switch) and the screenshots were regenerated.

### Behaviour changes
* `ExportFormat` has a new value, `csv` (add a case to exhaustive `switch`es), and CSV is in the default export menu.
* `FilterItemsUseCase` folds Arabic text by default; pass `FilterItemsUseCase(textNormalizer: TableTextNormalizer.caseInsensitive)` (or `textNormalizer:` on the table) for the previous matching.
* `TableCubit.updateConfiguration` only recomputes what changed; call `refresh()` to force a run.
* The card title / subtitle defaults and the desktop empty / loading look changed (see Design).

## 0.1.4

### Skeleton / shimmer loading (new)
* `loadingStyle: TableLoadingStyle.skeleton` shows placeholder rows shaped like the visible columns (placeholder cards on phones) with a shimmer sweep while there are no rows yet — including the first page of a server-side `dataSource`. The default stays `TableLoadingStyle.spinner`, and `loadingWidget` still takes precedence.
* `skeletonRowCount` (default: the page size, at most 10).
* `AdaptiveTableTheme.skeletonBaseColor` / `skeletonHighlightColor` (derived from the row text color by default, so every built-in theme works in light and dark).
* The sweep follows the text direction (RTL) and stops when the platform asks to reduce motion.
* Reusable building blocks: `TableSkeleton`, `TableShimmer`, `SkeletonBox`. No new dependency.

## 0.1.3

### Fixes
* **Date panel popped the page underneath (web / wide screens):** pressing *Apply* in the date range panel closed it with the caller's `Navigator`, not the dialog's. With go_router's `ShellRoute` (a nested navigator under the root one that hosts the dialog) this popped the current page instead, throwing *"You have popped the last page off of the stack"* followed by `!_debugLocked` errors. The panel now closes through its own route context. Covered by a regression test with a nested navigator.

## 0.1.2

### Release automation
* Versions are now published to pub.dev automatically from GitHub Actions when a `v{{version}}` tag is pushed.

### Fixes
* **Column resize in RTL felt inverted:** grid rows were anchored to the left in right-to-left layouts, so widening a column moved the opposite edge. Rows now start at the right in RTL.
* **Resize edge didn't follow the pointer:** flexible columns *before* the resized one absorbed the change. They are now frozen during the drag; only the columns after it adapt. Covered by 8 tests (LTR/RTL × fixed/flex × grow/shrink).

### Date filter redesign (new)
* The two From / To buttons (each opening the same full calendar) are replaced by a single **"Period" button**. It opens a panel with quick periods (all, today, yesterday, last 7 / 30 days, this / last month, this year), a two-month range calendar and typed From / To fields. On phones it opens as a bottom sheet.
* `datePresets` / `DateRangePreset` for custom periods, `showTableDateRangePicker` / `DateRangePanel` for standalone use.
* `dateFilterStyle: DateFilterStyle.separateFields` keeps the previous look.

## 0.1.1

- Fixes and improvements.

## 0.1.0

A full audit and overhaul. The public API is backward compatible: existing code
keeps compiling, and the original tests pass unchanged.

### Bug fixes
* **Date filter:** clearing a date (✕) did nothing because `copyWith` couldn't reset nullable fields. `TableStateModel.copyWith` now has `clearStartDate` / `clearEndDate` / `clearSort`.
* **Columns menu:** toggling a column threw `ProviderNotFoundException` (the popup lives outside the `BlocProvider`), and its checkboxes didn't update.
* **Web export:** nothing was downloaded (the download code was commented out). Rewritten with `package:web`.
* **`showPagination: false`:** only the first 10 rows were ever shown.
* **`pageSizes` without 10:** the rows-per-page dropdown crashed.
* **Data updates:** changing the `items` list in place (add / remove followed by `setState`) did not refresh the table.
* **`TableCubit`** mutated the caller's column list, and crashed when given a `const` list.
* **Exports:** columns hidden by the user were still exported.
* **Word export:** values were not HTML-escaped, so `<`, `&` or quotes broke the document.
* **Excel export:** invalid sheet names (`/`, `:`, more than 31 characters) produced corrupted files. Also fixed the fragile default-sheet deletion.
* **RTL:** pagination arrows were flipped twice, and column alignment ignored RTL.
* **Sorting:** crashed on mixed value types, was case-sensitive, not stable, and placed `null`s inconsistently.
* **Pagination:** the current page was not clamped after filtering or deleting (it showed "No data" while data existed), and an empty table showed "Page 1 of 0".
* **Filters:** the date pickers were shown even without a `dateProvider`. The picker crashed when `initialDate` was outside 2000–2100.
* **Row details:** `expandedRowBuilder` only opened for *selected* rows (impossible when `showSelection: false`), and `onRowTap` was ignored on mobile.
* **Footer:** the page numbers could overflow on phones when there were many pages.
* **Toolbar:** it overflowed on narrow screens, and snackbars used a `BuildContext` across async gaps.
* **Theme:** the default theme was always light, even in dark apps. Many colors were hard-coded blue.
* **Dynamic form:**
  * any name containing "is" (`discount`, `wishlist`…) was detected as a boolean;
  * a required dropdown displayed its first item but submitted `null`;
  * an invalid dropdown initial value crashed;
  * the date field ignored `isRequired`;
  * custom validators only ran for text fields;
  * the internal mutable map was leaked to callers.
* Removed dead placeholder code in `FilterItemsUseCase.execute`, which now works and sorts.
* Fixed every analyzer deprecation (`withOpacity`, `dart:html`, `Share.shareXFiles`, `DropdownButtonFormField.value`, `Switch.activeColor`).

### Advanced grid (new)
* **Frozen columns:** `pin: ColumnPin.start / end`, pin/unpin from the columns menu, LTR and RTL. Implemented with a custom `RenderPinnedRow`.
* **Sticky header + virtualized rows:** `bodyHeight` / `fillHeight`. Only visible rows are built (tested with 100,000 rows).
* **Column resize** (drag the header edge, double-click to reset), **drag & drop reorder** (long-press), and "Reset columns".
* **Per-column filter row** (`showColumnFilters`) with `ColumnFilterMatcher` expressions (`>10`, `10..20`, `=x`, `!=x`, `!x`, dates, `a, b`).
* **Multi-column sort** (Shift + click, `setSorts`, `addSort`) with level badges.
* **Row grouping** (`groupByColumnId`, collapsible groups, `groupHeaderBuilder` with `TableGroupInfo`), on desktop and mobile.
* **Inline cell editing** (`isEditable`, `CellEditor.text / number / dropdown / date / boolean`, `cellValidator`, `onCellEdited`, `canEditCell`), with Enter / Tab / Escape.
* **Keyboard navigation**: arrows, Enter / F2, Space, Tab, Home / End, Page Up / Down, Ctrl + A, Escape.
* **Server-side data:** `AdaptiveTableDataSource` / `TableDataPage`, stale-response protection, automatic last-page clamping, and a Retry button on errors.
* `TableStateModel` gained `additionalSorts`, `columnFilters`, `groupByColumnId`, `sorts`. `TableLoaded` gained `columnWidths`, `columnOrder`, `columnPins`, `collapsedGroups`, `isFetching`, `arrange()` and `pinOf()`.
* Mobile cards are virtualized too when the table has a bounded height.
* Exports follow the user's column order.

### New
* `layoutMode` (`TableLayoutMode.auto` / `table` / `cards`) to force the grid on phones or cards on desktop.
* `onExportRequested` / `onPrintRequested` to plug in your own export and print implementations.
* `AdaptiveTableController` to search, filter, sort, paginate and select from outside.
* `onSelectionChanged`, `onTableStateChanged`, `onRowLongPress`, `rowColorBuilder`, `toolbarActions`, `isLoading`, `showClearFilters`, `showDateFilter`, `initialPageSize`, `initialSortColumnId` / `initialSortAscending`, `mobileBreakpoint`, `mobileTitleColumnId` / `mobileSubtitleColumnId`, `searchDebounce`, `firstDate` / `lastDate`.
* Column options: `valueFormatter`, `isSearchable`, `isExportable`, `isHideable`. `fieldName` is now optional.
* `TableExportOptions`: file name, formats, PDF fonts and page format, "export selected rows only", and a custom `onExport` handler.
* `AdaptiveTableLabels` with English and Arabic built in, chosen from the app locale.
* `AdaptiveTableTheme` is now a `ThemeExtension` (`copyWith`, `lerp`, `AdaptiveTableTheme.of`), with an `adaptive` preset and new `accentColor`, `onAccentColor`, `selectedRowColor`, `titleTextStyle`, `toolbarIconColor`, `summaryBackgroundColor` and `blurSigma`.
* Tri-state "select all", numbered pagination, "Showing 11–20 of 48", a search clear button, a "Clear filters" button, and separate "no data" vs "no results" states.
* PDF: cached Cairo font with a timeout, custom fonts, automatic landscape, column widths and alignments.
* Excel: typed date cells, RTL sheets, automatic column widths.
* Desktop exports are saved to the Downloads folder, and the saved path is shown.
* `TableCubit`: `sortBy`, `clearSort`, `setCustomFilter`, `resetFilters`, `resetAll`, `setSelection`, `setColumnVisibility`, `toggleRowExpansion`, `updateConfiguration`, `nextPage` / `previousPage`. It emits `TableError` instead of crashing.
* `FilterItemsUseCase.apply` returns `TableQueryResult` (with `totalPages` and `effectivePage`). Supports hidden columns and search-only keys.
* `DynamicFormField`: `hint`, `helperText`, `enabled`, `maxLines`, `firstDate` / `lastDate`, `copyWith`, and `inferType` / `tokenize`. `detectFromColumns` gained `fieldTypes`, `excludeIds` and `optionalIds`. `DynamicFormDialog.show` returns the submitted values.

### Behaviour changes
* An empty, optional number field now submits `null` instead of `0`.
* Exports use the selected rows when there is a selection (turn this off with `TableExportOptions(exportSelectedWhenAny: false)`).
* `saveAndShareFile` returns `Future<String?>` (the saved path or file name).

### Project
* 135 package tests + 6 example smoke tests (previously 7), a CI workflow, stricter lints, a rewritten README with screenshots, and a rebuilt example app with all platforms.

## 0.0.2

* **Dynamic Form Generator**: 
  * Implemented `DynamicFormField` schemas with automatic field type detection (inferred from column properties like name patterns for dates, numbers, booleans, and dropdown lists).
  * Created `DynamicForm` and `DynamicFormDialog` with fully-validated inputs, customized actions, and submit callback events.
* **Premium Adaptive Themes**:
  * Added `AdaptiveTableTheme.glassmorphic` featuring iOS-like real-time backdrop blur filter overlay (`BackdropFilter`) and translucency.
  * Added `AdaptiveTableTheme.gradient` implementing styling sweeps across headers and footers.
  * Added `AdaptiveTableTheme.cozy` supporting soft shadows and expanded spacing.
* **CRUD Action Handlers & Settings**:
  * Integrated interactive styling picker inside the AppBar settings.
  * Replaced static action buttons with CRUD dialog triggers utilizing the dynamic forms generator.
* **Validation & Testing**:
  * Added comprehensive unit and widget tests covering type detection, validation logic, and form state submissions.

## 0.0.1

* Initial release of the adaptive data table layout.
* Responsive layouts automatically adapting between desktop data grids and collapsable mobile cards.
* Localized global searching, date-range filtering, and pagination support.
* Multi-currency aggregate bottom banner summary builder.
* Integrated Excel, Word, PDF, and system printing exporters with shaped Arabic font support.
