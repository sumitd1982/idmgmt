// ============================================================
// Theme Settings Screen — 10 themes, 5 layouts, role-based
// ============================================================
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../config/theme.dart';
import '../../models/portal_theme_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/theme_provider.dart';

class ThemeSettingsScreen extends ConsumerWidget {
  const ThemeSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ts       = ref.watch(themeProvider);
    final user     = ref.watch(authNotifierProvider).valueOrNull;
    final role     = user?.role ?? '';
    final isSuperAdmin   = role == 'super_admin';
    final isSchoolAdmin  = role == 'school_owner' || role == 'principal' || role == 'vp';
    final schoolId = user?.schoolId;

    return Scaffold(
      backgroundColor: AppTheme.grey50,
      appBar: AppBar(
        title: Text('Appearance & Theme',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 16)),
        backgroundColor: Colors.white,
        foregroundColor: AppTheme.grey900,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppTheme.grey200),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
        children: [

          // ── Super Admin — Portal Default ─────────────────────
          if (isSuperAdmin) ...[
            _SectionLabel(
              icon: Icons.admin_panel_settings_outlined,
              title: 'Portal-Wide Default (Super Admin)',
              subtitle: 'This becomes the default theme for all schools and users who have not set their own.',
              color: AppTheme.error,
            ),
            const SizedBox(height: 16),
            _ThemeGrid(
              selected: ts.portalTheme,
              onSelect: (t) async {
                await ref.read(themeProvider.notifier).setGlobalDefault(t);
                await ref.read(themeProvider.notifier).updatePortalTheme(t);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Portal default set to "${t.name}"'),
                      backgroundColor: AppTheme.success,
                    ),
                  );
                }
              },
            ),
            const SizedBox(height: 36),
          ],

          // ── School Admin — School Default ─────────────────────
          if (isSchoolAdmin && schoolId != null) ...[
            _SectionLabel(
              icon: Icons.school_outlined,
              title: 'School Default',
              subtitle: 'Override the portal default for your school\'s employees and students.',
              color: AppTheme.primary,
            ),
            const SizedBox(height: 16),
            _ThemeGrid(
              selected: ts.portalTheme,
              onSelect: (t) async {
                await ref.read(themeProvider.notifier).setSchoolDefault(schoolId, t, ts.layout);
                await ref.read(themeProvider.notifier).updatePortalTheme(t);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('School default set to "${t.name}"'),
                      backgroundColor: AppTheme.success,
                    ),
                  );
                }
              },
            ),
            const SizedBox(height: 36),
          ],

          // ── Personal Theme ────────────────────────────────────
          _SectionLabel(
            icon: Icons.palette_outlined,
            title: 'Your Theme',
            subtitle: 'Your personal choice overrides the school default.',
            color: AppTheme.secondary,
          ),
          const SizedBox(height: 16),
          _ThemeGrid(
            selected: ts.portalTheme,
            onSelect: (t) => ref.read(themeProvider.notifier).updatePortalTheme(t),
          ),
          const SizedBox(height: 36),

          // ── Layout ───────────────────────────────────────────
          _SectionLabel(
            icon: Icons.dashboard_customize_outlined,
            title: 'Layout',
            subtitle: 'Choose how the navigation and content are arranged.',
            color: AppTheme.accent,
          ),
          const SizedBox(height: 16),
          _LayoutGrid(
            selected: ts.layout,
            onSelect: (l) => ref.read(themeProvider.notifier).updateLayout(l),
          ),
          const SizedBox(height: 36),

          // ── Light / Dark Mode ────────────────────────────────
          _SectionLabel(
            icon: Icons.brightness_6_outlined,
            title: 'Brightness',
            subtitle: 'Override the theme\'s built-in brightness setting.',
            color: AppTheme.grey700,
          ),
          const SizedBox(height: 12),
          _Card(
            child: Column(
              children: ThemeMode.values.map((m) {
                final icons = [Icons.brightness_auto, Icons.light_mode_outlined, Icons.dark_mode_outlined];
                final labels = ['Follow System', 'Light Mode', 'Dark Mode'];
                final idx = ThemeMode.values.indexOf(m);
                return RadioListTile<ThemeMode>(
                  value: m,
                  groupValue: ts.mode,
                  title: Row(children: [
                    Icon(icons[idx], size: 18, color: AppTheme.grey600),
                    const SizedBox(width: 10),
                    Text(labels[idx], style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w500)),
                  ]),
                  onChanged: (v) => ref.read(themeProvider.notifier).updateMode(v!),
                  activeColor: AppTheme.primary,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                );
              }).toList(),
            ),
          ),

          const SizedBox(height: 40),
          Center(
            child: Text(
              'Changes are saved automatically.',
              style: GoogleFonts.poppins(color: AppTheme.grey500, fontSize: 12),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

// ── Theme Grid ────────────────────────────────────────────────
class _ThemeGrid extends StatelessWidget {
  final PortalTheme selected;
  final ValueChanged<PortalTheme> onSelect;

  const _ThemeGrid({required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (ctx, constraints) {
      final cols = constraints.maxWidth > 700 ? 4 : constraints.maxWidth > 450 ? 3 : 2;
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: cols,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 0.85,
        ),
        itemCount: PortalThemes.all.length,
        itemBuilder: (_, i) {
          final theme = PortalThemes.all[i];
          final isSelected = theme.id == selected.id;
          return _ThemeCard(theme: theme, isSelected: isSelected, onTap: () => onSelect(theme));
        },
      );
    });
  }
}

