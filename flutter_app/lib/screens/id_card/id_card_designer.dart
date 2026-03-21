// ============================================================
// ID Card Designer
// ============================================================
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../providers/api_provider.dart';
import '../../config/theme.dart';
import 'dart:convert';

// ── Models ────────────────────────────────────────────────────
class IdCardTheme {
  final String id;
  final String name;
  final String? description;
  final Color primary;
  final Color secondary;
  final Color accent;
  final Color textColor;
  final Color bgColor;
  final Map<String, dynamic> frontLayout;
  final Map<String, dynamic> backLayout;
  final List<dynamic> customFields;
  final String templateType;
  final String orientation;
  final String? termsFront;
  final String? termsBack;
  final bool isPrebuilt;
  final bool isDefault;

  IdCardTheme({
    required this.id, required this.name, this.description,
    required this.primary, required this.secondary, required this.accent,
    required this.textColor, required this.bgColor,
    required this.frontLayout, required this.backLayout, required this.customFields,
    required this.templateType, required this.orientation,
    this.termsFront, this.termsBack, required this.isPrebuilt, required this.isDefault,
  });

  factory IdCardTheme.fromJson(Map<String, dynamic> json) {
    Color _parseColor(String? hex, Color fallback) {
      if (hex == null || hex.isEmpty) return fallback;
      try { return Color(int.parse(hex.replaceAll('#', '0xFF'))); } catch (_) { return fallback; }
    }
    return IdCardTheme(
      id: json['id'], name: json['name'], description: json['description'],
      primary: _parseColor(json['primary_color'], AppTheme.primary),
      secondary: _parseColor(json['secondary_color'], AppTheme.secondary),
      accent: _parseColor(json['accent_color'], AppTheme.accent),
      textColor: _parseColor(json['text_color'], Colors.black87),
      bgColor: _parseColor(json['bg_color'], Colors.white),
      frontLayout: json['front_layout'] is String ? jsonDecode(json['front_layout']) : (json['front_layout'] ?? {}),
      backLayout: json['back_layout'] is String ? jsonDecode(json['back_layout']) : (json['back_layout'] ?? {}),
      customFields: json['custom_fields'] is String ? jsonDecode(json['custom_fields']) : (json['custom_fields'] ?? []),
      templateType: json['template_type'] ?? 'student',
      orientation: json['orientation'] ?? 'landscape',
      termsFront: json['terms_front'],
      termsBack: json['terms_back'],
      isPrebuilt: json['is_prebuilt'] == 1 || json['is_prebuilt'] == true,
      isDefault: json['is_default'] == 1 || json['is_default'] == true,
    );
  }
}

class _CustomField {
  final String id;
  String label;
  String value;
  String position; // top | middle | bottom

  _CustomField({required this.id, required this.label, required this.value, required this.position});
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
  final String templateType;
  final String orientation;
  final String termsFront;
  final String termsBack;
  final List<_CustomField> customFields;

  const _DesignerState({
    required this.selectedThemeId, required this.primaryColor, required this.secondaryColor, required this.accentColor,
    required this.showPhoto, required this.showQr, required this.showBloodGroup, required this.showBack,
    required this.templateType, required this.orientation, required this.termsFront, required this.termsBack, required this.customFields,
  });

  _DesignerState copyWith({
    String? selectedThemeId, Color? primaryColor, Color? secondaryColor, Color? accentColor,
    bool? showPhoto, bool? showQr, bool? showBloodGroup, bool? showBack,
    String? templateType, String? orientation, String? termsFront, String? termsBack, List<_CustomField>? customFields,
  }) => _DesignerState(
        selectedThemeId: selectedThemeId ?? this.selectedThemeId,
        primaryColor: primaryColor ?? this.primaryColor, secondaryColor: secondaryColor ?? this.secondaryColor, accentColor: accentColor ?? this.accentColor,
        showPhoto: showPhoto ?? this.showPhoto, showQr: showQr ?? this.showQr, showBloodGroup: showBloodGroup ?? this.showBloodGroup, showBack: showBack ?? this.showBack,
        templateType: templateType ?? this.templateType, orientation: orientation ?? this.orientation,
        termsFront: termsFront ?? this.termsFront, termsBack: termsBack ?? this.termsBack, customFields: customFields ?? this.customFields,
      );
}

