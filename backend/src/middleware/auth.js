// ============================================================
// Firebase Auth + Role-Based Access Control Middleware
// ============================================================
const admin  = require('firebase-admin');
const jwt    = require('jsonwebtoken');
const { query } = require('../models/db');
const logger    = require('../utils/logger');

const JWT_SECRET = process.env.JWT_SECRET || 'changeme';

// Initialize Firebase Admin (service account from env)
let firebaseInitialized = false;

const ensureFirebase = () => {
  if (!firebaseInitialized && process.env.FIREBASE_SERVICE_ACCOUNT) {
    try {
      const serviceAccount = JSON.parse(
        Buffer.from(process.env.FIREBASE_SERVICE_ACCOUNT, 'base64').toString('utf8')
      );
      admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });
      firebaseInitialized = true;
    } catch (e) {
      logger.warn('Firebase init failed — running in development mode without Firebase auth');
    }
  }
};

/**
 * Verify Firebase ID token only — does NOT require user to exist in DB.
 * Used for /auth/register where the user may not exist yet.
 */
const verifyToken = async (req, res, next) => {
  ensureFirebase();
  const authHeader = req.headers.authorization;

  if (!authHeader?.startsWith('Bearer ')) {
    return res.status(401).json({ success: false, message: 'No auth token provided' });
  }

  const token = authHeader.slice(7);

  try {
    if (firebaseInitialized) {
      const decoded = await admin.auth().verifyIdToken(token);
      req.firebaseUid   = decoded.uid;
      req.firebaseEmail = decoded.email;
      req.firebasePhone = decoded.phone_number;
    } else {
      const mock = JSON.parse(Buffer.from(token, 'base64').toString('utf8'));
      req.firebaseUid   = mock.uid;
      req.firebaseEmail = mock.email;
      req.firebasePhone = mock.phone;
    }
    next();
  } catch (err) {
    logger.warn(`Token verify failed: ${err.message}`);
    return res.status(401).json({ success: false, message: 'Invalid or expired token' });
  }
};

/**
 * Verify Firebase ID token and attach user to req.user (requires DB user to exist).
 * Also accepts own JWTs issued by /auth/otp/verify (for MSG91 phone login).
 */
const authenticate = async (req, res, next) => {
  ensureFirebase();
  const authHeader = req.headers.authorization;

  if (!authHeader?.startsWith('Bearer ')) {
    return res.status(401).json({ success: false, message: 'No auth token provided' });
  }

  const token = authHeader.slice(7);

  try {
    // ── Try own JWT first (MSG91 phone login) ──────────────────
    try {
      const decoded = jwt.verify(token, JWT_SECRET);
      if (decoded.userId) {
        const users = await query(
          'SELECT * FROM users WHERE id = ? AND is_active = TRUE LIMIT 1',
          [decoded.userId]
        );
        if (users.length) {
          req.user = users[0];
          if (req.user.role !== 'super_admin' && req.user.role !== 'parent') {
            const emps = await query(
              `SELECT e.*, r.level as role_level, r.can_approve, r.can_upload_bulk
               FROM employees e JOIN org_roles r ON e.org_role_id = r.id
               WHERE e.user_id = ? AND e.is_active = TRUE LIMIT 1`,
              [req.user.id]
            );
            if (emps.length) req.employee = emps[0];
          }
          return next();
        }
      }
    } catch (_) { /* not our JWT — try Firebase */ }

    // ── Try Firebase token (Google login) ─────────────────────
    let uid, email, phone;

    if (firebaseInitialized) {
      const decoded = await admin.auth().verifyIdToken(token);
      uid   = decoded.uid;
      email = decoded.email;
      phone = decoded.phone_number;
    } else {
      // Dev mode: accept a base64-encoded JSON mock token
      const mock = JSON.parse(Buffer.from(token, 'base64').toString('utf8'));
      uid   = mock.uid;
      email = mock.email;
      phone = mock.phone;
    }

    const users = await query(
      'SELECT * FROM users WHERE firebase_uid = ? AND is_active = TRUE LIMIT 1',
      [uid]
    );

    if (!users.length) {
      return res.status(401).json({ success: false, message: 'User not found or inactive' });
    }

    req.user = users[0];

    if (req.user.role !== 'super_admin' && req.user.role !== 'parent') {
      const emps = await query(
        `SELECT e.*, r.level as role_level, r.can_approve, r.can_upload_bulk
         FROM employees e
         JOIN org_roles r ON e.org_role_id = r.id
         WHERE e.user_id = ? AND e.is_active = TRUE LIMIT 1`,
        [req.user.id]
      );
      if (emps.length) req.employee = emps[0];
    }

    next();
  } catch (err) {
    logger.warn(`Auth failed: ${err.message}`);
    return res.status(401).json({ success: false, message: 'Invalid or expired token' });
  }
};

/**
 * Role gate middleware factory
 * @param {...string} roles — allowed roles
 */
const requireRole = (...roles) => (req, res, next) => {
  if (!req.user) return res.status(401).json({ success: false, message: 'Unauthenticated' });
  if (!roles.includes(req.user.role)) {
    return res.status(403).json({
      success: false,
      message: `Access denied. Required roles: ${roles.join(', ')}`
    });
  }
  next();
};

/**
 * Org level gate — requires employee level <= maxLevel
 */
const requireLevel = (maxLevel) => (req, res, next) => {
  if (!req.employee) {
    return res.status(403).json({ success: false, message: 'No employee context' });
  }
  if (req.employee.role_level > maxLevel) {
    return res.status(403).json({
      success: false,
      message: `Insufficient org level. Required: level <= ${maxLevel}`
    });
  }
  next();
};

/**
 * Ensure user belongs to the school in the request
 */
const requireSchoolAccess = async (req, res, next) => {
  const schoolId = req.params.schoolId || req.body.school_id || req.query.school_id;
  if (!schoolId) return next();

  if (req.user.role === 'super_admin') return next();

  if (!req.employee || req.employee.school_id !== schoolId) {
    return res.status(403).json({ success: false, message: 'Not authorized for this school' });
  }
  next();
};

module.exports = { authenticate, verifyToken, requireRole, requireLevel, requireSchoolAccess };
