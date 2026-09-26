import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../../core/labels.dart';
import '../../core/theme.dart';
import 'adaptive_table_layout.dart';

/// The supported data input types for dynamic form fields.
enum FieldType {
  text,
  number,
  dropdown,
  date,
  boolean,
  multiSelect,
  relationship,
}

/// Description schema of a form input element.
class DynamicFormField {
  /// Key of the value in the submitted map.
  final String id;

  /// Field label.
  final String label;

  /// Input widget type.
  final FieldType type;

  /// Initial value: `String` (text / dropdown), `num` (number), `DateTime`
  /// (date), or `bool` (boolean).
  final dynamic initialValue;

  /// Options of a [FieldType.dropdown] field.
  final List<String>? dropdownItems;

  /// Whether the field must be filled.
  final bool isRequired;

  /// Extra validation. Receives the current value (`String?` for text /
  /// number / dropdown, `DateTime?` for date, `bool` for boolean) and returns
  /// an error message or `null`.
  final String? Function(dynamic)? validator;

  /// Placeholder text.
  final String? hint;

  /// Helper text shown under the field.
  final String? helperText;

  /// When `false` the field is shown read-only.
  final bool enabled;

  /// Lines of a text field (> 1 for multi-line input).
  final int maxLines;

  /// Earliest selectable date for [FieldType.date].
  final DateTime? firstDate;

  /// Latest selectable date for [FieldType.date].
  final DateTime? lastDate;

  /// Whether a [FieldType.relationship] field accepts several selections.
  final bool isMultiSelect;

  /// Callback to create a new option / instance inline. When provided, a
  /// `+` button is shown next to the dropdown or selector.
  final Future<String?> Function(BuildContext)? onAddInstance;

  /// Custom lookup / search dialog handler for [FieldType.relationship].
  final Future<List<String>?> Function(BuildContext, List<String>)?
  onSearchRelationship;

  /// Optional custom controller for text-based inputs.
  final TextEditingController? controller;

  DynamicFormField({
    required this.id,
    required this.label,
    required this.type,
    this.initialValue,
    this.dropdownItems,
    this.isRequired = false,
    this.validator,
    this.hint,
    this.helperText,
    this.enabled = true,
    this.maxLines = 1,
    this.firstDate,
    this.lastDate,
    this.isMultiSelect = false,
    this.onAddInstance,
    this.onSearchRelationship,
    this.controller,
  });

  DynamicFormField copyWith({
    String? label,
    FieldType? type,
    dynamic initialValue,
    List<String>? dropdownItems,
    bool? isRequired,
    String? Function(dynamic)? validator,
    String? hint,
    String? helperText,
    bool? enabled,
    int? maxLines,
    DateTime? firstDate,
    DateTime? lastDate,
    bool? isMultiSelect,
    Future<String?> Function(BuildContext)? onAddInstance,
    Future<List<String>?> Function(BuildContext, List<String>)?
    onSearchRelationship,
    TextEditingController? controller,
  }) {
    return DynamicFormField(
      id: id,
      label: label ?? this.label,
      type: type ?? this.type,
      initialValue: initialValue ?? this.initialValue,
      dropdownItems: dropdownItems ?? this.dropdownItems,
      isRequired: isRequired ?? this.isRequired,
      validator: validator ?? this.validator,
      hint: hint ?? this.hint,
      helperText: helperText ?? this.helperText,
      enabled: enabled ?? this.enabled,
      maxLines: maxLines ?? this.maxLines,
      firstDate: firstDate ?? this.firstDate,
      lastDate: lastDate ?? this.lastDate,
      isMultiSelect: isMultiSelect ?? this.isMultiSelect,
      onAddInstance: onAddInstance ?? this.onAddInstance,
      onSearchRelationship: onSearchRelationship ?? this.onSearchRelationship,
      controller: controller ?? this.controller,
    );
  }

