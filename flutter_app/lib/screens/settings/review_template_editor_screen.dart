// ============================================================
// Review Template Editor — create/edit a review screen template
// ============================================================
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../config/theme.dart';
import '../../providers/customization_provider.dart';
import '../../services/api_service.dart';

class ReviewTemplateEditorScreen extends StatefulWidget {
  final ReviewTemplate? template; // null = create new
  final String entityType;        // 'student' | 'teacher'
  final String schoolId;

  const ReviewTemplateEditorScreen({
    super.key,
    this.template,
    required this.entityType,
    required this.schoolId,
  });

  @override
  State<ReviewTemplateEditorScreen> createState() => _ReviewTemplateEditorScreenState();
}

class _ReviewTemplateEditorScreenState extends State<ReviewTemplateEditorScreen> {
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  String _layoutStyle = 'side_by_side';
  List<ReviewTemplateSection> _sections = [];
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final tpl = widget.template;
    if (tpl != null) {
      _nameCtrl.text  = tpl.name;
      _descCtrl.text  = tpl.description ?? '';
      _layoutStyle    = tpl.layoutStyle;
      // Deep copy sections so edits don't mutate the original
      _sections = tpl.sections
          .map((s) => ReviewTemplateSection(
                sectionName: s.sectionName,
                sortOrder:   s.sortOrder,
                fields: s.fields.map((f) => ReviewTemplateField(
                  fieldKey: f.fieldKey,
                  label:    f.label,
                  visible:  f.visible,
                  required: f.required,
                )).toList(),
              ))
          .toList();
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Template name is required')));
      return;
    }
    if (_sections.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('At least one section is required')));
      return;
    }

    setState(() { _saving = true; });

    final body = {
      'school_id':    widget.schoolId,
      'entity_type':  widget.entityType,
      'name':         _nameCtrl.text.trim(),
      'description':  _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
      'layout_style': _layoutStyle,
      'sections': _sections.asMap().entries.map((e) =>
        e.value.copyWith(sortOrder: e.key).toJson()
      ).toList(),
    };

    try {
      if (widget.template != null) {
        await ApiService().put('/customization/review-templates/${widget.template!.id}', body: body);
      } else {
        await ApiService().post('/customization/review-templates', body: body);
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() { _saving = false; });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Save failed: $e'), backgroundColor: AppTheme.error));
      }
    }
  }

  void _toggleField(int sectionIdx, int fieldIdx) {
    setState(() {
      final s = _sections[sectionIdx];
      final f = s.fields[fieldIdx];
      _sections[sectionIdx] = s.copyWith(
        fields: List<ReviewTemplateField>.from(s.fields)
          ..[fieldIdx] = f.copyWith(visible: !f.visible),
      );
    });
  }

  void _onSectionReorder(int oldIdx, int newIdx) {
    if (newIdx > oldIdx) newIdx--;
    setState(() {
      final s = _sections.removeAt(oldIdx);
      _sections.insert(newIdx, s);
    });
  }

  @override
  Widget build(BuildContext context) {
    final isNew = widget.template == null;
    final typeLabel = widget.entityType == 'student' ? 'Student' : 'Teacher';

    return Scaffold(
      backgroundColor: AppTheme.grey50,
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D1B63),
        foregroundColor: Colors.white,
        title: Text(isNew ? 'New $typeLabel Template' : 'Edit Template',
          style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 18)),
        actions: [
          if (!_saving)
            TextButton(
              onPressed: _save,
              child: Text('Save', style: GoogleFonts.poppins(
                color: Colors.white, fontWeight: FontWeight.w600)),
            )
          else
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Center(child: SizedBox(
                width: 20, height: 20,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
              )),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // ── Template Name ──────────────────────────────────
          _Card(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SectionLabel('Template Details'),
              const SizedBox(height: 12),
              TextField(
                controller: _nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Template Name',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                style: GoogleFonts.poppins(fontSize: 14),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _descCtrl,
                decoration: const InputDecoration(
                  labelText: 'Description (optional)',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                maxLines: 2,
                style: GoogleFonts.poppins(fontSize: 14),
              ),
            ],
          )),

          const SizedBox(height: 16),

          // ── Layout Style ───────────────────────────────────
          _Card(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SectionLabel('Comparison Layout'),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: [
                  _LayoutOption(
                    value: 'side_by_side',
                    label: 'Side by Side',
                    icon: Icons.view_column_outlined,
                    description: 'Old and new values shown in two columns',
                    selected: _layoutStyle == 'side_by_side',
                    onTap: () => setState(() => _layoutStyle = 'side_by_side'),
                  ),
                  _LayoutOption(
                    value: 'stacked',
                    label: 'Stacked',
                    icon: Icons.view_stream_outlined,
                    description: 'Old value above, new value below each field',
                    selected: _layoutStyle == 'stacked',
                    onTap: () => setState(() => _layoutStyle = 'stacked'),
                  ),
                  _LayoutOption(
                    value: 'card',
                    label: 'Card',
                    icon: Icons.credit_card_outlined,
                    description: 'Each field shown in its own card',
                    selected: _layoutStyle == 'card',
                    onTap: () => setState(() => _layoutStyle = 'card'),
                  ),
                ],
              ),
            ],
          )),

          const SizedBox(height: 16),

          // ── Sections & Fields ──────────────────────────────
          _Card(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: _SectionLabel('Sections & Fields')),
                  Text('Toggle to show/hide each field',
                    style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.grey500)),
                ],
              ),
              if (_sections.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: Text('No sections. Clone a system template to start.',
                    style: GoogleFonts.poppins(color: AppTheme.grey400, fontSize: 13))),
                ),
            ],
          )),

          // Sections list (outside the card for full reorderability)
          if (_sections.isNotEmpty) ...[
            const SizedBox(height: 8),
            SizedBox(
              height: _sections.fold<double>(0, (h, s) => h + 56.0 + s.fields.length * 48.0) + 40,
              child: ReorderableListView(
                onReorder: _onSectionReorder,
                children: List.generate(_sections.length, (sIdx) {
                  final section = _sections[sIdx];
                  final visibleCount = section.fields.where((f) => f.visible).length;
                  return _SectionCard(
                    key: ValueKey('section_$sIdx'),
                    section: section,
                    visibleCount: visibleCount,
                    onToggleField: (fIdx) => _toggleField(sIdx, fIdx),
                  );
                }),
              ),
            ),
          ],

          const SizedBox(height: 60),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
    ),
    child: child,
  );
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) => Text(text,
    style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.grey700));
}

