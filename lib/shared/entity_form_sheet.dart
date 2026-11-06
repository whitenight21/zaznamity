import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'amount_parser.dart';
import 'zaznamity_palette.dart';

// One bottom sheet for adding AND editing budgets, liabilities, goals and more.
//
// You describe the form as a list of fields; the sheet returns a map of values
// (or null if cancelled). Amount fields accept "12,50" and "12.50".
//
// ---- Budget (add; pass `initial:` values to edit) ---------------------------
//
//   final v = await showEntityFormSheet(
//     context,
//     title: 'Add Budget',
//     submitLabel: 'Save',
//     fields: [
//       FormFieldSpec.dropdown(
//         key: 'label', label: 'Category / Label',
//         options: [for (final l in labels) FormOption(l.id, l.name)],
//         initial: labels.isNotEmpty ? labels.first.id : null,
//       ),
//       FormFieldSpec.dropdown(
//         key: 'owner', label: 'Owner',
//         options: [for (final o in owners) FormOption(o, o)],
//         initial: owners.isNotEmpty ? owners.first : null,
//       ),
//       FormFieldSpec.amount(key: 'limit', label: 'Monthly limit', prefix: Money.symbol('EUR')),
//     ],
//   );
//   if (v != null) onAddBudget(v['label'] as int, v['limit'] as double, v['owner'] as String);
//
// ---- Liability, with a soft warning ----------------------------------------
//
//   final v = await showEntityFormSheet(
//     context,
//     title: 'Add Liability',
//     fields: [
//       FormFieldSpec.text(key: 'name', label: 'Liability name'),
//       FormFieldSpec.amount(key: 'balance', label: 'Remaining balance', prefix: symbol),
//       FormFieldSpec.amount(key: 'installment', label: 'Monthly installment', prefix: symbol),
//       FormFieldSpec.percent(key: 'rate', label: 'Interest rate', rowGroup: 1, flex: 3),
//       FormFieldSpec.integer(key: 'dueDay', label: 'Due day', min: 1, max: 31,
//           initial: 1, rowGroup: 1, flex: 2),
//       FormFieldSpec.date(key: 'until', label: 'Project until',
//           initial: DateTime.now().add(const Duration(days: 365)), required: true,
//           firstDate: DateTime.now()),
//     ],
//     warningBuilder: (v) {
//       final bal = v['balance'] as double?;
//       final inst = v['installment'] as double?;
//       final rate = (v['rate'] as double?) ?? 0;
//       if (bal == null || inst == null) return null;
//       final monthlyInterest = bal * rate / 100 / 12;
//       return inst <= monthlyInterest
//           ? 'This installment does not cover the monthly interest, so the debt '
//             'would never be paid off.'
//           : null;
//     },
//   );
//
// ---- Savings goal -----------------------------------------------------------
//
//   fields: [
//     FormFieldSpec.text(key: 'name', label: 'Goal name'),
//     FormFieldSpec.amount(key: 'target', label: 'Target amount', rowGroup: 1),
//     FormFieldSpec.amount(key: 'monthly', label: 'Monthly installment',
//         required: false, allowZero: true, rowGroup: 1),
//     FormFieldSpec.date(key: 'due', label: 'Due date'),   // optional by default
//   ]

enum FieldKind { text, amount, percent, integer, date, dropdown }

/// One choice in a dropdown field. [value] is what you get back in the result.
class FormOption {
  final Object value;
  final String label;
  const FormOption(this.value, this.label);
}

/// Describes one field. Use the named factories (text, amount, ...).
///
/// Result types in the returned map:
///   text -> String?, amount/percent -> double?, integer -> int?,
///   date -> DateTime?, dropdown -> the option's value.
///
/// Fields with the same non-null [rowGroup] that follow each other share a row;
/// [flex] controls their relative widths.
class FormFieldSpec {
  final String key;
  final String label;
  final FieldKind kind;
  final Object? initialValue;
  final bool required;
  final bool enabled;
  final String? hint;
  final String? helper;
  final String? prefix;
  final String? suffix;
  final num? min;
  final num? max;
  final bool allowZero;
  final List<FormOption> options;
  final DateTime? firstDate;
  final DateTime? lastDate;
  final int? rowGroup;
  final int flex;
  final String? Function(Object? value)? validator;

