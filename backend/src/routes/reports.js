// ============================================================
// Reports Routes — N+1 hierarchy aware
// ============================================================
const router = require('express').Router();
const { query } = require('../models/db');
const { authenticate } = require('../middleware/auth');
const xlsx = require('xlsx');

function sendExcel(res, data, sheetName, filename) {
  const wb  = xlsx.utils.book_new();
  const ws  = xlsx.utils.json_to_sheet(data);
  xlsx.utils.book_append_sheet(wb, ws, sheetName);
  const buf = xlsx.write(wb, { type: 'buffer', bookType: 'xlsx' });
  res.setHeader('Content-Disposition', `attachment; filename="${filename}"`);
  res.setHeader('Content-Type', 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
  res.send(buf);
}

// ── GET /reports/dashboard — role-based stats ─────────────────
router.get('/dashboard', authenticate, async (req, res, next) => {
  try {
    const schoolId  = req.employee?.school_id || req.query.school_id;
    const branchId  = req.employee?.branch_id || req.query.branch_id;
    const empLevel  = req.employee?.role_level || 0;

    let where = ['s.is_active = TRUE'];
    let params = [];
    if (schoolId) { where.push('s.school_id = ?'); params.push(schoolId); }
    if (branchId && empLevel >= 5) { where.push('s.branch_id = ?'); params.push(branchId); }

    const [totals] = await query(
      `SELECT
         COUNT(*) AS total,
         SUM(status_color = 'green') AS approved,
         SUM(status_color = 'blue')  AS changes_pending,
         SUM(status_color = 'red')   AS not_responded,
         SUM(review_status = 'parent_reviewed') AS parent_reviewed
       FROM students s WHERE ${where.join(' AND ')}`, params
    );

    // By class breakdown
    const byClass = await query(
      `SELECT class_name, section,
              COUNT(*) AS total,
              SUM(status_color='green') AS green,
              SUM(status_color='blue')  AS blue,
              SUM(status_color='red')   AS red
       FROM students s
       WHERE ${where.join(' AND ')}
       GROUP BY class_name, section
       ORDER BY class_name, section`, params
    );

    res.json({ success: true, data: { totals, by_class: byClass } });
  } catch (err) { next(err); }
});

// ── GET /reports/teacher-wise — N+1 view ─────────────────────
router.get('/teacher-wise', authenticate, async (req, res, next) => {
  try {
    const schoolId = req.employee?.school_id || req.query.school_id;

    const teachers = await query(
      `SELECT e.id, e.first_name, e.last_name, e.employee_id,
              r.name AS role_name, r.level AS role_level,
              e.assigned_classes,
              COUNT(DISTINCT s.id)                           AS total_students,
              SUM(s.status_color = 'green')                  AS green,
              SUM(s.status_color = 'blue')                   AS blue,
              SUM(s.status_color = 'red')                    AS red
       FROM employees e
       JOIN org_roles r ON r.id = e.org_role_id
       LEFT JOIN students s
         ON s.school_id = e.school_id
         AND JSON_CONTAINS(e.assigned_classes, JSON_QUOTE(s.class_name))
       WHERE e.school_id = ? AND e.is_active = TRUE
         AND r.level >= 5
       GROUP BY e.id
       ORDER BY r.level, e.last_name`, [schoolId]
    );

    res.json({ success: true, data: teachers });
  } catch (err) { next(err); }
});

// ── GET /reports/class-summary — detailed class report ────────
router.get('/class-summary', authenticate, async (req, res, next) => {
  try {
    const { school_id, branch_id, class_name } = req.query;
    let where = ['s.is_active = TRUE'];
    let params = [];
    if (school_id)  { where.push('s.school_id = ?'); params.push(school_id); }
    if (branch_id)  { where.push('s.branch_id = ?'); params.push(branch_id); }
    if (class_name) { where.push('s.class_name = ?'); params.push(class_name); }

    const students = await query(
      `SELECT s.id, s.student_id, s.roll_number, s.first_name, s.last_name,
              s.class_name, s.section, s.gender, s.status_color, s.review_status,
              g.first_name AS parent_first, g.last_name AS parent_last,
              g.phone AS parent_phone, g.whatsapp_no AS parent_whatsapp,
              pr.submitted_at, pr.status AS review_link_status
       FROM students s
       LEFT JOIN guardians g ON g.student_id = s.id AND g.is_primary = TRUE
       LEFT JOIN parent_reviews pr ON pr.student_id = s.id AND pr.status != 'expired'
       WHERE ${where.join(' AND ')}
       ORDER BY s.class_name, s.section, CAST(s.roll_number AS UNSIGNED)`, params
    );

    res.json({ success: true, data: students });
  } catch (err) { next(err); }
});

// ── GET /reports/n-plus-one — hierarchical report for a manager
router.get('/n-plus-one', authenticate, async (req, res, next) => {
  try {
    const managerId = req.employee?.id;
    if (!managerId) return res.status(403).json({ success: false, message: 'No employee context' });

    // Find all direct reports (N) and their reports (N-1) recursively
    const directReports = await query(
      `WITH RECURSIVE subordinates AS (
         SELECT id, first_name, last_name, employee_id, org_role_id, reports_to_emp_id, school_id
         FROM employees WHERE reports_to_emp_id = ? AND is_active = TRUE
         UNION ALL
         SELECT e.id, e.first_name, e.last_name, e.employee_id, e.org_role_id, e.reports_to_emp_id, e.school_id
         FROM employees e
         INNER JOIN subordinates s ON e.reports_to_emp_id = s.id
         WHERE e.is_active = TRUE
       )
       SELECT sub.*,
              r.name AS role_name, r.level AS role_level,
              COUNT(DISTINCT s.id)           AS total_students,
              SUM(s.status_color='green')    AS green,
              SUM(s.status_color='blue')     AS blue,
              SUM(s.status_color='red')      AS red
       FROM subordinates sub
       JOIN org_roles r ON r.id = sub.org_role_id
       LEFT JOIN students s
         ON s.school_id = sub.school_id
         AND JSON_CONTAINS(
               (SELECT assigned_classes FROM employees WHERE id = sub.id),
               JSON_QUOTE(s.class_name))
       GROUP BY sub.id
       ORDER BY r.level, sub.last_name`, [managerId]
    );

    res.json({ success: true, data: directReports });
  } catch (err) { next(err); }
});

// ── GET /reports/review-changes — changes pending approval ────
router.get('/review-changes', authenticate, async (req, res, next) => {
  try {
    const employeeId = req.employee?.id;
    const schoolId   = req.employee?.school_id;

    const pending = await query(
      `SELECT pr.id, pr.changes_summary, pr.submitted_at, pr.original_data, pr.submitted_data,
              s.first_name, s.last_name, s.student_id, s.class_name, s.section
       FROM parent_reviews pr
       JOIN students s ON s.id = pr.student_id
       WHERE s.school_id = ? AND pr.status = 'parent_submitted'
       ORDER BY pr.submitted_at`, [schoolId]
    );

    const result = pending.map(r => ({
      ...r,
      original_data:  JSON.parse(r.original_data || '{}'),
      submitted_data: JSON.parse(r.submitted_data || '{}'),
      changes:        JSON.parse(r.changes_summary || '{}')
    }));

    res.json({ success: true, data: result });
  } catch (err) { next(err); }
});

// ── GET /reports/download/dashboard ───────────────────────────
router.get('/download/dashboard', authenticate, async (req, res, next) => {
  try {
    const schoolId = req.employee?.school_id || req.query.school_id;
    let where = ['s.is_active = TRUE'];
    let params = [];
    if (schoolId) { where.push('s.school_id = ?'); params.push(schoolId); }

    const byClass = await query(
      `SELECT class_name AS 'Class', section AS 'Section',
              COUNT(*) AS 'Total',
              SUM(status_color='green') AS 'Verified',
              SUM(status_color='blue')  AS 'Changes Pending',
              SUM(status_color='red')   AS 'Not Responded'
       FROM students s
       WHERE ${where.join(' AND ')}
       GROUP BY class_name, section
       ORDER BY class_name, section`, params
    );
    sendExcel(res, byClass, 'Dashboard', `dashboard_report_${Date.now()}.xlsx`);
  } catch (err) { next(err); }
});

// ── GET /reports/download/teacher-wise ────────────────────────
router.get('/download/teacher-wise', authenticate, async (req, res, next) => {
  try {
    const schoolId = req.employee?.school_id || req.query.school_id;
    const teachers = await query(
      `SELECT e.employee_id AS 'Employee ID',
              CONCAT(e.first_name,' ',e.last_name) AS 'Teacher Name',
              r.name AS 'Role', r.level AS 'Level',
              COUNT(DISTINCT s.id)                AS 'Total Students',
              SUM(s.status_color='green')         AS 'Verified',
              SUM(s.status_color='blue')          AS 'Changes Pending',
              SUM(s.status_color='red')           AS 'Not Responded'
       FROM employees e
       JOIN org_roles r ON r.id = e.org_role_id
       LEFT JOIN students s
         ON s.school_id = e.school_id
         AND JSON_CONTAINS(e.assigned_classes, JSON_QUOTE(s.class_name))
       WHERE e.school_id = ? AND e.is_active = TRUE AND r.level >= 5
       GROUP BY e.id ORDER BY r.level, e.last_name`, [schoolId]
    );
    sendExcel(res, teachers, 'Teacher-wise', `teacher_report_${Date.now()}.xlsx`);
  } catch (err) { next(err); }
});

// ── GET /reports/download/class-summary ───────────────────────
router.get('/download/class-summary', authenticate, async (req, res, next) => {
  try {
    const { school_id, branch_id, class_name } = req.query;
    let where = ['s.is_active = TRUE'];
    let params = [];
    if (school_id)  { where.push('s.school_id = ?'); params.push(school_id || req.employee?.school_id); }
    else if (req.employee?.school_id) { where.push('s.school_id = ?'); params.push(req.employee.school_id); }
    if (branch_id)  { where.push('s.branch_id = ?'); params.push(branch_id); }
    if (class_name) { where.push('s.class_name = ?'); params.push(class_name); }

    const students = await query(
      `SELECT s.student_id AS 'Student ID', s.roll_number AS 'Roll No',
              CONCAT(s.first_name,' ',s.last_name) AS 'Student Name',
              s.class_name AS 'Class', s.section AS 'Section',
              s.gender AS 'Gender', s.status_color AS 'Status',
              s.review_status AS 'Review Status',
              CONCAT(g.first_name,' ',g.last_name) AS 'Parent Name',
              g.phone AS 'Parent Phone', g.whatsapp_no AS 'Parent WhatsApp'
       FROM students s
       LEFT JOIN guardians g ON g.student_id = s.id AND g.is_primary = TRUE
       WHERE ${where.join(' AND ')}
       ORDER BY s.class_name, s.section, CAST(s.roll_number AS UNSIGNED)`, params
    );
    sendExcel(res, students, 'Class Summary', `class_summary_${Date.now()}.xlsx`);
  } catch (err) { next(err); }
});

// ── GET /reports/download/n-plus-one ──────────────────────────
router.get('/download/n-plus-one', authenticate, async (req, res, next) => {
  try {
    const managerId = req.employee?.id;
    if (!managerId) return res.status(403).json({ success: false, message: 'No employee context' });

    const rows = await query(
      `WITH RECURSIVE subordinates AS (
         SELECT id, first_name, last_name, employee_id, org_role_id, reports_to_emp_id, school_id
         FROM employees WHERE reports_to_emp_id = ? AND is_active = TRUE
         UNION ALL
         SELECT e.id, e.first_name, e.last_name, e.employee_id, e.org_role_id, e.reports_to_emp_id, e.school_id
         FROM employees e
         INNER JOIN subordinates s ON e.reports_to_emp_id = s.id
         WHERE e.is_active = TRUE
       )
       SELECT sub.employee_id AS 'Employee ID',
              CONCAT(sub.first_name,' ',sub.last_name) AS 'Name',
              r.name AS 'Role', r.level AS 'Level',
              COUNT(DISTINCT s.id)        AS 'Total Students',
              SUM(s.status_color='green') AS 'Verified',
              SUM(s.status_color='blue')  AS 'Changes Pending',
              SUM(s.status_color='red')   AS 'Not Responded'
       FROM subordinates sub
       JOIN org_roles r ON r.id = sub.org_role_id
       LEFT JOIN students s
         ON s.school_id = sub.school_id
         AND JSON_CONTAINS(
               (SELECT assigned_classes FROM employees WHERE id = sub.id),
               JSON_QUOTE(s.class_name))
       GROUP BY sub.id ORDER BY r.level, sub.last_name`, [managerId]
    );
    sendExcel(res, rows, 'N+1 Hierarchy', `nplus1_report_${Date.now()}.xlsx`);
  } catch (err) { next(err); }
});

// ── GET /reports/download/review-changes ──────────────────────
router.get('/download/review-changes', authenticate, async (req, res, next) => {
  try {
    const schoolId = req.employee?.school_id || req.query.school_id;
    const pending = await query(
      `SELECT CONCAT(s.first_name,' ',s.last_name) AS 'Student Name',
              s.student_id AS 'Student ID', s.class_name AS 'Class', s.section AS 'Section',
              pr.changes_summary AS 'Changes', pr.submitted_at AS 'Submitted At'
       FROM parent_reviews pr
       JOIN students s ON s.id = pr.student_id
       WHERE s.school_id = ? AND pr.status = 'parent_submitted'
       ORDER BY pr.submitted_at`, [schoolId]
    );
    sendExcel(res, pending, 'Pending Reviews', `review_changes_${Date.now()}.xlsx`);
  } catch (err) { next(err); }
});

module.exports = router;
