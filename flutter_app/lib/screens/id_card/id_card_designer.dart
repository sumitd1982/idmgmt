// ============================================================
// ID Card Designer
// ============================================================
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../config/theme.dart';

// ── Models ────────────────────────────────────────────────────
class _CardTheme {
  final String id;
  final String name;
  final Color primary;
  final Color secondary;
  final Color accent;

  const _CardTheme({
    required this.id,
    required this.name,
    required this.primary,
    required this.secondary,
    required this.accent,
  });
}

class _CustomField {
  final String id;
  String label;
  String value;
  String position; // top | middle | bottom

  _CustomField({
    required this.id,
    required this.label,
    required this.value,
    required this.position,
  });
}

class _DesignerState {
  final String selectedThemeId;
  final Color primaryColor;
  final Color secondaryColor;
  final Color accentColor;
  final bool showPhoto;
  final bool showQr;
  final bool showBloodGroup;
  final bool showBack;
  final List<_CustomField> customFields;

  const _DesignerState({
    required this.selectedThemeId,
    required this.primaryColor,
    required this.secondaryColor,
    required this.accentColor,
    required this.showPhoto,
    required this.showQr,
    required this.showBloodGroup,
    required this.showBack,
    required this.customFields,
  });

  _DesignerState copyWith({
    String? selectedThemeId,
    Color?  primaryColor,
    Color?  secondaryColor,
    Color?  accentColor,
    bool?   showPhoto,
    bool?   showQr,
    bool?   showBloodGroup,
    bool?   showBack,
    List<_CustomField>? customFields,
  }) => _DesignerState(
        selectedThemeId: selectedThemeId ?? this.selectedThemeId,
        primaryColor:   primaryColor    ?? this.primaryColor,
        secondaryColor: secondaryColor  ?? this.secondaryColor,
        accentColor:    accentColor     ?? this.accentColor,
        showPhoto:      showPhoto       ?? this.showPhoto,
        showQr:         showQr          ?? this.showQr,
        showBloodGroup: showBloodGroup  ?? this.showBloodGroup,
        showBack:       showBack        ?? this.showBack,
        customFields:   customFields    ?? this.customFields,
      );
}

// ── Providers ─────────────────────────────────────────────────
final _cardDesignerProvider =
    StateNotifierProvider<_DesignerNotifier, _DesignerState>((ref) {
  return _DesignerNotifier();
});

class _DesignerNotifier extends StateNotifier<_DesignerState> {
  _DesignerNotifier()
      : super(_DesignerState(
          selectedThemeId: 'classic',
          primaryColor:    AppTheme.primary,
          secondaryColor:  AppTheme.secondary,
          accentColor:     AppTheme.accent,
          showPhoto:       true,
          showQr:          true,
          showBloodGroup:  true,
          showBack:        false,
          customFields:    [],
        ));

  void selectTheme(String id) {
    final t = _cardThemes.firstWhere((t) => t.id == id, orElse: () => _cardThemes.first);
    state = state.copyWith(
      selectedThemeId: id,
      primaryColor:   t.primary,
      secondaryColor: t.secondary,
      accentColor:    t.accent,
    );
  }

  void setPrimary(Color c)    => state = state.copyWith(primaryColor:   c);
  void setSecondary(Color c)  => state = state.copyWith(secondaryColor: c);
  void setAccent(Color c)     => state = state.copyWith(accentColor:    c);
  void togglePhoto()          => state = state.copyWith(showPhoto:       !state.showPhoto);
  void toggleQr()             => state = state.copyWith(showQr:          !state.showQr);
  void toggleBloodGroup()     => state = state.copyWith(showBloodGroup:  !state.showBloodGroup);
  void toggleBack()           => state = state.copyWith(showBack:        !state.showBack);

  void addCustomField() {
    final updated = [...state.customFields,
      _CustomField(
        id:       DateTime.now().millisecondsSinceEpoch.toString(),
        label:    'Custom Field',
        value:    'Value',
        position: 'bottom',
      )
    ];
    state = state.copyWith(customFields: updated);
  }

