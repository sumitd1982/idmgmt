import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../config/theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/theme_provider.dart';
import '../../providers/api_provider.dart';

class ThemeSettingsScreen extends ConsumerWidget {
  const ThemeSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeSettings = ref.watch(themeProvider);
    final user = ref.watch(authNotifierProvider).valueOrNull;
    final isSuperAdmin = user?.role == 'super_admin';

    return Scaffold(
      backgroundColor: AppTheme.grey50,
      appBar: AppBar(
        title: Text('Appearance & Theme', 
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 16)),
        backgroundColor: Colors.white,
        foregroundColor: AppTheme.grey900,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          _SectionHeader(title: 'Personal Preferences'),
          const SizedBox(height: 16),
          
          _Card(
            child: Column(
              children: [
                _ListTile(
                  title: 'Theme Mode',
                  subtitle: 'Choose between light, dark, or system default',
                  trailing: DropdownButton<ThemeMode>(
                    value: themeSettings.mode,
                    underline: const SizedBox(),
                    items: ThemeMode.values.map((m) => DropdownMenuItem(
                      value: m,
                      child: Text(m.name.toUpperCase(), style: const TextStyle(fontSize: 13)),
                    )).toList(),
                    onChanged: (m) => ref.read(themeProvider.notifier).updateTheme(m!),
                  ),
                ),
                const Divider(),
                _ListTile(
                  title: 'Layout Style',
                  subtitle: 'Select your preferred navigation layout',
                  trailing: DropdownButton<AppLayout>(
                    value: themeSettings.layout,
                    underline: const SizedBox(),
                    items: AppLayout.values.map((l) => DropdownMenuItem(
                      value: l,
                      child: Text(l.name.toUpperCase(), style: const TextStyle(fontSize: 13)),
                    )).toList(),
                    onChanged: (l) => ref.read(themeProvider.notifier).updateLayout(l!),
                  ),
                ),
              ],
            ),
          ),
          
          if (isSuperAdmin) ...[
            const SizedBox(height: 32),
            _SectionHeader(title: 'School Defaults (SuperAdmin)'),
            const SizedBox(height: 16),
            _Card(
              child: Column(
                children: [
                  _ListTile(
                    title: 'Default School Theme',
                    subtitle: 'Sets the default theme for all staff and parents',
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _showSchoolThemeDialog(context, ref, user?.schoolId),
                  ),
                  const Divider(),
                  _ListTile(
                    title: 'Primary Brand Color',
                    subtitle: 'Update the main accent color for your organization',
                    trailing: Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: themeSettings.primaryColor ?? AppTheme.primary,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                    ),
                    onTap: () => _showColorPicker(context, ref, user?.schoolId),
                  ),
                ],
              ),
            ),
          ],
          
          const SizedBox(height: 48),
          Center(
            child: Text(
              'Changes are saved automatically to your profile.',
              style: GoogleFonts.poppins(color: AppTheme.grey500, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  void _showSchoolThemeDialog(BuildContext context, WidgetRef ref, String? schoolId) {
    if (schoolId == null) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Set School Default'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: ['light', 'dark'].map((m) => ListTile(
            title: Text(m.toUpperCase()),
            onTap: () async {
              try {
                final api = ref.read(apiServiceProvider);
                await api.put('/schools/$schoolId', body: {
                  'settings': {'default_theme': m}
                });
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('School default updated')),
                );
              } catch (_) {}
            },
          )).toList(),
        ),
      ),
    );
  }

  void _showColorPicker(BuildContext context, WidgetRef ref, String? schoolId) {
    // Simple color picker mock-up
    final colors = [
      const Color(0xFF1A237E), // Indigo
      const Color(0xFFC62828), // Red
      const Color(0xFF2E7D32), // Green
      const Color(0xFFEF6C00), // Orange
      const Color(0xFF6A1B9A), // Purple
      const Color(0xFF00838F), // Cyan
    ];

    showModalBottomSheet(
      context: context,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Select Brand Color', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 20),
            GridView.count(
              shrinkWrap: true,
              crossAxisCount: 6,
              children: colors.map((c) => GestureDetector(
                onTap: () async {
                  try {
                    final api = ref.read(apiServiceProvider);
                    final hex = '#${c.value.toRadixString(16).substring(2).toUpperCase()}';
                    await api.put('/schools/$schoolId', body: {
                      'settings': {'primary_color': hex}
                    });
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Brand color updated')),
                    );
                  } catch (_) {}
                },
                child: Container(
                  margin: const EdgeInsets.all(4),
                  decoration: BoxDecoration(color: c, shape: BoxShape.circle),
                ),
              )).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title.toUpperCase(),
      style: GoogleFonts.poppins(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: AppTheme.grey600,
        letterSpacing: 1.2,
      ),
    );
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
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.grey200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: child,
      ),
    );
  }
}

class _ListTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget trailing;
  final VoidCallback? onTap;

  const _ListTile({
    required this.title,
    required this.subtitle,
    required this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      title: Text(title, style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14)),
      subtitle: Text(subtitle, style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.grey500)),
      trailing: trailing,
    );
  }
}
