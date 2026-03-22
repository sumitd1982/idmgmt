// ============================================================
// Theme Provider — Portal theme + layout + role-based defaults
// ============================================================
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/portal_theme_model.dart';
import '../models/user_model.dart';
import 'auth_provider.dart';
import 'api_provider.dart';

export '../models/portal_theme_model.dart' show AppLayout, PortalTheme, PortalThemes;

// ── Theme Settings ────────────────────────────────────────────
class ThemeSettings {
  final ThemeMode mode;
  final AppLayout layout;
  final PortalTheme portalTheme;

  const ThemeSettings({
    this.mode = ThemeMode.system,
    this.layout = AppLayout.modern,
    this.portalTheme = PortalThemes.classicIndigo,
  });

  Color get primaryColor => portalTheme.primaryColor;

  ThemeSettings copyWith({
    ThemeMode? mode,
    AppLayout? layout,
    PortalTheme? portalTheme,
  }) {
    return ThemeSettings(
      mode: mode ?? this.mode,
      layout: layout ?? this.layout,
      portalTheme: portalTheme ?? this.portalTheme,
    );
  }
}

// ── Notifier ──────────────────────────────────────────────────
class ThemeNotifier extends StateNotifier<ThemeSettings> {
  final Ref _ref;

  ThemeNotifier(this._ref) : super(const ThemeSettings()) {
    _ref.listen<AsyncValue<AppUser?>>(authNotifierProvider, (_, next) {
      final user = next.valueOrNull;
      if (user != null) _applyUserPrefs(user);
    });
  }

  void _applyUserPrefs(AppUser user) {
    final prefs = user.preferences;
    final themeId   = prefs['portal_theme_id'] as String?;
    final modeStr   = prefs['theme_mode'] as String?;
    final layoutStr = prefs['layout'] as String?;

    state = state.copyWith(
      portalTheme: PortalThemes.byId(themeId),
      mode: _parseMode(modeStr),
      layout: _parseLayout(layoutStr),
    );
  }

  ThemeMode _parseMode(String? m) {
    switch (m) {
      case 'light': return ThemeMode.light;
      case 'dark':  return ThemeMode.dark;
      default:      return ThemeMode.system;
    }
  }

  AppLayout _parseLayout(String? l) {
    switch (l) {
      case 'classic': return AppLayout.classic;
      case 'compact': return AppLayout.compact;
      case 'topbar':  return AppLayout.topbar;
      case 'minimal': return AppLayout.minimal;
      default:        return AppLayout.modern;
    }
  }

  // ── Public update methods ─────────────────────────────────

  Future<void> updatePortalTheme(PortalTheme theme) async {
    state = state.copyWith(portalTheme: theme);
    await _save({'portal_theme_id': theme.id});
  }

  Future<void> updateMode(ThemeMode mode) async {
    state = state.copyWith(mode: mode);
    await _save({'theme_mode': mode.name});
  }

  Future<void> updateLayout(AppLayout layout) async {
    state = state.copyWith(layout: layout);
    await _save({'layout': layout.name});
  }

  /// SuperAdmin: set the global portal default theme for all users
  Future<void> setGlobalDefault(PortalTheme theme) async {
    try {
      final api = _ref.read(apiServiceProvider);
      await api.put('/settings/portal-theme', body: {'portal_theme_id': theme.id});
    } catch (_) {}
  }

  /// School owner/admin: set default theme for their school's users
  Future<void> setSchoolDefault(String schoolId, PortalTheme theme, AppLayout layout) async {
    try {
      final api = _ref.read(apiServiceProvider);
      await api.put('/schools/$schoolId', body: {
        'settings': {
          'portal_theme_id': theme.id,
          'portal_layout': layout.name,
        }
      });
    } catch (_) {}
  }

  Future<void> _save(Map<String, dynamic> delta) async {
    try {
      final api = _ref.read(apiServiceProvider);
      await api.put('/users/preferences', body: delta);
    } catch (_) {}
  }
}

final themeProvider = StateNotifierProvider<ThemeNotifier, ThemeSettings>((ref) {
  return ThemeNotifier(ref);
});
