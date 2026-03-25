// ============================================================
// Theme Settings Screen — Spectacular Redesign
// Fonts: Playfair Display · Raleway · Inter · Poppins
// Sections: Mode Cards · Palette Scroll · Layout Illustrator
// ============================================================
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../config/theme.dart';
import '../../models/portal_theme_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/theme_provider.dart';

class ThemeSettingsScreen extends ConsumerStatefulWidget {
  const ThemeSettingsScreen({super.key});

  @override
  ConsumerState<ThemeSettingsScreen> createState() => _ThemeSettingsScreenState();
}

class _ThemeSettingsScreenState extends ConsumerState<ThemeSettingsScreen>
    with TickerProviderStateMixin {
  late TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ts            = ref.watch(themeProvider);
    final user          = ref.watch(authNotifierProvider).valueOrNull;
    final role          = user?.role ?? '';
    final isSuperAdmin  = role == 'super_admin';
    final isSchoolAdmin = role == 'school_owner' || role == 'principal' || role == 'vp';
    final schoolId      = user?.schoolId;

    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F8),
      body: NestedScrollView(
        headerSliverBuilder: (context, _) => [
          // ── Hero Header ────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            backgroundColor: const Color(0xFF0D1B63),
            foregroundColor: Colors.white,
            flexibleSpace: FlexibleSpaceBar(
              collapseMode: CollapseMode.parallax,
              background: _HeroHeader(ts: ts),
            ),
            title: Text('Appearance',
              style: GoogleFonts.playfairDisplay(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 20,
                fontStyle: FontStyle.italic,
              )),
            bottom: _ColorfulTabBar(controller: _tabCtrl),
          ),
        ],
        body: TabBarView(
          controller: _tabCtrl,
          children: [
            // ── Tab 1: Brightness Mode ─────────────────────────
            _ModeTab(ts: ts, ref: ref),

            // ── Tab 2: Color Palette ────────────────────────────
            _PaletteTab(
              ts: ts,
              ref: ref,
              isSuperAdmin: isSuperAdmin,
              isSchoolAdmin: isSchoolAdmin,
              schoolId: schoolId,
            ),

            // ── Tab 3: Layout ───────────────────────────────────
            _LayoutTab(ts: ts, ref: ref),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Hero Header
// ─────────────────────────────────────────────────────────────
class _HeroHeader extends StatelessWidget {
  final ThemeSettings ts;
  const _HeroHeader({required this.ts});

  @override
  Widget build(BuildContext context) {
    final theme = ts.portalTheme;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 600),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.headerColor,
            theme.menuColor,
            theme.primaryColor.withOpacity(0.8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        children: [
          // Decorative blobs
          Positioned(top: -40, right: -40,
            child: _Blob(120, Colors.white.withOpacity(0.05))),
          Positioned(bottom: 10, left: -30,
            child: _Blob(90, theme.accentColor.withOpacity(0.15))),
          Positioned(top: 40, right: 80,
            child: _Blob(50, Colors.white.withOpacity(0.08))),
          Positioned(bottom: 30, right: 20,
            child: _Blob(30, theme.accentColor.withOpacity(0.2))),

          // Text content
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 52, 24, 16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Make it yours',
                  style: GoogleFonts.playfairDisplay(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    fontStyle: FontStyle.italic,
                    height: 1.1,
                  )),
                const SizedBox(height: 6),
                Text(
                  'Active: ${theme.name}  ·  ${ts.layout.label} layout  ·  ${_modeLabel(ts.mode)}',
                  style: GoogleFonts.inter(
                    color: Colors.white70,
                    fontSize: 12,
                    letterSpacing: 0.3,
                  )),
                const SizedBox(height: 12),
                // Color strip of active theme
                Row(children: [
                  _ThemeColorDot(theme.headerColor),
                  _ThemeColorDot(theme.menuColor),
                  _ThemeColorDot(theme.primaryColor),
                  _ThemeColorDot(theme.accentColor),
                  _ThemeColorDot(theme.bodyColor),
                  _ThemeColorDot(theme.cardColor),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white30),
                    ),
                    child: Text('Live Preview',
                      style: GoogleFonts.inter(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w500)),
                  ),
                ]),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _modeLabel(ThemeMode m) {
    switch (m) {
      case ThemeMode.light:  return 'Light';
      case ThemeMode.dark:   return 'Dark';
      default:               return 'System';
    }
  }
}

