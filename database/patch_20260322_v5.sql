-- ============================================================
-- PATCH 2026-03-22 v5: Portal Themes System
--   1. portal_themes table — 10 prebuilt themes
--   2. global_settings table — portal-wide defaults (super admin)
--   3. schools.settings extended to hold portal_theme_id + portal_layout
--   4. users.preferences extended (no schema change — JSON field)
-- ============================================================
USE idmgmt;
SET FOREIGN_KEY_CHECKS = 0;

-- ── 1. Portal Themes table ───────────────────────────────────
CREATE TABLE IF NOT EXISTS portal_themes (
  id              VARCHAR(36)   NOT NULL DEFAULT (UUID()) PRIMARY KEY,
  theme_id        VARCHAR(60)   NOT NULL UNIQUE COMMENT 'slug used in user prefs',
  name            VARCHAR(100)  NOT NULL,
  description     TEXT          NULL,
  header_color    VARCHAR(20)   NOT NULL,
  footer_color    VARCHAR(20)   NOT NULL,
  menu_color      VARCHAR(20)   NOT NULL,
  menu_text_color VARCHAR(20)   NOT NULL DEFAULT '#FFFFFF',
  body_color      VARCHAR(20)   NOT NULL,
  card_color      VARCHAR(20)   NOT NULL DEFAULT '#FFFFFF',
  primary_color   VARCHAR(20)   NOT NULL,
  accent_color    VARCHAR(20)   NOT NULL,
  text_color      VARCHAR(20)   NOT NULL,
  subtle_color    VARCHAR(20)   NOT NULL,
  is_dark         TINYINT(1)    NOT NULL DEFAULT 0,
  is_prebuilt     TINYINT(1)    NOT NULL DEFAULT 1,
  sort_order      INT           NOT NULL DEFAULT 0,
  created_at      DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_pt_slug (theme_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ── 2. Seed 10 prebuilt portal themes ────────────────────────
INSERT IGNORE INTO portal_themes
  (theme_id, name, description, header_color, footer_color, menu_color, menu_text_color,
   body_color, card_color, primary_color, accent_color, text_color, subtle_color, is_dark, sort_order)
VALUES
('classic_indigo',  'Classic Indigo',   'Deep professional blue',            '#1A237E','#0D1B63','#283593','#FFFFFF','#F5F7FA','#FFFFFF','#1A237E','#FF6F00','#212121','#757575', 0, 1),
('emerald_forest',  'Emerald Forest',   'Fresh and natural green',           '#1B5E20','#0A3D12','#2E7D32','#FFFFFF','#F1F8E9','#FFFFFF','#2E7D32','#FFEB3B','#1B2E1C','#558B2F', 0, 2),
('royal_amethyst',  'Royal Amethyst',   'Premium purple gradient',           '#4A148C','#2D0056','#6A1B9A','#FFFFFF','#F8F0FF','#FFFFFF','#6A1B9A','#F9A825','#1A0030','#7B1FA2', 0, 3),
('ocean_teal',      'Ocean Teal',       'Cool teal and coral',               '#006064','#003D40','#00838F','#FFFFFF','#E0F7FA','#FFFFFF','#00838F','#FF7043','#002B2E','#00ACC1', 0, 4),
('slate_modern',    'Slate Modern',     'Minimal slate grey',                '#37474F','#1C2B30','#455A64','#ECEFF1','#F0F4F8','#FFFFFF','#455A64','#FFCA28','#212121','#78909C', 0, 5),
('sunrise_amber',   'Sunrise Amber',    'Warm amber and deep brown',         '#E65100','#8D2700','#BF360C','#FFFFFF','#FFF8F0','#FFFFFF','#E65100','#1565C0','#3E1600','#FF7043', 0, 6),
('crimson_power',   'Crimson Power',    'Bold red authority',                '#B71C1C','#7F0000','#C62828','#FFFFFF','#FFF5F5','#FFFFFF','#C62828','#FFC107','#3E0000','#E57373', 0, 7),
('midnight_pro',    'Midnight Pro',     'Full dark mode',                    '#0D0D0D','#050505','#1A1A2E','#E0E0E0','#121212','#1E1E2E','#7C83FD','#FF79C6','#E0E0E0','#9E9E9E', 1, 8),
('rose_blossom',    'Rose Blossom',     'Soft rose gold, warm and elegant',  '#AD1457','#78003E','#C2185B','#FFFFFF','#FFF0F5','#FFFFFF','#C2185B','#FFD700','#3D001A','#E91E63', 0, 9),
('earth_khaki',     'Earth Khaki',      'Warm earthy tones',                 '#4E342E','#2C1A15','#6D4C41','#FFF8E1','#FAF3E8','#FFFFFF','#6D4C41','#8BC34A','#1A0F0A','#8D6E63', 0,10);

-- ── 3. Global settings table (super admin portal-wide defaults)
CREATE TABLE IF NOT EXISTS global_settings (
  id              VARCHAR(36)   NOT NULL DEFAULT (UUID()) PRIMARY KEY,
  setting_key     VARCHAR(100)  NOT NULL UNIQUE,
  setting_value   TEXT          NULL,
  updated_by      VARCHAR(36)   NULL,
  updated_at      DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  FOREIGN KEY (updated_by) REFERENCES users(id) ON DELETE SET NULL,
  INDEX idx_gs_key (setting_key)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Seed defaults
INSERT IGNORE INTO global_settings (setting_key, setting_value) VALUES
  ('portal_theme_id',  'classic_indigo'),
  ('portal_layout',    'modern'),
  ('portal_theme_mode','system');

SET FOREIGN_KEY_CHECKS = 1;
-- ============================================================
