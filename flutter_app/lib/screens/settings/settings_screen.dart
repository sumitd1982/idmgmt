// ============================================================
// Settings Hub Screen
// ============================================================
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../config/theme.dart';
import '../../providers/auth_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user   = ref.watch(authNotifierProvider).valueOrNull;
    final role   = user?.role ?? '';

    final bool canCustomizeMenu      = ['super_admin', 'school_admin', 'school_owner', 'principal'].contains(role);
    final bool canCustomizeDashboard = ['super_admin', 'school_owner', 'principal', 'branch_admin'].contains(role);
    final bool canCustomizeTemplates = ['super_admin', 'school_admin', 'school_owner', 'branch_admin'].contains(role);

    return Scaffold(
      backgroundColor: AppTheme.grey50,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            backgroundColor: const Color(0xFF0D1B63),
            foregroundColor: Colors.white,
            expandedHeight: 140,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              title: Text('Settings',
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 18,
                )),
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF0D1B63), Color(0xFF1565C0)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(20),
            sliver: SliverList(
              delegate: SliverChildListDelegate([

                // ── Appearance ─────────────────────────────
                _SectionHeader(title: 'Appearance'),
                _SettingsTile(
                  icon: Icons.palette_outlined,
                  iconColor: const Color(0xFF7C4DFF),
                  title: 'Theme & Layout',
                  subtitle: 'Colors, dark mode, and navigation style',
                  onTap: () => context.go('/settings/theme'),
                ),

                const SizedBox(height: 20),

                // ── Customization (role-gated) ──────────────
                if (canCustomizeMenu || canCustomizeDashboard || canCustomizeTemplates) ...[
                  _SectionHeader(title: 'Customization'),
                  if (canCustomizeMenu)
                    _SettingsTile(
                      icon: Icons.menu_outlined,
                      iconColor: const Color(0xFF00897B),
                      title: 'Menu Layout',
                      subtitle: 'Show, hide, and reorder navigation items per role',
                      onTap: () => context.go('/settings/menu-layout'),
                    ),
                  if (canCustomizeDashboard)
                    _SettingsTile(
                      icon: Icons.dashboard_customize_outlined,
                      iconColor: const Color(0xFF1565C0),
                      title: 'Dashboard Widgets',
                      subtitle: 'Configure which widgets appear on the dashboard',
                      onTap: () => context.go('/settings/dashboard-widgets'),
                    ),
                  if (canCustomizeTemplates) ...[
                    _SettingsTile(
                      icon: Icons.person_pin_outlined,
                      iconColor: const Color(0xFFE65100),
                      title: 'Student Review Templates',
                      subtitle: 'Manage templates for student data review screens',
                      onTap: () => context.go('/settings/review-templates?type=student'),
                    ),
                    _SettingsTile(
                      icon: Icons.badge_outlined,
                      iconColor: const Color(0xFF6A1B9A),
                      title: 'Teacher Review Templates',
                      subtitle: 'Manage templates for teacher data review screens',
                      onTap: () => context.go('/settings/review-templates?type=teacher'),
                    ),
                  ],
                  const SizedBox(height: 20),
                ],

                // ── Account ────────────────────────────────
                _SectionHeader(title: 'Account'),
                _SettingsTile(
                  icon: Icons.person_outline,
                  iconColor: AppTheme.grey600,
                  title: 'Profile',
                  subtitle: 'Name, email, and contact details',
                  onTap: () {},
                ),
                _SettingsTile(
                  icon: Icons.logout,
                  iconColor: AppTheme.error,
                  title: 'Sign Out',
                  subtitle: 'Sign out of your account',
                  onTap: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Sign Out'),
                        content: const Text('Are you sure you want to sign out?'),
                        actions: [
                          TextButton(onPressed: () => ctx.pop(false), child: const Text('Cancel')),
                          TextButton(
                            onPressed: () => ctx.pop(true),
                            child: const Text('Sign Out', style: TextStyle(color: AppTheme.error)),
                          ),
                        ],
                      ),
                    );
                    if (confirm == true && context.mounted) {
                      await ref.read(authNotifierProvider.notifier).signOut();
                    }
                  },
                ),

                const SizedBox(height: 40),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8, left: 4),
        child: Text(title,
          style: GoogleFonts.poppins(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppTheme.grey600,
            letterSpacing: 0.8,
          ).copyWith(color: AppTheme.grey600),
        ),
      );
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _SettingsTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Card(
        elevation: 0,
        color: Colors.white,
        margin: const EdgeInsets.only(bottom: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          title: Text(title,
            style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w500)),
          subtitle: Text(subtitle,
            style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.grey600)),
          trailing: const Icon(Icons.chevron_right, color: AppTheme.grey400),
          onTap: onTap,
        ),
      );
}
