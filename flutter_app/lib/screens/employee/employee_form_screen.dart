// ============================================================
// Employee Form Screen
// ============================================================
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../../config/theme.dart';
import '../../config/constants.dart';
import '../../models/employee_model.dart';
import '../../services/api_service.dart';
import '../../providers/auth_provider.dart';

// Reuse the same providers from employee_screen.dart if needed, 
// but for the form we'll define a simple role provider.
final _rolesProvider = FutureProvider.family<List<Map<String, dynamic>>, String?>((ref, schoolId) async {
  try {
    final user = ref.read(authNotifierProvider).value;
    final sid = schoolId ?? user?.schoolId ?? user?.employee?.schoolId;
    if (sid == null) return [];
    final res = await ApiService().get('/org/roles/$sid');
    return List<Map<String, dynamic>>.from(res['data'] ?? []);
  } catch (_) { return []; }
});

final _managersProvider = FutureProvider.family<List<EmployeeRecord>, String?>((ref, schoolId) async {
  try {
    final res = await ApiService().get('/employees', params: {
      if (schoolId != null) 'school_id': schoolId,
    });
    final list = res['data'] as List<dynamic>? ?? [];
    return list.map((e) => EmployeeRecord.fromJson(e)).toList();
  } catch (_) { return []; }
});

class EmployeeFormScreen extends ConsumerStatefulWidget {
  final String? employeeId;
  final String? reportsTo;
  final String? schoolId;
  final String? branchId;

  const EmployeeFormScreen({
    super.key,
    this.employeeId,
    this.reportsTo,
    this.schoolId,
    this.branchId,
  });

  @override
  ConsumerState<EmployeeFormScreen> createState() => _EmployeeFormScreenState();
}

class _EmployeeFormScreenState extends ConsumerState<EmployeeFormScreen> {
  final _formKey = GlobalKey<FormState>();
  
  final _firstCtrl = TextEditingController();
  final _lastCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _empIdCtrl = TextEditingController();
  
  int _roleLevel = 5;
  String? _managerId;
  String? _currentSchoolId;
  String? _currentBranchId;
  
  bool _canApprove = false;
  bool _canBulk = false;
  bool _isActive = true;
  bool _saving = false;
  bool _loading = false;
  
  Uint8List? _photo;
  List<String> _extraRoles = [];

  @override
  void initState() {
    super.initState();
    _currentSchoolId = widget.schoolId;
    _currentBranchId = widget.branchId;
    _managerId = widget.reportsTo;
    
    if (widget.employeeId != null) {
      _loadEmployee();
    }
  }

