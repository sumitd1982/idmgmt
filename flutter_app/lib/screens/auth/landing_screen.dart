// ============================================================
// Landing Screen — Full Marketing Page
// ============================================================
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../config/theme.dart';

// ── Palette ─────────────────────────────────────────────────
const _navy   = Color(0xFF0D1B63);
const _indigo = Color(0xFF1A237E);
const _teal   = Color(0xFF00BCD4);
const _gold   = Color(0xFFFFCA28);
const _sky    = Color(0xFF0EA5E9);
const _green  = Color(0xFF10B981);

class LandingScreen extends StatefulWidget {
  const LandingScreen({super.key});
  @override
  State<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulse;
  final ScrollController _scroll = ScrollController();

  // section keys for nav scroll
  final _heroKey     = GlobalKey();
  final _aboutKey    = GlobalKey();
  final _featuresKey = GlobalKey();
  final _contactKey  = GlobalKey();

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(vsync: this, duration: const Duration(seconds: 2))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _scrollTo(GlobalKey key) {
    final ctx = key.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(ctx,
          duration: 600.ms, curve: Curves.easeInOut);
    }
  }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final isWide = w > 800;

    return Scaffold(
      body: SingleChildScrollView(
        controller: _scroll,
        child: Column(
          children: [
            _NavBar(
              onAbout:    () => _scrollTo(_aboutKey),
              onFeatures: () => _scrollTo(_featuresKey),
              onContact:  () => _scrollTo(_contactKey),
            ),
            _HeroSection(key: _heroKey, pulse: _pulse, isWide: isWide),
            _AboutSection(key: _aboutKey, isWide: isWide),
            _FeaturesSection(key: _featuresKey, isWide: isWide),
            _PortalSection(isWide: isWide),
            _ContactSection(key: _contactKey, isWide: isWide),
            const _Footer(),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// NAV BAR
// ══════════════════════════════════════════════════════════════
class _NavBar extends StatelessWidget {
  final VoidCallback onAbout, onFeatures, onContact;
  const _NavBar({required this.onAbout, required this.onFeatures, required this.onContact});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _navy,
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
      child: Row(
        children: [
          // Logo mark
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: _gold.withOpacity(0.15),
              borderRadius: BorderRadius.circular(9),
              border: Border.all(color: _gold.withOpacity(0.4)),
            ),
            child: const Icon(Icons.school_rounded, color: _gold, size: 20),
          ),
          const SizedBox(width: 10),
          Text('SchoolID Pro',
              style: GoogleFonts.poppins(
                  color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
          const Spacer(),
          _NavLink('About',    onAbout),
          _NavLink('Features', onFeatures),
          _NavLink('Contact',  onContact),
        ],
      ),
    );
  }
}

class _NavLink extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _NavLink(this.label, this.onTap);

  @override
  Widget build(BuildContext context) => TextButton(
        onPressed: onTap,
        child: Text(label,
            style: GoogleFonts.poppins(
                color: Colors.white.withOpacity(0.8), fontSize: 13)),
      );
}

// ══════════════════════════════════════════════════════════════
// HERO
// ══════════════════════════════════════════════════════════════
class _HeroSection extends StatelessWidget {
  final AnimationController pulse;
  final bool isWide;
  const _HeroSection({super.key, required this.pulse, required this.isWide});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [_navy, _indigo, _teal],
          stops: [0.0, 0.55, 1.0],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      padding: EdgeInsets.symmetric(
          horizontal: isWide ? 80 : 24, vertical: isWide ? 100 : 72),
      child: Column(
        children: [
          // Pulsing logo
          ScaleTransition(
            scale: Tween(begin: 1.0, end: 1.07).animate(
                CurvedAnimation(parent: pulse, curve: Curves.easeInOut)),
            child: Container(
              width: 96, height: 96,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.12),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: _gold.withOpacity(0.5), width: 2),
                boxShadow: [
                  BoxShadow(color: _gold.withOpacity(0.2), blurRadius: 30, spreadRadius: 4)
                ],
              ),
              child: const Icon(Icons.school_rounded, color: Colors.white, size: 52),
            ),
          ).animate().scale(delay: 100.ms),

          const SizedBox(height: 28),

          Text('SchoolID Pro',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                  fontSize: isWide ? 56 : 38,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: -1,
                  height: 1.1))
              .animate().fadeIn(delay: 200.ms).slideY(begin: 0.15),

          const SizedBox(height: 14),

          Text('Intelligent School Identity Management',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                  fontSize: isWide ? 20 : 15,
                  color: Colors.white.withOpacity(0.8),
                  fontWeight: FontWeight.w400))
              .animate().fadeIn(delay: 300.ms),

          const SizedBox(height: 10),

          // Gold accent bar
          Container(
            width: 56, height: 4,
            decoration: BoxDecoration(
                color: _gold, borderRadius: BorderRadius.circular(2)),
          ).animate().scaleX(delay: 400.ms),

          const SizedBox(height: 20),

          Text(
            'Streamline your school\'s student identity workflow —\nbulk uploads, custom ID cards, parent approvals & more.',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
                fontSize: isWide ? 16 : 13,
                color: Colors.white.withOpacity(0.65),
                height: 1.7),
          ).animate().fadeIn(delay: 500.ms),

          const SizedBox(height: 40),

          // CTA chips
          Wrap(
            spacing: 16, runSpacing: 12,
            alignment: WrapAlignment.center,
            children: [
              _HeroChip(label: 'Free to Start', icon: Icons.rocket_launch_rounded),
              _HeroChip(label: 'CBSE Compliant', icon: Icons.verified_rounded),
              _HeroChip(label: 'Oracle Cloud Powered', icon: Icons.cloud_rounded),
              _HeroChip(label: '2000+ Students', icon: Icons.groups_rounded),
            ],
          ).animate().fadeIn(delay: 600.ms),

          const SizedBox(height: 48),

          // Portal buttons
          Wrap(
            spacing: 20, runSpacing: 12,
            alignment: WrapAlignment.center,
            children: [
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _sky,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                  textStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14),
                  elevation: 0,
                ),
                onPressed: () => context.go('/login/staff'),
                icon: const Icon(Icons.badge_outlined, size: 18),
                label: const Text('Staff Portal'),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                  textStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14),
                  elevation: 0,
                ),
                onPressed: () => context.go('/login/parent'),
                icon: const Icon(Icons.family_restroom_outlined, size: 18),
                label: const Text('Parent Portal'),
              ),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: _gold,
                  side: const BorderSide(color: _gold, width: 1.5),
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                  textStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14),
                ),
                onPressed: () => context.go('/login/register'),
                icon: const Icon(Icons.account_balance_rounded, size: 18),
                label: const Text('Register School'),
              ),
            ],
          ).animate().fadeIn(delay: 700.ms),

          const SizedBox(height: 60),
        ],
      ),
    );
  }
}