  static const _booleanPrefixes = {'is', 'has', 'can', 'should', 'allow'};
  static const _booleanWords = {'active', 'enabled', 'status', 'visible'};
  static const _dateWords = {'date', 'day', 'birthday', 'dob', 'time'};
  static const _dateSuffixes = {'at', 'on'};
  static const _numberWords = {
    'id', 'index', 'num', 'number', 'count', 'qty', 'quantity', 'rate', //
    'amount', 'price', 'total', 'cost', 'equivalent', 'balance', 'age',
    'salary', 'percent', 'percentage', 'score', 'sum', 'fee', 'tax',
    'discount', 'min', 'max',
  };

  /// Splits `createdAt`, `created_at`, `Created At`, `created-at` into
  /// `[created, at]`.
  static List<String> tokenize(String name) {
    final spaced = name
        .replaceAllMapped(
          RegExp(r'([a-z0-9])([A-Z])'),
          (m) => '${m[1]} ${m[2]}',
        )
        .replaceAll(RegExp(r'[_\-\s.]+'), ' ')
        .trim()
        .toLowerCase();
    return spaced.isEmpty ? const [] : spaced.split(' ');
  }

  /// Infers a [FieldType] from a column id / field name (whole words only,
  /// so `discount` is not mistaken for a boolean because it contains "is").
  static FieldType inferType(String id, String fieldName) {
    for (final tokens in [tokenize(fieldName), tokenize(id)]) {
      if (tokens.isEmpty) continue;
      if (_booleanPrefixes.contains(tokens.first) && tokens.length > 1) {
        return FieldType.boolean;
      }
      if (tokens.any(_booleanWords.contains)) return FieldType.boolean;
    }
    for (final tokens in [tokenize(fieldName), tokenize(id)]) {
      if (tokens.isEmpty) continue;
      if (tokens.any(_dateWords.contains) ||
          (tokens.length > 1 && _dateSuffixes.contains(tokens.last))) {
        return FieldType.date;
      }
    }
    for (final tokens in [tokenize(fieldName), tokenize(id)]) {
      if (tokens.any(_numberWords.contains)) return FieldType.number;
    }
    return FieldType.text;
  }

  /// Automatically generates field schemas by detecting column settings and titles.
  ///
  /// * [dropdownItems] – columns rendered as dropdowns, with their options.
  /// * [initialValues] – pre-filled values (e.g. when editing a row).
  /// * [fieldTypes] – explicit type overrides that win over detection.
  /// * [excludeIds] – columns to skip (defaults to `{'actions'}`). Columns
  ///   with `isExportable: false` are skipped too.
  /// * [optionalIds] – columns that are not required (defaults to `{'id'}`).
  static List<DynamicFormField> detectFromColumns<T>(
    List<AdaptiveTableColumn<T>> columns, {
    Map<String, List<String>>? dropdownItems,
    Map<String, dynamic>? initialValues,
    Map<String, FieldType>? fieldTypes,
    Set<String> excludeIds = const {'actions'},
    Set<String> optionalIds = const {'id'},
  }) {
    return columns
        .where((col) => !excludeIds.contains(col.id) && col.isExportable)
        .map((col) {
          final FieldType type;
          if (fieldTypes?.containsKey(col.id) ?? false) {
            type = fieldTypes![col.id]!;
          } else if (dropdownItems?.containsKey(col.id) ?? false) {
            type = FieldType.dropdown;
          } else {
            type = inferType(col.id, col.fieldName);
          }
          return DynamicFormField(
            id: col.id,
            label: col.title,
            type: type,
            dropdownItems: dropdownItems?[col.id],
            initialValue: initialValues?[col.id],
            isRequired: !optionalIds.contains(col.id),
          );
        })
        .toList();
  }
}

/// A dynamic input form populated by schema rules.
///
/// Submitted values: `String?` (text / dropdown), `num?` (number, `null` when
/// left empty), `DateTime` (date), `bool` (boolean).
class DynamicForm extends StatefulWidget {
  final List<DynamicFormField> fields;
  final ValueChanged<Map<String, dynamic>> onFormSubmitted;

