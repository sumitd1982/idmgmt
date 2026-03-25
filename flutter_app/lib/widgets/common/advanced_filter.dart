// ============================================================
// Advanced Filter — Reusable multi-rule filter panel
// Industry-grade: field types, operators, AND/OR, presets
// ============================================================
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../config/theme.dart';

// ── Data Models ───────────────────────────────────────────────

enum FilterFieldType { text, number, select, date, boolean }

enum FilterOperator {
  contains, notContains,
  equals, notEquals,
  startsWith, endsWith,
  greaterThan, lessThan,
  isEmpty, isNotEmpty,
  isTrue, isFalse,
}

extension FilterOperatorX on FilterOperator {
  String get label {
    switch (this) {
      case FilterOperator.contains:    return 'contains';
      case FilterOperator.notContains: return 'does not contain';
      case FilterOperator.equals:      return 'equals';
      case FilterOperator.notEquals:   return 'not equals';
      case FilterOperator.startsWith:  return 'starts with';
      case FilterOperator.endsWith:    return 'ends with';
      case FilterOperator.greaterThan: return 'greater than';
      case FilterOperator.lessThan:    return 'less than';
      case FilterOperator.isEmpty:     return 'is empty';
      case FilterOperator.isNotEmpty:  return 'is not empty';
      case FilterOperator.isTrue:      return 'is true';
      case FilterOperator.isFalse:     return 'is false';
    }
  }

  bool get needsValue {
    return this != FilterOperator.isEmpty &&
           this != FilterOperator.isNotEmpty &&
           this != FilterOperator.isTrue &&
           this != FilterOperator.isFalse;
  }
}

List<FilterOperator> operatorsFor(FilterFieldType type) {
  switch (type) {
    case FilterFieldType.text:
      return [
        FilterOperator.contains, FilterOperator.notContains,
        FilterOperator.equals, FilterOperator.notEquals,
        FilterOperator.startsWith, FilterOperator.endsWith,
        FilterOperator.isEmpty, FilterOperator.isNotEmpty,
      ];
    case FilterFieldType.number:
      return [
        FilterOperator.equals, FilterOperator.notEquals,
        FilterOperator.greaterThan, FilterOperator.lessThan,
        FilterOperator.isEmpty, FilterOperator.isNotEmpty,
      ];
    case FilterFieldType.select:
      return [FilterOperator.equals, FilterOperator.notEquals];
    case FilterFieldType.date:
      return [
        FilterOperator.equals, FilterOperator.greaterThan, FilterOperator.lessThan,
        FilterOperator.isEmpty, FilterOperator.isNotEmpty,
      ];
    case FilterFieldType.boolean:
      return [FilterOperator.isTrue, FilterOperator.isFalse];
  }
}

class FilterOption {
  final String value;
  final String label;
  const FilterOption(this.value, this.label);
}

class FilterField {
  final String key;
  final String label;
  final FilterFieldType type;
  final List<FilterOption> options;
  final IconData? icon;

  const FilterField({
    required this.key,
    required this.label,
    required this.type,
    this.options = const [],
    this.icon,
  });
}

class FilterRule {
  final String id;
  final FilterField field;
  final FilterOperator operator;
  final String value;
  final bool enabled;

  FilterRule({
    String? id,
    required this.field,
    required this.operator,
    this.value = '',
    this.enabled = true,
  }) : id = id ?? DateTime.now().microsecondsSinceEpoch.toString();

  FilterRule copyWith({
    FilterField? field,
    FilterOperator? operator,
    String? value,
    bool? enabled,
  }) => FilterRule(
    id: id,
    field: field ?? this.field,
    operator: operator ?? this.operator,
    value: value ?? this.value,
    enabled: enabled ?? this.enabled,
  );

