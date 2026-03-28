// ============================================================
// Student Add / Edit Form — full attribute coverage
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

// ── Constants ─────────────────────────────────────────────────
const _genders      = ['Male', 'Female', 'Other'];
const _bloodGroups  = ['A+', 'A-', 'B+', 'B-', 'O+', 'O-', 'AB+', 'AB-'];
const _categories   = ['General', 'OBC', 'SC', 'ST', 'EWS'];
const _countries    = ['India', 'Other'];
const _guardianRelations = [
  'Father', 'Mother', 'Guardian', 'Step-Father', 'Step-Mother',
  'Uncle', 'Aunt', 'Grandparent', 'Sibling', 'Other',
];
const _indianStates = [
  'Andhra Pradesh', 'Arunachal Pradesh', 'Assam', 'Bihar', 'Chhattisgarh',
  'Goa', 'Gujarat', 'Haryana', 'Himachal Pradesh', 'Jharkhand', 'Karnataka',
  'Kerala', 'Madhya Pradesh', 'Maharashtra', 'Manipur', 'Meghalaya', 'Mizoram',
  'Nagaland', 'Odisha', 'Punjab', 'Rajasthan', 'Sikkim', 'Tamil Nadu',
  'Telangana', 'Tripura', 'Uttar Pradesh', 'Uttarakhand', 'West Bengal',
  'Andaman and Nicobar Islands', 'Chandigarh',
  'Dadra and Nagar Haveli and Daman and Diu', 'Delhi', 'Jammu and Kashmir',
  'Ladakh', 'Lakshadweep', 'Puducherry',
];

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

  // ── Personal
  final _firstNameCtrl    = TextEditingController();
  final _middleNameCtrl   = TextEditingController();
  final _lastNameCtrl     = TextEditingController();
  final _dobCtrl          = TextEditingController();
  final _aadhaarCtrl      = TextEditingController();
  final _nationalityCtrl  = TextEditingController();
  final _religionCtrl     = TextEditingController();
  final _schoolHouseCtrl  = TextEditingController();
  String? _gender;
  String? _bloodGroup;
  String? _category;

  // Student photo
  Uint8List? _studentPhotoBytes;
  String?    _studentPhotoUrl;
  bool       _uploadingStudentPhoto = false;

  // ── Guardian
  final _guardianCtrls = List.generate(4, (_) => _GuardianControllers());
  int _activeGuardianTab = 0;

  // ── Address
  final _addrLine1Ctrl = TextEditingController();
  final _addrLine2Ctrl = TextEditingController();
  final _cityCtrl      = TextEditingController();
  final _stateCtrl     = TextEditingController();
  final _zipCtrl       = TextEditingController();
  String _country      = 'India';

  // ── Transport
  final _busRouteCtrl  = TextEditingController();
  final _busStopCtrl   = TextEditingController();
  final _busNumberCtrl = TextEditingController();
  bool  _privateCabFlag         = false;
  bool  _parentsPersonallyPick  = false;
  final _cabRegnCtrl            = TextEditingController();
  final _cabModelCtrl           = TextEditingController();
  final _cabDriverNameCtrl      = TextEditingController();
  final _cabDriverLicenseCtrl   = TextEditingController();
  final _cabLicenseExpiryCtrl   = TextEditingController();

  // ── School Info
  final _classCtrl       = TextEditingController();
  final _sectionCtrl     = TextEditingController();
  final _rollNoCtrl      = TextEditingController();
  final _studentIdCtrl   = TextEditingController();
  final _admissionNoCtrl = TextEditingController();

  // ── Change reason (edit only)
  final _changeReasonCtrl = TextEditingController();

  bool _saving  = false;
  bool _loading = false;

  bool get _isEdit => widget.studentId != null;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 5, vsync: this);
    if (_isEdit) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
    }
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final resp = await ref.read(_studentDetailProvider(widget.studentId).future);
      if (resp == null || !mounted) return;
      final d = (resp['data'] as Map<String, dynamic>?) ?? resp;

      _firstNameCtrl.text    = d['first_name']    as String? ?? '';
      _middleNameCtrl.text   = d['middle_name']   as String? ?? '';
      _lastNameCtrl.text     = d['last_name']      as String? ?? '';
      _dobCtrl.text          = d['date_of_birth']  as String? ?? '';
      _aadhaarCtrl.text      = d['aadhaar_no']     as String? ?? '';
      _nationalityCtrl.text  = d['nationality']   as String? ?? '';
      _religionCtrl.text     = d['religion']       as String? ?? '';
      _schoolHouseCtrl.text  = d['school_house_name'] as String? ?? '';
      _addrLine1Ctrl.text    = d['address_line1']  as String? ?? '';
      _addrLine2Ctrl.text    = d['address_line2']  as String? ?? '';
      _cityCtrl.text         = d['city']           as String? ?? '';
      _stateCtrl.text        = d['state']          as String? ?? '';
      _zipCtrl.text          = d['zip_code']       as String? ?? '';
      _busRouteCtrl.text     = d['bus_route']      as String? ?? '';
      _busStopCtrl.text      = d['bus_stop']       as String? ?? '';
      _busNumberCtrl.text    = d['bus_number']     as String? ?? '';
      _cabRegnCtrl.text      = d['private_cab_regn_no']          as String? ?? '';
      _cabModelCtrl.text     = d['private_cab_model']            as String? ?? '';
      _cabDriverNameCtrl.text     = d['private_cab_driver_name']        as String? ?? '';
      _cabDriverLicenseCtrl.text  = d['private_cab_driver_license_no']  as String? ?? '';
      _cabLicenseExpiryCtrl.text  = d['private_cab_license_expiry_dt']  as String? ?? '';
      _classCtrl.text        = d['class_name']     as String? ?? '';
      _sectionCtrl.text      = d['section']        as String? ?? '';
      _rollNoCtrl.text       = d['roll_number']    as String? ?? '';
      _studentIdCtrl.text    = d['student_id']     as String? ?? '';
      _admissionNoCtrl.text  = d['admission_no']   as String? ?? '';

      final rawCountry = d['country'] as String?;
      if (rawCountry != null && _countries.contains(rawCountry)) {
        _country = rawCountry;
      }

      setState(() {
        _gender          = d['gender']      as String?;
        _bloodGroup      = d['blood_group'] as String?;
        _category        = d['category']    as String?;
        _studentPhotoUrl = d['photo_url']   as String?;
        _privateCabFlag        = (d['private_cab_flag']        as bool?) ?? false;
        _parentsPersonallyPick = (d['parents_personally_pick'] as bool?) ?? false;
      });

      // Guardians
      const typeIndex = <String, int>{
        'mother': 0, 'father': 1, 'guardian_1': 2, 'guardian_2': 3,
      };
      for (final g in (d['guardians'] as List<dynamic>? ?? [])) {
        final gm  = g as Map<String, dynamic>;
        final idx = typeIndex[(gm['guardian_type'] as String? ?? '').toLowerCase()];
        if (idx == null) continue;
        final c = _guardianCtrls[idx];
        c.firstNameCtrl.text   = gm['first_name']   as String? ?? '';
        c.lastNameCtrl.text    = gm['last_name']     as String? ?? '';
        c.phoneCtrl.text       = gm['phone']         as String? ?? '';
        c.whatsappCtrl.text    = gm['whatsapp_no']   as String? ?? '';
        c.altPhoneCtrl.text    = gm['alt_phone']     as String? ?? '';
        c.emailCtrl.text       = gm['email']         as String? ?? '';
        c.occupationCtrl.text  = gm['occupation']    as String? ?? '';
        c.organizationCtrl.text = gm['organization'] as String? ?? '';
        c.annualIncomeCtrl.text = gm['annual_income'] != null
            ? gm['annual_income'].toString() : '';
        c.aadhaarCtrl.text     = gm['aadhaar_no']   as String? ?? '';
        c.addrLine1Ctrl.text   = gm['address_line1'] as String? ?? '';
        c.addrLine2Ctrl.text   = gm['address_line2'] as String? ?? '';
        c.cityCtrl.text        = gm['city']          as String? ?? '';
        c.stateCtrl.text       = gm['state']         as String? ?? '';
        c.zipCtrl.text         = gm['zip_code']      as String? ?? '';
        final rawRel = gm['relation'] as String?;
        setState(() {
          c.relation   = rawRel != null && _guardianRelations.contains(rawRel) ? rawRel : null;
          c.isPrimary  = (gm['is_primary'] as bool?) ?? false;
          c.sameAsStudent = (gm['same_as_student'] as bool?) ?? false;
          c.photoUrl   = gm['photo_url'] as String?;
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Failed to load student: $e'),
        backgroundColor: AppTheme.error,
      ));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── Photo upload helpers ──────────────────────────────────────
  Future<void> _pickStudentPhoto() async {
    final img = await ImagePicker().pickImage(
      source: ImageSource.gallery, maxWidth: 800, maxHeight: 800, imageQuality: 90,
    );
    if (img == null) return;
    final bytes = await img.readAsBytes();
    setState(() { _studentPhotoBytes = bytes; _uploadingStudentPhoto = true; });
    try {
      final res = await ApiService().uploadFile(
        '/uploads/student-photo',
        bytes: bytes, fileName: 'student_photo.jpg', fieldName: 'photo',
      );
      setState(() => _studentPhotoUrl = res['data']['url'] as String?);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Photo upload failed: $e'), backgroundColor: AppTheme.error,
      ));
      setState(() { _studentPhotoBytes = null; _studentPhotoUrl = null; });
    } finally {
      if (mounted) setState(() => _uploadingStudentPhoto = false);
    }
  }

  Future<void> _pickGuardianPhoto(int idx) async {
    final img = await ImagePicker().pickImage(
      source: ImageSource.gallery, maxWidth: 600, maxHeight: 600, imageQuality: 85,
    );
    if (img == null) return;
    final bytes = await img.readAsBytes();
    setState(() { _guardianCtrls[idx].photoBytes = bytes; _guardianCtrls[idx].uploadingPhoto = true; });
    try {
      final res = await ApiService().uploadFile(
        '/uploads/photo',
        bytes: bytes, fileName: 'guardian_photo.jpg', fieldName: 'photo',
        fields: {'entity': 'guardian'},
      );
      setState(() => _guardianCtrls[idx].photoUrl = res['data']['url'] as String?);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Photo upload failed: $e'), backgroundColor: AppTheme.error,
      ));
      setState(() { _guardianCtrls[idx].photoBytes = null; _guardianCtrls[idx].photoUrl = null; });
    } finally {
      if (mounted) setState(() => _guardianCtrls[idx].uploadingPhoto = false);
    }
  }

  // ── Save ─────────────────────────────────────────────────────
  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      _tabCtrl.animateTo(0);
      return;
    }
    setState(() => _saving = true);

    try {
      // Build guardians list
      const guardianTypes = ['mother', 'father', 'guardian_1', 'guardian_2'];
      final guardiansList = <Map<String, dynamic>>[];
      for (int i = 0; i < 4; i++) {
        final c = _guardianCtrls[i];
        if (c.firstNameCtrl.text.isEmpty && c.phoneCtrl.text.isEmpty) continue;
        guardiansList.add({
          'guardian_type':  guardianTypes[i],
          'first_name':     c.firstNameCtrl.text.trim(),
          'last_name':      c.lastNameCtrl.text.trim(),
          'relation':       c.relation,
          'phone':          c.phoneCtrl.text.trim(),
          'whatsapp_no':    c.whatsappCtrl.text.trim(),
          'alt_phone':      c.altPhoneCtrl.text.trim(),
          'email':          c.emailCtrl.text.trim(),
          'occupation':     c.occupationCtrl.text.trim(),
          'organization':   c.organizationCtrl.text.trim(),
          'annual_income':  c.annualIncomeCtrl.text.trim().isEmpty
              ? null : double.tryParse(c.annualIncomeCtrl.text.trim()),
          'aadhaar_no':     c.aadhaarCtrl.text.trim(),
          'is_primary':     c.isPrimary,
          'same_as_student': c.sameAsStudent,
          'address_line1':  c.sameAsStudent ? _addrLine1Ctrl.text.trim() : c.addrLine1Ctrl.text.trim(),
          'address_line2':  c.sameAsStudent ? _addrLine2Ctrl.text.trim() : c.addrLine2Ctrl.text.trim(),
          'city':           c.sameAsStudent ? _cityCtrl.text.trim()      : c.cityCtrl.text.trim(),
          'state':          c.sameAsStudent ? _stateCtrl.text.trim()     : c.stateCtrl.text.trim(),
          'country':        _country,
          'zip_code':       c.sameAsStudent ? _zipCtrl.text.trim()       : c.zipCtrl.text.trim(),
          if (c.photoUrl != null) 'photo_url': c.photoUrl,
        });
      }

      final user = ref.read(authNotifierProvider).value;
      final body = <String, dynamic>{
        'school_id':     user?.schoolId ?? user?.employee?.schoolId,
        'branch_id':     user?.employee?.branchId,
        'first_name':    _firstNameCtrl.text.trim(),
        'middle_name':   _middleNameCtrl.text.trim(),
        'last_name':     _lastNameCtrl.text.trim(),
        'date_of_birth': _dobCtrl.text.trim(),
        'gender':        _gender?.toLowerCase(),
        'blood_group':   _bloodGroup,
        'category':      _category,
        'nationality':   _nationalityCtrl.text.trim(),
        'religion':      _religionCtrl.text.trim(),
        'aadhaar_no':    _aadhaarCtrl.text.trim(),
        'school_house_name': _schoolHouseCtrl.text.trim(),
        'address_line1': _addrLine1Ctrl.text.trim(),
        'address_line2': _addrLine2Ctrl.text.trim(),
        'city':          _cityCtrl.text.trim(),
        'state':         _stateCtrl.text.trim(),
        'country':       _country,
        'zip_code':      _zipCtrl.text.trim(),
        'bus_route':     _busRouteCtrl.text.trim(),
        'bus_stop':      _busStopCtrl.text.trim(),
        'bus_number':    _busNumberCtrl.text.trim(),
        'private_cab_flag':        _privateCabFlag,
        'parents_personally_pick': _parentsPersonallyPick,
        'private_cab_regn_no':           _cabRegnCtrl.text.trim(),
        'private_cab_model':             _cabModelCtrl.text.trim(),
        'private_cab_driver_name':       _cabDriverNameCtrl.text.trim(),
        'private_cab_driver_license_no': _cabDriverLicenseCtrl.text.trim(),
        'private_cab_license_expiry_dt': _cabLicenseExpiryCtrl.text.trim(),
        'class_name':    _classCtrl.text.trim(),
        'section':       _sectionCtrl.text.trim(),
        'roll_number':   _rollNoCtrl.text.trim(),
        'guardians':     guardiansList,
        if (_studentPhotoUrl != null) 'photo_url': _studentPhotoUrl,
        // student_id and admission_no only on add (not editable)
        if (!_isEdit) 'student_id':   _studentIdCtrl.text.trim(),
        if (!_isEdit) 'admission_no': _admissionNoCtrl.text.trim(),
      };

      if (_isEdit) {
        // Require change reason for audit trail
        _changeReasonCtrl.clear();
        final confirmed = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            title: const Text('Reason for Change'),
            content: TextField(
              controller: _changeReasonCtrl,
              autofocus: true,
              maxLength: 255,
              decoration: const InputDecoration(
                hintText: 'e.g. Address updated, class promoted…',
                counterText: '',
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  if (_changeReasonCtrl.text.trim().isEmpty) return;
                  Navigator.of(ctx).pop(true);
                },
                child: const Text('Save'),
              ),
            ],
          ),
        );
        if (confirmed != true || !mounted) {
          setState(() => _saving = false);
          return;
        }
        body['change_reason'] = _changeReasonCtrl.text.trim();
        await ApiService().put('/students/${widget.studentId}', body: body);
      } else {
        await ApiService().post('/students', body: body);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(_isEdit ? 'Student updated successfully' : 'Student created successfully'),
        backgroundColor: AppTheme.statusGreen,
      ));
      Navigator.of(context).pop();
    } catch (e) {
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Error: $e'), backgroundColor: AppTheme.error,
      ));
    }
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _firstNameCtrl.dispose(); _middleNameCtrl.dispose(); _lastNameCtrl.dispose();
    _dobCtrl.dispose(); _aadhaarCtrl.dispose(); _nationalityCtrl.dispose();
    _religionCtrl.dispose(); _schoolHouseCtrl.dispose();
    _addrLine1Ctrl.dispose(); _addrLine2Ctrl.dispose(); _cityCtrl.dispose();
    _stateCtrl.dispose(); _zipCtrl.dispose();
    _busRouteCtrl.dispose(); _busStopCtrl.dispose(); _busNumberCtrl.dispose();
    _cabRegnCtrl.dispose(); _cabModelCtrl.dispose(); _cabDriverNameCtrl.dispose();
    _cabDriverLicenseCtrl.dispose(); _cabLicenseExpiryCtrl.dispose();
    _classCtrl.dispose(); _sectionCtrl.dispose(); _rollNoCtrl.dispose();
    _studentIdCtrl.dispose(); _admissionNoCtrl.dispose();
    _changeReasonCtrl.dispose();
    for (final g in _guardianCtrls) g.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          backgroundColor: AppTheme.grey50,
          appBar: AppBar(
            title: Text(_isEdit ? 'Edit Student' : 'Add New Student'),
            bottom: TabBar(
              controller: _tabCtrl,
              isScrollable: true,
              tabs: const [
                Tab(icon: Icon(Icons.person, size: 18),       text: 'Personal'),
                Tab(icon: Icon(Icons.family_restroom, size: 18), text: 'Guardian'),
                Tab(icon: Icon(Icons.home, size: 18),         text: 'Address'),
                Tab(icon: Icon(Icons.directions_bus, size: 18), text: 'Transport'),
                Tab(icon: Icon(Icons.school, size: 18),       text: 'School Info'),
              ],
            ),
          ),
          body: Form(
            key: _formKey,
            child: TabBarView(
              controller: _tabCtrl,
              children: [
                _PersonalTab(
                  firstNameCtrl:   _firstNameCtrl,
                  middleNameCtrl:  _middleNameCtrl,
                  lastNameCtrl:    _lastNameCtrl,
                  dobCtrl:         _dobCtrl,
                  aadhaarCtrl:     _aadhaarCtrl,
                  nationalityCtrl: _nationalityCtrl,
                  religionCtrl:    _religionCtrl,
                  schoolHouseCtrl: _schoolHouseCtrl,
                  gender:          _gender,
                  bloodGroup:      _bloodGroup,
                  category:        _category,
                  photoBytes:      _studentPhotoBytes,
                  photoUrl:        _studentPhotoUrl,
                  uploadingPhoto:  _uploadingStudentPhoto,
                  onGenderChanged:     (v) => setState(() => _gender     = v),
                  onBloodGroupChanged: (v) => setState(() => _bloodGroup = v),
                  onCategoryChanged:   (v) => setState(() => _category   = v),
                  onPickPhoto:         _pickStudentPhoto,
                ),
                _GuardianTab(
                  controllers:  _guardianCtrls,
                  activeTab:    _activeGuardianTab,
                  onTabChanged: (i) => setState(() => _activeGuardianTab = i),
                  onPickPhoto:  _pickGuardianPhoto,
                  onChanged:    () => setState(() {}),
                ),
                _AddressTab(
                  addrLine1Ctrl: _addrLine1Ctrl,
                  addrLine2Ctrl: _addrLine2Ctrl,
                  cityCtrl:      _cityCtrl,
                  stateCtrl:     _stateCtrl,
                  zipCtrl:       _zipCtrl,
                  country:       _country,
                  onCountryChanged: (v) => setState(() => _country = v ?? 'India'),
                ),
                _TransportTab(
                  busRouteCtrl:   _busRouteCtrl,
                  busStopCtrl:    _busStopCtrl,
                  busNumberCtrl:  _busNumberCtrl,
                  privateCabFlag: _privateCabFlag,
                  parentsPersonallyPick: _parentsPersonallyPick,
                  cabRegnCtrl:    _cabRegnCtrl,
                  cabModelCtrl:   _cabModelCtrl,
                  cabDriverNameCtrl:    _cabDriverNameCtrl,
                  cabDriverLicenseCtrl: _cabDriverLicenseCtrl,
                  cabLicenseExpiryCtrl: _cabLicenseExpiryCtrl,
                  onPrivateCabChanged:   (v) => setState(() => _privateCabFlag = v ?? false),
                  onParentsPickChanged:  (v) => setState(() => _parentsPersonallyPick = v ?? false),
                ),
                _SchoolInfoTab(
                  classCtrl:      _classCtrl,
                  sectionCtrl:    _sectionCtrl,
                  rollNoCtrl:     _rollNoCtrl,
                  studentIdCtrl:  _studentIdCtrl,
                  admissionCtrl:  _admissionNoCtrl,
                  isEdit:         _isEdit,
                ),
              ],
            ),
          ),
          bottomNavigationBar: _FormBottomBar(
            onSave:   _save,
            saving:   _saving,
            onCancel: () => Navigator.of(context).pop(),
          ),
        ),
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
}