// ─────────────────────────────────────────────────────────────
// Colorful Tab Bar
// ─────────────────────────────────────────────────────────────
class _ColorfulTabBar extends StatelessWidget implements PreferredSizeWidget {
  final TabController controller;
  const _ColorfulTabBar({required this.controller});

  @override
  Size get preferredSize => const Size.fromHeight(56);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        border: Border(top: BorderSide(color: Colors.white.withOpacity(0.15))),
      ),
      child: TabBar(
        controller: controller,
        dividerColor: Colors.transparent,
        indicator: BoxDecoration(
          color: Colors.white.withOpacity(0.2),
          borderRadius: BorderRadius.circular(8),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white54,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        tabs: [
          _Tab(icon: Icons.brightness_medium_rounded, label: 'MODE'),
          _Tab(icon: Icons.palette_rounded,            label: 'PALETTE'),
          _Tab(icon: Icons.dashboard_customize_rounded,label: 'LAYOUT'),
        ],
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  final IconData icon;
  final String label;
  const _Tab({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Tab(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 16),
          const SizedBox(width: 6),
          Text(label, style: GoogleFonts.raleway(fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1.0)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Tab 1 — Mode (Brightness)
// ─────────────────────────────────────────────────────────────
class _ModeTab extends StatelessWidget {
  final ThemeSettings ts;
  final WidgetRef ref;
  const _ModeTab({required this.ts, required this.ref});

  @override
  Widget build(BuildContext context) {
    final modes = [
      _ModeOption(
        mode: ThemeMode.system,
        icon: Icons.brightness_auto_rounded,
        label: 'Follow System',
        subtitle: 'Automatically matches your device setting',
        gradientColors: [const Color(0xFF1A237E), const Color(0xFF4A148C), const Color(0xFF6A1B9A)],
        glowColor: const Color(0xFF7B1FA2),
        emoji: '🌐',
      ),
      _ModeOption(
        mode: ThemeMode.light,
        icon: Icons.light_mode_rounded,
        label: 'Light Mode',
        subtitle: 'Bright, clean and energising for daily use',
        gradientColors: [const Color(0xFFFF8F00), const Color(0xFFFFB300), const Color(0xFFFFCA28)],
        glowColor: const Color(0xFFFF8F00),
        emoji: '☀️',
      ),
      _ModeOption(
        mode: ThemeMode.dark,
        icon: Icons.dark_mode_rounded,
        label: 'Dark Mode',
        subtitle: 'Easy on eyes — perfect for night sessions',
        gradientColors: [const Color(0xFF0A0A1A), const Color(0xFF0D1B63), const Color(0xFF1A237E)],
        glowColor: const Color(0xFF3F51B5),
        emoji: '🌙',
      ),
    ];

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
      children: [
        _TabSectionHeading(
          icon: Icons.brightness_medium_rounded,
          title: 'Display Mode',
          subtitle: 'Control how the app looks in any lighting',
        ),
        const SizedBox(height: 20),
        ...modes.map((opt) {
          final selected = ts.mode == opt.mode;
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: _ModeCard(
              option: opt,
              selected: selected,
              onTap: () => ref.read(themeProvider.notifier).updateMode(opt.mode),
            ),
          );
        }),

        const SizedBox(height: 8),
        _InfoBadge(
          icon: Icons.info_outline_rounded,
          text: 'Mode is applied on top of your chosen colour theme.',
        ),
      ],
    );
  }
}

class _ModeOption {
  final ThemeMode mode;
  final IconData icon;
  final String label;
  final String subtitle;
  final List<Color> gradientColors;
  final Color glowColor;
  final String emoji;

  const _ModeOption({
    required this.mode,
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.gradientColors,
    required this.glowColor,
    required this.emoji,
  });
}

class _ModeCard extends StatelessWidget {
  final _ModeOption option;
  final bool selected;
  final VoidCallback onTap;
  const _ModeCard({required this.option, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        height: 110,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: selected
                ? option.gradientColors
                : [const Color(0xFFFFFFFF), const Color(0xFFF5F5F5)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? option.glowColor : const Color(0xFFE0E0E0),
            width: selected ? 2.5 : 1,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: option.glowColor.withOpacity(0.45),
                    blurRadius: 20,
                    offset: const Offset(0, 6),
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
        ),
        child: Stack(
          children: [
            // Background emoji watermark
            Positioned(
              right: 16, top: -4,
              child: Text(option.emoji,
                style: TextStyle(fontSize: selected ? 72 : 56, height: 1),
              ),
            ),
            // Content
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
              child: Row(
                children: [
                  Container(
                    width: 52, height: 52,
                    decoration: BoxDecoration(
                      color: selected ? Colors.white.withOpacity(0.2) : option.glowColor.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(option.icon,
                      size: 26,
                      color: selected ? Colors.white : option.glowColor,
                    ),
                  ),
                  const SizedBox(width: 18),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(option.label,
                          style: GoogleFonts.raleway(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: selected ? Colors.white : const Color(0xFF1A1A2E),
                          )),
                        const SizedBox(height: 4),
                        Text(option.subtitle,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: selected ? Colors.white70 : const Color(0xFF757575),
                            height: 1.4,
                          )),
                      ],
                    ),
                  ),
                  if (selected)
                    Container(
                      width: 28, height: 28,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.check_rounded, size: 18, color: option.glowColor),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Tab 2 — Palette
// ─────────────────────────────────────────────────────────────
class _PaletteTab extends StatelessWidget {
  final ThemeSettings ts;
  final WidgetRef ref;
  final bool isSuperAdmin;
  final bool isSchoolAdmin;
  final String? schoolId;

  const _PaletteTab({
    required this.ts,
    required this.ref,
    required this.isSuperAdmin,
    required this.isSchoolAdmin,
    required this.schoolId,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(0, 24, 0, 40),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: _TabSectionHeading(
            icon: Icons.palette_rounded,
            title: 'Colour Palettes',
            subtitle: 'Pick a personality that fits your style',
          ),
        ),
        const SizedBox(height: 16),

        // ── Quick Swatch Strip ──────────────────────────────────
        SizedBox(
          height: 64,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: PortalThemes.all.length,
            itemBuilder: (_, i) {
              final t = PortalThemes.all[i];
              final sel = t.id == ts.portalTheme.id;
              return GestureDetector(
                onTap: () => ref.read(themeProvider.notifier).updatePortalTheme(t),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  margin: const EdgeInsets.only(right: 12),
                  width: sel ? 64 : 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [t.headerColor, t.accentColor],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(sel ? 16 : 24),
                    border: Border.all(
                      color: sel ? Colors.white : Colors.transparent,
                      width: 2.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: t.primaryColor.withOpacity(sel ? 0.5 : 0.2),
                        blurRadius: sel ? 14 : 4,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: sel
                      ? const Icon(Icons.check_rounded, color: Colors.white, size: 22)
                      : null,
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 24),

        // ── Persona label (selected theme name) ────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [ts.portalTheme.headerColor, ts.portalTheme.accentColor],
                  begin: Alignment.centerLeft, end: Alignment.centerRight,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(ts.portalTheme.name,
                style: GoogleFonts.raleway(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(ts.portalTheme.description,
              style: GoogleFonts.inter(color: const Color(0xFF757575), fontSize: 12))),
          ]),
        ),
        const SizedBox(height: 20),

        // ── Super Admin global default ──────────────────────────
        if (isSuperAdmin) ...[
          _AdminBanner(
            icon: Icons.admin_panel_settings_rounded,
            label: 'Portal Default  (Super Admin)',
            color: AppTheme.error,
          ),
          const SizedBox(height: 12),
          _PaletteGrid(
            selected: ts.portalTheme,
            onSelect: (t) async {
              await ref.read(themeProvider.notifier).setGlobalDefault(t);
              await ref.read(themeProvider.notifier).updatePortalTheme(t);
            },
          ),
          const SizedBox(height: 28),
        ],

        // ── School Admin default ────────────────────────────────
        if (isSchoolAdmin && schoolId != null) ...[
          _AdminBanner(
            icon: Icons.school_rounded,
            label: 'School Default',
            color: AppTheme.primary,
          ),
          const SizedBox(height: 12),
          _PaletteGrid(
            selected: ts.portalTheme,
            onSelect: (t) async {
              await ref.read(themeProvider.notifier).setSchoolDefault(schoolId!, t, ts.layout);
              await ref.read(themeProvider.notifier).updatePortalTheme(t);
            },
          ),
          const SizedBox(height: 28),
        ],

        // ── Personal Theme ──────────────────────────────────────
        if (!isSuperAdmin && !(isSchoolAdmin && schoolId != null)) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _PaletteGrid(
              selected: ts.portalTheme,
              onSelect: (t) => ref.read(themeProvider.notifier).updatePortalTheme(t),
            ),
          ),
        ] else ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _AdminBanner(icon: Icons.person_outline_rounded, label: 'Your Personal Theme', color: AppTheme.secondary),
              const SizedBox(height: 12),
              _PaletteGrid(
                selected: ts.portalTheme,
                onSelect: (t) => ref.read(themeProvider.notifier).updatePortalTheme(t),
              ),
            ]),
          ),
        ],

        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: _InfoBadge(
            icon: Icons.auto_awesome_rounded,
            text: 'The header, sidebar, cards and footer all update with your chosen palette.',
          ),
        ),
      ],
    );
  }
}