  const FormFieldSpec({
    required this.key,
    required this.label,
    required this.kind,
    this.initialValue,
    this.required = true,
    this.enabled = true,
    this.hint,
    this.helper,
    this.prefix,
    this.suffix,
    this.min,
    this.max,
    this.allowZero = false,
    this.options = const [],
    this.firstDate,
    this.lastDate,
    this.rowGroup,
    this.flex = 1,
    this.validator,
  });

  factory FormFieldSpec.text({
    required String key,
    required String label,
    String? initial,
    bool required = true,
    bool enabled = true,
    String? hint,
    String? helper,
    int? rowGroup,
    int flex = 1,
    String? Function(Object? value)? validator,
  }) {
    return FormFieldSpec(
      key: key,
      label: label,
      kind: FieldKind.text,
      initialValue: initial,
      required: required,
      enabled: enabled,
      hint: hint,
      helper: helper,
      rowGroup: rowGroup,
      flex: flex,
      validator: validator,
    );
  }

  /// A money amount. Must be greater than 0 unless [allowZero] is true.
  factory FormFieldSpec.amount({
    required String key,
    required String label,
    double? initial,
    bool required = true,
    bool enabled = true,
    String? prefix,
    double? min,
    double? max,
    bool allowZero = false,
    String? helper,
    int? rowGroup,
    int flex = 1,
  }) {
    return FormFieldSpec(
      key: key,
      label: label,
      kind: FieldKind.amount,
      initialValue: initial,
      required: required,
      enabled: enabled,
      prefix: prefix,
      min: min,
      max: max,
      allowZero: allowZero,
      helper: helper,
      rowGroup: rowGroup,
      flex: flex,
    );
  }

  /// A percentage from 0 to [max] (default 100). Zero is allowed.
  factory FormFieldSpec.percent({
    required String key,
    required String label,
    double? initial,
    bool required = true,
    bool enabled = true,
    double max = 100,
    String? helper,
    int? rowGroup,
    int flex = 1,
  }) {
    return FormFieldSpec(
      key: key,
      label: label,
      kind: FieldKind.percent,
      initialValue: initial,
      required: required,
      enabled: enabled,
      suffix: '%',
      min: 0,
      max: max,
      allowZero: true,
      helper: helper,
      rowGroup: rowGroup,
      flex: flex,
    );
  }

  factory FormFieldSpec.integer({
    required String key,
    required String label,
    int? initial,
    bool required = true,
    bool enabled = true,
    int? min,
    int? max,
    bool allowZero = false,
    String? helper,
    int? rowGroup,
    int flex = 1,
  }) {
    return FormFieldSpec(
      key: key,
      label: label,
      kind: FieldKind.integer,
      initialValue: initial,
      required: required,
      enabled: enabled,
      min: min,
      max: max,
      allowZero: allowZero,
      helper: helper,
      rowGroup: rowGroup,
      flex: flex,
    );
  }

  /// A date picker. Optional by default (shows a clear button when filled).
  factory FormFieldSpec.date({
    required String key,
    required String label,
    DateTime? initial,
    bool required = false,
    bool enabled = true,
    DateTime? firstDate,
    DateTime? lastDate,
    String? helper,
    int? rowGroup,
    int flex = 1,
  }) {
    return FormFieldSpec(
      key: key,
      label: label,
      kind: FieldKind.date,
      initialValue: initial,
      required: required,
      enabled: enabled,
      firstDate: firstDate,
      lastDate: lastDate,
      helper: helper,
      rowGroup: rowGroup,
      flex: flex,
    );
  }

