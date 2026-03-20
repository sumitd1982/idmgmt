// ============================================================
// Landing Screen — SchoolID Pro (rebuilt from scratch)
// ============================================================
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:responsive_framework/responsive_framework.dart';
import '../../config/theme.dart';
import '../../config/constants.dart';

class LandingScreen extends StatefulWidget {
  const LandingScreen({super.key});

  @override
  State<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen>
    with SingleTickerProviderStateMixin {
  final _scrollCtrl = ScrollController();
  bool _scrolled = false;
  late AnimationController _bgAnim;

  @override
  void initState() {
    super.initState();
    _bgAnim = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat(reverse: true);
    _scrollCtrl.addListener(() {
      final s = _scrollCtrl.offset > 40;
      if (s != _scrolled) setState(() => _scrolled = s);
    });
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    _bgAnim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF06070F),
      body: Stack(
        children: [
          SingleChildScrollView(
            controller: _scrollCtrl,
            child: Column(
              children: [
                _HeroSection(bgAnim: _bgAnim),
                _LogoStrip(),
                _FeaturesSection(),
                _HowItWorksSection(),
                _StatsSection(),
                _CtaBanner(),
                _Footer(),
              ],
            ),
          ),
          _NavBar(scrolled: _scrolled),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// NAV BAR
// ─────────────────────────────────────────────────────────────
class _NavBar extends StatelessWidget {
  final bool scrolled;
  const _NavBar({required this.scrolled});

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveBreakpoints.of(context).smallerThan(TABLET);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      color: scrolled
          ? const Color(0xFF06070F).withValues(alpha: 0.95)
          : Colors.transparent,
      child: SafeArea(
        child: SizedBox(
          height: 68,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: isMobile ? 20 : 48),
            child: Row(
              children: [
                // Logo
                Row(children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      gradient: AppTheme.heroGradient,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.school_rounded,
                        color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 10),
                  Text(AppConstants.appName,
                      style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w700)),
                ]),
                const Spacer(),
                if (!isMobile) ...[
                  _NavLink('Features'),
                  _NavLink('How it works'),
                  _NavLink('Pricing'),
                  const SizedBox(width: 8),
                ],
                TextButton(
                  onPressed: () => context.go('/login'),
                  style:
                      TextButton.styleFrom(foregroundColor: Colors.white70),
                  child: Text('Sign in',
                      style: GoogleFonts.poppins(
                          fontSize: 14, fontWeight: FontWeight.w500)),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () => context.go('/login'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.secondary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    elevation: 0,
                  ),
                  child: Text('Get started',
                      style: GoogleFonts.poppins(
                          fontSize: 13, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavLink extends StatelessWidget {
  final String label;
  const _NavLink(this.label);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: TextButton(
        onPressed: () {},
        style: TextButton.styleFrom(foregroundColor: Colors.white70),
        child: Text(label,
            style: GoogleFonts.poppins(
                fontSize: 14, fontWeight: FontWeight.w500)),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// HERO SECTION
// ─────────────────────────────────────────────────────────────
class _HeroSection extends StatelessWidget {
  final AnimationController bgAnim;
  const _HeroSection({required this.bgAnim});

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveBreakpoints.of(context).smallerThan(TABLET);

    return SizedBox(
      height: isMobile ? null : 780,
      child: Stack(
        children: [
          Positioned.fill(child: _GradientBackground(anim: bgAnim)),
          Positioned.fill(child: CustomPaint(painter: _GridPainter())),
          Padding(
            padding: EdgeInsets.only(
              top: 100,
              left: isMobile ? 24 : 80,
              right: isMobile ? 24 : 80,
              bottom: 80,
            ),
            child: isMobile
                ? _HeroContent(isMobile: true)
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const Expanded(
                          flex: 5, child: _HeroContent(isMobile: false)),
                      const SizedBox(width: 60),
                      Expanded(flex: 4, child: _HeroDashboardPreview()),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _HeroContent extends StatelessWidget {
  final bool isMobile;
  const _HeroContent({required this.isMobile});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Pill badge
        Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            border: Border.all(
                color: AppTheme.secondary.withValues(alpha: 0.4)),
            borderRadius: BorderRadius.circular(20),
            color: AppTheme.secondary.withValues(alpha: 0.08),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 7,
              height: 7,
              decoration: const BoxDecoration(
                  color: AppTheme.secondary, shape: BoxShape.circle),
            ),
            const SizedBox(width: 8),
            Text('Trusted by 500+ schools across India',
                style: GoogleFonts.poppins(
                    color: AppTheme.secondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w500)),
          ]),
        ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.3),

        const SizedBox(height: 28),

        // Headline
        Text(
          'School Identity\nManagement,\nReimagined.',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontSize: isMobile ? 36 : 58,
            fontWeight: FontWeight.w800,
            height: 1.08,
            letterSpacing: -1.5,
          ),
        ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.3),

        const SizedBox(height: 20),

        Text(
          'Design ID cards, manage student data,\nrun parent reviews and print — one dashboard.',
          style: GoogleFonts.poppins(
            color: Colors.white.withValues(alpha: 0.5),
            fontSize: isMobile ? 15 : 17,
            height: 1.7,
          ),
        ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.3),

        const SizedBox(height: 40),

        // CTA buttons
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () => ctx.go('/login'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.secondary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 28, vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text('Start free trial',
                      style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w700, fontSize: 15)),
                  const SizedBox(width: 8),
                  const Icon(Icons.arrow_forward_rounded, size: 18),
                ]),
              ),
            ),
            OutlinedButton(
              onPressed: () {},
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: BorderSide(
                    color: Colors.white.withValues(alpha: 0.2)),
                padding: const EdgeInsets.symmetric(
                    horizontal: 28, vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: Text('Watch demo',
                  style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600, fontSize: 15)),
            ),
          ],
        ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.3),

        const SizedBox(height: 40),

        // Social proof avatars
        Row(children: [
          ...List.generate(
            4,
            (i) => Container(
              width: 32,
              height: 32,
              margin: EdgeInsets.only(left: i > 0 ? -8 : 0),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: [
                  const Color(0xFF6C63FF),
                  const Color(0xFF00BCD4),
                  const Color(0xFFFF6584),
                  const Color(0xFF43A047),
                ][i],
                border: Border.all(
                    color: const Color(0xFF06070F), width: 2),
              ),
              child: Center(
                child: Text(['R', 'P', 'S', 'A'][i],
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold)),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Text('2,000+ educators joined this year',
              style: GoogleFonts.poppins(
                  color: Colors.white.withValues(alpha: 0.4),
                  fontSize: 13)),
        ]).animate().fadeIn(delay: 500.ms),
      ],
    );
  }
}

class _HeroDashboardPreview extends StatelessWidget {
  const _HeroDashboardPreview();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(24),
        border:
            Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Mini ID card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0D1B63), Color(0xFF1565C0)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(children: [
              Container(
                width: 52,
                height: 64,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.person_rounded,
                    color: Colors.white, size: 36),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Rahul Sharma',
                        style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 15)),
                    const SizedBox(height: 4),
                    Text('Class X-A  •  Roll 14',
                        style: GoogleFonts.poppins(
                            color: Colors.white.withValues(alpha: 0.7),
                            fontSize: 12)),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppTheme.secondary.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text('DPS, New Delhi',
                          style: GoogleFonts.poppins(
                              color: AppTheme.secondary,
                              fontSize: 11,
                              fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
              ),
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.all(4),
                child: const Icon(Icons.qr_code_2_rounded,
                    color: Color(0xFF0D1B63), size: 36),
              ),
            ]),
          ),
          const SizedBox(height: 18),

          // Mini stats
          Row(children: [
            _PreviewStat('2,400', 'Students'),
            const SizedBox(width: 10),
            _PreviewStat('98%', 'Approved'),
            const SizedBox(width: 10),
            _PreviewStat('6 hrs', 'Saved/week'),
          ]),
          const SizedBox(height: 18),

          // Activity feed
          for (final item in [
            (Icons.upload_rounded, 'Bulk upload complete', 'Just now',
                AppTheme.secondary),
            (Icons.rate_review_rounded, '12 parent reviews pending',
                '2 min ago', AppTheme.accentLight),
            (Icons.print_rounded, 'ID cards ready to print', '5 min ago',
                AppTheme.statusGreen),
          ])
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: Colors.white.withValues(alpha: 0.06)),
              ),
              child: Row(children: [
                Icon(item.$1, color: item.$4, size: 15),
                const SizedBox(width: 10),
                Expanded(
                    child: Text(item.$2,
                        style: GoogleFonts.poppins(
                            color: Colors.white.withValues(alpha: 0.7),
                            fontSize: 12))),
                Text(item.$3,
                    style: GoogleFonts.poppins(
                        color: Colors.white.withValues(alpha: 0.3),
                        fontSize: 11)),
              ]),
            ),
        ],
      ),
    )
        .animate()
        .fadeIn(delay: 450.ms, duration: 600.ms)
        .slideX(begin: 0.12);
  }
}