// ── Personal Tab ──────────────────────────────────────────────
class _PersonalTab extends StatelessWidget {
  final TextEditingController firstNameCtrl, middleNameCtrl, lastNameCtrl;
  final TextEditingController dobCtrl, aadhaarCtrl, nationalityCtrl, religionCtrl, schoolHouseCtrl;
  final String? gender, bloodGroup, category;
  final Uint8List? photoBytes;
  final String?   photoUrl;
  final bool      uploadingPhoto;
  final ValueChanged<String?> onGenderChanged, onBloodGroupChanged, onCategoryChanged;
  final VoidCallback onPickPhoto;

  const _PersonalTab({
    required this.firstNameCtrl, required this.middleNameCtrl, required this.lastNameCtrl,
    required this.dobCtrl, required this.aadhaarCtrl, required this.nationalityCtrl,
    required this.religionCtrl, required this.schoolHouseCtrl,
    required this.gender, required this.bloodGroup, required this.category,
    required this.photoBytes, required this.photoUrl, required this.uploadingPhoto,
    required this.onGenderChanged, required this.onBloodGroupChanged,
    required this.onCategoryChanged, required this.onPickPhoto,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Photo column
          Column(
            children: [
              _PhotoWidget(
                bytes: photoBytes, url: photoUrl, uploading: uploadingPhoto, onTap: onPickPhoto,
              ),
              const SizedBox(height: 8),
              Text('Student Photo',
                  style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.grey600)),
            ],
          ),
          const SizedBox(width: 32),
          Expanded(
            child: Column(
              children: [
                Row(children: [
                  Expanded(child: _FF(label: 'First Name *', ctrl: firstNameCtrl,
                      validator: (v) => v == null || v.isEmpty ? 'Required' : null)),
                  const SizedBox(width: 16),
                  Expanded(child: _FF(label: 'Middle Name', ctrl: middleNameCtrl)),
                  const SizedBox(width: 16),
                  Expanded(child: _FF(label: 'Last Name *', ctrl: lastNameCtrl,
                      validator: (v) => v == null || v.isEmpty ? 'Required' : null)),
                ]),
                const SizedBox(height: 16),
                Row(children: [
                  Expanded(child: _FF(
                    label: 'Date of Birth *', ctrl: dobCtrl, hint: 'YYYY-MM-DD',
                    suffix: const Icon(Icons.calendar_today, size: 16),
                    validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                  )),
                  const SizedBox(width: 16),
                  Expanded(child: _DD<String>(label: 'Gender *', value: gender,
                    items: _genders, onChanged: onGenderChanged,
                    validator: (v) => v == null ? 'Required' : null)),
                ]),
                const SizedBox(height: 16),
                Row(children: [
                  Expanded(child: _DD<String>(label: 'Blood Group', value: bloodGroup,
                      items: _bloodGroups, onChanged: onBloodGroupChanged)),
                  const SizedBox(width: 16),
                  Expanded(child: _DD<String>(label: 'Category', value: category,
                      items: _categories, onChanged: onCategoryChanged)),
                ]),
                const SizedBox(height: 16),
                Row(children: [
                  Expanded(child: _FF(label: 'Nationality', ctrl: nationalityCtrl, hint: 'e.g. Indian')),
                  const SizedBox(width: 16),
                  Expanded(child: _FF(label: 'Religion', ctrl: religionCtrl)),
                ]),
                const SizedBox(height: 16),
                Row(children: [
                  Expanded(child: _FF(
                    label: 'Aadhaar Number', ctrl: aadhaarCtrl,
                    hint: '12-digit Aadhaar', maxLen: 12,
                    keyboard: TextInputType.number,
                  )),
                  const SizedBox(width: 16),
                  Expanded(child: _FF(label: 'School House', ctrl: schoolHouseCtrl,
                      hint: 'e.g. Red House')),
                ]),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms);
  }
}

// ── Guardian Tab ──────────────────────────────────────────────
class _GuardianTab extends StatelessWidget {
  final List<_GuardianControllers> controllers;
  final int activeTab;
  final ValueChanged<int> onTabChanged;
  final void Function(int) onPickPhoto;
  final VoidCallback onChanged;

  const _GuardianTab({
    required this.controllers, required this.activeTab,
    required this.onTabChanged, required this.onPickPhoto, required this.onChanged,
  });

  static const _labels = ['Mother', 'Father', 'Guardian 1', 'Guardian 2'];
  static const _icons  = [Icons.person, Icons.person_2, Icons.person_3, Icons.person_4];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          color: AppTheme.grey100,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Row(
            children: List.generate(4, (i) {
              final isActive = i == activeTab;
              return Expanded(
                child: GestureDetector(
                  onTap: () => onTabChanged(i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: isActive ? AppTheme.primary : Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: isActive
                          ? [BoxShadow(color: AppTheme.primary.withOpacity(0.3), blurRadius: 8)]
                          : null,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(_icons[i], size: 14,
                            color: isActive ? Colors.white : AppTheme.grey600),
                        const SizedBox(width: 4),
                        Text(_labels[i], style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: isActive ? Colors.white : AppTheme.grey600,
                          fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                        )),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: _GuardianForm(
              label: _labels[activeTab],
              ctrl: controllers[activeTab],
              onPickPhoto: () => onPickPhoto(activeTab),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }
}

class _GuardianForm extends StatelessWidget {
  final String label;
  final _GuardianControllers ctrl;
  final VoidCallback onPickPhoto;
  final VoidCallback onChanged;

  const _GuardianForm({
    required this.label, required this.ctrl,
    required this.onPickPhoto, required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Photo + primary/same-address toggles
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              children: [
                _PhotoWidget(
                  bytes: ctrl.photoBytes, url: ctrl.photoUrl,
                  uploading: ctrl.uploadingPhoto, onTap: onPickPhoto,
                  size: 100,
                ),
                const SizedBox(height: 6),
                Text('$label Photo',
                    style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.grey600)),
              ],
            ),
            const SizedBox(width: 24),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: CheckboxListTile(
                          value: ctrl.isPrimary,
                          onChanged: (v) { ctrl.isPrimary = v ?? false; onChanged(); },
                          title: Text('Primary Contact',
                              style: GoogleFonts.poppins(fontSize: 13)),
                          dense: true, contentPadding: EdgeInsets.zero,
                        ),
                      ),
                      Expanded(
                        child: CheckboxListTile(
                          value: ctrl.sameAsStudent,
                          onChanged: (v) { ctrl.sameAsStudent = v ?? false; onChanged(); },
                          title: Text('Same Address as Student',
                              style: GoogleFonts.poppins(fontSize: 13)),
                          dense: true, contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(child: _DD<String>(
                      label: 'Relation', value: ctrl.relation,
                      items: _guardianRelations,
                      onChanged: (v) { ctrl.relation = v; onChanged(); },
                    )),
                  ]),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _SectionHeader('Personal Info'),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: _FF(label: 'First Name', ctrl: ctrl.firstNameCtrl)),
          const SizedBox(width: 14),
          Expanded(child: _FF(label: 'Last Name', ctrl: ctrl.lastNameCtrl)),
        ]),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(child: _FF(label: 'Phone', ctrl: ctrl.phoneCtrl,
              keyboard: TextInputType.phone, prefix: const Icon(Icons.phone, size: 16))),
          const SizedBox(width: 14),
          Expanded(child: _FF(label: 'WhatsApp', ctrl: ctrl.whatsappCtrl,
              keyboard: TextInputType.phone, prefix: const Icon(Icons.chat, size: 16))),
          const SizedBox(width: 14),
          Expanded(child: _FF(label: 'Alt. Phone', ctrl: ctrl.altPhoneCtrl,
              keyboard: TextInputType.phone)),
        ]),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(child: _FF(label: 'Email', ctrl: ctrl.emailCtrl,
              keyboard: TextInputType.emailAddress,
              prefix: const Icon(Icons.email_outlined, size: 16))),
          const SizedBox(width: 14),
          Expanded(child: _FF(label: 'Occupation', ctrl: ctrl.occupationCtrl,
              prefix: const Icon(Icons.work_outline, size: 16))),
        ]),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(child: _FF(label: 'Organization / Employer',
              ctrl: ctrl.organizationCtrl)),
          const SizedBox(width: 14),
          Expanded(child: _FF(label: 'Annual Income (₹)',
              ctrl: ctrl.annualIncomeCtrl, keyboard: TextInputType.number)),
          const SizedBox(width: 14),
          Expanded(child: _FF(label: 'Aadhaar No.', ctrl: ctrl.aadhaarCtrl,
              keyboard: TextInputType.number, maxLen: 12)),
        ]),
        if (!ctrl.sameAsStudent) ...[
          const SizedBox(height: 20),
          _SectionHeader('Guardian Address'),
          const SizedBox(height: 12),
          _FF(label: 'Street Address', ctrl: ctrl.addrLine1Ctrl, maxLines: 2,
              prefix: const Icon(Icons.location_on_outlined, size: 16)),
          const SizedBox(height: 14),
          _FF(label: 'Address Line 2', ctrl: ctrl.addrLine2Ctrl),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(child: _FF(label: 'City', ctrl: ctrl.cityCtrl)),
            const SizedBox(width: 14),
            Expanded(child: _FF(label: 'State', ctrl: ctrl.stateCtrl)),
            const SizedBox(width: 14),
            SizedBox(width: 120, child: _FF(label: 'PIN Code', ctrl: ctrl.zipCtrl,
                keyboard: TextInputType.number, maxLen: 6)),
          ]),
        ],
      ],
    );
  }
}