  // Apply this rule to a string value from a record
  bool matches(dynamic recordValue) {
    if (!enabled) return true;
    final rv = recordValue?.toString() ?? '';

    if (!operator.needsValue) {
      switch (operator) {
        case FilterOperator.isEmpty:    return rv.isEmpty;
        case FilterOperator.isNotEmpty: return rv.isNotEmpty;
        case FilterOperator.isTrue:     return rv == 'true' || rv == '1';
        case FilterOperator.isFalse:    return rv == 'false' || rv == '0';
        default: return true;
      }
    }

    final v = value.toLowerCase();
    final r = rv.toLowerCase();

    switch (operator) {
      case FilterOperator.contains:    return r.contains(v);
      case FilterOperator.notContains: return !r.contains(v);
      case FilterOperator.equals:      return r == v;
      case FilterOperator.notEquals:   return r != v;
      case FilterOperator.startsWith:  return r.startsWith(v);
      case FilterOperator.endsWith:    return r.endsWith(v);
      case FilterOperator.greaterThan:
        final n1 = num.tryParse(rv); final n2 = num.tryParse(value);
        return n1 != null && n2 != null && n1 > n2;
      case FilterOperator.lessThan:
        final n1 = num.tryParse(rv); final n2 = num.tryParse(value);
        return n1 != null && n2 != null && n1 < n2;
      default: return true;
    }
  }
}

enum FilterLogic { and, or }

// ── Main Widget ───────────────────────────────────────────────

class AdvancedFilter extends StatefulWidget {
  final List<FilterField> fields;
  final List<FilterRule> rules;
  final FilterLogic logic;
  final ValueChanged<List<FilterRule>> onRulesChanged;
  final ValueChanged<FilterLogic> onLogicChanged;
  final bool compact; // if true, shows as a collapsed chip that opens a dialog

  const AdvancedFilter({
    super.key,
    required this.fields,
    required this.rules,
    required this.onRulesChanged,
    this.logic = FilterLogic.and,
    this.onLogicChanged = _noop,
    this.compact = false,
  });

  static void _noop(FilterLogic _) {}

  @override
  State<AdvancedFilter> createState() => _AdvancedFilterState();
}

class _AdvancedFilterState extends State<AdvancedFilter> {
  void _addRule() {
    final newRule = FilterRule(
      field: widget.fields.first,
      operator: operatorsFor(widget.fields.first.type).first,
    );
    widget.onRulesChanged([...widget.rules, newRule]);
  }

  void _updateRule(int index, FilterRule rule) {
    final updated = [...widget.rules];
    updated[index] = rule;
    widget.onRulesChanged(updated);
  }

  void _removeRule(int index) {
    final updated = [...widget.rules];
    updated.removeAt(index);
    widget.onRulesChanged(updated);
  }

  void _clearAll() => widget.onRulesChanged([]);

  @override
  Widget build(BuildContext context) {
    final activeCount = widget.rules.where((r) => r.enabled).length;

    if (widget.compact) {
      return _CompactTrigger(
        activeCount: activeCount,
        onTap: () => _showDialog(context),
      );
    }

    return _FilterPanel(
      fields: widget.fields,
      rules: widget.rules,
      logic: widget.logic,
      onAdd: _addRule,
      onUpdate: _updateRule,
      onRemove: _removeRule,
      onClear: _clearAll,
      onLogicChanged: widget.onLogicChanged,
    );
  }

