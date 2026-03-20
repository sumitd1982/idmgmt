// ============================================================
// Landing Page — Marketing + Home
// Beautiful, animated, SEO-friendly landing page
// ============================================================
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:animated_text_kit/animated_text_kit.dart';
import 'package:responsive_framework/responsive_framework.dart';
import '../../config/theme.dart';
import '../../config/constants.dart';

class LandingScreen extends StatefulWidget {
  const LandingScreen({super.key});

  @override
  State<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen> {
  final _scrollController = ScrollController();
  bool _isScrolled = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      setState(() => _isScrolled = _scrollController.offset > 50);
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollTo(GlobalKey key) {
    Scrollable.ensureVisible(key.currentContext!,
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveBreakpoints.of(context).isMobile;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // ── Main Content ────────────────────────────────────
          CustomScrollView(
            controller: _scrollController,
            slivers: [
              SliverToBoxAdapter(child: _HeroSection()),
              SliverToBoxAdapter(child: _StatsBar()),
              SliverToBoxAdapter(child: _FeaturesSection()),
              SliverToBoxAdapter(child: _HowItWorksSection()),
              SliverToBoxAdapter(child: _IdCardShowcase()),
              SliverToBoxAdapter(child: _TestimonialsSection()),
              SliverToBoxAdapter(child: _PricingSection()),
              SliverToBoxAdapter(child: _AboutSection()),
              SliverToBoxAdapter(child: _ContactSection()),
              SliverToBoxAdapter(child: _Footer()),
            ],
          ),

          // ── Sticky Top Navigation ──────────────────────────
          Positioned(
            top: 0, left: 0, right: 0,
            child: _TopNav(
              isScrolled: _isScrolled,
              onLogin: () => context.go('/login'),
            ),
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────
// Top Navigation Bar
// ──────────────────────────────────────────────────────────────
class _TopNav extends StatelessWidget {
  final bool isScrolled;
  final VoidCallback onLogin;

  const _TopNav({required this.isScrolled, required this.onLogin});

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveBreakpoints.of(context).isMobile;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      color: isScrolled ? Colors.white : Colors.transparent,
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
      child: SafeArea(
        child: Row(
          children: [
            // Logo
            Row(
              children: [
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    gradient: AppTheme.primaryGradient,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.school, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 10),
                Text(
                  AppConstants.appName,
                  style: GoogleFonts.poppins(
                    fontSize: 20, fontWeight: FontWeight.w700,
                    color: isScrolled ? AppTheme.primary : Colors.white,
                  ),
                ),
              ],
            ),

            const Spacer(),

            // Nav links (desktop only)
            if (!isMobile) ...[
              for (final item in ['Features', 'About', 'Contact'])
                TextButton(
                  onPressed: () {},
                  child: Text(item,
                    style: GoogleFonts.poppins(
                      color: isScrolled ? AppTheme.grey800 : Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              const SizedBox(width: 8),
            ],

            // Login Button
            ElevatedButton.icon(
              onPressed: onLogin,
              icon: const Icon(Icons.login, size: 18),
              label: const Text('Login / Sign Up'),
              style: ElevatedButton.styleFrom(
                backgroundColor: isScrolled ? AppTheme.primary : Colors.white,
                foregroundColor: isScrolled ? Colors.white : AppTheme.primary,
                elevation: 2,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────
// Hero Section
// ──────────────────────────────────────────────────────────────
class _HeroSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveBreakpoints.of(context).isMobile;
    final isTablet = ResponsiveBreakpoints.of(context).isTablet;

    return Container(
      height: isMobile ? 680 : 720,
      decoration: const BoxDecoration(gradient: AppTheme.heroGradient),
      child: Stack(
        children: [
          // Background pattern
          Positioned.fill(
            child: CustomPaint(painter: _GridPainter()),
          ),

          // Floating shapes
          ..._buildFloatingShapes(),

          // Content
          Center(
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: isMobile ? 24 : 80,
                vertical: 100,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white.withOpacity(0.3)),
                    ),
                    child: Text(
                      '🏆  #1 School ID Management Platform in India',
                      style: GoogleFonts.poppins(
                        color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500,
                      ),
                    ),
                  ).animate().fadeIn(delay: 200.ms).slideY(begin: -0.3),

                  const SizedBox(height: 24),

                  // Headline
                  Text(
                    'Smart School ID\nManagement System',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: isMobile ? 32 : 52,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      height: 1.2,
                    ),
                  ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.3),

                  const SizedBox(height: 16),

                  // Animated subtitle
                  DefaultTextStyle(
                    style: GoogleFonts.poppins(
                      fontSize: isMobile ? 16 : 20,
                      color: Colors.white.withOpacity(0.9),
                    ),
                    child: AnimatedTextKit(
                      repeatForever: true,
                      animatedTexts: [
                        TypewriterAnimatedText('Manage 2000+ students effortlessly'),
                        TypewriterAnimatedText('8-level org hierarchy, zero confusion'),
                        TypewriterAnimatedText('Custom ID cards, plug & play themes'),
                        TypewriterAnimatedText('Parent review via WhatsApp & SMS'),
                      ],
                    ),
                  ).animate().fadeIn(delay: 600.ms),

                  const SizedBox(height: 16),

                  Text(
                    'Multi-tenant · Multi-branch · Multi-role · Multi-country',
                    style: GoogleFonts.poppins(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 13,
                    ),
                  ).animate().fadeIn(delay: 700.ms),

                  const SizedBox(height: 40),

                  // CTA buttons
                  Wrap(
                    spacing: 16, runSpacing: 12,
                    alignment: WrapAlignment.center,
                    children: [
                      ElevatedButton.icon(
                        onPressed: () => GoRouter.of(context).go('/login'),
                        icon: const Icon(Icons.rocket_launch, size: 20),
                        label: const Text('Get Started Free'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.accentLight,
                          foregroundColor: AppTheme.grey900,
                          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 18),
                          textStyle: GoogleFonts.poppins(
                            fontSize: 16, fontWeight: FontWeight.w700),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          elevation: 8,
                          shadowColor: AppTheme.accentLight.withOpacity(0.5),
                        ),
                      ).animate().fadeIn(delay: 800.ms).scale(begin: const Offset(0.8, 0.8)),

                      OutlinedButton.icon(
                        onPressed: () {},
                        icon: const Icon(Icons.play_circle_outline, size: 20),
                        label: const Text('Watch Demo'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Colors.white, width: 2),
                          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 18),
                          textStyle: GoogleFonts.poppins(
                            fontSize: 16, fontWeight: FontWeight.w600),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                      ).animate().fadeIn(delay: 900.ms).scale(begin: const Offset(0.8, 0.8)),
                    ],
                  ),

                  const SizedBox(height: 40),

                  // Trust badges
                  Wrap(
                    spacing: 24, runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: [
                      _TrustBadge(icon: Icons.verified_user, text: 'CBSE Compliant'),
                      _TrustBadge(icon: Icons.lock, text: 'Data Encrypted'),
                      _TrustBadge(icon: Icons.cloud, text: 'Oracle Cloud'),
                      _TrustBadge(icon: Icons.devices, text: 'Web + Mobile'),
                    ],
                  ).animate().fadeIn(delay: 1000.ms),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildFloatingShapes() => [
    _FloatingShape(top: 80, left: -60, size: 200, opacity: 0.06),
    _FloatingShape(top: 300, right: -80, size: 250, opacity: 0.05),
    _FloatingShape(bottom: 60, left: 100, size: 150, opacity: 0.08),
  ];
}

class _FloatingShape extends StatelessWidget {
  final double? top, left, right, bottom, size, opacity;
  const _FloatingShape({this.top, this.left, this.right, this.bottom, this.size, this.opacity});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: top, left: left, right: right, bottom: bottom,
      child: Container(
        width: size, height: size,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(opacity ?? 0.05),
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

class _TrustBadge extends StatelessWidget {
  final IconData icon;
  final String text;
  const _TrustBadge({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Colors.white.withOpacity(0.8), size: 16),
        const SizedBox(width: 6),
        Text(text, style: GoogleFonts.poppins(
          color: Colors.white.withOpacity(0.8), fontSize: 12)),
      ],
    );
  }
}

// ──────────────────────────────────────────────────────────────
// Stats Bar
// ──────────────────────────────────────────────────────────────
class _StatsBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 40),
      decoration: BoxDecoration(
        color: AppTheme.primary,
        boxShadow: [BoxShadow(color: AppTheme.primary.withOpacity(0.3),
          blurRadius: 20, offset: const Offset(0, 8))],
      ),
      child: Wrap(
        alignment: WrapAlignment.spaceEvenly,
        spacing: 32, runSpacing: 24,
        children: [
          _StatItem(number: '500+', label: 'Schools', icon: Icons.account_balance),
          _StatItem(number: '2,000+', label: 'Branches', icon: Icons.business),
          _StatItem(number: '5L+', label: 'Students', icon: Icons.people),
          _StatItem(number: '99.9%', label: 'Uptime', icon: Icons.cloud_done),
        ],
      ),
    ).animate().fadeIn().slideY(begin: 0.2);
  }
}

class _StatItem extends StatelessWidget {
  final String number, label;
  final IconData icon;
  const _StatItem({required this.number, required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: AppTheme.accentLight, size: 28),
        const SizedBox(height: 8),
        Text(number, style: GoogleFonts.poppins(
          fontSize: 28, fontWeight: FontWeight.w800, color: Colors.white)),
        Text(label, style: GoogleFonts.poppins(
          fontSize: 13, color: Colors.white.withOpacity(0.8))),
      ],
    );
  }
}

// ──────────────────────────────────────────────────────────────
// Features Section
// ──────────────────────────────────────────────────────────────
class _FeaturesSection extends StatelessWidget {
  final features = const [
    _Feature(
      icon: Icons.account_tree, color: Color(0xFF1565C0),
      title: '8-Level Hierarchy',
      desc: 'Principal → VP → Head Teacher → Senior → Class → Subject → Backup → Temp. '
            'Full org-chart with role-based permissions and N+1 approval chains.',
    ),
    _Feature(
      icon: Icons.badge, color: Color(0xFF2E7D32),
      title: 'Plug & Play ID Cards',
      desc: 'Design custom dual-sided ID cards with drag-and-drop themes. '
            'Multiple layouts, color schemes, logos, QR codes, and custom text fields.',
    ),
    _Feature(
      icon: Icons.people, color: Color(0xFF6A1B9A),
      title: 'Parent Review Portal',
      desc: 'Class teachers send review links via WhatsApp/SMS/Email. '
            'Parents review and update student details. N+1 chain approves changes.',
    ),
    _Feature(
      icon: Icons.upload_file, color: Color(0xFFE65100),
      title: 'Bulk Upload & Validate',
      desc: 'Upload 2000 students or 100+ employees via Excel template. '
            'Row-level validation report with error details before import.',
    ),
    _Feature(
      icon: Icons.bar_chart, color: Color(0xFF00838F),
      title: 'Smart Reports',
      desc: 'Green = Verified ✓, Blue = Changed ⟳, Red = Pending ✗. '
            'Teacher-wise, class-wise, branch-wise, school-wide dashboards.',
    ),
    _Feature(
      icon: Icons.notifications_active, color: Color(0xFFC62828),
      title: 'MSG91 Integration',
      desc: 'Send WhatsApp, SMS, and Email notifications via MSG91. '
            'Automated review links, approval alerts, and bulk messaging.',
    ),
    _Feature(
      icon: Icons.account_balance, color: Color(0xFF37474F),
      title: 'Multi-Tenant Schools',
      desc: 'One platform, many schools. Each school has its own branches, '
            'staff, students, themes, and data — fully isolated.',
    ),
    _Feature(
      icon: Icons.devices, color: Color(0xFF1B5E20),
      title: 'Web + iOS + Android',
      desc: 'Flutter-powered — one codebase for all platforms. '
            'Responsive design works beautifully on phones, tablets, and desktops.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 80, horizontal: 40),
      color: AppTheme.grey50,
      child: Column(
        children: [
          _SectionHeader(
            tag: 'FEATURES',
            title: 'Everything You Need\nto Manage School IDs',
            subtitle: 'A complete ecosystem for modern school identity management',
          ),
          const SizedBox(height: 60),
          LayoutBuilder(builder: (ctx, constraints) {
            final cols = constraints.maxWidth > 900 ? 4 :
                         constraints.maxWidth > 600 ? 2 : 1;
            return _ResponsiveGrid(
              columns: cols, children: features.map((f) => _FeatureCard(f)).toList(),
            );
          }),
        ],
      ),
    );
  }
}

class _Feature {
  final IconData icon;
  final Color color;
  final String title, desc;
  const _Feature({required this.icon, required this.color,
                  required this.title, required this.desc});
}

class _FeatureCard extends StatefulWidget {
  final _Feature feature;
  const _FeatureCard(this.feature);

  @override
  State<_FeatureCard> createState() => _FeatureCardState();
}

class _FeatureCardState extends State<_FeatureCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit:  (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        transform: Matrix4.translationValues(0, _hovered ? -6 : 0, 0),
        child: Card(
          elevation: _hovered ? 12 : 3,
          shadowColor: widget.feature.color.withOpacity(0.2),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 52, height: 52,
                  decoration: BoxDecoration(
                    color: widget.feature.color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(widget.feature.icon, color: widget.feature.color, size: 28),
                ),
                const SizedBox(height: 20),
                Text(widget.feature.title,
                  style: GoogleFonts.poppins(
                    fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.grey900)),
                const SizedBox(height: 10),
                Text(widget.feature.desc,
                  style: GoogleFonts.poppins(
                    fontSize: 13, color: AppTheme.grey600, height: 1.6)),
              ],
            ),
          ),
        ),
      ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.3),
    );
  }
}

