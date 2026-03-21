// ============================================================
// Login Screen — rebuilt from scratch
// Google Sign-In + Phone OTP via MSG91
// ============================================================
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:responsive_framework/responsive_framework.dart';
import '../../config/theme.dart';
import '../../config/constants.dart';
import '../../providers/auth_provider.dart';

// ── Login flow states ────────────────────────────────────────
enum _Step { method, phone, otp }

class LoginScreen extends ConsumerStatefulWidget {
  final String portalType;
  const LoginScreen({super.key, required this.portalType});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with SingleTickerProviderStateMixin {
  _Step _step = _Step.method;
  final _phoneCtrl = TextEditingController();
  final _focusNodes = List.generate(6, (_) => FocusNode());
  final _otpCtrls = List.generate(6, (_) => TextEditingController());
  bool _loading = false;
  String? _error;
  String? _pendingPhone; // full phone used to send OTP
  late AnimationController _bgAnim;

  @override
  void initState() {
    super.initState();
    _bgAnim = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _bgAnim.dispose();
    _phoneCtrl.dispose();
    for (final c in _otpCtrls) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  // ── Helpers ────────────────────────────────────────────────
  void _setError(String? e) => setState(() => _error = e);
  void _clearOtp() {
    for (final c in _otpCtrls) {
      c.clear();
    }
    _focusNodes.first.requestFocus();
  }

  String get _otpValue => _otpCtrls.map((c) => c.text).join();

  Future<void> _navigateAfterLogin() async {
    if (!mounted) return;
    final user = ref.read(authNotifierProvider).valueOrNull;
    if (user == null) return;

    bool isBlocked = false;
    String errorMessage = '';

    if (widget.portalType == 'staff') {
      if (user.role == 'viewer' || user.role == 'parent' || user.role == 'student') {
        isBlocked = true;
        errorMessage = 'Your number is not registered as Staff. Please contact your administrator.';
      }
    } else if (widget.portalType == 'parent') {
      if (user.role != 'parent') {
        isBlocked = true;
        errorMessage = 'This number is not registered as a Parent. Please contact your administrator.';
      }
    } else if (widget.portalType == 'superadmin') {
      if (user.role != 'super_admin') {
        isBlocked = true;
        errorMessage = 'Unauthorized. This console is restricted.';
      }
    } 

    if (isBlocked) {
      await ref.read(authNotifierProvider.notifier).signOut();
      if (!mounted) return;
      setState(() => _error = errorMessage);
      return;
    }

    context.go(user.needsOnboarding ? '/onboarding' : '/dashboard');
  }

  String get _title {
    switch (widget.portalType) {
      case 'parent': return 'Parent Portal 👋';
      case 'register': return 'Register School 🏫';
      case 'superadmin': return 'System Console 🛡️';
      default: return 'Staff Portal 👋';
    }
  }

  String get _subtitle {
    switch (widget.portalType) {
      case 'parent': return 'Track your child’s ID and view school updates.';
      case 'register': return 'Set up a new institution on SchoolID Pro.';
      case 'superadmin': return 'Unrestricted system-wide access.';
      default: return 'Sign in to manage your school operations.';
    }
  }

  // ── Actions ────────────────────────────────────────────────
  Future<void> _signInGoogle() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      debugPrint('[LOGIN] Google sign-in started');
      await ref.read(authNotifierProvider.notifier).signInWithGoogle();
      debugPrint('[LOGIN] Google sign-in success');
      await _navigateAfterLogin();
    } catch (e) {
      debugPrint('[LOGIN] Google sign-in failed: $e');
      _setError(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _sendOtp() async {
    final raw = _phoneCtrl.text.trim();
    if (raw.length < 10) {
      _setError('Enter a valid 10-digit phone number');
      return;
    }
    final full = raw.startsWith('+') ? raw : '+91$raw';
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      debugPrint('[LOGIN] Sending OTP to $full');
      await ref.read(authServiceProvider).sendOtp(full);
      debugPrint('[LOGIN] OTP sent successfully to $full');
      _pendingPhone = raw; // store without country code for display
      setState(() {
        _step = _Step.otp;
        _loading = false;
      });
    } catch (e) {
      debugPrint('[LOGIN] OTP send failed: $e');
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  Future<void> _verifyOtp() async {
    final otp = _otpValue;
    if (otp.length < 6) {
      _setError('Enter all 6 digits');
      return;
    }
    final raw = _pendingPhone!;
    final full = raw.startsWith('+') ? raw : '+91$raw';
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      debugPrint('[LOGIN] Verifying OTP — phone: $full, otp: $otp');
      await ref.read(authNotifierProvider.notifier).signInWithPhone(full, otp);
      final user = ref.read(authNotifierProvider).valueOrNull;
      debugPrint('[LOGIN] OTP verify SUCCESS — userId: ${user?.id}, '
          'role: ${user?.role}, needsOnboarding: ${user?.needsOnboarding}');
      await _navigateAfterLogin();
    } catch (e) {
      debugPrint('[LOGIN] OTP verify FAILED — $e');
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
      _clearOtp();
    }
  }

  Future<void> _resendOtp() async {
    _clearOtp();
    _setError(null);
    await _sendOtp();
  }

  // ── Build ──────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveBreakpoints.of(context).smallerThan(TABLET);

    if (isMobile) return _buildMobile();
    return _buildDesktop();
  }

  Widget _buildDesktop() {
    return Scaffold(
      backgroundColor: const Color(0xFF06070F),
      body: Row(
        children: [
          // Left brand panel
          Expanded(
            flex: 5,
            child: _BrandPanel(bgAnim: _bgAnim),
          ),
          // Right form panel
          Expanded(
            flex: 4,
            child: Container(
              color: const Color(0xFF0D0F1A),
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(40),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: _buildForm(),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobile() {
    return Scaffold(
      backgroundColor: const Color(0xFF06070F),
      body: Stack(
        children: [
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _bgAnim,
              builder: (_, __) {
                final t = _bgAnim.value;
                return Stack(children: [
                  Positioned(
                    top: -60 + 30 * t,
                    left: -40 + 20 * t,
                    child: _GlowBlob(280, const Color(0xFF1A237E), 0.45),
                  ),
                  Positioned(
                    bottom: 80 + 20 * t,
                    right: -40 + 20 * t,
                    child: _GlowBlob(240, const Color(0xFF006064), 0.35),
                  ),
                ]);
              },
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                  horizontal: 24, vertical: 32),
              child: Column(
                children: [
                  // Mini brand header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          gradient: AppTheme.heroGradient,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.school_rounded,
                            color: Colors.white, size: 24),
                      ),
                      const SizedBox(width: 12),
                      Text(AppConstants.appName,
                          style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w700)),
                    ],
                  ),
                  const SizedBox(height: 40),
                  _buildForm(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Animated form switcher ──────────────────────────────────
  Widget _buildForm() {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 350),
      transitionBuilder: (child, anim) => FadeTransition(
        opacity: anim,
        child: SlideTransition(
          position: Tween<Offset>(
                  begin: const Offset(0.04, 0), end: Offset.zero)
              .animate(anim),
          child: child,
        ),
      ),
      child: switch (_step) {
        _Step.method => _MethodStep(
            key: const ValueKey('method'),
            portalType: widget.portalType,
            title: _title,
            subtitle: _subtitle,
            loading: _loading,
            error: _error,
            onGoogle: _signInGoogle,
            onPhone: () => setState(() {
              _step = _Step.phone;
              _error = null;
            }),
          ),
        _Step.phone => _PhoneStep(
            key: const ValueKey('phone'),
            controller: _phoneCtrl,
            loading: _loading,
            error: _error,
            onSend: _sendOtp,
            onBack: () => setState(() {
              _step = _Step.method;
              _error = null;
            }),
          ),
        _Step.otp => _OtpStep(
            key: const ValueKey('otp'),
            phone: _pendingPhone ?? '',
            ctrls: _otpCtrls,
            focusNodes: _focusNodes,
            loading: _loading,
            error: _error,
            onVerify: _verifyOtp,
            onResend: _resendOtp,
            onBack: () => setState(() {
              _step = _Step.phone;
              _error = null;
              _clearOtp();
            }),
          ),
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────
// BRAND PANEL (desktop left side)
// ─────────────────────────────────────────────────────────────
class _BrandPanel extends StatelessWidget {
  final AnimationController bgAnim;
  const _BrandPanel({required this.bgAnim});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Animated background
        Positioned.fill(
          child: AnimatedBuilder(
            animation: bgAnim,
            builder: (_, __) {
              final t = bgAnim.value;
              return Stack(children: [
                Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF040613), Color(0xFF0A1628)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                ),
                Positioned(
                  top: -100 + 50 * t,
                  left: -60 + 30 * t,
                  child: _GlowBlob(450, const Color(0xFF1A237E), 0.5),
                ),
                Positioned(
                  bottom: 100 + 40 * t,
                  right: -80 + 40 * t,
                  child: _GlowBlob(350, const Color(0xFF006064), 0.38),
                ),
              ]);
            },
          ),
        ),

        // Subtle grid
        Positioned.fill(
          child: CustomPaint(painter: _MiniGridPainter()),
        ),

        // Content
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 56, vertical: 60),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Logo
              Row(children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: AppTheme.heroGradient,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.school_rounded,
                      color: Colors.white, size: 28),
                ),
                const SizedBox(width: 14),
                Text(AppConstants.appName,
                    style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w700)),
              ]).animate().fadeIn(delay: 100.ms),

              const SizedBox(height: 48),

              Text('The smarter way to\nmanage school IDs.',
                  style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 38,
                      fontWeight: FontWeight.w800,
                      height: 1.15,
                      letterSpacing: -1))
                  .animate()
                  .fadeIn(delay: 200.ms)
                  .slideY(begin: 0.2),

              const SizedBox(height: 16),

              Text('Design, review and print ID cards for your\nentire school — all from one dashboard.',
                  style: GoogleFonts.poppins(
                      color: Colors.white.withOpacity(0.45),
                      fontSize: 15,
                      height: 1.7))
                  .animate()
                  .fadeIn(delay: 300.ms),

              const SizedBox(height: 48),

              // Feature bullets
              ...[
                (Icons.check_circle_rounded, 'ID card design + bulk print'),
                (Icons.check_circle_rounded, 'Parent review via WhatsApp'),
                (Icons.check_circle_rounded, '2,000+ student Excel import'),
                (Icons.check_circle_rounded, '8-level org hierarchy'),
                (Icons.check_circle_rounded, 'Works on web, iOS & Android'),
              ]
                  .asMap()
                  .entries
                  .map((e) => Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: Row(children: [
                          Icon(e.value.$1,
                              color: AppTheme.secondary, size: 18),
                          const SizedBox(width: 12),
                          Text(e.value.$2,
                              style: GoogleFonts.poppins(
                                  color:
                                      Colors.white.withOpacity(0.7),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500)),
                        ]),
                      )
                          .animate()
                          .fadeIn(
                              delay:
                                  Duration(milliseconds: 350 + e.key * 60))
                          .slideX(begin: -0.1)),

              const SizedBox(height: 48),

              // Social proof
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                      color: Colors.white.withOpacity(0.08)),
                ),
                child: Row(children: [
                  // Avatars
                  SizedBox(
                    width: 80,
                    height: 36,
                    child: Stack(
                      children: List.generate(
                          3,
                          (i) => Positioned(
                                left: i * 22.0,
                                child: Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: [
                                      const Color(0xFF6C63FF),
                                      const Color(0xFF00BCD4),
                                      const Color(0xFF43A047),
                                    ][i],
                                    border: Border.all(
                                        color: const Color(0xFF06070F),
                                        width: 2),
                                  ),
                                  child: Center(
                                    child: Text(['R', 'P', 'S'][i],
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold)),
                                  ),
                                ),
                              )),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('500+ schools onboarded',
                            style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 13)),
                        const SizedBox(height: 2),
                        Text('Across India — CBSE, ICSE & State boards',
                            style: GoogleFonts.poppins(
                                color: Colors.white.withOpacity(0.4),
                                fontSize: 11)),
                      ],
                    ),
                  ),
                ]),
              ).animate().fadeIn(delay: 700.ms),
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// STEP: METHOD (choose Google or Phone)
// ─────────────────────────────────────────────────────────────
class _MethodStep extends StatelessWidget {
  final String portalType;
  final String title;
  final String subtitle;
  final bool loading;
  final String? error;
  final VoidCallback? onGoogle;
  final VoidCallback? onPhone;

