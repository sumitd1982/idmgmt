// ============================================================
// Portal Theme Model — 10 prebuilt themes + 5 layout options
// ============================================================
import 'package:flutter/material.dart';

// ── Layout Options ────────────────────────────────────────────
enum AppLayout {
  modern,   // Left sidebar + card-based content
  classic,  // Top navbar + left sidebar (traditional)
  compact,  // Dense sidebar, smaller padding
  topbar,   // Horizontal top navigation only
  minimal,  // Centered content, no sidebar
}

extension AppLayoutX on AppLayout {
  String get label {
    switch (this) {
      case AppLayout.modern:  return 'Modern';
      case AppLayout.classic: return 'Classic';
      case AppLayout.compact: return 'Compact';
      case AppLayout.topbar:  return 'Topbar';
      case AppLayout.minimal: return 'Minimal';
    }
  }

  String get description {
    switch (this) {
      case AppLayout.modern:  return 'Card-based with floating left sidebar';
      case AppLayout.classic: return 'Top nav bar with collapsible side menu';
      case AppLayout.compact: return 'Dense layout for information-heavy screens';
      case AppLayout.topbar:  return 'Horizontal navigation across the top';
      case AppLayout.minimal: return 'Clean centered content, no sidebar';
    }
  }

  IconData get icon {
    switch (this) {
      case AppLayout.modern:  return Icons.view_sidebar_outlined;
      case AppLayout.classic: return Icons.space_dashboard_outlined;
      case AppLayout.compact: return Icons.view_compact_outlined;
      case AppLayout.topbar:  return Icons.view_stream_outlined;
      case AppLayout.minimal: return Icons.crop_square_outlined;
    }
  }
}

// ── Portal Theme ──────────────────────────────────────────────
class PortalTheme {
  final String id;          // unique slug, stored in user prefs
  final String name;
  final String description;
  final Color headerColor;
  final Color footerColor;
  final Color menuColor;
  final Color menuTextColor;
  final Color bodyColor;
  final Color cardColor;
  final Color primaryColor;
  final Color accentColor;
  final Color textColor;
  final Color subtleColor;
  final bool isDark;

  const PortalTheme({
    required this.id,
    required this.name,
    required this.description,
    required this.headerColor,
    required this.footerColor,
    required this.menuColor,
    required this.menuTextColor,
    required this.bodyColor,
    required this.cardColor,
    required this.primaryColor,
    required this.accentColor,
    required this.textColor,
    required this.subtleColor,
    this.isDark = false,
  });

  ThemeMode get themeMode => isDark ? ThemeMode.dark : ThemeMode.light;
}

// ── 10 Prebuilt Portal Themes ─────────────────────────────────
class PortalThemes {
  PortalThemes._();

  static const PortalTheme classicIndigo = PortalTheme(
    id: 'classic_indigo',
    name: 'Classic Indigo',
    description: 'Deep professional blue — the default official look',
    headerColor:  Color(0xFF1A237E),
    footerColor:  Color(0xFF0D1B63),
    menuColor:    Color(0xFF283593),
    menuTextColor:Color(0xFFFFFFFF),
    bodyColor:    Color(0xFFF5F7FA),
    cardColor:    Color(0xFFFFFFFF),
    primaryColor: Color(0xFF1A237E),
    accentColor:  Color(0xFFFF6F00),
    textColor:    Color(0xFF212121),
    subtleColor:  Color(0xFF757575),
  );

  static const PortalTheme emeraldForest = PortalTheme(
    id: 'emerald_forest',
    name: 'Emerald Forest',
    description: 'Fresh and natural — ideal for environment-focused schools',
    headerColor:  Color(0xFF1B5E20),
    footerColor:  Color(0xFF0A3D12),
    menuColor:    Color(0xFF2E7D32),
    menuTextColor:Color(0xFFFFFFFF),
    bodyColor:    Color(0xFFF1F8E9),
    cardColor:    Color(0xFFFFFFFF),
    primaryColor: Color(0xFF2E7D32),
    accentColor:  Color(0xFFFFEB3B),
    textColor:    Color(0xFF1B2E1C),
    subtleColor:  Color(0xFF558B2F),
  );

  static const PortalTheme royalAmethyst = PortalTheme(
    id: 'royal_amethyst',
    name: 'Royal Amethyst',
    description: 'Premium purple gradient — sophisticated and distinguished',
    headerColor:  Color(0xFF4A148C),
    footerColor:  Color(0xFF2D0056),
    menuColor:    Color(0xFF6A1B9A),
    menuTextColor:Color(0xFFFFFFFF),
    bodyColor:    Color(0xFFF8F0FF),
    cardColor:    Color(0xFFFFFFFF),
    primaryColor: Color(0xFF6A1B9A),
    accentColor:  Color(0xFFF9A825),
    textColor:    Color(0xFF1A0030),
    subtleColor:  Color(0xFF7B1FA2),
  );

