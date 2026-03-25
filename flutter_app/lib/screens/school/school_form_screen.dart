// ============================================================
// School Create / Edit Form
// ============================================================
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
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
  final _shortNameCtrl    = TextEditingController();
  final _codeCtrl         = TextEditingController();
  final _regNoCtrl        = TextEditingController();
  final _affiliationCtrl  = TextEditingController();
  String? _schoolType = 'private';

  // Contact
  final _phoneCtrl        = TextEditingController();
  final _altPhoneCtrl     = TextEditingController();
  final _whatsappCtrl     = TextEditingController();
  final _emailCtrl        = TextEditingController();
  final _websiteCtrl      = TextEditingController();
  final _principalCtrl    = TextEditingController();

  // Address
  final _addressCtrl      = TextEditingController();
  final _cityCtrl         = TextEditingController();
  final _districtCtrl     = TextEditingController();
  final _stateCtrl        = TextEditingController();
  final _pinCtrl          = TextEditingController();

  // Social
  final _facebookCtrl     = TextEditingController();
  final _twitterCtrl      = TextEditingController();
  final _instagramCtrl    = TextEditingController();

  // Media
  Uint8List? _logoBytes;
  Uint8List? _bannerBytes;
  String?    _logoUrl;
  String?    _bannerUrl;
  bool       _uploadingLogo   = false;
  bool       _uploadingBanner = false;

  // Settings
  bool _isMessagingEnabled = true;

  bool _saving = false;

  // Tab indices: 0=Basic, 1=Branding, 2=Contact, 3=Address, 4=Social
  static const int _totalTabs = 5;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: _totalTabs, vsync: this);
    _tabCtrl.addListener(() => setState(() {}));

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
      _shortNameCtrl.text   = data['short_name']       as String? ?? '';
      _codeCtrl.text        = data['code']             as String? ?? '';
      _regNoCtrl.text       = data['affiliation_no']   as String? ?? '';
      _affiliationCtrl.text = data['affiliation_board'] as String? ?? '';
      _schoolType           = data['school_type']      as String?;
      _phoneCtrl.text       = data['phone1']           as String? ?? '';
      _altPhoneCtrl.text    = data['phone2']           as String? ?? '';
      _whatsappCtrl.text    = data['whatsapp_no']      as String? ?? '';
      _emailCtrl.text       = data['email']            as String? ?? '';
      _websiteCtrl.text     = data['website']          as String? ?? '';
      _principalCtrl.text   = data['principal_name']   as String? ?? '';
      _addressCtrl.text     = data['address_line1']    as String? ?? '';
      _cityCtrl.text        = data['city']             as String? ?? '';
      _districtCtrl.text    = data['district']         as String? ?? '';
      _stateCtrl.text       = data['state']            as String? ?? '';
      _pinCtrl.text         = data['zip_code']         as String? ?? '';
      _facebookCtrl.text    = data['facebook_url']     as String? ?? '';
      _twitterCtrl.text     = data['twitter_url']      as String? ?? '';
      _instagramCtrl.text   = data['instagram_url']    as String? ?? '';
      _logoUrl              = data['logo_url']         as String?;
      _bannerUrl            = data['banner_url']       as String?;

      bool messagingEnabled = true;
      if (data['settings'] != null) {
        try {
          final settings = data['settings'] is String
              ? jsonDecode(data['settings'])
              : data['settings'];
          messagingEnabled = settings['is_messaging_enabled'] ?? true;
        } catch (_) {}
      }
      _isMessagingEnabled = messagingEnabled;
    });
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _nameCtrl.dispose();
    _shortNameCtrl.dispose();
    _codeCtrl.dispose();
    _regNoCtrl.dispose();
    _affiliationCtrl.dispose();
    _phoneCtrl.dispose();
    _altPhoneCtrl.dispose();
    _whatsappCtrl.dispose();
    _emailCtrl.dispose();
    _websiteCtrl.dispose();
    _principalCtrl.dispose();
    _addressCtrl.dispose();
    _cityCtrl.dispose();
    _districtCtrl.dispose();
    _stateCtrl.dispose();
    _pinCtrl.dispose();
    _facebookCtrl.dispose();
    _twitterCtrl.dispose();
    _instagramCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickLogo() async {
    final picker = ImagePicker();
    final img    = await picker.pickImage(source: ImageSource.gallery, maxWidth: 400);
    if (img == null) return;
    final bytes = await img.readAsBytes();
    setState(() { _logoBytes = bytes; _uploadingLogo = true; });
    try {
      final resp = await ApiService().uploadFile(
        '/uploads/school-logo',
        bytes: bytes,
        fileName: 'logo.png',
        fieldName: 'logo',
      );
      final url = resp['data']?['url'] as String?;
      if (url != null && mounted) setState(() => _logoUrl = url);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Logo upload failed'), backgroundColor: AppTheme.error),
        );
      }
    } finally {
      if (mounted) setState(() => _uploadingLogo = false);
    }
  }

  Future<void> _pickBanner() async {
    final picker = ImagePicker();
    final img    = await picker.pickImage(source: ImageSource.gallery, maxWidth: 1200);
    if (img == null) return;
    final bytes = await img.readAsBytes();
    setState(() { _bannerBytes = bytes; _uploadingBanner = true; });
    try {
      final resp = await ApiService().uploadFile(
        '/uploads/school-banner',
        bytes: bytes,
        fileName: 'banner.png',
        fieldName: 'banner',
      );
      final url = resp['data']?['url'] as String?;
      if (url != null && mounted) setState(() => _bannerUrl = url);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Banner upload failed'), backgroundColor: AppTheme.error),
        );
      }
    } finally {
      if (mounted) setState(() => _uploadingBanner = false);
    }
  }

  Future<void> _save() async {
    final currentTab = _tabCtrl.index;
    final lastTab = _totalTabs - 1;

    // Tabs 0-3: validate current tab fields then advance
    if (currentTab < lastTab) {
      bool invalid = false;
      if (currentTab == 0 &&
          (_nameCtrl.text.trim().isEmpty || _codeCtrl.text.trim().isEmpty)) {
        invalid = true;
      } else if (currentTab == 2 &&
          (_phoneCtrl.text.trim().isEmpty || _emailCtrl.text.trim().isEmpty)) {
        invalid = true;
      } else if (currentTab == 3 &&
          (_addressCtrl.text.trim().isEmpty ||
           _cityCtrl.text.trim().isEmpty ||
           _stateCtrl.text.trim().isEmpty ||
           _pinCtrl.text.trim().isEmpty)) {
        invalid = true;
      }

      if (invalid) {
        await Future.delayed(const Duration(milliseconds: 50));
        _formKey.currentState?.validate();
        return;
      }

      _tabCtrl.animateTo(currentTab + 1);
      return;
    }

    // On last tab (Social): validate all required fields then submit
    int? errorTab;
    if (_nameCtrl.text.trim().isEmpty || _codeCtrl.text.trim().isEmpty) {
      errorTab = 0;
    } else if (_phoneCtrl.text.trim().isEmpty || _emailCtrl.text.trim().isEmpty) {
      errorTab = 2;
    } else if (_addressCtrl.text.trim().isEmpty ||
        _cityCtrl.text.trim().isEmpty ||
        _stateCtrl.text.trim().isEmpty ||
        _pinCtrl.text.trim().isEmpty) {
      errorTab = 3;
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

    if (_uploadingLogo || _uploadingBanner) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please wait for images to finish uploading')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final body = {
        'name':             _nameCtrl.text.trim(),
        'short_name':       _shortNameCtrl.text.trim(),
        'code':             _codeCtrl.text.trim().toUpperCase(),
        'affiliation_no':   _regNoCtrl.text.trim(),
        'affiliation_board': _affiliationCtrl.text.trim(),
        'school_type':      _schoolType ?? 'private',
        'phone1':           _phoneCtrl.text.trim(),
        'phone2':           _altPhoneCtrl.text.trim(),
        'whatsapp_no':      _whatsappCtrl.text.trim(),
        'email':            _emailCtrl.text.trim(),
        'website':          _websiteCtrl.text.trim(),
        'principal_name':   _principalCtrl.text.trim(),
        'address_line1':    _addressCtrl.text.trim(),
        'city':             _cityCtrl.text.trim(),
        'district':         _districtCtrl.text.trim(),
        'state':            _stateCtrl.text.trim(),
        'country':          'India',
        'zip_code':         _pinCtrl.text.trim(),
        'facebook_url':     _facebookCtrl.text.trim(),
        'twitter_url':      _twitterCtrl.text.trim(),
        'instagram_url':    _instagramCtrl.text.trim(),
        'settings':         {'is_messaging_enabled': _isMessagingEnabled},
        if (_logoUrl != null)   'logo_url':   _logoUrl,
        if (_bannerUrl != null) 'banner_url': _bannerUrl,
      };

      String createdSchoolId = widget.schoolId ?? '';
      if (widget.schoolId != null) {
        await ApiService().put('/schools/${widget.schoolId}', body: body);
      } else {
        final resp = await ApiService().post('/schools', body: body);
        final data = (resp['data'] as Map<String, dynamic>?) ?? {};
        createdSchoolId = data['id'] as String? ?? '';
      }

      if (!mounted) return;

      await ref.read(authNotifierProvider.notifier).refreshUser();
      ref.invalidate(_schoolDetailProvider);

      if (!mounted) return;

      if (widget.schoolId != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('School details updated successfully'),
            backgroundColor: AppTheme.statusGreen,
          ),
        );
        Navigator.of(context).pop();
      } else {
        final shouldCreateBranch = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (_) => _SchoolCreatedDialog(schoolName: _nameCtrl.text.trim()),
        );
        if (!mounted) return;
        if (shouldCreateBranch == true && createdSchoolId.isNotEmpty) {
          context.pushReplacement('/schools/setup-branch', extra: {
            'schoolId':      createdSchoolId,
            'schoolName':    _nameCtrl.text.trim(),
            'schoolCode':    _codeCtrl.text.trim().toUpperCase(),
            'schoolPhone':   _phoneCtrl.text.trim(),
            'schoolEmail':   _emailCtrl.text.trim(),
            'schoolAddress': _addressCtrl.text.trim(),
            'schoolCity':    _cityCtrl.text.trim(),
          });
        } else {
          context.go('/schools');
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
          isScrollable: true,
          tabs: const [
            Tab(icon: Icon(Icons.info_outline, size: 18),    text: 'Basic Info'),
            Tab(icon: Icon(Icons.image_outlined, size: 18),  text: 'Branding'),
            Tab(icon: Icon(Icons.contact_phone, size: 18),   text: 'Contact'),
            Tab(icon: Icon(Icons.location_on, size: 18),     text: 'Address'),
            Tab(icon: Icon(Icons.share_outlined, size: 18),  text: 'Social'),
          ],
        ),
      ),
      body: Form(
        key: _formKey,
        child: TabBarView(
          controller: _tabCtrl,
          children: [
            _BasicInfoTab(
              nameCtrl:           _nameCtrl,
              shortNameCtrl:      _shortNameCtrl,
              codeCtrl:           _codeCtrl,
              regNoCtrl:          _regNoCtrl,
              affiliationCtrl:    _affiliationCtrl,
              schoolType:         _schoolType,
              isMessagingEnabled: _isMessagingEnabled,
              onTypeChanged:      (v) => setState(() => _schoolType = v),
              onMessagingToggle:  (v) => setState(() => _isMessagingEnabled = v),
            ),
            _BrandingTab(
              logoBytes:      _logoBytes,
              bannerBytes:    _bannerBytes,
              logoUrl:        _logoUrl,
              bannerUrl:      _bannerUrl,
              uploadingLogo:  _uploadingLogo,
              uploadingBanner: _uploadingBanner,
              onPickLogo:     _pickLogo,
              onPickBanner:   _pickBanner,
            ),
            _ContactTab(
              phoneCtrl:     _phoneCtrl,
              altPhoneCtrl:  _altPhoneCtrl,
              whatsappCtrl:  _whatsappCtrl,
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
            _SocialTab(
              facebookCtrl:  _facebookCtrl,
              twitterCtrl:   _twitterCtrl,
              instagramCtrl: _instagramCtrl,
            ),
          ],
        ),
      ),
      bottomNavigationBar: _BottomBar(
        onSave:    _save,
        onCancel:  () => Navigator.of(context).pop(),
        saving:    _saving,
        isLastTab: _tabCtrl.index == _totalTabs - 1,
      ),
    );
  }
}

