import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;
import '../../core/theme.dart';
import 'adaptive_table_layout.dart';

/// The supported data input types for dynamic form fields.
enum FieldType {
  text,
  number,
  dropdown,
  date,
  boolean,
}

/// Description schema of a form input element.
class DynamicFormField {
  final String id;
  final String label;
  final FieldType type;
  final dynamic initialValue;
  final List<String>? dropdownItems;
  final bool isRequired;
  final String? Function(dynamic)? validator;

  DynamicFormField({
    required this.id,
    required this.label,
    required this.type,
    this.initialValue,
    this.dropdownItems,
    this.isRequired = false,
    this.validator,
  });

  /// Automatically generates field schemas by detecting column settings and titles.
  static List<DynamicFormField> detectFromColumns<T>(
    List<AdaptiveTableColumn<T>> columns, {
    Map<String, List<String>>? dropdownItems,
    Map<String, dynamic>? initialValues,
  }) {
    return columns
        .where((col) => col.id != 'actions') // Exclude action grids
        .map((col) {
      final nameLower = col.fieldName.toLowerCase();
      final idLower = col.id.toLowerCase();

      FieldType detectedType = FieldType.text;

      if (dropdownItems != null && dropdownItems.containsKey(col.id)) {
        detectedType = FieldType.dropdown;
      } else if (nameLower.contains('is') ||
          nameLower.contains('active') ||
          nameLower.contains('status') ||
          idLower.contains('status')) {
        detectedType = FieldType.boolean;
      } else if (nameLower.contains('date') || idLower.contains('date')) {
        detectedType = FieldType.date;
      } else if (nameLower.contains('rate') ||
          nameLower.contains('amount') ||
          nameLower.contains('price') ||
          nameLower.contains('equivalent') ||
          idLower == 'id' ||
          idLower == 'index' ||
          idLower == 'num') {
        detectedType = FieldType.number;
      }

      return DynamicFormField(
        id: col.id,
        label: col.title,
        type: detectedType,
        dropdownItems: dropdownItems?[col.id],
        initialValue: initialValues?[col.id],
        isRequired: col.id != 'id', // ID usually auto-generates
      );
    }).toList();
  }
}

/// A dynamic input form populated by schema rules.
class DynamicForm extends StatefulWidget {
  final List<DynamicFormField> fields;
  final ValueChanged<Map<String, dynamic>> onFormSubmitted;
  final String submitLabel;
  final String cancelLabel;
  final VoidCallback onCancel;
  final AdaptiveTableTheme theme;

  const DynamicForm({
    super.key,
    required this.fields,
    required this.onFormSubmitted,
    this.submitLabel = 'Send',
    this.cancelLabel = 'Cancel',
    required this.onCancel,
    required this.theme,
  });

  @override
  State<DynamicForm> createState() => _DynamicFormState();
}

class _DynamicFormState extends State<DynamicForm> {
  final _formKey = GlobalKey<FormState>();
  final Map<String, dynamic> _formValues = {};

  @override
  void initState() {
    super.initState();
    for (final field in widget.fields) {
      _formValues[field.id] = field.initialValue ?? _getDefaultValue(field.type);
    }
  }

  dynamic _getDefaultValue(FieldType type) {
    return switch (type) {
      FieldType.boolean => false,
      FieldType.date => DateTime.now(),
      _ => null,
    };
  }

