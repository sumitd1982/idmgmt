// ============================================================
// Attendance Routes
// Handles module configuration and daily tracking
// ============================================================
const router = require('express').Router();
const { query } = require('../models/db');
const { authenticate, requireRole } = require('../middleware/auth');

// ── MODULE CONFIGURATION ──────────────────────────────────────

// GET /attendance/modules
router.get('/modules', authenticate, async (req, res, next) => {
  try {
    const schoolId = req.employee?.school_id || req.user.school_id || req.query.school_id;
    if (!schoolId) return res.status(403).json({ success: false, message: 'No school context' });

    const modules = await query(
      `SELECT id, name, type, is_active, visible_to_parents, created_at
       FROM attendance_modules
       WHERE school_id = ?
       ORDER BY type, name`,
      [schoolId]
    );

    res.json({ success: true, data: modules });
  } catch (err) { next(err); }
});

// POST /attendance/modules (Create new module)
router.post('/modules', authenticate, requireRole('super_admin', 'school_owner', 'principal', 'vp'), async (req, res, next) => {
  try {
    const { name, type, is_active = true } = req.body;
    // SuperAdmin must provide school_id, others use their session school_id
    const isSchoolScoped = req.user.role === 'super_admin' || req.user.role === 'school_owner';
    const schoolId = isSchoolScoped ? (req.user.school_id || req.body.school_id) : req.employee?.school_id;

    if (!schoolId) return res.status(400).json({ success: false, message: 'school_id is required' });
    if (!name || !type) return res.status(400).json({ success: false, message: 'Name and Type required' });

    await query(
      `INSERT INTO attendance_modules (school_id, name, type, is_active)
       VALUES (?, ?, ?, ?)`,
      [schoolId, name, type, is_active]
    );

    res.json({ success: true, message: 'Module created successfully' });
  } catch (err) { next(err); }
});

// PATCH /attendance/modules/:id/toggle (Turn module ON/OFF)
router.patch('/modules/:id/toggle', authenticate, requireRole('super_admin', 'school_owner', 'principal', 'vp'), async (req, res, next) => {
  try {
    const schoolId = req.employee?.school_id || req.user.school_id || req.body.school_id;
    const { is_active } = req.body;

    await query(
      `UPDATE attendance_modules SET is_active = ? WHERE id = ? AND school_id = ?`,
      [is_active, req.params.id, schoolId]
    );
    res.json({ success: true, message: 'Module updated' });
  } catch (err) { next(err); }
});

// PATCH /attendance/modules/:id/settings (Update name, visible_to_parents, etc.)
router.patch('/modules/:id/settings', authenticate, requireRole('super_admin', 'school_owner', 'principal', 'vp'), async (req, res, next) => {
  try {
    const schoolId = req.employee?.school_id || req.user.school_id || req.body.school_id;
    const { visible_to_parents, name } = req.body;

    const updates = [];
    const params  = [];
    if (visible_to_parents !== undefined) { updates.push('visible_to_parents = ?'); params.push(visible_to_parents ? 1 : 0); }
    if (name !== undefined)               { updates.push('name = ?');               params.push(name); }
    if (!updates.length) return res.status(400).json({ success: false, message: 'Nothing to update' });

    params.push(req.params.id, schoolId);
    await query(
      `UPDATE attendance_modules SET ${updates.join(', ')} WHERE id = ? AND school_id = ?`,
      params
    );
    res.json({ success: true, message: 'Module settings updated' });
  } catch (err) { next(err); }
});

// ── STUDENT ASSIGNMENT (For Custom Modules) ───────────────────

// GET /attendance/modules/:id/students
router.get('/modules/:id/students', authenticate, async (req, res, next) => {
  try {
    const schoolId = req.employee?.school_id || req.user.school_id || req.query.school_id;
    
    const students = await query(
      `SELECT s.id, s.student_id, s.first_name, s.last_name, s.class_name, s.section, s.photo_url
       FROM students s
       JOIN student_module_mapping map ON map.student_id = s.id
       WHERE map.module_id = ? AND s.school_id = ?
       ORDER BY s.class_name, s.first_name`,
      [req.params.id, schoolId]
    );

    res.json({ success: true, data: students });
  } catch (err) { next(err); }
});