class _LayoutOption extends StatelessWidget {
  final String value;
  final String label;
  final String description;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _LayoutOption({
    required this.value,
    required this.label,
    required this.description,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: 140,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: selected ? const Color(0xFF1565C0).withOpacity(0.08) : AppTheme.grey50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: selected ? const Color(0xFF1565C0) : AppTheme.grey200,
          width: selected ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 22, color: selected ? const Color(0xFF1565C0) : AppTheme.grey400),
          const SizedBox(height: 6),
          Text(label, style: GoogleFonts.poppins(
            fontSize: 13, fontWeight: FontWeight.w600,
            color: selected ? const Color(0xFF1565C0) : AppTheme.grey700)),
          const SizedBox(height: 2),
          Text(description, style: GoogleFonts.poppins(
            fontSize: 10, color: AppTheme.grey500), maxLines: 2, overflow: TextOverflow.ellipsis),
        ],
      ),
    ),
  );
}

class _SectionCard extends StatelessWidget {
  final ReviewTemplateSection section;
  final int visibleCount;
  final ValueChanged<int> onToggleField;

  const _SectionCard({
    super.key,
    required this.section,
    required this.visibleCount,
    required this.onToggleField,
  });

  @override
  Widget build(BuildContext context) => Card(
    elevation: 0,
    color: Colors.white,
    margin: const EdgeInsets.only(bottom: 8),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    child: ExpansionTile(
      tilePadding: const EdgeInsets.symmetric(horizontal: 12),
      leading: const Icon(Icons.drag_handle, color: AppTheme.grey400, size: 20),
      title: Text(section.sectionName, style: GoogleFonts.poppins(
        fontSize: 14, fontWeight: FontWeight.w600)),
      subtitle: Text('$visibleCount / ${section.fields.length} fields visible',
        style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.grey500)),
      children: section.fields.asMap().entries.map((entry) {
        final fIdx  = entry.key;
        final field = entry.value;
        return ListTile(
          dense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 24),
          title: Text(field.label, style: GoogleFonts.poppins(
            fontSize: 13,
            color: field.visible ? AppTheme.grey800 : AppTheme.grey400,
          )),
          subtitle: Text(field.fieldKey, style: GoogleFonts.poppins(
            fontSize: 10, color: AppTheme.grey400)),
          trailing: Switch(
            value: field.visible,
            activeColor: const Color(0xFF1565C0),
            onChanged: (_) => onToggleField(fIdx),
          ),
        );
      }).toList(),
    ),
  );
}