// ── Providers ─────────────────────────────────────────────────
final idCardThemesProvider = FutureProvider<List<IdCardTheme>>((ref) async {
  final api = ref.read(apiServiceProvider);
  final res = await api.get('/idcards/themes');
  if (res['success'] == true && res['data'] != null) {
    return (res['data'] as List).map((t) => IdCardTheme.fromJson(t)).toList();
  }
  return [];
});

final _cardDesignerProvider = StateNotifierProvider<_DesignerNotifier, _DesignerState>((ref) {
  return _DesignerNotifier();
});

class _DesignerNotifier extends StateNotifier<_DesignerState> {
  _DesignerNotifier() : super(const _DesignerState(
          selectedThemeId: '', primaryColor: AppTheme.primary, secondaryColor: AppTheme.secondary, accentColor: AppTheme.accent,
          showPhoto: true, showQr: true, showBloodGroup: true, showBack: false,
          templateType: 'student', orientation: 'landscape', termsFront: '', termsBack: 'If found, return to school.', customFields: [],
        ));

  void applyTheme(IdCardTheme t) {
    state = state.copyWith(
      selectedThemeId: t.id, primaryColor: t.primary, secondaryColor: t.secondary, accentColor: t.accent,
      templateType: t.templateType, orientation: t.orientation,
      termsFront: t.termsFront ?? '', termsBack: t.termsBack ?? '',
      showPhoto: t.frontLayout['show_photo'] ?? true,
      showQr: t.frontLayout['show_qr'] ?? true,
      showBloodGroup: t.frontLayout['show_blood'] ?? true,
      customFields: t.customFields.map((f) => _CustomField(id: DateTime.now().millisecondsSinceEpoch.toString(), label: f['label'] ?? '', value: f['value'] ?? '', position: f['position'] ?? 'bottom')).toList(),
    );
  }

  void setPrimary(Color c) => state = state.copyWith(primaryColor: c);
  void setSecondary(Color c) => state = state.copyWith(secondaryColor: c);
  void setAccent(Color c) => state = state.copyWith(accentColor: c);
  void togglePhoto() => state = state.copyWith(showPhoto: !state.showPhoto);
  void toggleQr() => state = state.copyWith(showQr: !state.showQr);
  void toggleBloodGroup() => state = state.copyWith(showBloodGroup: !state.showBloodGroup);
  void toggleBack() => state = state.copyWith(showBack: !state.showBack);
  void setOrientation(String o) => state = state.copyWith(orientation: o);
  void setTermsBack(String t) => state = state.copyWith(termsBack: t);
  void setTermsFront(String t) => state = state.copyWith(termsFront: t);