class _PaletteGrid extends StatelessWidget {
  final PortalTheme selected;
  final ValueChanged<PortalTheme> onSelect;
  const _PaletteGrid({required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (ctx, c) {
      final cols = c.maxWidth > 700 ? 4 : c.maxWidth > 450 ? 3 : 2;
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: cols,
          mainAxisSpacing: 14,
          crossAxisSpacing: 14,
          childAspectRatio: 0.78,
        ),
        itemCount: PortalThemes.all.length,
        itemBuilder: (_, i) {
          final t = PortalThemes.all[i];
          final sel = t.id == selected.id;
          return _PaletteCard(theme: t, isSelected: sel, onTap: () => onSelect(t));
        },
      );
    });
  }
}

class _PaletteCard extends StatelessWidget {
  final PortalTheme theme;
  final bool isSelected;
  final VoidCallback onTap;
  const _PaletteCard({required this.theme, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected ? theme.primaryColor : Colors.transparent,
            width: isSelected ? 2.5 : 0,
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected
                  ? theme.primaryColor.withOpacity(0.35)
                  : Colors.black.withOpacity(0.06),
              blurRadius: isSelected ? 18 : 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            // Gradient preview header
            Expanded(
              flex: 5,
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(17)),
                child: _RichMiniPreview(theme: theme),
              ),
            ),
            // Name row
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Text(theme.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.raleway(
                          fontSize: 10.5,
                          fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                          color: isSelected ? theme.primaryColor : const Color(0xFF424242),
                          height: 1.2,
                        )),
                    ),
                    if (isSelected)
                      Container(
                        width: 20, height: 20,
                        decoration: BoxDecoration(
                          color: theme.primaryColor,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.check_rounded, size: 13, color: Colors.white),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RichMiniPreview extends StatelessWidget {
  final PortalTheme theme;
  const _RichMiniPreview({required this.theme});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: theme.bodyColor,
      child: Column(children: [
        // Header
        Container(
          height: 22,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [theme.headerColor, theme.menuColor],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Row(children: [
            Container(width: 7, height: 7,
              decoration: BoxDecoration(color: theme.accentColor, shape: BoxShape.circle)),
            const SizedBox(width: 4),
            Expanded(child: Container(height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.35),
                borderRadius: BorderRadius.circular(2),
              ))),
            const SizedBox(width: 4),
            Container(width: 14, height: 8,
              decoration: BoxDecoration(
                color: theme.accentColor.withOpacity(0.8),
                borderRadius: BorderRadius.circular(3),
              )),
          ]),
        ),
        // Body
        Expanded(child: Row(children: [
          // Sidebar
          Container(
            width: 24,
            color: theme.menuColor,
            padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 4),
            child: Column(children: [
              for (int i = 0; i < 5; i++) ...[
                Container(
                  height: 4,
                  decoration: BoxDecoration(
                    color: i == 0 ? theme.accentColor : Colors.white.withOpacity(i == 1 ? 0.5 : 0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 4),
              ],
            ]),
          ),
          // Content
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(5),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(
                  height: 5, width: double.infinity,
                  decoration: BoxDecoration(
                    color: theme.primaryColor.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(2),
                  )),
                const SizedBox(height: 5),
                Row(children: [
                  Expanded(child: Container(
                    height: 22,
                    decoration: BoxDecoration(
                      color: theme.cardColor,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: theme.primaryColor.withOpacity(0.12)),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 2)],
                    ),
                    child: Center(child: Container(
                      width: 20, height: 3,
                      decoration: BoxDecoration(
                        color: theme.primaryColor.withOpacity(0.4),
                        borderRadius: BorderRadius.circular(2),
                      ))),
                  )),
                  const SizedBox(width: 4),
                  Expanded(child: Container(
                    height: 22,
                    decoration: BoxDecoration(
                      color: theme.accentColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: theme.accentColor.withOpacity(0.2)),
                    ),
                    child: Center(child: Container(
                      width: 16, height: 3,
                      decoration: BoxDecoration(
                        color: theme.accentColor.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(2),
                      ))),
                  )),
                ]),
                const SizedBox(height: 4),
                Container(
                  height: 14,
                  decoration: BoxDecoration(
                    color: theme.cardColor,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.black.withOpacity(0.05)),
                  )),
              ]),
            ),
          ),
        ])),
        // Footer
        Container(
          height: 10,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [theme.footerColor, theme.headerColor],
              begin: Alignment.centerLeft, end: Alignment.centerRight,
            ),
          ),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Tab 3 — Layout
