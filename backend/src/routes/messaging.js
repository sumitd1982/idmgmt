// ============================================================
// Messaging & Queries Routes
// ============================================================
const router  = require('express').Router();
const { v4: uuid } = require('uuid');
const { query, transaction } = require('../models/db');
const { authenticate } = require('../middleware/auth');
const { body, validationResult } = require('express-validator');

const validate = (req, res, next) => {
  const errors = validationResult(req);
  if (!errors.isEmpty()) return res.status(422).json({ success: false, errors: errors.array() });
  next();
};

/**
 * Middleware to check if the school has messaging enabled.
 */
const requireMessagingEnabled = async (req, res, next) => {
  try {
    const isSchoolScoped = req.user.role === 'super_admin' || req.user.role === 'school_owner';
    const schoolId = req.user.role === 'parent' ? (req.query.school_id || req.body.school_id) : (isSchoolScoped ? (req.user.school_id || req.query.school_id || req.body.school_id) : req.employee?.school_id);
    if (!schoolId) return res.status(400).json({ success: false, message: 'school_id is required to verify settings' });
    
    const [school] = await query('SELECT settings FROM schools WHERE id = ?', [schoolId]);
    if (!school) return res.status(404).json({ success: false, message: 'School not found' });

    let settings = {};
    if (school.settings) {
      settings = typeof school.settings === 'string' ? JSON.parse(school.settings) : school.settings;
    }

    if (settings.is_messaging_enabled === false) {
      return res.status(403).json({ success: false, message: 'Messaging is currently disabled by the school administration.' });
    }
    next();
  } catch (err) {
    next(err);
  }
};

// ── GET /messaging — list conversations ───────────────────────
router.get('/', authenticate, async (req, res, next) => {
  try {
    let whereParams = [];
    let whereClause = '';

    if (req.user.role === 'parent') {
      whereClause = 'c.parent_id = ?';
      whereParams.push(req.user.id);
    } else {
      // It's an employee
      if (!req.employee) return res.status(403).json({ success: false, message: 'Employee profile not found' });
      
      if (['super_admin', 'school_owner', 'school_admin', 'principal'].includes(req.user.role)) {
         // SuperAdmins can pass school_id in query, others use their session school_id
         const isGlobalAdmin = req.user.role === 'super_admin';
         const schoolId = isGlobalAdmin ? req.query.school_id : (req.user.school_id || req.employee?.school_id);
         if (!schoolId) return res.status(400).json({ success: false, message: 'school_id query param required for this role' });
         
         whereClause = 'c.school_id = ?';
         whereParams.push(schoolId);
      } else {
         whereClause = 'c.employee_id = ?'; // Teachers see only theirs
         whereParams.push(req.employee.id);
      }
    }

    const conversations = await query(
      `SELECT c.*, 
              s.first_name AS student_first, s.last_name AS student_last, s.class_name,
              e.first_name AS emp_first, e.last_name AS emp_last,
              u.full_name AS parent_name
       FROM conversations c
       JOIN students s ON s.id = c.student_id
       JOIN employees e ON e.id = c.employee_id
       JOIN users u ON u.id = c.parent_id
       WHERE ${whereClause}
       ORDER BY c.updated_at DESC`,
      whereParams
    );

    res.json({ success: true, data: conversations });
  } catch (err) { next(err); }
});

// ── GET /messaging/:id/messages — get messages in a thread ────
router.get('/:id/messages', authenticate, async (req, res, next) => {
  try {
    const [conv] = await query('SELECT * FROM conversations WHERE id = ?', [req.params.id]);
    if (!conv) return res.status(404).json({ success: false, message: 'Conversation not found' });

    // Mark as read basically... 
    // In a real app we'd track who read it. We skip complex read-receipts for brevity.
    
    const messages = await query(
      `SELECT * FROM messages WHERE conversation_id = ? ORDER BY created_at ASC`,
      [req.params.id]
    );

    res.json({ success: true, data: messages });
  } catch (err) { next(err); }
});