  void _showDialog(BuildContext context) {
    List<FilterRule> draft = List.from(widget.rules);
    FilterLogic draftLogic = widget.logic;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setState) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Container(
            width: 680,
            constraints: const BoxConstraints(maxHeight: 600),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
                  decoration: const BoxDecoration(
                    gradient: AppTheme.primaryGradient,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                  child: Row(children: [
                    const Icon(Icons.filter_alt_rounded, color: Colors.white, size: 20),
                    const SizedBox(width: 10),
                    Text('Advanced Filter',
                      style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
                    const Spacer(),
                    if (draft.isNotEmpty)
                      TextButton(
                        onPressed: () => setState(() => draft = []),
                        child: Text('Clear All', style: GoogleFonts.poppins(color: Colors.white70, fontSize: 12)),
                      ),
                    IconButton(
                      onPressed: () => Navigator.pop(ctx),
                      icon: const Icon(Icons.close, color: Colors.white, size: 18),
                    ),
                  ]),
                ),
                // Logic toggle
                if (draft.length > 1)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                    child: Row(children: [
                      Text('Match', style: GoogleFonts.poppins(fontSize: 13, color: AppTheme.grey700)),
                      const SizedBox(width: 10),
                      _LogicToggle(
                        value: draftLogic,
                        onChanged: (l) => setState(() => draftLogic = l),
                      ),
                      const SizedBox(width: 10),
                      Text('of the following rules',
                        style: GoogleFonts.poppins(fontSize: 13, color: AppTheme.grey700)),
                    ]),
                  ),
                // Rules list
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                    itemCount: draft.length,
                    itemBuilder: (_, i) => _RuleRow(
                      key: ValueKey(draft[i].id),
                      rule: draft[i],
                      fields: widget.fields,
                      onChanged: (r) => setState(() => draft[i] = r),
                      onRemove: () => setState(() => draft.removeAt(i)),
                      isFirst: i == 0,
                      logic: draftLogic,
                    ),
                  ),
                ),
                // Add rule button
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                  child: OutlinedButton.icon(
                    onPressed: () => setState(() => draft.add(FilterRule(
                      field: widget.fields.first,
                      operator: operatorsFor(widget.fields.first.type).first,
                    ))),
                    icon: const Icon(Icons.add, size: 16),
                    label: Text('Add Filter Rule', style: GoogleFonts.poppins(fontSize: 13)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.primary,
                      side: const BorderSide(color: AppTheme.primary),
                    ),
                  ),
                ),
                // Footer buttons
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(children: [
                    Expanded(child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: Text('Cancel', style: GoogleFonts.poppins(fontSize: 13)),
                    )),
                    const SizedBox(width: 12),
                    Expanded(child: ElevatedButton(
                      onPressed: () {
                        widget.onRulesChanged(draft);
                        widget.onLogicChanged(draftLogic);
                        Navigator.pop(ctx);
                      },
                      style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary, foregroundColor: Colors.white),
                      child: Text('Apply Filters', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13)),
                    )),
                  ]),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }
}

class _CompactTrigger extends StatelessWidget {
  final int activeCount;
  final VoidCallback onTap;
  const _CompactTrigger({required this.activeCount, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final hasFilters = activeCount > 0;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: hasFilters ? AppTheme.primary : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: hasFilters ? AppTheme.primary : AppTheme.grey300),
          boxShadow: hasFilters ? [BoxShadow(color: AppTheme.primary.withOpacity(0.25), blurRadius: 8, offset: const Offset(0,2))] : null,
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.filter_alt_rounded, size: 16, color: hasFilters ? Colors.white : AppTheme.grey600),
          const SizedBox(width: 6),
          Text('Filter', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w500, color: hasFilters ? Colors.white : AppTheme.grey700)),
          if (hasFilters) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.25), borderRadius: BorderRadius.circular(10)),
              child: Text('$activeCount', style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white)),
            ),
          ],
        ]),
      ),
    );
  }
}

class _FilterPanel extends StatelessWidget {
  final List<FilterField> fields;
  final List<FilterRule> rules;
  final FilterLogic logic;
  final VoidCallback onAdd;
  final Function(int, FilterRule) onUpdate;
  final Function(int) onRemove;
  final VoidCallback onClear;
  final ValueChanged<FilterLogic> onLogicChanged;