class _PreviewStat extends StatelessWidget {
  final String value;
  final String label;
  const _PreviewStat(this.value, this.label);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(children: [
          Text(value,
              style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 15)),
          const SizedBox(height: 2),
          Text(label,
              style: GoogleFonts.poppins(
                  color: Colors.white.withValues(alpha: 0.35),
                  fontSize: 10)),
        ]),
      ),
    );
  }
}

// Animated gradient blobs
class _GradientBackground extends StatelessWidget {
  final AnimationController anim;
  const _GradientBackground({required this.anim});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: anim,
      builder: (_, __) {
        final t = anim.value;
        return Stack(children: [
          Container(color: const Color(0xFF06070F)),
          Positioned(
            top: -80 + 40 * t,
            left: -60 + 30 * t,
            child: _Blob(380, const Color(0xFF1A237E), 0.5),
          ),
          Positioned(
            top: 180 - 50 * t,
            right: -40 + 40 * t,
            child: _Blob(300, const Color(0xFF006064), 0.38),
          ),
          Positioned(
            bottom: 80 + 30 * t,
            left: 220 + 20 * t,
            child: _Blob(240, const Color(0xFF4A148C), 0.3),
          ),
        ]);
      },
    );
  }
}

class _Blob extends StatelessWidget {
  final double size;
  final Color color;
  final double opacity;
  const _Blob(this.size, this.color, this.opacity);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            color.withValues(alpha: opacity),
            color.withValues(alpha: 0),
          ],
        ),
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.025)
      ..strokeWidth = 1;
    const gap = 52.0;
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