// ── Address Tab ───────────────────────────────────────────────
class _AddressTab extends StatelessWidget {
  final TextEditingController addrLine1Ctrl, addrLine2Ctrl, cityCtrl, stateCtrl, zipCtrl;
  final String country;
  final ValueChanged<String?> onCountryChanged;

  const _AddressTab({
    required this.addrLine1Ctrl, required this.addrLine2Ctrl,
    required this.cityCtrl, required this.stateCtrl, required this.zipCtrl,
    required this.country, required this.onCountryChanged,
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
          _FF(label: 'Street Address', ctrl: addrLine1Ctrl, maxLines: 2,
              prefix: const Icon(Icons.location_on_outlined, size: 16)),
          const SizedBox(height: 14),
          _FF(label: 'Address Line 2', ctrl: addrLine2Ctrl),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(child: _FF(label: 'City', ctrl: cityCtrl)),
            const SizedBox(width: 14),
            Expanded(child: _FF(label: 'State / UT', ctrl: stateCtrl)),
            const SizedBox(width: 14),
            SizedBox(width: 120, child: _FF(label: 'PIN Code', ctrl: zipCtrl,
                keyboard: TextInputType.number, maxLen: 6)),
          ]),
          const SizedBox(height: 14),
          SizedBox(
            width: 200,
            child: _DD<String>(label: 'Country', value: country,
                items: _countries, onChanged: onCountryChanged),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms);
  }
}

