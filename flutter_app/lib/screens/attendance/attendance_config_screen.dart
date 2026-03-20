// ============================================================
// Attendance Configuration Screen (Admin)
// ============================================================
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../config/theme.dart';
import '../../services/api_service.dart';
import '../../providers/auth_provider.dart';

// ── Models ────────────────────────────────────────────────────
class AttendanceModule {
  final String id;
  final String name;
  final String type;
  final bool isActive;

  AttendanceModule({
    required this.id,
    required this.name,
    required this.type,
    required this.isActive,
  });

  factory AttendanceModule.fromJson(Map<String, dynamic> j) => AttendanceModule(
        id:       j['id'] as String,
        name:     j['name'] as String,
        type:     j['type'] as String,
        isActive: (j['is_active'] as int?) != 0,
      );

  String get typeLabel {
    switch (type) {
      case 'daily_class': return 'Daily Class';
      case 'transport':   return 'Transport / Bus';
      case 'event':       return 'Event / Picnic';
      default:            return 'Other';
    }
  }

  IconData get typeIcon {
    switch (type) {
      case 'daily_class': return Icons.school_outlined;
      case 'transport':   return Icons.directions_bus_outlined;
      case 'event':       return Icons.event_outlined;
      default:            return Icons.category_outlined;
    }
  }
}

// ── Providers ─────────────────────────────────────────────────
final _modulesProvider = FutureProvider.family<List<AttendanceModule>, String?>((ref, schoolId) async {
  try {
    final user = ref.read(authNotifierProvider).value;
    final sid = schoolId ?? user?.employee?.schoolId;
    if (sid == null) return [];
    
    final res = await ApiService().get('/attendance/modules', params: {'school_id': sid});
    final list = res['data'] as List<dynamic>? ?? [];
    return list.map((e) => AttendanceModule.fromJson(e)).toList();
  } catch (e) { return []; }
});

// ── Screen ────────────────────────────────────────────────────
class AttendanceConfigScreen extends ConsumerWidget {
  const AttendanceConfigScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final modulesAsync = ref.watch(_modulesProvider(null));

    return Scaffold(
      backgroundColor: AppTheme.grey50,
      appBar: AppBar(
        title: Text('Attendance Modules',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 16)),
        backgroundColor: Colors.white,
        foregroundColor: AppTheme.grey900,
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showModuleForm(context, ref),
        label: const Text('New Module'),
        icon: const Icon(Icons.add),
      ),
      body: modulesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error:   (e, _) => Center(child: Text('Error: $e')),
        data:    (modules) {
          if (modules.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                   Icon(Icons.rule_folder_outlined, size: 60, color: AppTheme.grey300),
                   const SizedBox(height: 16),
                   Text('No custom attendance modules found.',
                       style: GoogleFonts.poppins(color: AppTheme.grey600)),
                ],
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(20),
            itemCount: modules.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, i) {
              final mod = modules[i];
              return _ModuleCard(module: mod, ref: ref)
                  .animate().fadeIn(delay: (i * 50).ms).slideY(begin: 0.1);
            },
          );
        },
      ),
    );
  }

  void _showModuleForm(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (_) => _ModuleFormDialog(),
    ).then((_) => ref.invalidate(_modulesProvider));
  }
}

class _ModuleCard extends StatelessWidget {
  final AttendanceModule module;
  final WidgetRef ref;
  const _ModuleCard({required this.module, required this.ref});

  Future<void> _toggle(BuildContext context, bool val) async {
    try {
      await ApiService().patch('/attendance/modules/${module.id}/toggle', body: {'is_active': val});
      ref.invalidate(_modulesProvider);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppTheme.grey200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: AppTheme.primary.withOpacity(0.1),
                  child: Icon(module.typeIcon, color: AppTheme.primary, size: 20),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(module.name,
                          style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 15)),
                      Text(module.typeLabel,
                          style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.grey600)),
                    ],
                  ),
                ),
                Switch(
                  value: module.isActive,
                  onChanged: (v) => _toggle(context, v),
                  activeColor: AppTheme.primary,
                ),
              ],
            ),
            if (module.type != 'daily_class') ...[
              const Divider(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => _manageStudents(context),
                    icon:  const Icon(Icons.group_add_outlined, size: 16),
                    label: const Text('Manage Linked Students'),
                  ),
                ],
              ),
            ]
          ],
        ),
      ),
    );
  }

  void _manageStudents(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _StudentMappingSheet(module: module),
    );
  }
}

// ── Create Module Form ─────────────────────────────────────────
class _ModuleFormDialog extends StatefulWidget {
  @override
  State<_ModuleFormDialog> createState() => _ModuleFormDialogState();
}

class _ModuleFormDialogState extends State<_ModuleFormDialog> {
  final _nameCtrl = TextEditingController();
  String _type    = 'transport';
  bool _saving    = false;

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty) return;
    setState(() => _saving = true);
    try {
      await ApiService().post('/attendance/modules', body: {
        'name': _nameCtrl.text.trim(),
        'type': _type,
      });
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() => _saving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Create Tracker Module', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _nameCtrl,
            decoration: const InputDecoration(labelText: 'Tracker Name (e.g. Bus 12)'),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: _type,
            decoration: const InputDecoration(labelText: 'Type'),
            items: const [
              DropdownMenuItem(value: 'transport', child: Text('Transport / Bus')),
              DropdownMenuItem(value: 'event', child: Text('Event / Picnic')),
              DropdownMenuItem(value: 'other', child: Text('Custom Other')),
            ],
            onChanged: (v) => setState(() => _type = v!),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(onPressed: _saving ? null : _save, child: Text(_saving ? 'Saving...' : 'Create')),
      ],
    );
  }
}

// ── Student Mapping Sheet ─────────────────────────────────────
class _StudentMappingSheet extends ConsumerStatefulWidget {
  final AttendanceModule module;
  const _StudentMappingSheet({required this.module});

  @override
  ConsumerState<_StudentMappingSheet> createState() => _StudentMappingSheetState();
}

class _StudentMappingSheetState extends ConsumerState<_StudentMappingSheet> {
  List<dynamic> _students = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadStudents();
  }

  Future<void> _loadStudents() async {
    try {
      final res = await ApiService().get('/attendance/modules/${widget.module.id}/students');
      setState(() {
        _students = res['data'] ?? [];
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }
  
  // Future implementation for actually adding students to this module
  Future<void> _addStudentsDummy(BuildContext context) async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Here a selector dialog would open to multi-select students via API.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.8,
      builder: (_, ctrl) => Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Students mapped to ${widget.module.name}',
                style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => _addStudentsDummy(context),
              icon: const Icon(Icons.add),
              label: const Text('Add Students to Roster'),
            ),
            const Divider(height: 30),
            Expanded(
              child: _loading 
                ? const Center(child: CircularProgressIndicator())
                : _students.isEmpty 
                  ? const Center(child: Text('No students mapped yet. Add students to use this module!'))
                  : ListView.builder(
                      controller: ctrl,
                      itemCount: _students.length,
                      itemBuilder: (context, i) {
                        final s = _students[i];
                        final name = '${s['first_name']} ${s['last_name']}';
                        return ListTile(
                          leading: CircleAvatar(child: Text(name[0])),
                          title: Text(name),
                          subtitle: Text('Class: ${s['class_name']} ${s['section'] ?? ''}'),
                          trailing: IconButton(
                            icon: const Icon(Icons.remove_circle_outline, color: AppTheme.error),
                            onPressed: () {}, // Future impl: remove mapping
                          ),
                        );
                      },
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
