// ============================================================
// Users & Profile Management Routes
// ============================================================
const router = require('express').Router();
const { query } = require('../models/db');
const { authenticate } = require('../middleware/auth');
const { body, validationResult } = require('express-validator');

const validate = (req, res, next) => {
  const errors = validationResult(req);
  if (!errors.isEmpty()) return res.status(422).json({ success: false, errors: errors.array() });
  next();
};

// ── PUT /users/preferences ────────────────────────────────────
router.put('/preferences',
  authenticate,
  [
    body('theme_mode').optional().isIn(['light', 'dark', 'system']),
    body('layout').optional().isString(),
    body('primary_color').optional().isHexColor(),
    body('sidebar_style').optional().isString(),
    body('portal_theme_id').optional().isString(),
  ],
  validate,
  async (req, res, next) => {
    try {
      // Get current preferences
      const [user] = await query('SELECT preferences FROM users WHERE id = ?', [req.user.id]);
      const currentPrefs = user.preferences || {};
      
      const newPrefs = {
        ...currentPrefs,
        ...req.body
      };

      await query(
        'UPDATE users SET preferences = ? WHERE id = ?',
        [JSON.stringify(newPrefs), req.user.id]
      );

      res.json({ success: true, data: newPrefs });
    } catch (err) { next(err); }
  }
);

module.exports = router;