  @override
  Widget build(BuildContext context) {
    // final isRtl = Directionality.of(context) == TextDirection.rtl;

    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ...widget.fields.map((field) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: _buildFieldInput(field),
            );
          }),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: widget.onCancel,
                child: Text(widget.cancelLabel, style: TextStyle(color: Colors.grey.shade600)),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade600,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () {
                  if (_formKey.currentState!.validate()) {
                    _formKey.currentState!.save();
                    widget.onFormSubmitted(_formValues);
                  }
                },
                child: Text(widget.submitLabel, style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFieldInput(DynamicFormField field) {
    return switch (field.type) {
      FieldType.boolean => _buildBooleanInput(field),
      FieldType.date => _buildDateInput(field),
      FieldType.dropdown => _buildDropdownInput(field),
      FieldType.number => _buildNumberInput(field),
      _ => _buildTextInput(field),
    };
  }

  Widget _buildTextInput(DynamicFormField field) {
    return TextFormField(
      initialValue: _formValues[field.id]?.toString(),
      style: widget.theme.rowTextStyle,
      decoration: _getInputDecoration(field.label),
      validator: (val) {
        if (field.isRequired && (val == null || val.trim().isEmpty)) {
          return 'Field is required';
        }
        if (field.validator != null) {
          return field.validator!(val);
        }
        return null;
      },
      onSaved: (val) => _formValues[field.id] = val,
    );
  }

  Widget _buildNumberInput(DynamicFormField field) {
    return TextFormField(
      initialValue: _formValues[field.id]?.toString(),
      style: widget.theme.rowTextStyle,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: _getInputDecoration(field.label),
      validator: (val) {
        if (field.isRequired && (val == null || val.trim().isEmpty)) {
          return 'Field is required';
        }
        if (val != null && val.isNotEmpty) {
          final number = num.tryParse(val);
          if (number == null) {
            return 'Invalid number format';
          }
        }
        if (field.validator != null) {
          return field.validator!(val);
        }
        return null;
      },
      onSaved: (val) {
        if (val == null || val.isEmpty) {
          _formValues[field.id] = 0;
        } else {
          _formValues[field.id] = num.tryParse(val) ?? 0;
        }
      },
    );
  }

  Widget _buildDropdownInput(DynamicFormField field) {
    final items = field.dropdownItems ?? [];
    return DropdownButtonFormField<String>(
      value: _formValues[field.id]?.toString() ?? (items.isNotEmpty ? items.first : null),
      style: widget.theme.rowTextStyle,
      decoration: _getInputDecoration(field.label),
      dropdownColor: widget.theme.cardBackgroundColor,
      items: items.map((item) {
        return DropdownMenuItem<String>(
          value: item,
          child: Text(item, style: widget.theme.rowTextStyle),
        );
      }).toList(),
      onChanged: (val) {
        setState(() {
          _formValues[field.id] = val;
        });
      },
      validator: (val) {
        if (field.isRequired && (val == null || val.isEmpty)) {
          return 'Selection required';
        }
        return null;
      },
    );
  }

  Widget _buildDateInput(DynamicFormField field) {
    final DateTime currentDate = _formValues[field.id] as DateTime? ?? DateTime.now();
    final dateStr = DateFormat('yyyy-MM-dd').format(currentDate);

    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: currentDate,
          firstDate: DateTime(2000),
          lastDate: DateTime(2100),
        );
        if (picked != null) {
          setState(() {
            _formValues[field.id] = picked;
          });
        }
      },
      child: InputDecorator(
        decoration: _getInputDecoration(field.label).copyWith(
          suffixIcon: Icon(Icons.calendar_today, size: 18, color: widget.theme.actionIconColor),
        ),
        child: Text(
          dateStr,
          style: widget.theme.rowTextStyle,
        ),
      ),
    );
  }

  Widget _buildBooleanInput(DynamicFormField field) {
    final isVal = _formValues[field.id] as bool? ?? false;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8.0),
        border: Border.all(color: widget.theme.dividerColor),
      ),
      child: SwitchListTile(
        title: Text(field.label, style: widget.theme.rowTextStyle.copyWith(fontSize: 13, fontWeight: FontWeight.w500)),
        value: isVal,
        activeColor: Colors.blue.shade600,
        onChanged: (val) {
          setState(() {
            _formValues[field.id] = val;
          });
        },
      ),
    );
  }

  InputDecoration _getInputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: widget.theme.footerTextStyle.copyWith(fontSize: 13),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8.0),
        borderSide: BorderSide(color: widget.theme.dividerColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8.0),
        borderSide: BorderSide(color: widget.theme.dividerColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8.0),
        borderSide: BorderSide(color: Colors.blue.shade500, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8.0),
        borderSide: const BorderSide(color: Colors.red, width: 1.0),
      ),
    );
  }
}

/// A showable popup dialog rendering dynamic field elements.
class DynamicFormDialog extends StatelessWidget {
  final String title;
  final List<DynamicFormField> fields;
  final ValueChanged<Map<String, dynamic>> onSubmitted;
  final String submitLabel;
  final String cancelLabel;
  final AdaptiveTableTheme theme;

  const DynamicFormDialog({
    super.key,
    required this.title,
    required this.fields,
    required this.onSubmitted,
    this.submitLabel = 'Send',
    this.cancelLabel = 'Cancel',
    required this.theme,
  });

  /// Opens the dynamic form modal.
  static Future<void> show(
    BuildContext context, {
    required String title,
    required List<DynamicFormField> fields,
    required ValueChanged<Map<String, dynamic>> onSubmitted,
    String submitLabel = 'Send',
    String cancelLabel = 'Cancel',
    required AdaptiveTableTheme theme,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return DynamicFormDialog(
          title: title,
          fields: fields,
          onSubmitted: onSubmitted,
          submitLabel: submitLabel,
          cancelLabel: cancelLabel,
          theme: theme,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: theme.borderRadius),
      backgroundColor: theme.cardBackgroundColor,
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
                  style: theme.headerTextStyle.copyWith(fontSize: 18),
                ),
                const SizedBox(height: 8),
                const Divider(),
                const SizedBox(height: 16),
                DynamicForm(
                  fields: fields,
                  onFormSubmitted: (values) {
                    Navigator.of(context).pop();
                    onSubmitted(values);
                  },
                  submitLabel: submitLabel,
                  cancelLabel: cancelLabel,
                  onCancel: () => Navigator.of(context).pop(),
                  theme: theme,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
