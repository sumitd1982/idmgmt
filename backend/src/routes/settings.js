// ============================================================
// Settings Routes — Portal themes, global defaults
// ============================================================
const router = require('express').Router();
const { query } = require('../models/db');
const { authenticate, requireRole } = require('../middleware/auth');

// ── GET /settings/portal-themes — list all prebuilt themes ───
router.get('/portal-themes', async (req, res, next) => {
  try {
    const themes = await query(
      'SELECT * FROM portal_themes WHERE is_prebuilt = 1 ORDER BY sort_order',
      []
    );
    res.json({ success: true, data: themes });
  } catch (err) { next(err); }
});

// ── GET /settings/portal-theme — get current global default ──
router.get('/portal-theme', authenticate, async (req, res, next) => {
  try {
    const rows = await query(
      'SELECT setting_value FROM global_settings WHERE setting_key = ?',
      ['portal_theme_id']
    );
    const themeId = rows[0]?.setting_value ?? 'classic_indigo';
    res.json({ success: true, data: { portal_theme_id: themeId } });
  } catch (err) { next(err); }
});

// ── PUT /settings/portal-theme — super admin sets global default
router.put('/portal-theme',
  authenticate,
  requireRole('super_admin'),
  async (req, res, next) => {
    try {
      const { portal_theme_id, portal_layout, portal_theme_mode } = req.body;

      if (portal_theme_id) {
        await query(
          `INSERT INTO global_settings (setting_key, setting_value, updated_by)
           VALUES ('portal_theme_id', ?, ?)
           ON DUPLICATE KEY UPDATE setting_value = VALUES(setting_value), updated_by = VALUES(updated_by)`,
          [portal_theme_id, req.user.id]
        );
      }
      if (portal_layout) {
        await query(
          `INSERT INTO global_settings (setting_key, setting_value, updated_by)
           VALUES ('portal_layout', ?, ?)
           ON DUPLICATE KEY UPDATE setting_value = VALUES(setting_value), updated_by = VALUES(updated_by)`,
          [portal_layout, req.user.id]
        );
      }
      if (portal_theme_mode) {
        await query(
          `INSERT INTO global_settings (setting_key, setting_value, updated_by)
           VALUES ('portal_theme_mode', ?, ?)
           ON DUPLICATE KEY UPDATE setting_value = VALUES(setting_value), updated_by = VALUES(updated_by)`,
          [portal_theme_mode, req.user.id]
        );
      }

      res.json({ success: true, message: 'Global portal default updated.' });
    } catch (err) { next(err); }
  }
);

module.exports = router;