  const _FilterPanel({
    required this.fields, required this.rules, required this.logic,
    required this.onAdd, required this.onUpdate, required this.onRemove,
    required this.onClear, required this.onLogicChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.grey200),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0,2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
            child: Row(children: [
              const Icon(Icons.filter_alt_rounded, size: 16, color: AppTheme.primary),
              const SizedBox(width: 8),
              Text('Filters', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13, color: AppTheme.grey900)),
              if (rules.length > 1) ...[
                const SizedBox(width: 12),
                _LogicToggle(value: logic, onChanged: onLogicChanged),
              ],
              const Spacer(),
              if (rules.isNotEmpty)
                TextButton(onPressed: onClear, child: Text('Clear', style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.grey500))),
              TextButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.add, size: 14),
                label: Text('Add Rule', style: GoogleFonts.poppins(fontSize: 12)),
              ),
            ]),
          ),
          if (rules.isNotEmpty) ...[
            const Divider(height: 1),
            ...rules.asMap().entries.map((entry) => _RuleRow(
              key: ValueKey(entry.value.id),
              rule: entry.value,
              fields: fields,
              onChanged: (r) => onUpdate(entry.key, r),
              onRemove: () => onRemove(entry.key),
              isFirst: entry.key == 0,
              logic: logic,
            )),
          ] else
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
              child: Text('No active filters — showing all records',
                style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.grey400, fontStyle: FontStyle.italic)),
            ),
        ],
      ),
    );
  }
}

class _RuleRow extends StatefulWidget {
  final FilterRule rule;
  final List<FilterField> fields;
  final ValueChanged<FilterRule> onChanged;
  final VoidCallback onRemove;
  final bool isFirst;
  final FilterLogic logic;

  const _RuleRow({
    super.key,
    required this.rule,
    required this.fields,
    required this.onChanged,
    required this.onRemove,
    required this.isFirst,
    required this.logic,
  });

  @override
  State<_RuleRow> createState() => _RuleRowState();
}

class _RuleRowState extends State<_RuleRow> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.rule.value);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final availableOps = operatorsFor(widget.rule.field.type);
    final op = availableOps.contains(widget.rule.operator)
        ? widget.rule.operator
        : availableOps.first;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: AppTheme.grey100))),
      child: Row(children: [
        // AND/OR label
        SizedBox(
          width: 40,
          child: Text(
            widget.isFirst ? 'WHERE' : (widget.logic == FilterLogic.and ? 'AND' : 'OR'),
            style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w700,
              color: widget.isFirst ? AppTheme.grey400 : AppTheme.primary),
          ),
        ),
        const SizedBox(width: 6),
        // Enable toggle
        Transform.scale(
          scale: 0.7,
          child: Switch(
            value: widget.rule.enabled,
            onChanged: (v) => widget.onChanged(widget.rule.copyWith(enabled: v)),
            activeColor: AppTheme.primary,
          ),
        ),
        const SizedBox(width: 4),
        // Field selector
        Expanded(
          flex: 3,
          child: _DropDown<FilterField>(
            value: widget.rule.field,
            items: widget.fields.map((f) => DropdownMenuItem(
              value: f,
              child: Row(children: [
                if (f.icon != null) ...[Icon(f.icon, size: 14, color: AppTheme.grey600), const SizedBox(width: 6)],
                Text(f.label, style: GoogleFonts.poppins(fontSize: 12)),
              ]),
            )).toList(),
            onChanged: (f) {
              if (f == null) return;
              final ops = operatorsFor(f.type);
              widget.onChanged(widget.rule.copyWith(field: f, operator: ops.first, value: ''));
              _ctrl.text = '';
            },
          ),
        ),
        const SizedBox(width: 6),
        // Operator selector
        Expanded(
          flex: 3,
          child: _DropDown<FilterOperator>(
            value: op,
            items: availableOps.map((o) => DropdownMenuItem(
              value: o,
              child: Text(o.label, style: GoogleFonts.poppins(fontSize: 12)),
            )).toList(),
            onChanged: (o) { if (o != null) widget.onChanged(widget.rule.copyWith(operator: o)); },
          ),
        ),
        const SizedBox(width: 6),
        // Value input
        Expanded(
          flex: 3,
          child: op.needsValue
              ? _ValueInput(
                  rule: widget.rule,
                  ctrl: _ctrl,
                  onChanged: (v) => widget.onChanged(widget.rule.copyWith(value: v)),
                )
              : Container(
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppTheme.grey100,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.grey200),
                  ),
                  alignment: Alignment.center,
                  child: Text('—', style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.grey400)),
                ),
        ),
        const SizedBox(width: 6),
        // Remove
        IconButton(
          onPressed: widget.onRemove,
          icon: const Icon(Icons.close, size: 16),
          color: AppTheme.grey400,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
        ),
      ]),
    );
  }
}