  void addCustomField() {
    state = state.copyWith(customFields: [...state.customFields, _CustomField(id: DateTime.now().millisecondsSinceEpoch.toString(), label: 'Custom Field', value: 'Value', position: 'bottom')]);
  }
  void removeCustomField(String id) {
    state = state.copyWith(customFields: state.customFields.where((f) => f.id != id).toList());
  }
  void updateField(String id, {String? label, String? value, String? position}) {
    state = state.copyWith(customFields: state.customFields.map((f) {
      if (f.id != id) return f;
      if (label != null) f.label = label;
      if (value != null) f.value = value;
      if (position != null) f.position = position;
      return f;
    }).toList());
  }
}

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
    final themesAsync = ref.watch(idCardThemesProvider);

    return Container(
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text('Themes', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13)),
          ),
          const Divider(height: 1),
          Expanded(
            child: themesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(child: Text('Error loading themes: $err')),
              data: (themes) {
                if (themes.isEmpty) return const Center(child: Text('No themes found.'));
                // Auto-select first if none selected
                if (selectedId.isEmpty && themes.isNotEmpty) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    ref.read(_cardDesignerProvider.notifier).applyTheme(themes.first);
                  });
                }
                
                return ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: themes.length,
                  itemBuilder: (_, i) {
                    final t = themes[i];
                    final isSelected = t.id == selectedId;
                    return GestureDetector(
                      onTap: () => ref.read(_cardDesignerProvider.notifier).applyTheme(t),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          border: Border.all(color: isSelected ? AppTheme.primary : AppTheme.grey200, width: isSelected ? 2 : 1),
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: isSelected ? [BoxShadow(color: AppTheme.primary.withOpacity(0.15), blurRadius: 6)] : null,
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(7),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Container(
                                height: 40,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(colors: [t.primary, t.secondary]),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    if (t.isPrebuilt)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        margin: const EdgeInsets.only(left: 6),
                                        decoration: BoxDecoration(color: Colors.black38, borderRadius: BorderRadius.circular(4)),
                                        child: Text('PREBUILT', style: GoogleFonts.poppins(fontSize: 8, color: Colors.white, fontWeight: FontWeight.bold)),
                                      )
                                    else const SizedBox(),
                                    Padding(
                                      padding: const EdgeInsets.only(right: 6),
                                      child: Icon(t.orientation == 'portrait' ? Icons.portrait : Icons.landscape, color: Colors.white70, size: 14),
                                    ),
                                  ],
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(8),
                                child: Text(t.name, style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.grey800, fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400)),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
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
                    backgroundColor: state.showBack ? AppTheme.secondary : AppTheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    textStyle: GoogleFonts.poppins(fontSize: 12),
                    minimumSize: Size.zero,
                  ),
                  icon: Icon(state.showBack ? Icons.flip_to_front : Icons.flip_to_back, size: 14),
                  label: Text(state.showBack ? 'Show Front' : 'Show Back'),
                ),
                const Spacer(),
                OutlinedButton.icon(
                  onPressed: () async {
                    try {
                      final api = ref.read(apiServiceProvider);
                      final payload = {
                        'name': 'Customized ${state.selectedThemeId.isNotEmpty ? state.selectedThemeId : "Theme"}',
                        'description': 'Saved from UI',
                        'primary_color': '#${state.primaryColor.value.toRadixString(16).substring(2).toUpperCase()}',
                        'secondary_color': '#${state.secondaryColor.value.toRadixString(16).substring(2).toUpperCase()}',
                        'accent_color': '#${state.accentColor.value.toRadixString(16).substring(2).toUpperCase()}',
                        'front_layout': {
                          'show_photo': state.showPhoto,
                          'show_qr': state.showQr,
                          'show_blood': state.showBloodGroup,
                        },
                        'template_type': state.templateType,
                        'orientation': state.orientation,
                        'terms_front': state.termsFront,
                        'terms_back': state.termsBack,
                        'custom_fields': state.customFields.map((f) => {'label': f.label, 'value': f.value, 'position': f.position}).toList(),
                      };
                      final res = await api.post('/idcards/themes', body: payload);
                      if (res['success'] == true && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Theme saved successfully!')));
                        ref.invalidate(idCardThemesProvider);
                      } else if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res['message'] ?? 'Failed to save theme'), backgroundColor: AppTheme.error));
                      }
                    } catch (e) {
                      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error saving theme: $e'), backgroundColor: AppTheme.error));
                    }
                  },
                  icon: const Icon(Icons.save_outlined, size: 14),
                  label: const Text('Save Theme'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
    final isPortrait = state.orientation == 'portrait';
    final cardWidth = isPortrait ? 200.0 : 320.0;
    final cardHeight = isPortrait ? 320.0 : 200.0;

    return Container(
      width: cardWidth,
      height: cardHeight,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(colors: [state.primaryColor, state.secondaryColor], begin: Alignment.topLeft, end: Alignment.bottomRight),
        boxShadow: [BoxShadow(color: state.primaryColor.withOpacity(0.4), blurRadius: 24, offset: const Offset(0, 10))],
      ),
      child: Stack(
        children: [
          Positioned(top: -20, right: -20, child: Container(width: 80, height: 80, decoration: BoxDecoration(color: Colors.white.withOpacity(0.08), shape: BoxShape.circle))),
          Positioned(bottom: -30, left: -10, child: Container(width: 100, height: 100, decoration: BoxDecoration(color: Colors.white.withOpacity(0.06), shape: BoxShape.circle))),

          Padding(
            padding: const EdgeInsets.all(16),
            child: isPortrait
                ? _buildPortraitContent()
                : _buildLandscapeContent(),
          ),
        ],
      ),
    ).animate().scale(duration: 300.ms, curve: Curves.easeOut);
  }

  Widget _buildLandscapeContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (state.showPhoto) ...[
              _buildPhoto(),
              const SizedBox(width: 12),
            ],
            Expanded(child: _buildDetails()),
            if (state.showQr) _buildQr(),
          ],
        ),
        if (state.termsFront.isNotEmpty) ...[
          const Spacer(),
          Text(state.termsFront, style: GoogleFonts.poppins(color: Colors.white70, fontSize: 8)),
        ],
        _buildCustomFields(),
      ],
    );
  }

  Widget _buildPortraitContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _buildHeader(center: true),
        const SizedBox(height: 12),
        if (state.showPhoto) ...[
          _buildPhoto(width: 70, height: 85),
          const SizedBox(height: 8),
        ],
        _buildDetails(center: true),
        const Spacer(),
        if (state.showQr) ...[
          _buildQr(),
          const SizedBox(height: 8),
        ],
        if (state.termsFront.isNotEmpty) ...[
          Text(state.termsFront, textAlign: TextAlign.center, style: GoogleFonts.poppins(color: Colors.white70, fontSize: 7)),
        ],
        _buildCustomFields(),
      ],
    );
  }

  Widget _buildHeader({bool center = false}) {
    return Row(
      mainAxisAlignment: center ? MainAxisAlignment.center : MainAxisAlignment.start,
      children: [
        Container(width: 24, height: 24, decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(6)), child: const Icon(Icons.school, color: Colors.white, size: 14)),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('GREEN VALLEY SCHOOL', style: GoogleFonts.poppins(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
            Text('Main Branch', style: GoogleFonts.poppins(color: Colors.white70, fontSize: 6)),
          ],
        ),
      ],
    );
  }

  Widget _buildPhoto({double width=60, double height=72}) {
    return Container(width: width, height: height, decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.white30, width: 1.5)), child: const Icon(Icons.person, color: Colors.white54, size: 30));
  }

  Widget _buildDetails({bool center = false}) {
    return Column(
      crossAxisAlignment: center ? CrossAxisAlignment.center : CrossAxisAlignment.start,
      children: [
        Text('Arjun Kumar', style: GoogleFonts.poppins(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
        const SizedBox(height: 2),
        Text('Class 5 - Section A', style: GoogleFonts.poppins(color: Colors.white70, fontSize: 9)),
        const SizedBox(height: 4),
        Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: state.accentColor.withOpacity(0.3), borderRadius: BorderRadius.circular(4)), child: Text('STU1015', style: GoogleFonts.poppins(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700))),
        if (state.showBloodGroup) ...[
          const SizedBox(height: 4),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [Icon(Icons.favorite, color: Colors.red.shade300, size: 10), const SizedBox(width: 3), Text('B+', style: GoogleFonts.poppins(color: Colors.white70, fontSize: 9))],
          ),
        ],
      ],
    );
  }

  Widget _buildQr() {
    return Container(width: 52, height: 52, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6)), padding: const EdgeInsets.all(4), child: QrImageView(data: 'STU1015', version: QrVersions.auto));
  }

  Widget _buildCustomFields() {
    if (state.customFields.isEmpty) return const SizedBox();
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Wrap(
        spacing: 8,
        children: state.customFields.where((f) => f.position == 'bottom').map((f) => Text('${f.label}: ${f.value}', style: GoogleFonts.poppins(color: Colors.white70, fontSize: 8))).toList(),
      ),
    );
  }
}