// ─────────────────────────────────────────────────────────────
// LOGO STRIP
// ─────────────────────────────────────────────────────────────
class _LogoStrip extends StatelessWidget {
  const _LogoStrip();

  static const _schools = [
    'Delhi Public School',
    'Kendriya Vidyalaya',
    'Ryan International',
    'DAV Public School',
    'Amity School',
    'Bal Bharati School',
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 36),
      decoration: BoxDecoration(
        border: Border.symmetric(
          horizontal: BorderSide(
              color: Colors.white.withValues(alpha: 0.06)),
        ),
      ),
      child: Column(children: [
        Text('TRUSTED BY LEADING SCHOOLS ACROSS INDIA',
            style: GoogleFonts.poppins(
                color: Colors.white.withValues(alpha: 0.25),
                fontSize: 11,
                letterSpacing: 2.5,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 24),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 40,
          runSpacing: 16,
          children: _schools
              .map((s) => Text(s,
                  style: GoogleFonts.poppins(
                      color: Colors.white.withValues(alpha: 0.18),
                      fontSize: 13,
                      fontWeight: FontWeight.w600)))
              .toList(),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// FEATURES SECTION
// ─────────────────────────────────────────────────────────────
class _FeaturesSection extends StatelessWidget {
  const _FeaturesSection();

  static const _features = [
    (
      Icons.account_tree_rounded,
      '8-Level Org Hierarchy',
      'Principal down to substitute — full org chart with role-based permissions and approvals.',
      Color(0xFF6C63FF),
    ),
    (
      Icons.badge_rounded,
      'Plug & Play ID Cards',
      'Drag-and-drop designer with 8 themes. Front + back. QR code and photo.',
      Color(0xFF00BCD4),
    ),
    (
      Icons.groups_rounded,
      'Parent Review Portal',
      'Send review links via WhatsApp/SMS. Parents approve or request changes instantly.',
      Color(0xFF43A047),
    ),
    (
      Icons.upload_file_rounded,
      '2,000+ Bulk Upload',
      'Excel import with live validation. Handles duplicates, missing fields and photos.',
      Color(0xFFFF9800),
    ),
    (
      Icons.insert_chart_rounded,
      'Real-time Reports',
      'Pending, approved and changed — live status across all branches and classes.',
      Color(0xFFE91E63),
    ),
    (
      Icons.school_rounded,
      'Multi-School & Branch',
      'One account for multiple campuses. Per-branch admins and independent workflows.',
      Color(0xFF009688),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveBreakpoints.of(context).smallerThan(TABLET);

    return Container(
      padding: EdgeInsets.symmetric(
          vertical: 100, horizontal: isMobile ? 24 : 80),
      child: Column(children: [
        _SectionLabel('FEATURES'),
        const SizedBox(height: 16),
        Text('Everything your school needs',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: isMobile ? 28 : 42,
                fontWeight: FontWeight.w800)),
        const SizedBox(height: 12),
        Text('From first upload to final print — all in one place.',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
                color: Colors.white.withValues(alpha: 0.4),
                fontSize: 16)),
        const SizedBox(height: 60),
        _buildGrid(isMobile),
      ]),
    );
  }

  Widget _buildGrid(bool isMobile) {
    if (isMobile) {
      return Column(
        children: _features
            .asMap()
            .entries
            .map((e) => Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: _FeatureCard(
                      icon: e.value.$1,
                      title: e.value.$2,
                      desc: e.value.$3,
                      color: e.value.$4,
                      delay: e.key * 80),
                ))
            .toList(),
      );
    }

    return LayoutBuilder(builder: (context, constraints) {
      final cardW = (constraints.maxWidth - 16) / 3;
      return Wrap(
        spacing: 16,
        runSpacing: 16,
        children: _features
            .asMap()
            .entries
            .map((e) => SizedBox(
                  width: cardW,
                  child: _FeatureCard(
                      icon: e.value.$1,
                      title: e.value.$2,
                      desc: e.value.$3,
                      color: e.value.$4,
                      delay: e.key * 80),
                ))
            .toList(),
      );
    });
  }
}

class _FeatureCard extends StatefulWidget {
  final IconData icon;
  final String title;
  final String desc;
  final Color color;
  final int delay;

  const _FeatureCard({
    required this.icon,
    required this.title,
    required this.desc,
    required this.color,
    required this.delay,
  });

  @override
  State<_FeatureCard> createState() => _FeatureCardState();
}

class _FeatureCardState extends State<_FeatureCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: _hovered
              ? Colors.white.withValues(alpha: 0.07)
              : Colors.white.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: _hovered
                ? widget.color.withValues(alpha: 0.35)
                : Colors.white.withValues(alpha: 0.07),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: widget.color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(widget.icon, color: widget.color, size: 24),
            ),
            const SizedBox(height: 18),
            Text(widget.title,
                style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 16)),
            const SizedBox(height: 8),
            Text(widget.desc,
                style: GoogleFonts.poppins(
                    color: Colors.white.withValues(alpha: 0.42),
                    fontSize: 13,
                    height: 1.65)),
          ],
        ),
      ),
    )
        .animate()
        .fadeIn(delay: Duration(milliseconds: 180 + widget.delay))
        .slideY(begin: 0.2);
  }
}