// ──────────────────────────────────────────────────────────────
// How It Works
// ──────────────────────────────────────────────────────────────
class _HowItWorksSection extends StatelessWidget {
  final steps = const [
    _Step(number: '01', title: 'Create School',
          desc: 'Principal registers school with all details. Multiple branches added instantly.',
          icon: Icons.add_business),
    _Step(number: '02', title: 'Build Org Structure',
          desc: 'Define 8-level hierarchy. Assign reporting lines. Upload staff via Excel.',
          icon: Icons.account_tree),
    _Step(number: '03', title: 'Import Students',
          desc: 'Bulk upload 2000+ students with auto-validation. Photos via Firebase Storage.',
          icon: Icons.group_add),
    _Step(number: '04', title: 'Design ID Cards',
          desc: 'Choose themes, customize layouts, add logos. Preview front & back instantly.',
          icon: Icons.badge),
    _Step(number: '05', title: 'Parent Review',
          desc: 'Send review links via WhatsApp. Parents confirm or update. Teachers approve.',
          icon: Icons.rate_review),
    _Step(number: '06', title: 'Print & Export',
          desc: 'Generate PDFs, bulk print ID cards. Export reports to Excel.',
          icon: Icons.print),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 80, horizontal: 40),
      decoration: const BoxDecoration(gradient: AppTheme.primaryGradient),
      child: Column(
        children: [
          _SectionHeader(
            tag: 'HOW IT WORKS',
            title: 'From Setup to\nPrinted ID in Minutes',
            subtitle: 'Simple 6-step process for any school size',
            lightTheme: true,
          ),
          const SizedBox(height: 60),
          Wrap(
            spacing: 24, runSpacing: 24,
            alignment: WrapAlignment.center,
            children: steps.map((s) => _StepCard(s)).toList(),
          ),
        ],
      ),
    );
  }
}