  const _MethodStep({
    super.key,
    required this.portalType,
    required this.title,
    required this.subtitle,
    required this.loading,
    required this.error,
    required this.onGoogle,
    required this.onPhone,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FormHeading(
          title: title,
          subtitle: subtitle,
        ),
        const SizedBox(height: 36),

        // Google button
        _AuthButton(
          label: 'Continue with Google',
          icon: _GoogleIcon(),
          onTap: loading ? null : onGoogle,
          loading: loading,
          style: _ButtonStyle.outline,
        ),
        const SizedBox(height: 14),

        // Phone button
        _AuthButton(
          label: 'Continue with Phone OTP',
          icon: const Icon(Icons.phone_android_rounded,
              color: Colors.white, size: 20),
          onTap: loading ? null : onPhone,
          loading: false,
          style: _ButtonStyle.filled,
        ),

        const SizedBox(height: 28),
        _Divider(),
        const SizedBox(height: 28),

        if (error != null) ...[
          _ErrorBanner(error!),
          const SizedBox(height: 20),
        ],

        // Who can sign in info card
        _InfoCard(),

        const SizedBox(height: 24),
        Center(
          child: Text(
              'By signing in you agree to our Terms of Service\nand Privacy Policy.',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                  color: Colors.white.withOpacity(0.3),
                  fontSize: 11,
                  height: 1.6)),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// STEP: PHONE INPUT
// ─────────────────────────────────────────────────────────────
class _PhoneStep extends StatelessWidget {
  final TextEditingController controller;
  final bool loading;
  final String? error;
  final VoidCallback onSend;
  final VoidCallback onBack;

  const _PhoneStep({
    super.key,
    required this.controller,
    required this.loading,
    required this.error,
    required this.onSend,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _BackButton(onBack: onBack),
        const SizedBox(height: 20),
        _FormHeading(
          title: 'Enter your phone',
          subtitle: 'We\'ll send a 6-digit OTP to verify your number.',
        ),
        const SizedBox(height: 32),

        // Phone input
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withOpacity(0.12)),
          ),
          child: Row(children: [
            // Country code
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 16),
              decoration: BoxDecoration(
                border: Border(
                    right: BorderSide(
                        color: Colors.white.withOpacity(0.1))),
              ),
              child: Row(children: [
                Text('🇮🇳',
                    style: const TextStyle(fontSize: 18)),
                const SizedBox(width: 6),
                Text('+91',
                    style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 15)),
              ]),
            ),
            Expanded(
              child: TextField(
                controller: controller,
                autofocus: true,
                keyboardType: TextInputType.phone,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(10),
                ],
                onSubmitted: (_) => onSend(),
                style: GoogleFonts.poppins(
                    color: Colors.white, fontSize: 17),
                decoration: InputDecoration(
                  border: InputBorder.none,
                  hintText: '98100 00000',
                  hintStyle: GoogleFonts.poppins(
                      color: Colors.white.withOpacity(0.25),
                      fontSize: 17),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 16),
                ),
              ),
            ),
          ]),
        ),

        const SizedBox(height: 20),

        if (error != null) ...[
          _ErrorBanner(error!),
          const SizedBox(height: 16),
        ],

        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: loading ? null : onSend,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.secondary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            child: loading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2.5, color: Colors.white))
                : Text('Send OTP',
                    style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w700, fontSize: 15)),
          ),
        ),

        const SizedBox(height: 16),
        Center(
          child: Text('OTP sent via SMS to your mobile number.',
              style: GoogleFonts.poppins(
                  color: Colors.white.withOpacity(0.3),
                  fontSize: 12)),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// STEP: OTP VERIFICATION
// ─────────────────────────────────────────────────────────────
class _OtpStep extends StatelessWidget {
  final String phone;
  final List<TextEditingController> ctrls;
  final List<FocusNode> focusNodes;
  final bool loading;
  final String? error;
  final VoidCallback onVerify;
  final VoidCallback onResend;
  final VoidCallback onBack;

  const _OtpStep({
    super.key,
    required this.phone,
    required this.ctrls,
    required this.focusNodes,
    required this.loading,
    required this.error,
    required this.onVerify,
    required this.onResend,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _BackButton(onBack: onBack),
        const SizedBox(height: 20),

        _FormHeading(
          title: 'Verify OTP',
          subtitle: 'Enter the 6-digit code sent to +91 $phone',
        ),
        const SizedBox(height: 32),

        // OTP boxes
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(
            6,
            (i) => _OtpBox(
              ctrl: ctrls[i],
              focusNode: focusNodes[i],
              nextFocus: i < 5 ? focusNodes[i + 1] : null,
              prevFocus: i > 0 ? focusNodes[i - 1] : null,
              onComplete: i == 5 ? onVerify : null,
            ),
          ),
        ),

        const SizedBox(height: 24),

        if (error != null) ...[
          _ErrorBanner(error!),
          const SizedBox(height: 16),
        ],

        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: loading ? null : onVerify,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.secondary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            child: loading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2.5, color: Colors.white))
                : Text('Verify & Sign In',
                    style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w700, fontSize: 15)),
          ),
        ),

        const SizedBox(height: 20),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text("Didn't receive the code? ",
              style: GoogleFonts.poppins(
                  color: Colors.white.withOpacity(0.35),
                  fontSize: 13)),
          GestureDetector(
            onTap: loading ? null : onResend,
            child: Text('Resend',
                style: GoogleFonts.poppins(
                    color: AppTheme.secondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600)),
          ),
        ]),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// OTP INPUT BOX