// ─────────────────────────────────────────────────────────────
// HOW IT WORKS
// ─────────────────────────────────────────────────────────────
class _HowItWorksSection extends StatelessWidget {
  const _HowItWorksSection();

  static const _steps = [
    (
      '01',
      'Create your school',
      'Add school name, logo, branches and org hierarchy in under 5 minutes.',
      Color(0xFF6C63FF),
    ),
    (
      '02',
      'Import students',
      'Bulk upload via Excel or add individually. Photos and roll numbers auto-assigned.',
      Color(0xFF00BCD4),
    ),
    (
      '03',
      'Design ID cards',
      'Pick a template, customise colours and fields. Preview front + back live.',
      Color(0xFFFF6584),
    ),
    (
      '04',
      'Send for parent review',
      'One click sends review links via WhatsApp. Parents approve or flag changes.',
      Color(0xFF43A047),
    ),
    (
      '05',
      'Print or export',
      'Download print-ready PDFs by class. Bulk or individual. No design tools needed.',
      Color(0xFFFF9800),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveBreakpoints.of(context).smallerThan(TABLET);

    return Container(
      padding: EdgeInsets.symmetric(
          vertical: 100, horizontal: isMobile ? 24 : 80),
      decoration: BoxDecoration(
        border: Border(
            top: BorderSide(
                color: Colors.white.withValues(alpha: 0.05))),
      ),
      child: Column(children: [
        _SectionLabel('HOW IT WORKS'),
        const SizedBox(height: 16),
        Text('From zero to printed ID cards in one hour',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: isMobile ? 26 : 40,
                fontWeight: FontWeight.w800)),
        const SizedBox(height: 60),
        isMobile
            ? Column(
                children: _steps
                    .asMap()
                    .entries
                    .map((e) => Padding(
                          padding: const EdgeInsets.only(bottom: 28),
                          child:
                              _StepTile(step: e.value, delay: e.key * 100),
                        ))
                    .toList(),
              )
            : Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: _steps
                    .asMap()
                    .entries
                    .map((e) => Expanded(
                        child: Padding(
                          padding:
                              const EdgeInsets.symmetric(horizontal: 8),
                          child: _StepTile(
                              step: e.value, delay: e.key * 100),
                        )))
                    .toList(),
              ),
      ]),
    );
  }
}