class _Step {
  final String number, title, desc;
  final IconData icon;
  const _Step({required this.number, required this.title,
               required this.desc, required this.icon});
}

class _StepCard extends StatelessWidget {
  final _Step step;
  const _StepCard(this.step);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 260,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.15)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Text(step.number,
                style: GoogleFonts.poppins(
                  fontSize: 36, fontWeight: FontWeight.w800,
                  color: AppTheme.accentLight.withOpacity(0.6))),
              const Spacer(),
              Icon(step.icon, color: AppTheme.accentLight, size: 28),
            ]),
            const SizedBox(height: 12),
            Text(step.title, style: GoogleFonts.poppins(
              fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
            const SizedBox(height: 8),
            Text(step.desc, style: GoogleFonts.poppins(
              fontSize: 12, color: Colors.white.withOpacity(0.75), height: 1.6)),
          ],
        ),
      ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.2),
    );
  }
}

// ──────────────────────────────────────────────────────────────
// ID Card Showcase
// ──────────────────────────────────────────────────────────────
class _IdCardShowcase extends StatefulWidget {
  @override
  State<_IdCardShowcase> createState() => _IdCardShowcaseState();
}

class _IdCardShowcaseState extends State<_IdCardShowcase>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  bool _showBack = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this,
      duration: const Duration(milliseconds: 600));
  }

  @override
  void dispose() { _controller.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 80, horizontal: 40),
      color: Colors.white,
      child: Column(
        children: [
          _SectionHeader(
            tag: 'ID CARD DESIGNER',
            title: 'Beautiful ID Cards\nWith Custom Themes',
            subtitle: 'Dual-sided, plug & play — change themes in one click',
          ),
          const SizedBox(height: 60),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 60, runSpacing: 40,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              // Card preview
              GestureDetector(
                onTap: () => setState(() => _showBack = !_showBack),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 400),
                  child: _showBack
                    ? _SampleIdCardBack(key: const ValueKey('back'))
                    : _SampleIdCardFront(key: const ValueKey('front')),
                ),
              ),

              // Theme selector + info
              SizedBox(
                width: 380,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Click card to flip', style: GoogleFonts.poppins(
                      fontSize: 13, color: AppTheme.grey600)),
                    const SizedBox(height: 24),

                    for (final feature in [
                      ('Dual-sided design', Icons.flip, 'Design both front and back separately'),
                      ('8 built-in themes', Icons.palette, 'Classic, Modern, Royal, Dark and more'),
                      ('Custom text fields', Icons.text_fields, 'Add any field — bus no, Aadhaar, etc.'),
                      ('QR code + Barcode', Icons.qr_code, 'Instantly scannable for verification'),
                      ('Bulk PDF export', Icons.picture_as_pdf, 'Generate all ID cards in one click'),
                    ])
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Row(children: [
                          Container(
                            width: 40, height: 40,
                            decoration: BoxDecoration(
                              color: AppTheme.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(feature.$2, color: AppTheme.primary, size: 20),
                          ),
                          const SizedBox(width: 16),
                          Expanded(child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(feature.$1, style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w600, fontSize: 14)),
                              Text(feature.$3, style: GoogleFonts.poppins(
                                fontSize: 12, color: AppTheme.grey600)),
                            ],
                          )),
                        ]),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SampleIdCardFront extends StatelessWidget {
  const _SampleIdCardFront({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 320, height: 200,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: AppTheme.cardGradient,
        boxShadow: [
          BoxShadow(color: AppTheme.primary.withOpacity(0.4),
            blurRadius: 30, offset: const Offset(0, 15)),
        ],
      ),
      child: Column(children: [
        // Header
        Container(
          height: 50,
          decoration: const BoxDecoration(
            color: Color(0xFF0D1B63),
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Center(child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('DELHI PUBLIC SCHOOL', style: GoogleFonts.poppins(
                color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
              Text('R.K. Puram, New Delhi', style: GoogleFonts.poppins(
                color: Colors.white.withOpacity(0.8), fontSize: 8)),
            ],
          )),
        ),

        // Body
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(children: [
              // Photo
              Container(
                width: 60, height: 75,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white.withOpacity(0.3)),
                ),
                child: const Icon(Icons.person, color: Colors.white70, size: 32),
              ),
              const SizedBox(width: 12),

              // Info
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('AARAV SHARMA', style: GoogleFonts.poppins(
                    color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  _CardField('ID', 'DPS-STU-00001'),
                  _CardField('Class', '10-A'),
                  _CardField('Roll', 'R001'),
                  _CardField('DOB', '15/03/2010'),
                ],
              )),

              // QR
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 48, height: 48,
                    color: Colors.white,
                    child: const Icon(Icons.qr_code, size: 40, color: Colors.black87),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    width: 48, height: 16,
                    decoration: BoxDecoration(
                      color: Colors.red[700],
                      borderRadius: BorderRadius.circular(2),
                    ),
                    child: Center(child: Text('A+', style: GoogleFonts.poppins(
                      color: Colors.white, fontSize: 8, fontWeight: FontWeight.w700))),
                  ),
                ],
              ),
            ]),
          ),
        ),

        // Footer
        Container(
          height: 28,
          decoration: BoxDecoration(
            color: const Color(0xFF1565C0),
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
          ),
          child: Center(child: Text('STUDENT IDENTITY CARD  •  AY 2025-26',
            style: GoogleFonts.poppins(color: Colors.white, fontSize: 8,
              fontWeight: FontWeight.w500, letterSpacing: 1))),
        ),
      ]),
    );
  }
}

