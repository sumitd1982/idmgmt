// ============================================================
// Roles & Permissions Settings Screen
// ============================================================
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../config/theme.dart';
import '../../services/api_service.dart';
import '../../providers/auth_provider.dart';

// ── Model ─────────────────────────────────────────────────────
class OrgRole {
  final String id;
  final String name;
  final String code;
  final int level;
  final String description;
  final bool canApprove;
  final bool canUploadBulk;
  final bool isActive;
  final Map<String, dynamic> permissions;

  OrgRole({
    required this.id,
    required this.name,
    required this.code,
    required this.level,
    required this.description,
    required this.canApprove,
    required this.canUploadBulk,
    required this.isActive,
    required this.permissions,
  });

  factory OrgRole.fromJson(Map<String, dynamic> j) {
    Map<String, dynamic> perms = {};
    if (j['permissions'] != null) {
      if (j['permissions'] is String) {
        // Handle if stringified JSON
        // Assume backend sends an object for now, or it's handled by Dio
      } else if (j['permissions'] is Map) {
        perms = Map<String, dynamic>.from(j['permissions']);
      }
    }
    return OrgRole(
      id:            j['id'] as String,
      name:          j['name'] as String,
      code:          j['code'] as String,
      level:         j['level'] as int,
      description:   j['description'] as String? ?? '',
      canApprove:    (j['can_approve'] as int?) == 1,
      canUploadBulk: (j['can_upload_bulk'] as int?) == 1,
      isActive:      (j['is_active'] as int?) != 0,
      permissions:   perms,
    );
  }
}

// ── Providers ─────────────────────────────────────────────────
final _rolesProvider = FutureProvider.family<List<OrgRole>, String?>((ref, schoolId) async {
  try {
    final user = ref.read(authNotifierProvider).value;
    final sid = schoolId ?? user?.employee?.schoolId;
    if (sid == null) return [];
    final res = await ApiService().get('/org/roles/$sid');
    final list = res['data'] as List<dynamic>? ?? [];
    return list.map((e) => OrgRole.fromJson(e)).toList();
  } catch (e) {
    return [];
  }
});

// ── Screen ────────────────────────────────────────────────────
class RolesSettingsScreen extends ConsumerWidget {
  const RolesSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rolesAsync = ref.watch(_rolesProvider(null));

    return Scaffold(
      backgroundColor: AppTheme.grey50,
      appBar: AppBar(
        title: Text('Roles & Permissions',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 16)),
        backgroundColor: Colors.white,
        foregroundColor: AppTheme.grey900,
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showRoleForm(context, ref, null),
        label: const Text('New Role'),
        icon: const Icon(Icons.add),
      ),
      body: rolesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error:   (e, _) => Center(child: Text('Error: $e')),
        data:    (roles) {
          if (roles.isEmpty) {
            return const Center(child: Text('No roles configured.'));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(20),
            itemCount: roles.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, i) {
              final role = roles[i];
              return Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: AppTheme.grey200),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  leading: CircleAvatar(
                    backgroundColor: AppTheme.primary.withOpacity(0.1),
                    child: Text('L${role.level}',
                        style: GoogleFonts.poppins(
                            color: AppTheme.primary,
                            fontWeight: FontWeight.bold,
                            fontSize: 13)),
                  ),
                  title: Text(role.name,
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        if (role.canApprove) _Badge('Can Approve', AppTheme.accent),
                        if (role.canUploadBulk) _Badge('Bulk Upload', AppTheme.statusGreen),
                        if (role.permissions.keys.isNotEmpty)
                          _Badge('${role.permissions.length} Custom Perms', AppTheme.grey700),
                      ],
                    ),
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.edit_outlined, color: AppTheme.primary),
                    onPressed: () => _showRoleForm(context, ref, role),
                  ),
                ),
              ).animate().fadeIn(delay: (i * 50).ms).slideY(begin: 0.1);
            },
          );
        },
      ),
    );
  }

  void _showRoleForm(BuildContext context, WidgetRef ref, OrgRole? role) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _RoleFormSheet(role: role),
    ).then((_) {
      // Refresh provider on close
      ref.invalidate(_rolesProvider);
    });
  }
}