class _ThemeCard extends StatelessWidget {
  final PortalTheme theme;
  final bool isSelected;
  final VoidCallback onTap;

  const _ThemeCard({required this.theme, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? theme.primaryColor : AppTheme.grey200,
            width: isSelected ? 2.5 : 1,
          ),
          boxShadow: isSelected
              ? [BoxShadow(color: theme.primaryColor.withOpacity(0.25), blurRadius: 12, offset: const Offset(0, 4))]
              : [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6)],
        ),
        child: Column(
          children: [
            // Preview mini-UI
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(13)),
                child: _MiniPreview(theme: theme),
              ),
            ),
            // Name + checkmark
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Row(children: [
                Expanded(
                  child: Text(
                    theme.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: isSelected ? theme.primaryColor : AppTheme.grey800,
                    ),
                  ),
                ),
                if (isSelected)
                  Icon(Icons.check_circle, size: 16, color: theme.primaryColor),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniPreview extends StatelessWidget {
  final PortalTheme theme;
  const _MiniPreview({required this.theme});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: theme.bodyColor,
      child: Column(children: [
        // Header bar
        Container(
          height: 18,
          color: theme.headerColor,
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Row(children: [
            Container(width: 6, height: 6, decoration: BoxDecoration(color: Colors.white.withOpacity(0.7), shape: BoxShape.circle)),
            const SizedBox(width: 3),
            Expanded(child: Container(height: 4, decoration: BoxDecoration(color: Colors.white.withOpacity(0.3), borderRadius: BorderRadius.circular(2)))),
          ]),
        ),
        // Body row: sidebar + content
        Expanded(
          child: Row(children: [
            // Sidebar / menu
            Container(
              width: 22,
              color: theme.menuColor,
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 3),
              child: Column(children: [
                for (int i = 0; i < 4; i++) ...[
                  Container(
                    height: 4,
                    decoration: BoxDecoration(
                      color: i == 0 ? theme.accentColor : Colors.white.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 4),
                ],
              ]),
            ),
            // Content area
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Container(height: 5, width: 40, decoration: BoxDecoration(color: theme.primaryColor.withOpacity(0.8), borderRadius: BorderRadius.circular(2))),
                  const SizedBox(height: 4),
                  Row(children: [
                    for (int i = 0; i < 2; i++) ...[
                      Expanded(child: Container(
                        height: 20,
                        decoration: BoxDecoration(
                          color: theme.cardColor,
                          borderRadius: BorderRadius.circular(3),
                          border: Border.all(color: Colors.black.withOpacity(0.05)),
                        ),
                      )),
                      if (i == 0) const SizedBox(width: 3),
                    ],
                  ]),
                  const SizedBox(height: 4),
                  Container(height: 14, decoration: BoxDecoration(color: theme.cardColor, borderRadius: BorderRadius.circular(3), border: Border.all(color: Colors.black.withOpacity(0.05)))),
                ]),
              ),
            ),
          ]),
        ),
        // Footer
        Container(
          height: 8,
          color: theme.footerColor,
        ),
      ]),
    );
  }
}

// ── Layout Grid ───────────────────────────────────────────────
class _LayoutGrid extends StatelessWidget {
  final AppLayout selected;
  final ValueChanged<AppLayout> onSelect;

  const _LayoutGrid({required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (ctx, c) {
      final cols = c.maxWidth > 600 ? 5 : c.maxWidth > 400 ? 3 : 2;
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: cols,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 0.9,
        ),
        itemCount: AppLayout.values.length,
        itemBuilder: (_, i) {
          final layout = AppLayout.values[i];
          final sel = layout == selected;
          return GestureDetector(
            onTap: () => onSelect(layout),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              decoration: BoxDecoration(
                color: sel ? AppTheme.primary.withOpacity(0.06) : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: sel ? AppTheme.primary : AppTheme.grey200,
                  width: sel ? 2 : 1,
                ),
              ),
              padding: const EdgeInsets.all(10),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(layout.icon,
                      size: 30,
                      color: sel ? AppTheme.primary : AppTheme.grey500),
                  const SizedBox(height: 6),
                  Text(layout.label,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                        color: sel ? AppTheme.primary : AppTheme.grey700,
                      )),
                  const SizedBox(height: 3),
                  Text(layout.description,
                      maxLines: 2,
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(fontSize: 8.5, color: AppTheme.grey500)),
                ],
              ),
            ),
          );
        },
      );
    });
  }
}

// ── Shared Widgets ────────────────────────────────────────────
class _SectionLabel extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;

  const _SectionLabel({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        width: 36, height: 36,
        decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, size: 18, color: color),
      ),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.grey900)),
        const SizedBox(height: 2),
        Text(subtitle, style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.grey600)),
      ])),
    ]);
  }
}

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.grey200),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 3))],
      ),
      child: ClipRRect(borderRadius: BorderRadius.circular(14), child: child),
    );
  }
}