class _HeroChip extends StatelessWidget {
  final String label;
  final IconData icon;
  const _HeroChip({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.2)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: _gold, size: 14),
            const SizedBox(width: 6),
            Text(label,
                style: GoogleFonts.poppins(
                    color: Colors.white.withOpacity(0.85), fontSize: 12)),
          ],
        ),
      );
}

// ══════════════════════════════════════════════════════════════
// ABOUT
// ══════════════════════════════════════════════════════════════
class _AboutSection extends StatelessWidget {
  final bool isWide;
  const _AboutSection({super.key, required this.isWide});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF8F9FF),
      padding: EdgeInsets.symmetric(
          horizontal: isWide ? 80 : 24, vertical: 72),
      child: Column(
        children: [
          _SectionLabel('About Us', _indigo),
          const SizedBox(height: 12),
          Text(
            'Who We Are',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
                fontSize: isWide ? 36 : 26,
                fontWeight: FontWeight.w800,
                color: _navy),
          ),
          const SizedBox(height: 16),
          Container(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Text(
              'SchoolID Pro is India\'s most comprehensive school identity management platform, '
              'purpose-built for the unique needs of CBSE and state-board institutions. '
              'We eliminate paperwork, reduce administrative overhead, and bring the entire '
              'student identity lifecycle — from enrollment to ID card printing — under one '
              'intelligent, cloud-powered roof.\n\n'
              'Built on Oracle Cloud Always Free infrastructure, we ensure enterprise-grade '
              'reliability without the enterprise price tag. Whether you manage 200 or 20,000 '
              'students, SchoolID Pro scales effortlessly with your institution.',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                  fontSize: 14, color: Colors.grey[600], height: 1.9),
            ),
          ),
          const SizedBox(height: 52),
          Wrap(
            spacing: 24, runSpacing: 24,
            alignment: WrapAlignment.center,
            children: const [
              _StatCard(value: '2000+', label: 'Students Managed'),
              _StatCard(value: '8',     label: 'Hierarchy Levels'),
              _StatCard(value: '100%',  label: 'Cloud Native'),
              _StatCard(value: '₹2999', label: 'Per Year Only'),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String value, label;
  const _StatCard({required this.value, required this.label});

  @override
  Widget build(BuildContext context) => Container(
        width: 160,
        padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(color: _navy.withOpacity(0.07), blurRadius: 20, offset: const Offset(0, 6))
          ],
        ),
        child: Column(
          children: [
            Text(value,
                style: GoogleFonts.poppins(
                    fontSize: 32, fontWeight: FontWeight.w900, color: _indigo)),
            const SizedBox(height: 4),
            Text(label,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[500])),
          ],
        ),
      ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.1);
}

