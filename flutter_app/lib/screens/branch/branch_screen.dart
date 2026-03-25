// ============================================================
// Branch Management Screen
// ============================================================
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:typed_data';
import '../../config/theme.dart';
import '../../services/api_service.dart';
import '../../providers/auth_provider.dart';
import '../../providers/school_provider.dart';

// ── Models ────────────────────────────────────────────────────
class BranchItem {
  final String id;
  final String schoolId;
  final String schoolName;
  final String name;
  final String code;
  final String address;
  final String city;
  final String phone;
  final String email;
  final String? principalName;
  final int studentCount;
  final int employeeCount;
  final bool isActive;

  const BranchItem({
    required this.id,
    required this.schoolId,
    required this.schoolName,
    required this.name,
    required this.code,
    required this.address,
    required this.city,
    required this.phone,
    required this.email,
    this.principalName,
    required this.studentCount,
    required this.employeeCount,
    required this.isActive,
  });

  factory BranchItem.fromJson(Map<String, dynamic> j) => BranchItem(
        id:            j['id']             as String,
        schoolId:      j['school_id']      as String,
        schoolName:    j['school_name']    as String? ?? '',
        name:          j['name']           as String? ?? '',
        code:          j['code']           as String? ?? '',
        address:       j['address_line1']  as String? ?? '',
        city:          j['city']           as String? ?? '',
        phone:         j['phone1']         as String? ?? '',
        email:         j['email']          as String? ?? '',
        principalName: j['principal_name'] as String?,
        studentCount:  (j['student_count']  as num?)?.toInt() ?? 0,
        employeeCount: (j['employee_count'] as num?)?.toInt() ?? 0,
        isActive:      (j['is_active']      as int?) != 0,
      );

  static List<BranchItem> mockList() => [
        const BranchItem(
          id:            'b1',
          schoolId:      's1',
          schoolName:    'Green Valley School',
          name:          'Main Branch',
          code:          'GVS-MAIN',
          address:       '12, School Road, Sector 5',
          city:          'New Delhi',
          phone:         '+91 11 1234 5678',
          email:         'main@greenvalley.edu.in',
          principalName: 'Dr. Rajesh Sharma',
          studentCount:  480,
          employeeCount: 28,
          isActive:      true,
        ),
        const BranchItem(
          id:            'b2',
          schoolId:      's1',
          schoolName:    'Green Valley School',
          name:          'East Campus',
          code:          'GVS-EAST',
          address:       '45, East Avenue, Sector 12',
          city:          'New Delhi',
          phone:         '+91 11 2345 6789',
          email:         'east@greenvalley.edu.in',
          principalName: 'Mrs. Sunita Rao',
          studentCount:  362,
          employeeCount: 22,
          isActive:      true,
        ),
        const BranchItem(
          id:            'b3',
          schoolId:      's1',
          schoolName:    'Green Valley School',
          name:          'West Campus',
          code:          'GVS-WEST',
          address:       '8, West Park, Sector 18',
          city:          'New Delhi',
          phone:         '+91 11 3456 7890',
          email:         'west@greenvalley.edu.in',
          principalName: 'Mr. Kiran Joshi',
          studentCount:  406,
          employeeCount: 24,
          isActive:      true,
        ),
      ];
}

// ── Providers ─────────────────────────────────────────────────
final _branchSchoolFilterProvider = StateProvider<String?>((ref) => null);

final _branchesProvider = FutureProvider<List<BranchItem>>((ref) async {
  final sid = ref.watch(_branchSchoolFilterProvider);
  final user = ref.watch(authNotifierProvider).valueOrNull;
  
  // Use session school if not superadmin and no filter
  final effectiveSid = sid ?? (user?.role != 'super_admin' ? user?.employee?.schoolId : null);

  try {
    final params = <String, dynamic>{};
    if (effectiveSid != null) params['school_id'] = effectiveSid;

    final data = await ApiService().get('/branches', params: params);
    final list = data['data'] as List<dynamic>? ?? [];
    return list
        .map((e) => BranchItem.fromJson(e as Map<String, dynamic>))
        .toList();
  } catch (_) {
    return [];
  }
});

