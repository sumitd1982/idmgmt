// ============================================================
// Workflow Requests Route — Industry-grade data review system
// Handles: Templates (standard + custom), Workflow Request
// instances, per-item status, comments, reminders.
// ============================================================
const router = require('express').Router();
const { v4: uuid } = require('uuid');
const { query, transaction } = require('../models/db');
const { authenticate } = require('../middleware/auth');
const logger = require('../utils/logger');

// Reuse shared notification helper
const notifModule = require('./notifications');
const sendNotification = notifModule.sendNotification;

// ─────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────
const FIELD_DEFS = {
  student_info: {
    'Identity': ['student_name','date_of_birth','gender','blood_group','nationality','religion','category'],
    'Enrollment': ['class_name','section','roll_number','academic_year','admission_no'],
    'Photos': ['photo_url'],
    'Contact & Address': ['address','city','state','zip_code'],
    'Government IDs': ['student_aadhaar','student_pan'],
    'Transport': ['bus_route','bus_stop','bus_number'],
    'Mother': ['mother_name','mother_phone','mother_email','mother_photo','mother_aadhaar','mother_pan'],
    'Father': ['father_name','father_phone','father_email','father_photo','father_aadhaar','father_pan'],
    'Guardian': ['guardian_name','guardian_phone','guardian_email','guardian_photo','guardian_aadhaar'],
  },
  teacher_info: {
    'Identity': ['teacher_name','employee_id','date_of_birth','gender'],
    'Role': ['designation','assigned_classes'],
    'Photos': ['photo_url'],
    'Contact': ['email','phone','whatsapp_no','address'],
    'Government IDs': ['aadhaar_no','pan_no'],
    'Professional': ['qualification','specialization','experience_years','date_of_joining'],
  },
  document: {
    'Person': ['name','date_of_birth','gender'],
    'IDs': ['aadhaar_no','pan_no'],
    'Photos': ['photo_url'],
    'Attachments': ['document_attachment'],
  },
};

// Send notification to multiple employees
const notifyEmployees = async (emps, schoolId, subject, message) => {
  for (const e of emps) {
    if (!e) continue;
    await sendNotification({
      phone: e.phone, whatsapp: e.whatsapp_no || e.phone, email: e.email,
      subject, message,
      school_id: schoolId, recipient_id: e.id, recipient_type: 'employee',
    }).catch(err => logger.warn(`[WORKFLOW] Employee notify failed: ${err.message}`));
  }
};

const notifyGuardians = async (guardians, schoolId, subject, message) => {
  for (const g of guardians) {
    if (!g || (!g.phone && !g.whatsapp_no && !g.email)) continue;
    await sendNotification({
      phone: g.phone, whatsapp: g.whatsapp_no, email: g.email,
      subject, message,
      school_id: schoolId, recipient_id: g.id, recipient_type: 'guardian',
    }).catch(err => logger.warn(`[WORKFLOW] Guardian notify failed: ${err.message}`));
  }
};

// Recompute and update request totals
const refreshRequestStats = async (requestId) => {
  const [stats] = await query(
    `SELECT
       COUNT(*) AS total,
       SUM(status IN ('pending','sent_to_parent','parent_submitted','teacher_under_review','resubmit_requested')) AS pending,
       SUM(status IN ('approved','rejected')) AS completed
     FROM workflow_request_items WHERE request_id = ?`, [requestId]
  );
  await query(
    `UPDATE workflow_requests SET
       total_items=?, pending_items=?, completed_items=?,
       status = CASE WHEN ? = 0 THEN 'active'
                     WHEN ? = ? THEN 'completed'
                     ELSE 'in_progress' END
     WHERE id=?`,
    [stats.total, stats.pending, stats.completed,
     stats.pending, stats.completed, stats.total,
     requestId]
  );
};

// ─────────────────────────────────────────────────────────────
// GET /workflow/field-defs
// Returns all available field definitions grouped by type
// ─────────────────────────────────────────────────────────────
router.get('/field-defs', authenticate, (req, res) => {
  res.json({ success: true, data: FIELD_DEFS });
});

// ─────────────────────────────────────────────────────────────
// GET /workflow/templates
// Returns standard templates + school-specific clones
// ─────────────────────────────────────────────────────────────
router.get('/templates', authenticate, async (req, res, next) => {
  try {
    const schoolId = req.query.school_id || req.employee?.school_id;
    const templates = await query(
      `SELECT t.*,
              pt.name AS parent_name
       FROM request_templates t
       LEFT JOIN request_templates pt ON pt.id = t.parent_id
       WHERE (t.school_id IS NULL OR t.school_id = ?) AND t.is_active = 1
       ORDER BY t.is_standard DESC, t.created_at ASC`,
      [schoolId]
    );
    res.json({ success: true, data: templates });
  } catch (err) { next(err); }
});

// ─────────────────────────────────────────────────────────────
// POST /workflow/templates
// Create a custom template (school-level clone or new)
// ─────────────────────────────────────────────────────────────
router.post('/templates', authenticate, async (req, res, next) => {
  try {
    const { school_id, name, template_type, description, default_fields, notify_channels, parent_id } = req.body;
    const sid = school_id || req.employee?.school_id;
    if (!sid) return res.status(400).json({ success: false, message: 'school_id required' });

    const id = uuid();
    await query(
      `INSERT INTO request_templates (id, school_id, name, template_type, description, default_fields, notify_channels, parent_id, created_by)
       VALUES (?,?,?,?,?,?,?,?,?)`,
      [id, sid, name, template_type || 'student_info', description || null,
       JSON.stringify(default_fields || []), JSON.stringify(notify_channels || ['sms','whatsapp','email']),
       parent_id || null, req.user?.id || null]
    );
    const [tmpl] = await query('SELECT * FROM request_templates WHERE id=?', [id]);
    res.status(201).json({ success: true, data: tmpl });
  } catch (err) { next(err); }
});