// POST /attendance/modules/:id/students (Add students to custom module)
router.post('/modules/:id/students', authenticate, requireRole('super_admin', 'school_owner', 'principal', 'vp'), async (req, res, next) => {
  try {
    const { student_ids } = req.body;
    if (!Array.isArray(student_ids) || student_ids.length === 0) {
      return res.status(400).json({ success: false, message: 'student_ids required' });
    }

    const moduleId = req.params.id;
    const values = student_ids.map(id => [id, moduleId]);

    await query(
      `INSERT IGNORE INTO student_module_mapping (student_id, module_id) VALUES ?`,
      [values]
    );

    res.json({ success: true, message: 'Students added to module' });
  } catch (err) { next(err); }
});

// ── DAILY TRACKING ────────────────────────────────────────────

// POST /attendance/record (Save daily attendance for a module)
router.post('/record', authenticate, async (req, res, next) => {
  try {
    const { module_id, date, records } = req.body; 
    // records = [{ student_id: '...', status: 'present', remarks: '...' }, ...]
    const recordedBy = req.employee?.id;

    if (!recordedBy) return res.status(403).json({ success: false, message: 'Employee context required' });
    if (!module_id || !date || !Array.isArray(records)) {
      return res.status(400).json({ success: false, message: 'Missing required data' });
    }

    const values = records.map(r => [
      module_id,
      date,
      r.student_id,
      r.status,
      r.remarks || null,
      recordedBy
    ]);

    // Use INSERT ... ON DUPLICATE KEY UPDATE to allow overriding today's attendance
    await query(
      `INSERT INTO attendance_records (module_id, date, student_id, status, remarks, recorded_by)
       VALUES ?
       ON DUPLICATE KEY UPDATE 
         status = VALUES(status), 
         remarks = VALUES(remarks),
         recorded_by = VALUES(recorded_by),
         created_at = CURRENT_TIMESTAMP`,
      [values]
    );

    res.json({ success: true, message: 'Attendance recorded successfully' });
  } catch (err) { next(err); }
});

// GET /attendance/history (View attendance for a module on a date)
router.get('/history', authenticate, async (req, res, next) => {
  try {
    const { module_id, date } = req.query;
    if (!module_id || !date) return res.status(400).json({ success: false, message: 'module_id and date required' });

    const history = await query(
      `SELECT r.student_id, r.status, r.remarks, r.created_at, e.first_name AS recorded_by_name
       FROM attendance_records r
       LEFT JOIN employees e ON e.id = r.recorded_by
       WHERE r.module_id = ? AND r.date = ?`,
      [module_id, date]
    );

    res.json({ success: true, data: history });
  } catch (err) { next(err); }
});

// ── MANAGEMENT SUMMARY ────────────────────────────────────────

// GET /attendance/summary (School-wide % by module for a date range)
router.get('/summary', authenticate, async (req, res, next) => {
  try {
    const schoolId  = req.employee?.school_id || req.user.school_id || req.query.school_id;
    const { from_date, to_date, class_name, section, module_id } = req.query;
    if (!schoolId) return res.status(403).json({ success: false, message: 'No school context' });

    const fromDate = from_date || new Date(Date.now() - 30 * 86400000).toISOString().split('T')[0];
    const toDate   = to_date   || new Date().toISOString().split('T')[0];

    let where  = ['am.school_id = ?', 'ar.date BETWEEN ? AND ?'];
    let params = [schoolId, fromDate, toDate];

    if (module_id)  { where.push('am.id = ?');          params.push(module_id); }
    if (class_name) { where.push('s.class_name = ?');   params.push(class_name); }
    if (section)    { where.push('s.section = ?');      params.push(section); }

    const rows = await query(
      `SELECT am.id AS module_id, am.name AS module_name, am.type,
              s.class_name, s.section,
              COUNT(*) AS total_records,
              SUM(CASE WHEN ar.status='present' THEN 1 ELSE 0 END) AS present_count,
              SUM(CASE WHEN ar.status='absent'  THEN 1 ELSE 0 END) AS absent_count,
              SUM(CASE WHEN ar.status='late'    THEN 1 ELSE 0 END) AS late_count
       FROM attendance_records ar
       JOIN attendance_modules am ON am.id = ar.module_id
       JOIN students s ON s.id = ar.student_id
       WHERE ${where.join(' AND ')}
       GROUP BY am.id, am.name, am.type, s.class_name, s.section
       ORDER BY am.type, am.name, s.class_name, s.section`,
      params
    );

    // Add percentage
    const data = rows.map(r => ({
      ...r,
      percentage: r.total_records > 0
        ? Math.round((r.present_count / r.total_records) * 100) : null,
    }));

    res.json({ success: true, data, from_date: fromDate, to_date: toDate });
  } catch (err) { next(err); }
});

module.exports = router;