  factory FormFieldSpec.dropdown({
    required String key,
    required String label,
    required List<FormOption> options,
    Object? initial,
    bool required = true,
    bool enabled = true,
    String? helper,
    int? rowGroup,
    int flex = 1,
  }) {
    return FormFieldSpec(
      key: key,
      label: label,
      kind: FieldKind.dropdown,
      initialValue: initial,
      required: required,
      enabled: enabled,
      options: options,
      helper: helper,
      rowGroup: rowGroup,
      flex: flex,
    );
  }
}

/// Shows the sheet. Returns the entered values, or null if the user cancelled.
///
/// [crossValidator] runs after every field is valid and can block submission by
/// returning an error message. [warningBuilder] is a soft, live warning that
/// does not block submission.
Future<Map<String, Object?>?> showEntityFormSheet(
  BuildContext context, {
  required String title,
  required List<FormFieldSpec> fields,
  String? subtitle,
  String submitLabel = 'Save',
  String? Function(Map<String, Object?> values)? crossValidator,
  String? Function(Map<String, Object?> values)? warningBuilder,
  ZPalette? palette,
}) async {
  final pal = palette ?? await ZPalette.load();
  if (!context.mounted) return null;

  return showModalBottomSheet<Map<String, Object?>>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: pal.dialogBg,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _EntityFormSheet(
      pal: pal,
      title: title,
      subtitle: subtitle,
      fields: fields,
      submitLabel: submitLabel,
      crossValidator: crossValidator,
      warningBuilder: warningBuilder,
    ),
  );
}

class _EntityFormSheet extends StatefulWidget {
  final ZPalette pal;
  final String title;
  final String? subtitle;
  final List<FormFieldSpec> fields;
  final String submitLabel;
  final String? Function(Map<String, Object?> values)? crossValidator;
  final String? Function(Map<String, Object?> values)? warningBuilder;

  const _EntityFormSheet({
    required this.pal,
    required this.title,
    required this.subtitle,
    required this.fields,
    required this.submitLabel,
    required this.crossValidator,
    required this.warningBuilder,
  });

  @override
  State<_EntityFormSheet> createState() => _EntityFormSheetState();
}

class _EntityFormSheetState extends State<_EntityFormSheet> {
  final Map<String, TextEditingController> _controllers = {};
  final Map<String, Object?> _values = {};
  final Map<String, String> _errors = {};
  String? _crossError;
  bool _submitted = false;

  ZPalette get pal => widget.pal;

