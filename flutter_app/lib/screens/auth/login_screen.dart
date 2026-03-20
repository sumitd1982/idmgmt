// ============================================================
// Login Screen — Google + Phone OTP
// ============================================================
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../config/theme.dart';
import '../../providers/auth_provider.dart';

enum _LoginMode { choose, phone, otp }

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  _LoginMode _mode = _LoginMode.choose;
  final _phoneCtrl = TextEditingController();
  final List<TextEditingController> _otpCtrls =
      List.generate(6, (_) => TextEditingController());
  bool _loading = false;
  String? _error;
  String? _phoneForOtp;

  @override
  void dispose() {
    _phoneCtrl.dispose();
    for (final c in _otpCtrls) c.dispose();
    super.dispose();
  }

  Future<void> _signInGoogle() async {
    setState(() { _loading = true; _error = null; });
    try {
      await ref.read(authNotifierProvider.notifier).signInWithGoogle();
      if (mounted) context.go('/dashboard');
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _sendOtp() async {
    final phone = _phoneCtrl.text.trim();
    if (phone.length < 10) {
      setState(() => _error = 'Enter a valid phone number');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      await ref.read(authServiceProvider).sendOtp(phone.startsWith('+') ? phone : '+91$phone');
      _phoneForOtp = phone;
      setState(() { _mode = _LoginMode.otp; _loading = false; });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _verifyOtp() async {
    final otp = _otpCtrls.map((c) => c.text).join();
    if (otp.length < 6) {
      setState(() => _error = 'Enter all 6 digits');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      await ref.read(authNotifierProvider.notifier)
          .signInWithPhone(_phoneForOtp!, otp);
      if (mounted) context.go('/dashboard');
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(children: [
        // Left Panel — Branding
        if (MediaQuery.of(context).size.width > 800)
          Expanded(
            flex: 5,
            child: Container(
              decoration: const BoxDecoration(gradient: AppTheme.heroGradient),
              child: Stack(children: [
                CustomPaint(
                  painter: _DotsPainter(),
                  size: Size.infinite,
                ),
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(60),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 80, height: 80,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Icon(Icons.school, color: Colors.white, size: 48),
                        ).animate().scale(delay: 200.ms),
                        const SizedBox(height: 32),
                        Text('SchoolID Pro',
                          style: GoogleFonts.poppins(
                            fontSize: 40, fontWeight: FontWeight.w800, color: Colors.white)),
                        const SizedBox(height: 12),
                        Text('Intelligent School Identity\nManagement System',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(
                            fontSize: 18, color: Colors.white.withOpacity(0.85), height: 1.5)),
                        const SizedBox(height: 48),
                        for (final f in [
                          '✅  8-Level Org Hierarchy',
                          '✅  2000+ Student Bulk Upload',
                          '✅  Custom ID Card Designer',
                          '✅  Parent Review via WhatsApp',
                          '✅  N+1 Approval Workflow',
                        ])
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Row(children: [
                              Text(f, style: GoogleFonts.poppins(
                                fontSize: 15, color: Colors.white.withOpacity(0.9))),
                            ]),
                          ),
                      ],
                    ).animate().fadeIn(delay: 300.ms),
                  ),
                ),
              ]),
            ),
          ),

        // Right Panel — Login Form
        Expanded(
          flex: 4,
          child: Container(
            color: Colors.white,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(40),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Welcome back 👋',
                        style: GoogleFonts.poppins(
                          fontSize: 28, fontWeight: FontWeight.w800, color: AppTheme.grey900)),
                      const SizedBox(height: 8),
                      Text('Sign in to your school dashboard',
                        style: GoogleFonts.poppins(fontSize: 14, color: AppTheme.grey600)),
                      const SizedBox(height: 40),

                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        child: _buildLoginContent(),
                      ),

                      if (_error != null) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppTheme.error.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppTheme.error.withOpacity(0.3)),
                          ),
                          child: Row(children: [
                            Icon(Icons.error_outline, color: AppTheme.error, size: 18),
                            const SizedBox(width: 8),
                            Expanded(child: Text(_error!,
                              style: GoogleFonts.poppins(
                                color: AppTheme.error, fontSize: 13))),
                          ]),
                        ),
                      ],

                      const SizedBox(height: 32),
                      Center(child: Text('By signing in, you agree to our Terms & Privacy Policy',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.grey600))),
                    ],
                  ),
                ),
              ).animate().fadeIn().slideX(begin: 0.1),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _buildLoginContent() {
    switch (_mode) {
      case _LoginMode.choose:
        return _buildChooseMode();
      case _LoginMode.phone:
        return _buildPhoneMode();
      case _LoginMode.otp:
        return _buildOtpMode();
    }
  }

  Widget _buildChooseMode() {
    return Column(key: const ValueKey('choose'), children: [
      // Google sign in
      _SocialButton(
        icon: Icons.g_mobiledata_rounded,
        label: 'Continue with Google',
        color: const Color(0xFF4285F4),
        onTap: _loading ? null : _signInGoogle,
      ),
      const SizedBox(height: 16),

      // Phone sign in
      _SocialButton(
        icon: Icons.phone_android,
        label: 'Continue with Phone OTP',
        color: AppTheme.success,
        onTap: _loading ? null : () => setState(() => _mode = _LoginMode.phone),
      ),

      const SizedBox(height: 24),
      Row(children: [
        Expanded(child: Divider(color: AppTheme.grey300)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text('or', style: GoogleFonts.poppins(color: AppTheme.grey600, fontSize: 13)),
        ),
        Expanded(child: Divider(color: AppTheme.grey300)),
      ]),
      const SizedBox(height: 24),

      // Role info cards
      _RoleInfoCard(),
    ]);
  }

  Widget _buildPhoneMode() {
    return Column(key: const ValueKey('phone'), children: [
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.primary.withOpacity(0.05),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.primary.withOpacity(0.15)),
        ),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            decoration: BoxDecoration(
              border: Border(right: BorderSide(color: AppTheme.grey300)),
            ),
            child: Text('+91', style: GoogleFonts.poppins(
              fontWeight: FontWeight.w600, color: AppTheme.grey800)),
          ),
          Expanded(
            child: TextField(
              controller: _phoneCtrl,
              keyboardType: TextInputType.phone,
              autofocus: true,
              style: GoogleFonts.poppins(fontSize: 16),
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: '9810000000',
                hintStyle: GoogleFonts.poppins(color: AppTheme.grey600),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              ),
            ),
          ),
        ]),
      ),
      const SizedBox(height: 20),

      SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: _loading ? null : _sendOtp,
          child: _loading
              ? const SizedBox(width: 20, height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('Send OTP'),
        ),
      ),
      const SizedBox(height: 12),
      TextButton(
        onPressed: () => setState(() { _mode = _LoginMode.choose; _error = null; }),
        child: const Text('← Back to login options'),
      ),
    ]);
  }

  Widget _buildOtpMode() {
    return Column(key: const ValueKey('otp'), children: [
      Text('Enter OTP sent to +91${_phoneForOtp}',
        style: GoogleFonts.poppins(fontSize: 14, color: AppTheme.grey700)),
      const SizedBox(height: 24),

      Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: List.generate(6, (i) => SizedBox(
          width: 48,
          child: TextField(
            controller: _otpCtrls[i],
            keyboardType: TextInputType.number,
            maxLength: 1,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.w700),
            decoration: InputDecoration(
              counterText: '',
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppTheme.grey300, width: 1.5),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppTheme.primary, width: 2),
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 14),
            ),
            onChanged: (v) {
              if (v.isNotEmpty && i < 5) {
                FocusScope.of(context).nextFocus();
              }
            },
          ),
        )),
      ),
      const SizedBox(height: 24),

      SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: _loading ? null : _verifyOtp,
          child: _loading
              ? const SizedBox(width: 20, height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('Verify & Sign In'),
        ),
      ),
      const SizedBox(height: 12),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        TextButton(onPressed: _sendOtp, child: const Text('Resend OTP')),
        const SizedBox(width: 16),
        TextButton(
          onPressed: () => setState(() { _mode = _LoginMode.phone; _error = null; }),
          child: const Text('Change Number'),
        ),
      ]),
    ]);
  }
}