class _ValueInput extends StatelessWidget {
  final FilterRule rule;
  final TextEditingController ctrl;
  final ValueChanged<String> onChanged;
  const _ValueInput({required this.rule, required this.ctrl, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    if (rule.field.type == FilterFieldType.select && rule.field.options.isNotEmpty) {
      final options = rule.field.options;
      final val = options.any((o) => o.value == rule.value) ? rule.value : options.first.value;
      return _DropDown<String>(
        value: val,
        items: options.map((o) => DropdownMenuItem(
          value: o.value,
          child: Text(o.label, style: GoogleFonts.poppins(fontSize: 12)),
        )).toList(),
        onChanged: (v) { if (v != null) onChanged(v); },
      );
    }

    return SizedBox(
      height: 36,
      child: TextFormField(
        controller: ctrl,
        style: GoogleFonts.poppins(fontSize: 12),
        decoration: InputDecoration(
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppTheme.grey300)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppTheme.grey300)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppTheme.primary, width: 1.5)),
          hintText: rule.field.type == FilterFieldType.number ? '0' : 'Type...',
          hintStyle: GoogleFonts.poppins(fontSize: 12, color: AppTheme.grey400),
          filled: true, fillColor: Colors.white,
        ),
        keyboardType: rule.field.type == FilterFieldType.number ? TextInputType.number : TextInputType.text,
        onChanged: onChanged,
      ),
    );
  }
}

class _LogicToggle extends StatelessWidget {
  final FilterLogic value;
  final ValueChanged<FilterLogic> onChanged;
  const _LogicToggle({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.grey100,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.grey200),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        _Toggle(label: 'AND', active: value == FilterLogic.and, onTap: () => onChanged(FilterLogic.and)),
        _Toggle(label: 'OR',  active: value == FilterLogic.or,  onTap: () => onChanged(FilterLogic.or)),
      ]),
    );
  }
}

class _Toggle extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _Toggle({required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: active ? AppTheme.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(label, style: GoogleFonts.poppins(
          fontSize: 11, fontWeight: FontWeight.w700,
          color: active ? Colors.white : AppTheme.grey500,
        )),
      ),
    );
  }
}

class _DropDown<T> extends StatelessWidget {
  final T value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;
  const _DropDown({required this.value, required this.items, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.grey300),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          items: items,
          onChanged: onChanged,
          style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.grey900),
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 16),
        ),
      ),
    );
  }
}

// ── Filter utilities ──────────────────────────────────────────

/// Apply a list of FilterRules (AND or OR logic) to extract a single value from each record.
/// Pass a `valueExtractor` that maps a record + field key → string value.
bool applyFilters<T>(T record, List<FilterRule> rules, FilterLogic logic, String Function(T, String) valueExtractor) {
  if (rules.isEmpty) return true;
  final active = rules.where((r) => r.enabled).toList();
  if (active.isEmpty) return true;

  if (logic == FilterLogic.and) {
    return active.every((r) => r.matches(valueExtractor(record, r.field.key)));
  } else {
    return active.any((r) => r.matches(valueExtractor(record, r.field.key)));
  }
}
