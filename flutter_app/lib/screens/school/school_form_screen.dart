// ============================================================
// School Create / Edit Form
// ============================================================
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:typed_data';
import '../../config/theme.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import 'branch_setup_screen.dart';

// ── Provider ──────────────────────────────────────────────────
final _schoolDetailProvider =
    FutureProvider.family<Map<String, dynamic>?, String?>((ref, id) async {
  if (id == null) return null;
  try {
    return await ApiService().get('/schools/$id');
  } catch (_) {
    return null;
  }
});

// ── Screen ────────────────────────────────────────────────────
class SchoolFormScreen extends ConsumerStatefulWidget {
  final String? schoolId;
  const SchoolFormScreen({super.key, this.schoolId});

  @override
  ConsumerState<SchoolFormScreen> createState() => _SchoolFormScreenState();
}

class _SchoolFormScreenState extends ConsumerState<SchoolFormScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;
  final _formKey = GlobalKey<FormState>();

  // Basic Info
  final _nameCtrl         = TextEditingController();
  final _codeCtrl         = TextEditingController();
  final _regNoCtrl        = TextEditingController();
  final _affiliationCtrl  = TextEditingController();
  String? _schoolType = 'private'; // government | private | aided | international

  // Contact
  final _phoneCtrl        = TextEditingController();
  final _altPhoneCtrl     = TextEditingController();
  final _emailCtrl        = TextEditingController();
  final _websiteCtrl      = TextEditingController();
  final _principalCtrl    = TextEditingController();

  // Address
  final _addressCtrl      = TextEditingController();
  final _cityCtrl         = TextEditingController();
  final _districtCtrl     = TextEditingController();
  final _stateCtrl        = TextEditingController();
  final _pinCtrl          = TextEditingController();

  // Media
  Uint8List? _logoBytes;
  Uint8List? _bannerBytes;
  
  // Settings
  bool _isMessagingEnabled = true;

  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 4, vsync: this);
    _tabCtrl.addListener(() => setState(() {}));

    // Pre-fill if editing
    if (widget.schoolId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
    }
  }

  Future<void> _loadData() async {
    final resp =
        await ref.read(_schoolDetailProvider(widget.schoolId).future);
    if (resp == null || !mounted) return;
    final data = (resp['data'] as Map<String, dynamic>?) ?? resp;
    setState(() {
      _nameCtrl.text        = data['name']             as String? ?? '';
      _codeCtrl.text        = data['code']             as String? ?? '';
      _regNoCtrl.text       = data['affiliation_no']   as String? ?? '';
      _affiliationCtrl.text = data['affiliation_board'] as String? ?? '';
      _schoolType           = data['school_type']      as String?;
      _phoneCtrl.text       = data['phone1']           as String? ?? '';
      _altPhoneCtrl.text    = data['phone2']           as String? ?? '';
      _emailCtrl.text       = data['email']            as String? ?? '';
      _websiteCtrl.text     = data['website']          as String? ?? '';
      _principalCtrl.text   = '';
      _addressCtrl.text     = data['address_line1']    as String? ?? '';
      _cityCtrl.text        = data['city']             as String? ?? '';
      _districtCtrl.text    = '';
      _stateCtrl.text       = data['state']            as String? ?? '';
      _pinCtrl.text         = data['zip_code']         as String? ?? '';

      bool messagingEnabled = true;
      if (data['settings'] != null) {
         try {
           final settings = data['settings'] is String ? jsonDecode(data['settings']) : data['settings'];
           messagingEnabled = settings['is_messaging_enabled'] ?? true;
         } catch(_) {}
      }
      _isMessagingEnabled = messagingEnabled;
    });
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _nameCtrl.dispose();
    _codeCtrl.dispose();
    _regNoCtrl.dispose();
    _affiliationCtrl.dispose();
    _phoneCtrl.dispose();
    _altPhoneCtrl.dispose();
    _emailCtrl.dispose();
    _websiteCtrl.dispose();
    _principalCtrl.dispose();
    _addressCtrl.dispose();
    _cityCtrl.dispose();
    _districtCtrl.dispose();
    _stateCtrl.dispose();
    _pinCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickLogo() async {
    final picker = ImagePicker();
    final img    = await picker.pickImage(source: ImageSource.gallery, maxWidth: 300);
    if (img == null) return;
    final bytes = await img.readAsBytes();
    setState(() => _logoBytes = bytes);
  }

  Future<void> _pickBanner() async {
    final picker = ImagePicker();
    final img    = await picker.pickImage(source: ImageSource.gallery, maxWidth: 800);
    if (img == null) return;
    final bytes = await img.readAsBytes();
    setState(() => _bannerBytes = bytes);
  }

  Future<void> _save() async {
    final currentTab = _tabCtrl.index;

    // Tab layout: 0=Basic, 1=Branding, 2=Contact, 3=Address(submit)
    // Tabs 0-2: validate current tab fields then advance to next tab.
    if (currentTab < 3) {
      bool currentTabInvalid = false;
      if (currentTab == 0 &&
          (_nameCtrl.text.trim().isEmpty || _codeCtrl.text.trim().isEmpty)) {
        currentTabInvalid = true;
      } else if (currentTab == 2 &&
          (_phoneCtrl.text.trim().isEmpty || _emailCtrl.text.trim().isEmpty)) {
        // Contact is tab 2; Branding (tab 1) has no required fields
        currentTabInvalid = true;
      }

      if (currentTabInvalid) {
        await Future.delayed(const Duration(milliseconds: 50));
        _formKey.currentState?.validate();
        return;
      }

      _tabCtrl.animateTo(currentTab + 1);
      return;
    }

    // On Address tab (index 3): validate all required fields then submit.
    int? errorTab;
    if (_nameCtrl.text.trim().isEmpty || _codeCtrl.text.trim().isEmpty) {
      errorTab = 0; // Basic
    } else if (_phoneCtrl.text.trim().isEmpty || _emailCtrl.text.trim().isEmpty) {
      errorTab = 2; // Contact
    } else if (_addressCtrl.text.trim().isEmpty ||
        _cityCtrl.text.trim().isEmpty ||
        _stateCtrl.text.trim().isEmpty ||
        _pinCtrl.text.trim().isEmpty) {
      errorTab = 3; // Address (current tab)
    }

    if (errorTab != null) {
      _tabCtrl.animateTo(errorTab);
      await Future.delayed(const Duration(milliseconds: 100));
      _formKey.currentState?.validate();
      return;
    }

    if (!(_formKey.currentState?.validate() ?? false)) {
      _tabCtrl.animateTo(0);
      return;
    }
    setState(() => _saving = true);
    try {
      final body = {
        'name':             _nameCtrl.text.trim(),
        'code':             _codeCtrl.text.trim().toUpperCase(),
        'affiliation_no':   _regNoCtrl.text.trim(),
        'affiliation_board': _affiliationCtrl.text.trim(),
        'school_type':      _schoolType ?? 'private',
        'phone1':           _phoneCtrl.text.trim(),
        'phone2':           _altPhoneCtrl.text.trim(),
        'email':            _emailCtrl.text.trim(),
        'website':          _websiteCtrl.text.trim(),
        'address_line1':    _addressCtrl.text.trim(),
        'city':             _cityCtrl.text.trim(),
        'state':            _stateCtrl.text.trim(),
        'country':          'India',
        'zip_code':         _pinCtrl.text.trim(),
        'settings':         {'is_messaging_enabled': _isMessagingEnabled},
      };

      String createdSchoolId = widget.schoolId ?? '';
      if (widget.schoolId != null) {
        await ApiService().put('/schools/${widget.schoolId}', body: body);
      } else {
        final resp = await ApiService().post('/schools', body: body);
        final data = (resp?['data'] as Map<String, dynamic>?) ?? resp ?? {};
        createdSchoolId = data['id'] as String? ?? data['school_id'] as String? ?? '';
      }

      if (!mounted) return;

      // Refresh user role & school state
      await ref.read(authNotifierProvider.notifier).refreshUser();
      ref.invalidate(_schoolDetailProvider);

      if (!mounted) return;

      if (widget.schoolId != null) {
        // Edit mode: snackbar + pop
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('School details updated successfully'),
            backgroundColor: AppTheme.statusGreen,
          ),
        );
        Navigator.of(context).pop();
      } else {
        // Create mode: show onboarding dialog to set up first branch
        final shouldCreateBranch = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (_) => _SchoolCreatedDialog(schoolName: _nameCtrl.text.trim()),
        );
        if (!mounted) return;
        if (shouldCreateBranch == true) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => BranchSetupScreen(
                schoolId:    createdSchoolId,
                schoolName:  _nameCtrl.text.trim(),
                schoolCode:  _codeCtrl.text.trim().toUpperCase(),
                schoolPhone: _phoneCtrl.text.trim(),
                schoolEmail: _emailCtrl.text.trim(),
                schoolAddress: _addressCtrl.text.trim(),
                schoolCity:  _cityCtrl.text.trim(),
              ),
            ),
          );
        } else {
          Navigator.of(context).pop();
        }
      }
    } catch (e) {
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.error),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.schoolId != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? 'Edit School' : 'Add New School'),
        bottom: TabBar(
          controller: _tabCtrl,
          tabs: const [
            Tab(icon: Icon(Icons.info_outline, size: 18),    text: 'Basic Info'),
            Tab(icon: Icon(Icons.image_outlined, size: 18),  text: 'Branding'),
            Tab(icon: Icon(Icons.contact_phone, size: 18),   text: 'Contact'),
            Tab(icon: Icon(Icons.location_on, size: 18),     text: 'Address'),
          ],
        ),
      ),
      body: Form(
        key: _formKey,
        child: TabBarView(
          controller: _tabCtrl,
          children: [
            _BasicInfoTab(
              nameCtrl:       _nameCtrl,
              codeCtrl:       _codeCtrl,
              regNoCtrl:      _regNoCtrl,
              affiliationCtrl: _affiliationCtrl,
              schoolType:     _schoolType,
              isMessagingEnabled: _isMessagingEnabled,
              onTypeChanged:  (v) => setState(() => _schoolType = v),
              onMessagingToggle: (v) => setState(() => _isMessagingEnabled = v),
            ),
            _BrandingTab(
              logoBytes:   _logoBytes,
              bannerBytes: _bannerBytes,
              onPickLogo:  _pickLogo,
              onPickBanner: _pickBanner,
            ),
            _ContactTab(
              phoneCtrl:     _phoneCtrl,
              altPhoneCtrl:  _altPhoneCtrl,
              emailCtrl:     _emailCtrl,
              websiteCtrl:   _websiteCtrl,
              principalCtrl: _principalCtrl,
            ),
            _AddressTab(
              addressCtrl:  _addressCtrl,
              cityCtrl:     _cityCtrl,
              districtCtrl: _districtCtrl,
              stateCtrl:    _stateCtrl,
              pinCtrl:      _pinCtrl,
            ),
          ],
        ),
      ),
      bottomNavigationBar: _BottomBar(
        onSave:    _save,
        onCancel:  () => Navigator.of(context).pop(),
        saving:    _saving,
        isLastTab: _tabCtrl.index == 3,
      ),
    );
  }
}