// ─────────────────────────────────────────────────────────────
// POST /workflow/templates/:id/clone
// Clone a template for school-level customization
// ─────────────────────────────────────────────────────────────
router.post('/templates/:id/clone', authenticate, async (req, res, next) => {
  try {
    const [src] = await query('SELECT * FROM request_templates WHERE id=?', [req.params.id]);
    if (!src) return res.status(404).json({ success: false, message: 'Template not found' });

    const schoolId = req.body.school_id || req.employee?.school_id;
    if (!schoolId) return res.status(400).json({ success: false, message: 'school_id required' });

    const id = uuid();
    const name = req.body.name || `${src.name} (Custom)`;
    await query(
      `INSERT INTO request_templates
         (id, school_id, name, template_type, description, default_fields, notify_channels, parent_id, is_standard, created_by)
       VALUES (?,?,?,?,?,?,?,?,FALSE,?)`,
      [id, schoolId, name, src.template_type,
       req.body.description || src.description,
       JSON.stringify(req.body.default_fields || (typeof src.default_fields === 'string' ? JSON.parse(src.default_fields || '[]') : (src.default_fields || []))),
       JSON.stringify(req.body.notify_channels || (typeof src.notify_channels === 'string' ? JSON.parse(src.notify_channels || '["sms","whatsapp","email"]') : (src.notify_channels || ['sms','whatsapp','email']))),
       src.id, req.user?.id || null]
    );
    const [tmpl] = await query('SELECT * FROM request_templates WHERE id=?', [id]);
    res.status(201).json({ success: true, data: tmpl });
  } catch (err) { next(err); }
});

// ─────────────────────────────────────────────────────────────
// GET /workflow/requests
// List workflow requests — role-based visibility
// ─────────────────────────────────────────────────────────────
router.get('/requests', authenticate, async (req, res, next) => {
  try {
    const { status, request_type, school_id } = req.query;
    const sid = school_id || req.employee?.school_id;
    const empId = req.employee?.id;
    const level = req.employee?.role_level || 99;

    let where = ['wr.school_id = ?'];
    let params = [sid];

    if (status)       { where.push('wr.status = ?');       params.push(status); }
    if (request_type) { where.push('wr.request_type = ?'); params.push(request_type); }

    // Visibility: level <= 3 → see all; else filter to own + assigned
    if (level > 3 && empId) {
      where.push(
        `(wr.requested_by = ?
          OR EXISTS (
            SELECT 1 FROM workflow_request_assignments wra
            WHERE wra.request_id = wr.id AND wra.teacher_id = ?
          ))`
      );
      params.push(empId, empId);
    }

    const requests = await query(
      `SELECT wr.*,
              CONCAT(e.first_name,' ',e.last_name) AS requester_name,
              rt.name AS template_name
       FROM workflow_requests wr
       JOIN employees e ON e.id = wr.requested_by
       LEFT JOIN request_templates rt ON rt.id = wr.template_id
       WHERE ${where.join(' AND ')}
       ORDER BY wr.created_at DESC`, params
    );
    res.json({ success: true, data: requests });
  } catch (err) { next(err); }
});

// ─────────────────────────────────────────────────────────────
// POST /workflow/requests
// Create a new workflow request (starts in draft)
// Body: { template_id, title, description, request_type,
//         selected_fields, selected_classes,
//         start_date, due_date, send_to_parent,
//         notify_channels, assignments: [{class_name, section, teacher_ids}] }
// ─────────────────────────────────────────────────────────────
router.post('/requests', authenticate, async (req, res, next) => {
  try {
    const empId = req.employee?.id || null;
    const isAdminUser = ['super_admin', 'school_owner'].includes(req.user?.role);
    if (!empId && !isAdminUser)
      return res.status(403).json({ success: false, message: 'Not an employee' });

    const {
      template_id, title, description, request_type,
      selected_fields, selected_classes,
      start_date, due_date, send_to_parent = false,
      notify_channels, assignments = [],
      school_id, branch_id,
    } = req.body;

    if (!template_id || !title || !request_type || !start_date)
      return res.status(400).json({ success: false, message: 'template_id, title, request_type, start_date required' });

    const today = new Date(); today.setHours(0,0,0,0);
    const startD = new Date(start_date); startD.setHours(0,0,0,0);
    if (startD < today)
      return res.status(400).json({ success: false, message: 'start_date cannot be in the past' });

    const sid = school_id || req.employee?.school_id || req.user?.school_id;
    const id  = uuid();

    await transaction(async (conn) => {
      await conn.execute(
        `INSERT INTO workflow_requests
           (id, school_id, branch_id, template_id, title, description, request_type,
            selected_fields, selected_classes, start_date, due_date,
            send_to_parent, notify_channels, requested_by)
         VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?)`,
        [id, sid, branch_id || null, template_id, title, description || null, request_type,
         JSON.stringify(selected_fields || []),
         JSON.stringify(selected_classes || []),
         start_date, due_date || null,
         send_to_parent ? 1 : 0,
         JSON.stringify(notify_channels || ['sms','whatsapp','email']),
         empId || req.user.id]
      );

      // Save teacher assignments
      for (const asgn of assignments) {
        const teacherIds = Array.isArray(asgn.teacher_ids) ? asgn.teacher_ids : [asgn.teacher_id].filter(Boolean);
        for (let i = 0; i < teacherIds.length; i++) {
          await conn.execute(
            `INSERT IGNORE INTO workflow_request_assignments
               (id, request_id, class_name, section, teacher_id, is_primary)
             VALUES (?,?,?,?,?,?)`,
            [uuid(), id, asgn.class_name, asgn.section, teacherIds[i], i === 0 ? 1 : 0]
          );
        }
      }
    });

    const [request] = await query('SELECT * FROM workflow_requests WHERE id=?', [id]);
    res.status(201).json({ success: true, data: request });
  } catch (err) { next(err); }
});

// ─────────────────────────────────────────────────────────────
// GET /workflow/requests/:id
// Get full request details with assignments
// ─────────────────────────────────────────────────────────────
router.get('/requests/:id', authenticate, async (req, res, next) => {
  try {
    const [wr] = await query(
      `SELECT wr.*,
              CONCAT(e.first_name,' ',e.last_name) AS requester_name,
              rt.name AS template_name, rt.template_type
       FROM workflow_requests wr
       JOIN employees e ON e.id = wr.requested_by
       LEFT JOIN request_templates rt ON rt.id = wr.template_id
       WHERE wr.id=?`, [req.params.id]
    );
    if (!wr) return res.status(404).json({ success: false, message: 'Request not found' });

    const assignments = await query(
      `SELECT wra.*, CONCAT(e.first_name,' ',e.last_name) AS teacher_name,
              e.photo_url AS teacher_photo, e.phone AS teacher_phone
       FROM workflow_request_assignments wra
       JOIN employees e ON e.id = wra.teacher_id
       WHERE wra.request_id=?
       ORDER BY wra.class_name, wra.section, wra.is_primary DESC`, [req.params.id]
    );

    res.json({ success: true, data: { ...wr, assignments } });
  } catch (err) { next(err); }
});

