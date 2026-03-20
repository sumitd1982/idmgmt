// ============================================================
// Invites — Send invite links to staff via SMS
// ============================================================
const router   = require('express').Router();
const { v4: uuid } = require('uuid');
const axios    = require('axios');
const { query } = require('../models/db');
const { authenticate, requireRole } = require('../middleware/auth');

const MSG91_KEY      = process.env.MSG91_AUTH_KEY;
const MSG91_TEMPLATE = process.env.MSG91_INVITE_TEMPLATE_ID || process.env.MSG91_TEMPLATE_ID;
const APP_URL        = process.env.APP_URL || 'https://yourdomain.com';

// POST /invites — send an invite to a phone number
router.post('/', authenticate, requireRole('super_admin','principal','vp','head_teacher'), async (req, res, next) => {
  try {
    const { phone, school_id, role_level, message } = req.body;
    if (!phone) return res.status(400).json({ success: false, message: 'phone is required' });

    const mobile    = phone.replace(/\D/g, '');
    const schoolId  = school_id || req.employee?.school_id;
    const inviteId  = uuid();
    const inviteUrl = `${APP_URL}/login?invite=${inviteId}&school=${schoolId}&level=${role_level || 5}`;

    // Store invite record
    await query(
      `INSERT INTO invites (id, school_id, phone, role_level, invited_by, invite_url, status)
       VALUES (?, ?, ?, ?, ?, ?, 'pending')
       ON DUPLICATE KEY UPDATE
         role_level = VALUES(role_level),
         invited_by = VALUES(invited_by),
         invite_url = VALUES(invite_url),
         status = 'pending',
         created_at = NOW()`,
      [inviteId, schoolId, mobile, role_level || 5, req.user.id, inviteUrl]
    ).catch(() => null); // table may not exist yet — fail gracefully

    // Send SMS via MSG91
    const smsText = message ||
      `You have been invited to join SchoolID Pro. Sign in at ${APP_URL}/login`;

    if (MSG91_KEY) {
      try {
        await axios.post('https://api.msg91.com/api/v5/flow/', {
          template_id: MSG91_TEMPLATE,
          short_url: '0',
          mobiles: `91${mobile}`,
          invite_url: inviteUrl,
        }, {
          headers: { authkey: MSG91_KEY, 'Content-Type': 'application/json' }
        });
      } catch (smsErr) {
        // Log but don't fail — invite link is still generated
      }
    }

    res.json({ success: true, data: { invite_url: inviteUrl, phone: mobile } });
  } catch (err) { next(err); }
});

// GET /invites — list invites sent by this school
router.get('/', authenticate, async (req, res, next) => {
  try {
    const schoolId = req.employee?.school_id || req.query.school_id;
    const rows = await query(
      `SELECT i.*, CONCAT(u.full_name) AS invited_by_name
       FROM invites i
       LEFT JOIN users u ON u.id = i.invited_by
       WHERE i.school_id = ?
       ORDER BY i.created_at DESC`,
      [schoolId]
    ).catch(() => []);
    res.json({ success: true, data: rows });
  } catch (err) { next(err); }
});

module.exports = router;
