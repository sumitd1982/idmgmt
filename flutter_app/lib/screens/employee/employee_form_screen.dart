// ============================================================
// Employee Form Screen — Full rewrite with all fields
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
import '../../providers/school_provider.dart';
import '../../data/lookups.dart';

// ── Providers ──────────────────────────────────────────────────
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

final _classSectionsProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String?>((ref, branchId) async {
  if (branchId == null) return [];
  try {
    final res = await ApiService().get('/classes/sections/all', params: {'branch_id': branchId});
    return List<Map<String, dynamic>>.from(res['data'] ?? []);
  } catch (_) { return []; }
});

final _subjectsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  try {
    final res = await ApiService().get('/org/subjects');
    return List<Map<String, dynamic>>.from(res['data'] ?? []);
  } catch (_) {
    return Lookups.subjects.map((s) => {'name': s, 'id': s}).toList();
  }
});

// ── Screen ─────────────────────────────────────────────────────
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

class _EmployeeFormScreenState extends ConsumerState<EmployeeFormScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();

  // ── Personal ───────────────────────────────────────────────
  final _firstCtrl       = TextEditingController();
  final _lastCtrl        = TextEditingController();
  final _displayCtrl     = TextEditingController();
  final _empIdCtrl       = TextEditingController();
  String? _gender;
  DateTime? _dob;

  // ── Contact ────────────────────────────────────────────────
  final _emailCtrl       = TextEditingController();
  final _phoneCtrl       = TextEditingController();
  final _altPhoneCtrl    = TextEditingController();
  final _whatsappCtrl    = TextEditingController();

  // ── Address ────────────────────────────────────────────────
  final _addr1Ctrl       = TextEditingController();
  final _addr2Ctrl       = TextEditingController();
  final _cityCtrl        = TextEditingController();
  String? _state;
  String  _country       = 'India';
  final _zipCtrl         = TextEditingController();

  // ── Professional ───────────────────────────────────────────
  DateTime? _doj;
  final _qualCtrl        = TextEditingController();
  final _specCtrl        = TextEditingController();
  final _expCtrl         = TextEditingController();
  List<String> _assignedClasses = [];
  List<String> _subjectIds      = [];

  // ── Role & org ──────────────────────────────────────────────
  int     _roleLevel     = 5;
  String? _managerId;
  String? _currentSchoolId;
  String? _currentBranchId;

  // ── Permissions ────────────────────────────────────────────
  bool _canApprove  = false;
  bool _canBulk     = false;
  bool _isActive    = true;
  final Map<String, bool> _perms = {
    for (final p in Lookups.permissions) p['key']!: false
  };

  // ── Photo ──────────────────────────────────────────────────
  Uint8List? _photo;
  String?    _photoUrl;
  bool       _uploadingPhoto = false;

  // ── Extra roles ────────────────────────────────────────────
  List<String> _extraRoles = [];

  bool _saving  = false;
  bool _loading = false;

  late AnimationController _animCtrl;
  late Animation<double>   _fadeAnim;

  @override
  void initState() {
    super.initState();
    _currentSchoolId = widget.schoolId;
    _currentBranchId = widget.branchId;
    _managerId       = widget.reportsTo;

    _animCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);

    if (widget.employeeId != null) {
      _loadEmployee();
    } else {
      _animCtrl.forward();
    }
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    for (final c in [_firstCtrl, _lastCtrl, _displayCtrl, _empIdCtrl,
                     _emailCtrl, _phoneCtrl, _altPhoneCtrl, _whatsappCtrl,
                     _addr1Ctrl, _addr2Ctrl, _cityCtrl, _zipCtrl,
                     _qualCtrl, _specCtrl, _expCtrl]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadEmployee() async {
    setState(() => _loading = true);
    try {
      final res = await ApiService().get('/employees/${widget.employeeId}');
      final e = EmployeeRecord.fromJson(res['data']);
      final raw = res['data'] as Map<String, dynamic>;

      // Parse permissions JSON
      Map<String, dynamic> permsRaw = {};
      if (raw['permissions'] != null) {
        try {
          permsRaw = raw['permissions'] is Map
              ? Map<String, dynamic>.from(raw['permissions'])
              : {};
        } catch (_) {}
      }

      setState(() {
        _firstCtrl.text     = e.firstName;
        _lastCtrl.text      = e.lastName;
        _displayCtrl.text   = raw['display_name'] as String? ?? '';
        _emailCtrl.text     = e.email;
        _phoneCtrl.text     = e.phone ?? '';
        _altPhoneCtrl.text  = raw['alt_phone'] as String? ?? '';
        _whatsappCtrl.text  = raw['whatsapp_no'] as String? ?? '';
        _empIdCtrl.text     = e.employeeId;
        _roleLevel          = e.roleLevel;
        _managerId          = e.reportsToEmpId;
        _canApprove         = e.canApprove;
        _canBulk            = e.canUploadBulk;
        _isActive           = e.isActive;
        _extraRoles         = List.from(e.extraRoles);
        _currentSchoolId    = e.schoolId;
        _currentBranchId    = e.branchId;
        _gender             = raw['gender'] as String?;
        _state              = raw['state'] as String?;
        _country            = raw['country'] as String? ?? 'India';
        _addr1Ctrl.text     = raw['address_line1'] as String? ?? '';
        _addr2Ctrl.text     = raw['address_line2'] as String? ?? '';
        _cityCtrl.text      = raw['city'] as String? ?? '';
        _zipCtrl.text       = raw['zip_code'] as String? ?? '';
        _qualCtrl.text      = raw['qualification'] as String? ?? '';
        _specCtrl.text      = raw['specialization'] as String? ?? '';
        _expCtrl.text       = (raw['experience_years'] ?? '').toString();
        _photoUrl           = raw['photo_url'] as String?;

        if (raw['date_of_birth'] != null) {
          try { _dob = DateTime.parse(raw['date_of_birth'] as String); } catch (_) {}
        }
        if (raw['date_of_joining'] != null) {
          try { _doj = DateTime.parse(raw['date_of_joining'] as String); } catch (_) {}
        }

        final ac = raw['assigned_classes'];
        _assignedClasses = ac is List ? List<String>.from(ac.map((x) => x.toString())) : [];
        final si = raw['subject_ids'];
        _subjectIds = si is List ? List<String>.from(si.map((x) => x.toString())) : [];

        for (final p in Lookups.permissions) {
          _perms[p['key']!] = permsRaw[p['key']] == true;
        }

        _loading = false;
      });
      _animCtrl.forward();
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading employee: $e')));
    }
  }

  Future<void> _pickPhoto() async {
    final picker = ImagePicker();
    final img = await picker.pickImage(source: ImageSource.gallery, maxWidth: 400, imageQuality: 85);
    if (img == null) return;
    final bytes = await img.readAsBytes();
    setState(() { _photo = bytes; _uploadingPhoto = true; });
    try {
      final resp = await ApiService().uploadFile(
        '/uploads/employee-photo',
        bytes: bytes,
        fileName: 'photo.jpg',
        fieldName: 'photo',
      );
      final url = resp['data']?['url'] as String?;
      if (url != null && mounted) setState(() => _photoUrl = url);
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Photo upload failed'), backgroundColor: AppTheme.error));
    } finally {
      if (mounted) setState(() => _uploadingPhoto = false);
    }
  }

  Future<void> _pickDate(bool isDob) async {
    final now    = DateTime.now();
    final first  = isDob ? DateTime(1940) : DateTime(2000);
    final last   = isDob ? now.subtract(const Duration(days: 365 * 18)) : now;
    final init   = isDob ? (_dob ?? DateTime(1990)) : (_doj ?? now);
    final picked = await showDatePicker(
      context: context,
      initialDate: init.isBefore(first) ? first : (init.isAfter(last) ? last : init),
      firstDate: first,
      lastDate: last,
    );
    if (picked != null) {
      setState(() { if (isDob) _dob = picked; else _doj = picked; });
    }
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    try {
      final body = <String, dynamic>{
        'first_name':       _firstCtrl.text.trim(),
        'last_name':        _lastCtrl.text.trim(),
        'display_name':     _displayCtrl.text.trim(),
        'email':            _emailCtrl.text.trim(),
        'phone':            _phoneCtrl.text.trim(),
        'alt_phone':        _altPhoneCtrl.text.trim(),
        'whatsapp_no':      _whatsappCtrl.text.trim(),
        'employee_id':      _empIdCtrl.text.trim(),
        'role_level':       _roleLevel,
        'reports_to_emp_id': _managerId,
        'is_active':        _isActive ? 1 : 0,
        'can_approve':      _canApprove,
        'can_upload_bulk':  _canBulk,
        'extra_roles':      _extraRoles,
        'school_id':        _currentSchoolId ?? ref.read(authNotifierProvider).value?.schoolId,
        'branch_id':        _currentBranchId,
        'gender':           _gender,
        'date_of_birth':    _dob != null ? '${_dob!.year}-${_dob!.month.toString().padLeft(2,'0')}-${_dob!.day.toString().padLeft(2,'0')}' : null,
        'date_of_joining':  _doj != null ? '${_doj!.year}-${_doj!.month.toString().padLeft(2,'0')}-${_doj!.day.toString().padLeft(2,'0')}' : null,
        'address_line1':    _addr1Ctrl.text.trim(),
        'address_line2':    _addr2Ctrl.text.trim(),
        'city':             _cityCtrl.text.trim(),
        'state':            _state,
        'country':          _country,
        'zip_code':         _zipCtrl.text.trim(),
        'qualification':    _qualCtrl.text.trim(),
        'specialization':   _specCtrl.text.trim(),
        'experience_years': double.tryParse(_expCtrl.text.trim()),
        'assigned_classes': _assignedClasses,
        'subject_ids':      _subjectIds,
        'permissions':      Map<String, dynamic>.from(_perms),
        if (_photoUrl != null) 'photo_url': _photoUrl,
      };

      if (widget.employeeId != null) {
        await ApiService().put('/employees/${widget.employeeId}', body: body);
      } else {
        await ApiService().post('/employees', body: body);
      }

      if (!mounted) return;
      await ref.read(authNotifierProvider.notifier).refreshUser();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Employee saved'), backgroundColor: AppTheme.statusGreen));
      Navigator.of(context).pop(true);
    } catch (e) {
      setState(() => _saving = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.error));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        body: Container(
          decoration: const BoxDecoration(gradient: AppTheme.primaryGradient),
          child: const Center(child: CircularProgressIndicator(color: Colors.white)),
        ),
      );
    }

    final isEdit     = widget.employeeId != null;
    final authState  = ref.watch(authNotifierProvider);
    final canEditPerms = authState.value?.isSuperAdmin == true || authState.value?.isSchoolOwner == true;
    final schoolId   = _currentSchoolId ?? authState.value?.schoolId ?? authState.value?.employee?.schoolId;
    final branchesAsy = ref.watch(branchesProvider(schoolId));

    return Scaffold(
      backgroundColor: AppTheme.grey50,
      body: FadeTransition(
        opacity: _fadeAnim,
        child: CustomScrollView(
          slivers: [
            // ── Hero Header ──────────────────────────────────────
            SliverAppBar(
              expandedHeight: 220,
              pinned: true,
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  decoration: const BoxDecoration(gradient: AppTheme.heroGradient),
                  child: Stack(
                    children: [
                      Positioned(top: -30, right: -30, child: _DecorCircle(80, Colors.white.withOpacity(0.06))),
                      Positioned(bottom: 20, left: -20, child: _DecorCircle(120, Colors.white.withOpacity(0.04))),
                      Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const SizedBox(height: 40),
                            GestureDetector(
                              onTap: _uploadingPhoto ? null : _pickPhoto,
                              child: Stack(
                                children: [
                                  Container(
                                    width: 90, height: 90,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Colors.white.withOpacity(0.15),
                                      border: Border.all(color: Colors.white.withOpacity(0.4), width: 2.5),
                                      image: _photo != null
                                          ? DecorationImage(image: MemoryImage(_photo!), fit: BoxFit.cover)
                                          : (_photoUrl != null
                                              ? DecorationImage(image: NetworkImage(_photoUrl!), fit: BoxFit.cover)
                                              : null),
                                    ),
                                    child: (_photo == null && _photoUrl == null)
                                        ? const Icon(Icons.person, size: 40, color: Colors.white70)
                                        : null,
                                  ),
                                  if (_uploadingPhoto)
                                    Positioned.fill(child: Container(
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle, color: Colors.black45),
                                      child: const Center(child: CircularProgressIndicator(
                                          color: Colors.white, strokeWidth: 2)),
                                    )),
                                  Positioned(right: 0, bottom: 0,
                                    child: Container(
                                      padding: const EdgeInsets.all(5),
                                      decoration: BoxDecoration(
                                        color: AppTheme.accent, shape: BoxShape.circle,
                                        border: Border.all(color: Colors.white, width: 2),
                                      ),
                                      child: const Icon(Icons.camera_alt, size: 12, color: Colors.white),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(isEdit ? 'Edit Employee' : 'New Employee',
                              style: GoogleFonts.poppins(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
                            Text('Fill in all required details',
                              style: GoogleFonts.poppins(color: Colors.white70, fontSize: 12)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              title: Text(isEdit ? 'Edit Employee' : 'Add Employee',
                style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 16)),
            ),

            // ── Form Body ────────────────────────────────────────
            SliverToBoxAdapter(
              child: Form(
                key: _formKey,
                child: Center(
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 800),
                    padding: const EdgeInsets.fromLTRB(16, 24, 16, 40),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [

                        // ── Branch Assignment ─────────────────────
                        _SectionCard(
                          icon: Icons.account_tree_rounded, iconColor: AppTheme.secondary,
                          title: 'Branch Assignment',
                          subtitle: 'Select which branch this employee belongs to',
                          child: branchesAsy.when(
                            loading: () => const LinearProgressIndicator(),
                            error:   (_, __) => const SizedBox(),
                            data:    (branches) => DropdownButtonFormField<String>(
                              value: _currentBranchId,
                              isExpanded: true,
                              decoration: _inputDeco('Branch', Icons.business_rounded),
                              items: [
                                const DropdownMenuItem(value: null, child: Text('— No specific branch —')),
                                ...branches.map((b) => DropdownMenuItem(
                                  value: b['id'] as String,
                                  child: Row(children: [
                                    const Icon(Icons.location_on_rounded, size: 16, color: AppTheme.secondary),
                                    const SizedBox(width: 8),
                                    Expanded(child: Text(b['name'] as String? ?? '')),
                                  ]),
                                )),
                              ],
                              onChanged: (v) => setState(() {
                                _currentBranchId = v;
                                _assignedClasses = [];
                              }),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // ── Personal Information ──────────────────
                        _SectionCard(
                          icon: Icons.badge_rounded, iconColor: AppTheme.primaryLight,
                          title: 'Personal Information',
                          subtitle: 'Basic identity and date of birth',
                          child: Column(children: [
                            Row(children: [
                              Expanded(child: _FormField(label: 'First Name', icon: Icons.person_outline, ctrl: _firstCtrl, required: true)),
                              const SizedBox(width: 12),
                              Expanded(child: _FormField(label: 'Last Name', icon: Icons.person_outline, ctrl: _lastCtrl, required: true)),
                            ]),
                            const SizedBox(height: 12),
                            _FormField(label: 'Display Name', icon: Icons.badge_outlined, ctrl: _displayCtrl,
                                hint: 'e.g. Mr. Sharma / Mrs. Priya'),
                            const SizedBox(height: 12),
                            _FormField(label: 'Employee ID', icon: Icons.tag_rounded, ctrl: _empIdCtrl, hint: 'e.g. EMP-001'),
                            const SizedBox(height: 12),
                            Row(children: [
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  value: _gender,
                                  decoration: _inputDeco('Gender', Icons.wc),
                                  items: const [
                                    DropdownMenuItem(value: 'male',   child: Text('Male')),
                                    DropdownMenuItem(value: 'female', child: Text('Female')),
                                    DropdownMenuItem(value: 'other',  child: Text('Other')),
                                  ],
                                  onChanged: (v) => setState(() => _gender = v),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: InkWell(
                                  onTap: () => _pickDate(true),
                                  child: InputDecorator(
                                    decoration: _inputDeco('Date of Birth', Icons.cake_outlined),
                                    child: Text(
                                      _dob != null
                                          ? '${_dob!.day.toString().padLeft(2,'0')}/${_dob!.month.toString().padLeft(2,'0')}/${_dob!.year}'
                                          : 'Select date',
                                      style: GoogleFonts.poppins(fontSize: 13,
                                          color: _dob != null ? AppTheme.grey900 : AppTheme.grey500),
                                    ),
                                  ),
                                ),
                              ),
                            ]),
                          ]),
                        ),
                        const SizedBox(height: 16),

                        // ── Contact Details ───────────────────────
                        _SectionCard(
                          icon: Icons.contact_phone_rounded, iconColor: AppTheme.accent,
                          title: 'Contact Details',
                          subtitle: 'Phone, WhatsApp and email',
                          child: Column(children: [
                            _FormField(label: 'Email Address', icon: Icons.email_outlined, ctrl: _emailCtrl,
                              required: true, keyboardType: TextInputType.emailAddress,
                              validator: (v) {
                                if (v == null || v.isEmpty) return 'Required';
                                if (!v.contains('@')) return 'Enter a valid email';
                                return null;
                              }),
                            const SizedBox(height: 12),
                            Row(children: [
                              Expanded(child: _FormField(label: 'Phone', icon: Icons.phone_outlined, ctrl: _phoneCtrl, keyboardType: TextInputType.phone)),
                              const SizedBox(width: 12),
                              Expanded(child: _FormField(label: 'Alternate Phone', icon: Icons.phone_callback_outlined, ctrl: _altPhoneCtrl, keyboardType: TextInputType.phone)),
                            ]),
                            const SizedBox(height: 12),
                            _FormField(label: 'WhatsApp No.', icon: Icons.chat_outlined, ctrl: _whatsappCtrl, keyboardType: TextInputType.phone),
                          ]),
                        ),
                        const SizedBox(height: 16),

                        // ── Address ───────────────────────────────
                        _SectionCard(
                          icon: Icons.home_outlined, iconColor: const Color(0xFF7B1FA2),
                          title: 'Address',
                          subtitle: 'Residential address details',
                          child: Column(children: [
                            _FormField(label: 'Address Line 1', icon: Icons.location_on_outlined, ctrl: _addr1Ctrl),
                            const SizedBox(height: 12),
                            _FormField(label: 'Address Line 2', icon: Icons.location_on_outlined, ctrl: _addr2Ctrl),
                            const SizedBox(height: 12),
                            Row(children: [
                              Expanded(child: _FormField(label: 'City', icon: Icons.location_city_outlined, ctrl: _cityCtrl)),
                              const SizedBox(width: 12),
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  value: Lookups.indiaStates.contains(_state) ? _state : null,
                                  isExpanded: true,
                                  decoration: _inputDeco('State', Icons.map_outlined),
                                  items: Lookups.indiaStates.map((s) =>
                                    DropdownMenuItem(value: s, child: Text(s, overflow: TextOverflow.ellipsis))).toList(),
                                  onChanged: (v) => setState(() => _state = v),
                                ),
                              ),
                            ]),
                            const SizedBox(height: 12),
                            Row(children: [
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  value: _country,
                                  isExpanded: true,
                                  decoration: _inputDeco('Country', Icons.flag_outlined),
                                  items: Lookups.countries.map((c) =>
                                    DropdownMenuItem(value: c, child: Text(c, overflow: TextOverflow.ellipsis))).toList(),
                                  onChanged: (v) => setState(() => _country = v ?? 'India'),
                                ),
                              ),
                              const SizedBox(width: 12),
                              SizedBox(
                                width: 140,
                                child: _FormField(label: 'ZIP / PIN', icon: Icons.markunread_mailbox_outlined, ctrl: _zipCtrl, keyboardType: TextInputType.number),
                              ),
                            ]),
                          ]),
                        ),
                        const SizedBox(height: 16),

                        // ── Role & Reporting ──────────────────────
                        _SectionCard(
                          icon: Icons.work_rounded, iconColor: AppTheme.primary,
                          title: 'Role & Reporting',
                          subtitle: 'Hierarchy level, manager and joining date',
                          child: Column(children: [
                            _RoleLevelPicker(value: _roleLevel, onChanged: (v) => setState(() { _roleLevel = v; _managerId = null; })),
                            const SizedBox(height: 16),
                            Consumer(builder: (context, ref, _) {
                              final managersAsy = ref.watch(_managersProvider(schoolId));
                              return managersAsy.when(
                                loading: () => const LinearProgressIndicator(),
                                error:   (_, __) => const SizedBox(),
                                data:    (employees) {
                                  final managers = employees.where((e) => e.roleLevel < _roleLevel && e.id != widget.employeeId).toList();
                                  return DropdownButtonFormField<String>(
                                    value: _managerId,
                                    isExpanded: true,
                                    decoration: _inputDeco('Reports To (Manager)', Icons.supervisor_account_rounded),
                                    items: [
                                      const DropdownMenuItem(value: null, child: Text('— Top Level / No Manager —')),
                                      ...managers.map((m) => DropdownMenuItem(
                                        value: m.id,
                                        child: Text('${m.fullName}  ·  L${m.roleLevel}', overflow: TextOverflow.ellipsis),
                                      )),
                                    ],
                                    onChanged: (v) => setState(() => _managerId = v),
                                  );
                                },
                              );
                            }),
                            const SizedBox(height: 16),
                            InkWell(
                              onTap: () => _pickDate(false),
                              child: InputDecorator(
                                decoration: _inputDeco('Date of Joining', Icons.calendar_today_outlined),
                                child: Text(
                                  _doj != null
                                      ? '${_doj!.day.toString().padLeft(2,'0')}/${_doj!.month.toString().padLeft(2,'0')}/${_doj!.year}'
                                      : 'Select date',
                                  style: GoogleFonts.poppins(fontSize: 13,
                                      color: _doj != null ? AppTheme.grey900 : AppTheme.grey500),
                                ),
                              ),
                            ),
                          ]),
                        ),
                        const SizedBox(height: 16),

                        // ── Qualification ─────────────────────────
                        _SectionCard(
                          icon: Icons.school_outlined, iconColor: AppTheme.statusGreen,
                          title: 'Qualification & Experience',
                          subtitle: 'Academic background and years of experience',
                          child: Column(children: [
                            _FormField(label: 'Qualification', icon: Icons.menu_book_outlined, ctrl: _qualCtrl, hint: 'e.g. B.Ed, M.Sc., B.Tech'),
                            const SizedBox(height: 12),
                            _FormField(label: 'Specialization', icon: Icons.star_outline, ctrl: _specCtrl, hint: 'e.g. Mathematics, English Literature'),
                            const SizedBox(height: 12),
                            _FormField(label: 'Years of Experience', icon: Icons.timeline_outlined, ctrl: _expCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              hint: 'e.g. 5.5',
                              validator: (v) {
                                if (v == null || v.isEmpty) return null;
                                if (double.tryParse(v) == null) return 'Enter a valid number';
                                return null;
                              }),
                          ]),
                        ),
                        const SizedBox(height: 16),

                        // ── Assigned Classes ──────────────────────
                        if (_currentBranchId != null)
                          Consumer(builder: (context, ref, _) {
                            final csAsync = ref.watch(_classSectionsProvider(_currentBranchId));
                            return csAsync.when(
                              loading: () => const SizedBox(),
                              error:   (_, __) => const SizedBox(),
                              data:    (sections) {
                                if (sections.isEmpty) return const SizedBox();
                                return _SectionCard(
                                  icon: Icons.class_outlined, iconColor: const Color(0xFFE65100),
                                  title: 'Assigned Classes',
                                  subtitle: 'Which class-sections does this teacher handle?',
                                  child: _MultiSelectChips(
                                    allItems: sections.map((s) {
                                      final label = s['class_section'] as String? ??
                                          '${s['class_name']}${s['section']}';
                                      return MapEntry(label, label);
                                    }).toList(),
                                    selected: _assignedClasses,
                                    onChanged: (v) => setState(() => _assignedClasses = v),
                                  ),
                                );
                              },
                            );
                          }),
                        if (_currentBranchId != null) const SizedBox(height: 16),

                        // ── Subjects ──────────────────────────────
                        _SectionCard(
                          icon: Icons.auto_stories_outlined, iconColor: const Color(0xFF0288D1),
                          title: 'Subjects',
                          subtitle: 'Which subjects does this employee teach?',
                          child: _MultiSelectChips(
                            allItems: Lookups.subjects.map((s) => MapEntry(s, s)).toList(),
                            selected: _subjectIds,
                            onChanged: (v) => setState(() => _subjectIds = v),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // ── Permissions ───────────────────────────
                        _SectionCard(
                          icon: Icons.security_outlined, iconColor: AppTheme.error,
                          title: 'Permissions',
                          subtitle: canEditPerms
                              ? 'Override permissions for this specific employee'
                              : 'Only school admins can change permissions',
                          child: Column(children: [
                            _ToggleRow(
                              icon: Icons.check_circle_outline, label: 'Active Account',
                              description: 'Employee can log in and access the system',
                              value: _isActive,
                              onToggle: (v) => setState(() => _isActive = v),
                            ),
                            const Divider(height: 20),
                            _ToggleRow(
                              icon: Icons.approval_rounded, label: 'Can Approve Requests',
                              description: 'Override approval permission',
                              value: _canApprove,
                              onToggle: canEditPerms ? (v) => setState(() => _canApprove = v) : null,
                            ),
                            const SizedBox(height: 8),
                            _ToggleRow(
                              icon: Icons.upload_file_rounded, label: 'Bulk Upload',
                              description: 'Can upload employees/students in bulk',
                              value: _canBulk,
                              onToggle: canEditPerms ? (v) => setState(() => _canBulk = v) : null,
                            ),
                            const Divider(height: 20),
                            ...Lookups.permissions.map((p) => Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: _ToggleRow(
                                icon: _permIcon(p['key']!),
                                label: p['label']!,
                                description: '',
                                value: _perms[p['key']] ?? false,
                                onToggle: canEditPerms
                                    ? (v) => setState(() => _perms[p['key']!] = v)
                                    : null,
                              ),
                            )),
                          ]),
                        ),
                        const SizedBox(height: 32),

                        // ── Save Button ───────────────────────────
                        SizedBox(
                          height: 52,
                          child: ElevatedButton(
                            onPressed: _saving ? null : _save,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primary,
                              foregroundColor: Colors.white,
                              disabledBackgroundColor: AppTheme.grey300,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              elevation: 3,
                              shadowColor: AppTheme.primary.withOpacity(0.4),
                            ),
                            child: _saving
                                ? const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      SizedBox(width: 20, height: 20,
                                        child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white)),
                                      SizedBox(width: 12),
                                      Text('Saving…', style: TextStyle(fontSize: 15)),
                                    ],
                                  )
                                : Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(Icons.save_rounded, size: 20),
                                      const SizedBox(width: 10),
                                      Text(isEdit ? 'Update Employee' : 'Add Employee',
                                        style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600)),
                                    ],
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _permIcon(String key) {
    switch (key) {
      case 'can_send_notification_to_parent': return Icons.notifications_outlined;
      case 'can_send_request':               return Icons.send_outlined;
      case 'can_create_workflow':             return Icons.account_tree_outlined;
      case 'can_edit_workflow':               return Icons.edit_outlined;
      case 'can_create_idcard':              return Icons.credit_card_outlined;
      case 'can_modify_idcard':              return Icons.edit_note_outlined;
      case 'can_see_reports':               return Icons.bar_chart_outlined;
      case 'delete_employee':               return Icons.person_remove_outlined;
      case 'delete_student':                return Icons.school_outlined;
      default:                              return Icons.lock_outline;
    }
  }
}

// ── Multi-Select Chips ─────────────────────────────────────────
class _MultiSelectChips extends StatelessWidget {
  final List<MapEntry<String, String>> allItems; // key=value, value=label
  final List<String> selected;
  final ValueChanged<List<String>> onChanged;

  const _MultiSelectChips({
    required this.allItems,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: allItems.map((entry) {
        final isSelected = selected.contains(entry.key);
        return FilterChip(
          label: Text(entry.value,
              style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w500,
                  color: isSelected ? Colors.white : AppTheme.grey800)),
          selected: isSelected,
          selectedColor: AppTheme.primary,
          backgroundColor: AppTheme.grey100,
          checkmarkColor: Colors.white,
          onSelected: (v) {
            final updated = List<String>.from(selected);
            if (v) updated.add(entry.key); else updated.remove(entry.key);
            onChanged(updated);
          },
        );
      }).toList(),
    );
  }
}

// ── Role Level Picker ──────────────────────────────────────────
class _RoleLevelPicker extends StatelessWidget {
  final int value;
  final ValueChanged<int> onChanged;
  const _RoleLevelPicker({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Hierarchy Level',
          style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.grey600, fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8, runSpacing: 8,
          children: AppConstants.orgLevels.entries.map((e) {
            final selected = e.key == value;
            return GestureDetector(
              onTap: () => onChanged(e.key),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: selected ? AppTheme.primary : Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: selected ? AppTheme.primary : AppTheme.grey300, width: selected ? 2 : 1),
                  boxShadow: selected
                      ? [BoxShadow(color: AppTheme.primary.withOpacity(0.3), blurRadius: 6, offset: const Offset(0, 2))]
                      : null,
                ),
                child: Column(children: [
                  Text('L${e.key}',
                    style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w700,
                        color: selected ? Colors.white70 : AppTheme.grey500)),
                  Text(e.value,
                    style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600,
                        color: selected ? Colors.white : AppTheme.grey800)),
                ]),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

// ── Section Card ───────────────────────────────────────────────
class _SectionCard extends StatelessWidget {
  final IconData icon;
  final Color    iconColor;
  final String   title;
  final String   subtitle;
  final Widget   child;

  const _SectionCard({
    required this.icon, required this.iconColor,
    required this.title, required this.subtitle, required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: AppTheme.primary.withOpacity(0.07), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: iconColor.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: iconColor, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.grey900)),
              Text(subtitle, style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.grey500)),
            ])),
          ]),
        ),
        Divider(height: 1, color: AppTheme.grey100),
        Padding(padding: const EdgeInsets.all(16), child: child),
      ]),
    );
  }
}