// ─────────────────────────────────────────────────────────────
class _LayoutTab extends StatelessWidget {
  final ThemeSettings ts;
  final WidgetRef ref;
  const _LayoutTab({required this.ts, required this.ref});

  @override
  Widget build(BuildContext context) {
    final layouts = AppLayout.values;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
      children: [
        _TabSectionHeading(
          icon: Icons.dashboard_customize_rounded,
          title: 'Layout Style',
          subtitle: 'Choose how navigation and content are arranged',
        ),
        const SizedBox(height: 20),

        ...layouts.map((layout) {
          final sel = layout == ts.layout;
          return Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: _LayoutCard(
              layout: layout,
              selected: sel,
              accentColor: ts.portalTheme.primaryColor,
              onTap: () => ref.read(themeProvider.notifier).updateLayout(layout),
            ),
          );
        }),

        const SizedBox(height: 8),
        _InfoBadge(
          icon: Icons.view_quilt_rounded,
          text: 'Layout reshapes navigation placement and content density.',
        ),
      ],
    );
  }
}

class _LayoutCard extends StatelessWidget {
  final AppLayout layout;
  final bool selected;
  final Color accentColor;
  final VoidCallback onTap;
  const _LayoutCard({required this.layout, required this.selected, required this.accentColor, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        height: 100,
        decoration: BoxDecoration(
          color: selected ? accentColor.withOpacity(0.07) : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? accentColor : const Color(0xFFE0E0E0),
            width: selected ? 2.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: selected ? accentColor.withOpacity(0.2) : Colors.black.withOpacity(0.04),
              blurRadius: selected ? 16 : 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(children: [
          // Layout illustration
          Container(
            width: 100,
            margin: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFF0F2F8),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: selected ? accentColor.withOpacity(0.3) : const Color(0xFFE0E0E0)),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: _LayoutDiagram(layout: layout, accent: accentColor),
            ),
          ),
          // Text
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Icon(layout.icon, size: 18, color: selected ? accentColor : const Color(0xFF757575)),
                    const SizedBox(width: 8),
                    Text(layout.label,
                      style: GoogleFonts.raleway(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: selected ? accentColor : const Color(0xFF212121),
                      )),
                  ]),
                  const SizedBox(height: 5),
                  Text(layout.description,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: const Color(0xFF757575),
                      height: 1.4,
                    )),
                ],
              ),
            ),
          ),
          if (selected)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Container(
                width: 28, height: 28,
                decoration: BoxDecoration(color: accentColor, shape: BoxShape.circle),
                child: const Icon(Icons.check_rounded, size: 16, color: Colors.white),
              ),
            ),
        ]),
      ),
    );
  }
}