class _SampleIdCardBack extends StatelessWidget {
  const _SampleIdCardBack({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 320, height: 200,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.white,
        border: Border.all(color: AppTheme.primary.withOpacity(0.3), width: 2),
        boxShadow: [
          BoxShadow(color: AppTheme.primary.withOpacity(0.2),
            blurRadius: 30, offset: const Offset(0, 15)),
        ],
      ),
      child: Column(children: [
        Container(
          height: 30, color: AppTheme.primary,
          child: Center(child: Text('CONTACT INFORMATION',
            style: GoogleFonts.poppins(color: Colors.white, fontSize: 9,
              fontWeight: FontWeight.w600, letterSpacing: 1))),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(children: [
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _BackField(Icons.home, 'House No. 42, Sector 5\nNew Delhi - 110022'),
                  _BackField(Icons.phone, '+91 98100 00001'),
                  _BackField(Icons.email, 'parent@gmail.com'),
                  _BackField(Icons.directions_bus, 'Route 7 • Stop: Sector 5'),
                ],
              )),
              Container(
                width: 80,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.qr_code_2, size: 70, color: AppTheme.grey800),
                    Text('Scan to Verify', style: GoogleFonts.poppins(
                      fontSize: 7, color: AppTheme.grey600)),
                  ],
                ),
              ),
            ]),
          ),
        ),
        Container(
          height: 26, color: AppTheme.grey100,
          child: Center(child: Text(
            'If found, please call +91-11-2617-1002 • dps-rkpuram.edu.in',
            style: GoogleFonts.poppins(fontSize: 7.5, color: AppTheme.grey600),
          )),
        ),
      ]),
    );
  }
}

