const router = require('express').Router();
const { query } = require('../models/db');
const { authenticate } = require('../middleware/auth');

// ─────────────────────────────────────────────────────────────
// Scope helper
// role_level from org_roles:
//   1 = Principal, 2 = VP  → school scope
//   3–5 = Head/Senior/Class Teacher → branch scope
//   6+  = Subject/Backup/Temp/Asst   → teacher scope
// ─────────────────────────────────────────────────────────────
function deriveScope(req) {
  const role    = req.user?.role;
  if (role === 'parent')      return 'parent';
  if (role === 'super_admin') return 'school';

  const level    = req.employee?.role_level ?? 99;
  const branchId = req.employee?.branch_id;

  if (!branchId || level <= 2) return 'school';
  if (level <= 5)              return 'branch';
  return 'teacher';
}

// ─────────────────────────────────────────────────────────────
// GET /dashboard/stats
// ─────────────────────────────────────────────────────────────
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

    const schoolId = req.employee?.school_id || req.user.school_id;

    if (!schoolId) {
      return res.json({
        success: true,
        data: {
          schools: 0, branches: 0, employees: 0,
          students: 0, students_approved: 0, students_changed: 0, students_pending: 0
        }
      });
    }
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

// ─────────────────────────────────────────────────────────────
// GET /dashboard/overview
// Role-scoped: school / branch / teacher / parent
// ─────────────────────────────────────────────────────────────
router.get('/overview', authenticate, async (req, res, next) => {
  try {
    const scope    = deriveScope(req);
    const empId    = req.employee?.id;
    const branchId = req.employee?.branch_id;
    const schoolId = req.employee?.school_id || req.user?.school_id;

    // Fetch school-level show_teacher_names setting
    let showTeacherNames = true;
    if (schoolId) {
      const [sch] = await query(
        `SELECT dashboard_show_teacher_names FROM schools WHERE id = ?`, [schoolId]
      );
      if (sch) showTeacherNames = !!sch.dashboard_show_teacher_names;
    }

    // Section SQL — per branch
    const SECTION_SQL = `
      SELECT cs.class_name, cs.section, cs.class_teacher_id,
             CONCAT(e.first_name,' ',IFNULL(e.last_name,'')) AS teacher_name,
             e.photo_url AS teacher_photo,
             (SELECT COUNT(*) FROM students s
              WHERE s.class_name = cs.class_name AND s.section = cs.section
                AND s.branch_id = cs.branch_id AND s.is_active = TRUE) AS student_count
      FROM class_sections cs
      LEFT JOIN employees e ON e.id = cs.class_teacher_id AND e.is_active = TRUE
      WHERE cs.branch_id = ? AND cs.is_active = TRUE
      ORDER BY CAST(REGEXP_REPLACE(COALESCE(cs.class_name,'0'),'[^0-9]','') AS UNSIGNED),
               cs.class_name, cs.section`;

    // ── School scope ──────────────────────────────────────────
    if (scope === 'school') {
      const branches = await query(
        `SELECT b.id, b.name,
                (SELECT COUNT(*) FROM employees emp WHERE emp.branch_id = b.id AND emp.is_active = TRUE) AS emp_count
         FROM branches b
         WHERE b.school_id = ? AND b.is_active = TRUE
         ORDER BY b.name`,
        [schoolId]
      );

      let totalStudents = 0, totalEmployees = 0;
      const branchData = await Promise.all(branches.map(async (b) => {
        const sections = await query(SECTION_SQL, [b.id]);
        const branchStudents = sections.reduce((s, r) => s + (parseInt(r.student_count) || 0), 0);
        const branchEmployees = parseInt(b.emp_count) || 0;
        totalStudents  += branchStudents;
        totalEmployees += branchEmployees;
        return {
          id:   b.id,
          name: b.name,
          totals: { students: branchStudents, employees: branchEmployees },
          sections: sections.map(s => ({
            class_name:       s.class_name,
            section:          s.section,
            student_count:    parseInt(s.student_count) || 0,
            teacher_name:     s.teacher_name || null,
            teacher_photo:    s.teacher_photo || null,
            class_teacher_id: s.class_teacher_id || null,
          })),
        };
      }));

      return res.json({
        success: true,
        data: {
          scope: 'school',
          show_teacher_names: showTeacherNames,
          totals: { students: totalStudents, employees: totalEmployees, branches: branches.length },
          branches: branchData,
        },
      });
    }

    // ── Branch scope ──────────────────────────────────────────
    if (scope === 'branch') {
      const sections = await query(SECTION_SQL, [branchId]);
      const branchStudents  = sections.reduce((s, r) => s + (parseInt(r.student_count) || 0), 0);
      const [branchRow] = await query(
        `SELECT b.id, b.name,
                (SELECT COUNT(*) FROM employees emp WHERE emp.branch_id = b.id AND emp.is_active = TRUE) AS emp_count
         FROM branches b WHERE b.id = ?`, [branchId]
      );
      const branchEmployees = parseInt(branchRow?.emp_count) || 0;

      return res.json({
        success: true,
        data: {
          scope: 'branch',
          show_teacher_names: showTeacherNames,
          totals: { students: branchStudents, employees: branchEmployees, branches: 1 },
          branch: branchRow ? { id: branchRow.id, name: branchRow.name } : null,
          sections: sections.map(s => ({
            class_name:       s.class_name,
            section:          s.section,
            student_count:    parseInt(s.student_count) || 0,
            teacher_name:     s.teacher_name || null,
            teacher_photo:    s.teacher_photo || null,
            class_teacher_id: s.class_teacher_id || null,
          })),
        },
      });
    }

    // ── Teacher scope ─────────────────────────────────────────
    if (scope === 'teacher') {
      const rows = await query(
        `SELECT cs.class_name, cs.section, cs.class_teacher_id,
                CONCAT(e.first_name,' ',IFNULL(e.last_name,'')) AS teacher_name,
                e.photo_url AS teacher_photo,
                b.id AS branch_id, b.name AS branch_name,
                (SELECT COUNT(*) FROM students s
                 WHERE s.class_name = cs.class_name AND s.section = cs.section
                   AND s.branch_id = cs.branch_id AND s.is_active = TRUE) AS student_count
         FROM class_sections cs
         LEFT JOIN employees e ON e.id = cs.class_teacher_id AND e.is_active = TRUE
         LEFT JOIN branches b  ON b.id  = cs.branch_id
         WHERE cs.is_active = TRUE
           AND (cs.class_teacher_id = ?
             OR cs.class_teacher_id IN (
               SELECT id FROM employees WHERE reports_to_emp_id = ?
             ))
         ORDER BY b.name,
                  CAST(REGEXP_REPLACE(COALESCE(cs.class_name,'0'),'[^0-9]','') AS UNSIGNED),
                  cs.class_name, cs.section`,
        [empId, empId]
      );

      return res.json({
        success: true,
        data: {
          scope: 'teacher',
          show_teacher_names: showTeacherNames,
          totals: {
            students:  rows.reduce((s, r) => s + (parseInt(r.student_count) || 0), 0),
            employees: 0,
            branches:  0,
          },
          sections: rows.map(s => ({
            class_name:       s.class_name,
            section:          s.section,
            student_count:    parseInt(s.student_count) || 0,
            teacher_name:     s.teacher_name || null,
            teacher_photo:    s.teacher_photo || null,
            class_teacher_id: s.class_teacher_id || null,
            branch_name:      s.branch_name || null,
          })),
        },
      });
    }

    // ── Parent scope ──────────────────────────────────────────
    const userId = req.user.id;
    const phone  = req.user.phone;

    // Link via guardians (by user_id first, then by phone)
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

    const children = studentIds.length
      ? await query(
          `SELECT s.id, s.first_name, s.last_name, s.class_name, s.section, s.branch_id,
                  b.name AS branch_name
           FROM students s
           LEFT JOIN branches b ON b.id = s.branch_id
           WHERE s.id IN (${studentIds.map(() => '?').join(',')}) AND s.is_active = TRUE`,
          studentIds
        )
      : [];

    return res.json({
      success: true,
      data: {
        scope: 'parent',
        show_teacher_names: false,
        totals: { students: children.length, employees: 0, branches: 0 },
        children: children.map(c => ({
          id:          c.id,
          first_name:  c.first_name,
          last_name:   c.last_name,
          class_name:  c.class_name,
          section:     c.section,
          branch_name: c.branch_name,
        })),
      },
    });
  } catch (err) { next(err); }
});

