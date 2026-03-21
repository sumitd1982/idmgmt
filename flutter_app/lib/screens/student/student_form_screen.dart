// ============================================================
// Student Add / Edit Form
// ============================================================
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../providers/auth_provider.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:typed_data';
import '../../config/theme.dart';
import '../../services/api_service.dart';

// ── Providers ─────────────────────────────────────────────────
final _studentDetailProvider =
    FutureProvider.family<Map<String, dynamic>?, String?>((ref, id) async {
  if (id == null) return null;
  try {
    return await ApiService().get('/students/$id');
  } catch (_) {
    return null;
  }
});

// ── Screen ────────────────────────────────────────────────────
class StudentFormScreen extends ConsumerStatefulWidget {
  final String? studentId;
  const StudentFormScreen({super.key, this.studentId});

  @override
  ConsumerState<StudentFormScreen> createState() => _StudentFormScreenState();
}

class _StudentFormScreenState extends ConsumerState<StudentFormScreen>
    with TickerProviderStateMixin {
  late final TabController _tabCtrl;
  final _formKey = GlobalKey<FormState>();

  // Personal Info
  final _firstNameCtrl    = TextEditingController();
  final _lastNameCtrl     = TextEditingController();
  final _dobCtrl          = TextEditingController();
  final _aadhaarCtrl      = TextEditingController();
  String? _gender;
  String? _bloodGroup;
  String? _category;
  Uint8List? _studentPhoto;

  // Guardian Info — 4 guardians
  final _guardianControllers = List.generate(
    4,
    (_) => _GuardianControllers(),
  );
  int _activeGuardianTab = 0;

  // Address
  final _addressCtrl   = TextEditingController();
  final _cityCtrl      = TextEditingController();
  final _stateCtrl     = TextEditingController();
  final _pinCtrl       = TextEditingController();
  final _busRouteCtrl  = TextEditingController();
  final _busStopCtrl   = TextEditingController();

  // School Info
  final _classCtrl       = TextEditingController();
  final _sectionCtrl     = TextEditingController();
  final _rollNoCtrl      = TextEditingController();
  final _studentIdCtrl   = TextEditingController();
  final _admissionNoCtrl = TextEditingController();

  bool _saving  = false;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 4, vsync: this);

    // Pre-fill if editing
    if (widget.studentId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
    }
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final resp =
          await ref.read(_studentDetailProvider(widget.studentId).future);
      if (resp == null || !mounted) return;
      final data = (resp['data'] as Map<String, dynamic>?) ?? resp;

      _firstNameCtrl.text   = data['first_name']    as String? ?? '';
      _lastNameCtrl.text    = data['last_name']      as String? ?? '';
      _dobCtrl.text         = data['date_of_birth']  as String? ?? '';
      _aadhaarCtrl.text     = data['aadhaar_no']     as String? ?? '';
      _addressCtrl.text     = data['address_line1']  as String? ?? '';
      _cityCtrl.text        = data['city']           as String? ?? '';
      _stateCtrl.text       = data['state']          as String? ?? '';
      _pinCtrl.text         = data['zip_code']       as String? ?? '';
      _busRouteCtrl.text    = data['bus_route']      as String? ?? '';
      _busStopCtrl.text     = data['bus_stop']       as String? ?? '';
      _classCtrl.text       = data['class_name']     as String? ?? '';
      _sectionCtrl.text     = data['section']        as String? ?? '';
      _rollNoCtrl.text      = data['roll_number']    as String? ?? '';
      _studentIdCtrl.text   = data['student_id']     as String? ?? '';
      _admissionNoCtrl.text = data['admission_no']   as String? ?? '';

      // Load guardian data into controllers
      const typeIndex = <String, int>{
        'mother': 0, 'father': 1, 'guardian_1': 2, 'guardian_2': 3,
      };
      final guardians = data['guardians'] as List<dynamic>? ?? [];
      for (final g in guardians) {
        final gm  = g as Map<String, dynamic>;
        final idx = typeIndex[(gm['guardian_type'] as String? ?? '').toLowerCase()];
        if (idx != null) {
          final c  = _guardianControllers[idx];
          final fn = gm['first_name'] as String? ?? '';
          final ln = gm['last_name']  as String? ?? '';
          c.nameCtrl.text      = [fn, ln].where((s) => s.isNotEmpty).join(' ');
          c.phoneCtrl.text     = gm['phone']       as String? ?? '';
          c.whatsappCtrl.text  = gm['whatsapp_no'] as String? ?? '';
          c.emailCtrl.text     = gm['email']       as String? ?? '';
          c.occupationCtrl.text = gm['occupation'] as String? ?? '';
        }
      }

      setState(() {
        _gender     = data['gender']      as String?;
        _bloodGroup = data['blood_group'] as String?;
        _category   = data['category']    as String?;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:         Text('Failed to load student data: $e'),
          backgroundColor: AppTheme.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _dobCtrl.dispose();
    _aadhaarCtrl.dispose();
    _addressCtrl.dispose();
    _cityCtrl.dispose();
    _stateCtrl.dispose();
    _pinCtrl.dispose();
    _busRouteCtrl.dispose();
    _busStopCtrl.dispose();
    _classCtrl.dispose();
    _sectionCtrl.dispose();
    _rollNoCtrl.dispose();
    _studentIdCtrl.dispose();
    _admissionNoCtrl.dispose();
    for (final g in _guardianControllers) {
      g.dispose();
    }
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final picker = ImagePicker();
    final img    = await picker.pickImage(
      source:    ImageSource.gallery,
      maxWidth:  400,
      maxHeight: 400,
      imageQuality: 85,
    );
    if (img == null) return;
    final bytes = await img.readAsBytes();
    setState(() => _studentPhoto = bytes);
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      // Jump to first tab with errors
      _tabCtrl.animateTo(0);
      return;
    }
    setState(() => _saving = true);
    try {
      // Build guardian list (only include non-empty guardians)
      const guardianTypes = ['mother', 'father', 'guardian_1', 'guardian_2'];
      final guardiansList = <Map<String, dynamic>>[];
      for (int i = 0; i < 4; i++) {
        final c = _guardianControllers[i];
        if (c.nameCtrl.text.isNotEmpty || c.phoneCtrl.text.isNotEmpty) {
          guardiansList.add({
            'guardian_type': guardianTypes[i],
            'first_name':    c.nameCtrl.text.trim(),
            'phone':         c.phoneCtrl.text.trim(),
            'whatsapp_no':   c.whatsappCtrl.text.trim(),
            'email':         c.emailCtrl.text.trim(),
            'occupation':    c.occupationCtrl.text.trim(),
          });
        }
      }

      final user = ref.read(authNotifierProvider).value;
      final body = {
        'school_id':     user?.schoolId ?? user?.employee?.schoolId,
        'branch_id':     user?.employee?.branchId,
        'first_name':    _firstNameCtrl.text.trim(),
        'last_name':     _lastNameCtrl.text.trim(),
        'date_of_birth': _dobCtrl.text.trim(),
        'gender':        _gender?.toLowerCase(),
        'blood_group':   _bloodGroup,
        'category':      _category,
        'aadhaar_no':    _aadhaarCtrl.text.trim(),
        'address_line1': _addressCtrl.text.trim(),
        'city':          _cityCtrl.text.trim(),
        'state':         _stateCtrl.text.trim(),
        'zip_code':      _pinCtrl.text.trim(),
        'bus_route':     _busRouteCtrl.text.trim(),
        'bus_stop':      _busStopCtrl.text.trim(),
        'class_name':    _classCtrl.text.trim(),
        'section':       _sectionCtrl.text.trim(),
        'roll_number':   _rollNoCtrl.text.trim(),
        'student_id':    _studentIdCtrl.text.trim(),
        'admission_no':  _admissionNoCtrl.text.trim(),
        'guardians':     guardiansList,
      };
      if (widget.studentId != null) {
        await ApiService().put('/students/${widget.studentId}', body: body);
      } else {
        await ApiService().post('/students', body: body);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(widget.studentId != null
              ? 'Student updated successfully'
              : 'Student created successfully'),
          backgroundColor: AppTheme.statusGreen,
        ),
      );
      Navigator.of(context).pop();
    } catch (e) {
      setState(() => _saving = false);
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
    final isEdit = widget.studentId != null;

    return Stack(
      children: [
        _buildScaffold(isEdit),
        if (_loading)
          const Positioned.fill(
            child: ColoredBox(
              color: Colors.black26,
              child: Center(child: CircularProgressIndicator()),
            ),
          ),
      ],
    );
  }

  Widget _buildScaffold(bool isEdit) {
    return Scaffold(
      backgroundColor: AppTheme.grey50,
      appBar: AppBar(
        title: Text(isEdit ? 'Edit Student' : 'Add New Student'),
        bottom: TabBar(
          controller: _tabCtrl,
          tabs: const [
            Tab(icon: Icon(Icons.person, size: 18),   text: 'Personal'),
            Tab(icon: Icon(Icons.family_restroom, size: 18), text: 'Guardian'),
            Tab(icon: Icon(Icons.home, size: 18),     text: 'Address'),
            Tab(icon: Icon(Icons.school, size: 18),   text: 'School Info'),
          ],
        ),
      ),
      body: Form(
        key: _formKey,
        child: TabBarView(
          controller: _tabCtrl,
          children: [
            _PersonalTab(
              firstNameCtrl: _firstNameCtrl,
              lastNameCtrl:  _lastNameCtrl,
              dobCtrl:       _dobCtrl,
              aadhaarCtrl:   _aadhaarCtrl,
              gender:        _gender,
              bloodGroup:    _bloodGroup,
              category:      _category,
              studentPhoto:  _studentPhoto,
              onGenderChanged:     (v) => setState(() => _gender     = v),
              onBloodGroupChanged: (v) => setState(() => _bloodGroup = v),
              onCategoryChanged:   (v) => setState(() => _category   = v),
              onPickPhoto:         _pickPhoto,
            ),
            _GuardianTab(
              controllers:      _guardianControllers,
              activeTab:        _activeGuardianTab,
              onTabChanged: (i) => setState(() => _activeGuardianTab = i),
            ),
            _AddressTab(
              addressCtrl:  _addressCtrl,
              cityCtrl:     _cityCtrl,
              stateCtrl:    _stateCtrl,
              pinCtrl:      _pinCtrl,
              busRouteCtrl: _busRouteCtrl,
              busStopCtrl:  _busStopCtrl,
            ),
            _SchoolInfoTab(
              classCtrl:      _classCtrl,
              sectionCtrl:    _sectionCtrl,
              rollNoCtrl:     _rollNoCtrl,
              studentIdCtrl:  _studentIdCtrl,
              admissionCtrl:  _admissionNoCtrl,
            ),
          ],
        ),
      ),
      bottomNavigationBar: _FormBottomBar(
        onSave:   _save,
        saving:   _saving,
        onCancel: () => Navigator.of(context).pop(),
      ),
    );
  }
}