// ── ID Card Back ──────────────────────────────────────────────
class _IdCardBack extends StatelessWidget {
  final _DesignerState state;
  const _IdCardBack({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final isPortrait = state.orientation == 'portrait';
    final cardWidth = isPortrait ? 200.0 : 320.0;
    final cardHeight = isPortrait ? 320.0 : 200.0;

    return Container(
      width: cardWidth,
      height: cardHeight,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.white,
        border: Border.all(color: AppTheme.grey200),
        boxShadow: [BoxShadow(color: AppTheme.primary.withOpacity(0.15), blurRadius: 24, offset: const Offset(0, 10))],
      ),
      child: Column(
        children: [
          Container(height: 8, decoration: BoxDecoration(gradient: LinearGradient(colors: [state.primaryColor, state.secondaryColor]), borderRadius: const BorderRadius.vertical(top: Radius.circular(16)))),
          Container(height: 28, color: AppTheme.grey900),
          const SizedBox(height: 12),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Container(height: 1, color: AppTheme.grey300), const SizedBox(height: 3), Text('Holder Signature', style: GoogleFonts.poppins(fontSize: 8, color: AppTheme.grey600))])),
                    const SizedBox(width: 10),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Container(height: 1, color: AppTheme.grey300), const SizedBox(height: 3), Text('Auth. Signature', style: GoogleFonts.poppins(fontSize: 8, color: AppTheme.grey600))])),
                  ],
                ),
                const SizedBox(height: 10),

                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: AppTheme.grey100, borderRadius: BorderRadius.circular(6)),
                  child: Row(
                    children: [
                      Icon(Icons.emergency, size: 14, color: AppTheme.error),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Emergency Contact', style: GoogleFonts.poppins(fontSize: 8, color: AppTheme.error, fontWeight: FontWeight.w600)),
                            Text('98765 43210', style: GoogleFonts.poppins(fontSize: 9, color: AppTheme.grey800)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),

                if (state.termsBack.isNotEmpty)
                  Text(state.termsBack, textAlign: TextAlign.center, style: GoogleFonts.poppins(fontSize: 7, color: AppTheme.grey600)),
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

            // Extra settings
            _SettingsSection(title: 'Properties', children: [
              _TextFieldRow(
                label: 'Terms (Front)',
                value: state.termsFront,
                onChanged: notifier.setTermsFront,
              ),
              _TextFieldRow(
                label: 'Terms (Back)',
                value: state.termsBack,
                onChanged: notifier.setTermsBack,
                maxLines: 2,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Text('Orientation', style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.grey800)),
                  const Spacer(),
                  DropdownButton<String>(
                    value: state.orientation,
                    style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.grey800),
                    underline: const SizedBox(),
                    items: const [
                      DropdownMenuItem(value: 'landscape', child: Text('Landscape')),
                      DropdownMenuItem(value: 'portrait', child: Text('Portrait')),
                    ],
                    onChanged: (v) => v != null ? notifier.setOrientation(v) : null,
                  ),
                ],
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

class _TextFieldRow extends StatelessWidget {
  final String label;
  final String value;
  final ValueChanged<String> onChanged;
  final int maxLines;

  const _TextFieldRow({
    required this.label,
    required this.value,
    required this.onChanged,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(label, style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.grey800)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextFormField(
              initialValue: value,
              onChanged: onChanged,
              maxLines: maxLines,
              style: GoogleFonts.poppins(fontSize: 12),
              decoration: InputDecoration(
                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(4),
                  borderSide: const BorderSide(color: AppTheme.grey300),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(4),
                  borderSide: const BorderSide(color: AppTheme.grey300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(4),
                  borderSide: const BorderSide(color: AppTheme.primary),
                ),
                filled: true,
                fillColor: AppTheme.grey50,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