class _CardField extends StatelessWidget {
  final String label, value;
  const _CardField(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(children: [
        Text('$label: ', style: GoogleFonts.poppins(
          color: Colors.white60, fontSize: 9)),
        Text(value, style: GoogleFonts.poppins(
          color: Colors.white, fontSize: 9, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

class _BackField extends StatelessWidget {
  final IconData icon;
  final String text;
  const _BackField(this.icon, this.text);

  @override
  Widget build(BuildContext context) {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, size: 12, color: AppTheme.primary),
      const SizedBox(width: 6),
      Expanded(child: Text(text, style: GoogleFonts.poppins(
        fontSize: 9.5, color: AppTheme.grey800, height: 1.4))),
    ]);
  }
}

// ──────────────────────────────────────────────────────────────
// Testimonials
// ──────────────────────────────────────────────────────────────
class _TestimonialsSection extends StatelessWidget {
  final testimonials = const [
    _Testimonial(
      name: 'Dr. Rajiv Sharma', role: 'Principal, DPS R.K. Puram',
      text: 'SchoolID Pro transformed how we manage 2000+ students. The parent review via WhatsApp is a game changer. Our teachers save 3 hours daily.',
      avatar: '👨‍💼', rating: 5,
    ),
    _Testimonial(
      name: 'Mrs. Sunita Agarwal', role: 'Principal, DPS Rohini',
      text: 'The 8-level org hierarchy perfectly mirrors our school structure. N+1 approval flow is exactly what we needed. Excellent platform!',
      avatar: '👩‍💼', rating: 5,
    ),
    _Testimonial(
      name: 'Mr. Anil Bhatia', role: 'Principal, DPS Dwarka',
      text: 'Bulk upload saved us weeks of data entry. The ID card designer lets us create beautiful cards in minutes. Highly recommended!',
      avatar: '👨‍💼', rating: 5,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 80, horizontal: 40),
      color: AppTheme.grey50,
      child: Column(children: [
        _SectionHeader(
          tag: 'TESTIMONIALS',
          title: 'Trusted by School\nLeaders Across India',
          subtitle: 'Join 500+ schools already using SchoolID Pro',
        ),
        const SizedBox(height: 60),
        Wrap(
          spacing: 24, runSpacing: 24,
          alignment: WrapAlignment.center,
          children: testimonials.map((t) => _TestimonialCard(t)).toList(),
        ),
      ]),
    );
  }
}

class _Testimonial {
  final String name, role, text, avatar;
  final int rating;
  const _Testimonial({required this.name, required this.role,
    required this.text, required this.avatar, required this.rating});
}

class _TestimonialCard extends StatelessWidget {
  final _Testimonial t;
  const _TestimonialCard(this.t);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 340,
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text(t.avatar, style: const TextStyle(fontSize: 36)),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(t.name, style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w700, fontSize: 14)),
                Text(t.role, style: GoogleFonts.poppins(
                  fontSize: 11, color: AppTheme.grey600)),
              ])),
            ]),
            const SizedBox(height: 16),
            Row(children: List.generate(t.rating, (_) =>
              const Icon(Icons.star, color: AppTheme.accentLight, size: 16))),
            const SizedBox(height: 12),
            Text('"${t.text}"', style: GoogleFonts.poppins(
              fontSize: 13, color: AppTheme.grey700, height: 1.7,
              fontStyle: FontStyle.italic)),
          ]),
        ),
      ).animate().fadeIn(delay: 200.ms),
    );
  }
}