// ══════════════════════════════════════════════════════════════
// FEATURES
// ══════════════════════════════════════════════════════════════
class _FeaturesSection extends StatelessWidget {
  final bool isWide;
  const _FeaturesSection({super.key, required this.isWide});

  static const _features = [
    _Feature(Icons.account_tree_rounded,     '8-Level Hierarchy',
        'Define your org from District → School → Grade → Section with fully dynamic, custom roles at every level.', _sky),
    _Feature(Icons.credit_card_rounded,      'Custom ID Card Designer',
        'Drag-and-drop templates, school branding, QR codes, and bulk print-ready PDF export in one click.', _green),
    _Feature(Icons.cloud_upload_rounded,     'Bulk Student Upload',
        'Import thousands of students in seconds via Excel/CSV with smart validation and duplicate detection.', Color(0xFF8B5CF6)),
    _Feature(Icons.message_rounded,          'WhatsApp Parent Review',
        'Parents receive ID card previews directly on WhatsApp and can approve or flag corrections instantly.', Color(0xFF25D366)),
    _Feature(Icons.sync_rounded,             'Real-time Sync',
        'All data syncs instantly across devices — teachers, admins, and parents always see the latest.', _teal),
    _Feature(Icons.shield_rounded,           'Role-Based Access',
        'Granular permission controls ensure each role only sees what they need — no data leaks, no confusion.', Color(0xFFEF4444)),
    _Feature(Icons.directions_bus_rounded,   'Transport Management',
        'Assign routes, buses, and drivers to students. Parents track live location via the parent portal.', Color(0xFFF59E0B)),
    _Feature(Icons.bar_chart_rounded,        'Smart Analytics',
        'Dashboards for attendance, ID issuance rates, pending approvals, and school-wide insights at a glance.', _indigo),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [_navy, _indigo],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      padding: EdgeInsets.symmetric(
          horizontal: isWide ? 80 : 24, vertical: 72),
      child: Column(
        children: [
          _SectionLabel('Features', _gold),
          const SizedBox(height: 12),
          Text('Everything Your School Needs',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                  fontSize: isWide ? 36 : 26,
                  fontWeight: FontWeight.w800,
                  color: Colors.white)),
          const SizedBox(height: 8),
          Text('One platform. Zero paperwork. Total control.',
              style: GoogleFonts.poppins(
                  fontSize: 14, color: Colors.white.withOpacity(0.6))),
          const SizedBox(height: 52),
          Wrap(
            spacing: 20, runSpacing: 20,
            alignment: WrapAlignment.center,
            children: _features
                .map((f) => _FeatureCard(feature: f))
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _Feature {
  final IconData icon;
  final String title, desc;
  final Color color;
  const _Feature(this.icon, this.title, this.desc, this.color);
}

class _FeatureCard extends StatelessWidget {
  final _Feature feature;
  const _FeatureCard({required this.feature});

  @override
  Widget build(BuildContext context) => Container(
        width: 280,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: feature.color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(feature.icon, color: feature.color, size: 26),
            ),
            const SizedBox(height: 16),
            Text(feature.title,
                style: GoogleFonts.poppins(
                    fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
            const SizedBox(height: 8),
            Text(feature.desc,
                style: GoogleFonts.poppins(
                    fontSize: 12.5, color: Colors.white.withOpacity(0.6), height: 1.6)),
          ],
        ),
      ).animate().fadeIn(delay: 150.ms).slideY(begin: 0.08);
}

// ══════════════════════════════════════════════════════════════
// PORTAL CARDS (login entry points)
// ══════════════════════════════════════════════════════════════
class _PortalSection extends StatelessWidget {
  final bool isWide;
  const _PortalSection({required this.isWide});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF8F9FF),
      padding: EdgeInsets.symmetric(
          horizontal: isWide ? 80 : 24, vertical: 72),
      child: Column(
        children: [
          _SectionLabel('Portals', _indigo),
          const SizedBox(height: 12),
          Text('Choose Your Portal',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                  fontSize: isWide ? 36 : 26,
                  fontWeight: FontWeight.w800,
                  color: _navy)),
          const SizedBox(height: 8),
          Text('Dedicated dashboards for every role in your institution.',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey[500])),
          const SizedBox(height: 48),
          Wrap(
            spacing: 24, runSpacing: 24,
            alignment: WrapAlignment.center,
            children: [
              _PortalCard(
                icon: Icons.badge_outlined,
                title: 'Staff Portal',
                subtitle: 'For Teachers, Admins & Transport staff. Manage rosters, IDs, and daily operations.',
                color: _sky,
                onTap: () => context.go('/login/staff'),
                delay: 200,
              ),
              _PortalCard(
                icon: Icons.family_restroom_outlined,
                title: 'Parent Portal',
                subtitle: 'Track your child\'s ID status, approve photos, and stay connected with school.',
                color: _green,
                onTap: () => context.go('/login/parent'),
                delay: 350,
              ),
              _PortalCard(
                icon: Icons.account_balance_rounded,
                title: 'School Admin',
                subtitle: 'Register your institution and set up hierarchy, roles, and staff onboarding.',
                color: _gold,
                onTap: () => context.go('/login/register'),
                delay: 500,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PortalCard extends StatelessWidget {
  final IconData icon;
  final String title, subtitle;
  final Color color;
  final VoidCallback onTap;
  final int delay;
  const _PortalCard({
    required this.icon, required this.title, required this.subtitle,
    required this.color, required this.onTap, required this.delay,
  });

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          width: 280,
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                  color: color.withOpacity(0.12),
                  blurRadius: 28,
                  offset: const Offset(0, 10))
            ],
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: RadialGradient(colors: [
                    color.withOpacity(0.15),
                    color.withOpacity(0.04)
                  ]),
                  shape: BoxShape.circle,
                  border: Border.all(color: color.withOpacity(0.2)),
                ),
                child: Icon(icon, size: 42, color: color),
              ),
              const SizedBox(height: 18),
              Text(title,
                  style: GoogleFonts.poppins(
                      fontSize: 17, fontWeight: FontWeight.w700, color: _navy)),
              const SizedBox(height: 8),
              Text(subtitle,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                      fontSize: 12.5, color: Colors.grey[500], height: 1.5)),
              const SizedBox(height: 22),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Enter Portal',
                        style: GoogleFonts.poppins(
                            fontSize: 12, fontWeight: FontWeight.w600, color: color)),
                    const SizedBox(width: 6),
                    Icon(Icons.arrow_forward_rounded, size: 14, color: color),
                  ],
                ),
              ),
            ],
          ),
        ),
      ).animate().fadeIn(delay: Duration(milliseconds: delay)).slideY(begin: 0.08);
}