  @override
  void initState() {
    super.initState();
    for (final f in widget.fields) {
      switch (f.kind) {
        case FieldKind.text:
        case FieldKind.amount:
        case FieldKind.percent:
        case FieldKind.integer:
          _controllers[f.key] = TextEditingController(text: _initialText(f));
          break;
        case FieldKind.date:
        case FieldKind.dropdown:
          _values[f.key] = f.initialValue;
          break;
      }
    }
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  String _initialText(FormFieldSpec f) {
    final v = f.initialValue;
    if (v == null) return '';
    if (f.kind == FieldKind.amount || f.kind == FieldKind.percent) {
      return v is num ? amountToInputText(v.toDouble()) : v.toString();
    }
    if (f.kind == FieldKind.integer) {
      return v is num ? v.toInt().toString() : v.toString();
    }
    return v.toString();
  }

  Object? _valueOf(FormFieldSpec f) {
    final c = _controllers[f.key];
    switch (f.kind) {
      case FieldKind.text:
        final t = c!.text.trim();
        return t.isEmpty ? null : t;
      case FieldKind.amount:
      case FieldKind.percent:
        return parseAmount(c!.text);
      case FieldKind.integer:
        return parseInt(c!.text);
      case FieldKind.date:
      case FieldKind.dropdown:
        return _values[f.key];
    }
  }

  Map<String, Object?> _collect() {
    return {for (final f in widget.fields) f.key: _valueOf(f)};
  }

  String _fmt(num n) => n == n.roundToDouble() ? n.toInt().toString() : n.toString();

  String? _validate(FormFieldSpec f) {
    final value = _valueOf(f);
    final isNumeric = f.kind == FieldKind.amount ||
        f.kind == FieldKind.percent ||
        f.kind == FieldKind.integer;

    if (value == null) {
      if (isNumeric && _controllers[f.key]!.text.trim().isNotEmpty) {
        return 'Enter a valid number';
      }
      return f.required ? 'Required' : null;
    }

    if (value is num) {
      if (isNumeric && !f.allowZero && value <= 0) return 'Must be greater than 0';
      if (f.min != null && value < f.min!) return 'Minimum ${_fmt(f.min!)}';
      if (f.max != null && value > f.max!) return 'Maximum ${_fmt(f.max!)}';
    }
    return f.validator?.call(value);
  }

  /// After the first submit attempt, errors update live as the user types.
  void _afterChange(FormFieldSpec f) {
    _crossError = null;
    if (!_submitted) return;
    final e = _validate(f);
    if (e == null) {
      _errors.remove(f.key);
    } else {
      _errors[f.key] = e;
    }
  }

  void _submit() {
    final errors = <String, String>{};
    for (final f in widget.fields) {
      final e = _validate(f);
      if (e != null) errors[f.key] = e;
    }

    String? cross;
    if (errors.isEmpty && widget.crossValidator != null) {
      cross = widget.crossValidator!(_collect());
    }

    if (errors.isNotEmpty || cross != null) {
      setState(() {
        _submitted = true;
        _errors
          ..clear()
          ..addAll(errors);
        _crossError = cross;
      });
      return;
    }
    Navigator.of(context).pop(_collect());
  }

  Future<void> _pickDate(FormFieldSpec f) async {
    final now = DateTime.now();
    final first = f.firstDate ?? DateTime(now.year - 5);
    final last = f.lastDate ?? DateTime(now.year + 30, 12, 31);
    var initial = (_values[f.key] as DateTime?) ?? now;
    if (initial.isBefore(first)) initial = first;
    if (initial.isAfter(last)) initial = last;

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: first,
      lastDate: last,
    );
    if (picked != null && mounted) {
      setState(() {
        _values[f.key] = picked;
        _afterChange(f);
      });
    }
  }