// ──────────────────────────────────────────────────────────────
// Pricing
// ──────────────────────────────────────────────────────────────
class _PricingSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 80, horizontal: 40),
      decoration: const BoxDecoration(gradient: AppTheme.primaryGradient),
      child: Column(children: [
        _SectionHeader(
          tag: 'PRICING',
          title: 'Simple, Transparent\nPricing',
          subtitle: 'No hidden fees. Cancel anytime.',
          lightTheme: true,
        ),
        const SizedBox(height: 60),
        Wrap(
          spacing: 24, runSpacing: 24,
          alignment: WrapAlignment.center,
          children: [
            _PriceCard(plan: 'Starter', price: '₹2,999', period: '/year',
              features: ['1 School', '2 Branches', '500 Students',
                         '10 Staff', 'Basic ID Themes', 'Email Support'],
              color: const Color(0xFF1E88E5)),
            _PriceCard(plan: 'School', price: '₹9,999', period: '/year',
              features: ['1 School', '10 Branches', '5,000 Students',
                         'Unlimited Staff', 'All ID Themes', 'WhatsApp + SMS',
                         'Bulk Upload', 'Priority Support'],
              color: AppTheme.accentLight, highlighted: true,
              badge: '🔥 Most Popular'),
            _PriceCard(plan: 'District', price: '₹29,999', period: '/year',
              features: ['50 Schools', 'Unlimited Branches', 'Unlimited Students',
                         'Unlimited Staff', 'Custom Branding', 'API Access',
                         'Dedicated Manager', 'SLA 99.9%'],
              color: const Color(0xFF7B1FA2)),
          ],
        ),
      ]),
    );
  }
}

class _PriceCard extends StatelessWidget {
  final String plan, price, period;
  final List<String> features;
  final Color color;
  final bool highlighted;
  final String? badge;

  const _PriceCard({
    required this.plan, required this.price, required this.period,
    required this.features, required this.color,
    this.highlighted = false, this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 280,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: highlighted ? Colors.white : Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: highlighted ? color : Colors.white.withOpacity(0.15),
          width: highlighted ? 2 : 1,
        ),
        boxShadow: highlighted ? [BoxShadow(
          color: color.withOpacity(0.3), blurRadius: 30, offset: const Offset(0, 15))] : [],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (badge != null) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(badge!, style: GoogleFonts.poppins(fontSize: 11,
              color: highlighted ? color : Colors.white, fontWeight: FontWeight.w600)),
          ),
          const SizedBox(height: 16),
        ],

        Text(plan, style: GoogleFonts.poppins(
          fontSize: 18, fontWeight: FontWeight.w700,
          color: highlighted ? AppTheme.grey900 : Colors.white)),
        const SizedBox(height: 8),

        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(price, style: GoogleFonts.poppins(
            fontSize: 36, fontWeight: FontWeight.w800,
            color: highlighted ? color : Colors.white)),
          Text(period, style: GoogleFonts.poppins(
            fontSize: 14, color: highlighted ? AppTheme.grey600 : Colors.white60)),
        ]),

        const SizedBox(height: 24),
        Divider(color: highlighted ? AppTheme.grey200 : Colors.white.withOpacity(0.2)),
        const SizedBox(height: 16),

        for (final f in features)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(children: [
              Icon(Icons.check_circle, size: 16,
                color: highlighted ? color : Colors.white),
              const SizedBox(width: 10),
              Text(f, style: GoogleFonts.poppins(fontSize: 13,
                color: highlighted ? AppTheme.grey700 : Colors.white.withOpacity(0.85))),
            ]),
          ),

        const SizedBox(height: 24),
        SizedBox(width: double.infinity,
          child: ElevatedButton(
            onPressed: () => GoRouter.of(context).go('/login'),
            style: ElevatedButton.styleFrom(
              backgroundColor: highlighted ? color : Colors.white,
              foregroundColor: highlighted ? Colors.white : AppTheme.primary,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text('Get Started', style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
          )),
      ]),
    );
  }
}