// ══════════════════════════════════════════════════════════════
// CONTACT
// ══════════════════════════════════════════════════════════════
class _ContactSection extends StatelessWidget {
  final bool isWide;
  const _ContactSection({super.key, required this.isWide});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [_indigo, _navy],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
      ),
      padding: EdgeInsets.symmetric(
          horizontal: isWide ? 80 : 24, vertical: 72),
      child: Column(
        children: [
          _SectionLabel('Contact Us', _gold),
          const SizedBox(height: 12),
          Text('Get In Touch',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                  fontSize: isWide ? 36 : 26,
                  fontWeight: FontWeight.w800,
                  color: Colors.white)),
          const SizedBox(height: 8),
          Text('We\'d love to hear from you. Reach us any time.',
              style: GoogleFonts.poppins(
                  fontSize: 14, color: Colors.white.withOpacity(0.6))),
          const SizedBox(height: 48),
          Wrap(
            spacing: 24, runSpacing: 24,
            alignment: WrapAlignment.center,
            children: [
              _ContactCard(
                icon: Icons.email_rounded,
                title: 'Email Us',
                detail: 'support@schoolidpro.in',
                color: _sky,
              ),
              _ContactCard(
                icon: Icons.chat_rounded,
                title: 'WhatsApp',
                detail: '+91 98765 43210',
                color: const Color(0xFF25D366),
              ),
              _ContactCard(
                icon: Icons.location_on_rounded,
                title: 'Location',
                detail: 'New Delhi, India',
                color: _gold,
              ),
            ],
          ),
          const SizedBox(height: 48),

          // CTA banner
          Container(
            constraints: const BoxConstraints(maxWidth: 600),
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.07),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _gold.withOpacity(0.3)),
            ),
            child: Column(
              children: [
                Text('Ready to Get Started?',
                    style: GoogleFonts.poppins(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: Colors.white)),
                const SizedBox(height: 8),
                Text(
                  'Register your school today — no credit card required.\nFree setup, full features.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                      fontSize: 13, color: Colors.white.withOpacity(0.65), height: 1.6),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _gold,
                    foregroundColor: _navy,
                    padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30)),
                    textStyle: GoogleFonts.poppins(
                        fontWeight: FontWeight.w700, fontSize: 15),
                    elevation: 0,
                  ),
                  onPressed: () => context.go('/login/register'),
                  child: const Text('Register Your School Free'),
                ),
              ],
            ),
          ).animate().fadeIn(delay: 400.ms),
        ],
      ),
    );
  }
}