class _Badge extends StatelessWidget {
  final String text;
  final Color color;
  const _Badge(this.text, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        text,
        style: GoogleFonts.poppins(fontSize: 10, color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}

// ── Form Sheet ────────────────────────────────────────────────
class _RoleFormSheet extends StatefulWidget {
  final OrgRole? role;
  const _RoleFormSheet({this.role});

  @override
  State<_RoleFormSheet> createState() => _RoleFormSheetState();
}

class _RoleFormSheetState extends State<_RoleFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _descCtrl;
  int  _level      = 5;
  bool _canApprove = false;
  bool _canBulk    = false;
  bool _isActive   = true;
  bool _saving     = false;
  
  // Custom module permissions
  bool _canManageAttendance = false;
  bool _canManageTransport  = false;

  @override
  void initState() {
    super.initState();
    final r = widget.role;
    _nameCtrl = TextEditingController(text: r?.name ?? '');
    _descCtrl = TextEditingController(text: r?.description ?? '');
    _level      = r?.level ?? 5;
    _canApprove = r?.canApprove ?? false;
    _canBulk    = r?.canUploadBulk ?? false;
    _isActive   = r?.isActive ?? true;

    final perms = r?.permissions ?? {};
    _canManageAttendance = perms['can_manage_attendance'] == true;
    _canManageTransport  = perms['can_manage_transport'] == true;
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    
    try {
      final user = ProviderScope.containerOf(context).read(authNotifierProvider).value;
      final sid = user?.employee?.schoolId;
      
      final body = {
        'school_id':   sid,
        'name':        _nameCtrl.text.trim(),
        'code':        _nameCtrl.text.trim().toLowerCase().replaceAll(' ', '_'),
        'level':       _level,
        'description': _descCtrl.text.trim(),
        'can_approve': _canApprove,
        'can_upload_bulk': _canBulk,
        'is_active':   _isActive,
        'permissions': {
          'can_manage_attendance': _canManageAttendance,
          'can_manage_transport':  _canManageTransport,
        }
      };

      if (widget.role != null) {
        await ApiService().put('/org/roles/${widget.role!.id}', body: body);
      } else {
        await ApiService().post('/org/roles', body: body);
      }

      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Role saved'), backgroundColor: AppTheme.statusGreen),
      );
    } catch (e) {
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.error),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.8, expand: false,
      builder: (_, ctrl) => Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Form(
          key: _formKey,
          child: ListView(
            controller: ctrl,
            children: [
              Text(widget.role == null ? 'Create Role' : 'Edit Role',
                  style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w700)),
              const Divider(height: 30),
              
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(labelText: 'Role Name * (e.g. Bus Driver)'),
                validator: (v) => v!.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<int>(
                value: _level,
                decoration: const InputDecoration(labelText: 'Hierarchy Level *'),
                items: List.generate(8, (i) => DropdownMenuItem(
                  value: i + 1,
                  child: Text('Level ${i + 1}'),
                )),
                onChanged: (v) => setState(() => _level = v ?? 5),
              ),
              const SizedBox(height: 16),
              
              SwitchListTile(
                title: const Text('Can Approve Requests'),
                value: _canApprove,
                onChanged: (v) => setState(() => _canApprove = v),
              ),
              SwitchListTile(
                title: const Text('Can Bulk Upload'),
                value: _canBulk,
                onChanged: (v) => setState(() => _canBulk = v),
              ),
              
              const SizedBox(height: 16),
              Text('Module Permissions', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
              Container(
                margin: const EdgeInsets.only(top: 8),
                decoration: BoxDecoration(
                  border: Border.all(color: AppTheme.grey200),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    SwitchListTile(
                      title: const Text('Can Manage Custom Attendance'),
                      subtitle: const Text('Allows taking bus or picnic attendance'),
                      value: _canManageAttendance,
                      onChanged: (v) => setState(() => _canManageAttendance = v),
                    ),
                    const Divider(height: 1),
                    SwitchListTile(
                      title: const Text('Can Manage Transport Routes'),
                      value: _canManageTransport,
                      onChanged: (v) => setState(() => _canManageTransport = v),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _saving ? null : _save,
                child: Text(_saving ? 'Saving...' : 'Save Role'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