// ──────────────────────────────────────────────────────────────
// About Section
// ──────────────────────────────────────────────────────────────
class _AboutSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 80, horizontal: 40),
      color: Colors.white,
      child: Column(children: [
        _SectionHeader(
          tag: 'ABOUT US',
          title: 'Built for Indian\nSchools by Educators',
          subtitle: 'SchoolID Pro is developed with deep understanding of CBSE school management',
        ),
        const SizedBox(height: 60),
        Wrap(
          spacing: 60, runSpacing: 40,
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: 480,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'SchoolID Pro was created to solve a real problem: managing thousands of student ID cards across multiple branches while keeping parents, teachers, and administrators in sync.',
                    style: GoogleFonts.poppins(fontSize: 15, color: AppTheme.grey700, height: 1.8),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'With an 8-level organizational hierarchy, multi-tenant architecture, and seamless MSG91 integration, we\'ve built the most comprehensive school ID management system in India.',
                    style: GoogleFonts.poppins(fontSize: 15, color: AppTheme.grey700, height: 1.8),
                  ),
                  const SizedBox(height: 32),
                  Wrap(
                    spacing: 16, runSpacing: 12,
                    children: [
                      _AboutBadge('🏆 5 Years Experience'),
                      _AboutBadge('🇮🇳 Made in India'),
                      _AboutBadge('🔒 CBSE Compliant'),
                      _AboutBadge('☁️ Oracle Cloud Powered'),
                    ],
                  ),
                ],
              ),
            ),
            Wrap(
              spacing: 16, runSpacing: 16,
              alignment: WrapAlignment.center,
              children: [
                _AboutStat('500+', 'Schools'),
                _AboutStat('5L+', 'Students'),
                _AboutStat('50K+', 'ID Cards/Day'),
                _AboutStat('99.9%', 'Uptime SLA'),
              ],
            ),
          ],
        ),
      ]),
    );
  }
}

class _AboutBadge extends StatelessWidget {
  final String text;
  const _AboutBadge(this.text);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.primary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.primary.withOpacity(0.2)),
      ),
      child: Text(text, style: GoogleFonts.poppins(
        fontSize: 12, color: AppTheme.primary, fontWeight: FontWeight.w500)),
    );
  }
}

class _AboutStat extends StatelessWidget {
  final String number, label;
  const _AboutStat(this.number, this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 130, height: 100,
      decoration: BoxDecoration(
        gradient: AppTheme.primaryGradient,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(number, style: GoogleFonts.poppins(
            fontSize: 28, fontWeight: FontWeight.w800, color: Colors.white)),
          Text(label, style: GoogleFonts.poppins(
            fontSize: 12, color: Colors.white.withOpacity(0.8))),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────
// Contact Section
// ──────────────────────────────────────────────────────────────
class _ContactSection extends StatelessWidget {
  final _nameCtrl  = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _msgCtrl   = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 80, horizontal: 40),
      color: AppTheme.grey50,
      child: Column(children: [
        _SectionHeader(
          tag: 'CONTACT US',
          title: 'Get in Touch\nWith Our Team',
          subtitle: 'We\'re here to help you get started',
        ),
        const SizedBox(height: 60),
        Wrap(
          spacing: 60, runSpacing: 40,
          alignment: WrapAlignment.center,
          children: [
            // Contact info
            SizedBox(
              width: 300,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ContactInfo(Icons.phone, '+91 98100 00000', 'Call us Mon-Sat, 9AM-6PM'),
                  const SizedBox(height: 24),
                  _ContactInfo(Icons.email, 'hello@schoolidpro.in', 'Email anytime'),
                  const SizedBox(height: 24),
                  _ContactInfo(Icons.chat, '+91 98100 00001', 'WhatsApp support'),
                  const SizedBox(height: 24),
                  _ContactInfo(Icons.location_on, 'New Delhi, India', 'Serving schools nationwide'),
                ],
              ),
            ),

            // Contact form
            SizedBox(
              width: 480,
              child: Card(
                elevation: 4,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(children: [
                    Row(children: [
                      Expanded(child: TextField(
                        controller: _nameCtrl,
                        decoration: const InputDecoration(labelText: 'Full Name', prefixIcon: Icon(Icons.person)),
                      )),
                      const SizedBox(width: 16),
                      Expanded(child: TextField(
                        controller: _phoneCtrl,
                        decoration: const InputDecoration(labelText: 'Phone', prefixIcon: Icon(Icons.phone)),
                      )),
                    ]),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _emailCtrl,
                      decoration: const InputDecoration(labelText: 'Email Address', prefixIcon: Icon(Icons.email)),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _msgCtrl,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        labelText: 'Message', prefixIcon: Icon(Icons.message),
                        alignLabelWithHint: true,
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Message sent! We\'ll contact you shortly.'),
                              backgroundColor: AppTheme.success),
                          );
                        },
                        icon: const Icon(Icons.send),
                        label: const Text('Send Message'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16)),
                      ),
                    ),
                  ]),
                ),
              ),
            ),
          ],
        ),
      ]),
    );
  }
}