// ── Transport Tab ─────────────────────────────────────────────
class _TransportTab extends StatelessWidget {
  final TextEditingController busRouteCtrl, busStopCtrl, busNumberCtrl;
  final bool privateCabFlag, parentsPersonallyPick;
  final TextEditingController cabRegnCtrl, cabModelCtrl, cabDriverNameCtrl,
      cabDriverLicenseCtrl, cabLicenseExpiryCtrl;
  final ValueChanged<bool?> onPrivateCabChanged, onParentsPickChanged;

  const _TransportTab({
    required this.busRouteCtrl, required this.busStopCtrl, required this.busNumberCtrl,
    required this.privateCabFlag, required this.parentsPersonallyPick,
    required this.cabRegnCtrl, required this.cabModelCtrl, required this.cabDriverNameCtrl,
    required this.cabDriverLicenseCtrl, required this.cabLicenseExpiryCtrl,
    required this.onPrivateCabChanged, required this.onParentsPickChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader('School Bus'),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: _FF(label: 'Bus Route No.', ctrl: busRouteCtrl,
                prefix: const Icon(Icons.directions_bus, size: 16))),
            const SizedBox(width: 14),
            Expanded(child: _FF(label: 'Bus Stop', ctrl: busStopCtrl,
                prefix: const Icon(Icons.location_city, size: 16))),
            const SizedBox(width: 14),
            Expanded(child: _FF(label: 'Bus Number', ctrl: busNumberCtrl)),
          ]),
          const SizedBox(height: 24),
          _SectionHeader('Private Transport'),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: CheckboxListTile(
                value: privateCabFlag,
                onChanged: onPrivateCabChanged,
                title: Text('Uses Private Cab',
                    style: GoogleFonts.poppins(fontSize: 13)),
                dense: true, contentPadding: EdgeInsets.zero,
              ),
            ),
            Expanded(
              child: CheckboxListTile(
                value: parentsPersonallyPick,
                onChanged: onParentsPickChanged,
                title: Text('Parents Pick Up Personally',
                    style: GoogleFonts.poppins(fontSize: 13)),
                dense: true, contentPadding: EdgeInsets.zero,
              ),
            ),
          ]),
          if (privateCabFlag) ...[
            const SizedBox(height: 16),
            Row(children: [
              Expanded(child: _FF(label: 'Cab Reg. No. *', ctrl: cabRegnCtrl,
                  validator: (v) => v == null || v.isEmpty ? 'Required for private cab' : null)),
              const SizedBox(width: 14),
              Expanded(child: _FF(label: 'Cab Model', ctrl: cabModelCtrl)),
            ]),
            const SizedBox(height: 14),
            Row(children: [
              Expanded(child: _FF(label: 'Driver Name', ctrl: cabDriverNameCtrl)),
              const SizedBox(width: 14),
              Expanded(child: _FF(label: 'Driver License No. *', ctrl: cabDriverLicenseCtrl,
                  validator: (v) => v == null || v.isEmpty ? 'Required for private cab' : null)),
              const SizedBox(width: 14),
              Expanded(child: _FF(
                label: 'License Expiry Date', ctrl: cabLicenseExpiryCtrl,
                hint: 'YYYY-MM-DD',
                suffix: const Icon(Icons.calendar_today, size: 16),
              )),
            ]),
          ],
        ],
      ),
    ).animate().fadeIn(duration: 300.ms);
  }
}

