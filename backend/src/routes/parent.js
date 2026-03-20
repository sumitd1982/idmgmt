// ============================================================
// Parent Review Portal Routes
// ============================================================
const router  = require('express').Router();
const { v4: uuid }   = require('uuid');
const crypto  = require('crypto');
const { query, transaction } = require('../models/db');
const { authenticate } = require('../middleware/auth');
const logger  = require('../utils/logger');

// ── POST /parent/send-link — Teacher sends review link ────────
router.post('/send-link', authenticate, async (req, res, next) => {
  try {
    const { student_ids, message, expires_hours = 72 } = req.body;
    if (!student_ids?.length) return res.status(400).json({ success: false, message: 'No students specified' });

    const employeeId = req.employee?.id;
    if (!employeeId) return res.status(403).json({ success: false, message: 'Not an employee' });

    const results = [];

    for (const sid of student_ids) {
      const [student] = await query(
        `SELECT s.*, b.name AS branch_name, sch.name AS school_name
         FROM students s
         JOIN branches b ON b.id = s.branch_id
         JOIN schools sch ON sch.id = s.school_id
         WHERE s.id = ?`, [sid]
      );
      if (!student) { results.push({ id: sid, error: 'Not found' }); continue; }

      const guardians = await query('SELECT * FROM guardians WHERE student_id = ?', [sid]);

      // Create review token
      const token     = crypto.randomBytes(32).toString('hex');
      const expiresAt = new Date(Date.now() + expires_hours * 60 * 60 * 1000);

      // Snapshot current data
      const snapshot = {
        student: { ...student },
        guardians: guardians
      };

      await query(
        `INSERT INTO parent_reviews (id, student_id, review_token, link_sent_by,
           link_sent_at, link_expires_at, original_data, status)
         VALUES (?,?,?,?,NOW(),?,?,'link_sent')
         ON DUPLICATE KEY UPDATE
           review_token=VALUES(review_token),
           link_sent_at=NOW(),
           link_expires_at=VALUES(link_expires_at),
           original_data=VALUES(original_data),
           status='link_sent'`,
        [uuid(), sid, token, employeeId, expiresAt, JSON.stringify(snapshot)]
      );

      const reviewUrl = `${process.env.APP_BASE_URL || 'https://80.225.246.32'}/idmgmt/parent-review?token=${token}`;

      // Queue notifications to all guardians
      for (const g of guardians.filter(g => g.phone || g.whatsapp_no || g.email)) {
        const msgText = message ||
          `Dear Parent, please review ${student.first_name}'s details for ${student.school_name}.\nLink: ${reviewUrl}\nExpires: ${expiresAt.toLocaleDateString('en-IN')}`;

        if (g.whatsapp_no) {
          await query(
            `INSERT INTO notifications (id, school_id, recipient_type, recipient_id, channel, message)
             VALUES (?,?,'guardian',?,'whatsapp',?)`,
            [uuid(), student.school_id, g.id, msgText]
          );
        }
        if (g.phone) {
          await query(
            `INSERT INTO notifications (id, school_id, recipient_type, recipient_id, channel, message)
             VALUES (?,?,'guardian',?,'sms',?)`,
            [uuid(), student.school_id, g.id, msgText]
          );
        }
      }

      results.push({ id: sid, token, review_url: reviewUrl });
    }

    // Update students status to pending
    if (student_ids.length) {
      await query(
        `UPDATE students SET status_color='red', review_status='pending'
         WHERE id IN (${student_ids.map(() => '?').join(',')})`,
        student_ids
      );
    }

    res.json({ success: true, data: results });
  } catch (err) { next(err); }
});

// ── GET /parent/review — Public: get student data via token ──
router.get('/review', async (req, res, next) => {
  try {
    const { token } = req.query;
    if (!token) return res.status(400).json({ success: false, message: 'Token required' });

    const [review] = await query(
      `SELECT pr.*, s.first_name, s.last_name, s.class_name, s.section,
              s.photo_url, s.school_id, s.branch_id,
              sch.name AS school_name, b.name AS branch_name
       FROM parent_reviews pr
       JOIN students s ON s.id = pr.student_id
       JOIN schools sch ON sch.id = s.school_id
       JOIN branches b ON b.id = s.branch_id
       WHERE pr.review_token = ?`, [token]
    );

    if (!review) return res.status(404).json({ success: false, message: 'Invalid or expired link' });
    if (new Date(review.link_expires_at) < new Date()) {
      await query(`UPDATE parent_reviews SET status='expired' WHERE review_token=?`, [token]);
      return res.status(410).json({ success: false, message: 'Review link has expired' });
    }
    if (review.status === 'approved' || review.status === 'rejected') {
      return res.status(409).json({ success: false, message: 'This review has already been processed' });
    }

    const guardians = await query('SELECT * FROM guardians WHERE student_id = ?', [review.student_id]);

    res.json({
      success: true,
      data: {
        review_id: review.id,
        student: JSON.parse(review.original_data).student,
        guardians: JSON.parse(review.original_data).guardians,
        school_name: review.school_name,
        branch_name: review.branch_name,
        expires_at: review.link_expires_at,
        status: review.status
      }
    });
  } catch (err) { next(err); }
});