  void removeCustomField(String id) {
    final updated = state.customFields.where((f) => f.id != id).toList();
    state = state.copyWith(customFields: updated);
  }

  void updateField(String id, {String? label, String? value, String? position}) {
    final updated = state.customFields.map((f) {
      if (f.id != id) return f;
      if (label    != null) f.label    = label;
      if (value    != null) f.value    = value;
      if (position != null) f.position = position;
      return f;
    }).toList();
    state = state.copyWith(customFields: updated);
  }
}

const _cardThemes = [
  _CardTheme(id: 'classic',  name: 'Classic Blue',   primary: AppTheme.primary,       secondary: AppTheme.secondary,    accent: AppTheme.accent),
  _CardTheme(id: 'emerald',  name: 'Emerald',         primary: Color(0xFF1B5E20),      secondary: Color(0xFF4CAF50),      accent: Color(0xFFFFEB3B)),
  _CardTheme(id: 'crimson',  name: 'Crimson',         primary: Color(0xFF7B1FA2),      secondary: Color(0xFFC62828),      accent: Color(0xFFFFC107)),
  _CardTheme(id: 'ocean',    name: 'Ocean',           primary: Color(0xFF006064),      secondary: Color(0xFF00ACC1),      accent: Color(0xFFFF7043)),
  _CardTheme(id: 'slate',    name: 'Slate',           primary: Color(0xFF37474F),      secondary: Color(0xFF78909C),      accent: Color(0xFFFFCA28)),
  _CardTheme(id: 'coral',    name: 'Coral Sunset',    primary: Color(0xFFBF360C),      secondary: Color(0xFFFF7043),      accent: Color(0xFFFFD54F)),
];

// ── Screen ────────────────────────────────────────────────────
class IdCardDesigner extends ConsumerWidget {
  const IdCardDesigner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(_cardDesignerProvider);