// ── School Info Tab ───────────────────────────────────────────
class _SchoolInfoTab extends StatelessWidget {
  final TextEditingController classCtrl, sectionCtrl, rollNoCtrl,
      studentIdCtrl, admissionCtrl;
  final bool isEdit;

  const _SchoolInfoTab({
    required this.classCtrl, required this.sectionCtrl, required this.rollNoCtrl,
    required this.studentIdCtrl, required this.admissionCtrl, required this.isEdit,
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
          Row(children: [
            Expanded(child: _FF(label: 'Class *', ctrl: classCtrl, hint: 'e.g. Class 5',
                validator: (v) => v == null || v.isEmpty ? 'Required' : null)),
            const SizedBox(width: 14),
            Expanded(child: _FF(label: 'Section *', ctrl: sectionCtrl, hint: 'A / B / C',
                validator: (v) => v == null || v.isEmpty ? 'Required' : null)),
            const SizedBox(width: 14),
            Expanded(child: _FF(label: 'Roll Number *', ctrl: rollNoCtrl,
                keyboard: TextInputType.number,
                validator: (v) => v == null || v.isEmpty ? 'Required' : null)),
          ]),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(
              child: isEdit
                  ? _ReadOnlyField(label: 'Student ID', value: studentIdCtrl.text)
                  : _FF(label: 'Student ID', ctrl: studentIdCtrl,
                        hint: 'Auto-generated if empty',
                        prefix: const Icon(Icons.badge_outlined, size: 16)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: isEdit
                  ? _ReadOnlyField(label: 'Admission No.', value: admissionCtrl.text)
                  : _FF(label: 'Admission No.', ctrl: admissionCtrl,
                        prefix: const Icon(Icons.assignment_ind, size: 16)),
            ),
          ]),
          if (isEdit) ...[
            const SizedBox(height: 8),
            Text(
              'Student ID and Admission No. cannot be changed after creation.',
              style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.grey600),
            ),
          ],
        ],
      ),
    ).animate().fadeIn(duration: 300.ms);
  }
}