// ── POST /parent/review — Public: parent submits changes ──────
router.post('/review', async (req, res, next) => {
  try {
    const { token, student_data, guardians_data } = req.body;
    if (!token) return res.status(400).json({ success: false, message: 'Token required' });

    const [review] = await query(
      `SELECT * FROM parent_reviews WHERE review_token = ? AND status IN ('link_sent','parent_submitted')`,
      [token]
    );
    if (!review) return res.status(404).json({ success: false, message: 'Invalid link' });
    if (new Date(review.link_expires_at) < new Date()) {
      return res.status(410).json({ success: false, message: 'Link expired' });
    }

    // Compute diff
    const original = JSON.parse(review.original_data);
    const diff     = {};
    const allowedFields = ['first_name','last_name','date_of_birth','address_line1',
                           'address_line2','city','state','zip_code','bus_route','bus_stop'];

    for (const f of allowedFields) {
      if (student_data[f] !== undefined && student_data[f] !== original.student[f]) {
        diff[f] = { old: original.student[f], new: student_data[f] };
      }
    }

    // Photo updates
    if (student_data.photo_url && student_data.photo_url !== original.student.photo_url) {
      diff['photo_url'] = { old: original.student.photo_url, new: student_data.photo_url };
    }

    const submitted = { student: student_data, guardians: guardians_data };
    const hasChanges = Object.keys(diff).length > 0;

    await query(
      `UPDATE parent_reviews SET
         submitted_at=NOW(), submitted_data=?, changes_summary=?, status='parent_submitted'
       WHERE review_token=?`,
      [JSON.stringify(submitted), JSON.stringify(diff), token]
    );

    // Update student status color
    const [r] = await query('SELECT student_id FROM parent_reviews WHERE review_token=?', [token]);
    await query(
      `UPDATE students SET status_color=?, review_status='parent_reviewed' WHERE id=?`,
      [hasChanges ? 'blue' : 'green', review.student_id]
    );

    // Notify teacher (backup teacher if class teacher unavailable)
    const [teacher] = await query(
      `SELECT e.*, u.full_name FROM employees e
       JOIN users u ON u.id = e.user_id
       WHERE e.id = ?`, [review.link_sent_by]
    );

    if (teacher) {
      const notifMsg = `Parent has ${hasChanges ? 'submitted changes' : 'confirmed details'} for student.`;
      await query(
        `INSERT INTO notifications (id, school_id, recipient_type, recipient_id, channel, message)
         VALUES (?,?,'employee',?,'whatsapp',?)`,
        [uuid(), teacher.school_id, teacher.id, notifMsg]
      );
    }

    res.json({
      success: true,
      message: hasChanges ? 'Changes submitted for teacher review' : 'Details confirmed, no changes',
      has_changes: hasChanges,
      diff
    });
  } catch (err) { next(err); }
});

// ── GET /parent/reviews — Teacher: pending reviews ────────────
router.get('/reviews', authenticate, async (req, res, next) => {
  try {
    const { status, class_name, section, branch_id } = req.query;
    let where = ['1=1'];
    let params = [];

    if (req.employee) {
      where.push('e.id = ?'); params.push(req.employee.id);
    }
    if (status)      { where.push('pr.status = ?');         params.push(status); }
    if (class_name)  { where.push('s.class_name = ?');      params.push(class_name); }
    if (section)     { where.push('s.section = ?');         params.push(section); }
    if (branch_id)   { where.push('s.branch_id = ?');       params.push(branch_id); }

    const reviews = await query(
      `SELECT pr.*, s.first_name, s.last_name, s.student_id, s.class_name, s.section,
              s.status_color, s.photo_url
       FROM parent_reviews pr
       JOIN students s ON s.id = pr.student_id
       JOIN employees e ON e.id = pr.link_sent_by
       WHERE ${where.join(' AND ')}
       ORDER BY pr.submitted_at DESC`, params
    );

    res.json({ success: true, data: reviews });
  } catch (err) { next(err); }
});

// ── POST /parent/reviews/:id/approve ─────────────────────────
router.post('/reviews/:id/approve', authenticate, async (req, res, next) => {
  try {
    const { action, notes } = req.body; // action: 'approve' | 'reject'

    const [review] = await query(
      `SELECT pr.*, s.school_id FROM parent_reviews pr
       JOIN students s ON s.id = pr.student_id
       WHERE pr.id = ? AND pr.status = 'parent_submitted'`, [req.params.id]
    );
    if (!review) return res.status(404).json({ success: false, message: 'Review not found or not pending' });

    if (action === 'approve' && review.submitted_data) {
      const submitted = JSON.parse(review.submitted_data);
      const allowedFields = ['first_name','last_name','address_line1','address_line2',
                             'city','state','zip_code','bus_route','bus_stop','photo_url'];

      const updateFields = Object.keys(submitted.student)
        .filter(k => allowedFields.includes(k));

      if (updateFields.length) {
        await query(
          `UPDATE students SET ${updateFields.map(f => `${f}=?`).join(',')} WHERE id=?`,
          [...updateFields.map(f => submitted.student[f]), review.student_id]
        );
      }

      // Update guardians
      if (submitted.guardians?.length) {
        for (const g of submitted.guardians) {
          await query(
            `UPDATE guardians SET first_name=?, last_name=?, phone=?, whatsapp_no=?,
               email=?, occupation=? WHERE student_id=? AND guardian_type=?`,
            [g.first_name, g.last_name, g.phone, g.whatsapp_no,
             g.email, g.occupation, review.student_id, g.guardian_type]
          );
        }
      }

      await query(
        `UPDATE students SET status_color='green', review_status='approved' WHERE id=?`,
        [review.student_id]
      );
    }

    await query(
      `UPDATE parent_reviews SET status=?, reviewed_by=?, reviewed_at=NOW(), review_notes=?
       WHERE id=?`,
      [action === 'approve' ? 'approved' : 'rejected', req.employee?.id, notes, req.params.id]
    );

    res.json({ success: true, message: `Review ${action}d successfully` });
  } catch (err) { next(err); }
});

module.exports = router;
