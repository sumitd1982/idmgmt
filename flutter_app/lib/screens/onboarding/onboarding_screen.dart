// ============================================================
// Onboarding Screen — First-time setup wizard
// Steps: School → Branch → My Profile → Roles → Invite Team
// ============================================================
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../config/theme.dart';
import '../../models/portal_theme_model.dart';
import '../../services/api_service.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  int _step = 0;
  bool _saving = false;
  String? _schoolId;
  String? _branchId;

  // Step 0 — School Details
  final _schoolNameCtrl   = TextEditingController();
  final _schoolCodeCtrl   = TextEditingController();
  final _schoolEmailCtrl  = TextEditingController();
  final _schoolPhoneCtrl  = TextEditingController();
  final _schoolAddressCtrl = TextEditingController();
  final _schoolCityCtrl   = TextEditingController();
  final _schoolStateCtrl  = TextEditingController();
  String _schoolType = 'private';

  // Step 1 — Branch Details
  final _branchNameCtrl  = TextEditingController();
  final _branchCodeCtrl  = TextEditingController();
  final _branchPhoneCtrl = TextEditingController();
  final _branchCityCtrl  = TextEditingController();

  // Step 2 — My Profile
  final _myNameCtrl  = TextEditingController();
  final _myEmpIdCtrl = TextEditingController();
  final _myPhoneCtrl = TextEditingController();
  int _myRoleLevel = 1;

  // Step 3 — Roles
  final List<_RoleConfig> _roles = [
    _RoleConfig(level: 1, name: 'Principal',      code: 'principal',     canApprove: true,  canBulk: true),
    _RoleConfig(level: 2, name: 'Vice Principal',  code: 'vp',            canApprove: true,  canBulk: true),
    _RoleConfig(level: 3, name: 'Head Teacher',    code: 'head_teacher',  canApprove: true,  canBulk: false),
    _RoleConfig(level: 4, name: 'Senior Teacher',  code: 'senior_teacher',canApprove: false, canBulk: false),
    _RoleConfig(level: 5, name: 'Class Teacher',   code: 'class_teacher', canApprove: false, canBulk: false),
    _RoleConfig(level: 6, name: 'Subject Teacher', code: 'subject_teacher',canApprove: false,canBulk: false),
  ];

  // Step 2 — Theme selection
  PortalTheme _selectedTheme = PortalThemes.classicIndigo;
  AppLayout _selectedLayout  = AppLayout.modern;

  // Step 4 — Invites (now step 5)
  final List<TextEditingController> _invitePhoneCtrls = [
    TextEditingController(),
  ];
  final List<int> _inviteLevels = [5];

  static const _steps = [
    'School Details',
    'Branch Details',
    'Choose Theme',
    'My Profile',
    'Define Roles',
    'Invite Team',
  ];

  @override
  void dispose() {
    _schoolNameCtrl.dispose();
    _schoolCodeCtrl.dispose();
    _schoolEmailCtrl.dispose();
    _schoolPhoneCtrl.dispose();
    _schoolAddressCtrl.dispose();
    _schoolCityCtrl.dispose();
    _schoolStateCtrl.dispose();
    _branchNameCtrl.dispose();
    _branchCodeCtrl.dispose();
    _branchPhoneCtrl.dispose();
    _branchCityCtrl.dispose();
    _myNameCtrl.dispose();
    _myEmpIdCtrl.dispose();
    _myPhoneCtrl.dispose();
    for (final c in _invitePhoneCtrls) c.dispose();
    super.dispose();
  }

  Future<void> _next() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      switch (_step) {
        case 0: await _saveSchool(); break;
        case 1: await _saveBranch(); break;
        case 2: await _saveTheme(); break;
        case 3: await _saveProfile(); break;
        case 4: await _saveRoles(); break;
        case 5: await _sendInvites(); break;
      }
      if (_step < _steps.length - 1) {
        setState(() => _step++);
      } else {
        if (mounted) context.go('/dashboard');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.error),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _saveSchool() async {
    if (_schoolNameCtrl.text.trim().isEmpty) throw 'School name is required';
    if (_schoolCodeCtrl.text.trim().isEmpty) throw 'School code is required';
    final resp = await ApiService().post('/schools', body: {
      'name':         _schoolNameCtrl.text.trim(),
      'code':         _schoolCodeCtrl.text.trim(),
      'email':        _schoolEmailCtrl.text.trim(),
      'phone1':       _schoolPhoneCtrl.text.trim(),
      'address_line1': _schoolAddressCtrl.text.trim(),
      'city':         _schoolCityCtrl.text.trim(),
      'state':        _schoolStateCtrl.text.trim(),
      'school_type':  _schoolType,
      'country':      'India',
      'zip_code':     '000000',
    });
    _schoolId = (resp['data'] as Map?)?['id'] as String?;
  }

  Future<void> _saveBranch() async {
    if (_schoolId == null) return;
    if (_branchNameCtrl.text.trim().isEmpty) throw 'Branch name is required';
    if (_branchCodeCtrl.text.trim().isEmpty) throw 'Branch code is required';
    final resp = await ApiService().post('/branches', body: {
      'school_id':    _schoolId,
      'name':         _branchNameCtrl.text.trim(),
      'code':         _branchCodeCtrl.text.trim(),
      'phone1':       _branchPhoneCtrl.text.trim(),
      'city':         _branchCityCtrl.text.trim(),
      'address_line1': '',
      'zip_code':     '000000',
      'email':        '',
    });
    _branchId = (resp['data'] as Map?)?['id'] as String?;
  }

  Future<void> _saveTheme() async {
    // Save theme selection to the school's settings and user preferences
    if (_schoolId != null) {
      await ApiService().put('/schools/$_schoolId', body: {
        'settings': {
          'portal_theme_id': _selectedTheme.id,
          'portal_layout': _selectedLayout.name,
        },
      });
    }
    await ApiService().put('/users/preferences', body: {
      'portal_theme_id': _selectedTheme.id,
      'layout': _selectedLayout.name,
    });
  }

  Future<void> _saveProfile() async {
    if (_myNameCtrl.text.trim().isEmpty) throw 'Your name is required';
    final parts = _myNameCtrl.text.trim().split(' ');
    await ApiService().post('/employees', body: {
      'school_id':    _schoolId,
      'branch_id':    _branchId,
      'first_name':   parts.first,
      'last_name':    parts.length > 1 ? parts.sublist(1).join(' ') : '',
      'employee_id':  _myEmpIdCtrl.text.trim().isEmpty ? 'EMP001' : _myEmpIdCtrl.text.trim(),
      'phone':        _myPhoneCtrl.text.trim(),
      'role_level':   _myRoleLevel,
    });
  }

  Future<void> _saveRoles() async {
    if (_schoolId == null) return;
    // Roles are auto-created by the backend when school is created.
    // This step lets user review/confirm — no additional API call needed.
    // If user modified role names, update them.
    for (final role in _roles) {
      if (role.nameChanged) {
        try {
          // Find the role by code and update name
          final roles = await ApiService().get('/org/roles', params: {'school_id': _schoolId});
          final list = (roles['data'] as List? ?? []);
          final match = list.firstWhere(
            (r) => (r as Map)['code'] == role.code,
            orElse: () => null,
          );
          if (match != null) {
            await ApiService().put('/org/roles/${match['id']}', body: {
              'name':           role.name,
              'can_approve':    role.canApprove ? 1 : 0,
              'can_upload_bulk': role.canBulk ? 1 : 0,
            });
          }
        } catch (_) {}
      }
    }
  }

  Future<void> _sendInvites() async {
    if (_schoolId == null) return;
    for (var i = 0; i < _invitePhoneCtrls.length; i++) {
      final phone = _invitePhoneCtrls[i].text.trim();
      if (phone.isEmpty) continue;
      try {
        await ApiService().post('/invites', body: {
          'phone':      phone,
          'school_id':  _schoolId,
          'role_level': _inviteLevels[i],
        });
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.grey50,
      body: Row(
        children: [
          // Left progress panel
          if (MediaQuery.of(context).size.width > 700)
            Container(
              width: 260,
              color: AppTheme.primary,
              padding: const EdgeInsets.all(32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 20),
                  Container(
                    width: 48, height: 48,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.school, color: Colors.white, size: 28),
                  ),
                  const SizedBox(height: 20),
                  Text('Setup Wizard',
                    style: GoogleFonts.poppins(
                      color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  Text('Complete these steps to get started',
                    style: GoogleFonts.poppins(
                      color: Colors.white.withOpacity(0.8), fontSize: 12)),
                  const SizedBox(height: 40),
                  ...List.generate(_steps.length, (i) {
                    final done    = i < _step;
                    final current = i == _step;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 20),
                      child: Row(
                        children: [
                          Container(
                            width: 32, height: 32,
                            decoration: BoxDecoration(
                              color: done
                                  ? AppTheme.statusGreen
                                  : current
                                      ? Colors.white
                                      : Colors.white.withOpacity(0.2),
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: done
                                  ? const Icon(Icons.check, color: Colors.white, size: 16)
                                  : Text('${i + 1}',
                                      style: GoogleFonts.poppins(
                                        color: current ? AppTheme.primary : Colors.white.withOpacity(0.7),
                                        fontWeight: FontWeight.w700, fontSize: 13)),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(_steps[i],
                            style: GoogleFonts.poppins(
                              color: current
                                  ? Colors.white
                                  : done
                                      ? Colors.white.withOpacity(0.9)
                                      : Colors.white.withOpacity(0.5),
                              fontWeight: current ? FontWeight.w600 : FontWeight.w400,
                              fontSize: 13,
                            )),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),

          // Right content
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(40),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Step ${_step + 1} of ${_steps.length}',
                        style: GoogleFonts.poppins(
                          color: AppTheme.primary, fontSize: 12, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      Text(_steps[_step],
                        style: GoogleFonts.poppins(
                          fontSize: 26, fontWeight: FontWeight.w800, color: AppTheme.grey900)),
                      const SizedBox(height: 4),
                      Text(_stepSubtitle(_step),
                        style: GoogleFonts.poppins(fontSize: 14, color: AppTheme.grey600)),
                      const SizedBox(height: 32),

                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        child: KeyedSubtree(
                          key: ValueKey(_step),
                          child: _buildStep(_step),
                        ),
                      ),

                      const SizedBox(height: 32),
                      Row(
                        children: [
                          if (_step > 0)
                            OutlinedButton(
                              onPressed: _saving ? null : () => setState(() => _step--),
                              child: const Text('Back'),
                            ),
                          const Spacer(),
                          if (_step == 5) // Last step — allow skip invites
                            TextButton(
                              onPressed: _saving ? null : () => context.go('/dashboard'),
                              child: const Text('Skip & Finish'),
                            ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: _saving ? null : _next,
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                            ),
                            child: _saving
                                ? const SizedBox(width: 18, height: 18,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : Text(_step < _steps.length - 1 ? 'Save & Continue' : 'Finish Setup'),
                          ),
                        ],
                      ),
                    ],
                  ).animate().fadeIn().slideY(begin: 0.05),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _stepSubtitle(int step) {
    switch (step) {
      case 0: return 'Enter your school\'s basic information';
      case 1: return 'Set up your first branch or campus';
      case 2: return 'Pick a look for your portal — you can change this later in Settings';
      case 3: return 'Tell us about yourself (the admin)';
      case 4: return 'Review and customise staff role permissions';
      case 5: return 'Invite teachers and staff to join';
      default: return '';
    }
  }

  Widget _buildStep(int step) {
    switch (step) {
      case 0: return _buildSchoolStep();
      case 1: return _buildBranchStep();
      case 2: return _buildThemeStep();
      case 3: return _buildProfileStep();
      case 4: return _buildRolesStep();
      case 5: return _buildInvitesStep();
      default: return const SizedBox.shrink();
    }
  }

  Widget _buildSchoolStep() {
    return Column(children: [
      _Field(ctrl: _schoolNameCtrl,    label: 'School Name *',       hint: 'e.g. Green Valley Public School'),
      _Field(ctrl: _schoolCodeCtrl,    label: 'School Code *',       hint: 'e.g. GVPS'),
      _Field(ctrl: _schoolEmailCtrl,   label: 'Official Email',      hint: 'school@example.com', keyboard: TextInputType.emailAddress),
      _Field(ctrl: _schoolPhoneCtrl,   label: 'Phone Number',        hint: '9800000000',          keyboard: TextInputType.phone),
      _Field(ctrl: _schoolAddressCtrl, label: 'Address',             hint: '123, Main Street'),
      Row(children: [
        Expanded(child: _Field(ctrl: _schoolCityCtrl,  label: 'City',  hint: 'Delhi')),
        const SizedBox(width: 12),
        Expanded(child: _Field(ctrl: _schoolStateCtrl, label: 'State', hint: 'Delhi')),
      ]),
      const SizedBox(height: 4),
      DropdownButtonFormField<String>(
        value: _schoolType,
        decoration: _inputDeco('School Type'),
        items: const [
          DropdownMenuItem(value: 'government',    child: Text('Government')),
          DropdownMenuItem(value: 'private',       child: Text('Private')),
          DropdownMenuItem(value: 'aided',         child: Text('Aided')),
          DropdownMenuItem(value: 'international', child: Text('International')),
        ],
        onChanged: (v) => setState(() => _schoolType = v ?? 'private'),
      ),
    ]);
  }

  Widget _buildBranchStep() {
    return Column(children: [
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.primary.withOpacity(0.05),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppTheme.primary.withOpacity(0.2)),
        ),
        child: Row(children: [
          const Icon(Icons.info_outline, color: AppTheme.primary, size: 16),
          const SizedBox(width: 8),
          Expanded(child: Text(
            'You can add more branches later from Settings.',
            style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.primary),
          )),
        ]),
      ),
      const SizedBox(height: 16),
      _Field(ctrl: _branchNameCtrl,  label: 'Branch Name *', hint: 'Main Campus'),
      _Field(ctrl: _branchCodeCtrl,  label: 'Branch Code *', hint: 'MAIN'),
      _Field(ctrl: _branchPhoneCtrl, label: 'Branch Phone',  hint: '9800000001', keyboard: TextInputType.phone),
      _Field(ctrl: _branchCityCtrl,  label: 'City',          hint: 'Delhi'),
    ]);
  }

  Widget _buildThemeStep() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Theme grid
      Text('Portal Theme', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.grey800)),
      const SizedBox(height: 10),
      GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 0.85,
        ),
        itemCount: PortalThemes.all.length,
        itemBuilder: (_, i) {
          final theme = PortalThemes.all[i];
          final sel = theme.id == _selectedTheme.id;
          return GestureDetector(
            onTap: () => setState(() => _selectedTheme = theme),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: sel ? theme.primaryColor : AppTheme.grey200, width: sel ? 2.5 : 1),
                boxShadow: sel ? [BoxShadow(color: theme.primaryColor.withOpacity(0.2), blurRadius: 10)] : [],
              ),
              child: Column(children: [
                Expanded(child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(11)),
                  child: _ThemeMiniPreview(theme: theme),
                )),
                Padding(
                  padding: const EdgeInsets.all(6),
                  child: Row(children: [
                    Expanded(child: Text(theme.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(fontSize: 10, fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                        color: sel ? theme.primaryColor : AppTheme.grey700))),
                    if (sel) Icon(Icons.check_circle, size: 14, color: theme.primaryColor),
                  ]),
                ),
              ]),
            ),
          );
        },
      ),
      const SizedBox(height: 24),
      // Layout row
      Text('Layout', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.grey800)),
      const SizedBox(height: 10),
      Row(children: AppLayout.values.map((l) {
        final sel = l == _selectedLayout;
        return Expanded(child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: GestureDetector(
            onTap: () => setState(() => _selectedLayout = l),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: sel ? AppTheme.primary.withOpacity(0.07) : Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: sel ? AppTheme.primary : AppTheme.grey200, width: sel ? 2 : 1),
              ),
              child: Column(children: [
                Icon(l.icon, size: 22, color: sel ? AppTheme.primary : AppTheme.grey400),
                const SizedBox(height: 4),
                Text(l.label, textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(fontSize: 10, fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                    color: sel ? AppTheme.primary : AppTheme.grey600)),
              ]),
            ),
          ),
        ));
      }).toList()),
    ]);
  }

  Widget _buildProfileStep() {
    return Column(children: [
      _Field(ctrl: _myNameCtrl,  label: 'Your Full Name *', hint: 'e.g. Rajesh Kumar'),
      _Field(ctrl: _myEmpIdCtrl, label: 'Employee ID',      hint: 'EMP001'),
      _Field(ctrl: _myPhoneCtrl, label: 'Mobile Number',    hint: '9800000000', keyboard: TextInputType.phone),
      const SizedBox(height: 4),
      DropdownButtonFormField<int>(
        value: _myRoleLevel,
        decoration: _inputDeco('Your Role'),
        items: const [
          DropdownMenuItem(value: 1, child: Text('Principal')),
          DropdownMenuItem(value: 2, child: Text('Vice Principal')),
          DropdownMenuItem(value: 3, child: Text('Head Teacher')),
        ],
        onChanged: (v) => setState(() => _myRoleLevel = v ?? 1),
      ),
    ]);
  }

  Widget _buildRolesStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('These roles will be auto-created for your school. You can customise names and permissions.',
          style: GoogleFonts.poppins(fontSize: 13, color: AppTheme.grey600)),
        const SizedBox(height: 16),
        ..._roles.map((r) => _RoleRow(
          role: r,
          onChanged: () => setState(() {}),
        )),
      ],
    );
  }

  Widget _buildInvitesStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Send invite links via SMS to your staff. They can sign in with OTP.',
          style: GoogleFonts.poppins(fontSize: 13, color: AppTheme.grey600)),
        const SizedBox(height: 16),
        ...List.generate(_invitePhoneCtrls.length, (i) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(children: [
            Expanded(
              flex: 3,
              child: TextFormField(
                controller: _invitePhoneCtrls[i],
                keyboardType: TextInputType.phone,
                decoration: _inputDeco('Phone Number').copyWith(
                  prefixText: '+91 ',
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: DropdownButtonFormField<int>(
                value: _inviteLevels[i],
                decoration: _inputDeco('Role'),
                items: const [
                  DropdownMenuItem(value: 1, child: Text('Principal')),
                  DropdownMenuItem(value: 2, child: Text('Vice Principal')),
                  DropdownMenuItem(value: 3, child: Text('Head Teacher')),
                  DropdownMenuItem(value: 4, child: Text('Sr. Teacher')),
                  DropdownMenuItem(value: 5, child: Text('Class Teacher')),
                  DropdownMenuItem(value: 6, child: Text('Subject Teacher')),
                ],
                onChanged: (v) => setState(() => _inviteLevels[i] = v ?? 5),
              ),
            ),
            IconButton(
              onPressed: _invitePhoneCtrls.length > 1
                  ? () => setState(() {
                        _invitePhoneCtrls.removeAt(i);
                        _inviteLevels.removeAt(i);
                      })
                  : null,
              icon: Icon(Icons.remove_circle_outline,
                color: _invitePhoneCtrls.length > 1 ? AppTheme.error : AppTheme.grey300),
            ),
          ]),
        )),
        TextButton.icon(
          onPressed: () => setState(() {
            _invitePhoneCtrls.add(TextEditingController());
            _inviteLevels.add(5);
          }),
          icon: const Icon(Icons.add, size: 16),
          label: const Text('Add another person'),
        ),
      ],
    );
  }

  InputDecoration _inputDeco(String label) => InputDecoration(
    labelText: label,
    labelStyle: GoogleFonts.poppins(fontSize: 13, color: AppTheme.grey600),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
  );
}

