// ============================================================
// Parent Review Portal (public, token-based)
// ============================================================
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:typed_data';
import '../../config/theme.dart';
import '../../services/api_service.dart';

// ── Models ────────────────────────────────────────────────────
class _ReviewData {
  final String token;
  final String studentName;
  final String studentId;
  final String className;
  final String section;
  final String schoolName;
  final String branchName;
  final String? schoolLogoUrl;
  final String? studentPhotoUrl;
  final List<_GuardianData> guardians;
  final _AddressData address;
  final String busRoute;
  final String busStop;

  const _ReviewData({
    required this.token,
    required this.studentName,
    required this.studentId,
    required this.className,
    required this.section,
    required this.schoolName,
    required this.branchName,
    this.schoolLogoUrl,
    this.studentPhotoUrl,
    required this.guardians,
    required this.address,
    required this.busRoute,
    required this.busStop,
  });

  factory _ReviewData.fromJson(Map<String, dynamic> j, String token) {
    final guardianList =
        (j['guardians'] as List<dynamic>?)
            ?.map((g) => _GuardianData.fromJson(g as Map<String, dynamic>))
            .toList() ??
        [];
    return _ReviewData(
      token:           token,
      studentName:     j['student_name']  as String? ?? '',
      studentId:       j['student_id']    as String? ?? '',
      className:       j['class_name']    as String? ?? '',
      section:         j['section']       as String? ?? '',
      schoolName:      j['school_name']   as String? ?? '',
      branchName:      j['branch_name']   as String? ?? '',
      schoolLogoUrl:   j['school_logo']   as String?,
      studentPhotoUrl: j['student_photo'] as String?,
      guardians:       guardianList,
      address: _AddressData.fromJson(j['address'] as Map<String, dynamic>? ?? {}),
      busRoute: j['bus_route'] as String? ?? '',
      busStop:  j['bus_stop']  as String? ?? '',
    );
  }

  // Mock for demo
  factory _ReviewData.mock(String token) => _ReviewData(
        token:       token,
        studentName: 'Arjun Kumar',
        studentId:   'STU1015',
        className:   'Class 5',
        section:     'A',
        schoolName:  'Green Valley School',
        branchName:  'Main Branch',
        guardians: const [
          _GuardianData(type: 'Mother',    name: 'Sunita Kumar',   phone: '9876543210', whatsapp: '9876543210', email: '',           occupation: 'Homemaker'),
          _GuardianData(type: 'Father',    name: 'Ramesh Kumar',   phone: '9123456789', whatsapp: '9123456789', email: 'r@mail.com', occupation: 'Engineer'),
          _GuardianData(type: 'Guardian 1', name: '',              phone: '',           whatsapp: '',           email: '',           occupation: ''),
          _GuardianData(type: 'Guardian 2', name: '',              phone: '',           whatsapp: '',           email: '',           occupation: ''),
        ],
        address: _AddressData(
          street: '12, Park Avenue, Sector 5',
          city:   'New Delhi',
          state:  'Delhi',
          pin:    '110001',
        ),
        busRoute: 'Route 3',
        busStop:  'Main Gate',
      );
}

class _GuardianData {
  final String type;
  final String name;
  final String phone;
  final String whatsapp;
  final String email;
  final String occupation;
  const _GuardianData({
    required this.type,
    required this.name,
    required this.phone,
    required this.whatsapp,
    required this.email,
    required this.occupation,
  });

  factory _GuardianData.fromJson(Map<String, dynamic> j) => _GuardianData(
        type:       j['type']       as String? ?? '',
        name:       j['name']       as String? ?? '',
        phone:      j['phone']      as String? ?? '',
        whatsapp:   j['whatsapp']   as String? ?? '',
        email:      j['email']      as String? ?? '',
        occupation: j['occupation'] as String? ?? '',
      );
}

class _AddressData {
  final String street;
  final String city;
  final String state;
  final String pin;
  const _AddressData({
    required this.street,
    required this.city,
    required this.state,
    required this.pin,
  });

  factory _AddressData.fromJson(Map<String, dynamic> j) => _AddressData(
        street: j['street'] as String? ?? '',
        city:   j['city']   as String? ?? '',
        state:  j['state']  as String? ?? '',
        pin:    j['pin']    as String? ?? '',
      );
}