// ── Form Field ─────────────────────────────────────────────────
class _FormField extends StatelessWidget {
  final String label;
  final IconData icon;
  final TextEditingController ctrl;
  final bool required;
  final String? hint;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;

  const _FormField({
    required this.label, required this.icon, required this.ctrl,
    this.required = false, this.hint, this.keyboardType, this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: ctrl,
      keyboardType: keyboardType,
      style: GoogleFonts.poppins(fontSize: 13),
      decoration: _inputDeco(required ? '$label *' : label, icon, hint: hint),
      validator: validator ?? (required ? (v) => (v == null || v.isEmpty) ? 'Required' : null : null),
    );
  }
}

// ── Toggle Row ─────────────────────────────────────────────────
class _ToggleRow extends StatelessWidget {
  final IconData icon;
  final String   label;
  final String   description;
  final bool     value;
  final ValueChanged<bool>? onToggle;

  const _ToggleRow({
    required this.icon, required this.label, required this.description,
    required this.value, required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onToggle != null;
    return Row(children: [
      Icon(icon, size: 20, color: enabled ? AppTheme.primary : AppTheme.grey400),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w500,
            color: enabled ? AppTheme.grey900 : AppTheme.grey400)),
        if (description.isNotEmpty)
          Text(description, style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.grey500)),
      ])),
      Switch(value: value, onChanged: onToggle, activeColor: enabled ? AppTheme.primary : AppTheme.grey400),
    ]);
  }
}

class _DecorCircle extends StatelessWidget {
  final double size; final Color color;
  const _DecorCircle(this.size, this.color);
  @override
  Widget build(BuildContext context) => Container(
    width: size, height: size,
    decoration: BoxDecoration(shape: BoxShape.circle, color: color),
  );
}

InputDecoration _inputDeco(String label, IconData icon, {String? hint}) {
  return InputDecoration(
    labelText: label, hintText: hint,
    prefixIcon: Icon(icon, size: 18, color: AppTheme.grey500),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.grey300)),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.grey300)),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.primary, width: 2)),
    filled: true, fillColor: Colors.white,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
    labelStyle: GoogleFonts.poppins(fontSize: 13, color: AppTheme.grey600),
  );
}
