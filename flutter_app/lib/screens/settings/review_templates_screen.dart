// ============================================================
// Review Templates Screen — list & manage review screen templates
// ============================================================
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../config/theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/customization_provider.dart';
import '../../services/api_service.dart';
import 'review_template_editor_screen.dart';

class ReviewTemplatesScreen extends ConsumerStatefulWidget {
  final String entityType; // 'student' | 'teacher'
  const ReviewTemplatesScreen({super.key, required this.entityType});

  @override
  ConsumerState<ReviewTemplatesScreen> createState() => _ReviewTemplatesScreenState();
}

class _ReviewTemplatesScreenState extends ConsumerState<ReviewTemplatesScreen> {
  List<ReviewTemplate>? _templates;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  String? _schoolId() {
    final user = ref.read(authNotifierProvider).valueOrNull;
    return user?.schoolId ?? user?.employee?.schoolId;
  }

  Future<void> _load() async {
    setState(() { _loading = true; });
    try {
      final schoolId = _schoolId();
      final params   = <String, dynamic>{'type': widget.entityType};
      if (schoolId != null) params['school_id'] = schoolId;
      final data = await ApiService().get('/customization/review-templates', params: params);
      final list = (data['data'] as List<dynamic>? ?? [])
          .map((e) => ReviewTemplate.fromJson(e as Map<String, dynamic>))
          .toList();
      setState(() { _templates = list; });
    } catch (_) {
      setState(() { _templates = []; });
    } finally {
      setState(() { _loading = false; });
    }
  }

  Future<void> _clone(ReviewTemplate tpl) async {
    final schoolId = _schoolId();
    if (schoolId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No school context found')));
      return;
    }

    final nameCtrl = TextEditingController(text: '${tpl.name} (copy)');
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clone Template'),
        content: TextField(
          controller: nameCtrl,
          decoration: const InputDecoration(labelText: 'New template name'),
        ),
        actions: [
          TextButton(onPressed: () => ctx.pop(false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => ctx.pop(true), child: const Text('Clone')),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await ApiService().post('/customization/review-templates/${tpl.id}/clone', body: {
        'school_id': schoolId,
        'name': nameCtrl.text.trim(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Template cloned'), backgroundColor: Colors.green));
        _load();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.error));
    }
  }

  Future<void> _setDefault(ReviewTemplate tpl) async {
    final schoolId = _schoolId();
    try {
      final body = <String, dynamic>{};
      if (schoolId != null) body['school_id'] = schoolId;
      await ApiService().patch('/customization/review-templates/${tpl.id}/set-default', body: body);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Default template updated'), backgroundColor: Colors.green));
        _load();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.error));
    }
  }