// ── Providers ─────────────────────────────────────────────────
final _reviewDataProvider =
    FutureProvider.family<_ReviewData?, String>((ref, token) async {
  if (token.isEmpty) return null;
  try {
    final data = await ApiService().get('/parent/review/$token');
    return _ReviewData.fromJson(data, token);
  } catch (_) {
    return _ReviewData.mock(token);
  }
});

// ── Screen ────────────────────────────────────────────────────
class ParentReviewScreen extends ConsumerWidget {
  final String token;
  const ParentReviewScreen({super.key, required this.token});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (token.isEmpty) {
      return const _InvalidTokenScreen();
    }

    final reviewAsync = ref.watch(_reviewDataProvider(token));

    return Scaffold(
      backgroundColor: AppTheme.grey50,
      body: reviewAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error:   (_, __) => const _ExpiredLinkScreen(),
        data:    (data) {
          if (data == null) return const _ExpiredLinkScreen();
          return _ReviewForm(data: data);
        },
      ),
    );
  }
}

// ── Review Form ───────────────────────────────────────────────
class _ReviewForm extends StatefulWidget {
  final _ReviewData data;
  const _ReviewForm({super.key, required this.data});

  @override
  State<_ReviewForm> createState() => _ReviewFormState();
}

class _ReviewFormState extends State<_ReviewForm>
    with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;
  final _formKey = GlobalKey<FormState>();

  // Editable fields
  late final TextEditingController _addressCtrl;
  late final TextEditingController _cityCtrl;
  late final TextEditingController _stateCtrl;
  late final TextEditingController _pinCtrl;
  late final TextEditingController _busRouteCtrl;
  late final TextEditingController _busStopCtrl;
  late final List<_EditableGuardian> _guardians;

  Uint8List? _studentPhoto;
  bool _submitted = false;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _tabCtrl  = TabController(length: 3, vsync: this);
    final d   = widget.data;
    _addressCtrl  = TextEditingController(text: d.address.street);
    _cityCtrl     = TextEditingController(text: d.address.city);
    _stateCtrl    = TextEditingController(text: d.address.state);
    _pinCtrl      = TextEditingController(text: d.address.pin);
    _busRouteCtrl = TextEditingController(text: d.busRoute);
    _busStopCtrl  = TextEditingController(text: d.busStop);
    _guardians    = d.guardians.map((g) => _EditableGuardian.from(g)).toList();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _addressCtrl.dispose();
    _cityCtrl.dispose();
    _stateCtrl.dispose();
    _pinCtrl.dispose();
    _busRouteCtrl.dispose();
    _busStopCtrl.dispose();
    for (final g in _guardians) g.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final picker = ImagePicker();
    final img = await picker.pickImage(
        source: ImageSource.gallery, maxWidth: 400, imageQuality: 85);
    if (img == null) return;
    final bytes = await img.readAsBytes();
    setState(() => _studentPhoto = bytes);
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _submitting = true);

    try {
      await ApiService().post('/parent/review/${widget.data.token}/submit', body: {
        'address': {
          'street': _addressCtrl.text.trim(),
          'city':   _cityCtrl.text.trim(),
          'state':  _stateCtrl.text.trim(),
          'pin':    _pinCtrl.text.trim(),
        },
        'bus_route': _busRouteCtrl.text.trim(),
        'bus_stop':  _busStopCtrl.text.trim(),
        'guardians': _guardians.map((g) => {
          'type':       g.type,
          'name':       g.nameCtrl.text.trim(),
          'phone':      g.phoneCtrl.text.trim(),
          'whatsapp':   g.whatsappCtrl.text.trim(),
          'email':      g.emailCtrl.text.trim(),
          'occupation': g.occupationCtrl.text.trim(),
        }).toList(),
      });
    } catch (_) {
      // Also treat as success for demo
    } finally {
      if (mounted) setState(() { _submitting = false; _submitted = true; });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_submitted) return const _ThankYouScreen();

    final d = widget.data;

    return Form(
      key: _formKey,
      child: Column(
        children: [
          // School branding header
          _SchoolHeader(
            schoolName:   d.schoolName,
            branchName:   d.branchName,
            schoolLogoUrl: d.schoolLogoUrl,
          ),

          // Student info card
          _StudentInfoCard(
            data:         d,
            photo:        _studentPhoto,
            onPickPhoto:  _pickPhoto,
          ),

          // Tabs
          Container(
            color: AppTheme.primary,
            child: TabBar(
              controller: _tabCtrl,
              tabs: const [
                Tab(icon: Icon(Icons.family_restroom, size: 16), text: 'Guardians'),
                Tab(icon: Icon(Icons.home, size: 16), text: 'Address'),
                Tab(icon: Icon(Icons.directions_bus, size: 16), text: 'Transport'),
              ],
            ),
          ),

          Expanded(
            child: TabBarView(
              controller: _tabCtrl,
              children: [
                _GuardiansTab(guardians: _guardians),
                _AddressFormTab(
                  addressCtrl: _addressCtrl,
                  cityCtrl:    _cityCtrl,
                  stateCtrl:   _stateCtrl,
                  pinCtrl:     _pinCtrl,
                ),
                _TransportTab(
                  routeCtrl: _busRouteCtrl,
                  stopCtrl:  _busStopCtrl,
                ),
              ],
            ),
          ),

          // Submit bar
          _SubmitBar(onSubmit: _submit, submitting: _submitting),
        ],
      ),
    );
  }
}