// ─────────────────────────────────────────────────────────────
// PATCH /workflow/requests/:id
// Update draft request (fields, assignments, schedule)
// ─────────────────────────────────────────────────────────────
router.patch('/requests/:id', authenticate, async (req, res, next) => {
  try {
    const [wr] = await query('SELECT * FROM workflow_requests WHERE id=?', [req.params.id]);
    if (!wr) return res.status(404).json({ success: false, message: 'Not found' });
    if (wr.status !== 'draft') return res.status(400).json({ success: false, message: 'Only draft requests can be edited' });

    const { title, description, selected_fields, selected_classes,
            start_date, due_date, send_to_parent, notify_channels, assignments } = req.body;

    if (start_date) {
      const today = new Date(); today.setHours(0,0,0,0);
      const startD = new Date(start_date); startD.setHours(0,0,0,0);
      if (startD < today) return res.status(400).json({ success: false, message: 'start_date cannot be in the past' });
    }

    await transaction(async (conn) => {
      await conn.execute(
        `UPDATE workflow_requests SET
           title=COALESCE(?,title), description=COALESCE(?,description),
           selected_fields=COALESCE(?,selected_fields),
           selected_classes=COALESCE(?,selected_classes),
           start_date=COALESCE(?,start_date), due_date=COALESCE(?,due_date),
           send_to_parent=COALESCE(?,send_to_parent),
           notify_channels=COALESCE(?,notify_channels)
         WHERE id=?`,
        [title||null, description||null,
         selected_fields ? JSON.stringify(selected_fields) : null,
         selected_classes ? JSON.stringify(selected_classes) : null,
         start_date||null, due_date||null,
         send_to_parent != null ? (send_to_parent ? 1 : 0) : null,
         notify_channels ? JSON.stringify(notify_channels) : null,
         req.params.id]
      );

      if (assignments) {
        await conn.execute('DELETE FROM workflow_request_assignments WHERE request_id=?', [req.params.id]);
        for (const asgn of assignments) {
          const teacherIds = Array.isArray(asgn.teacher_ids) ? asgn.teacher_ids : [asgn.teacher_id].filter(Boolean);
          for (let i = 0; i < teacherIds.length; i++) {
            await conn.execute(
              `INSERT IGNORE INTO workflow_request_assignments
                 (id, request_id, class_name, section, teacher_id, is_primary)
               VALUES (?,?,?,?,?,?)`,
              [uuid(), req.params.id, asgn.class_name, asgn.section, teacherIds[i], i === 0 ? 1 : 0]
            );
          }
        }
      }
    });

    const [updated] = await query('SELECT * FROM workflow_requests WHERE id=?', [req.params.id]);
    res.json({ success: true, data: updated });
  } catch (err) { next(err); }
});