class _LayoutDiagram extends StatelessWidget {
  final AppLayout layout;
  final Color accent;
  const _LayoutDiagram({required this.layout, required this.accent});

  @override
  Widget build(BuildContext context) {
    switch (layout) {
      case AppLayout.modern:
        return _buildModern();
      case AppLayout.classic:
        return _buildClassic();
      case AppLayout.compact:
        return _buildCompact();
      case AppLayout.topbar:
        return _buildTopbar();
      case AppLayout.minimal:
        return _buildMinimal();
    }
  }

  Widget _buildModern() => Column(children: [
    Container(height: 10, color: accent),
    Expanded(child: Row(children: [
      Container(width: 20, color: accent.withOpacity(0.8),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          for (int i = 0; i < 4; i++) ...[
            Container(width: 10, height: 3, margin: const EdgeInsets.symmetric(vertical: 2),
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.7), borderRadius: BorderRadius.circular(1))),
          ],
        ])),
      Expanded(child: Padding(
        padding: const EdgeInsets.all(4),
        child: Column(children: [
          Row(children: [
            Expanded(child: Container(height: 14, decoration: BoxDecoration(color: accent.withOpacity(0.15), borderRadius: BorderRadius.circular(3)))),
            const SizedBox(width: 4),
            Expanded(child: Container(height: 14, decoration: BoxDecoration(color: accent.withOpacity(0.1), borderRadius: BorderRadius.circular(3)))),
          ]),
          const SizedBox(height: 4),
          Container(height: 10, decoration: BoxDecoration(color: Colors.grey.withOpacity(0.15), borderRadius: BorderRadius.circular(3))),
        ]),
      )),
    ])),
  ]);

  Widget _buildClassic() => Column(children: [
    Container(height: 12, color: accent,
      child: Row(children: [
        const SizedBox(width: 4),
        for (int i = 0; i < 3; i++) ...[
          Container(width: 14, height: 5, margin: const EdgeInsets.only(right: 4),
            decoration: BoxDecoration(color: Colors.white.withOpacity(i == 0 ? 0.9 : 0.4), borderRadius: BorderRadius.circular(1))),
        ],
      ])),
    Expanded(child: Row(children: [
      Container(width: 24, color: accent.withOpacity(0.9),
        child: Column(children: [
          const SizedBox(height: 4),
          for (int i = 0; i < 5; i++) ...[
            Container(width: 14, height: 3, margin: const EdgeInsets.symmetric(vertical: 1.5),
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.6), borderRadius: BorderRadius.circular(1))),
          ],
        ])),
      Expanded(child: Container(
        margin: const EdgeInsets.all(3),
        decoration: BoxDecoration(color: accent.withOpacity(0.05), borderRadius: BorderRadius.circular(3)),
      )),
    ])),
  ]);

  Widget _buildCompact() => Column(children: [
    Container(height: 8, color: accent),
    Expanded(child: Row(children: [
      Container(width: 16, color: accent.withOpacity(0.85),
        child: Column(mainAxisAlignment: MainAxisAlignment.start, children: [
          const SizedBox(height: 3),
          for (int i = 0; i < 6; i++) ...[
            Container(width: 10, height: 2.5, margin: const EdgeInsets.symmetric(vertical: 1),
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.6), borderRadius: BorderRadius.circular(1))),
          ],
        ])),
      Expanded(child: Padding(
        padding: const EdgeInsets.all(3),
        child: Column(children: [
          for (int i = 0; i < 3; i++) ...[
            Container(height: 8, margin: const EdgeInsets.only(bottom: 2),
              decoration: BoxDecoration(color: accent.withOpacity(0.1), borderRadius: BorderRadius.circular(2))),
          ],
        ]),
      )),
    ])),
  ]);

  Widget _buildTopbar() => Column(children: [
    Container(height: 16, color: accent,
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
        for (int i = 0; i < 4; i++)
          Container(width: 14, height: 4,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(i == 0 ? 0.95 : 0.4),
              borderRadius: BorderRadius.circular(1),
            )),
      ])),
    Expanded(child: Padding(
      padding: const EdgeInsets.all(4),
      child: Column(children: [
        Row(children: [
          Expanded(child: Container(height: 14, decoration: BoxDecoration(color: accent.withOpacity(0.15), borderRadius: BorderRadius.circular(3)))),
          const SizedBox(width: 4),
          Expanded(child: Container(height: 14, decoration: BoxDecoration(color: accent.withOpacity(0.08), borderRadius: BorderRadius.circular(3)))),
          const SizedBox(width: 4),
          Expanded(child: Container(height: 14, decoration: BoxDecoration(color: accent.withOpacity(0.12), borderRadius: BorderRadius.circular(3)))),
        ]),
        const SizedBox(height: 4),
        Container(height: 14, decoration: BoxDecoration(color: Colors.grey.withOpacity(0.12), borderRadius: BorderRadius.circular(3))),
      ]),
    )),
  ]);

  Widget _buildMinimal() => Column(children: [
    Container(height: 8, color: Colors.grey.withOpacity(0.3)),
    Expanded(child: Center(child: Padding(
      padding: const EdgeInsets.all(8),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(height: 6, width: 50,
          decoration: BoxDecoration(color: accent.withOpacity(0.6), borderRadius: BorderRadius.circular(2))),
        const SizedBox(height: 6),
        Container(height: 20,
          decoration: BoxDecoration(color: accent.withOpacity(0.1), borderRadius: BorderRadius.circular(4))),
        const SizedBox(height: 4),
        Container(height: 8,
          decoration: BoxDecoration(color: Colors.grey.withOpacity(0.15), borderRadius: BorderRadius.circular(2))),
      ]),
    ))),
    Container(height: 6, color: Colors.grey.withOpacity(0.2)),
  ]);
}