  Future<void> _loadEmployee() async {
    setState(() => _loading = true);
    try {
      final res = await ApiService().get('/employees/${widget.employeeId}');
      final e = EmployeeRecord.fromJson(res['data']);
      setState(() {
        _firstCtrl.text = e.firstName;
        _lastCtrl.text = e.lastName;
        _emailCtrl.text = e.email;
        _phoneCtrl.text = e.phone ?? '';
        _empIdCtrl.text = e.employeeId;
        _roleLevel = e.roleLevel;
        _managerId = e.reportsToEmpId;
        _canApprove = e.canApprove;
        _canBulk = e.canUploadBulk;
        _isActive = e.isActive;
        _extraRoles = List.from(e.extraRoles);
        _currentSchoolId = e.schoolId;
        _currentBranchId = e.branchId;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error loading employee: $e')));
    }
  }

  Future<void> _pickPhoto() async {
    final picker = ImagePicker();
    final img = await picker.pickImage(source: ImageSource.gallery, maxWidth: 300, imageQuality: 85);
    if (img == null) return;
    final bytes = await img.readAsBytes();
    setState(() => _photo = bytes);
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    try {
      final body = {
        'first_name': _firstCtrl.text.trim(),
        'last_name': _lastCtrl.text.trim(),
        'email': _emailCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
        'employee_id': _empIdCtrl.text.trim(),
        'role_level': _roleLevel,
        'reports_to_emp_id': _managerId,
        'isActive': _isActive ? 1 : 0,
        'extra_roles': _extraRoles,
        'school_id': _currentSchoolId ?? ref.read(authNotifierProvider).value?.schoolId,
        'branch_id': _currentBranchId,
      };
      
      if (widget.employeeId != null) {
        await ApiService().put('/employees/${widget.employeeId}', body: body);
      } else {
        await ApiService().post('/employees', body: body);
      }
      
      if (!mounted) return;
      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Employee saved successfully'), backgroundColor: AppTheme.statusGreen),
      );
    } catch (e) {
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.error));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.employeeId != null ? 'Edit Employee' : 'Add Employee'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Center(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 600),
              child: Column(
                children: [
                  GestureDetector(
                    onTap: _pickPhoto,
                    child: CircleAvatar(
                      radius: 50,
                      backgroundColor: AppTheme.grey200,
                      backgroundImage: _photo != null ? MemoryImage(_photo!) : null,
                      child: _photo == null ? const Icon(Icons.add_a_photo, size: 32, color: AppTheme.grey600) : null,
                    ),
                  ),
                  const SizedBox(height: 32),
                  Row(
                    children: [
                      Expanded(
                        child: _Fld(label: 'First Name *', ctrl: _firstCtrl, validator: (v) => v!.isEmpty ? 'Required' : null),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _Fld(label: 'Last Name *', ctrl: _lastCtrl, validator: (v) => v!.isEmpty ? 'Required' : null),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _Fld(label: 'Email *', ctrl: _emailCtrl, keyboardType: TextInputType.emailAddress, validator: (v) => v!.isEmpty ? 'Required' : null),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _Fld(label: 'Phone', ctrl: _phoneCtrl, keyboardType: TextInputType.phone),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _Fld(label: 'Employee ID', ctrl: _empIdCtrl),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const Divider(),
                  const SizedBox(height: 24),
                  
                  // Role Level
                  DropdownButtonFormField<int>(
                    value: _roleLevel,
                    decoration: const InputDecoration(labelText: 'Hierarchy Level *'),
                    items: AppConstants.orgLevels.entries.map((e) => DropdownMenuItem(
                      value: e.key,
                      child: Text('Level ${e.key}: ${e.value}'),
                    )).toList(),
                    onChanged: (v) => setState(() {
                      _roleLevel = v ?? _roleLevel;
                      _managerId = null;
                    }),
                  ),
                  const SizedBox(height: 16),
                  
                  // Manager
                  Consumer(builder: (context, ref, _) {
                    final managersAsy = ref.watch(_managersProvider(_currentSchoolId));
                    return managersAsy.when(
                      loading: () => const LinearProgressIndicator(),
                      error: (_, __) => const SizedBox(),
                      data: (employees) {
                        final managers = employees.where((e) => e.roleLevel < _roleLevel && e.id != widget.employeeId).toList();
                        return DropdownButtonFormField<String>(
                          value: _managerId,
                          decoration: const InputDecoration(labelText: 'Reports To (Manager)'),
                          items: [
                            const DropdownMenuItem(value: null, child: Text('— None (Top Level) —')),
                            ...managers.map((m) => DropdownMenuItem(value: m.id, child: Text('${m.fullName} (L${m.roleLevel})'))),
                          ],
                          onChanged: (v) => setState(() => _managerId = v),
                        );
                      },
                    );
                  }),
                  const SizedBox(height: 24),
                  
                  // Toggles
                  _ToggleRow(label: 'Can Approve Requests', value: _canApprove, onToggle: (v) => setState(() => _canApprove = v)),
                  _ToggleRow(label: 'Bulk Upload Permission', value: _canBulk, onToggle: (v) => setState(() => _canBulk = v)),
                  _ToggleRow(label: 'Active Account', value: _isActive, onToggle: (v) => setState(() => _isActive = v)),
                  
                  const SizedBox(height: 40),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: _saving ? null : _save,
                      icon: _saving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.save),
                      label: Text(_saving ? 'Saving...' : 'Save Employee'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Fld extends StatelessWidget {
  final String label;
  final TextEditingController ctrl;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  const _Fld({required this.label, required this.ctrl, this.validator, this.keyboardType});

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: ctrl,
      validator: validator,
      keyboardType: keyboardType,
      style: GoogleFonts.poppins(fontSize: 14),
      decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onToggle;
  const _ToggleRow({required this.label, required this.value, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      title: Text(label, style: GoogleFonts.poppins(fontSize: 14)),
      value: value,
      onChanged: onToggle,
      activeColor: AppTheme.primary,
      contentPadding: EdgeInsets.zero,
    );
  }
}