    return Scaffold(
      backgroundColor: AppTheme.grey50,
      body: LayoutBuilder(
        builder: (ctx, constraints) {
          final isWide = constraints.maxWidth > 900;
          if (isWide) {
            return Row(
              children: [
                // Left: Theme selector
                SizedBox(
                  width:  200,
                  child: _ThemeSelector(selectedId: state.selectedThemeId),
                ),
                // Center: Preview
                Expanded(child: _CardPreviewPanel(state: state)),
                // Right: Settings
                SizedBox(
                  width:  280,
                  child: _SettingsPanel(state: state),
                ),
              ],
            );
          }
          return Column(
            children: [
              _CardPreviewPanel(state: state),
              const Divider(height: 1),
              Expanded(
                child: Row(
                  children: [
                    Expanded(child: _ThemeSelector(selectedId: state.selectedThemeId)),
                    const VerticalDivider(width: 1),
                    Expanded(child: _SettingsPanel(state: state)),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ── Theme Selector Panel ──────────────────────────────────────
class _ThemeSelector extends ConsumerWidget {
  final String selectedId;
  const _ThemeSelector({required this.selectedId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text('Themes',
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600, fontSize: 13)),
          ),
          const Divider(height: 1),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(12),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 0.85,
              ),
              itemCount: _cardThemes.length,
              itemBuilder: (_, i) {
                final t = _cardThemes[i];
                final isSelected = t.id == selectedId;
                return GestureDetector(
                  onTap: () => ref.read(_cardDesignerProvider.notifier).selectTheme(t.id),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: isSelected ? AppTheme.primary : AppTheme.grey200,
                        width: isSelected ? 2 : 1,
                      ),
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: isSelected
                          ? [BoxShadow(
                              color:  AppTheme.primary.withOpacity(0.25),
                              blurRadius: 8)]
                          : null,
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(7),
                      child: Column(
                        children: [
                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [t.primary, t.secondary],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                              ),
                              child: Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    CircleAvatar(
                                      radius: 12,
                                      backgroundColor: Colors.white30,
                                      child: const Icon(Icons.person,
                                          size: 14, color: Colors.white),
                                    ),
                                    const SizedBox(height: 4),
                                    Container(
                                      height: 4,
                                      width: 36,
                                      color: Colors.white54,
                                    ),
                                    const SizedBox(height: 2),
                                    Container(
                                      height: 3,
                                      width: 24,
                                      color: Colors.white38,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                vertical: 4, horizontal: 6),
                            child: Text(
                              t.name,
                              textAlign: TextAlign.center,
                              style: GoogleFonts.poppins(
                                  fontSize: 9,
                                  color: AppTheme.grey800,
                                  fontWeight: isSelected
                                      ? FontWeight.w600
                                      : FontWeight.w400),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ── Card Preview Panel ────────────────────────────────────────
class _CardPreviewPanel extends ConsumerWidget {
  final _DesignerState state;
  const _CardPreviewPanel({required this.state});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      color: AppTheme.grey100,
      child: Column(
        children: [
          // Action bar
          Container(
            height: 52,
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                // Flip toggle
                ElevatedButton.icon(
                  onPressed: () => ref.read(_cardDesignerProvider.notifier).toggleBack(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: state.showBack
                        ? AppTheme.secondary
                        : AppTheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    textStyle: GoogleFonts.poppins(fontSize: 12),
                    minimumSize: Size.zero,
                  ),
                  icon:  Icon(state.showBack
                      ? Icons.flip_to_front
                      : Icons.flip_to_back, size: 14),
                  label: Text(state.showBack ? 'Show Front' : 'Show Back'),
                ),
                const Spacer(),
                OutlinedButton.icon(
                  onPressed: () {},
                  icon:  const Icon(Icons.save_outlined, size: 14),
                  label: const Text('Save Theme'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    textStyle: GoogleFonts.poppins(fontSize: 12),
                    minimumSize: Size.zero,
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: () {},
                  icon:  const Icon(Icons.picture_as_pdf, size: 14),
                  label: const Text('Generate PDF'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.error,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    textStyle: GoogleFonts.poppins(fontSize: 12),
                    minimumSize: Size.zero,
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: () {},
                  icon:  const Icon(Icons.people, size: 14),
                  label: const Text('Bulk Generate'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    textStyle: GoogleFonts.poppins(fontSize: 12),
                    minimumSize: Size.zero,
                  ),
                ),
              ],
            ),
          ),
          // Preview
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(32),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 400),
                  transitionBuilder: (child, anim) => FadeTransition(
                    opacity: anim,
                    child: ScaleTransition(scale: anim, child: child),
                  ),
                  child: state.showBack
                      ? _IdCardBack(key: const ValueKey('back'), state: state)
                      : _IdCardFront(key: const ValueKey('front'), state: state),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── ID Card Front ─────────────────────────────────────────────
class _IdCardFront extends StatelessWidget {
  final _DesignerState state;
  const _IdCardFront({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    return Container(
      width:  320,
      height: 200,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          colors: [state.primaryColor, state.secondaryColor],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color:  state.primaryColor.withOpacity(0.4),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Decorative circles
          Positioned(
            top:  -20,
            right: -20,
            child: Container(
              width:  80,
              height: 80,
              decoration: BoxDecoration(
                color:  Colors.white.withOpacity(0.08),
                shape:  BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            bottom: -30,
            left: -10,
            child: Container(
              width:  100,
              height: 100,
              decoration: BoxDecoration(
                color:  Colors.white.withOpacity(0.06),
                shape:  BoxShape.circle,
              ),
            ),
          ),

          // Content
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // School name
                Row(
                  children: [
                    Container(
                      width: 32, height: 32,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Icon(Icons.school, color: Colors.white, size: 18),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('GREEN VALLEY SCHOOL',
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.5,
                              )),
                          Text('Main Branch, New Delhi',
                              style: GoogleFonts.poppins(
                                  color: Colors.white70, fontSize: 7)),
                        ],
                      ),
                    ),
                    Text('STUDENT ID',
                        style: GoogleFonts.poppins(
                          color: Colors.white54,
                          fontSize: 7,
                          letterSpacing: 1,
                        )),
                  ],
                ),
                const SizedBox(height: 12),

                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Photo
                    if (state.showPhoto)
                      Container(
                        width:  60,
                        height: 72,
                        decoration: BoxDecoration(
                          color:        Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.white30, width: 1.5),
                        ),
                        child: const Icon(Icons.person,
                            color: Colors.white54, size: 30),
                      ),
                    const SizedBox(width: 12),

                    // Details
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Arjun Kumar',
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              )),
                          const SizedBox(height: 2),
                          Text('Class 5 - Section A',
                              style: GoogleFonts.poppins(
                                  color: Colors.white70, fontSize: 9)),
                          Text('Roll No: 15',
                              style: GoogleFonts.poppins(
                                  color: Colors.white70, fontSize: 9)),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: state.accentColor.withOpacity(0.3),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text('STU1015',
                                style: GoogleFonts.poppins(
                                  color: state.accentColor == AppTheme.accent
                                      ? Colors.white
                                      : Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.5,
                                )),
                          ),
                          if (state.showBloodGroup) ...[
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(Icons.favorite,
                                    color: Colors.red.shade300, size: 10),
                                const SizedBox(width: 3),
                                Text('B+',
                                    style: GoogleFonts.poppins(
                                        color: Colors.white70, fontSize: 9)),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),

                    // QR
                    if (state.showQr)
                      Container(
                        width: 52, height: 52,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        padding: const EdgeInsets.all(4),
                        child: QrImageView(
                          data: 'STU1015',
                          version: QrVersions.auto,
                        ),
                      ),
                  ],
                ),

                // Custom fields
                if (state.customFields.isNotEmpty &&
                    state.customFields.any((f) => f.position == 'bottom'))
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Wrap(
                      spacing: 8,
                      children: state.customFields
                          .where((f) => f.position == 'bottom')
                          .map((f) => Text('${f.label}: ${f.value}',
                              style: GoogleFonts.poppins(
                                  color: Colors.white70, fontSize: 8)))
                          .toList(),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    ).animate().scale(duration: 300.ms, curve: Curves.easeOut);
  }
}

// ── ID Card Back ──────────────────────────────────────────────
class _IdCardBack extends StatelessWidget {
  final _DesignerState state;
  const _IdCardBack({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    return Container(
      width:  320,
      height: 200,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.white,
        border: Border.all(color: AppTheme.grey200),
        boxShadow: [
          BoxShadow(
            color:  AppTheme.primary.withOpacity(0.15),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          // Top stripe
          Container(
            height: 8,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [state.primaryColor, state.secondaryColor],
              ),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
          ),
          // Magnetic strip
          Container(height: 28, color: AppTheme.grey900),
          const SizedBox(height: 12),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                // Signature line
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(height: 1, color: AppTheme.grey300),
                          const SizedBox(height: 3),
                          Text('Signature',
                              style: GoogleFonts.poppins(
                                  fontSize: 8, color: AppTheme.grey600)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(height: 1, color: AppTheme.grey300),
                          const SizedBox(height: 3),
                          Text('Principal Signature',
                              style: GoogleFonts.poppins(
                                  fontSize: 8, color: AppTheme.grey600)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Emergency contact
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color:        AppTheme.grey100,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.emergency,
                          size: 14, color: AppTheme.error),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Emergency Contact',
                                style: GoogleFonts.poppins(
                                    fontSize: 8,
                                    color: AppTheme.error,
                                    fontWeight: FontWeight.w600)),
                            Text('Parent: 98765 43210',
                                style: GoogleFonts.poppins(
                                    fontSize: 9,
                                    color: AppTheme.grey800)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),

                Text(
                  'If found, please return to: Green Valley School, Main Branch',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                      fontSize: 7, color: AppTheme.grey600),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().scale(duration: 300.ms, curve: Curves.easeOut);
  }
}

// ── Settings Panel ────────────────────────────────────────────
class _SettingsPanel extends ConsumerWidget {
  final _DesignerState state;
  const _SettingsPanel({required this.state});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(_cardDesignerProvider.notifier);

    return Container(
      color: Colors.white,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Customize',
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600, fontSize: 13)),
            const SizedBox(height: 16),

            // Color pickers
            _SettingsSection(title: 'Colors', children: [
              _ColorRow(
                label: 'Primary',
                color: state.primaryColor,
                onChanged: notifier.setPrimary,
              ),
              _ColorRow(
                label: 'Secondary',
                color: state.secondaryColor,
                onChanged: notifier.setSecondary,
              ),
              _ColorRow(
                label: 'Accent',
                color: state.accentColor,
                onChanged: notifier.setAccent,
              ),
            ]),

            const SizedBox(height: 16),

            // Layout toggles
            _SettingsSection(title: 'Layout', children: [
              _ToggleRow(
                label:   'Show Photo',
                value:   state.showPhoto,
                onToggle: notifier.togglePhoto,
              ),
              _ToggleRow(
                label:   'Show QR Code',
                value:   state.showQr,
                onToggle: notifier.toggleQr,
              ),
              _ToggleRow(
                label:   'Show Blood Group',
                value:   state.showBloodGroup,
                onToggle: notifier.toggleBloodGroup,
              ),
            ]),

            const SizedBox(height: 16),

            // Custom fields
            _SettingsSection(
              title: 'Custom Fields',
              trailing: TextButton.icon(
                onPressed: notifier.addCustomField,
                icon:  const Icon(Icons.add, size: 14),
                label: const Text('Add'),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  textStyle: GoogleFonts.poppins(fontSize: 11),
                ),
              ),
              children: state.customFields.isEmpty
                  ? [
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text('No custom fields added.',
                            style: GoogleFonts.poppins(
                                fontSize: 11,
                                color: AppTheme.grey600)),
                      )
                    ]
                  : state.customFields
                      .map((f) => _CustomFieldRow(
                            field:    f,
                            onRemove: () =>
                                notifier.removeCustomField(f.id),
                            onUpdate: (label, value, pos) =>
                                notifier.updateField(f.id,
                                    label: label,
                                    value: value,
                                    position: pos),
                          ))
                      .toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  final String title;
  final List<Widget> children;
  final Widget? trailing;
  const _SettingsSection({
    required this.title,
    required this.children,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(title,
                style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: AppTheme.grey600,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5)),
            const Spacer(),
            if (trailing != null) trailing!,
          ],
        ),
        const SizedBox(height: 8),
        ...children,
      ],
    );
  }
}

class _ColorRow extends StatelessWidget {
  final String label;
  final Color color;
  final ValueChanged<Color> onChanged;
  const _ColorRow({
    required this.label,
    required this.color,
    required this.onChanged,
  });

  void _openPicker(BuildContext context) {
    Color temp = color;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Pick $label Color',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        content: SingleChildScrollView(
          child: ColorPicker(
            pickerColor: color,
            onColorChanged: (c) => temp = c,
            enableAlpha: false,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              onChanged(temp);
              Navigator.of(context).pop();
            },
            child: const Text('Apply'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(label,
              style:
                  GoogleFonts.poppins(fontSize: 12, color: AppTheme.grey800)),
          const Spacer(),
          GestureDetector(
            onTap: () => _openPicker(context),
            child: Container(
              width:  32,
              height: 20,
              decoration: BoxDecoration(
                color:        color,
                borderRadius: BorderRadius.circular(4),
                border:       Border.all(color: AppTheme.grey300),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  final String label;
  final bool value;
  final VoidCallback onToggle;
  const _ToggleRow({
    required this.label,
    required this.value,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(label,
            style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.grey800)),
        const Spacer(),
        Transform.scale(
          scale: 0.75,
          child: Switch(
            value:     value,
            onChanged: (_) => onToggle(),
            activeColor: AppTheme.primary,
          ),
        ),
      ],
    );
  }
}

class _CustomFieldRow extends StatelessWidget {
  final _CustomField field;
  final VoidCallback onRemove;
  final void Function(String? label, String? value, String? position) onUpdate;
  const _CustomFieldRow({
    required this.field,
    required this.onRemove,
    required this.onUpdate,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color:        AppTheme.grey50,
        borderRadius: BorderRadius.circular(6),
        border:       Border.all(color: AppTheme.grey200),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '${field.label}: ${field.value}',
              style: GoogleFonts.poppins(fontSize: 11),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            onPressed: onRemove,
            icon: const Icon(Icons.close, size: 14, color: AppTheme.error),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
          ),
        ],
      ),
    );
  }
}