// ─────────────────────────────────────────────────────────────
// GET /dashboard/workflow-overview
// ─────────────────────────────────────────────────────────────
router.get('/workflow-overview', authenticate, async (req, res, next) => {
  try {
    const scope    = deriveScope(req);
    const empId    = req.employee?.id;
    const branchId = req.employee?.branch_id;
    const schoolId = req.employee?.school_id || req.user?.school_id;
    const userId   = req.user?.id;
    const phone    = req.user?.phone;

    // Build workflow request filter
    let wrWhere  = ['wr.school_id = ?'];
    let wrParams = [schoolId];

    if (scope === 'teacher' && empId) {
      wrWhere.push(
        `(wr.requested_by = ?
          OR EXISTS (
            SELECT 1 FROM workflow_request_assignments wra
            WHERE wra.request_id = wr.id AND wra.teacher_id = ?
          ))`
      );
      wrParams.push(empId, empId);
    }

    if (scope === 'parent') {
      // Get parent's student IDs
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

      if (!studentIds.length) {
        return res.json({ success: true, data: { scope: 'parent', requests: [] } });
      }

      const placeholders = studentIds.map(() => '?').join(',');
      wrWhere = [
        `wr.school_id IS NOT NULL`,  // no-op, real filter below
        `EXISTS (
           SELECT 1 FROM workflow_request_items wri2
           WHERE wri2.request_id = wr.id
             AND wri2.student_id IN (${placeholders})
         )`,
      ];
      wrParams = [...studentIds];

      const requests = await query(
        `SELECT wr.id, wr.title, wr.request_type, wr.status
         FROM workflow_requests wr
         WHERE ${wrWhere.join(' AND ')}
         ORDER BY wr.created_at DESC`,
        wrParams
      );

      const requestStats = await Promise.all(requests.map(async (wr) => {
        const rows = await query(
          `SELECT wri.student_id,
                  CONCAT(s.first_name,' ',IFNULL(s.last_name,'')) AS student_name,
                  wri.status
           FROM workflow_request_items wri
           JOIN students s ON s.id = wri.student_id
           WHERE wri.request_id = ? AND wri.student_id IN (${placeholders})`,
          [wr.id, ...studentIds]
        );

        const sumCounts = rows.reduce(
          (acc, r) => ({
            total:         acc.total + 1,
            not_started:   acc.not_started   + (r.status === 'pending' ? 1 : 0),
            not_responded: acc.not_responded + (r.status === 'sent_to_parent' ? 1 : 0),
            in_progress:   acc.in_progress   + (['teacher_under_review','parent_submitted','resubmit_requested'].includes(r.status) ? 1 : 0),
            completed:     acc.completed     + (['approved','rejected'].includes(r.status) ? 1 : 0),
          }),
          { total: 0, not_started: 0, not_responded: 0, in_progress: 0, completed: 0 }
        );

        return {
          id: wr.id, title: wr.title, request_type: wr.request_type, status: wr.status,
          totals: sumCounts,
          children: rows.map(r => ({
            student_id:   r.student_id,
            student_name: r.student_name,
            status:       r.status,
          })),
        };
      }));

      return res.json({ success: true, data: { scope: 'parent', requests: requestStats } });
    }

    const requests = await query(
      `SELECT wr.id, wr.title, wr.request_type, wr.status
       FROM workflow_requests wr
       WHERE ${wrWhere.join(' AND ')}
       ORDER BY wr.created_at DESC`,
      wrParams
    );

    const SECTION_STATS_SQL = `
      SELECT wri.class_name, wri.section,
             b.id AS branch_id, b.name AS branch_name,
             ANY_VALUE(cs.class_teacher_id) AS class_teacher_id,
             CONCAT(ANY_VALUE(e.first_name),' ',IFNULL(ANY_VALUE(e.last_name),'')) AS teacher_name,
             COUNT(*) AS total,
             SUM(wri.status='pending')  AS not_started,
             SUM(wri.status='sent_to_parent') AS not_responded,
             SUM(wri.status IN ('teacher_under_review','parent_submitted','resubmit_requested')) AS in_progress,
             SUM(wri.status IN ('approved','rejected')) AS completed
      FROM workflow_request_items wri
      JOIN students stu ON stu.id = wri.student_id
      JOIN branches b   ON b.id   = stu.branch_id
      LEFT JOIN class_sections cs
             ON cs.class_name = wri.class_name AND cs.section = wri.section AND cs.branch_id = stu.branch_id
      LEFT JOIN employees e ON e.id = cs.class_teacher_id
      WHERE wri.request_id = ?`;

    const sumCounts = rows => rows.reduce(
      (acc, r) => ({
        total:         acc.total         + (parseInt(r.total)         || 0),
        not_started:   acc.not_started   + (parseInt(r.not_started)   || 0),
        not_responded: acc.not_responded + (parseInt(r.not_responded) || 0),
        in_progress:   acc.in_progress   + (parseInt(r.in_progress)   || 0),
        completed:     acc.completed     + (parseInt(r.completed)     || 0),
      }),
      { total: 0, not_started: 0, not_responded: 0, in_progress: 0, completed: 0 }
    );

    const requestStats = await Promise.all(requests.map(async (wr) => {
      if (scope === 'school') {
        const rows = await query(
          SECTION_STATS_SQL +
          ` GROUP BY wri.class_name, wri.section, b.id
            ORDER BY b.name,
                     CAST(REGEXP_REPLACE(COALESCE(wri.class_name,'0'),'[^0-9]','') AS UNSIGNED),
                     wri.class_name, wri.section`,
          [wr.id]
        );

        const branchMap = {};
        for (const r of rows) {
          if (!branchMap[r.branch_id]) {
            branchMap[r.branch_id] = { id: r.branch_id, name: r.branch_name, rows: [] };
          }
          branchMap[r.branch_id].rows.push(r);
        }

        const branches = Object.values(branchMap).map(b => ({
          id:   b.id,
          name: b.name,
          totals: sumCounts(b.rows),
          sections: b.rows.map(r => ({
            class_name:    r.class_name,
            section:       r.section,
            teacher_name:  r.teacher_name || null,
            total:         parseInt(r.total)         || 0,
            not_started:   parseInt(r.not_started)   || 0,
            not_responded: parseInt(r.not_responded) || 0,
            in_progress:   parseInt(r.in_progress)   || 0,
            completed:     parseInt(r.completed)     || 0,
          })),
        }));

        return {
          id: wr.id, title: wr.title, request_type: wr.request_type, status: wr.status,
          totals: sumCounts(rows),
          branches,
        };
      }

      if (scope === 'branch') {
        const rows = await query(
          SECTION_STATS_SQL +
          ` AND stu.branch_id = ?
            GROUP BY wri.class_name, wri.section, b.id
            ORDER BY CAST(REGEXP_REPLACE(COALESCE(wri.class_name,'0'),'[^0-9]','') AS UNSIGNED),
                     wri.class_name, wri.section`,
          [wr.id, branchId]
        );

        return {
          id: wr.id, title: wr.title, request_type: wr.request_type, status: wr.status,
          totals: sumCounts(rows),
          sections: rows.map(r => ({
            class_name:    r.class_name,
            section:       r.section,
            teacher_name:  r.teacher_name || null,
            total:         parseInt(r.total)         || 0,
            not_started:   parseInt(r.not_started)   || 0,
            not_responded: parseInt(r.not_responded) || 0,
            in_progress:   parseInt(r.in_progress)   || 0,
            completed:     parseInt(r.completed)     || 0,
          })),
        };
      }

      // Teacher scope
      const rows = await query(
        SECTION_STATS_SQL +
        ` AND (cs.class_teacher_id = ?
             OR cs.class_teacher_id IN (SELECT id FROM employees WHERE reports_to_emp_id = ?))
          GROUP BY wri.class_name, wri.section, b.id
          ORDER BY b.name,
                   CAST(REGEXP_REPLACE(COALESCE(wri.class_name,'0'),'[^0-9]','') AS UNSIGNED),
                   wri.class_name, wri.section`,
        [wr.id, empId, empId]
      );

      return {
        id: wr.id, title: wr.title, request_type: wr.request_type, status: wr.status,
        totals: sumCounts(rows),
        sections: rows.map(r => ({
          class_name:    r.class_name,
          section:       r.section,
          teacher_name:  r.teacher_name || null,
          total:         parseInt(r.total)         || 0,
          not_started:   parseInt(r.not_started)   || 0,
          not_responded: parseInt(r.not_responded) || 0,
          in_progress:   parseInt(r.in_progress)   || 0,
          completed:     parseInt(r.completed)     || 0,
        })),
      };
    }));

    return res.json({
      success: true,
      data: { scope, requests: requestStats },
    });
  } catch (err) { next(err); }
});

// ─────────────────────────────────────────────────────────────
// PATCH /dashboard/settings  — Toggle show_teacher_names
// School owner/principal/VP only
// ─────────────────────────────────────────────────────────────
router.patch('/settings', authenticate, async (req, res, next) => {
  try {
    const schoolId = req.employee?.school_id || req.user?.school_id;
    if (!schoolId) return res.status(403).json({ success: false, message: 'No school context' });

    const level = req.employee?.role_level ?? 99;
    if (req.user.role !== 'super_admin' && level > 3) {
      return res.status(403).json({ success: false, message: 'Insufficient permissions' });
    }

    const { show_teacher_names } = req.body;
    if (show_teacher_names !== undefined) {
      await query(
        `UPDATE schools SET dashboard_show_teacher_names = ? WHERE id = ?`,
        [show_teacher_names ? 1 : 0, schoolId]
      );
    }

    const [sch] = await query(
      `SELECT dashboard_show_teacher_names FROM schools WHERE id = ?`, [schoolId]
    );
    res.json({ success: true, data: { show_teacher_names: !!sch?.dashboard_show_teacher_names } });
  } catch (err) { next(err); }
});

module.exports = router;