  /// Submit button text. Defaults to the `send` label.
  final String? submitLabel;

  /// Cancel button text. Defaults to the `cancel` label.
  final String? cancelLabel;

  /// Hides the cancel button when `null`.
  final VoidCallback? onCancel;

  /// Defaults to [AdaptiveTableTheme.of].
  final AdaptiveTableTheme? theme;

  /// Defaults to [AdaptiveTableLabels.of].
  final AdaptiveTableLabels? labels;

  const DynamicForm({
    super.key,
    required this.fields,
    required this.onFormSubmitted,
    this.submitLabel,
    this.cancelLabel,
    this.onCancel,
    this.theme,
    this.labels,
  });

  @override
  State<DynamicForm> createState() => _DynamicFormState();
}

class _DynamicFormState extends State<DynamicForm> {
  final _formKey = GlobalKey<FormState>();
  final Map<String, dynamic> _formValues = {};
  final Map<String, TextEditingController> _controllers = {};
  final Map<String, List<String>> _fieldOptions = {};
  final Map<String, GlobalKey<FormFieldState<String>>> _dropdownKeys = {};

  late AdaptiveTableTheme _theme;
  late AdaptiveTableLabels _labels;

  @override
  void initState() {
    super.initState();
    for (final field in widget.fields) {
      final initialValue = _initialValueFor(field);
      _formValues[field.id] = initialValue;
      _fieldOptions[field.id] = List<String>.from(
        field.dropdownItems ?? const <String>[],
      );
      if (field.type == FieldType.text || field.type == FieldType.number) {
        _controllers[field.id] =
            field.controller ??
            TextEditingController(text: initialValue?.toString() ?? '');
      }
    }
  }

  @override
  void dispose() {
    for (final field in widget.fields) {
      if (field.controller == null) _controllers[field.id]?.dispose();
    }
    super.dispose();
  }

  static List<String> _stringList(dynamic value) {
    if (value is Iterable) return value.map((e) => e.toString()).toList();
    return <String>[];
  }

  dynamic _initialValueFor(DynamicFormField field) {
    final v = field.initialValue;
    switch (field.type) {
      case FieldType.boolean:
        return v is bool ? v : false;
      case FieldType.date:
        if (v is DateTime) return v;
        if (v is String) return DateTime.tryParse(v) ?? DateTime.now();
        return DateTime.now();
      case FieldType.dropdown:
        final items = field.dropdownItems ?? const <String>[];
        final s = v?.toString();
        if (s != null && items.contains(s)) return s;
        return field.isRequired && items.isNotEmpty ? items.first : null;
      case FieldType.number:
        if (v is num) return v;
        return v == null ? null : num.tryParse(v.toString());
      case FieldType.text:
        return v?.toString();
      case FieldType.multiSelect:
        return _stringList(v);
      case FieldType.relationship:
        return field.isMultiSelect ? _stringList(v) : v?.toString();
    }
  }