class _StepTile extends StatelessWidget {
  final (String, String, String, Color) step;
  final int delay;
  const _StepTile({required this.step, required this.delay});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(step.$1,
            style: GoogleFonts.poppins(
                color: step.$4,
                fontSize: 42,
                fontWeight: FontWeight.w900,
                letterSpacing: -2)),
        const SizedBox(height: 12),
        Text(step.$2,
            style: GoogleFonts.poppins(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 16)),
        const SizedBox(height: 8),
        Text(step.$3,
            style: GoogleFonts.poppins(
                color: Colors.white.withValues(alpha: 0.42),
                fontSize: 13,
                height: 1.65)),
      ],
    )
        .animate()
        .fadeIn(delay: Duration(milliseconds: 200 + delay))
        .slideY(begin: 0.2);
  }
}

// ─────────────────────────────────────────────────────────────
// STATS SECTION
// ─────────────────────────────────────────────────────────────
class _StatsSection extends StatelessWidget {
  const _StatsSection();

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveBreakpoints.of(context).smallerThan(TABLET);

    return Padding(
      padding: EdgeInsets.symmetric(
          vertical: 60, horizontal: isMobile ? 24 : 80),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 56, horizontal: 40),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF0D1B63), Color(0xFF006064)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(28),
        ),
        child: Wrap(
          alignment: WrapAlignment.spaceAround,
          runSpacing: 32,
          children: const [
            _StatChip('500+', 'Schools'),
            _StatChip('2,000+', 'Branches'),
            _StatChip('5 Lakh+', 'Students'),
            _StatChip('99.9%', 'Uptime'),
          ],
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String value;
  final String label;
  const _StatChip(this.value, this.label);

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Text(value,
          style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 44,
              fontWeight: FontWeight.w800,
              letterSpacing: -1.5)),
      const SizedBox(height: 4),
      Text(label,
          style: GoogleFonts.poppins(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 15)),
    ]).animate().fadeIn(delay: 200.ms).scale(begin: const Offset(0.85, 0.85));
  }
}

// ─────────────────────────────────────────────────────────────
// CTA BANNER
// ─────────────────────────────────────────────────────────────
class _CtaBanner extends StatelessWidget {
  const _CtaBanner();

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveBreakpoints.of(context).smallerThan(TABLET);

