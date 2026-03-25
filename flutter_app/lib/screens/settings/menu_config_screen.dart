// ============================================================
// Menu Config Screen — hide/unhide/reorder nav items per role
// ============================================================
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../config/theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/customization_provider.dart';
import '../../services/api_service.dart';

class MenuConfigScreen extends ConsumerStatefulWidget {
  const MenuConfigScreen({super.key});

  @override
  ConsumerState<MenuConfigScreen> createState() => _MenuConfigScreenState();
}

class _MenuConfigScreenState extends ConsumerState<MenuConfigScreen> {
  String _selectedRole = 'principal';
  List<NavItemConfig>? _items;
  bool _loading  = false;
  bool _saving   = false;
  String? _error;

  static const _configurableRoles = [
    ('super_admin',   'Super Admin'),
    ('school_owner',  'School Owner'),
    ('school_admin',  'School Admin'),
    ('branch_admin',  'Branch Admin'),
    ('principal',     'Principal'),
    ('vp',            'Vice Principal'),
    ('head_teacher',  'Head Teacher'),
  ];

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  String? _schoolId() {
    final user = ref.read(authNotifierProvider).valueOrNull;
    return user?.schoolId ?? user?.employee?.schoolId;
  }

  Future<void> _loadConfig() async {
    setState(() { _loading = true; _error = null; });
    try {
      final schoolId = _schoolId();
      final params   = <String, dynamic>{'role': _selectedRole};
      if (schoolId != null) params['school_id'] = schoolId;
      final data = await ApiService().get('/customization/menu-config', params: params);
      final rawItems = data['data']?['items'] as List<dynamic>? ?? [];
      final configs  = rawItems
          .map((e) => NavItemConfig.fromJson(e as Map<String, dynamic>))
          .toList()
        ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
      setState(() { _items = configs; });
    } catch (e) {
      setState(() { _error = e.toString(); });
    } finally {
      setState(() { _loading = false; });
    }
  }

  Future<void> _save() async {
    if (_items == null) return;
    final user = ref.read(authNotifierProvider).valueOrNull;
    if (user == null) return;

    setState(() { _saving = true; });
    try {
      final schoolId = _schoolId();
      final body = <String, dynamic>{
        'role':  _selectedRole,
        'items': _items!.asMap().entries
            .map((e) => e.value.copyWith(sortOrder: e.key).toJson())
            .toList(),
      };
      if (schoolId != null) body['school_id'] = schoolId;

      await ApiService().put('/customization/menu-config', body: body);

      // Invalidate the provider cache
      if (mounted) {
        ref.invalidate(menuConfigProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Menu layout saved'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Save failed: $e'), backgroundColor: AppTheme.error),
        );
      }
    } finally {
      if (mounted) setState(() { _saving = false; });
    }
  }

  void _onReorder(int oldIdx, int newIdx) {
    if (_items == null) return;
    if (newIdx > oldIdx) newIdx--;
    setState(() {
      final item = _items!.removeAt(oldIdx);
      _items!.insert(newIdx, item);
    });
  }

  void _toggleVisible(int idx) {
    if (_items == null) return;
    setState(() {
      _items![idx] = _items![idx].copyWith(visible: !_items![idx].visible);
    });
  }

  @override
  Widget build(BuildContext context) {
    final user       = ref.watch(authNotifierProvider).valueOrNull;
    final userRole   = user?.role ?? '';
    final isSuperAdmin = userRole == 'super_admin';

    return Scaffold(
      backgroundColor: AppTheme.grey50,
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D1B63),
        foregroundColor: Colors.white,
        title: Text('Menu Layout', style: GoogleFonts.poppins(
          color: Colors.white, fontWeight: FontWeight.w600, fontSize: 18)),
        actions: [
          if (!_saving)
            TextButton(
              onPressed: _items != null ? _save : null,
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
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Role selector
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(
              children: [
                Text('Configure for:', style: GoogleFonts.poppins(
                  fontSize: 13, color: AppTheme.grey600)),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _selectedRole,
                    decoration: InputDecoration(
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    items: _configurableRoles
                        .map((r) => DropdownMenuItem(value: r.$1, child: Text(r.$2,
                              style: GoogleFonts.poppins(fontSize: 13))))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) {
                        setState(() { _selectedRole = v; _items = null; });
                        _loadConfig();
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
            child: Text(
              'Drag items to reorder. Toggle the switch to show or hide.',
              style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.grey600),
            ),
          ),
          if (!isSuperAdmin)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, size: 16, color: Colors.blue.shade700),
                    const SizedBox(width: 8),
                    Expanded(child: Text(
                      'This configuration applies to your school only.',
                      style: GoogleFonts.poppins(fontSize: 12, color: Colors.blue.shade700),
                    )),
                  ],
                ),
              ),
            ),
          Expanded(
            child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                ? Center(child: Text('Error: $_error', style: const TextStyle(color: AppTheme.error)))
                : _items == null || _items!.isEmpty
                  ? const Center(child: Text('No menu items found'))
                  : ReorderableListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      onReorder: _onReorder,
                      itemCount: _items!.length,
                      itemBuilder: (ctx, idx) {
                        final item = _items![idx];
                        return Card(
                          key: ValueKey(item.key),
                          elevation: 0,
                          color: Colors.white,
                          margin: const EdgeInsets.only(bottom: 6),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                            leading: const Icon(Icons.drag_handle, color: AppTheme.grey400),
                            title: Text(item.label, style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: item.visible ? AppTheme.grey900 : AppTheme.grey400,
                            )),
                            subtitle: Text(item.path, style: GoogleFonts.poppins(
                              fontSize: 11, color: AppTheme.grey400)),
                            trailing: Switch(
                              value: item.visible,
                              activeColor: const Color(0xFF1565C0),
                              onChanged: (_) => _toggleVisible(idx),
                            ),
                          ),
                        );
                      },
                    ),
          ),
        ],
      ),
    );
  }
}
