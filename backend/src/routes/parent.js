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
       JOIN employees e ON e.id = pr.link_sent_by
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
    const original = JSON.parse(review.original_data);
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
      await notifyEmployee? notifyEmployee : (() => {});  // no-op safety

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

    let students = await query(
      `SELECT s.*, sch.name AS school_name, b.name AS branch_name,
              g.guardian_type, g.first_name AS guardian_first_name, g.last_name AS guardian_last_name
       FROM students s
       JOIN guardians g ON g.student_id = s.id
       JOIN schools sch ON sch.id = s.school_id
       JOIN branches b ON b.id = s.branch_id
       WHERE g.user_id = ?`,
      [userId]
    );
    if (!students.length && phone) {
      const last10 = phone.replace(/\D/g, '').slice(-10);
      students = await query(
        `SELECT s.*, sch.name AS school_name, b.name AS branch_name,
                g.guardian_type, g.first_name AS guardian_first_name, g.last_name AS guardian_last_name
         FROM students s
         JOIN guardians g ON g.student_id = s.id
         JOIN schools sch ON sch.id = s.school_id
         JOIN branches b ON b.id = s.branch_id
         WHERE g.phone LIKE ? OR g.phone LIKE ?`,
        [`%${last10}`, last10]
      );
    }
    res.json({ success: true, data: students });
  } catch (err) { next(err); }
});

module.exports = router;