// ─────────────────────────────────────────────────────────────
// POST /workflow/requests/:id/launch
// Launch the workflow: create items for each student/teacher
// and send initial notifications
// ─────────────────────────────────────────────────────────────
router.post('/requests/:id/launch', authenticate, async (req, res, next) => {
  try {
    const [wr] = await query('SELECT * FROM workflow_requests WHERE id=?', [req.params.id]);
    if (!wr) return res.status(404).json({ success: false, message: 'Not found' });
    if (!['draft'].includes(wr.status))
      return res.status(400).json({ success: false, message: 'Request already launched' });

    const assignments = await query(
      'SELECT * FROM workflow_request_assignments WHERE request_id=?', [req.params.id]
    );

    const selectedClasses = Array.isArray(wr.selected_classes)
      ? wr.selected_classes
      : JSON.parse(wr.selected_classes || '[]');

    let items = [];

    if (wr.request_type === 'student_info') {
      // Build class-section list from assignments or selected_classes
      const classSections = selectedClasses.length > 0
        ? selectedClasses
        : [...new Set(assignments.map(a => `${a.class_name}||${a.section}`))].map(cs => {
            const [cn, sec] = cs.split('||');
            return { class_name: cn, section: sec };
          });

      for (const cs of classSections) {
        const students = await query(
          `SELECT id, class_name, section, roll_number FROM students
           WHERE school_id=? AND class_name=? AND section=? AND is_active=1`,
          [wr.school_id, cs.class_name, cs.section]
        );
        const primaryTeacher = assignments.find(
          a => a.class_name === cs.class_name && a.section === cs.section && a.is_primary
        );
        for (const s of students) {
          items.push({
            id: uuid(), request_id: wr.id, item_type: 'student',
            student_id: s.id, class_name: s.class_name, section: s.section,
            roll_number: s.roll_number, assigned_teacher_id: primaryTeacher?.teacher_id || null,
          });
        }
      }
    } else if (wr.request_type === 'teacher_info') {
      const classSections = selectedClasses.length > 0 ? selectedClasses : null;
      let employeeQuery = `SELECT id, first_name, last_name, assigned_classes FROM employees
                           WHERE school_id=? AND is_active=1`;
      const empParams = [wr.school_id];
      if (wr.branch_id) { employeeQuery += ' AND branch_id=?'; empParams.push(wr.branch_id); }
      const teachers = await query(employeeQuery, empParams);

      for (const t of teachers) {
        if (t.id === req.employee?.id) continue; // skip requestor themselves
        // Find a reviewer who is not the teacher being reviewed; prefer primary
        const primaryReviewer = assignments.find(a => a.is_primary && a.teacher_id !== t.id)
          || assignments.find(a => a.teacher_id !== t.id)
          || assignments[0];
        items.push({
          id: uuid(), request_id: wr.id, item_type: 'employee',
          employee_id: t.id, assigned_teacher_id: primaryReviewer?.teacher_id || null,
        });
      }
    } else { // document
      // Same as student_info but for all students in school/branch
      let studentQuery = 'SELECT id, class_name, section, roll_number FROM students WHERE school_id=? AND is_active=1';
      const sparams = [wr.school_id];
      if (wr.branch_id) { studentQuery += ' AND branch_id=?'; sparams.push(wr.branch_id); }
      const students = await query(studentQuery, sparams);
      for (const s of students) {
        const primaryTeacher = assignments.find(
          a => a.class_name === s.class_name && a.section === s.section && a.is_primary
        );
        items.push({
          id: uuid(), request_id: wr.id, item_type: 'student',
          student_id: s.id, class_name: s.class_name, section: s.section,
          roll_number: s.roll_number, assigned_teacher_id: primaryTeacher?.teacher_id || null,
        });
      }
    }

    if (!items.length)
      return res.status(400).json({ success: false, message: 'No students/employees found for selected classes' });

    // Insert all items
    for (const item of items) {
      await query(
        `INSERT INTO workflow_request_items
           (id, request_id, item_type, student_id, employee_id,
            class_name, section, roll_number, assigned_teacher_id)
         VALUES (?,?,?,?,?,?,?,?,?)`,
        [item.id, item.request_id, item.item_type,
         item.student_id || null, item.employee_id || null,
         item.class_name || null, item.section || null,
         item.roll_number || null, item.assigned_teacher_id || null]
      );
    }

    // Update request status
    await query(
      `UPDATE workflow_requests SET status='active', launched_at=NOW(),
       total_items=?, pending_items=?, completed_items=0 WHERE id=?`,
      [items.length, items.length, wr.id]
    );

    // Notify assigned teachers
    const teacherIds = [...new Set(items.map(i => i.assigned_teacher_id).filter(Boolean))];
    if (teacherIds.length) {
      const teachers = await query(
        `SELECT id, first_name, phone, whatsapp_no, email FROM employees WHERE id IN (${teacherIds.map(() => '?').join(',')})`,
        teacherIds
      );
      const dueDateStr = wr.due_date
        ? new Date(wr.due_date).toLocaleDateString('en-IN', { day:'2-digit', month:'short', year:'numeric' })
        : 'to be notified';
      const msg = `Dear Teacher, you have a new data review workflow assigned: "${wr.title}". Please log in to review and process the student records. Due by: ${dueDateStr}.`;
      await notifyEmployees(teachers, wr.school_id, `New Workflow Assignment: ${wr.title}`, msg);
    }

    // If send_to_parent, immediately send parent review links
    if (wr.send_to_parent) {
      // This triggers the same flow as parent/send-link for each student
      // We just flag items as sent_to_parent and send notifications
      // (Full parent portal review is handled via existing parent.js route)
      const crypto = require('crypto');
      const studentItems = items.filter(i => i.item_type === 'student' && i.student_id);
      for (const item of studentItems) {
        const [student] = await query(
          `SELECT s.*, sch.name AS school_name FROM students s
           JOIN schools sch ON sch.id = s.school_id
           WHERE s.id=?`, [item.student_id]
        );
        const guardians = await query('SELECT * FROM guardians WHERE student_id=?', [item.student_id]);
        const token = crypto.randomBytes(32).toString('hex');
        const expiresAt = wr.due_date
          ? new Date(new Date(wr.due_date).getTime() + 24*60*60*1000)
          : new Date(Date.now() + 72*60*60*1000);
        const reviewId = uuid();

        await query(
          `INSERT INTO parent_reviews
             (id, student_id, review_token, link_sent_by, link_sent_at, link_expires_at,
              original_data, status)
           VALUES (?,?,?,?,NOW(),?,?,'link_sent')`,
          [reviewId, item.student_id, token, wr.requested_by, expiresAt,
           JSON.stringify({ student, guardians })]
        );
        await query(
          `UPDATE workflow_request_items SET status='sent_to_parent', parent_review_id=?, last_notified_at=NOW()
           WHERE id=?`, [reviewId, item.id]
        );

        const baseUrl = process.env.APP_BASE_URL || 'https://80.225.246.32';
        const reviewUrl = `${baseUrl}/idmgmt/parent-review?token=${token}`;
        const expiresStr = expiresAt.toLocaleDateString('en-IN', { day:'2-digit', month:'short', year:'numeric' });
        const parentMsg = `Dear Parent, please review and update ${student.first_name}'s details for ${student.school_name}.\nWorkflow: ${wr.title}\nLink: ${reviewUrl}\nExpires: ${expiresStr}`;

        await notifyGuardians(
          guardians.filter(g => g.phone || g.whatsapp_no || g.email),
          wr.school_id,
          `Action Required: Review ${student.first_name}'s details`,
          parentMsg
        );
      }
    }

    await refreshRequestStats(wr.id);
    const [updated] = await query('SELECT * FROM workflow_requests WHERE id=?', [wr.id]);
    res.json({ success: true, data: updated, items_created: items.length });
  } catch (err) { next(err); }
});

// ─────────────────────────────────────────────────────────────
// PATCH /workflow/requests/:id/extend
// Extend due date
// ─────────────────────────────────────────────────────────────
router.patch('/requests/:id/extend', authenticate, async (req, res, next) => {
  try {
    const { new_due_date, reason } = req.body;
    if (!new_due_date) return res.status(400).json({ success: false, message: 'new_due_date required' });

    await query(
      'UPDATE workflow_requests SET extended_due_date=?, due_date=? WHERE id=?',
      [new_due_date, new_due_date, req.params.id]
    );
    res.json({ success: true, message: 'Due date extended' });
  } catch (err) { next(err); }
});

