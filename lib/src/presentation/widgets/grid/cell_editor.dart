import 'package:flutter/services.dart';

/// Input used when a cell is edited inline.
enum CellEditorType { text, number, dropdown, date, boolean }

/// Configures inline editing of a column (desktop grid).
///
/// When a column is `isEditable` without an explicit editor, the type is
/// inferred from the current value: `num` → number, `DateTime` → date,
/// `bool` → boolean, anything else → text.
class CellEditor {
  final CellEditorType type;

  /// Options of a [CellEditorType.dropdown] editor.
  final List<Object?> options;

  /// Label of each dropdown option (defaults to `toString()`).
  final String Function(Object? option)? optionLabel;

  /// Date range of a [CellEditorType.date] editor.
  final DateTime? firstDate;
  final DateTime? lastDate;

  /// Extra input formatters of text / number editors.
  final List<TextInputFormatter>? inputFormatters;

  const CellEditor.text({this.inputFormatters})
    : type = CellEditorType.text,
      options = const [],
      optionLabel = null,
      firstDate = null,
      lastDate = null;

  const CellEditor.number({this.inputFormatters})
    : type = CellEditorType.number,
      options = const [],
      optionLabel = null,
      firstDate = null,
      lastDate = null;

  const CellEditor.dropdown(this.options, {this.optionLabel})
    : type = CellEditorType.dropdown,
      firstDate = null,
      lastDate = null,
      inputFormatters = null;

  const CellEditor.date({this.firstDate, this.lastDate})
    : type = CellEditorType.date,
      options = const [],
      optionLabel = null,
      inputFormatters = null;

  const CellEditor.boolean()
    : type = CellEditorType.boolean,
      options = const [],
      optionLabel = null,
      firstDate = null,
      lastDate = null,
      inputFormatters = null;

  /// Infers an editor from a current cell value.
  static CellEditor infer(Object? value) => switch (value) {
    num() => const CellEditor.number(),
    DateTime() => const CellEditor.date(),
    bool() => const CellEditor.boolean(),
    _ => const CellEditor.text(),
  };
}