// ─────────────────────────────────────────────────────────────
class _OtpBox extends StatelessWidget {
  final TextEditingController ctrl;
  final FocusNode focusNode;
  final FocusNode? nextFocus;
  final FocusNode? prevFocus;
  final VoidCallback? onComplete;

  const _OtpBox({
    required this.ctrl,
    required this.focusNode,
    this.nextFocus,
    this.prevFocus,
    this.onComplete,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 48,
      height: 58,
      child: TextField(
        controller: ctrl,
        focusNode: focusNode,
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        maxLength: 1,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        style: GoogleFonts.poppins(
            color: AppTheme.primary, // Dark text on white box
            fontSize: 24,
            fontWeight: FontWeight.w800),
        decoration: InputDecoration(
          counterText: '',
          filled: true,
          fillColor: Colors.white, // High contrast background for the box
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide:
                const BorderSide(color: Colors.white),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide:
                const BorderSide(color: Colors.white),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide:
                const BorderSide(color: AppTheme.secondary, width: 2.5),
          ),
          contentPadding: EdgeInsets.zero,
        ),
        onChanged: (v) {
          if (v.isNotEmpty) {
            if (nextFocus != null) {
              nextFocus!.requestFocus();
            } else {
              onComplete?.call();
            }
          } else if (v.isEmpty && prevFocus != null) {
            prevFocus!.requestFocus();
          }
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// SMALL SHARED WIDGETS
// ─────────────────────────────────────────────────────────────

class _FormHeading extends StatelessWidget {
  final String title;
  final String subtitle;
  const _FormHeading({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title,
          style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w800)),
      const SizedBox(height: 6),
      Text(subtitle,
          style: GoogleFonts.poppins(
              color: Colors.white.withOpacity(0.42), fontSize: 14)),
    ]).animate().fadeIn(duration: 300.ms).slideY(begin: 0.15);
  }
}

class _BackButton extends StatelessWidget {
  final VoidCallback onBack;
  const _BackButton({required this.onBack});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onBack,
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.arrow_back_rounded,
            color: Colors.white.withOpacity(0.5), size: 18),
        const SizedBox(width: 6),
        Text('Back',
            style: GoogleFonts.poppins(
                color: Colors.white.withOpacity(0.5),
                fontSize: 13)),
      ]),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner(this.message);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.error.withOpacity(0.12),
        borderRadius: BorderRadius.circular(10),
        border:
            Border.all(color: AppTheme.error.withOpacity(0.3)),
      ),
      child: Row(children: [
        Icon(Icons.error_outline_rounded,
            color: AppTheme.error.withOpacity(0.8), size: 18),
        const SizedBox(width: 10),
        Expanded(
            child: Text(message,
                style: GoogleFonts.poppins(
                    color: const Color(0xFFEF9A9A),
                    fontSize: 13))),
      ]),
    ).animate().fadeIn().shakeX(hz: 3, amount: 4);
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Expanded(
          child: Divider(
              color: Colors.white.withOpacity(0.1))),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Text('or',
            style: GoogleFonts.poppins(
                color: Colors.white.withOpacity(0.3),
                fontSize: 13)),
      ),
      Expanded(
          child: Divider(
              color: Colors.white.withOpacity(0.1))),
    ]);
  }
}