// ── Basic Info Tab ────────────────────────────────────────────
class _BasicInfoTab extends StatelessWidget {
  final TextEditingController nameCtrl;
  final TextEditingController codeCtrl;
  final TextEditingController regNoCtrl;
  final TextEditingController affiliationCtrl;
  final String? schoolType;
  final bool isMessagingEnabled;
  final ValueChanged<String?> onTypeChanged;
  final ValueChanged<bool> onMessagingToggle;

  const _BasicInfoTab({
    required this.nameCtrl,
    required this.codeCtrl,
    required this.regNoCtrl,
    required this.affiliationCtrl,
    required this.schoolType,
    required this.isMessagingEnabled,
    required this.onTypeChanged,
    required this.onMessagingToggle,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          _F(label: 'School Name *',       controller: nameCtrl,
              validator: (v) => v == null || v.isEmpty ? 'Required' : null),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _F(
                  label: 'School Code *',
                  controller: codeCtrl,
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Required';
                    if (!RegExp(r'^[A-Z0-9]+$').hasMatch(v.toUpperCase())) {
                      return 'Alphanumeric ONLY (A-Z, 0-9)';
                    }
                    if (v.length > 20) return 'Max 20 chars';
                    return null;
                  },
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _F(label: 'Registration No.', controller: regNoCtrl),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _F(label: 'Affiliation Board',
                    controller: affiliationCtrl,
                    hint: 'CBSE / ICSE / State Board'),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: schoolType,
                  decoration: const InputDecoration(labelText: 'School Type'),
                  style: GoogleFonts.poppins(fontSize: 13, color: AppTheme.grey900),
                  items: const [
                    DropdownMenuItem(value: 'private',       child: Text('Private')),
                    DropdownMenuItem(value: 'government',    child: Text('Government')),
                    DropdownMenuItem(value: 'aided',         child: Text('Aided')),
                    DropdownMenuItem(value: 'international', child: Text('International')),
                  ],
                  onChanged: onTypeChanged,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _SectionTitle('School Preferences'),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: AppTheme.grey300),
              borderRadius: BorderRadius.circular(8),
            ),
            child: SwitchListTile(
              title: Text('Enable Parent-Teacher Messaging', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w500)),
              subtitle: Text('Allows parents to initiate structured queries within working hours.', style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.grey600)),
              value: isMessagingEnabled,
              onChanged: onMessagingToggle,
              activeColor: AppTheme.primary,
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms);
  }
}