final _editBranchProvider = StateProvider<BranchItem?>((ref) => null);

// ── Screen ────────────────────────────────────────────────────
class BranchScreen extends ConsumerWidget {
  const BranchScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final branchesAsy = ref.watch(_branchesProvider);
    final editBranch  = ref.watch(_editBranchProvider);

    return Scaffold(
      backgroundColor: AppTheme.grey50,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showForm(context, ref, null),
        icon:  const Icon(Icons.add_business),
        label: const Text('Add Branch'),
      ).animate().scale(delay: 300.ms),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: branchesAsy.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error:   (e, _) => Center(child: Text('Error: $e')),
          data:    (branches) => Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // List
              Expanded(
                flex: editBranch != null ? 3 : 1,
                child: _BranchList(
                  branches:  branches,
                  onEdit: (b) => ref.read(_editBranchProvider.notifier).state = b,
                ),
              ),
              // Form panel
              if (editBranch != null) ...[
                const SizedBox(width: 16),
                SizedBox(
                  width: 360,
                  child: _BranchFormPanel(
                    branch:   editBranch,
                    onClose:  () => ref.read(_editBranchProvider.notifier).state = null,
                    onSaved:  () {
                      ref.read(_editBranchProvider.notifier).state = null;
                      ref.invalidate(_branchesProvider);
                    },
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showForm(BuildContext context, WidgetRef ref, BranchItem? branch) {
    final sid = ref.read(_branchSchoolFilterProvider) ?? '';
    ref.read(_editBranchProvider.notifier).state =
        branch ?? BranchItem(
          id: '', schoolId: sid, schoolName: '', name: '', code: '',
          address: '', city: '', phone: '', email: '',
          studentCount: 0, employeeCount: 0, isActive: true,
        );
  }
}

// ── Branch List ───────────────────────────────────────────────
class _BranchList extends StatelessWidget {
  final List<BranchItem> branches;
  final ValueChanged<BranchItem> onEdit;
  const _BranchList({required this.branches, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Branches (${branches.length})',
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600, fontSize: 15)),
            // School filter for SuperAdmin
            Consumer(builder: (ctx, ref, _) {
              final user = ref.watch(authNotifierProvider).valueOrNull;
              if (user?.role != 'super_admin') return const SizedBox.shrink();
              final schoolsAsync = ref.watch(allSchoolsProvider);
              final selected     = ref.watch(_branchSchoolFilterProvider);

              return SizedBox(
                width: 220,
                child: schoolsAsync.when(
                  data: (schools) => DropdownButtonFormField<String>(
                    value: selected,
                    hint: const Text('Filter by School'),
                    isDense: true,
                    decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.all(8)),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('All Schools')),
                      ...schools.map((s) => DropdownMenuItem(
                        value: s['id'] as String,
                        child: Text(s['name'] as String, overflow: TextOverflow.ellipsis),
                      )),
                    ],
                    onChanged: (v) => ref.read(_branchSchoolFilterProvider.notifier).state = v,
                  ),
                  loading: () => const LinearProgressIndicator(),
                  error:   (_, __) => const Text('Error'),
                ),
              );
            }),
          ],
        ),
        const SizedBox(height: 14),
        Expanded(
          child: ListView.separated(
            itemCount:        branches.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (ctx, i) => _BranchCard(
              branch: branches[i],
              index:  i,
              onEdit: () => onEdit(branches[i]),
            ),
          ),
        ),
      ],
    );
  }
}