  static const PortalTheme oceanTeal = PortalTheme(
    id: 'ocean_teal',
    name: 'Ocean Teal',
    description: 'Cool teal & coral — vibrant and modern',
    headerColor:  Color(0xFF006064),
    footerColor:  Color(0xFF003D40),
    menuColor:    Color(0xFF00838F),
    menuTextColor:Color(0xFFFFFFFF),
    bodyColor:    Color(0xFFE0F7FA),
    cardColor:    Color(0xFFFFFFFF),
    primaryColor: Color(0xFF00838F),
    accentColor:  Color(0xFFFF7043),
    textColor:    Color(0xFF002B2E),
    subtleColor:  Color(0xFF00ACC1),
  );

  static const PortalTheme slateModern = PortalTheme(
    id: 'slate_modern',
    name: 'Slate Modern',
    description: 'Minimal slate grey — clean, no-distraction design',
    headerColor:  Color(0xFF37474F),
    footerColor:  Color(0xFF1C2B30),
    menuColor:    Color(0xFF455A64),
    menuTextColor:Color(0xFFECEFF1),
    bodyColor:    Color(0xFFF0F4F8),
    cardColor:    Color(0xFFFFFFFF),
    primaryColor: Color(0xFF455A64),
    accentColor:  Color(0xFFFFCA28),
    textColor:    Color(0xFF212121),
    subtleColor:  Color(0xFF78909C),
  );

  static const PortalTheme sunriseAmber = PortalTheme(
    id: 'sunrise_amber',
    name: 'Sunrise Amber',
    description: 'Warm amber and deep brown — energetic and welcoming',
    headerColor:  Color(0xFFE65100),
    footerColor:  Color(0xFF8D2700),
    menuColor:    Color(0xFFBF360C),
    menuTextColor:Color(0xFFFFFFFF),
    bodyColor:    Color(0xFFFFF8F0),
    cardColor:    Color(0xFFFFFFFF),
    primaryColor: Color(0xFFE65100),
    accentColor:  Color(0xFF1565C0),
    textColor:    Color(0xFF3E1600),
    subtleColor:  Color(0xFFFF7043),
  );

  static const PortalTheme crimsonPower = PortalTheme(
    id: 'crimson_power',
    name: 'Crimson Power',
    description: 'Bold red authority — strong and assertive',
    headerColor:  Color(0xFFB71C1C),
    footerColor:  Color(0xFF7F0000),
    menuColor:    Color(0xFFC62828),
    menuTextColor:Color(0xFFFFFFFF),
    bodyColor:    Color(0xFFFFF5F5),
    cardColor:    Color(0xFFFFFFFF),
    primaryColor: Color(0xFFC62828),
    accentColor:  Color(0xFFFFC107),
    textColor:    Color(0xFF3E0000),
    subtleColor:  Color(0xFFE57373),
  );

  static const PortalTheme midnightPro = PortalTheme(
    id: 'midnight_pro',
    name: 'Midnight Pro',
    description: 'Full dark mode — easy on eyes, modern feel',
    headerColor:  Color(0xFF0D0D0D),
    footerColor:  Color(0xFF050505),
    menuColor:    Color(0xFF1A1A2E),
    menuTextColor:Color(0xFFE0E0E0),
    bodyColor:    Color(0xFF121212),
    cardColor:    Color(0xFF1E1E2E),
    primaryColor: Color(0xFF7C83FD),
    accentColor:  Color(0xFFFF79C6),
    textColor:    Color(0xFFE0E0E0),
    subtleColor:  Color(0xFF9E9E9E),
    isDark: true,
  );

  static const PortalTheme roseBlossom = PortalTheme(
    id: 'rose_blossom',
    name: 'Rose Blossom',
    description: 'Soft rose gold — warm, welcoming and elegant',
    headerColor:  Color(0xFFAD1457),
    footerColor:  Color(0xFF78003E),
    menuColor:    Color(0xFFC2185B),
    menuTextColor:Color(0xFFFFFFFF),
    bodyColor:    Color(0xFFFFF0F5),
    cardColor:    Color(0xFFFFFFFF),
    primaryColor: Color(0xFFC2185B),
    accentColor:  Color(0xFFFFD700),
    textColor:    Color(0xFF3D001A),
    subtleColor:  Color(0xFFE91E63),
  );

  static const PortalTheme earthKhaki = PortalTheme(
    id: 'earth_khaki',
    name: 'Earth Khaki',
    description: 'Warm earthy tones — grounded and natural',
    headerColor:  Color(0xFF4E342E),
    footerColor:  Color(0xFF2C1A15),
    menuColor:    Color(0xFF6D4C41),
    menuTextColor:Color(0xFFFFF8E1),
    bodyColor:    Color(0xFFFAF3E8),
    cardColor:    Color(0xFFFFFFFF),
    primaryColor: Color(0xFF6D4C41),
    accentColor:  Color(0xFF8BC34A),
    textColor:    Color(0xFF1A0F0A),
    subtleColor:  Color(0xFF8D6E63),
  );

  /// All 10 themes in display order
  static const List<PortalTheme> all = [
    classicIndigo,
    emeraldForest,
    royalAmethyst,
    oceanTeal,
    slateModern,
    sunriseAmber,
    crimsonPower,
    midnightPro,
    roseBlossom,
    earthKhaki,
  ];

  /// Look up by ID (returns classicIndigo as fallback)
  static PortalTheme byId(String? id) {
    if (id == null) return classicIndigo;
    return all.firstWhere((t) => t.id == id, orElse: () => classicIndigo);
  }
}
