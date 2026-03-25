// ============================================================
// Dashboard Config Screen — hide/unhide/reorder/resize widgets
// ============================================================
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../config/theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/customization_provider.dart';
import '../../services/api_service.dart';

class DashboardConfigScreen extends ConsumerStatefulWidget {
  const DashboardConfigScreen({super.key});

  @override
  ConsumerState<DashboardConfigScreen> createState() => _DashboardConfigScreenState();
}

class _DashboardConfigScreenState extends ConsumerState<DashboardConfigScreen> {
  String _selectedRole = 'principal';
  List<WidgetConfig>? _widgets;
  bool _loading = false;
  bool _saving  = false;

  static const _configurableRoles = [
    ('super_admin',  'Super Admin'),
    ('school_owner', 'School Owner'),
    ('principal',    'Principal'),
    ('branch_admin', 'Branch Admin'),
    ('vp',           'Vice Principal'),
    ('head_teacher', 'Head Teacher'),
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
    setState(() { _loading = true; });
    try {
      final schoolId = _schoolId();
      final params   = <String, dynamic>{'role': _selectedRole};
      if (schoolId != null) params['school_id'] = schoolId;
      final data = await ApiService().get('/customization/dashboard-config', params: params);
      final rawWidgets = data['data']?['widgets'] as List<dynamic>? ?? [];
      final configs    = rawWidgets
          .map((e) => WidgetConfig.fromJson(e as Map<String, dynamic>))
          .toList()
        ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
      setState(() { _widgets = configs; });
    } catch (_) {
      setState(() { _widgets = []; });
    } finally {
      setState(() { _loading = false; });
    }
  }

  Future<void> _save() async {
    if (_widgets == null) return;
    setState(() { _saving = true; });
    try {
      final schoolId = _schoolId();
      final body = <String, dynamic>{
        'role':    _selectedRole,
        'widgets': _widgets!.asMap().entries
            .map((e) => e.value.copyWith(sortOrder: e.key).toJson())
            .toList(),
      };
      if (schoolId != null) body['school_id'] = schoolId;

      await ApiService().put('/customization/dashboard-config', body: body);
      if (mounted) {
        ref.invalidate(dashboardConfigProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Dashboard layout saved'), backgroundColor: Colors.green),
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
    if (_widgets == null) return;
    if (newIdx > oldIdx) newIdx--;
    setState(() {
      final w = _widgets!.removeAt(oldIdx);
      _widgets!.insert(newIdx, w);
    });
  }

  void _toggleVisible(int idx) {
    if (_widgets == null) return;
    setState(() {
      _widgets![idx] = _widgets![idx].copyWith(visible: !_widgets![idx].visible);
    });
  }

  void _toggleColSpan(int idx) {
    if (_widgets == null) return;
    setState(() {
      final cur = _widgets![idx].colSpan;
      _widgets![idx] = _widgets![idx].copyWith(colSpan: cur == 2 ? 1 : 2);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.grey50,
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D1B63),
        foregroundColor: Colors.white,
        title: Text('Dashboard Widgets', style: GoogleFonts.poppins(
          color: Colors.white, fontWeight: FontWeight.w600, fontSize: 18)),
        actions: [
          if (!_saving)
            TextButton(
              onPressed: _widgets != null ? _save : null,
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
                        setState(() { _selectedRole = v; _widgets = null; });
                        _loadConfig();
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
            child: Text(
              'Drag to reorder • Toggle visibility • Tap the width icon to change size',
              style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.grey600),
            ),
          ),
          // Legend
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Row(
              children: [
                _LegendChip(color: const Color(0xFF1565C0), label: 'Full width'),
                const SizedBox(width: 8),
                _LegendChip(color: Colors.orange.shade700, label: 'Half width'),
              ],
            ),
          ),
          Expanded(
            child: _loading
              ? const Center(child: CircularProgressIndicator())
              : (_widgets == null || _widgets!.isEmpty)
                ? const Center(child: Text('No widgets found'))
                : ReorderableListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    onReorder: _onReorder,
                    itemCount: _widgets!.length,
                    itemBuilder: (ctx, idx) {
                      final w = _widgets![idx];
                      final isFullWidth = w.colSpan == 2;
                      return Card(
                        key: ValueKey(w.key),
                        elevation: 0,
                        color: Colors.white,
                        margin: const EdgeInsets.only(bottom: 6),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: BorderSide(
                            color: isFullWidth
                              ? const Color(0xFF1565C0).withOpacity(0.3)
                              : Colors.orange.shade300,
                            width: 1,
                          ),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                          leading: const Icon(Icons.drag_handle, color: AppTheme.grey400),
                          title: Text(w.label, style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: w.visible ? AppTheme.grey900 : AppTheme.grey400,
                          )),
                          subtitle: Text(isFullWidth ? 'Full width' : 'Half width',
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              color: isFullWidth
                                ? const Color(0xFF1565C0)
                                : Colors.orange.shade700,
                            )),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Width toggle
                              IconButton(
                                icon: Icon(
                                  isFullWidth ? Icons.width_full : Icons.width_normal,
                                  color: isFullWidth
                                    ? const Color(0xFF1565C0)
                                    : Colors.orange.shade700,
                                  size: 20,
                                ),
                                tooltip: isFullWidth ? 'Switch to half width' : 'Switch to full width',
                                onPressed: () => _toggleColSpan(idx),
                              ),
                              Switch(
                                value: w.visible,
                                activeColor: const Color(0xFF1565C0),
                                onChanged: (_) => _toggleVisible(idx),
                              ),
                            ],
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

class _LegendChip extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendChip({required this.color, required this.label});

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(width: 12, height: 12, decoration: BoxDecoration(
        color: color, borderRadius: BorderRadius.circular(2))),
      const SizedBox(width: 4),
      Text(label, style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.grey600)),
    ],
  );
}