  InputDecoration _decoration(FormFieldSpec f, String? error) {
    OutlineInputBorder outline(Color color, [double width = 1]) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: color, width: width),
        );

    return InputDecoration(
      labelText: f.required ? f.label : '${f.label} (optional)',
      labelStyle: TextStyle(color: pal.muted, fontSize: 13),
      hintText: f.hint,
      hintStyle: TextStyle(color: pal.muted, fontSize: 12),
      helperText: f.helper,
      helperStyle: TextStyle(color: pal.muted, fontSize: 11),
      helperMaxLines: 2,
      errorText: error,
      errorStyle: TextStyle(color: pal.danger, fontSize: 11),
      prefixText: f.prefix != null ? '${f.prefix} ' : null,
      prefixStyle: TextStyle(color: pal.muted, fontSize: 13),
      suffixText: f.suffix,
      suffixStyle: TextStyle(color: pal.muted, fontSize: 13),
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      filled: true,
      fillColor: pal.fieldBg,
      border: outline(pal.border),
      enabledBorder: outline(pal.border),
      disabledBorder: outline(pal.border.withValues(alpha: 0.5)),
      focusedBorder: outline(pal.accent, 1.5),
      errorBorder: outline(pal.danger),
      focusedErrorBorder: outline(pal.danger, 1.5),
    );
  }

  Widget _fieldWidget(FormFieldSpec f) {
    switch (f.kind) {
      case FieldKind.text:
      case FieldKind.amount:
      case FieldKind.percent:
      case FieldKind.integer:
        return _textField(f);
      case FieldKind.date:
        return _dateField(f);
      case FieldKind.dropdown:
        return _dropdownField(f);
    }
  }

  Widget _textField(FormFieldSpec f) {
    final isMoney = f.kind == FieldKind.amount || f.kind == FieldKind.percent;
    final isInt = f.kind == FieldKind.integer;

    return TextField(
      controller: _controllers[f.key],
      enabled: f.enabled,
      style: TextStyle(color: pal.text, fontSize: 14),
      keyboardType: isMoney
          ? const TextInputType.numberWithOptions(decimal: true)
          : (isInt ? TextInputType.number : TextInputType.text),
      textCapitalization: f.kind == FieldKind.text
          ? TextCapitalization.sentences
          : TextCapitalization.none,
      textInputAction: TextInputAction.next,
      inputFormatters: isMoney
          ? [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,\s]'))]
          : (isInt ? [FilteringTextInputFormatter.digitsOnly] : null),
      decoration: _decoration(f, _errors[f.key]),
      onChanged: (_) => setState(() => _afterChange(f)),
    );
  }

  Widget _dropdownField(FormFieldSpec f) {
    final current = _values[f.key];
    final valid = f.options.any((o) => o.value == current);

    return DropdownButtonFormField<Object>(
      initialValue: valid ? current : null,
      isExpanded: true,
      dropdownColor: pal.dialogBg,
      style: TextStyle(fontSize: 14, color: pal.text),
      decoration: _decoration(f, _errors[f.key]),
      items: [
        for (final o in f.options)
          DropdownMenuItem<Object>(
            value: o.value,
            child: Text(o.label, overflow: TextOverflow.ellipsis),
          ),
      ],
      onChanged: f.enabled
          ? (val) => setState(() {
                _values[f.key] = val;
                _afterChange(f);
              })
          : null,
    );
  }

  Widget _dateField(FormFieldSpec f) {
    final v = _values[f.key] as DateTime?;

    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: f.enabled ? () => _pickDate(f) : null,
      child: InputDecorator(
        decoration: _decoration(f, _errors[f.key]),
        child: Row(
          children: [
            Expanded(
              child: Text(
                v == null ? 'Not set' : DateFormat('yyyy-MM-dd').format(v),
                style: TextStyle(fontSize: 14, color: v == null ? pal.muted : pal.text),
              ),
            ),
            if (v != null && !f.required && f.enabled)
              InkWell(
                onTap: () => setState(() {
                  _values[f.key] = null;
                  _afterChange(f);
                }),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(Icons.close, size: 16, color: pal.muted),
                ),
              ),
            Icon(Icons.calendar_today_outlined, size: 16, color: pal.muted),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildFields() {
    final out = <Widget>[];
    final fields = widget.fields;
    var i = 0;
    while (i < fields.length) {
      final f = fields[i];
      if (f.rowGroup == null) {
        out.add(_fieldWidget(f));
        i++;
      } else {
        final group = <FormFieldSpec>[];
        while (i < fields.length && fields[i].rowGroup == f.rowGroup) {
          group.add(fields[i]);
          i++;
        }
        out.add(
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var g = 0; g < group.length; g++) ...[
                if (g > 0) const SizedBox(width: 10),
                Expanded(flex: group[g].flex, child: _fieldWidget(group[g])),
              ],
            ],
          ),
        );
      }
      out.add(const SizedBox(height: 14));
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final warning = widget.warningBuilder?.call(_collect());

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: pal.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              widget.title,
              style: TextStyle(color: pal.title, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            if (widget.subtitle != null) ...[
              const SizedBox(height: 4),
              Text(widget.subtitle!, style: TextStyle(color: pal.muted, fontSize: 12)),
            ],
            const SizedBox(height: 16),
            ..._buildFields(),
            if (warning != null)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 14),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: pal.warning.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: pal.warning.withValues(alpha: 0.6)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.warning_amber_rounded, size: 18, color: pal.warning),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        warning,
                        style: TextStyle(fontSize: 12, height: 1.35, color: pal.text),
                      ),
                    ),
                  ],
                ),
              ),
            if (_crossError != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Text(
                  _crossError!,
                  style: TextStyle(color: pal.danger, fontSize: 12),
                ),
              ),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text('Cancel', style: TextStyle(color: pal.muted)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: pal.accent,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: _submit,
                    child: Text(
                      widget.submitLabel,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