// ─────────────────────────────────────────────────────────────
// GET /workflow/requests/:id/items
// List items with filtering and sorting
// Query params: class_name, section, status, item_type, sort_by
// ─────────────────────────────────────────────────────────────
router.get('/requests/:id/items', authenticate, async (req, res, next) => {
  try {
    const { class_name, section, status, sort_by = 'class_name,section,roll_number' } = req.query;
    const empId  = req.employee?.id;
    const level  = req.employee?.role_level || 99;
    const adminRoles = ['super_admin', 'school_owner', 'principal', 'vp'];
    const isAdmin = adminRoles.includes(req.user?.role);

    let where = ['wri.request_id = ?'];
    let params = [req.params.id];

    // Level > 3 teachers only see their assigned items (or their subordinates')
    // Admins and school owners always see all items
    if (!isAdmin && level > 3 && empId) {
      where.push(
        `(wri.assigned_teacher_id = ?
          OR wri.assigned_teacher_id IN (
            SELECT id FROM employees WHERE reports_to_emp_id = ?
          ))`
      );
      params.push(empId, empId);
    }

    if (class_name) { where.push('wri.class_name = ?'); params.push(class_name); }
    if (section)    { where.push('wri.section = ?');    params.push(section); }
    if (status)     { where.push('wri.status = ?');     params.push(status); }

    // Allowed sort columns
    const sortMap = {
      'class': 'wri.class_name, wri.section, wri.roll_number',
      'roll':  'wri.roll_number',
      'name':  'stu.first_name, stu.last_name',
      'status':'wri.status',
    };
    const orderBy = sortMap[sort_by] || 'wri.class_name, wri.section, CAST(wri.roll_number AS UNSIGNED)';

    const items = await query(
      `SELECT wri.*,
              stu.first_name AS student_first, stu.last_name AS student_last,
              stu.photo_url AS student_photo, stu.status_color,
              stu.aadhaar_no AS student_aadhaar, stu.review_status AS student_review_status,
              emp.first_name AS emp_first, emp.last_name AS emp_last,
              emp.photo_url AS emp_photo,
              CONCAT(tch.first_name,' ',tch.last_name) AS teacher_name,
              tch.photo_url AS teacher_photo,
              pr.status AS parent_review_status,
              pr.changes_summary AS parent_changes_summary,
              pr.submitted_at AS parent_submitted_at
       FROM workflow_request_items wri
       LEFT JOIN students stu ON stu.id = wri.student_id
       LEFT JOIN employees emp ON emp.id = wri.employee_id
       LEFT JOIN employees tch ON tch.id = wri.assigned_teacher_id
       LEFT JOIN parent_reviews pr ON pr.id = wri.parent_review_id
       WHERE ${where.join(' AND ')}
       ORDER BY ${orderBy}`, params
    );
    // Parse JSON fields returned as strings from TEXT columns
    const parsed = items.map(item => ({
      ...item,
      parent_changes_summary: item.parent_changes_summary
        ? (typeof item.parent_changes_summary === 'string'
            ? JSON.parse(item.parent_changes_summary)
            : item.parent_changes_summary)
        : null,
    }));
    res.json({ success: true, data: parsed });
  } catch (err) { next(err); }
});

// ─────────────────────────────────────────────────────────────
// GET /workflow/requests/:id/items/:itemId
// Full item detail including parent submission data
// ─────────────────────────────────────────────────────────────
router.get('/requests/:id/items/:itemId', authenticate, async (req, res, next) => {
  try {
    const [item] = await query(
      `SELECT wri.*,
              stu.first_name AS student_first, stu.last_name AS student_last, stu.photo_url AS student_photo,
              stu.class_name, stu.section, stu.roll_number,
              emp.first_name AS emp_first, emp.last_name AS emp_last, emp.photo_url AS emp_photo,
              CONCAT(tch.first_name,' ',tch.last_name) AS teacher_name,
              pr.status AS parent_review_status,
              pr.submitted_data AS parent_submitted_data,
              pr.changes_summary AS parent_changes_summary,
              pr.original_data AS parent_original_data,
              pr.submitted_at AS parent_submitted_at,
              pr.link_expires_at AS parent_link_expires_at
       FROM workflow_request_items wri
       LEFT JOIN students stu ON stu.id = wri.student_id
       LEFT JOIN employees emp ON emp.id = wri.employee_id
       LEFT JOIN employees tch ON tch.id = wri.assigned_teacher_id
       LEFT JOIN parent_reviews pr ON pr.id = wri.parent_review_id
       WHERE wri.id = ? AND wri.request_id = ?`,
      [req.params.itemId, req.params.id]
    );
    if (!item) return res.status(404).json({ success: false, message: 'Item not found' });

    // Parse stored JSON strings
    const parseField = (v) => v == null ? null : (typeof v === 'string' ? JSON.parse(v) : v);
    item.parent_submitted_data  = parseField(item.parent_submitted_data);
    item.parent_changes_summary = parseField(item.parent_changes_summary);
    item.parent_original_data   = parseField(item.parent_original_data);

    res.json({ success: true, data: item });
  } catch (err) { next(err); }
});