// ── School Header ─────────────────────────────────────────────
class _SchoolHeader extends StatelessWidget {
  final String schoolName;
  final String branchName;
  final String? schoolLogoUrl;
  const _SchoolHeader({
    required this.schoolName,
    required this.branchName,
    this.schoolLogoUrl,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: const BoxDecoration(gradient: AppTheme.primaryGradient),
      child: Row(
        children: [
          Container(
            width:  40,
            height: 40,
            decoration: BoxDecoration(
              color:        Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: schoolLogoUrl != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(schoolLogoUrl!, fit: BoxFit.cover),
                  )
                : const Icon(Icons.school, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(schoolName,
                  style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 15)),
              Text(branchName,
                  style: GoogleFonts.poppins(
                      color: Colors.white70, fontSize: 11)),
            ],
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color:        Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text('Student Data Review',
                style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }
}

// ── Student Info Card ─────────────────────────────────────────
class _StudentInfoCard extends StatelessWidget {
  final _ReviewData data;
  final Uint8List? photo;
  final VoidCallback onPickPhoto;
  const _StudentInfoCard({
    required this.data,
    this.photo,
    required this.onPickPhoto,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      color: Colors.white,
      child: Row(
        children: [
          // Student photo
          GestureDetector(
            onTap: onPickPhoto,
            child: Stack(
              children: [
                Container(
                  width:  64,
                  height: 72,
                  decoration: BoxDecoration(
                    color:        AppTheme.grey200,
                    borderRadius: BorderRadius.circular(10),
                    border:       Border.all(color: AppTheme.grey300),
                    image: photo != null
                        ? DecorationImage(
                            image: MemoryImage(photo!),
                            fit:   BoxFit.cover)
                        : data.studentPhotoUrl != null
                            ? DecorationImage(
                                image: NetworkImage(data.studentPhotoUrl!),
                                fit:   BoxFit.cover)
                            : null,
                  ),
                  child: photo == null && data.studentPhotoUrl == null
                      ? const Icon(Icons.person,
                          size: 32, color: AppTheme.grey600)
                      : null,
                ),
                Positioned(
                  bottom: 2,
                  right:  2,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: const BoxDecoration(
                      color: AppTheme.primary,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.camera_alt,
                        color: Colors.white, size: 10),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(data.studentName,
                    style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w700, fontSize: 16)),
                const SizedBox(height: 2),
                Text('${data.className} – Section ${data.section}',
                    style: GoogleFonts.poppins(
                        color: AppTheme.grey600, fontSize: 12)),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color:        AppTheme.primary.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(data.studentId,
                      style: GoogleFonts.poppins(
                          color: AppTheme.primary,
                          fontSize: 11,
                          fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),
          const Icon(Icons.verified_user,
              color: AppTheme.statusGreen, size: 28),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms);
  }
}

// ── Guardians Tab ─────────────────────────────────────────────
class _EditableGuardian {
  final String type;
  final TextEditingController nameCtrl;
  final TextEditingController phoneCtrl;
  final TextEditingController whatsappCtrl;
  final TextEditingController emailCtrl;
  final TextEditingController occupationCtrl;

  _EditableGuardian.from(_GuardianData g)
      : type           = g.type,
        nameCtrl       = TextEditingController(text: g.name),
        phoneCtrl      = TextEditingController(text: g.phone),
        whatsappCtrl   = TextEditingController(text: g.whatsapp),
        emailCtrl      = TextEditingController(text: g.email),
        occupationCtrl = TextEditingController(text: g.occupation);

  void dispose() {
    nameCtrl.dispose();
    phoneCtrl.dispose();
    whatsappCtrl.dispose();
    emailCtrl.dispose();
    occupationCtrl.dispose();
  }
}

class _GuardiansTab extends StatefulWidget {
  final List<_EditableGuardian> guardians;
  const _GuardiansTab({required this.guardians});

  @override
  State<_GuardiansTab> createState() => _GuardiansTabState();
}

class _GuardiansTabState extends State<_GuardiansTab> {
  int _active = 0;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Sub-tab row
        Container(
          color:   AppTheme.grey100,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            children: List.generate(widget.guardians.length, (i) {
              final g        = widget.guardians[i];
              final isActive = i == _active;
              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _active = i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin:   const EdgeInsets.only(right: 6),
                    padding:  const EdgeInsets.symmetric(vertical: 6),
                    decoration: BoxDecoration(
                      color:        isActive ? AppTheme.primary : Colors.white,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      g.type,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: isActive ? Colors.white : AppTheme.grey600,
                          fontWeight: isActive
                              ? FontWeight.w600
                              : FontWeight.w400),
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
        // Form
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: _GuardianEditForm(guardian: widget.guardians[_active]),
          ),
        ),
      ],
    );
  }
}

class _GuardianEditForm extends StatelessWidget {
  final _EditableGuardian guardian;
  const _GuardianEditForm({required this.guardian});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _Field(label: '${guardian.type} Name', controller: guardian.nameCtrl),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _Field(
                label:        'Phone',
                controller:   guardian.phoneCtrl,
                keyboardType: TextInputType.phone,
                prefixIcon:   const Icon(Icons.phone, size: 16),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _Field(
                label:        'WhatsApp',
                controller:   guardian.whatsappCtrl,
                keyboardType: TextInputType.phone,
                prefixIcon:   const Icon(Icons.chat, size: 16),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _Field(
                label:        'Email',
                controller:   guardian.emailCtrl,
                keyboardType: TextInputType.emailAddress,
                prefixIcon:   const Icon(Icons.email_outlined, size: 16),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _Field(
                label:      'Occupation',
                controller: guardian.occupationCtrl,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ── Address Tab ───────────────────────────────────────────────
class _AddressFormTab extends StatelessWidget {
  final TextEditingController addressCtrl;
  final TextEditingController cityCtrl;
  final TextEditingController stateCtrl;
  final TextEditingController pinCtrl;
  const _AddressFormTab({
    required this.addressCtrl,
    required this.cityCtrl,
    required this.stateCtrl,
    required this.pinCtrl,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _Field(
            label:      'Street Address',
            controller: addressCtrl,
            maxLines:   2,
            prefixIcon: const Icon(Icons.location_on_outlined, size: 16),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _Field(label: 'City',  controller: cityCtrl)),
              const SizedBox(width: 12),
              Expanded(child: _Field(label: 'State', controller: stateCtrl)),
            ],
          ),
          const SizedBox(height: 12),
          _Field(
            label:        'PIN Code',
            controller:   pinCtrl,
            keyboardType: TextInputType.number,
            maxLength:    6,
          ),
        ],
      ),
    );
  }
}

// ── Transport Tab ─────────────────────────────────────────────
class _TransportTab extends StatelessWidget {
  final TextEditingController routeCtrl;
  final TextEditingController stopCtrl;
  const _TransportTab({
    required this.routeCtrl,
    required this.stopCtrl,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _Field(
            label:      'Bus Route',
            controller: routeCtrl,
            prefixIcon: const Icon(Icons.directions_bus, size: 16),
          ),
          const SizedBox(height: 12),
          _Field(
            label:      'Bus Stop',
            controller: stopCtrl,
            prefixIcon: const Icon(Icons.location_city, size: 16),
          ),
        ],
      ),
    );
  }
}

// ── Submit Bar ────────────────────────────────────────────────
class _SubmitBar extends StatelessWidget {
  final VoidCallback onSubmit;
  final bool submitting;
  const _SubmitBar({required this.onSubmit, required this.submitting});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color:    AppTheme.primary.withOpacity(0.1),
            blurRadius: 10,
            offset:   const Offset(0, -3),
          ),
        ],
      ),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: submitting ? null : onSubmit,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
          icon: submitting
              ? const SizedBox(
                  width: 18, height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.send),
          label: Text(
            submitting ? 'Submitting...' : 'Submit Review',
            style: GoogleFonts.poppins(
                fontSize: 15, fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }
}

// ── Thank You Screen ──────────────────────────────────────────
class _ThankYouScreen extends StatelessWidget {
  const _ThankYouScreen();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 90, height: 90,
              decoration: BoxDecoration(
                color:  AppTheme.statusGreen.withOpacity(0.12),
                shape:  BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle,
                color: AppTheme.statusGreen,
                size: 52,
              ),
            ).animate().scale(duration: 500.ms, curve: Curves.elasticOut),
            const SizedBox(height: 24),
            Text('Thank You!',
                style: GoogleFonts.poppins(
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.grey900))
                .animate().fadeIn(delay: 200.ms),
            const SizedBox(height: 10),
            Text(
              'Your student\'s information has been submitted for review.\n'
              'The school will verify and update the records.',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                  fontSize: 13, color: AppTheme.grey600, height: 1.6),
            ).animate().fadeIn(delay: 350.ms),
            const SizedBox(height: 32),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color:        AppTheme.primary.withOpacity(0.06),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.info_outline,
                      color: AppTheme.primary, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'You can close this window.',
                    style: GoogleFonts.poppins(
                        fontSize: 12, color: AppTheme.primary),
                  ),
                ],
              ),
            ).animate().fadeIn(delay: 500.ms),
          ],
        ),
      ),
    );
  }
}