// ─────────────────────────────────────────────────────────────
// Shared Widgets
// ─────────────────────────────────────────────────────────────
class _TabSectionHeading extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  const _TabSectionHeading({required this.icon, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppTheme.primary, AppTheme.primaryLight],
            begin: Alignment.topLeft, end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: AppTheme.primary.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 3))],
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
      const SizedBox(width: 14),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title,
          style: GoogleFonts.playfairDisplay(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF0D1B63),
            fontStyle: FontStyle.italic,
          )),
        const SizedBox(height: 2),
        Text(subtitle,
          style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF757575))),
      ])),
    ]);
  }
}

class _AdminBanner extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _AdminBanner({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 10),
        Text(label,
          style: GoogleFonts.raleway(
            color: color,
            fontWeight: FontWeight.w700,
            fontSize: 13,
          )),
      ]),
    );
  }
}

class _InfoBadge extends StatelessWidget {
  final IconData icon;
  final String text;
  const _InfoBadge({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F5E9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFA5D6A7)),
      ),
      child: Row(children: [
        Icon(icon, color: const Color(0xFF2E7D32), size: 16),
        const SizedBox(width: 8),
        Expanded(child: Text(text,
          style: GoogleFonts.inter(
            color: const Color(0xFF2E7D32),
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ))),
      ]),
    );
  }
}

class _ThemeColorDot extends StatelessWidget {
  final Color color;
  const _ThemeColorDot(this.color);

  @override
  Widget build(BuildContext context) => Container(
    width: 14, height: 14,
    margin: const EdgeInsets.only(right: 5),
    decoration: BoxDecoration(
      color: color,
      shape: BoxShape.circle,
      border: Border.all(color: Colors.white.withOpacity(0.4), width: 1),
    ),
  );
}

class _Blob extends StatelessWidget {
  final double size;
  final Color color;
  const _Blob(this.size, this.color);

  @override
  Widget build(BuildContext context) => Container(
    width: size, height: size,
    decoration: BoxDecoration(shape: BoxShape.circle, color: color),
  );
}
