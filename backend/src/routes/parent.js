// ============================================================
// Parent Review Portal Routes  (v2 — with document uploads,
// mandatory-doc flag, return-to-parent cycle & notifications)
// ============================================================
const router  = require('express').Router();
const { v4: uuid }   = require('uuid');
const crypto  = require('crypto');
const { query } = require('../models/db');
const { authenticate } = require('../middleware/auth');
const logger  = require('../utils/logger');
const multer  = require('multer');
const path    = require('path');
const sharp   = require('sharp');
const fs      = require('fs');

const UPLOAD_DIR = path.join(__dirname, '../../uploads');
fs.mkdirSync(path.join(UPLOAD_DIR, 'photos'), { recursive: true });
const _multerTemp = multer({ dest: path.join(UPLOAD_DIR, 'temp'), limits: { fileSize: 5 * 1024 * 1024 } });

// Shared notification helper (SMS + WhatsApp + Email)
const notifModule = require('./notifications');
const sendNotification = notifModule.sendNotification;

// ─────────────────────────────────────────────────────────────
//  Helpers
// ─────────────────────────────────────────────────────────────
const notifyGuardians = async (guardians, schoolId, subject, message) => {
  for (const g of guardians) {
    if (!g.phone && !g.whatsapp_no && !g.email) continue;
    await sendNotification({
      phone:    g.phone,
      whatsapp: g.whatsapp_no,
      email:    g.email,
      subject,
      message,
      school_id:      schoolId,
      recipient_id:   g.id,
      recipient_type: 'guardian',
    }).catch(err => logger.warn(`[PARENT] Guardian notify failed: ${err.message}`));
  }
};

const notifyEmployee = async (emp, schoolId, subject, message) => {
  if (!emp) return;
  await sendNotification({
    phone:    emp.phone,
    whatsapp: emp.whatsapp_no || emp.phone,
    email:    emp.email,
    subject,
    message,
    school_id:      schoolId,
    recipient_id:   emp.id,
    recipient_type: 'employee',
  }).catch(err => logger.warn(`[PARENT] Employee notify failed: ${err.message}`));
};

// ─────────────────────────────────────────────────────────────
//  POST /parent/send-link
//  Teacher sends a review link to the parent(s) of one or more
//  students.  Now supports: document_required, document_instructions
// ─────────────────────────────────────────────────────────────
router.post('/send-link', authenticate, async (req, res, next) => {
  try {
    const {
      student_ids,
      message,
      expires_hours = 72,
      document_required = false,
      document_instructions = null,
    } = req.body;
    if (!student_ids?.length) return res.status(400).json({ success: false, message: 'No students specified' });

    const employeeId = req.employee?.id;
    if (!employeeId) return res.status(403).json({ success: false, message: 'Not an employee' });

    const results = [];

    for (const sid of student_ids) {
      const [student] = await query(
        `SELECT s.*, b.name AS branch_name, sch.name AS school_name, sch.id AS school_id
         FROM students s
         JOIN branches b ON b.id = s.branch_id
         JOIN schools sch ON sch.id = s.school_id
         WHERE s.id = ?`, [sid]
      );
      if (!student) { results.push({ id: sid, error: 'Not found' }); continue; }

      const guardians = await query('SELECT * FROM guardians WHERE student_id = ?', [sid]);

      const token     = crypto.randomBytes(32).toString('hex');
      const expiresAt = new Date(Date.now() + expires_hours * 60 * 60 * 1000);
      const snapshot  = { student: { ...student }, guardians };
      const reviewId  = uuid();

      await query(
        `INSERT INTO parent_reviews
           (id, student_id, review_token, link_sent_by, link_sent_at, link_expires_at,
            original_data, status, document_required, document_instructions)
         VALUES (?,?,?,?,NOW(),?,?,'link_sent',?,?)
         ON DUPLICATE KEY UPDATE
           review_token=VALUES(review_token), link_sent_at=NOW(),
           link_expires_at=VALUES(link_expires_at), original_data=VALUES(original_data),
           status='link_sent', document_required=VALUES(document_required),
           document_instructions=VALUES(document_instructions)`,
        [reviewId, sid, token, employeeId, expiresAt,
         JSON.stringify(snapshot), document_required ? 1 : 0, document_instructions]
      );

      const reviewUrl = `${process.env.APP_BASE_URL || 'https://80.225.246.32'}/idmgmt/parent-review?token=${token}`;
      const expiresStr = expiresAt.toLocaleDateString('en-IN', { day: '2-digit', month: 'short', year: 'numeric' });

      let notifText = message
        || `Dear Parent, please review and update ${student.first_name}'s details for ${student.school_name}.\nLink: ${reviewUrl}\nExpires: ${expiresStr}`;

      if (document_required) {
        notifText += `\n\n📎 Document upload required.`;
        if (document_instructions) notifText += ` Please upload: ${document_instructions}`;
      }

      await notifyGuardians(
        guardians.filter(g => g.phone || g.whatsapp_no || g.email),
        student.school_id,
        `Action Required: Review details for ${student.first_name}`,
        notifText,
      );

      // Mark student pending
      await query(
        `UPDATE students SET status_color='red', review_status='pending' WHERE id=?`, [sid]
      );

      results.push({ id: sid, review_id: reviewId, token, review_url: reviewUrl });
    }

    res.json({ success: true, data: results });
  } catch (err) { next(err); }
});