class _ContactCard extends StatelessWidget {
  final IconData icon;
  final String title, detail;
  final Color color;
  const _ContactCard(
      {required this.icon, required this.title, required this.detail, required this.color});

  @override
  Widget build(BuildContext context) => Container(
        width: 200,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.07),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.25)),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                  color: color.withOpacity(0.15), shape: BoxShape.circle),
              child: Icon(icon, color: color, size: 26),
            ),
            const SizedBox(height: 14),
            Text(title,
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                    fontSize: 14)),
            const SizedBox(height: 4),
            Text(detail,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.white.withOpacity(0.55))),
          ],
        ),
      ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.1);
}

// ══════════════════════════════════════════════════════════════
// FOOTER
// ══════════════════════════════════════════════════════════════
class _Footer extends StatelessWidget {
  const _Footer();

  @override
  Widget build(BuildContext context) => Container(
        color: const Color(0xFF070E38),
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 28),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.school_rounded, color: _gold, size: 18),
                const SizedBox(width: 8),
                Text('SchoolID Pro',
                    style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 15)),
              ],
            ),
            const SizedBox(height: 10),
            Text('India\'s most comprehensive school identity management system.',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                    fontSize: 12, color: Colors.white.withOpacity(0.4))),
            const SizedBox(height: 16),
            Divider(color: Colors.white.withOpacity(0.08)),
            const SizedBox(height: 12),
            Text('© ${DateTime.now().year} SchoolID Pro · Powered by Oracle Cloud Always Free · CBSE Compliant',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                    fontSize: 11, color: Colors.white.withOpacity(0.3))),
          ],
        ),
      );
}

// ══════════════════════════════════════════════════════════════
// SHARED HELPERS
// ══════════════════════════════════════════════════════════════
class _SectionLabel extends StatelessWidget {
  final String text;
  final Color color;
  const _SectionLabel(this.text, this.color);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Text(text.toUpperCase(),
            style: GoogleFonts.poppins(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: color,
                letterSpacing: 1.5)),
      );
}