  @override
  Widget build(BuildContext context) {
    _theme = widget.theme ?? AdaptiveTableTheme.of(context);
    _labels = widget.labels ?? AdaptiveTableLabels.of(context);

    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final field in widget.fields)
            Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: _buildFieldInput(field),
            ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (widget.onCancel != null) ...[
                TextButton(
                  onPressed: widget.onCancel,
                  child: Text(
                    widget.cancelLabel ?? _labels.cancel,
                    style: TextStyle(color: _theme.footerTextStyle.color),
                  ),
                ),
                const SizedBox(width: 12),
              ],
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _theme.accentColor,
                  foregroundColor: _theme.onAccentColor,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: _submit,
                child: Text(
                  widget.submitLabel ?? _labels.send,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _submit() {
    final form = _formKey.currentState!;
    if (!form.validate()) return;
    form.save();
    widget.onFormSubmitted(Map<String, dynamic>.of(_formValues));
  }

  String? _runValidator(DynamicFormField field, dynamic value) =>
      field.validator?.call(value);

  Widget _buildFieldInput(DynamicFormField field) {
    return switch (field.type) {
      FieldType.boolean => _buildBooleanInput(field),
      FieldType.date => _buildDateInput(field),
      FieldType.dropdown => _buildDropdownInput(field),
      FieldType.number => _buildNumberInput(field),
      FieldType.text => _buildTextInput(field),
      FieldType.multiSelect => _buildMultiSelectInput(field),
      FieldType.relationship => _buildRelationshipInput(field),
    };
  }

  /// Adds a trailing `+` button that creates a new option through
  /// [DynamicFormField.onAddInstance] and selects it.
  Widget _wrapWithAddButton(
    DynamicFormField field,
    Widget child, {
    required ValueChanged<String> onAdded,
  }) {
    if (field.onAddInstance == null) return child;
    return Row(
      children: [
        Expanded(child: child),
        const SizedBox(width: 8),
        IconButton(
          icon: const Icon(Icons.add_circle, color: Colors.blue),
          tooltip: '${_labels.addNew} ${field.label}',
          onPressed: () async {
            final newValue = await field.onAddInstance!(context);
            if (newValue == null || newValue.isEmpty) return;
            final items = _fieldOptions.putIfAbsent(field.id, () => []);
            setState(() {
              if (!items.contains(newValue)) items.add(newValue);
            });
            onAdded(newValue);
          },
        ),
      ],
    );
  }

  Widget _buildTextInput(DynamicFormField field) {
    return TextFormField(
      controller: _controllers[field.id],
      enabled: field.enabled,
      maxLines: field.maxLines,
      minLines: 1,
      style: _theme.rowTextStyle,
      cursorColor: _theme.accentColor,
      decoration: _getInputDecoration(field),
      validator: (val) {
        if (field.isRequired && (val == null || val.trim().isEmpty)) {
          return _labels.fieldRequired;
        }
        return _runValidator(field, val);
      },
      onSaved: (val) => _formValues[field.id] = val,
    );
  }

  Widget _buildNumberInput(DynamicFormField field) {
    return TextFormField(
      controller: _controllers[field.id],
      enabled: field.enabled,
      style: _theme.rowTextStyle,
      cursorColor: _theme.accentColor,
      keyboardType: const TextInputType.numberWithOptions(
        decimal: true,
        signed: true,
      ),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'[0-9.,\-]')),
      ],
      decoration: _getInputDecoration(field),
      validator: (val) {
        final text = val?.trim() ?? '';
        if (field.isRequired && text.isEmpty) return _labels.fieldRequired;
        if (text.isNotEmpty && _parseNum(text) == null) {
          return _labels.invalidNumber;
        }
        return _runValidator(field, val);
      },
      onSaved: (val) {
        final text = val?.trim() ?? '';
        _formValues[field.id] = text.isEmpty ? null : _parseNum(text);
      },
    );
  }

  /// Accepts `1234.5` and `1,234.5`.
  static num? _parseNum(String text) =>
      num.tryParse(text) ?? num.tryParse(text.replaceAll(',', ''));

  Widget _buildDropdownInput(DynamicFormField field) {
    final items = _fieldOptions[field.id] ?? const <String>[];
    final child = DropdownButtonFormField<String>(
      key: _dropdownKeys.putIfAbsent(
        field.id,
        GlobalKey<FormFieldState<String>>.new,
      ),
      initialValue: _formValues[field.id] as String?,
      style: _theme.rowTextStyle,
      decoration: _getInputDecoration(field),
      dropdownColor: _theme.cardBackgroundColor.withValues(alpha: 1),
      isExpanded: true,
      items: [
        for (final item in items)
          DropdownMenuItem<String>(
            value: item,
            child: Text(item, style: _theme.rowTextStyle),
          ),
      ],
      onChanged: field.enabled
          ? (val) => setState(() => _formValues[field.id] = val)
          : null,
      validator: (val) {
        if (field.isRequired && (val == null || val.isEmpty)) {
          return _labels.selectionRequired;
        }
        return _runValidator(field, val);
      },
      onSaved: (val) => _formValues[field.id] = val,
    );

    return _wrapWithAddButton(
      field,
      child,
      onAdded: (newValue) {
        setState(() => _formValues[field.id] = newValue);
        _dropdownKeys[field.id]?.currentState?.didChange(newValue);
      },
    );
  }

  Widget _buildMultiSelectInput(DynamicFormField field) {
    final items = _fieldOptions[field.id] ?? <String>[];
    return FormField<List<String>>(
      initialValue: List<String>.from(_stringList(_formValues[field.id])),
      validator: (val) {
        if (field.isRequired && (val == null || val.isEmpty)) {
          return _labels.selectionRequired;
        }
        return _runValidator(field, val);
      },
      onSaved: (val) => _formValues[field.id] = val,
      builder: (state) {
        final currentValues = state.value ?? const <String>[];
        final child = InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: !field.enabled
              ? null
              : () async {
                  final result = await showDialog<List<String>>(
                    context: context,
                    builder: (context) => SearchSelectDialog(
                      title: field.label,
                      items: items,
                      initialSelected: currentValues,
                      isMultiSelect: true,
                      theme: _theme,
                      onAddInstance: field.onAddInstance,
                    ),
                  );
                  if (result == null) return;
                  state.didChange(result);
                  for (final val in result) {
                    if (!items.contains(val)) items.add(val);
                  }
                },
          child: InputDecorator(
            decoration: _getInputDecoration(field).copyWith(
              errorText: state.errorText,
              enabled: field.enabled,
              suffixIcon: Icon(
                Icons.arrow_drop_down,
                color: _theme.actionIconColor,
              ),
            ),
            child: currentValues.isEmpty
                ? Text(
                    'Select ${field.label}...',
                    style: _theme.rowTextStyle.copyWith(
                      color: Colors.grey.shade500,
                    ),
                  )
                : _buildChips(currentValues, (val) {
                    state.didChange(
                      List<String>.from(currentValues)..remove(val),
                    );
                  }),
          ),
        );
        return _wrapWithAddButton(
          field,
          child,
          onAdded: (newValue) {
            state.didChange(
              List<String>.from(state.value ?? const <String>[])..add(newValue),
            );
          },
        );
      },
    );
  }

  Widget _buildRelationshipInput(DynamicFormField field) {
    final items = _fieldOptions[field.id] ?? <String>[];
    final isMulti = field.isMultiSelect;

    if (isMulti) {
      return FormField<List<String>>(
        initialValue: List<String>.from(_stringList(_formValues[field.id])),
        validator: (val) {
          if (field.isRequired && (val == null || val.isEmpty)) {
            return _labels.selectionRequired;
          }
          return _runValidator(field, val);
        },
        onSaved: (val) => _formValues[field.id] = val,
        builder: (state) {
          final currentValues = state.value ?? const <String>[];
          final child = InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: !field.enabled
                ? null
                : () async {
                    List<String>? result;
                    if (field.onSearchRelationship != null) {
                      result = await field.onSearchRelationship!(
                        context,
                        currentValues,
                      );
                    } else {
                      result = await showDialog<List<String>>(
                        context: context,
                        builder: (context) => SearchSelectDialog(
                          title: field.label,
                          items: items,
                          initialSelected: currentValues,
                          isMultiSelect: true,
                          theme: _theme,
                          onAddInstance: field.onAddInstance,
                        ),
                      );
                    }
                    if (result == null) return;
                    state.didChange(result);
                    for (final val in result) {
                      if (!items.contains(val)) items.add(val);
                    }
                  },
            child: InputDecorator(
              decoration: _getInputDecoration(field).copyWith(
                errorText: state.errorText,
                enabled: field.enabled,
                suffixIcon: Icon(
                  Icons.search,
                  size: 18,
                  color: _theme.actionIconColor,
                ),
              ),
              child: currentValues.isEmpty
                  ? Text(
                      'Select ${field.label}...',
                      style: _theme.rowTextStyle.copyWith(
                        color: Colors.grey.shade500,
                      ),
                    )
                  : _buildChips(currentValues, (val) {
                      state.didChange(
                        List<String>.from(currentValues)..remove(val),
                      );
                    }),
            ),
          );
          return _wrapWithAddButton(
            field,
            child,
            onAdded: (newValue) {
              state.didChange(
                List<String>.from(state.value ?? const <String>[])
                  ..add(newValue),
              );
            },
          );
        },
      );
    }

    return FormField<String>(
      initialValue: _formValues[field.id]?.toString(),
      validator: (val) {
        if (field.isRequired && (val == null || val.isEmpty)) {
          return _labels.selectionRequired;
        }
        return _runValidator(field, val);
      },
      onSaved: (val) => _formValues[field.id] = val,
      builder: (state) {
        final currentValue = state.value;
        final child = InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: !field.enabled
              ? null
              : () async {
                  List<String>? result;
                  if (field.onSearchRelationship != null) {
                    result = await field.onSearchRelationship!(context, [
                      if (currentValue != null) currentValue,
                    ]);
                  } else {
                    result = await showDialog<List<String>>(
                      context: context,
                      builder: (context) => SearchSelectDialog(
                        title: field.label,
                        items: items,
                        initialSelected: [
                          if (currentValue != null) currentValue,
                        ],
                        isMultiSelect: false,
                        theme: _theme,
                        onAddInstance: field.onAddInstance,
                      ),
                    );
                  }
                  if (result == null || result.isEmpty) return;
                  state.didChange(result.first);
                  if (!items.contains(result.first)) items.add(result.first);
                },
          child: InputDecorator(
            decoration: _getInputDecoration(field).copyWith(
              errorText: state.errorText,
              enabled: field.enabled,
              suffixIcon: Icon(
                Icons.search,
                size: 18,
                color: _theme.actionIconColor,
              ),
            ),
            child: currentValue == null || currentValue.isEmpty
                ? Text(
                    'Select ${field.label}...',
                    style: _theme.rowTextStyle.copyWith(
                      color: Colors.grey.shade500,
                    ),
                  )
                : Text(currentValue, style: _theme.rowTextStyle),
          ),
        );
        return _wrapWithAddButton(field, child, onAdded: state.didChange);
      },
    );
  }

  Widget _buildChips(List<String> values, ValueChanged<String> onDeleted) {
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: [
        for (final val in values)
          Chip(
            label: Text(val, style: _theme.rowTextStyle.copyWith(fontSize: 12)),
            padding: EdgeInsets.zero,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            onDeleted: () => onDeleted(val),
          ),
      ],
    );
  }

  Widget _buildDateInput(DynamicFormField field) {
    return FormField<DateTime>(
      initialValue: _formValues[field.id] as DateTime?,
      validator: (val) {
        if (field.isRequired && val == null) return _labels.fieldRequired;
        return _runValidator(field, val);
      },
      onSaved: (val) => _formValues[field.id] = val,
      builder: (state) {
        final current = state.value;
        return InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: !field.enabled
              ? null
              : () async {
                  final first = field.firstDate ?? DateTime(1900);
                  final last = field.lastDate ?? DateTime(2200);
                  var initial = current ?? DateTime.now();
                  if (initial.isBefore(first)) initial = first;
                  if (initial.isAfter(last)) initial = last;
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: initial,
                    firstDate: first,
                    lastDate: last,
                  );
                  if (picked != null) {
                    state.didChange(picked);
                    _formValues[field.id] = picked;
                  }
                },
          child: InputDecorator(
            decoration: _getInputDecoration(field).copyWith(
              errorText: state.errorText,
              enabled: field.enabled,
              suffixIcon: Icon(
                Icons.calendar_today,
                size: 18,
                color: _theme.actionIconColor,
              ),
            ),
            isEmpty: current == null,
            child: Text(
              current == null ? '' : DateFormat('yyyy-MM-dd').format(current),
              style: _theme.rowTextStyle,
            ),
          ),
        );
      },
    );
  }

  Widget _buildBooleanInput(DynamicFormField field) {
    return FormField<bool>(
      initialValue: _formValues[field.id] as bool? ?? false,
      validator: (val) => _runValidator(field, val),
      onSaved: (val) => _formValues[field.id] = val ?? false,
      builder: (state) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8.0),
                border: Border.all(
                  color: state.hasError
                      ? _theme.statusNegativeColor
                      : _theme.dividerColor,
                ),
              ),
              child: SwitchListTile(
                title: Text(
                  field.label,
                  style: _theme.rowTextStyle.copyWith(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                subtitle: field.helperText == null
                    ? null
                    : Text(field.helperText!, style: _theme.footerTextStyle),
                value: state.value ?? false,
                activeThumbColor: _theme.accentColor,
                onChanged: field.enabled
                    ? (val) {
                        state.didChange(val);
                        _formValues[field.id] = val;
                      }
                    : null,
              ),
            ),
            if (state.hasError)
              Padding(
                padding: const EdgeInsetsDirectional.only(start: 12, top: 6),
                child: Text(
                  state.errorText!,
                  style: TextStyle(
                    color: _theme.statusNegativeColor,
                    fontSize: 12,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  InputDecoration _getInputDecoration(DynamicFormField field) {
    OutlineInputBorder border(Color color, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.0),
          borderSide: BorderSide(color: color, width: width),
        );
    return InputDecoration(
      labelText: field.label,
      hintText: field.hint,
      helperText: field.helperText,
      labelStyle: _theme.footerTextStyle.copyWith(fontSize: 13),
      hintStyle: _theme.footerTextStyle.copyWith(fontSize: 12),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: border(_theme.dividerColor),
      enabledBorder: border(_theme.dividerColor),
      disabledBorder: border(_theme.dividerColor.withValues(alpha: 0.5)),
      focusedBorder: border(_theme.accentColor, 1.5),
      errorBorder: border(_theme.statusNegativeColor),
      focusedErrorBorder: border(_theme.statusNegativeColor, 1.5),
    );
  }
}

/// A search-and-select popup dialog for single and multiple selections.
///
/// Used by [FieldType.multiSelect] and [FieldType.relationship] fields.
class SearchSelectDialog extends StatefulWidget {
  final String title;
  final List<String> items;
  final List<String> initialSelected;
  final bool isMultiSelect;
  final AdaptiveTableTheme theme;
  final Future<String?> Function(BuildContext)? onAddInstance;

  const SearchSelectDialog({
    super.key,
    required this.title,
    required this.items,
    required this.initialSelected,
    required this.isMultiSelect,
    required this.theme,
    this.onAddInstance,
  });

  @override
  State<SearchSelectDialog> createState() => _SearchSelectDialogState();
}

class _SearchSelectDialogState extends State<SearchSelectDialog> {
  final List<String> _localItems = [];
  final Set<String> _selectedItems = {};
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _localItems.addAll(widget.items);
    _selectedItems.addAll(widget.initialSelected);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<String> get _filteredItems {
    if (_searchQuery.isEmpty) return _localItems;
    final query = _searchQuery.toLowerCase();
    return _localItems
        .where((item) => item.toLowerCase().contains(query))
        .toList();
  }

  Future<void> _addInstance() async {
    final newItem = await widget.onAddInstance!(context);
    if (newItem == null || newItem.isEmpty || !mounted) return;
    setState(() {
      if (!_localItems.contains(newItem)) _localItems.add(newItem);
      if (widget.isMultiSelect) {
        _selectedItems.add(newItem);
      } else {
        _selectedItems
          ..clear()
          ..add(newItem);
        Navigator.of(context).pop(_selectedItems.toList());
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    final filtered = _filteredItems;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: theme.borderRadius),
      backgroundColor: theme.cardBackgroundColor,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400, maxHeight: 500),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.title,
                style: theme.headerTextStyle.copyWith(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      style: theme.rowTextStyle,
                      decoration: InputDecoration(
                        hintText: 'Search...',
                        hintStyle: theme.footerTextStyle.copyWith(fontSize: 13),
                        prefixIcon: Icon(
                          Icons.search,
                          size: 18,
                          color: theme.actionIconColor,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onChanged: (val) => setState(() => _searchQuery = val),
                    ),
                  ),
                  if (widget.onAddInstance != null) ...[
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.add_circle, color: Colors.blue),
                      onPressed: _addInstance,
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: filtered.isEmpty
                    ? Center(
                        child: Text(
                          'No items found',
                          style: theme.rowTextStyle.copyWith(
                            color: Colors.grey,
                          ),
                        ),
                      )
                    : ListView.builder(
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final item = filtered[index];
                          final isSelected = _selectedItems.contains(item);
                          if (widget.isMultiSelect) {
                            return CheckboxListTile(
                              title: Text(item, style: theme.rowTextStyle),
                              value: isSelected,
                              activeColor: Colors.blue.shade600,
                              onChanged: (val) => setState(() {
                                if (val == true) {
                                  _selectedItems.add(item);
                                } else {
                                  _selectedItems.remove(item);
                                }
                              }),
                            );
                          }
                          return RadioGroup<String>(
                            groupValue: isSelected ? item : null,
                            onChanged: (val) {
                              if (val != null) {
                                Navigator.of(context).pop([val]);
                              }
                            },
                            child: RadioListTile<String>(
                              title: Text(item, style: theme.rowTextStyle),
                              value: item,
                              activeColor: Colors.blue.shade600,
                            ),
                          );
                        },
                      ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                  if (widget.isMultiSelect) ...[
                    const SizedBox(width: 8),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade600,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: () =>
                          Navigator.of(context).pop(_selectedItems.toList()),
                      child: const Text('Save'),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A showable popup dialog rendering dynamic field elements.
class DynamicFormDialog extends StatelessWidget {
  final String title;
  final List<DynamicFormField> fields;
  final ValueChanged<Map<String, dynamic>>? onSubmitted;
  final String? submitLabel;
  final String? cancelLabel;
  final AdaptiveTableTheme? theme;
  final AdaptiveTableLabels? labels;

  const DynamicFormDialog({
    super.key,
    required this.title,
    required this.fields,
    this.onSubmitted,
    this.submitLabel,
    this.cancelLabel,
    this.theme,
    this.labels,
  });

  /// Opens the dynamic form modal.
  ///
  /// Completes with the submitted values, or `null` when cancelled.
  static Future<Map<String, dynamic>?> show(
    BuildContext context, {
    required String title,
    required List<DynamicFormField> fields,
    ValueChanged<Map<String, dynamic>>? onSubmitted,
    String? submitLabel,
    String? cancelLabel,
    AdaptiveTableTheme? theme,
    AdaptiveTableLabels? labels,
    bool barrierDismissible = false,
  }) {
    return showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: barrierDismissible,
      builder: (context) {
        return DynamicFormDialog(
          title: title,
          fields: fields,
          onSubmitted: onSubmitted,
          submitLabel: submitLabel,
          cancelLabel: cancelLabel,
          theme: theme,
          labels: labels,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = theme ?? AdaptiveTableTheme.of(context);
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: t.borderRadius),
      backgroundColor: t.cardBackgroundColor.withValues(alpha: 1),
      elevation: 24,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  title,
                  style: t.rowTextStyle.copyWith(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Divider(color: t.dividerColor),
                const SizedBox(height: 16),
                DynamicForm(
                  fields: fields,
                  onFormSubmitted: (values) {
                    Navigator.of(context).pop(values);
                    onSubmitted?.call(values);
                  },
                  submitLabel: submitLabel,
                  cancelLabel: cancelLabel,
                  onCancel: () => Navigator.of(context).pop(),
                  theme: t,
                  labels: labels,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