class _SocialButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;

  const _SocialButton({required this.icon, required this.label,
    required this.color, this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          side: BorderSide(color: color.withOpacity(0.4)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(width: 12),
            Text(label, style: GoogleFonts.poppins(
              fontSize: 15, fontWeight: FontWeight.w600, color: AppTheme.grey800)),
          ],
        ),
      ),
    );
  }
}

class _RoleInfoCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.grey50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.grey300),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Who can sign in?', style: GoogleFonts.poppins(
          fontWeight: FontWeight.w700, fontSize: 13, color: AppTheme.grey800)),
        const SizedBox(height: 10),
        for (final role in [
          ('🏫', 'Principal / VP', 'Create schools, branches, org structure'),
          ('👩‍🏫', 'Teachers', 'Manage students, send review links'),
          ('👨‍👩‍👦', 'Parents', 'Review student details via link'),
          ('🔑', 'Admin', 'Full system access'),
        ])
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(children: [
              Text(role.$1, style: const TextStyle(fontSize: 16)),
              const SizedBox(width: 10),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(role.$2, style: GoogleFonts.poppins(
                  fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.grey800)),
                Text(role.$3, style: GoogleFonts.poppins(
                  fontSize: 11, color: AppTheme.grey600)),
              ]),
            ]),
          ),
      ]),
    );
  }
}

class _DotsPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white.withOpacity(0.06);
    const gap = 30.0;
    for (var x = 0.0; x < size.width; x += gap) {
      for (var y = 0.0; y < size.height; y += gap) {
        canvas.drawCircle(Offset(x, y), 1.5, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_) => false;
}
