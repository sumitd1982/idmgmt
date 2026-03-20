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
    const schoolId = req.employee?.school_id || req.query.school_id;
    if (!schoolId) return res.status(403).json({ success: false, message: 'No school context' });

    const modules = await query(
      `SELECT id, name, type, is_active, created_at
       FROM attendance_modules
       WHERE school_id = ?
       ORDER BY type, name`,
      [schoolId]
    );

    res.json({ success: true, data: modules });
  } catch (err) { next(err); }
});

// POST /attendance/modules (Create new module)
router.post('/modules', authenticate, requireRole('super_admin', 'principal', 'vp'), async (req, res, next) => {
  try {
    const schoolId = req.employee?.school_id || req.body.school_id;
    const { name, type, is_active = true } = req.body;

    if (!name || !type) return res.status(400).json({ success: false, message: 'Name and Type required' });

    const [result] = await query(
      `INSERT INTO attendance_modules (school_id, name, type, is_active)
       VALUES (?, ?, ?, ?)`,
      [schoolId, name, type, is_active]
    );

    res.json({ success: true, message: 'Module created successfully' });
  } catch (err) { next(err); }
});

// PATCH /attendance/modules/:id/toggle (Turn module ON/OFF)
router.patch('/modules/:id/toggle', authenticate, requireRole('super_admin', 'principal', 'vp'), async (req, res, next) => {
  try {
    const schoolId = req.employee?.school_id || req.body.school_id;
    const { is_active } = req.body;

    await query(
      `UPDATE attendance_modules SET is_active = ? WHERE id = ? AND school_id = ?`,
      [is_active, req.params.id, schoolId]
    );
    res.json({ success: true, message: 'Module updated' });
  } catch (err) { next(err); }
});

// ── STUDENT ASSIGNMENT (For Custom Modules) ───────────────────

// GET /attendance/modules/:id/students
router.get('/modules/:id/students', authenticate, async (req, res, next) => {
  try {
    const schoolId = req.employee?.school_id || req.query.school_id;
    
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
router.post('/modules/:id/students', authenticate, requireRole('super_admin', 'principal', 'vp'), async (req, res, next) => {
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

module.exports = router;