// ─────────────────────────────────────────────────────────────
// PATCH /workflow/requests/:id/items/:itemId
// Teacher: approve | reject | request_resubmit | send_to_parent
// ─────────────────────────────────────────────────────────────
router.patch('/requests/:id/items/:itemId', authenticate, async (req, res, next) => {
  try {
    const { action, notes } = req.body;
    const validActions = ['approve','reject','request_resubmit','mark_under_review','send_to_parent'];
    if (!validActions.includes(action))
      return res.status(400).json({ success: false, message: `action must be one of: ${validActions.join(', ')}` });

    const [item] = await query('SELECT * FROM workflow_request_items WHERE id=? AND request_id=?',
      [req.params.itemId, req.params.id]);
    if (!item) return res.status(404).json({ success: false, message: 'Item not found' });

    const [wr] = await query('SELECT * FROM workflow_requests WHERE id=?', [req.params.id]);

    let newStatus;
    switch (action) {
      case 'approve':          newStatus = 'approved'; break;
      case 'reject':           newStatus = 'rejected'; break;
      case 'request_resubmit': newStatus = 'resubmit_requested'; break;
      case 'mark_under_review':newStatus = 'teacher_under_review'; break;
      case 'send_to_parent':   newStatus = 'sent_to_parent'; break;
    }

    await query(
      `UPDATE workflow_request_items
       SET status=?, teacher_notes=COALESCE(?,teacher_notes),
           reviewed_at = CASE WHEN ? IN ('approved','rejected') THEN NOW() ELSE reviewed_at END
       WHERE id=?`,
      [newStatus, notes||null, newStatus, item.id]
    );

    // If sending to parent — create parent_review record
    if (action === 'send_to_parent' && item.student_id) {
      const crypto = require('crypto');
      const [student] = await query(
        `SELECT s.*, sch.name AS school_name FROM students s
         JOIN schools sch ON sch.id=s.school_id WHERE s.id=?`, [item.student_id]
      );
      const guardians = await query('SELECT * FROM guardians WHERE student_id=?', [item.student_id]);
      const token = crypto.randomBytes(32).toString('hex');
      const expiresAt = wr.due_date
        ? new Date(new Date(wr.due_date).getTime() + 24*60*60*1000)
        : new Date(Date.now() + 72*60*60*1000);
      const reviewId = uuid();

      const sentById = req.employee?.id || req.user.id;
      // link_sent_by is a FK to employees; if school_owner has no emp record, use their emp if any
      // The JOIN in POST /parent/review is handled with LEFT JOIN for safety
      await query(
        `INSERT INTO parent_reviews
           (id, student_id, review_token, link_sent_by, link_sent_at, link_expires_at, original_data, status)
         VALUES (?,?,?,?,NOW(),?,?,'link_sent')`,
        [reviewId, item.student_id, token, sentById, expiresAt,
         JSON.stringify({ student, guardians })]
      );
      await query(
        'UPDATE workflow_request_items SET parent_review_id=?, last_notified_at=NOW() WHERE id=?',
        [reviewId, item.id]
      );

      const baseUrl = process.env.APP_BASE_URL || 'https://80.225.246.32';
      const reviewUrl = `${baseUrl}/idmgmt/parent-review?token=${token}`;
      const expiresStr = expiresAt.toLocaleDateString('en-IN', { day:'2-digit', month:'short', year:'numeric' });
      const parentMsg = `Dear Parent, please review and update ${student.first_name}'s details.\nWorkflow: ${wr.title}\nLink: ${reviewUrl}\nExpires: ${expiresStr}`;
      await notifyGuardians(
        guardians.filter(g => g.phone || g.whatsapp_no || g.email),
        wr.school_id,
        `Action Required: Review ${student.first_name}'s details`,
        parentMsg
      );
    }

    // Notify requestor on completion
    if (['approved','rejected'].includes(newStatus)) {
      const [requestor] = await query(
        'SELECT id, first_name, phone, whatsapp_no, email FROM employees WHERE id=?',
        [wr.requested_by]
      );
      if (requestor) {
        const subjectName = item.student_id
          ? (await query('SELECT first_name FROM students WHERE id=?', [item.student_id]))[0]?.first_name
          : (await query('SELECT first_name FROM employees WHERE id=?', [item.employee_id]))[0]?.first_name;
        await notifyEmployees([requestor], wr.school_id,
          `Item ${newStatus}: ${wr.title}`,
          `Item for ${subjectName || 'record'} has been ${newStatus}.${notes ? ` Notes: ${notes}` : ''}`
        );
      }
    }

    await refreshRequestStats(req.params.id);
    res.json({ success: true, message: `Item ${newStatus}` });
  } catch (err) { next(err); }
});

// ─────────────────────────────────────────────────────────────
// POST /workflow/requests/:id/remind
// Resend notifications to pending parents/teachers
// Body: { item_ids: [...], custom_message, extend_due_date }
// ─────────────────────────────────────────────────────────────
router.post('/requests/:id/remind', authenticate, async (req, res, next) => {
  try {
    const { item_ids, custom_message, extend_due_date } = req.body;
    const [wr] = await query('SELECT * FROM workflow_requests WHERE id=?', [req.params.id]);
    if (!wr) return res.status(404).json({ success: false, message: 'Request not found' });

    // Extend due date if provided
    if (extend_due_date) {
      const today = new Date(); today.setHours(0,0,0,0);
      const extD  = new Date(extend_due_date); extD.setHours(0,0,0,0);
      if (extD <= today) return res.status(400).json({ success: false, message: 'Extended due date must be in the future' });
      await query('UPDATE workflow_requests SET due_date=?, extended_due_date=? WHERE id=?',
        [extend_due_date, extend_due_date, wr.id]);
    }

    // Select items to remind
    let whereIds = 'wri.request_id = ?';
    let qparams  = [wr.id];
    if (item_ids?.length) { whereIds += ` AND wri.id IN (${item_ids.map(() => '?').join(',')})`;  qparams.push(...item_ids); }
    else { whereIds += ` AND wri.status NOT IN ('approved','rejected')`; }

    const items = await query(
      `SELECT wri.*,
              stu.first_name AS student_first, stu.last_name AS student_last, stu.school_id,
              pr.review_token, pr.link_expires_at,
              CONCAT(tch.first_name,' ',tch.last_name) AS teacher_name,
              tch.phone AS teacher_phone, tch.whatsapp_no AS teacher_wa, tch.email AS teacher_email
       FROM workflow_request_items wri
       LEFT JOIN students stu ON stu.id = wri.student_id
       LEFT JOIN parent_reviews pr ON pr.id = wri.parent_review_id
       LEFT JOIN employees tch ON tch.id = wri.assigned_teacher_id
       WHERE ${whereIds}`, qparams
    );

    const newDue = extend_due_date || wr.due_date;
    const dueDateStr = newDue
      ? new Date(newDue).toLocaleDateString('en-IN', { day:'2-digit', month:'short', year:'numeric' })
      : 'as soon as possible';

    let reminded = 0;
    for (const item of items) {
      // Remind parent if sent to parent
      if (item.review_token && item.status === 'sent_to_parent') {
        const baseUrl = process.env.APP_BASE_URL || 'https://80.225.246.32';
        const reviewUrl = `${baseUrl}/idmgmt/parent-review?token=${item.review_token}`;
        const guardians = await query(
          'SELECT * FROM guardians WHERE student_id=? AND (phone IS NOT NULL OR whatsapp_no IS NOT NULL OR email IS NOT NULL)',
          [item.student_id]
        );
        const msg = custom_message
          || `Reminder: Please review ${item.student_first}'s details for "${wr.title}".\nLink: ${reviewUrl}\nDue by: ${dueDateStr}`;
        await notifyGuardians(guardians, item.school_id, `Reminder: ${wr.title}`, msg);
        await query('UPDATE workflow_request_items SET reminder_count=reminder_count+1, last_notified_at=NOW() WHERE id=?', [item.id]);
        reminded++;
      }
      // Remind teacher if still pending
      if (item.status === 'pending' && item.teacher_phone) {
        const teacherMsg = custom_message
          || `Reminder: You have pending review items in "${wr.title}". Please log in and process them by ${dueDateStr}.`;
        await sendNotification({
          phone: item.teacher_phone, whatsapp: item.teacher_wa, email: item.teacher_email,
          subject: `Reminder: ${wr.title}`, message: teacherMsg,
          school_id: wr.school_id, recipient_id: item.assigned_teacher_id, recipient_type: 'employee',
        }).catch(err => logger.warn(`[WORKFLOW] Remind teacher failed: ${err.message}`));
        await query('UPDATE workflow_request_items SET reminder_count=reminder_count+1, last_notified_at=NOW() WHERE id=?', [item.id]);
        reminded++;
      }
    }

    res.json({ success: true, message: `Reminders sent to ${reminded} recipient(s)`, reminded });
  } catch (err) { next(err); }
});

