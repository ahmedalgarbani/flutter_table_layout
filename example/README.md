# flutter_table_layout example

A two-tab dashboard that shows most of the package's features:

- **Account statement:** date and currency filters (a custom filter widget), a
  summary row, selection, expandable rows, simulated loading on refresh, and an
  auto-generated "Add" form.
- **Currencies:** hidden-by-default columns, a non-exportable actions column,
  inline switches, `rowColorBuilder`, and edit/delete via dynamic forms.
- AppBar switches for the theme preset (modern / glass / gradient / cozy),
  dark mode, and Arabic ⇄ English.

```bash
flutter run -d chrome   # or any device
```

`test/screenshots_test.dart` regenerates the README screenshots (see the main README).
