// ============================================================
// Class Section Manager
// ============================================================
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../config/theme.dart';
import '../../services/api_service.dart';
import '../../data/lookups.dart';

// ── Provider ─────────────────────────────────────────────────
final classSectionsProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>((ref, branchId) async {
  try {
    final res = await ApiService().get('/classes/sections/all', params: {'branch_id': branchId});
    return List<Map<String, dynamic>>.from(res['data'] ?? []);
  } catch (_) { return []; }
});

class ClassSectionScreen extends ConsumerStatefulWidget {
  final String branchId;
  final String branchName;

  const ClassSectionScreen({
    super.key,
    required this.branchId,
    required this.branchName,
  });

  @override
  ConsumerState<ClassSectionScreen> createState() => _ClassSectionScreenState();
}

class _ClassSectionScreenState extends ConsumerState<ClassSectionScreen> {
  String? _addClassName;
  String? _addSectionVal;
  bool    _adding = false;

  Future<void> _submitAddSection() async {
    if (_addClassName == null || _addSectionVal == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select both class and section')));
      return;
    }
    setState(() => _adding = true);
    try {
      await ApiService().post('/classes/sections', body: {
        'branch_id':  widget.branchId,
        'class_name': _addClassName,
        'section':    _addSectionVal,
      });
      ref.invalidate(classSectionsProvider(widget.branchId));
      setState(() { _addClassName = null; _addSectionVal = null; });
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.error));
    } finally {
      if (mounted) setState(() => _adding = false);
    }
  }

  Future<void> _deleteSection(String sectionId, String label) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Remove Section?'),
        content: Text('Remove "$label" from this branch?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ApiService().delete('/classes/sections/$sectionId');
      ref.invalidate(classSectionsProvider(widget.branchId));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.error));
    }
  }

  @override
  Widget build(BuildContext context) {
    final sectionsAsync = ref.watch(classSectionsProvider(widget.branchId));

    return Scaffold(
      appBar: AppBar(
        title: Text('Class Sections — ${widget.branchName}'),
        actions: [
          TextButton.icon(
            onPressed: () => _showAddDialog(),
            icon: const Icon(Icons.add, color: Colors.white),
            label: Text('Add', style: GoogleFonts.poppins(color: Colors.white)),
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Summary banner ────────────────────────────────
          sectionsAsync.when(
            loading: () => const SizedBox(),
            error:   (_, __) => const SizedBox(),
            data:    (rows) => Container(
              color: AppTheme.primary.withOpacity(0.06),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  const Icon(Icons.class_outlined, size: 18, color: AppTheme.primary),
                  const SizedBox(width: 8),
                  Text('${rows.length} class-section rows configured',
                      style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.primary)),
                ],
              ),
            ),
          ),

          // ── Table ─────────────────────────────────────────
          Expanded(
            child: sectionsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (rows) {
                if (rows.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.class_outlined, size: 64, color: AppTheme.grey400),
                        const SizedBox(height: 12),
                        Text('No class sections yet',
                            style: GoogleFonts.poppins(color: AppTheme.grey600)),
                        const SizedBox(height: 8),
                        ElevatedButton.icon(
                          onPressed: () => _showAddDialog(),
                          icon: const Icon(Icons.add),
                          label: const Text('Add Class Section'),
                        ),
                      ],
                    ),
                  );
                }

                // Group by class_name for display
                final Map<String, List<Map<String, dynamic>>> grouped = {};
                for (final row in rows) {
                  final cn = row['class_name'] as String? ?? '?';
                  grouped.putIfAbsent(cn, () => []).add(row);
                }

                return SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: grouped.entries.map((entry) {
                      return _ClassCard(
                        className:  entry.key,
                        sections:   entry.value,
                        onDelete:   (id, label) => _deleteSection(id, label),
                      );
                    }).toList(),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showAddDialog() {
    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setDState) => AlertDialog(
          title: Text('Add Class Section',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: _addClassName,
                decoration: const InputDecoration(labelText: 'Class'),
                items: Lookups.defaultClasses.map((c) =>
                  DropdownMenuItem(value: c, child: Text(c))).toList(),
                onChanged: (v) { setDState(() => _addClassName = v); setState(() => _addClassName = v); },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _addSectionVal,
                decoration: const InputDecoration(labelText: 'Section'),
                items: Lookups.defaultSections.map((s) =>
                  DropdownMenuItem(value: s, child: Text(s))).toList(),
                onChanged: (v) { setDState(() => _addSectionVal = v); setState(() => _addSectionVal = v); },
              ),
              if (_addClassName != null && _addSectionVal != null) ...[
                const SizedBox(height: 12),
                Chip(
                  label: Text('Preview: ${_addClassName!}${_addSectionVal!}',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                  backgroundColor: AppTheme.primary.withOpacity(0.1),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton.icon(
              onPressed: _adding ? null : () { Navigator.pop(ctx); _submitAddSection(); },
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Class Card ────────────────────────────────────────────────
class _ClassCard extends StatelessWidget {
  final String className;
  final List<Map<String, dynamic>> sections;
  final void Function(String id, String label) onDelete;

  const _ClassCard({
    required this.className,
    required this.sections,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.primary,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text('Class $className',
                      style: GoogleFonts.poppins(
                          color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                ),
                const SizedBox(width: 8),
                Text('${sections.length} section${sections.length == 1 ? '' : 's'}',
                    style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.grey600)),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: sections.map((sec) {
                final label = sec['class_section'] as String? ??
                    '${className}${sec['section'] ?? ''}';
                return Chip(
                  label: Text(label,
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 12)),
                  backgroundColor: AppTheme.primary.withOpacity(0.08),
                  deleteIcon: const Icon(Icons.close, size: 14),
                  onDeleted: () => onDelete(sec['id'] as String, label),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}
