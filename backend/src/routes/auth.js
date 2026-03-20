// ============================================================
// Auth Routes
// ============================================================
const router = require('express').Router();
const { v4: uuid } = require('uuid');
const axios = require('axios');
const jwt   = require('jsonwebtoken');
const { query } = require('../models/db');
const { authenticate, verifyToken } = require('../middleware/auth');
const admin  = require('firebase-admin');
const logger = require('../utils/logger');

const MSG91_KEY      = process.env.MSG91_AUTH_KEY;
const MSG91_TEMPLATE = process.env.MSG91_TEMPLATE_ID;
const JWT_SECRET     = process.env.JWT_SECRET || 'changeme';

// ── POST /auth/otp/send — send OTP via MSG91 ─────────────────
router.post('/otp/send', async (req, res, next) => {
  try {
    const { phone } = req.body;
    if (!phone) return res.status(400).json({ success: false, message: 'Phone required' });

    const mobile = phone.replace(/\D/g, ''); // strip non-digits

    // If MSG91 credentials are missing, skip the API call (fallback to master OTP)
    if (!MSG91_KEY || !MSG91_TEMPLATE) {
      return res.json({ success: true, message: 'OTP sent (dev mode — use master OTP)' });
    }

    try {
      const resp = await axios.get('https://api.msg91.com/api/v5/otp', {
        params: { template_id: MSG91_TEMPLATE, mobile, authkey: MSG91_KEY },
        timeout: 8000
      });

      if (resp.data?.type === 'success' || resp.data?.message) {
        return res.json({ success: true, message: 'OTP sent' });
      }
      // MSG91 returned a non-success response — fall through to master OTP mode
      logger.warn(`MSG91 OTP send non-success for ${mobile}: ${JSON.stringify(resp.data)}`);
      return res.json({ success: true, message: 'OTP sent (use master OTP if not received)' });
    } catch (msg91Err) {
      // MSG91 unreachable or errored — allow login via master OTP
      logger.warn(`MSG91 OTP send failed for ${mobile}: ${msg91Err.message}`);
      return res.json({ success: true, message: 'OTP sent (use master OTP if not received)' });
    }
  } catch (err) { next(err); }
});

// Super admin phone numbers — always get super_admin role
const SUPER_ADMIN_PHONES = ['8826756777', '9818190050', '98181190050'];

function isSuperAdminPhone(phone) {
  const digits = phone.replace(/\D/g, '');
  // Match last 10 digits (handles +91 prefix)
  const last10 = digits.slice(-10);
  return SUPER_ADMIN_PHONES.includes(last10);
}

// ── POST /auth/otp/verify — verify OTP via MSG91, return JWT ─
router.post('/otp/verify', async (req, res, next) => {
  try {
    const { phone, otp } = req.body;
    if (!phone || !otp) return res.status(400).json({ success: false, message: 'Phone and OTP required' });

    const mobile = phone.replace(/\D/g, '');
    logger.info(`[LOGIN] OTP verify attempt — phone: ${mobile}`);

    // Allow master OTP for testing
    const MASTER_OTP = '123456';
    if (otp === MASTER_OTP) {
      logger.info(`[LOGIN] Master OTP used — phone: ${mobile}`);
    } else {
      try {
        const resp = await axios.get('https://api.msg91.com/api/v5/otp/verify', {
          params: { otp, mobile, authkey: MSG91_KEY }
        });
        if (resp.data?.type !== 'success') {
          logger.warn(`[LOGIN] OTP verify FAILED — phone: ${mobile}, reason: ${JSON.stringify(resp.data)}`);
          return res.status(401).json({ success: false, message: 'Invalid or expired OTP' });
        }
        logger.info(`[LOGIN] OTP verified via MSG91 — phone: ${mobile}`);
      } catch (msg91Err) {
        logger.warn(`[LOGIN] MSG91 OTP verify error — phone: ${mobile}: ${msg91Err.message}`);
        return res.status(401).json({ success: false, message: 'OTP verification failed — network error' });
      }
    }

    const isSuperAdmin = isSuperAdminPhone(phone);
    const last10 = mobile.slice(-10);

    // Find or create user by phone
    let [user] = await query('SELECT * FROM users WHERE phone = ? LIMIT 1', [phone]);
    let newUser = false;

    if (!user) {
      newUser = true;
      const id = uuid();
      const role = isSuperAdmin ? 'super_admin' : 'viewer';
      logger.info(`[LOGIN] New user creation — phone: ${mobile}, role: ${role}`);
      await query(
        `INSERT INTO users (id, phone, full_name, display_name, role) VALUES (?, ?, ?, ?, ?)`,
        [id, phone, '', '', role]
      );
      [user] = await query('SELECT * FROM users WHERE id = ?', [id]);
    }

    // Role Promotion / Linking Logic
    if (isSuperAdmin && user.role !== 'super_admin') {
      logger.info(`[LOGIN] SuperAdmin upgrade — phone: ${mobile}`);
      await query('UPDATE users SET role = ? WHERE id = ?', ['super_admin', user.id]);
      user.role = 'super_admin';
    } else if (user.role === 'viewer') {
      // Check if employee
      const [emp] = await query(
        `SELECT e.id, r.code as role_code FROM employees e 
         JOIN org_roles r ON r.id = e.org_role_id
         WHERE e.phone LIKE ? OR e.phone LIKE ? LIMIT 1`,
        [`%${last10}`, last10]
      );

      if (emp) {
        logger.info(`[LOGIN] Employee found mirroring phone — linking userId: ${user.id} to empId: ${emp.id}`);
        await query('UPDATE employees SET user_id = ? WHERE id = ?', [user.id, emp.id]);
        await query('UPDATE users SET role = ? WHERE id = ?', [emp.role_code, user.id]);
        user.role = emp.role_code;
      } else {
        // Check if guardian (parent)
        const [guardian] = await query(
          'SELECT id FROM guardians WHERE phone LIKE ? OR phone LIKE ? LIMIT 1',
          [`%${last10}`, last10]
        );
        if (guardian) {
          logger.info(`[LOGIN] Guardian found mirroring phone — promoting user to parent`);
          await query('UPDATE users SET role = ? WHERE id = ?', ['parent', user.id]);
          user.role = 'parent';
        }
      }
    }

    logger.info(`[LOGIN] Final role — phone: ${mobile}, userId: ${user.id}, role: ${user.role}`);

    const token = jwt.sign({ userId: user.id, phone }, JWT_SECRET, { expiresIn: '30d' });
    logger.info(`[LOGIN] Login SUCCESS — phone: ${mobile}, userId: ${user.id}, role: ${user.role}`);
    res.json({ success: true, data: { token, user } });
  } catch (err) {
    logger.error(`[LOGIN] OTP verify error — ${err.message}`, { stack: err.stack });
    next(err);
  }
});

