import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user_model.dart';
import 'auth_provider.dart';
import 'api_provider.dart';

enum AppLayout { modern, classic, compact, topnav }

class ThemeSettings {
  final ThemeMode mode;
  final AppLayout layout;
  final Color? primaryColor;

  const ThemeSettings({
    this.mode = ThemeMode.system,
    this.layout = AppLayout.modern,
    this.primaryColor,
  });

  ThemeSettings copyWith({
    ThemeMode? mode,
    AppLayout? layout,
    Color? primaryColor,
  }) {
    return ThemeSettings(
      mode: mode ?? this.mode,
      layout: layout ?? this.layout,
      primaryColor: primaryColor ?? this.primaryColor,
    );
  }
}

class ThemeNotifier extends StateNotifier<ThemeSettings> {
  final Ref _ref;

  ThemeNotifier(this._ref) : super(const ThemeSettings()) {
    _init();
  }

  void _init() {
    _ref.listen<AsyncValue<AppUser?>>(authNotifierProvider, (prev, next) {
      final user = next.valueOrNull;
      if (user != null) {
        // Load from user preferences
        final prefs = user.preferences;
        final modeStr = prefs['theme_mode'] as String?;
        final layoutStr = prefs['layout'] as String?;
        final colorStr = prefs['primary_color'] as String?;

        state = state.copyWith(
          mode: _parseMode(modeStr),
          layout: _parseLayout(layoutStr),
          primaryColor: colorStr != null ? _parseColor(colorStr) : null,
        );
      }
    });
  }

  ThemeMode _parseMode(String? mode) {
    switch (mode) {
      case 'light': return ThemeMode.light;
      case 'dark': return ThemeMode.dark;
      default: return ThemeMode.system;
    }
  }

  AppLayout _parseLayout(String? layout) {
    switch (layout) {
      case 'classic': return AppLayout.classic;
      case 'compact': return AppLayout.compact;
      case 'topnav': return AppLayout.topnav;
      default: return AppLayout.modern;
    }
  }

  Color? _parseColor(String hex) {
    try {
      return Color(int.parse(hex.replaceFirst('#', '0xFF')));
    } catch (_) { return null; }
  }

  Future<void> updateTheme(ThemeMode mode) async {
    state = state.copyWith(mode: mode);
    await _saveTheme({'theme_mode': mode.name});
  }

  Future<void> updateLayout(AppLayout layout) async {
    state = state.copyWith(layout: layout);
    await _saveTheme({'layout': layout.name});
  }

  Future<void> _saveTheme(Map<String, dynamic> delta) async {
    try {
      final api = _ref.read(apiServiceProvider);
      await api.put('/users/preferences', body: delta);
    } catch (_) {}
  }
}

final themeProvider = StateNotifierProvider<ThemeNotifier, ThemeSettings>((ref) {
  return ThemeNotifier(ref);
});