// ── Theme Mini Preview (used in onboarding theme step) ────────
class _ThemeMiniPreview extends StatelessWidget {
  final PortalTheme theme;
  const _ThemeMiniPreview({required this.theme});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: theme.bodyColor,
      child: Column(children: [
        Container(height: 16, color: theme.headerColor,
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Row(children: [
            Container(width: 5, height: 5, decoration: BoxDecoration(color: Colors.white.withOpacity(0.7), shape: BoxShape.circle)),
            const SizedBox(width: 3),
            Expanded(child: Container(height: 3, decoration: BoxDecoration(color: Colors.white.withOpacity(0.3), borderRadius: BorderRadius.circular(2)))),
          ]),
        ),
        Expanded(child: Row(children: [
          Container(width: 18, color: theme.menuColor,
            padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 2),
            child: Column(children: [
              for (int i = 0; i < 4; i++) ...[
                Container(height: 3, decoration: BoxDecoration(color: i == 0 ? theme.accentColor : Colors.white.withOpacity(0.3), borderRadius: BorderRadius.circular(1))),
                const SizedBox(height: 3),
              ],
            ]),
          ),
          Expanded(child: Padding(
            padding: const EdgeInsets.all(3),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(height: 4, width: 30, decoration: BoxDecoration(color: theme.primaryColor.withOpacity(0.7), borderRadius: BorderRadius.circular(1))),
              const SizedBox(height: 3),
              Row(children: [
                Expanded(child: Container(height: 14, decoration: BoxDecoration(color: theme.cardColor, borderRadius: BorderRadius.circular(2), border: Border.all(color: Colors.black.withOpacity(0.05))))),
                const SizedBox(width: 2),
                Expanded(child: Container(height: 14, decoration: BoxDecoration(color: theme.cardColor, borderRadius: BorderRadius.circular(2), border: Border.all(color: Colors.black.withOpacity(0.05))))),
              ]),
            ]),
          )),
        ])),
        Container(height: 6, color: theme.footerColor),
      ]),
    );
  }
}