// ── Photo Widget ──────────────────────────────────────────────
class _PhotoWidget extends StatelessWidget {
  final Uint8List? bytes;
  final String?   url;
  final bool      uploading;
  final VoidCallback onTap;
  final double    size;

  const _PhotoWidget({
    this.bytes, this.url, required this.uploading,
    required this.onTap, this.size = 120,
  });

  @override
  Widget build(BuildContext context) {
    final hasPhoto = bytes != null || url != null;
    return GestureDetector(
      onTap: uploading ? null : onTap,
      child: Container(
        width: size, height: size * 1.15,
        decoration: BoxDecoration(
          color: AppTheme.grey200,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.grey300),
          image: bytes != null
              ? DecorationImage(image: MemoryImage(bytes!), fit: BoxFit.cover)
              : null,
        ),
        child: uploading
            ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
            : !hasPhoto
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add_a_photo, color: AppTheme.grey600, size: 28),
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
                          color: AppTheme.primary, shape: BoxShape.circle),
                        padding: const EdgeInsets.all(4),
                        child: const Icon(Icons.edit, color: Colors.white, size: 14),
                      ),
                    ),
                  ),
      ),
    );
  }
}

// ── Read-only field ───────────────────────────────────────────
class _ReadOnlyField extends StatelessWidget {
  final String label, value;
  const _ReadOnlyField({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: AppTheme.grey100,
      ),
      child: Text(value.isEmpty ? '—' : value,
          style: GoogleFonts.poppins(fontSize: 13, color: AppTheme.grey600)),
    );
  }
}