// ─────────────────────────────────────────────────────────────
//  GET /parent/review — fetch review data by token (public)
// ─────────────────────────────────────────────────────────────
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
    if (['approved','rejected'].includes(review.status)) {
      return res.status(409).json({ success: false, message: 'This review has already been processed' });
    }

    const guardians = await query('SELECT * FROM guardians WHERE student_id = ?', [review.student_id]);
    const documents = await query('SELECT * FROM review_documents WHERE review_id = ? ORDER BY uploaded_at DESC', [review.id]);

    res.json({
      success: true,
      data: {
        review_id:             review.id,
        status:                review.status,
        student:               JSON.parse(review.original_data).student,
        guardians:             JSON.parse(review.original_data).guardians,
        school_name:           review.school_name,
        branch_name:           review.branch_name,
        expires_at:            review.link_expires_at,
        document_required:     !!review.document_required,
        document_instructions: review.document_instructions,
        return_reason:         review.return_reason,
        documents,
      }
    });
  } catch (err) { next(err); }
});

// ─────────────────────────────────────────────────────────────
//  POST /parent/review — parent submits changes + documents
// ─────────────────────────────────────────────────────────────
router.post('/review', async (req, res, next) => {
  try {
    const { token, student_data, guardians_data, documents = [] } = req.body;
    if (!token) return res.status(400).json({ success: false, message: 'Token required' });

    const [review] = await query(
      `SELECT pr.*, e.phone AS teacher_phone, e.email AS teacher_email,
              e.whatsapp_no AS teacher_wa, e.id AS teacher_emp_id,
              s.first_name AS student_first, s.school_id
       FROM parent_reviews pr
       LEFT JOIN employees e ON e.id = pr.link_sent_by
       JOIN students s ON s.id = pr.student_id
       WHERE pr.review_token = ? AND pr.status IN ('link_sent','returned')`,
      [token]
    );
    if (!review) return res.status(404).json({ success: false, message: 'Invalid link or already submitted' });
    if (new Date(review.link_expires_at) < new Date()) {
      return res.status(410).json({ success: false, message: 'Link expired' });
    }

    // Enforce mandatory doc requirement
    if (review.document_required) {
      const existingDocs = await query('SELECT id FROM review_documents WHERE review_id = ?', [review.id]);
      const totalDocs = existingDocs.length + (documents?.length || 0);
      if (totalDocs === 0) {
        return res.status(422).json({
          success: false,
          message: 'Document upload is required before submitting',
        });
      }
    }

    // Persist uploaded document references
    for (const doc of documents) {
      if (!doc.file_url || !doc.file_name) continue;
      const ext = doc.file_name.split('.').pop()?.toLowerCase();
      const fileType = ['pdf'].includes(ext) ? 'pdf'
        : ['doc','docx'].includes(ext) ? 'docx'
        : ['jpg','jpeg','png','gif','webp','heic'].includes(ext) ? 'image'
        : 'other';
      await query(
        `INSERT INTO review_documents (id, review_id, uploader_id, file_name, file_type, file_url, file_size_kb, description)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
        [uuid(), review.id, doc.uploader_id || 'unknown', doc.file_name, fileType, doc.file_url,
         doc.file_size_kb || null, doc.description || null]
      );
    }

    // Compute diff
    const original = typeof review.original_data === 'string'
      ? JSON.parse(review.original_data)
      : review.original_data;
    const diff = {};
    const allowedFields = ['first_name','last_name','date_of_birth','address_line1',
                           'address_line2','city','state','zip_code','bus_route','bus_stop','photo_url'];
    for (const f of allowedFields) {
      if (student_data[f] !== undefined && student_data[f] !== original.student[f]) {
        diff[f] = { old: original.student[f], new: student_data[f] };
      }
    }
    const hasChanges = Object.keys(diff).length > 0;

    await query(
      `UPDATE parent_reviews SET
         submitted_at=NOW(), submitted_data=?, changes_summary=?,
         status='parent_submitted', return_reason=NULL
       WHERE review_token=?`,
      [JSON.stringify({ student: student_data, guardians: guardians_data }), JSON.stringify(diff), token]
    );

    await query(
      `UPDATE students SET status_color=?, review_status='parent_reviewed' WHERE id=?`,
      [hasChanges ? 'blue' : 'green', review.student_id]
    );

    // Notify teacher
    const docsCount = documents.length;
    const teacherMsg = `Parent has ${hasChanges ? 'submitted changes' : 'confirmed details'} for ${review.student_first}.`
      + (docsCount > 0 ? ` ${docsCount} document(s) uploaded.` : '');
    await notifyEmployee(
      { id: review.teacher_emp_id, phone: review.teacher_phone,
        email: review.teacher_email, whatsapp_no: review.teacher_wa },
      review.school_id,
      `Parent Submission: ${review.student_first}`,
      teacherMsg,
    );

    res.json({
      success: true,
      message: hasChanges ? 'Changes submitted for teacher review' : 'Details confirmed, no changes',
      has_changes: hasChanges,
      diff,
    });
  } catch (err) { next(err); }
});

// ─────────────────────────────────────────────────────────────
//  POST /parent/documents — upload document reference
//  (Called after Firebase upload by client; saves URL to DB)
// ─────────────────────────────────────────────────────────────
router.post('/documents', authenticate, async (req, res, next) => {
  try {
    const { review_id, file_name, file_url, file_size_kb, description } = req.body;
    if (!review_id || !file_url || !file_name)
      return res.status(400).json({ success: false, message: 'review_id, file_name and file_url required' });

    const ext = file_name.split('.').pop()?.toLowerCase();
    const fileType = ['pdf'].includes(ext) ? 'pdf'
      : ['doc','docx'].includes(ext) ? 'docx'
      : ['jpg','jpeg','png','gif','webp','heic'].includes(ext) ? 'image'
      : 'other';

    const id = uuid();
    await query(
      `INSERT INTO review_documents (id, review_id, uploader_id, file_name, file_type, file_url, file_size_kb, description)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
      [id, review_id, req.user.id, file_name, fileType, file_url, file_size_kb || null, description || null]
    );

    const [doc] = await query('SELECT * FROM review_documents WHERE id = ?', [id]);
    res.status(201).json({ success: true, data: doc });
  } catch (err) { next(err); }
});

// ─────────────────────────────────────────────────────────────
//  GET /parent/documents/:review_id — list uploaded documents
// ─────────────────────────────────────────────────────────────
router.get('/documents/:review_id', authenticate, async (req, res, next) => {
  try {
    const docs = await query(
      'SELECT * FROM review_documents WHERE review_id = ? ORDER BY uploaded_at DESC',
      [req.params.review_id]
    );
    res.json({ success: true, data: docs });
  } catch (err) { next(err); }
});

// ─────────────────────────────────────────────────────────────
//  GET /parent/reviews — Teacher: list review requests
// ─────────────────────────────────────────────────────────────
router.get('/reviews', authenticate, async (req, res, next) => {
  try {
    const { status, class_name, section, branch_id } = req.query;
    let where = ['1=1'];
    let params = [];

    if (req.employee) {
      where.push('pr.link_sent_by = ?'); params.push(req.employee.id);
    }
    if (status)      { where.push('pr.status = ?');         params.push(status); }
    if (class_name)  { where.push('s.class_name = ?');      params.push(class_name); }
    if (section)     { where.push('s.section = ?');         params.push(section); }
    if (branch_id)   { where.push('s.branch_id = ?');       params.push(branch_id); }

    const reviews = await query(
      `SELECT pr.*,
              s.first_name, s.last_name, s.student_id AS student_roll,
              s.class_name, s.section, s.status_color, s.photo_url,
              (SELECT COUNT(*) FROM review_documents rd WHERE rd.review_id = pr.id) AS doc_count
       FROM parent_reviews pr
       JOIN students s ON s.id = pr.student_id
       WHERE ${where.join(' AND ')}
       ORDER BY pr.updated_at DESC`, params
    );
    res.json({ success: true, data: reviews });
  } catch (err) { next(err); }
});

// ─────────────────────────────────────────────────────────────
//  POST /parent/reviews/:id/approve   (approve | reject | return)
// ─────────────────────────────────────────────────────────────
router.post('/reviews/:id/approve', authenticate, async (req, res, next) => {
  try {
    const { action, notes, return_reason } = req.body;
    if (!['approve','reject','return'].includes(action)) {
      return res.status(400).json({ success: false, message: 'action must be approve | reject | return' });
    }

    const [review] = await query(
      `SELECT pr.*, s.school_id, s.first_name AS student_first,
              g.phone AS guardian_phone, g.whatsapp_no AS guardian_wa, g.email AS guardian_email, g.id AS guardian_id
       FROM parent_reviews pr
       JOIN students s ON s.id = pr.student_id
       LEFT JOIN guardians g ON g.student_id = s.id AND g.is_primary = 1
       WHERE pr.id = ? AND pr.status = 'parent_submitted'`, [req.params.id]
    );
    if (!review) return res.status(404).json({ success: false, message: 'Review not found or not in submitted state' });

    // ── RETURN TO PARENT ──────────────────────────────────────
    if (action === 'return') {
      if (!return_reason?.trim())
        return res.status(400).json({ success: false, message: 'return_reason is required' });

      await query(
        `UPDATE parent_reviews SET status='returned', return_reason=?, reviewed_by=?, reviewed_at=NOW(), review_notes=?
         WHERE id=?`,
        [return_reason, req.employee?.id, notes || null, req.params.id]
      );
      await query(
        `UPDATE students SET status_color='red', review_status='pending' WHERE id=?`,
        [review.student_id]
      );

      const parentMsg = `Your submission for ${review.student_first} has been returned by the teacher for revision.\n\nReason: ${return_reason}\n\nPlease re-submit after making the necessary corrections.`;
      // (teacher notification on return is handled below via guardian notify)

      // Primary guardian notification
      if (review.guardian_phone || review.guardian_email) {
        await sendNotification({
          phone:    review.guardian_phone,
          whatsapp: review.guardian_wa || review.guardian_phone,
          email:    review.guardian_email,
          subject:  `Revision Requested: ${review.student_first}'s details`,
          message:  parentMsg,
          school_id:      review.school_id,
          recipient_id:   review.guardian_id,
          recipient_type: 'guardian',
        });
      }

      return res.json({ success: true, message: 'Returned to parent for revision' });
    }

    // ── APPROVE ───────────────────────────────────────────────
    if (action === 'approve' && review.submitted_data) {
      const submitted = JSON.parse(review.submitted_data);
      const allowedFields = ['first_name','last_name','address_line1','address_line2',
                             'city','state','zip_code','bus_route','bus_stop','photo_url'];
      const updateFields = Object.keys(submitted.student || {}).filter(k => allowedFields.includes(k));

      if (updateFields.length) {
        await query(
          `UPDATE students SET ${updateFields.map(f => `${f}=?`).join(',')} WHERE id=?`,
          [...updateFields.map(f => submitted.student[f]), review.student_id]
        );
      }
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
    } else if (action === 'reject') {
      await query(
        `UPDATE students SET status_color='red', review_status='pending' WHERE id=?`,
        [review.student_id]
      );
    }

    await query(
      `UPDATE parent_reviews SET status=?, reviewed_by=?, reviewed_at=NOW(), review_notes=?
       WHERE id=?`,
      [action === 'approve' ? 'approved' : 'rejected', req.employee?.id, notes || null, req.params.id]
    );

    // Notify primary guardian
    const actionLabel = action === 'approve' ? 'approved ✅' : 'rejected ❌';
    const parentMsg   = `The review for ${review.student_first}'s details has been ${actionLabel}.`
      + (notes ? `\n\nTeacher's notes: ${notes}` : '');
    if (review.guardian_phone || review.guardian_email) {
      await sendNotification({
        phone:    review.guardian_phone,
        whatsapp: review.guardian_wa || review.guardian_phone,
        email:    review.guardian_email,
        subject:  `Review ${action === 'approve' ? 'Approved' : 'Rejected'}: ${review.student_first}`,
        message:  parentMsg,
        school_id:      review.school_id,
        recipient_id:   review.guardian_id,
        recipient_type: 'guardian',
      });
    }

    res.json({ success: true, message: `Review ${action}d successfully` });
  } catch (err) { next(err); }
});

// ─────────────────────────────────────────────────────────────
//  GET /parent/students — Parent: list their children
// ─────────────────────────────────────────────────────────────
router.get('/students', authenticate, async (req, res, next) => {
  try {
    if (req.user.role !== 'parent' && req.user.role !== 'super_admin') {
      return res.status(403).json({ success: false, message: 'Access denied' });
    }
    const userId = req.user.id;
    const phone  = req.user.phone;

    let studentIds = [];
    const byUserId = await query(
      `SELECT DISTINCT student_id FROM guardians WHERE user_id = ?`, [userId]
    );
    if (byUserId.length) {
      studentIds = byUserId.map(r => r.student_id);
    } else if (phone) {
      const last10 = phone.replace(/\D/g, '').slice(-10);
      const byPhone = await query(
        `SELECT DISTINCT student_id FROM guardians WHERE phone LIKE ? OR phone LIKE ?`,
        [`%${last10}`, last10]
      );
      studentIds = byPhone.map(r => r.student_id);
    }

    if (!studentIds.length) return res.json({ success: true, data: [] });

    const ph = studentIds.map(() => '?').join(',');
    const students = await query(
      `SELECT s.id, s.first_name, s.last_name, s.class_name, s.section,
              s.photo_url, s.student_id, s.admission_no, s.status_color,
              sch.name AS school_name, b.name AS branch_name,
              TRIM(CONCAT(IFNULL(ct.first_name,''), ' ', IFNULL(ct.last_name,''))) AS class_teacher_name,
              (SELECT COUNT(*) FROM students s2
               WHERE s2.class_name = s.class_name AND s2.section = s.section
                 AND s2.branch_id = s.branch_id AND s2.is_active = TRUE AND s2.is_current = TRUE) AS total_in_class
       FROM students s
       JOIN schools sch ON sch.id = s.school_id
       JOIN branches b ON b.id = s.branch_id
       LEFT JOIN class_sections cs ON cs.class_name = s.class_name AND cs.section = s.section
                                  AND cs.branch_id = s.branch_id AND cs.is_active = TRUE
       LEFT JOIN employees ct ON ct.id = cs.class_teacher_id AND ct.is_active = TRUE
       WHERE s.id IN (${ph})
       ORDER BY s.class_name, s.first_name`,
      studentIds
    );

    for (const student of students) {
      const guardians = await query(
        `SELECT guardian_type, first_name, last_name, phone
         FROM guardians WHERE student_id = ? ORDER BY guardian_type`,
        [student.id]
      );
      student.guardians = guardians
        .map(g => ({
          type: g.guardian_type,
          name: `${g.first_name || ''} ${g.last_name || ''}`.trim(),
          phone: g.phone || '',
        }))
        .filter(g => g.name || g.phone);

      // Determine which guardian type this user is
      const [myG] = await query(
        `SELECT guardian_type FROM guardians WHERE student_id = ? AND user_id = ? LIMIT 1`,
        [student.id, userId]
      ).catch(() => [null]);
      student.guardian_type = myG?.guardian_type || null;

      student.class_teacher_name = (student.class_teacher_name || '').trim() || null;
    }

    res.json({ success: true, data: students });
  } catch (err) { next(err); }
});

// ─────────────────────────────────────────────────────────────
//  GET /parent/my-reviews — Parent: pending/active reviews
// ─────────────────────────────────────────────────────────────
router.get('/my-reviews', authenticate, async (req, res, next) => {
  try {
    if (req.user.role !== 'parent' && req.user.role !== 'super_admin') {
      return res.status(403).json({ success: false, message: 'Access denied' });
    }
    const userId  = req.user.id;
    const phone   = req.user.phone;
    // ?history=true returns completed (approved/rejected) reviews; default is active only
    const history = req.query.history === 'true';

    let studentIds = [];
    const byUserId = await query(
      `SELECT DISTINCT student_id FROM guardians WHERE user_id = ?`, [userId]
    );
    if (byUserId.length) {
      studentIds = byUserId.map(r => r.student_id);
    } else if (phone) {
      const last10 = phone.replace(/\D/g, '').slice(-10);
      const byPhone = await query(
        `SELECT DISTINCT student_id FROM guardians WHERE phone LIKE ? OR phone LIKE ?`,
        [`%${last10}`, last10]
      );
      studentIds = byPhone.map(r => r.student_id);
    }

    if (!studentIds.length) return res.json({ success: true, data: [], history });

    const placeholders = studentIds.map(() => '?').join(',');
    const statusFilter = history
      ? `pr.status IN ('approved','rejected')`
      : `pr.status NOT IN ('approved','rejected')`;

    const reviews = await query(
      `SELECT pr.id, pr.status, pr.review_token,
              pr.link_sent_at, pr.link_expires_at,
              pr.submitted_at, pr.reviewed_at, pr.return_reason, pr.review_notes,
              pr.document_required, pr.document_instructions,
              pr.changes_summary,
              s.id AS student_id, s.first_name, s.last_name, s.student_id AS student_roll,
              s.class_name, s.section, s.photo_url, s.school_id,
              sch.name AS school_name,
              CASE
                WHEN tch.first_name IS NOT NULL
                  THEN TRIM(CONCAT(tch.first_name,' ',IFNULL(tch.last_name,'')))
                ELSE TRIM(CONCAT(e.first_name,' ',IFNULL(e.last_name,'')))
              END AS teacher_name,
              (SELECT COUNT(*) FROM review_documents rd WHERE rd.review_id = pr.id) AS doc_count,
              (SELECT COUNT(*) FROM parent_review_messages pm WHERE pm.review_id = pr.id AND pm.sender_type != 'parent') AS unread_count
       FROM parent_reviews pr
       JOIN students s ON s.id = pr.student_id
       JOIN schools sch ON sch.id = s.school_id
       LEFT JOIN employees e ON e.id = pr.link_sent_by
       LEFT JOIN workflow_request_items wri ON wri.parent_review_id = pr.id
       LEFT JOIN employees tch ON tch.id = wri.assigned_teacher_id AND tch.is_active = TRUE
       WHERE pr.student_id IN (${placeholders})
         AND ${statusFilter}
       ORDER BY pr.link_sent_at DESC`,
      studentIds
    );

    const parsed = reviews.map(r => ({
      ...r,
      changes_summary: r.changes_summary
        ? (typeof r.changes_summary === 'string' ? JSON.parse(r.changes_summary) : r.changes_summary)
        : null,
    }));
    res.json({ success: true, data: parsed, history });
  } catch (err) { next(err); }
});

// ─────────────────────────────────────────────────────────────
//  GET /parent/attendance-summary — Per-child attendance %
// ─────────────────────────────────────────────────────────────
router.get('/attendance-summary', authenticate, async (req, res, next) => {
  try {
    if (req.user.role !== 'parent' && req.user.role !== 'super_admin') {
      return res.status(403).json({ success: false, message: 'Access denied' });
    }
    const userId = req.user.id;
    const phone  = req.user.phone;

    let studentIds = [];
    const byUserId = await query(`SELECT DISTINCT student_id FROM guardians WHERE user_id = ?`, [userId]);
    if (byUserId.length) {
      studentIds = byUserId.map(r => r.student_id);
    } else if (phone) {
      const last10 = phone.replace(/\D/g, '').slice(-10);
      const byPhone = await query(
        `SELECT DISTINCT student_id FROM guardians WHERE phone LIKE ? OR phone LIKE ?`,
        [`%${last10}`, last10]
      );
      studentIds = byPhone.map(r => r.student_id);
    }

    if (!studentIds.length) return res.json({ success: true, data: {} });

    const result = {};
    for (const sid of studentIds) {
      const rows = await query(
        `SELECT am.id AS module_id, am.type, am.name,
                COUNT(*) AS total_days,
                SUM(CASE WHEN ar.status='present' THEN 1 ELSE 0 END) AS present_days
         FROM attendance_records ar
         JOIN attendance_modules am ON am.id = ar.module_id
         WHERE ar.student_id = ?
           AND ar.date >= DATE_SUB(CURDATE(), INTERVAL 30 DAY)
           AND am.visible_to_parents = TRUE
         GROUP BY am.id, am.type, am.name`,
        [sid]
      );

      const summary = { by_module: [] };
      let totalAll = 0, presentAll = 0;
      for (const r of rows) {
        const pct = r.total_days > 0 ? Math.round((r.present_days / r.total_days) * 100) : null;
        summary.by_module.push({
          module_id:    r.module_id,
          name:         r.name,
          type:         r.type,
          total_days:   r.total_days,
          present_days: r.present_days,
          percentage:   pct,
        });
        totalAll   += r.total_days;
        presentAll += r.present_days;
      }
      summary.overall_percentage = totalAll > 0 ? Math.round((presentAll / totalAll) * 100) : null;
      result[sid] = summary;
    }

    res.json({ success: true, data: result });
  } catch (err) { next(err); }
});

// ─────────────────────────────────────────────────────────────
//  GET /parent/reviews/:id/messages — Parent-teacher messages
// ─────────────────────────────────────────────────────────────
router.get('/reviews/:id/messages', authenticate, async (req, res, next) => {
  try {
    const messages = await query(
      `SELECT * FROM parent_review_messages WHERE review_id = ? ORDER BY created_at ASC`,
      [req.params.id]
    );
    res.json({ success: true, data: messages });
  } catch (err) { next(err); }
});

// ─────────────────────────────────────────────────────────────
//  POST /parent/reviews/:id/messages — Send message
// ─────────────────────────────────────────────────────────────
router.post('/reviews/:id/messages', authenticate, async (req, res, next) => {
  try {
    const { message } = req.body;
    if (!message?.trim()) return res.status(400).json({ success: false, message: 'Message required' });

    const reviewId = req.params.id;
    const [review] = await query(
      `SELECT pr.*, s.first_name AS student_first, s.school_id,
              e.phone AS teacher_phone, e.email AS teacher_email
       FROM parent_reviews pr
       JOIN students s ON s.id = pr.student_id
       LEFT JOIN employees e ON e.id = pr.link_sent_by
       WHERE pr.id = ?`, [reviewId]
    );
    if (!review) return res.status(404).json({ success: false, message: 'Review not found' });

    let senderType, senderId, senderName;
    if (req.user.role === 'parent') {
      senderType = 'parent';
      senderId   = req.user.id;
      senderName = req.user.full_name || req.user.phone || 'Parent';
    } else if (req.employee) {
      senderType = 'teacher';
      senderId   = req.employee.id;
      senderName = `${req.employee.first_name || ''} ${req.employee.last_name || ''}`.trim() || 'Teacher';
    } else {
      senderType = 'admin';
      senderId   = req.user.id;
      senderName = req.user.full_name || 'Admin';
    }

    const msgId = uuid();
    await query(
      `INSERT INTO parent_review_messages (id, review_id, sender_type, sender_id, sender_name, message)
       VALUES (?, ?, ?, ?, ?, ?)`,
      [msgId, reviewId, senderType, senderId, senderName, message.trim()]
    );

    const [saved] = await query(`SELECT * FROM parent_review_messages WHERE id = ?`, [msgId]);

    if (senderType === 'parent' && review.teacher_phone) {
      await sendNotification({
        phone:    review.teacher_phone,
        email:    review.teacher_email,
        subject:  `Message from parent re: ${review.student_first}`,
        message:  `${senderName}: ${message.trim()}`,
        school_id:      review.school_id,
        recipient_id:   review.link_sent_by,
        recipient_type: 'employee',
      }).catch(() => {});
    }

    res.status(201).json({ success: true, data: saved });
  } catch (err) { next(err); }
});

// ─────────────────────────────────────────────────────────────
//  GET /parent/fee-reminders — Active fee workflow requests
// ─────────────────────────────────────────────────────────────
router.get('/fee-reminders', authenticate, async (req, res, next) => {
  try {
    if (req.user.role !== 'parent' && req.user.role !== 'super_admin') {
      return res.status(403).json({ success: false, message: 'Access denied' });
    }
    const userId = req.user.id;
    const phone  = req.user.phone;

    let studentIds = [];
    const byUserId = await query(`SELECT DISTINCT student_id FROM guardians WHERE user_id = ?`, [userId]);
    if (byUserId.length) {
      studentIds = byUserId.map(r => r.student_id);
    } else if (phone) {
      const last10 = phone.replace(/\D/g, '').slice(-10);
      const byPhone = await query(
        `SELECT DISTINCT student_id FROM guardians WHERE phone LIKE ? OR phone LIKE ?`,
        [`%${last10}`, last10]
      );
      studentIds = byPhone.map(r => r.student_id);
    }

    if (!studentIds.length) return res.json({ success: true, data: [] });

    const placeholders = studentIds.map(() => '?').join(',');
    const reminders = await query(
      `SELECT wri.id, wri.status, wr.due_date AS deadline, wri.teacher_notes AS notes,
              wr.title, wr.description, wr.created_at AS request_created_at,
              s.first_name, s.last_name, s.class_name, s.section,
              sch.name AS school_name
       FROM workflow_request_items wri
       JOIN workflow_requests wr ON wr.id = wri.request_id
       JOIN students s ON s.id = wri.student_id
       JOIN schools sch ON sch.id = s.school_id
       WHERE wri.student_id IN (${placeholders})
         AND LOWER(wr.title) LIKE '%fee%'
         AND wri.status NOT IN ('approved','rejected')
       ORDER BY wr.due_date ASC`,
      studentIds
    );
    res.json({ success: true, data: reminders });
  } catch (err) { next(err); }
});

// ─────────────────────────────────────────────────────────────
//  POST /parent/review/photo — public photo upload (token-gated)
//  Parent uploads student photo during review; token validates access
// ─────────────────────────────────────────────────────────────
router.post('/review/photo', _multerTemp.single('photo'), async (req, res, next) => {
  try {
    const { token } = req.body;
    if (!token) return res.status(400).json({ success: false, message: 'Token required' });

    const [review] = await query(
      `SELECT pr.id, pr.student_id FROM parent_reviews pr
       WHERE pr.review_token = ? AND pr.status IN ('link_sent','returned')
         AND pr.link_expires_at > NOW()`, [token]
    );
    if (!review) return res.status(403).json({ success: false, message: 'Invalid or expired token' });
    if (!req.file)  return res.status(400).json({ success: false, message: 'No file uploaded' });

    const filename = `student_${review.student_id}_${uuid()}.webp`;
    const outPath  = path.join(UPLOAD_DIR, 'photos', filename);
    await sharp(req.file.path).resize(400, 400, { fit: 'cover' }).webp({ quality: 85 }).toFile(outPath);
    fs.unlinkSync(req.file.path);

    const url = `/idmgmt/api/static/photos/${filename}`;
    res.json({ success: true, data: { url } });
  } catch (err) {
    if (req.file) fs.unlink(req.file.path, () => {});
    next(err);
  }
});

// ─────────────────────────────────────────────────────────────
//  GET /parent/workflow-requests — Active/historical workflow items
// ─────────────────────────────────────────────────────────────
router.get('/workflow-requests', authenticate, async (req, res, next) => {
  try {
    if (req.user.role !== 'parent' && req.user.role !== 'super_admin') {
      return res.status(403).json({ success: false, message: 'Access denied' });
    }
    const userId = req.user.id;
    const phone  = req.user.phone;
    const history = req.query.history === 'true';

    let studentIds = [];
    const byUserId = await query(`SELECT DISTINCT student_id FROM guardians WHERE user_id = ?`, [userId]);
    if (byUserId.length) {
      studentIds = byUserId.map(r => r.student_id);
    } else if (phone) {
      const last10 = phone.replace(/\D/g, '').slice(-10);
      const byPhone = await query(
        `SELECT DISTINCT student_id FROM guardians WHERE phone LIKE ? OR phone LIKE ?`,
        [`%${last10}`, last10]
      );
      studentIds = byPhone.map(r => r.student_id);
    }

    if (!studentIds.length) return res.json({ success: true, data: [] });

    const ph = studentIds.map(() => '?').join(',');
    const statusFilter = history
      ? `wri.status IN ('approved','rejected')`
      : `wri.status NOT IN ('approved','rejected')`;

    const requests = await query(
      `SELECT wri.id, wri.status, wri.student_id, wri.parent_review_id,
              wri.teacher_notes, wri.updated_at,
              wr.id AS request_id, wr.title, wr.description, wr.due_date,
              wr.created_at AS request_date,
              s.first_name, s.last_name, s.class_name, s.section,
              TRIM(CONCAT(IFNULL(e.first_name,''), ' ', IFNULL(e.last_name,''))) AS assigned_teacher
       FROM workflow_request_items wri
       JOIN workflow_requests wr ON wr.id = wri.request_id
       JOIN students s ON s.id = wri.student_id
       LEFT JOIN employees e ON e.id = wri.assigned_teacher_id AND e.is_active = TRUE
       WHERE wri.student_id IN (${ph})
         AND ${statusFilter}
       ORDER BY wr.created_at DESC`,
      studentIds
    );

    res.json({ success: true, data: requests });
  } catch (err) { next(err); }
});

module.exports = router;