  Future<void> _delete(ReviewTemplate tpl) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Template'),
        content: Text('Delete "${tpl.name}"? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => ctx.pop(false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => ctx.pop(true),
            child: const Text('Delete', style: TextStyle(color: AppTheme.error)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await ApiService().delete('/customization/review-templates/${tpl.id}');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Template deleted')));
        _load();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.error));
    }
  }

  Future<void> _openEditor(ReviewTemplate? tpl) async {
    final schoolId = _schoolId();
    if (schoolId == null) return;
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => ReviewTemplateEditorScreen(
        template: tpl,
        entityType: widget.entityType,
        schoolId: schoolId,
      )),
    );
    if (result == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    final typeLabel = widget.entityType == 'student' ? 'Student' : 'Teacher';
    final schoolId  = _schoolId();

    return Scaffold(
      backgroundColor: AppTheme.grey50,
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D1B63),
        foregroundColor: Colors.white,
        title: Text('$typeLabel Review Templates', style: GoogleFonts.poppins(
          color: Colors.white, fontWeight: FontWeight.w600, fontSize: 18)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _load,
          ),
        ],
      ),
      floatingActionButton: schoolId != null
          ? FloatingActionButton.extended(
              onPressed: () => _openEditor(null),
              icon: const Icon(Icons.add),
              label: const Text('New Template'),
              backgroundColor: const Color(0xFF1565C0),
            )
          : null,
      body: _loading
        ? const Center(child: CircularProgressIndicator())
        : (_templates == null || _templates!.isEmpty)
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.assignment_outlined, size: 64, color: AppTheme.grey300),
                  const SizedBox(height: 16),
                  Text('No templates yet', style: GoogleFonts.poppins(
                    color: AppTheme.grey500, fontSize: 16)),
                  const SizedBox(height: 8),
                  Text('Clone a system template to get started',
                    style: GoogleFonts.poppins(color: AppTheme.grey400, fontSize: 13)),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _templates!.length,
              itemBuilder: (ctx, idx) {
                final tpl = _templates![idx];
                final fieldCount = tpl.sections.fold<int>(
                  0, (sum, s) => sum + s.fields.where((f) => f.visible).length);
                return Card(
                  elevation: 0,
                  color: Colors.white,
                  margin: const EdgeInsets.only(bottom: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: tpl.isDefault
                      ? const BorderSide(color: Color(0xFF1565C0), width: 1.5)
                      : BorderSide.none,
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    leading: Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(
                        color: tpl.isSystem
                          ? Colors.grey.shade100
                          : const Color(0xFF1565C0).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        tpl.isSystem ? Icons.lock_outline : Icons.assignment_outlined,
                        color: tpl.isSystem ? AppTheme.grey400 : const Color(0xFF1565C0),
                        size: 20,
                      ),
                    ),
                    title: Row(
                      children: [
                        Expanded(child: Text(tpl.name, style: GoogleFonts.poppins(
                          fontSize: 14, fontWeight: FontWeight.w600))),
                        if (tpl.isDefault)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1565C0),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text('Default', style: GoogleFonts.poppins(
                              fontSize: 10, color: Colors.white, fontWeight: FontWeight.w600)),
                          ),
                      ],
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        if (tpl.description != null)
                          Text(tpl.description!, style: GoogleFonts.poppins(
                            fontSize: 12, color: AppTheme.grey600),
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            _Chip(label: '$fieldCount fields', color: AppTheme.grey100, textColor: AppTheme.grey600),
                            const SizedBox(width: 6),
                            _Chip(label: _layoutLabel(tpl.layoutStyle), color: AppTheme.grey100, textColor: AppTheme.grey600),
                            const SizedBox(width: 6),
                            if (tpl.isSystem)
                              _Chip(label: 'System', color: Colors.grey.shade100, textColor: AppTheme.grey500),
                          ],
                        ),
                      ],
                    ),
                    trailing: _TemplateMenu(
                      template: tpl,
                      onClone: () => _clone(tpl),
                      onEdit: tpl.isSystem ? null : () => _openEditor(tpl),
                      onSetDefault: tpl.isDefault ? null : () => _setDefault(tpl),
                      onDelete: (tpl.isSystem || tpl.isDefault) ? null : () => _delete(tpl),
                    ),
                  ),
                );
              },
            ),
    );
  }

  String _layoutLabel(String style) {
    switch (style) {
      case 'side_by_side': return 'Side by side';
      case 'stacked':      return 'Stacked';
      case 'card':         return 'Card';
      default:             return style;
    }
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final Color color;
  final Color textColor;
  const _Chip({required this.label, required this.color, required this.textColor});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(8)),
    child: Text(label, style: GoogleFonts.poppins(fontSize: 10, color: textColor)),
  );
}

class _TemplateMenu extends StatelessWidget {
  final ReviewTemplate template;
  final VoidCallback onClone;
  final VoidCallback? onEdit;
  final VoidCallback? onSetDefault;
  final VoidCallback? onDelete;

  const _TemplateMenu({
    required this.template,
    required this.onClone,
    this.onEdit,
    this.onSetDefault,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) => PopupMenuButton<String>(
    onSelected: (v) {
      switch (v) {
        case 'clone':      onClone();        break;
        case 'edit':       onEdit?.call();   break;
        case 'default':    onSetDefault?.call(); break;
        case 'delete':     onDelete?.call(); break;
      }
    },
    itemBuilder: (_) => [
      const PopupMenuItem(value: 'clone', child: ListTile(
        dense: true,
        leading: Icon(Icons.copy_outlined, size: 18),
        title: Text('Clone'),
        contentPadding: EdgeInsets.zero,
      )),
      if (onEdit != null)
        const PopupMenuItem(value: 'edit', child: ListTile(
          dense: true,
          leading: Icon(Icons.edit_outlined, size: 18),
          title: Text('Edit'),
          contentPadding: EdgeInsets.zero,
        )),
      if (onSetDefault != null)
        const PopupMenuItem(value: 'default', child: ListTile(
          dense: true,
          leading: Icon(Icons.star_outline, size: 18),
          title: Text('Set as Default'),
          contentPadding: EdgeInsets.zero,
        )),
      if (onDelete != null)
        const PopupMenuItem(value: 'delete', child: ListTile(
          dense: true,
          leading: Icon(Icons.delete_outline, size: 18, color: AppTheme.error),
          title: Text('Delete', style: TextStyle(color: AppTheme.error)),
          contentPadding: EdgeInsets.zero,
        )),
    ],
  );
}