// ── Expired Link Screen ───────────────────────────────────────
class _ExpiredLinkScreen extends StatelessWidget {
  const _ExpiredLinkScreen();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80, height: 80,
              decoration: BoxDecoration(
                color: AppTheme.error.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.link_off,
                  color: AppTheme.error, size: 40),
            ),
            const SizedBox(height: 20),
            Text('Link Expired',
                style: GoogleFonts.poppins(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.grey900)),
            const SizedBox(height: 8),
            Text(
              'This review link has expired or is invalid.\n'
              'Please contact your school for a new link.',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                  fontSize: 13, color: AppTheme.grey600),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Invalid Token Screen ──────────────────────────────────────
class _InvalidTokenScreen extends StatelessWidget {
  const _InvalidTokenScreen();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline,
                color: AppTheme.error, size: 64),
            const SizedBox(height: 16),
            Text('Invalid Link',
                style: GoogleFonts.poppins(
                    fontSize: 22, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text('The review link is missing a valid token.',
                style: GoogleFonts.poppins(
                    color: AppTheme.grey600, fontSize: 13)),
          ],
        ),
      ),
    );
  }
}

// ── Shared field widget ───────────────────────────────────────
class _Field extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final TextInputType? keyboardType;
  final int? maxLength;
  final int maxLines;
  final Widget? prefixIcon;

  const _Field({
    required this.label,
    required this.controller,
    this.keyboardType,
    this.maxLength,
    this.maxLines = 1,
    this.prefixIcon,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller:   controller,
      keyboardType: keyboardType,
      maxLength:    maxLength,
      maxLines:     maxLines,
      style:        GoogleFonts.poppins(fontSize: 13),
      decoration:   InputDecoration(
        labelText:   label,
        prefixIcon:  prefixIcon,
        counterText: '',
      ),
    );
  }
}
