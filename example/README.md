# flutter_table_layout example

A four-tab dashboard that shows most of the package's features:

- **Account statement:** date and currency filters (a custom filter widget), a
  summary row, selection, expandable rows, simulated loading on refresh, and an
  auto-generated "Add" form.
- **Currencies:** hidden-by-default columns, a non-exportable actions column,
  inline switches, `rowColorBuilder`, and edit/delete via dynamic forms.
- **Advanced grid:** 2,000 employees in a full-height virtualized grid with
  frozen columns (start and end), a per-column filter row, grouping with
  aggregates, inline editing (text / number / dropdown / date / boolean),
  an edit-permission switch, and keyboard navigation.
- **Server data:** a fake API with latency that filters, sorts and paginates
  10,000 rows through `AdaptiveTableDataSource`.
- AppBar switches for the theme preset (modern / glass / gradient / cozy),
  dark mode, and Arabic ⇄ English.

```bash
flutter run -d chrome   # or any device
```

`test/screenshots_test.dart` regenerates the README screenshots (see the main README).