// ── Bottom Save Bar ───────────────────────────────────────────
class _FormBottomBar extends StatelessWidget {
  final VoidCallback onSave, onCancel;
  final bool saving;
  const _FormBottomBar({required this.onSave, required this.onCancel, required this.saving});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(
          color: AppTheme.primary.withOpacity(0.08), blurRadius: 10, offset: const Offset(0, -2),
        )],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          OutlinedButton(onPressed: onCancel, child: const Text('Cancel')),
          const SizedBox(width: 12),
          ElevatedButton.icon(
            onPressed: saving ? null : onSave,
            icon: saving
                ? const SizedBox(width: 16, height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.save, size: 16),
            label: Text(saving ? 'Saving…' : 'Save Student'),
          ),
        ],
      ),
    );
  }
}

// ── Guardian Controllers ──────────────────────────────────────
class _GuardianControllers {
  final firstNameCtrl    = TextEditingController();
  final lastNameCtrl     = TextEditingController();
  final phoneCtrl        = TextEditingController();
  final whatsappCtrl     = TextEditingController();
  final altPhoneCtrl     = TextEditingController();
  final emailCtrl        = TextEditingController();
  final occupationCtrl   = TextEditingController();
  final organizationCtrl = TextEditingController();
  final annualIncomeCtrl = TextEditingController();
  final aadhaarCtrl      = TextEditingController();
  final addrLine1Ctrl    = TextEditingController();
  final addrLine2Ctrl    = TextEditingController();
  final cityCtrl         = TextEditingController();
  final stateCtrl        = TextEditingController();
  final zipCtrl          = TextEditingController();