// ── Role Config ───────────────────────────────────────────────
class _RoleConfig {
  String name;
  final String code;
  final int level;
  bool canApprove;
  bool canBulk;
  bool nameChanged = false;

  _RoleConfig({
    required this.level,
    required this.name,
    required this.code,
    required this.canApprove,
    required this.canBulk,
  });
}

class _RoleRow extends StatefulWidget {
  final _RoleConfig role;
  final VoidCallback onChanged;
  const _RoleRow({required this.role, required this.onChanged});

  @override
  State<_RoleRow> createState() => _RoleRowState();
}

class _RoleRowState extends State<_RoleRow> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.role.name);
    _ctrl.addListener(() {
      widget.role.name = _ctrl.text;
      widget.role.nameChanged = true;
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final levelColors = [
      const Color(0xFFFFD700),
      const Color(0xFFC0C0C0),
      const Color(0xFFCD7F32),
      AppTheme.primary,
      AppTheme.secondary,
      AppTheme.accent,
    ];
    final color = levelColors[(widget.role.level - 1).clamp(0, 5)];

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.grey200),
      ),
      child: Row(children: [
        Container(
          width: 28, height: 28,
          decoration: BoxDecoration(color: color.withOpacity(0.15), shape: BoxShape.circle),
          child: Center(
            child: Text('L${widget.role.level}',
              style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w700, color: color)),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: TextFormField(
            controller: _ctrl,
            style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w500),
            decoration: const InputDecoration(
              isDense: true,
              border: InputBorder.none,
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ),
        // Can Approve toggle
        Tooltip(
          message: 'Can Approve',
          child: InkWell(
            onTap: () => setState(() => widget.role.canApprove = !widget.role.canApprove),
            borderRadius: BorderRadius.circular(6),
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.check_circle,
                  size: 16,
                  color: widget.role.canApprove ? AppTheme.statusGreen : AppTheme.grey300),
                const SizedBox(width: 3),
                Text('Approve',
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    color: widget.role.canApprove ? AppTheme.statusGreen : AppTheme.grey600)),
              ]),
            ),
          ),
        ),
        const SizedBox(width: 8),
        // Bulk upload toggle
        Tooltip(
          message: 'Bulk Upload',
          child: InkWell(
            onTap: () => setState(() => widget.role.canBulk = !widget.role.canBulk),
            borderRadius: BorderRadius.circular(6),
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.upload_file,
                  size: 16,
                  color: widget.role.canBulk ? AppTheme.primary : AppTheme.grey300),
                const SizedBox(width: 3),
                Text('Bulk',
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    color: widget.role.canBulk ? AppTheme.primary : AppTheme.grey600)),
              ]),
            ),
          ),
        ),
      ]),
    );
  }
}

// ── Shared field widget ───────────────────────────────────────
class _Field extends StatelessWidget {
  final TextEditingController ctrl;
  final String label;
  final String hint;
  final TextInputType keyboard;
  const _Field({
    required this.ctrl,
    required this.label,
    required this.hint,
    this.keyboard = TextInputType.text,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller: ctrl,
        keyboardType: keyboard,
        style: GoogleFonts.poppins(fontSize: 14),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          hintStyle: GoogleFonts.poppins(color: AppTheme.grey600, fontSize: 13),
          labelStyle: GoogleFonts.poppins(fontSize: 13, color: AppTheme.grey600),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
      ),
    );
  }
}