// ── Contact Tab ───────────────────────────────────────────────
class _ContactTab extends StatelessWidget {
  final TextEditingController phoneCtrl;
  final TextEditingController altPhoneCtrl;
  final TextEditingController emailCtrl;
  final TextEditingController websiteCtrl;
  final TextEditingController principalCtrl;

  const _ContactTab({
    required this.phoneCtrl,
    required this.altPhoneCtrl,
    required this.emailCtrl,
    required this.websiteCtrl,
    required this.principalCtrl,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _F(
                  label:        'Phone *',
                  controller:   phoneCtrl,
                  keyboardType: TextInputType.phone,
                  prefixIcon:   const Icon(Icons.phone, size: 16),
                  validator:    (v) =>
                      v == null || v.isEmpty ? 'Required' : null,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _F(
                  label:        'Alternate Phone',
                  controller:   altPhoneCtrl,
                  keyboardType: TextInputType.phone,
                  prefixIcon:   const Icon(Icons.phone_outlined, size: 16),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _F(
            label:        'Official Email *',
            controller:   emailCtrl,
            keyboardType: TextInputType.emailAddress,
            prefixIcon:   const Icon(Icons.email_outlined, size: 16),
            validator:    (v) => v == null || v.isEmpty ? 'Required' : null,
          ),
          const SizedBox(height: 14),
          _F(
            label:      'Website',
            controller: websiteCtrl,
            hint:       'https://www.school.edu.in',
            prefixIcon: const Icon(Icons.language, size: 16),
          ),
          const SizedBox(height: 14),
          _F(
            label:      'Principal Name',
            controller: principalCtrl,
            prefixIcon: const Icon(Icons.person_outline, size: 16),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms);
  }
}

// ── Address Tab ───────────────────────────────────────────────
class _AddressTab extends StatelessWidget {
  final TextEditingController addressCtrl;
  final TextEditingController cityCtrl;
  final TextEditingController districtCtrl;
  final TextEditingController stateCtrl;
  final TextEditingController pinCtrl;

  const _AddressTab({
    required this.addressCtrl,
    required this.cityCtrl,
    required this.districtCtrl,
    required this.stateCtrl,
    required this.pinCtrl,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          _F(
            label:      'Street Address *',
            controller: addressCtrl,
            maxLines:   3,
            prefixIcon: const Icon(Icons.location_on_outlined, size: 16),
            validator:  (v) => v == null || v.isEmpty ? 'Required' : null,
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: _F(label: 'City *',     controller: cityCtrl,
                  validator: (v) => v == null || v.isEmpty ? 'Required' : null)),
              const SizedBox(width: 14),
              Expanded(child: _F(label: 'District', controller: districtCtrl)),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: _F(label: 'State *', controller: stateCtrl,
                  validator: (v) => v == null || v.isEmpty ? 'Required' : null)),
              const SizedBox(width: 14),
              SizedBox(
                width: 130,
                child: _F(
                  label:        'PIN Code *',
                  controller:   pinCtrl,
                  keyboardType: TextInputType.number,
                  maxLength:    6,
                  validator:    (v) => v == null || v.isEmpty ? 'Required' : null,
                ),
              ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms);
  }
}

// ── Branding Tab ──────────────────────────────────────────────
class _BrandingTab extends StatelessWidget {
  final Uint8List? logoBytes;
  final Uint8List? bannerBytes;
  final VoidCallback onPickLogo;
  final VoidCallback onPickBanner;

  const _BrandingTab({
    this.logoBytes,
    this.bannerBytes,
    required this.onPickLogo,
    required this.onPickBanner,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionTitle('School Logo'),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: onPickLogo,
            child: Container(
              width:  120,
              height: 120,
              decoration: BoxDecoration(
                color:        AppTheme.grey200,
                borderRadius: BorderRadius.circular(12),
                border:       Border.all(color: AppTheme.grey300),
                image: logoBytes != null
                    ? DecorationImage(
                        image: MemoryImage(logoBytes!),
                        fit:   BoxFit.cover)
                    : null,
              ),
              child: logoBytes == null
                  ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_photo_alternate,
                            size: 32, color: AppTheme.grey600),
                        const SizedBox(height: 6),
                        Text('Upload Logo',
                            style: GoogleFonts.poppins(
                                fontSize: 11, color: AppTheme.grey600)),
                      ],
                    )
                  : const Align(
                      alignment: Alignment.bottomRight,
                      child: Padding(
                        padding: EdgeInsets.all(4),
                        child: CircleAvatar(
                          radius: 12,
                          backgroundColor: AppTheme.primary,
                          child: Icon(Icons.edit, color: Colors.white, size: 12),
                        ),
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 24),
          _SectionTitle('School Banner / Cover Photo'),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: onPickBanner,
            child: Container(
              width:       double.infinity,
              height:      140,
              decoration: BoxDecoration(
                color:        AppTheme.grey200,
                borderRadius: BorderRadius.circular(12),
                border:       Border.all(color: AppTheme.grey300),
                image: bannerBytes != null
                    ? DecorationImage(
                        image: MemoryImage(bannerBytes!),
                        fit:   BoxFit.cover)
                    : null,
              ),
              child: bannerBytes == null
                  ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_photo_alternate,
                            size: 36, color: AppTheme.grey600),
                        const SizedBox(height: 8),
                        Text('Upload Banner (Recommended: 1200×300)',
                            style: GoogleFonts.poppins(
                                fontSize: 11, color: AppTheme.grey600)),
                      ],
                    )
                  : null,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'The school logo and banner appear on student ID cards, '
            'parent review portal, and reports.',
            style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.grey600),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms);
  }
}