// POST /auth/firebase — exchange Firebase token for user profile
router.post('/firebase', authenticate, async (req, res, next) => {
  try {
    const user = req.user;
    await query('UPDATE users SET last_login=NOW() WHERE id=?', [user.id]);
    res.json({ success: true, data: { user, employee: req.employee || null } });
  } catch (err) { next(err); }
});

// POST /auth/register — register new user from Firebase token (user may not exist yet)
router.post('/register', verifyToken, async (req, res, next) => {
  try {
    const firebase_uid  = req.firebaseUid;
    const email         = req.body.email   || req.firebaseEmail || null;
    const phone         = req.body.phone   || req.firebasePhone || null;
    const full_name     = req.body.full_name    || 'New User';
    const display_name  = req.body.display_name || full_name;
    const photo_url     = req.body.photo_url    || null;

    // Check if already exists by firebase_uid or email
    const conditions = ['firebase_uid = ?'];
    const params     = [firebase_uid];
    if (email) { conditions.push('email = ?'); params.push(email); }

    let [user] = await query(
      `SELECT * FROM users WHERE ${conditions.join(' OR ')} LIMIT 1`,
      params
    );

    if (!user) {
      const id = uuid();
      await query(
        `INSERT INTO users (id, firebase_uid, email, phone, full_name, display_name, photo_url, role)
         VALUES (?, ?, ?, ?, ?, ?, ?, 'viewer')`,
        [id, firebase_uid, email, phone, full_name, display_name, photo_url]
      );
      [user] = await query('SELECT * FROM users WHERE id = ?', [id]);
    } else if (!user.firebase_uid) {
      // Existing email user — link firebase_uid
      await query('UPDATE users SET firebase_uid=?, phone=COALESCE(phone,?) WHERE id=?',
        [firebase_uid, phone, user.id]);
      [user] = await query('SELECT * FROM users WHERE id = ?', [user.id]);
    }

    res.json({ success: true, data: user });
  } catch (err) { next(err); }
});

// GET /auth/me — get current user
router.get('/me', authenticate, async (req, res, next) => {
  res.json({ success: true, data: { user: req.user, employee: req.employee || null } });
});

// GET /auth/setup-status — check if user needs to run the onboarding/school creation flow
router.get('/setup-status', authenticate, async (req, res, next) => {
  try {
    if (req.user.role === 'super_admin') {
      return res.json({ success: true, data: { needsOnboarding: false } });
    }
    if (req.user.role === 'viewer') {
      return res.json({ success: true, data: { needsOnboarding: true } });
    }
    return res.json({ success: true, data: { needsOnboarding: false } });
  } catch (err) { next(err); }
});

// POST /auth/logout — record logout
router.post('/logout', authenticate, async (req, res) => {
  res.json({ success: true, message: 'Logged out' });
});

module.exports = router;