class _ContactInfo extends StatelessWidget {
  final IconData icon;
  final String title, subtitle;
  const _ContactInfo(this.icon, this.title, this.subtitle);

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(
        width: 44, height: 44,
        decoration: BoxDecoration(
          color: AppTheme.primary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: AppTheme.primary, size: 22),
      ),
      const SizedBox(width: 14),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: GoogleFonts.poppins(
          fontWeight: FontWeight.w600, fontSize: 14, color: AppTheme.grey900)),
        Text(subtitle, style: GoogleFonts.poppins(
          fontSize: 12, color: AppTheme.grey600)),
      ]),
    ]);
  }
}

// ──────────────────────────────────────────────────────────────
// Footer
// ──────────────────────────────────────────────────────────────
class _Footer extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 40),
      color: AppTheme.grey900,
      child: Column(children: [
        Wrap(
          spacing: 60, runSpacing: 32,
          children: [
            // Brand
            SizedBox(
              width: 260,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      gradient: AppTheme.primaryGradient,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.school, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Text('SchoolID Pro', style: GoogleFonts.poppins(
                    color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
                ]),
                const SizedBox(height: 12),
                Text('Intelligent School Identity Management System. '
                     'Built for Indian schools, powered by Oracle Cloud.',
                  style: GoogleFonts.poppins(
                    fontSize: 12, color: Colors.white.withOpacity(0.6), height: 1.6)),
              ]),
            ),

            // Links
            for (final col in [
              ['Product', 'Features', 'Pricing', 'API Docs', 'Changelog'],
              ['Support', 'Documentation', 'FAQ', 'Contact Us', 'Status Page'],
              ['Company', 'About', 'Blog', 'Careers', 'Privacy Policy'],
            ])
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(col[0], style: GoogleFonts.poppins(
                    color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)),
                  const SizedBox(height: 12),
                  for (final link in col.skip(1))
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(link, style: GoogleFonts.poppins(
                        fontSize: 13, color: Colors.white.withOpacity(0.6))),
                    ),
                ],
              ),
          ],
        ),
        const SizedBox(height: 32),
        Divider(color: Colors.white.withOpacity(0.1)),
        const SizedBox(height: 20),
        Text('© 2026 SchoolID Pro. Made with ❤️ in India. Running on Oracle Cloud Always Free.',
          style: GoogleFonts.poppins(fontSize: 12, color: Colors.white.withOpacity(0.4)),
          textAlign: TextAlign.center),
      ]),
    );
  }
}

// ──────────────────────────────────────────────────────────────
// Shared Widgets
// ──────────────────────────────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  final String tag, title;
  final String? subtitle;
  final bool lightTheme;

  const _SectionHeader({
    required this.tag, required this.title,
    this.subtitle, this.lightTheme = false,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = lightTheme ? Colors.white : AppTheme.grey900;
    final subColor  = lightTheme ? Colors.white.withOpacity(0.75) : AppTheme.grey600;

    return Column(children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: lightTheme ? Colors.white.withOpacity(0.15) : AppTheme.primary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: lightTheme ? Colors.white.withOpacity(0.3) : AppTheme.primary.withOpacity(0.2)),
        ),
        child: Text(tag, style: GoogleFonts.poppins(
          fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 2,
          color: lightTheme ? Colors.white : AppTheme.primary)),
      ),
      const SizedBox(height: 16),
      Text(title,
        textAlign: TextAlign.center,
        style: GoogleFonts.poppins(
          fontSize: 34, fontWeight: FontWeight.w800, color: textColor, height: 1.3)),
      if (subtitle != null) ...[
        const SizedBox(height: 12),
        Text(subtitle!,
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(fontSize: 16, color: subColor, height: 1.5)),
      ],
    ]).animate().fadeIn(delay: 100.ms).slideY(begin: 0.2);
  }
}

class _ResponsiveGrid extends StatelessWidget {
  final int columns;
  final List<Widget> children;

  const _ResponsiveGrid({required this.columns, required this.children});

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i += columns) {
      rows.add(Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var j = i; j < (i + columns).clamp(0, children.length); j++)
            Expanded(child: Padding(
              padding: const EdgeInsets.all(8), child: children[j])),
          if ((i + columns) > children.length)
            for (var k = 0; k < (i + columns - children.length); k++)
              const Expanded(child: SizedBox()),
        ],
      ));
    }
    return Column(children: rows);
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.04)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    const spacing = 40.0;
    for (var x = 0.0; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (var y = 0.0; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_) => false;
}