// ── Personal Info Tab ─────────────────────────────────────────
class _PersonalTab extends StatelessWidget {
  final TextEditingController firstNameCtrl;
  final TextEditingController lastNameCtrl;
  final TextEditingController dobCtrl;
  final TextEditingController aadhaarCtrl;
  final String? gender;
  final String? bloodGroup;
  final String? category;
  final Uint8List? studentPhoto;
  final ValueChanged<String?> onGenderChanged;
  final ValueChanged<String?> onBloodGroupChanged;
  final ValueChanged<String?> onCategoryChanged;
  final VoidCallback onPickPhoto;

  const _PersonalTab({
    required this.firstNameCtrl,
    required this.lastNameCtrl,
    required this.dobCtrl,
    required this.aadhaarCtrl,
    required this.gender,
    required this.bloodGroup,
    required this.category,
    required this.studentPhoto,
    required this.onGenderChanged,
    required this.onBloodGroupChanged,
    required this.onCategoryChanged,
    required this.onPickPhoto,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Photo
          Column(
            children: [
              _PhotoUpload(photo: studentPhoto, onTap: onPickPhoto),
              const SizedBox(height: 8),
              Text('Student Photo',
                  style: GoogleFonts.poppins(
                      fontSize: 12, color: AppTheme.grey600)),
            ],
          ),
          const SizedBox(width: 32),
          // Fields
          Expanded(
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _FormField(
                        label:      'First Name *',
                        controller: firstNameCtrl,
                        validator:  (v) =>
                            v == null || v.isEmpty ? 'Required' : null,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _FormField(
                        label:      'Last Name *',
                        controller: lastNameCtrl,
                        validator:  (v) =>
                            v == null || v.isEmpty ? 'Required' : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _FormField(
                        label:      'Date of Birth *',
                        controller: dobCtrl,
                        hint:       'YYYY-MM-DD',
                        suffixIcon: const Icon(Icons.calendar_today, size: 16),
                        validator: (v) =>
                            v == null || v.isEmpty ? 'Required' : null,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _DropdownFormField<String>(
                        label: 'Gender *',
                        value: gender,
                        items: const ['Male', 'Female', 'Other'],
                        onChanged: onGenderChanged,
                        validator: (v) => v == null ? 'Required' : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _DropdownFormField<String>(
                        label:    'Blood Group',
                        value:    bloodGroup,
                        items:    const ['A+', 'A−', 'B+', 'B−', 'O+', 'O−', 'AB+', 'AB−'],
                        onChanged: onBloodGroupChanged,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _DropdownFormField<String>(
                        label:    'Category',
                        value:    category,
                        items:    const ['General', 'OBC', 'SC', 'ST', 'EWS'],
                        onChanged: onCategoryChanged,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _FormField(
                  label:      'Aadhaar Number',
                  controller: aadhaarCtrl,
                  hint:       '12-digit Aadhaar',
                  maxLength:  12,
                  keyboardType: TextInputType.number,
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms);
  }
}

class _PhotoUpload extends StatelessWidget {
  final Uint8List? photo;
  final VoidCallback onTap;
  const _PhotoUpload({this.photo, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width:  120,
        height: 140,
        decoration: BoxDecoration(
          color:        AppTheme.grey200,
          borderRadius: BorderRadius.circular(12),
          border:       Border.all(color: AppTheme.grey300),
          image: photo != null
              ? DecorationImage(
                  image: MemoryImage(photo!),
                  fit:   BoxFit.cover,
                )
              : null,
        ),
        child: photo == null
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_a_photo,
                      color: AppTheme.grey600, size: 32),
                  const SizedBox(height: 6),
                  Text('Upload\nPhoto',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                          fontSize: 11, color: AppTheme.grey600)),
                ],
              )
            : Align(
                alignment: Alignment.bottomRight,
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: Container(
                    decoration: const BoxDecoration(
                      color:  AppTheme.primary,
                      shape:  BoxShape.circle,
                    ),
                    padding: const EdgeInsets.all(4),
                    child: const Icon(Icons.edit,
                        color: Colors.white, size: 14),
                  ),
                ),
              ),
      ),
    );
  }
}

// ── Guardian Tab ──────────────────────────────────────────────
class _GuardianControllers {
  final nameCtrl      = TextEditingController();
  final phoneCtrl     = TextEditingController();
  final whatsappCtrl  = TextEditingController();
  final emailCtrl     = TextEditingController();
  final occupationCtrl = TextEditingController();
  Uint8List? photo;

  void dispose() {
    nameCtrl.dispose();
    phoneCtrl.dispose();
    whatsappCtrl.dispose();
    emailCtrl.dispose();
    occupationCtrl.dispose();
  }
}

class _GuardianTab extends StatelessWidget {
  final List<_GuardianControllers> controllers;
  final int activeTab;
  final ValueChanged<int> onTabChanged;

  const _GuardianTab({
    required this.controllers,
    required this.activeTab,
    required this.onTabChanged,
  });

  static const _labels = ['Mother', 'Father', 'Guardian 1', 'Guardian 2'];
  static const _icons  = [
    Icons.person,
    Icons.person_2,
    Icons.person_3,
    Icons.person_4,
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Sub-tabs
        Container(
          color:   AppTheme.grey100,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Row(
            children: List.generate(4, (i) {
              final isActive = i == activeTab;
              return Expanded(
                child: GestureDetector(
                  onTap: () => onTabChanged(i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin:   const EdgeInsets.only(right: 8),
                    padding:  const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color:        isActive
                          ? AppTheme.primary
                          : Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: isActive
                          ? [
                              BoxShadow(
                                color:  AppTheme.primary.withOpacity(0.3),
                                blurRadius: 8,
                              )
                            ]
                          : null,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(_icons[i],
                            size:  14,
                            color: isActive
                                ? Colors.white
                                : AppTheme.grey600),
                        const SizedBox(width: 4),
                        Text(_labels[i],
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color:    isActive
                                  ? Colors.white
                                  : AppTheme.grey600,
                              fontWeight: isActive
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                            )),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
        // Content
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: _GuardianForm(
              label:       _labels[activeTab],
              controllers: controllers[activeTab],
            ),
          ),
        ),
      ],
    );
  }
}

class _GuardianForm extends StatefulWidget {
  final String label;
  final _GuardianControllers controllers;
  const _GuardianForm({required this.label, required this.controllers});

  @override
  State<_GuardianForm> createState() => _GuardianFormState();
}

class _GuardianFormState extends State<_GuardianForm> {
  Future<void> _pickPhoto() async {
    final picker = ImagePicker();
    final img    = await picker.pickImage(source: ImageSource.gallery);
    if (img == null) return;
    final bytes  = await img.readAsBytes();
    setState(() => widget.controllers.photo = bytes);
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controllers;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            _PhotoUpload(photo: c.photo, onTap: _pickPhoto),
            const SizedBox(height: 6),
            Text('${widget.label} Photo',
                style: GoogleFonts.poppins(
                    fontSize: 11, color: AppTheme.grey600)),
          ],
        ),
        const SizedBox(width: 28),
        Expanded(
          child: Column(
            children: [
              _FormField(label: '${widget.label} Name', controller: c.nameCtrl),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _FormField(
                      label:        'Phone',
                      controller:   c.phoneCtrl,
                      keyboardType: TextInputType.phone,
                      prefixIcon:   const Icon(Icons.phone, size: 16),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: _FormField(
                      label:        'WhatsApp',
                      controller:   c.whatsappCtrl,
                      keyboardType: TextInputType.phone,
                      prefixIcon:   const Icon(Icons.chat, size: 16),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _FormField(
                      label:        'Email',
                      controller:   c.emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      prefixIcon:   const Icon(Icons.email_outlined, size: 16),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: _FormField(
                      label:      'Occupation',
                      controller: c.occupationCtrl,
                      prefixIcon: const Icon(Icons.work_outline, size: 16),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Address Tab ───────────────────────────────────────────────
class _AddressTab extends StatelessWidget {
  final TextEditingController addressCtrl;
  final TextEditingController cityCtrl;
  final TextEditingController stateCtrl;
  final TextEditingController pinCtrl;
  final TextEditingController busRouteCtrl;
  final TextEditingController busStopCtrl;

  const _AddressTab({
    required this.addressCtrl,
    required this.cityCtrl,
    required this.stateCtrl,
    required this.pinCtrl,
    required this.busRouteCtrl,
    required this.busStopCtrl,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader('Home Address'),
          const SizedBox(height: 16),
          _FormField(
            label:      'Street Address',
            controller: addressCtrl,
            maxLines:   2,
            prefixIcon: const Icon(Icons.location_on_outlined, size: 16),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _FormField(
                  label:      'City',
                  controller: cityCtrl,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _FormField(
                  label:      'State',
                  controller: stateCtrl,
                ),
              ),
              const SizedBox(width: 14),
              SizedBox(
                width: 120,
                child: _FormField(
                  label:        'PIN Code',
                  controller:   pinCtrl,
                  keyboardType: TextInputType.number,
                  maxLength:    6,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _SectionHeader('Bus / Transport Details'),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _FormField(
                  label:      'Bus Route No.',
                  controller: busRouteCtrl,
                  prefixIcon: const Icon(Icons.directions_bus, size: 16),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _FormField(
                  label:      'Bus Stop',
                  controller: busStopCtrl,
                  prefixIcon: const Icon(Icons.location_city, size: 16),
                ),
              ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms);
  }
}

// ── School Info Tab ───────────────────────────────────────────
class _SchoolInfoTab extends StatelessWidget {
  final TextEditingController classCtrl;
  final TextEditingController sectionCtrl;
  final TextEditingController rollNoCtrl;
  final TextEditingController studentIdCtrl;
  final TextEditingController admissionCtrl;

  const _SchoolInfoTab({
    required this.classCtrl,
    required this.sectionCtrl,
    required this.rollNoCtrl,
    required this.studentIdCtrl,
    required this.admissionCtrl,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader('Academic Details'),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _FormField(
                  label:      'Class *',
                  controller: classCtrl,
                  hint:       'e.g. Class 5',
                  validator:  (v) =>
                      v == null || v.isEmpty ? 'Required' : null,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _FormField(
                  label:      'Section *',
                  controller: sectionCtrl,
                  hint:       'A / B / C',
                  validator:  (v) =>
                      v == null || v.isEmpty ? 'Required' : null,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _FormField(
                  label:      'Roll Number *',
                  controller: rollNoCtrl,
                  keyboardType: TextInputType.number,
                  validator:  (v) =>
                      v == null || v.isEmpty ? 'Required' : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _FormField(
                  label:      'Student ID',
                  controller: studentIdCtrl,
                  hint:       'Auto-generated if empty',
                  prefixIcon: const Icon(Icons.badge_outlined, size: 16),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _FormField(
                  label:      'Admission No.',
                  controller: admissionCtrl,
                  prefixIcon: const Icon(Icons.assignment_ind, size: 16),
                ),
              ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms);
  }
}

// ── Bottom Save Bar ───────────────────────────────────────────
class _FormBottomBar extends StatelessWidget {
  final VoidCallback onSave;
  final VoidCallback onCancel;
  final bool saving;
  const _FormBottomBar({
    required this.onSave,
    required this.onCancel,
    required this.saving,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color:    AppTheme.primary.withOpacity(0.08),
            blurRadius: 10,
            offset:   const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          OutlinedButton(
            onPressed: onCancel,
            child: const Text('Cancel'),
          ),
          const SizedBox(width: 12),
          ElevatedButton.icon(
            onPressed: saving ? null : onSave,
            icon: saving
                ? const SizedBox(
                    width:  16,
                    height: 16,
                    child:  CircularProgressIndicator(
                      strokeWidth: 2,
                      color:       Colors.white,
                    ))
                : const Icon(Icons.save, size: 16),
            label: Text(saving ? 'Saving...' : 'Save Student'),
          ),
        ],
      ),
    );
  }
}

// ── Shared Form Widgets ───────────────────────────────────────
class _FormField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String? hint;
  final FormFieldValidator<String>? validator;
  final TextInputType? keyboardType;
  final int? maxLength;
  final int maxLines;
  final Widget? prefixIcon;
  final Widget? suffixIcon;

  const _FormField({
    required this.label,
    required this.controller,
    this.hint,
    this.validator,
    this.keyboardType,
    this.maxLength,
    this.maxLines = 1,
    this.prefixIcon,
    this.suffixIcon,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller:   controller,
      validator:    validator,
      keyboardType: keyboardType,
      maxLength:    maxLength,
      maxLines:     maxLines,
      style:        GoogleFonts.poppins(fontSize: 13),
      decoration: InputDecoration(
        labelText:   label,
        hintText:    hint,
        prefixIcon:  prefixIcon,
        suffixIcon:  suffixIcon,
        counterText: '',
      ),
    );
  }
}

class _DropdownFormField<T> extends StatelessWidget {
  final String label;
  final T? value;
  final List<T> items;
  final ValueChanged<T?> onChanged;
  final FormFieldValidator<T>? validator;

  const _DropdownFormField({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<T>(
      value:     value,
      validator: validator,
      decoration: InputDecoration(labelText: label),
      style:     GoogleFonts.poppins(fontSize: 13, color: AppTheme.grey900),
      items:     items.map((item) => DropdownMenuItem<T>(
            value: item,
            child: Text(item.toString()),
          )).toList(),
      onChanged: onChanged,
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width:  4,
          height: 18,
          decoration: BoxDecoration(
            color:        AppTheme.primary,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            fontSize:   14,
            color:      AppTheme.grey900,
          ),
        ),
      ],
    );
  }
}