// ── Basic Info Tab ────────────────────────────────────────────
class _BasicInfoTab extends StatelessWidget {
  final TextEditingController nameCtrl;
  final TextEditingController shortNameCtrl;
  final TextEditingController codeCtrl;
  final TextEditingController regNoCtrl;
  final TextEditingController affiliationCtrl;
  final String? schoolType;
  final bool isMessagingEnabled;
  final ValueChanged<String?> onTypeChanged;
  final ValueChanged<bool> onMessagingToggle;

  const _BasicInfoTab({
    required this.nameCtrl,
    required this.shortNameCtrl,
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
          _F(label: 'School Name *', controller: nameCtrl,
              validator: (v) => v == null || v.isEmpty ? 'Required' : null),
          const SizedBox(height: 14),
          _F(label: 'Short Name', controller: shortNameCtrl,
              hint: 'e.g. DPS, KV, St. Marys',
              maxLength: 50),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _F(
                  label: 'School Code *',
                  controller: codeCtrl,
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Required';
                    if (!RegExp(r'^[A-Z0-9\-]+$').hasMatch(v.toUpperCase())) {
                      return 'Alphanumeric only (A-Z, 0-9, -)';
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
              title: Text('Enable Parent-Teacher Messaging',
                  style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w500)),
              subtitle: Text(
                  'Allows parents to initiate structured queries within working hours.',
                  style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.grey600)),
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
  final TextEditingController whatsappCtrl;
  final TextEditingController emailCtrl;
  final TextEditingController websiteCtrl;
  final TextEditingController principalCtrl;

  const _ContactTab({
    required this.phoneCtrl,
    required this.altPhoneCtrl,
    required this.whatsappCtrl,
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
                  validator:    (v) => v == null || v.isEmpty ? 'Required' : null,
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
            label:        'WhatsApp No.',
            controller:   whatsappCtrl,
            keyboardType: TextInputType.phone,
            prefixIcon:   const Icon(Icons.chat_outlined, size: 16),
            hint:         '+91 9XXXXXXXXX',
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
              Expanded(child: _F(label: 'City *', controller: cityCtrl,
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
  final String?    logoUrl;
  final String?    bannerUrl;
  final bool       uploadingLogo;
  final bool       uploadingBanner;
  final VoidCallback onPickLogo;
  final VoidCallback onPickBanner;

  const _BrandingTab({
    this.logoBytes,
    this.bannerBytes,
    this.logoUrl,
    this.bannerUrl,
    required this.uploadingLogo,
    required this.uploadingBanner,
    required this.onPickLogo,
    required this.onPickBanner,
  });

  ImageProvider? _logoImage() {
    if (logoBytes != null) return MemoryImage(logoBytes!);
    if (logoUrl != null && logoUrl!.isNotEmpty) return NetworkImage(logoUrl!);
    return null;
  }

  ImageProvider? _bannerImage() {
    if (bannerBytes != null) return MemoryImage(bannerBytes!);
    if (bannerUrl != null && bannerUrl!.isNotEmpty) return NetworkImage(bannerUrl!);
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final logoImg   = _logoImage();
    final bannerImg = _bannerImage();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionTitle('School Logo'),
          const SizedBox(height: 4),
          Text('Saved to: images/school/',
              style: GoogleFonts.poppins(fontSize: 10, color: AppTheme.grey600)),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: uploadingLogo ? null : onPickLogo,
            child: Stack(
              children: [
                Container(
                  width:  120,
                  height: 120,
                  decoration: BoxDecoration(
                    color:        AppTheme.grey200,
                    borderRadius: BorderRadius.circular(12),
                    border:       Border.all(color: AppTheme.grey300),
                    image: logoImg != null
                        ? DecorationImage(image: logoImg, fit: BoxFit.cover)
                        : null,
                  ),
                  child: logoImg == null
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
                      : Align(
                          alignment: Alignment.bottomRight,
                          child: Padding(
                            padding: const EdgeInsets.all(4),
                            child: CircleAvatar(
                              radius: 12,
                              backgroundColor: AppTheme.primary,
                              child: const Icon(Icons.edit, color: Colors.white, size: 12),
                            ),
                          ),
                        ),
                ),
                if (uploadingLogo)
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black38,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Center(child: CircularProgressIndicator(color: Colors.white)),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _SectionTitle('School Banner / Cover Photo'),
          const SizedBox(height: 4),
          Text('Saved to: images/school/',
              style: GoogleFonts.poppins(fontSize: 10, color: AppTheme.grey600)),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: uploadingBanner ? null : onPickBanner,
            child: Stack(
              children: [
                Container(
                  width:       double.infinity,
                  height:      140,
                  decoration: BoxDecoration(
                    color:        AppTheme.grey200,
                    borderRadius: BorderRadius.circular(12),
                    border:       Border.all(color: AppTheme.grey300),
                    image: bannerImg != null
                        ? DecorationImage(image: bannerImg, fit: BoxFit.cover)
                        : null,
                  ),
                  child: bannerImg == null
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
                      : Align(
                          alignment: Alignment.bottomRight,
                          child: Padding(
                            padding: const EdgeInsets.all(8),
                            child: CircleAvatar(
                              radius: 12,
                              backgroundColor: AppTheme.primary,
                              child: const Icon(Icons.edit, color: Colors.white, size: 12),
                            ),
                          ),
                        ),
                ),
                if (uploadingBanner)
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black38,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Center(child: CircularProgressIndicator(color: Colors.white)),
                    ),
                  ),
              ],
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

// ── Social Tab ────────────────────────────────────────────────
class _SocialTab extends StatelessWidget {
  final TextEditingController facebookCtrl;
  final TextEditingController twitterCtrl;
  final TextEditingController instagramCtrl;

  const _SocialTab({
    required this.facebookCtrl,
    required this.twitterCtrl,
    required this.instagramCtrl,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionTitle('Social Media Links'),
          const SizedBox(height: 4),
          Text('Optional — helps parents find the school online.',
              style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.grey600)),
          const SizedBox(height: 20),
          _F(
            label:      'Facebook URL',
            controller: facebookCtrl,
            hint:       'https://facebook.com/yourschool',
            prefixIcon: const Icon(Icons.facebook, size: 16),
          ),
          const SizedBox(height: 14),
          _F(
            label:      'Twitter / X URL',
            controller: twitterCtrl,
            hint:       'https://twitter.com/yourschool',
            prefixIcon: const Icon(Icons.alternate_email, size: 16),
          ),
          const SizedBox(height: 14),
          _F(
            label:      'Instagram URL',
            controller: instagramCtrl,
            hint:       'https://instagram.com/yourschool',
            prefixIcon: const Icon(Icons.photo_camera_outlined, size: 16),
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