// ── Shared helpers ────────────────────────────────────────────
class _F extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String? hint;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final int? maxLength;
  final int maxLines;
  final Widget? prefixIcon;

  const _F({
    required this.label,
    required this.controller,
    this.hint,
    this.validator,
    this.keyboardType,
    this.maxLength,
    this.maxLines = 1,
    this.prefixIcon,
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
        counterText: '',
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle(this.title);

  @override
  Widget build(BuildContext context) {
    return Text(title,
        style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600, fontSize: 13, color: AppTheme.grey900));
  }
}

class _BottomBar extends StatelessWidget {
  final VoidCallback onSave;
  final VoidCallback onCancel;
  final bool saving;
  final bool isLastTab;
  const _BottomBar({
    required this.onSave,
    required this.onCancel,
    required this.saving,
    required this.isLastTab,
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
          OutlinedButton(onPressed: onCancel, child: const Text('Cancel')),
          const SizedBox(width: 12),
          ElevatedButton.icon(
            onPressed: saving ? null : onSave,
            icon: saving
                ? const SizedBox(
                    width: 16, height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : Icon(isLastTab ? Icons.save : Icons.arrow_forward, size: 16),
            label: Text(saving ? 'Saving...' : (isLastTab ? 'Save School' : 'Next')),
          ),
        ],
      ),
    );
  }
}