class _InfoCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(14),
        border:
            Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Who can sign in?',
              style: GoogleFonts.poppins(
                  color: Colors.white.withOpacity(0.5),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1)),
          const SizedBox(height: 12),
          for (final row in [
            (Icons.admin_panel_settings_rounded, 'Admins & Principals',
                const Color(0xFF6C63FF)),
            (Icons.people_rounded, 'Teachers & Staff',
                const Color(0xFF00BCD4)),
            (Icons.family_restroom_rounded, 'Parents (via review link)',
                const Color(0xFF43A047)),
          ])
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(children: [
                Icon(row.$1, color: row.$3, size: 16),
                const SizedBox(width: 10),
                Text(row.$2,
                    style: GoogleFonts.poppins(
                        color: Colors.white.withOpacity(0.55),
                        fontSize: 13)),
              ]),
            ),
        ],
      ),
    );
  }
}

// Auth button styles
enum _ButtonStyle { outline, filled }

class _AuthButton extends StatelessWidget {
  final String label;
  final Widget icon;
  final VoidCallback? onTap;
  final bool loading;
  final _ButtonStyle style;

  const _AuthButton({
    required this.label,
    required this.icon,
    required this.onTap,
    required this.loading,
    required this.style,
  });

  @override
  Widget build(BuildContext context) {
    final isOutline = style == _ButtonStyle.outline;

    return SizedBox(
      width: double.infinity,
      child: Material(
        color: isOutline
            ? Colors.transparent
            : AppTheme.primary.withOpacity(0.8),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 15),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: isOutline
                      ? Colors.white.withOpacity(0.15)
                      : AppTheme.primaryLight.withOpacity(0.4)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (loading)
                  const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2.5, color: Colors.white))
                else ...[
                  icon,
                  const SizedBox(width: 12),
                  Text(label,
                      style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 14)),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// MISC HELPERS
// ─────────────────────────────────────────────────────────────
class _GoogleIcon extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 20,
      height: 20,
      decoration: const BoxDecoration(shape: BoxShape.circle),
      child: Stack(
        children: [
          CustomPaint(
            size: const Size(20, 20),
            painter: _GoogleLogoPainter(),
          ),
        ],
      ),
    );
  }
}

