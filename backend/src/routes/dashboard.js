const router = require('express').Router();
const { query } = require('../models/db');
const { authenticate } = require('../middleware/auth');

// GET /dashboard/stats
// super_admin  → aggregate totals across all schools
// employee     → stats for their school only
// viewer (no employee, new user) → all zeros
router.get('/stats', authenticate, async (req, res, next) => {
  try {
    if (req.user.role === 'super_admin') {
      const [stats] = await query(
        `SELECT
           (SELECT COUNT(*) FROM schools   WHERE is_active = 1) AS schools,
           (SELECT COUNT(*) FROM branches  WHERE is_active = 1) AS branches,
           (SELECT COUNT(*) FROM employees WHERE is_active = 1) AS employees,
           (SELECT COUNT(*) FROM students  WHERE is_active = 1) AS students,
           (SELECT COUNT(*) FROM students  WHERE status_color = 'green') AS students_approved,
           (SELECT COUNT(*) FROM students  WHERE status_color = 'blue')  AS students_changed,
           (SELECT COUNT(*) FROM students  WHERE status_color = 'red')   AS students_pending`
      );
      return res.json({ success: true, data: stats });
    }

    if (!req.employee) {
      // New user — not assigned to any school yet
      return res.json({
        success: true,
        data: {
          schools: 0, branches: 0, employees: 0,
          students: 0, students_approved: 0, students_changed: 0, students_pending: 0
        }
      });
    }

    const schoolId = req.employee.school_id;
    const [stats] = await query(
      `SELECT
         1 AS schools,
         (SELECT COUNT(*) FROM branches  WHERE school_id = ? AND is_active = 1) AS branches,
         (SELECT COUNT(*) FROM employees WHERE school_id = ? AND is_active = 1) AS employees,
         (SELECT COUNT(*) FROM students  WHERE school_id = ? AND is_active = 1) AS students,
         (SELECT COUNT(*) FROM students  WHERE school_id = ? AND status_color = 'green') AS students_approved,
         (SELECT COUNT(*) FROM students  WHERE school_id = ? AND status_color = 'blue')  AS students_changed,
         (SELECT COUNT(*) FROM students  WHERE school_id = ? AND status_color = 'red')   AS students_pending`,
      Array(6).fill(schoolId)
    );
    res.json({ success: true, data: stats });
  } catch (err) { next(err); }
});

module.exports = router;