// ─────────────────────────────────────────────────────────────
// GET /workflow/requests/:id/items/:itemId/comments
// ─────────────────────────────────────────────────────────────
router.get('/requests/:id/items/:itemId/comments', authenticate, async (req, res, next) => {
  try {
    const comments = await query(
      'SELECT * FROM workflow_item_comments WHERE item_id=? ORDER BY created_at ASC',
      [req.params.itemId]
    );
    res.json({ success: true, data: comments });
  } catch (err) { next(err); }
});

// ─────────────────────────────────────────────────────────────
// POST /workflow/requests/:id/items/:itemId/comments
// Add a comment at item level
// ─────────────────────────────────────────────────────────────
router.post('/requests/:id/items/:itemId/comments', authenticate, async (req, res, next) => {
  try {
    const { comment_text, commenter_type } = req.body;
    if (!comment_text?.trim()) return res.status(400).json({ success: false, message: 'comment_text required' });

    const id = uuid();
    const commenterName = req.employee
      ? `${req.employee.first_name} ${req.employee.last_name}`
      : (req.user?.full_name || 'User');
    const ctype = commenter_type || (req.user?.role === 'parent' ? 'parent' : 'teacher');

    await query(
      `INSERT INTO workflow_item_comments (id, item_id, commenter_id, commenter_name, commenter_type, comment_text)
       VALUES (?,?,?,?,?,?)`,
      [id, req.params.itemId, req.user.id, commenterName, ctype, comment_text.trim()]
    );

    const [comment] = await query('SELECT * FROM workflow_item_comments WHERE id=?', [id]);
    res.status(201).json({ success: true, data: comment });
  } catch (err) { next(err); }
});

// ─────────────────────────────────────────────────────────────
// GET /workflow/requests/:id/available-teachers
// Return teachers for each class-section, ordered by
// class+section then alphabetically (for assignment UI)
// ─────────────────────────────────────────────────────────────
router.get('/requests/:id/available-teachers', authenticate, async (req, res, next) => {
  try {
    const [wr] = await query('SELECT * FROM workflow_requests WHERE id=?', [req.params.id]);
    if (!wr) return res.status(404).json({ success: false, message: 'Not found' });

    const selectedClasses = Array.isArray(wr.selected_classes)
      ? wr.selected_classes
      : JSON.parse(wr.selected_classes || '[]');

    const result = [];
    for (const cs of selectedClasses) {
      // Primary: actual class teacher
      const classTeachers = await query(
        `SELECT DISTINCT e.id, e.first_name, e.last_name, e.photo_url, e.phone, e.email,
                or2.level, or2.name AS role_name
         FROM employees e
         JOIN org_roles or2 ON or2.id = e.org_role_id
         WHERE e.school_id = ? AND e.is_active = 1
           AND JSON_CONTAINS(e.assigned_classes, JSON_QUOTE(CONCAT(?,?)), '$')
         ORDER BY or2.level ASC, e.first_name ASC`,
        [wr.school_id, cs.class_name, cs.section]
      );

      // Fallback: all active teachers in school ordered alphabetically
      const allTeachers = await query(
        `SELECT e.id, e.first_name, e.last_name, e.photo_url, e.phone, e.email,
                or2.level, or2.name AS role_name
         FROM employees e
         JOIN org_roles or2 ON or2.id = e.org_role_id
         WHERE e.school_id = ? AND e.is_active = 1 AND or2.level >= 4
         ORDER BY or2.level ASC, e.first_name ASC`,
        [wr.school_id]
      );

      result.push({
        class_name: cs.class_name,
        section:    cs.section,
        class_teachers: classTeachers,
        all_teachers:   allTeachers,
        suggested_teacher_id: classTeachers[0]?.id || null,
      });
    }

    res.json({ success: true, data: result });
  } catch (err) { next(err); }
});

// ─────────────────────────────────────────────────────────────
// GET /workflow/classes  — get all class-sections for school
// ─────────────────────────────────────────────────────────────
router.get('/classes', authenticate, async (req, res, next) => {
  try {
    const schoolId = req.query.school_id || req.employee?.school_id;
    const branchId = req.query.branch_id;

    let q = `SELECT DISTINCT s.class_name, s.section,
               (SELECT e.id FROM employees e
                JOIN org_roles r ON r.id = e.org_role_id
                WHERE e.school_id = s.school_id AND e.is_active = 1
                  AND JSON_CONTAINS(e.assigned_classes, JSON_QUOTE(CONCAT(s.class_name, s.section)), '$')
                ORDER BY r.level ASC, e.first_name ASC LIMIT 1) AS teacher_id,
               (SELECT CONCAT(e.first_name,' ',e.last_name) FROM employees e
                JOIN org_roles r ON r.id = e.org_role_id
                WHERE e.school_id = s.school_id AND e.is_active = 1
                  AND JSON_CONTAINS(e.assigned_classes, JSON_QUOTE(CONCAT(s.class_name, s.section)), '$')
                ORDER BY r.level ASC, e.first_name ASC LIMIT 1) AS teacher_name
             FROM students s
             WHERE s.school_id=? AND s.is_active=1`;
    const p = [schoolId];
    if (branchId) { q += ' AND s.branch_id=?'; p.push(branchId); }
    q += ' ORDER BY s.class_name, s.section';

    const classes = await query(q, p);
    res.json({ success: true, data: classes });
  } catch (err) { next(err); }
});