// ── POST /messaging — create a new conversation ──────────────
router.post('/', 
  authenticate,
  requireMessagingEnabled,
  [
    body('school_id').notEmpty(),
    body('student_id').notEmpty(),
    body('employee_id').notEmpty(),
    body('subject').notEmpty().trim(),
    body('message').notEmpty().trim()
  ],
  validate,
  async (req, res, next) => {
    try {
      const { school_id, student_id, employee_id, subject, message } = req.body;
      const convId = uuid();
      
      const parentId = req.user.role === 'parent' ? req.user.id : req.body.parent_id;
      if (!parentId) return res.status(400).json({ success: false, message: 'parent_id is required' });

      // Start transaction
      const connection = await transaction();
      try {
        await connection.query(
          `INSERT INTO conversations (id, school_id, student_id, employee_id, parent_id, subject, status)
           VALUES (?, ?, ?, ?, ?, ?, 'open')`,
          [convId, school_id, student_id, employee_id, parentId, subject]
        );

        const msgId = uuid();
        const senderType = req.user.role === 'parent' ? 'parent' : 'employee';
        // Note: sender_id is either parent's user_id or employee's employee_id.
        const senderId = req.user.role === 'parent' ? req.user.id : req.employee?.id;

        await connection.query(
          `INSERT INTO messages (id, conversation_id, sender_id, sender_type, body)
           VALUES (?, ?, ?, ?, ?)`,
          [msgId, convId, senderId, senderType, message]
        );

        await connection.commit();
        res.status(201).json({ success: true, data: { id: convId }, message: 'Conversation created' });
      } catch (err) {
        await connection.rollback();
        throw err;
      } finally {
        connection.release();
      }
    } catch (err) { next(err); }
  }
);

// ── POST /messaging/:id/messages — reply to a thread ──────────
router.post('/:id/messages', 
  authenticate,
  [
    body('message').notEmpty().trim()
  ],
  validate,
  async (req, res, next) => {
    try {
      const { message } = req.body;
      const convId = req.params.id;

      const [conv] = await query('SELECT * FROM conversations WHERE id = ?', [convId]);
      if (!conv) return res.status(404).json({ success: false, message: 'Conversation not found' });
      if (conv.status === 'closed') return res.status(400).json({ success: false, message: 'Conversation is closed' });

      const msgId = uuid();
      const senderType = req.user.role === 'parent' ? 'parent' : 'employee';
      const senderId = req.user.role === 'parent' ? req.user.id : req.employee?.id;

      const connection = await transaction();
      try {
        await connection.query(
          `INSERT INTO messages (id, conversation_id, sender_id, sender_type, body)
           VALUES (?, ?, ?, ?, ?)`,
          [msgId, convId, senderId, senderType, message]
        );

        // Update the conversation's updated_at timestamp and potentially set it back to open if it was resolved
        await connection.query(
          `UPDATE conversations SET updated_at = CURRENT_TIMESTAMP, status = 'open' WHERE id = ?`,
          [convId]
        );

        await connection.commit();
        res.status(201).json({ success: true, message: 'Message sent' });
      } catch (err) {
        await connection.rollback();
        throw err;
      } finally {
        connection.release();
      }
    } catch (err) { next(err); }
  }
);

// ── PATCH /messaging/:id/status — mark as resolved/closed ─────
router.patch('/:id/status', 
  authenticate,
  [
    body('status').isIn(['open', 'resolved', 'closed'])
  ],
  validate,
  async (req, res, next) => {
    try {
      const { status } = req.body;
      await query(`UPDATE conversations SET status = ? WHERE id = ?`, [status, req.params.id]);
      res.json({ success: true, message: `Conversation marked as ${status}` });
    } catch (err) { next(err); }
  }
);

module.exports = router;