  String?    relation;
  bool       isPrimary      = false;
  bool       sameAsStudent  = false;
  Uint8List? photoBytes;
  String?    photoUrl;
  bool       uploadingPhoto = false;

  void dispose() {
    for (final c in [
      firstNameCtrl, lastNameCtrl, phoneCtrl, whatsappCtrl, altPhoneCtrl,
      emailCtrl, occupationCtrl, organizationCtrl, annualIncomeCtrl, aadhaarCtrl,
      addrLine1Ctrl, addrLine2Ctrl, cityCtrl, stateCtrl, zipCtrl,
    ]) c.dispose();
  }
}

// ── Shared Widgets ────────────────────────────────────────────
class _FF extends StatelessWidget {
  final String label;
  final TextEditingController ctrl;
  final String? hint;
  final FormFieldValidator<String>? validator;
  final TextInputType? keyboard;
  final int? maxLen;
  final int maxLines;
  final Widget? prefix, suffix;

  const _FF({
    required this.label, required this.ctrl,
    this.hint, this.validator, this.keyboard, this.maxLen,
    this.maxLines = 1, this.prefix, this.suffix,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: ctrl, validator: validator,
      keyboardType: keyboard, maxLength: maxLen, maxLines: maxLines,
      style: GoogleFonts.poppins(fontSize: 13),
      decoration: InputDecoration(
        labelText: label, hintText: hint,
        prefixIcon: prefix, suffixIcon: suffix, counterText: '',
      ),
    );
  }
}

class _DD<T> extends StatelessWidget {
  final String label;
  final T? value;
  final List<T> items;
  final ValueChanged<T?> onChanged;
  final FormFieldValidator<T>? validator;

  const _DD({
    required this.label, required this.value,
    required this.items, required this.onChanged, this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<T>(
      value: value, validator: validator,
      decoration: InputDecoration(labelText: label),
      style: GoogleFonts.poppins(fontSize: 13, color: AppTheme.grey900),
      items: items.map((item) =>
        DropdownMenuItem<T>(value: item, child: Text(item.toString()))).toList(),
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
          width: 4, height: 18,
          decoration: BoxDecoration(
            color: AppTheme.primary, borderRadius: BorderRadius.circular(2)),
        ),
        const SizedBox(width: 8),
        Text(title, style: GoogleFonts.poppins(
          fontWeight: FontWeight.w600, fontSize: 14, color: AppTheme.grey900)),
      ],
    );
  }
}