// ─────────────────────────────────────────────────────────────
// GET /workflow/requests/:id/overview
// Per-class-section: class teacher, backup teachers, supervisor (n+1), item stats
// ─────────────────────────────────────────────────────────────
router.get('/requests/:id/overview', authenticate, async (req, res, next) => {
  try {
    const [wr] = await query('SELECT * FROM workflow_requests WHERE id=?', [req.params.id]);
    if (!wr) return res.status(404).json({ success: false, message: 'Not found' });

    const empId = req.employee?.id;
    const level = req.employee?.role_level || 99;

    // Teachers (level > 3) only see their assigned class-sections (+ subordinates')
    let assignmentWhere = 'wra.request_id = ?';
    const assignmentParams = [req.params.id];
    if (level > 3 && empId) {
      assignmentWhere += ` AND (wra.teacher_id = ? OR wra.teacher_id IN (
        SELECT id FROM employees WHERE reports_to_emp_id = ?
      ))`;
      assignmentParams.push(empId, empId);
    }

    const assignments = await query(
      `SELECT wra.class_name, wra.section, wra.is_primary,
              e.id AS teacher_id,
              CONCAT(e.first_name,' ',e.last_name) AS teacher_name,
              e.photo_url AS teacher_photo, e.phone AS teacher_phone,
              sup.id AS supervisor_id,
              CONCAT(sup.first_name,' ',sup.last_name) AS supervisor_name,
              sup.photo_url AS supervisor_photo
       FROM workflow_request_assignments wra
       JOIN employees e ON e.id = wra.teacher_id
       LEFT JOIN employees sup ON sup.id = e.reports_to_emp_id
       WHERE ${assignmentWhere}
       ORDER BY wra.class_name, wra.section, wra.is_primary DESC`,
      assignmentParams
    );

    // For stats, restrict to the teacher's visible class-sections
    let statsWhere = 'request_id = ?';
    const statsParams = [req.params.id];
    if (level > 3 && empId && assignments.length > 0) {
      const uniqueKeys = [...new Set(assignments.map(a => `${a.class_name}||${a.section}`))];
      const pairs = uniqueKeys.map(() => `(class_name = ? AND section = ?)`).join(' OR ');
      statsWhere += ` AND (${pairs})`;
      uniqueKeys.forEach(k => { const [cn, sec] = k.split('||'); statsParams.push(cn, sec); });
    }

    const statsRows = await query(
      `SELECT class_name, section,
              COUNT(*) AS total,
              SUM(status='pending') AS pending,
              SUM(status='teacher_under_review') AS in_review,
              SUM(status='sent_to_parent') AS sent_to_parent,
              SUM(status='parent_submitted') AS parent_submitted,
              SUM(status='approved') AS approved,
              SUM(status='rejected') AS rejected,
              SUM(status='resubmit_requested') AS resubmit_requested
       FROM workflow_request_items WHERE ${statsWhere}
       GROUP BY class_name, section`,
      statsParams
    );

    const statsMap = {};
    for (const s of statsRows) {
      statsMap[`${s.class_name}||${s.section}`] = {
        total:            Number(s.total),
        pending:          Number(s.pending),
        in_review:        Number(s.in_review),
        sent_to_parent:   Number(s.sent_to_parent),
        parent_submitted: Number(s.parent_submitted),
        approved:         Number(s.approved),
        rejected:         Number(s.rejected),
        resubmit_requested: Number(s.resubmit_requested),
      };
    }

    const grouped = {};
    for (const a of assignments) {
      const key = `${a.class_name}||${a.section}`;
      if (!grouped[key]) {
        grouped[key] = { class_name: a.class_name, section: a.section,
                         class_teacher: null, backup_teachers: [], supervisor: null };
      }
      const teacher = { id: a.teacher_id, name: a.teacher_name, photo: a.teacher_photo, phone: a.teacher_phone };
      if (a.is_primary) {
        grouped[key].class_teacher = teacher;
        if (a.supervisor_id) {
          grouped[key].supervisor = { id: a.supervisor_id, name: a.supervisor_name, photo: a.supervisor_photo };
        }
      } else {
        grouped[key].backup_teachers.push(teacher);
      }
    }

    const result = Object.values(grouped).map(g => ({
      ...g,
      stats: statsMap[`${g.class_name}||${g.section}`]
             || { total:0, pending:0, in_review:0, sent_to_parent:0, parent_submitted:0, approved:0, rejected:0, resubmit_requested:0 },
    }));

    res.json({ success: true, data: result });
  } catch (err) { next(err); }
});

// ─────────────────────────────────────────────────────────────
// PATCH /workflow/requests/:id/status
// Body: { action: 'cancel' | 'hold' | 'resume' }
// cancel → 'cancelled'  |  hold → 'on_hold'  |  resume → back to active/in_progress
// ─────────────────────────────────────────────────────────────
router.patch('/requests/:id/status', authenticate, async (req, res, next) => {
  try {
    const { action } = req.body;
    if (!['cancel','hold','resume'].includes(action))
      return res.status(400).json({ success: false, message: 'action must be: cancel | hold | resume' });

    const [wr] = await query('SELECT * FROM workflow_requests WHERE id=?', [req.params.id]);
    if (!wr) return res.status(404).json({ success: false, message: 'Not found' });

    let newStatus;
    if (action === 'cancel') {
      if (['completed','cancelled'].includes(wr.status))
        return res.status(400).json({ success: false, message: 'Cannot cancel a completed or already cancelled request' });
      newStatus = 'cancelled';
    } else if (action === 'hold') {
      if (!['active','in_progress','draft'].includes(wr.status))
        return res.status(400).json({ success: false, message: 'Can only hold active, in_progress, or draft requests' });
      newStatus = 'on_hold';
    } else {
      if (wr.status !== 'on_hold')
        return res.status(400).json({ success: false, message: 'Can only resume requests that are on hold' });
      const total = Number(wr.total_items) || 0;
      const completed = Number(wr.completed_items) || 0;
      newStatus = total === 0 ? 'active' : (completed >= total ? 'completed' : 'in_progress');
    }

    await query('UPDATE workflow_requests SET status=? WHERE id=?', [newStatus, wr.id]);
    res.json({ success: true, status: newStatus });
  } catch (err) { next(err); }
});

module.exports = router;
