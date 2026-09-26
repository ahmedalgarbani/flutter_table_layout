# Changelog
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

### Fixes
* **Column resize in RTL felt inverted:** grid rows were anchored to the left in right-to-left layouts, so widening a column moved the opposite edge. Rows now start at the right in RTL.
* **Resize edge didn't follow the pointer:** flexible columns *before* the resized one absorbed the change. They are now frozen during the drag; only the columns after it adapt. Covered by 8 tests (LTR/RTL × fixed/flex × grow/shrink).

### Date filter redesign (new)
* The two From / To buttons (each opening the same full calendar) are replaced by a single **"Period" button**. It opens a panel with quick periods (all, today, yesterday, last 7 / 30 days, this / last month, this year), a two-month range calendar and typed From / To fields. On phones it opens as a bottom sheet.
* `datePresets` / `DateRangePreset` for custom periods, `showTableDateRangePicker` / `DateRangePanel` for standalone use.
* `dateFilterStyle: DateFilterStyle.separateFields` keeps the previous look.

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