    return Padding(
      padding: EdgeInsets.symmetric(
          vertical: 100, horizontal: isMobile ? 24 : 80),
      child: Column(children: [
        Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            border: Border.all(
                color: AppTheme.accentLight.withValues(alpha: 0.4)),
            borderRadius: BorderRadius.circular(20),
            color: AppTheme.accentLight.withValues(alpha: 0.06),
          ),
          child: Text('No credit card required',
              style: GoogleFonts.poppins(
                  color: AppTheme.accentLight,
                  fontSize: 12,
                  fontWeight: FontWeight.w500)),
        ),
        const SizedBox(height: 28),
        Text('Ready to modernise\nyour school?',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: isMobile ? 32 : 52,
                fontWeight: FontWeight.w800,
                height: 1.15)),
        const SizedBox(height: 16),
        Text(
            'Join 500+ schools already using SchoolID Pro.\nSetup takes less than 10 minutes.',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
                color: Colors.white.withValues(alpha: 0.4),
                fontSize: 16,
                height: 1.6)),
        const SizedBox(height: 40),
        Builder(
          builder: (ctx) => ElevatedButton(
            onPressed: () => ctx.go('/login'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.secondary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(
                  horizontal: 40, vertical: 18),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              elevation: 0,
            ),
            child: Text('Get started for free',
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w700, fontSize: 16)),
          ),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// FOOTER
// ─────────────────────────────────────────────────────────────
class _Footer extends StatelessWidget {
  const _Footer();

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveBreakpoints.of(context).smallerThan(TABLET);

    return Container(
      padding: EdgeInsets.symmetric(
          vertical: 52, horizontal: isMobile ? 24 : 80),
      decoration: BoxDecoration(
        border: Border(
            top: BorderSide(
                color: Colors.white.withValues(alpha: 0.06))),
      ),
      child: isMobile
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildBrand(),
                const SizedBox(height: 36),
                _buildLinks(),
                const SizedBox(height: 32),
                _buildCopy(),
              ],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 3, child: _buildBrand()),
                Expanded(flex: 5, child: _buildLinks()),
              ],
            ),
    );
  }

  Widget _buildBrand() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            gradient: AppTheme.heroGradient,
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.school_rounded,
              color: Colors.white, size: 20),
        ),
        const SizedBox(width: 10),
        Text(AppConstants.appName,
            style: GoogleFonts.poppins(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 16)),
      ]),
      const SizedBox(height: 14),
      Text('Intelligent school identity\nmanagement for India.',
          style: GoogleFonts.poppins(
              color: Colors.white.withValues(alpha: 0.3),
              fontSize: 13,
              height: 1.65)),
      const SizedBox(height: 20),
      _buildCopy(),
    ]);
  }

  Widget _buildLinks() {
    return Wrap(
      spacing: 56,
      runSpacing: 24,
      children: [
        _FooterCol('Product',
            ['Features', 'Pricing', 'Changelog', 'Roadmap']),
        _FooterCol('Company', ['About', 'Blog', 'Careers', 'Contact']),
        _FooterCol('Legal', ['Privacy', 'Terms', 'Security']),
      ],
    );
  }

  Widget _buildCopy() {
    return Text(
        '© ${DateTime.now().year} SchoolID Pro. Made in India 🇮🇳',
        style: GoogleFonts.poppins(
            color: Colors.white.withValues(alpha: 0.2), fontSize: 12));
  }
}

class _FooterCol extends StatelessWidget {
  final String title;
  final List<String> links;
  const _FooterCol(this.title, this.links);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: GoogleFonts.poppins(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 13)),
        const SizedBox(height: 12),
        ...links.map((l) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: TextButton(
                onPressed: () {},
                style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                child: Text(l,
                    style: GoogleFonts.poppins(
                        color: Colors.white.withValues(alpha: 0.3),
                        fontSize: 13)),
              ),
            )),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// SHARED WIDGETS
// ─────────────────────────────────────────────────────────────
class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel(this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        border:
            Border.all(color: Colors.white.withValues(alpha: 0.12)),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label,
          style: GoogleFonts.poppins(
              color: Colors.white.withValues(alpha: 0.4),
              fontSize: 11,
              letterSpacing: 2.5,
              fontWeight: FontWeight.w600)),
    );
  }
}