// ── School Created Dialog ─────────────────────────────────────
class _SchoolCreatedDialog extends StatelessWidget {
  final String schoolName;
  const _SchoolCreatedDialog({required this.schoolName});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      contentPadding: const EdgeInsets.fromLTRB(24, 28, 24, 8),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64, height: 64,
            decoration: BoxDecoration(
              color: AppTheme.statusGreen.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check_circle_rounded,
                color: AppTheme.statusGreen, size: 36),
          ),
          const SizedBox(height: 16),
          Text('School Registered!',
              style: GoogleFonts.poppins(
                  fontSize: 18, fontWeight: FontWeight.w700,
                  color: AppTheme.grey900)),
          const SizedBox(height: 8),
          Text(
            '"$schoolName" has been added successfully.\nNow set up your first branch to get started.',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(fontSize: 13, color: AppTheme.grey600),
          ),
          const SizedBox(height: 24),
        ],
      ),
      actionsAlignment: MainAxisAlignment.center,
      actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
      actions: [
        OutlinedButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Done'),
        ),
        const SizedBox(width: 8),
        ElevatedButton.icon(
          onPressed: () => Navigator.of(context).pop(true),
          icon: const Icon(Icons.account_tree_outlined, size: 16),
          label: const Text('Create Branch'),
        ),
      ],
    );
  }
}