class _BranchCard extends StatelessWidget {
  final BranchItem branch;
  final int index;
  final VoidCallback onEdit;
  const _BranchCard({
    required this.branch,
    required this.index,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width:  40, height: 40,
                  decoration: BoxDecoration(
                    gradient:     AppTheme.primaryGradient,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text(
                      branch.name[0].toUpperCase(),
                      style: GoogleFonts.poppins(
                          color: Colors.white, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(branch.name,
                          style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w700, fontSize: 14)),
                      Text('${branch.schoolName} · ${branch.code}',
                          style: GoogleFonts.poppins(
                              fontSize: 11, color: AppTheme.grey600)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: branch.isActive
                        ? AppTheme.statusGreen.withOpacity(0.1)
                        : AppTheme.grey200,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    branch.isActive ? 'Active' : 'Inactive',
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      color: branch.isActive
                          ? AppTheme.statusGreen
                          : AppTheme.grey600,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 16,
              runSpacing: 6,
              children: [
                _InfoChip(Icons.location_on_outlined, branch.city),
                _InfoChip(Icons.phone_outlined,       branch.phone),
                if (branch.principalName != null)
                  _InfoChip(Icons.person_outline, branch.principalName!),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _StatBadge(
                    icon:  Icons.people,
                    value: '${branch.studentCount}',
                    label: 'Students',
                    color: AppTheme.primary),
                const SizedBox(width: 10),
                _StatBadge(
                    icon:  Icons.badge,
                    value: '${branch.employeeCount}',
                    label: 'Staff',
                    color: AppTheme.secondary),
                const Spacer(),
                OutlinedButton.icon(
                  onPressed: () => context.push(
                    '/branches/class-sections?branchId=${branch.id}&branchName=${Uri.encodeComponent(branch.name)}',
                  ),
                  icon:  const Icon(Icons.class_outlined, size: 14),
                  label: const Text('Classes'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    textStyle: GoogleFonts.poppins(fontSize: 12),
                    minimumSize: Size.zero,
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: onEdit,
                  icon:  const Icon(Icons.edit_outlined, size: 14),
                  label: const Text('Edit'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    textStyle: GoogleFonts.poppins(fontSize: 12),
                    minimumSize: Size.zero,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    )
        .animate(delay: (index * 60).ms)
        .fadeIn(duration: 300.ms)
        .slideY(begin: 0.1);
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String text;
  const _InfoChip(this.icon, this.text);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: AppTheme.grey600),
        const SizedBox(width: 3),
        Text(text,
            style: GoogleFonts.poppins(
                fontSize: 11, color: AppTheme.grey600)),
      ],
    );
  }
}

class _StatBadge extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;
  const _StatBadge({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color:        color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text('$value $label',
              style: GoogleFonts.poppins(
                  fontSize: 11, color: color, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

// ── Branch Form Panel ─────────────────────────────────────────
class _BranchFormPanel extends StatefulWidget {
  final BranchItem branch;
  final VoidCallback onClose;
  final VoidCallback onSaved;
  const _BranchFormPanel({
    required this.branch,
    required this.onClose,
    required this.onSaved,
  });

  @override
  State<_BranchFormPanel> createState() => _BranchFormPanelState();
}

class _BranchFormPanelState extends State<_BranchFormPanel> {
  final _formKey        = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _codeCtrl;
  late final TextEditingController _addressCtrl;
  late final TextEditingController _cityCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _principalCtrl;
  bool _isActive = true;
  bool _saving   = false;
  Uint8List? _logoBytes;

  @override
  void initState() {
    super.initState();
    _fillFrom(widget.branch);
  }

  @override
  void didUpdateWidget(_BranchFormPanel old) {
    super.didUpdateWidget(old);
    if (old.branch.id != widget.branch.id) {
      _disposeControllers();
      _fillFrom(widget.branch);
      setState(() {}); // rebuild with new controller values
    }
  }

  void _disposeControllers() {
    _nameCtrl.dispose();
    _codeCtrl.dispose();
    _addressCtrl.dispose();
    _cityCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _principalCtrl.dispose();
  }

  void _fillFrom(BranchItem b) {
    _nameCtrl      = TextEditingController(text: b.name);
    _codeCtrl      = TextEditingController(text: b.code);
    _addressCtrl   = TextEditingController(text: b.address);
    _cityCtrl      = TextEditingController(text: b.city);
    _phoneCtrl     = TextEditingController(text: b.phone);
    _emailCtrl     = TextEditingController(text: b.email);
    _principalCtrl = TextEditingController(text: b.principalName ?? '');
    _isActive      = b.isActive;
  }

  @override
  void dispose() {
    _disposeControllers();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    try {
      final body = {
        'name':          _nameCtrl.text.trim(),
        'code':          _codeCtrl.text.trim().toUpperCase(),
        'address_line1': _addressCtrl.text.trim(),
        'city':          _cityCtrl.text.trim(),
        'phone1':        _phoneCtrl.text.trim(),
        'email':         _emailCtrl.text.trim(),
        'school_id':     widget.branch.schoolId.isNotEmpty ? widget.branch.schoolId : null,
        'is_active':     _isActive ? 1 : 0,
      };
      if (widget.branch.id.isNotEmpty) {
        await ApiService().put('/branches/${widget.branch.id}', body: body);
      } else {
        await ApiService().post('/branches', body: body);
      }
      widget.onSaved();
    } catch (e) {
      setState(() => _saving = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:         Text('Error: $e'),
          backgroundColor: AppTheme.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.branch.id.isNotEmpty;
    return Card(
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(
                gradient: AppTheme.primaryGradient,
                borderRadius:
                    BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  Text(
                    isEdit ? 'Edit Branch' : 'New Branch',
                    style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 14),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: widget.onClose,
                    icon: const Icon(Icons.close,
                        color: Colors.white70, size: 18),
                    padding: EdgeInsets.zero,
                    constraints:
                        const BoxConstraints(minWidth: 24, minHeight: 24),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _Fld(label: 'Branch Name *', ctrl: _nameCtrl,
                        validator: (v) => v == null || v.isEmpty ? 'Required' : null),
                    const SizedBox(height: 12),
                    _Fld(label: 'Branch Code *', ctrl: _codeCtrl,
                        validator: (v) => v == null || v.isEmpty ? 'Required' : null),
                    const SizedBox(height: 12),
                    _Fld(label: 'Address',    ctrl: _addressCtrl, maxLines: 2),
                    const SizedBox(height: 12),
                    _Fld(label: 'City',       ctrl: _cityCtrl),
                    const SizedBox(height: 12),
                    _Fld(label: 'Phone',      ctrl: _phoneCtrl,
                        keyboardType: TextInputType.phone),
                    const SizedBox(height: 12),
                    _Fld(label: 'Email',      ctrl: _emailCtrl,
                        keyboardType: TextInputType.emailAddress),
                    const SizedBox(height: 12),
                    _Fld(label: 'Principal Name', ctrl: _principalCtrl),
                    const SizedBox(height: 12),
                    // Active toggle
                    Row(
                      children: [
                        Text('Active',
                            style: GoogleFonts.poppins(fontSize: 13)),
                        const Spacer(),
                        Switch(
                          value:      _isActive,
                          onChanged:  (v) => setState(() => _isActive = v),
                          activeColor: AppTheme.statusGreen,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            // Save bar
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: widget.onClose,
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _saving ? null : _save,
                      icon: _saving
                          ? const SizedBox(
                              width: 14, height: 14,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.save, size: 14),
                      label: Text(_saving ? 'Saving...' : 'Save'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ).animate().slideX(begin: 0.3, duration: 300.ms);
  }
}

class _Fld extends StatelessWidget {
  final String label;
  final TextEditingController ctrl;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final int maxLines;
  const _Fld({
    required this.label,
    required this.ctrl,
    this.validator,
    this.keyboardType,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller:   ctrl,
      validator:    validator,
      keyboardType: keyboardType,
      maxLines:     maxLines,
      style:        GoogleFonts.poppins(fontSize: 13),
      decoration:   InputDecoration(labelText: label),
    );
  }
}