class _GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2;

    // Draw simple G icon using quadrants
    final bluePaint = Paint()..color = const Color(0xFF4285F4);
    final redPaint = Paint()..color = const Color(0xFFEA4335);
    final yellowPaint = Paint()..color = const Color(0xFFFBBC04);
    final greenPaint = Paint()..color = const Color(0xFF34A853);

    final rect = Rect.fromCircle(center: c, radius: r);
    canvas.drawArc(rect, -1.57, 3.14, false, bluePaint..style = PaintingStyle.stroke..strokeWidth = size.width * 0.25);
    canvas.drawArc(rect, 1.57, 1.57, false, greenPaint..style = PaintingStyle.stroke..strokeWidth = size.width * 0.25);
    canvas.drawArc(rect, 3.14, 0.78, false, yellowPaint..style = PaintingStyle.stroke..strokeWidth = size.width * 0.25);
    canvas.drawArc(rect, -0.78, 0.78, false, redPaint..style = PaintingStyle.stroke..strokeWidth = size.width * 0.25);
  }

  @override
  bool shouldRepaint(_) => false;
}

class _GlowBlob extends StatelessWidget {
  final double size;
  final Color color;
  final double opacity;
  const _GlowBlob(this.size, this.color, this.opacity);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: [
          color.withOpacity(opacity),
          color.withOpacity(0),
        ]),
      ),
    );
  }
}

class _MiniGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.02)
      ..strokeWidth = 1;
    const gap = 48.0;
    for (var x = 0.0; x < size.width; x += gap) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (var y = 0.0; y < size.height; y += gap) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_) => false;
}
