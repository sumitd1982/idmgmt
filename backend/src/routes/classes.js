// ============================================================
// Classes & Per-Section Teacher Assignment
// ============================================================
const router = require('express').Router();
const { v4: uuid } = require('uuid');
const { query, transaction } = require('../models/db');
const { authenticate, requireRole } = require('../middleware/auth');
const logger = require('../utils/logger');

// ── GET /classes ──────────────────────────────────────────────
router.get('/', authenticate, async (req, res, next) => {
  try {
    const { school_id, branch_id } = req.query;

    const effectiveSchoolId = req.user.role === 'super_admin'
      ? (school_id || req.employee?.school_id)
      : (req.employee?.school_id || (req.user.role === 'school_owner' ? req.user.school_id : null));

    if (!effectiveSchoolId) return res.json({ success: true, data: [] });

    let where = ['c.is_active = TRUE', 'b.school_id = ?'];
    const params = [effectiveSchoolId];
    if (branch_id) { where.push('c.branch_id = ?'); params.push(branch_id); }

    const classes = await query(
      `SELECT c.*,
              b.name AS branch_name,
              (SELECT COUNT(*) FROM class_sections cs WHERE cs.class_id = c.id AND cs.is_active = TRUE) AS section_count,
              (SELECT COUNT(*) FROM students s
               WHERE s.class_name = c.name AND s.branch_id = c.branch_id
                 AND s.is_active = TRUE AND s.is_current = TRUE) AS student_count
       FROM classes c
       JOIN branches b ON b.id = c.branch_id
       WHERE ${where.join(' AND ')}
       ORDER BY c.numeric_level, c.name`,
      params
    );

    // Attach sections with teacher info
    for (const cls of classes) {
      cls.sections_detail = await query(
        `SELECT cs.section, cs.class_teacher_id,
                CONCAT(e.first_name,' ',e.last_name) AS teacher_name,
                e.photo_url AS teacher_photo, e.employee_id AS teacher_emp_id
         FROM class_sections cs
         LEFT JOIN employees e ON e.id = cs.class_teacher_id
         WHERE cs.class_id = ? AND cs.is_active = TRUE
         ORDER BY cs.section`,
        [cls.id]
      );
    }

    res.json({ success: true, data: classes });
  } catch (err) { next(err); }
});

// ── GET /classes/sections/all — flat class_section lookup ─────
router.get('/sections/all', authenticate, async (req, res, next) => {
  try {
    const { school_id, branch_id } = req.query;
    const effectiveSchoolId = req.user.role === 'super_admin'
      ? (school_id || req.employee?.school_id)
      : (req.employee?.school_id || (req.user.role === 'school_owner' ? req.user.school_id : null));
    if (!effectiveSchoolId) return res.json({ success: true, data: [] });

    let where = ['cs.is_active = TRUE', 'cs.school_id = ?'];
    const params = [effectiveSchoolId];
    if (branch_id) { where.push('cs.branch_id = ?'); params.push(branch_id); }

    const rows = await query(
      `SELECT cs.id, cs.class_id, cs.class_name, cs.section, cs.class_section,
              cs.branch_id, cs.school_id, cs.class_teacher_id, b.name AS branch_name
       FROM class_sections cs
       LEFT JOIN branches b ON b.id = cs.branch_id
       WHERE ${where.join(' AND ')}
       ORDER BY cs.branch_id,
                CAST(REGEXP_REPLACE(COALESCE(cs.class_name,'0'),'[^0-9]','') AS UNSIGNED),
                cs.class_name, cs.section`,
      params
    );
    res.json({ success: true, data: rows });
  } catch (err) { next(err); }
});

// ── POST /classes/sections — add a class+section row ──────────
router.post('/sections', authenticate, requireRole('super_admin','principal','vp','head_teacher'), async (req, res, next) => {
  try {
    const { branch_id, class_name, section } = req.body;
    if (!branch_id || !class_name || !section) {
      return res.status(400).json({ success: false, message: 'branch_id, class_name and section are required' });
    }
    const [branch] = await query('SELECT school_id FROM branches WHERE id = ?', [branch_id]);
    if (!branch) return res.status(404).json({ success: false, message: 'Branch not found' });

    let [cls] = await query('SELECT id FROM classes WHERE branch_id = ? AND name = ?', [branch_id, class_name]);
    if (!cls) {
      const classId = uuid();
      const numLevel = parseInt(class_name, 10) || null;
      await query(
        `INSERT INTO classes (id, branch_id, name, numeric_level, sections) VALUES (?, ?, ?, ?, ?)`,
        [classId, branch_id, class_name, numLevel, JSON.stringify([section])]
      );
      cls = { id: classId };
    } else {
      await query(
        `UPDATE classes SET sections = JSON_ARRAY_APPEND(
           CASE WHEN JSON_VALID(sections) THEN sections ELSE '[]' END, '$', ?)
         WHERE id = ? AND NOT JSON_CONTAINS(sections, JSON_QUOTE(?))`,
        [section, cls.id, section]
      );
    }

    await query(
      `INSERT IGNORE INTO class_sections (id, class_id, section, class_name, branch_id, school_id)
       VALUES (?, ?, ?, ?, ?, ?)`,
      [uuid(), cls.id, section, class_name, branch_id, branch.school_id]
    );

    const [created] = await query(
      `SELECT cs.*, b.name AS branch_name FROM class_sections cs
       LEFT JOIN branches b ON b.id = cs.branch_id
       WHERE cs.class_id = ? AND cs.section = ?`,
      [cls.id, section]
    );
    res.status(201).json({ success: true, data: created });
  } catch (err) { next(err); }
});

// ── DELETE /classes/sections/:id ──────────────────────────────
router.delete('/sections/:id', authenticate, requireRole('super_admin','principal','vp','head_teacher'), async (req, res, next) => {
  try {
    const [cs] = await query('SELECT * FROM class_sections WHERE id = ?', [req.params.id]);
    if (!cs) return res.status(404).json({ success: false, message: 'Section not found' });

    await query('UPDATE class_sections SET is_active = FALSE WHERE id = ?', [req.params.id]);
    await query(
      `UPDATE classes SET sections = (
         SELECT JSON_ARRAYAGG(section) FROM class_sections WHERE class_id = ? AND is_active = TRUE
       ) WHERE id = ?`,
      [cs.class_id, cs.class_id]
    );
    res.json({ success: true, message: 'Section removed' });
  } catch (err) { next(err); }
});

// ── GET /classes/:id ──────────────────────────────────────────
router.get('/:id', authenticate, async (req, res, next) => {
  try {
    const [cls] = await query(
      `SELECT c.*, b.name AS branch_name, b.school_id
       FROM classes c JOIN branches b ON b.id = c.branch_id
       WHERE c.id = ? AND c.is_active = TRUE`,
      [req.params.id]
    );
    if (!cls) return res.status(404).json({ success: false, message: 'Class not found' });

    const sections = await query(
      `SELECT cs.id, cs.section, cs.class_teacher_id,
              CONCAT(e.first_name,' ',e.last_name) AS teacher_name,
              e.photo_url AS teacher_photo, e.employee_id AS teacher_emp_id,
              r.name AS teacher_role
       FROM class_sections cs
       LEFT JOIN employees e  ON e.id  = cs.class_teacher_id
       LEFT JOIN org_roles r  ON r.id  = e.org_role_id
       WHERE cs.class_id = ? AND cs.is_active = TRUE
       ORDER BY cs.section`,
      [req.params.id]
    );

    res.json({ success: true, data: { ...cls, sections_detail: sections } });
  } catch (err) { next(err); }
});

// ── POST /classes ─────────────────────────────────────────────
router.post('/', authenticate, requireRole('super_admin', 'principal', 'vp'), async (req, res, next) => {
  try {
    const { branch_id, name, numeric_level, sections = [] } = req.body;
    if (!branch_id || !name) {
      return res.status(400).json({ success: false, message: 'branch_id and name are required' });
    }

    const id = uuid();
    const sectionsJson = JSON.stringify(sections);

    await transaction(async (conn) => {
      await conn.query(
        `INSERT INTO classes (id, branch_id, name, numeric_level, sections)
         VALUES (?, ?, ?, ?, ?)`,
        [id, branch_id, name, numeric_level || null, sectionsJson]
      );

      for (const sec of sections) {
        await conn.query(
          `INSERT IGNORE INTO class_sections (id, class_id, section) VALUES (?, ?, ?)`,
          [uuid(), id, sec]
        );
      }
    });

    const [created] = await query(
      `SELECT c.*, b.name AS branch_name FROM classes c JOIN branches b ON b.id = c.branch_id WHERE c.id = ?`,
      [id]
    );
    logger.info(`Class created: ${id} — ${name}`);
    res.status(201).json({ success: true, data: created });
  } catch (err) { next(err); }
});

// ── PUT /classes/:id ──────────────────────────────────────────
router.put('/:id', authenticate, requireRole('super_admin', 'principal', 'vp'), async (req, res, next) => {
  try {
    const [existing] = await query('SELECT * FROM classes WHERE id = ? AND is_active = TRUE', [req.params.id]);
    if (!existing) return res.status(404).json({ success: false, message: 'Class not found' });

    const { name, numeric_level, sections } = req.body;

    await transaction(async (conn) => {
      await conn.query(
        `UPDATE classes SET
           name          = COALESCE(?, name),
           numeric_level = COALESCE(?, numeric_level),
           sections      = COALESCE(?, sections)
         WHERE id = ?`,
        [name || null, numeric_level !== undefined ? numeric_level : null,
         sections ? JSON.stringify(sections) : null, req.params.id]
      );

      // Sync class_sections for any new sections added
      if (Array.isArray(sections)) {
        for (const sec of sections) {
          await conn.query(
            `INSERT IGNORE INTO class_sections (id, class_id, section) VALUES (?, ?, ?)`,
            [uuid(), req.params.id, sec]
          );
        }
      }
    });

    const [updated] = await query(
      `SELECT c.*, b.name AS branch_name FROM classes c JOIN branches b ON b.id = c.branch_id WHERE c.id = ?`,
      [req.params.id]
    );
    res.json({ success: true, data: updated });
  } catch (err) { next(err); }
});

// ── DELETE /classes/:id ───────────────────────────────────────
router.delete('/:id', authenticate, requireRole('super_admin', 'principal', 'vp'), async (req, res, next) => {
  try {
    await query('UPDATE classes SET is_active = FALSE WHERE id = ?', [req.params.id]);
    res.json({ success: true, message: 'Class deactivated' });
  } catch (err) { next(err); }
});

// ── GET /classes/:id/sections ─────────────────────────────────
router.get('/:id/sections', authenticate, async (req, res, next) => {
  try {
    const sections = await query(
      `SELECT cs.id, cs.section, cs.class_teacher_id, cs.is_active,
              CONCAT(e.first_name,' ',e.last_name) AS teacher_name,
              e.photo_url AS teacher_photo,
              e.employee_id AS teacher_emp_id,
              r.name AS teacher_role,
              (SELECT COUNT(*) FROM students s
               WHERE s.class_name = (SELECT name FROM classes WHERE id = cs.class_id)
                 AND s.section = cs.section
                 AND s.branch_id = (SELECT branch_id FROM classes WHERE id = cs.class_id)
                 AND s.is_active = TRUE AND s.is_current = TRUE) AS student_count
       FROM class_sections cs
       LEFT JOIN employees e ON e.id  = cs.class_teacher_id
       LEFT JOIN org_roles r  ON r.id = e.org_role_id
       WHERE cs.class_id = ?
       ORDER BY cs.section`,
      [req.params.id]
    );
    res.json({ success: true, data: sections });
  } catch (err) { next(err); }
});

// ── PUT /classes/:id/sections/:section/teacher ────────────────
// Assign or unassign a class teacher for a specific section.
// Body: { employee_id: "<uuid>" }  or  { employee_id: null }  to unassign
router.put('/:id/sections/:section/teacher',
  authenticate,
  requireRole('super_admin', 'principal', 'vp', 'head_teacher'),
  async (req, res, next) => {
    try {
      const { employee_id } = req.body;

      // Upsert class_section row
      const [existing] = await query(
        'SELECT id FROM class_sections WHERE class_id = ? AND section = ?',
        [req.params.id, req.params.section]
      );

      if (existing) {
        await query(
          'UPDATE class_sections SET class_teacher_id = ?, updated_at = NOW() WHERE class_id = ? AND section = ?',
          [employee_id || null, req.params.id, req.params.section]
        );
      } else {
        await query(
          'INSERT INTO class_sections (id, class_id, section, class_teacher_id) VALUES (?, ?, ?, ?)',
          [uuid(), req.params.id, req.params.section, employee_id || null]
        );
      }

      // Also sync the sections JSON in the classes table if this is a new section
      if (!existing) {
        await query(
          `UPDATE classes
           SET sections = JSON_ARRAY_APPEND(
               CASE WHEN JSON_VALID(sections) THEN sections ELSE '[]' END,
               '$', ?
           )
           WHERE id = ? AND NOT JSON_CONTAINS(sections, JSON_QUOTE(?))`,
          [req.params.section, req.params.id, req.params.section]
        );
      }

      const teacherName = employee_id
        ? (await query('SELECT CONCAT(first_name," ",last_name) AS name FROM employees WHERE id = ?', [employee_id]))[0]?.name
        : null;

      logger.info(`Class ${req.params.id} section ${req.params.section} teacher → ${employee_id || 'unassigned'}`);
      res.json({
        success: true,
        message: employee_id ? `Teacher assigned to ${req.params.section}` : `Teacher unassigned from ${req.params.section}`,
        data: { class_id: req.params.id, section: req.params.section, employee_id: employee_id || null, teacher_name: teacherName }
      });
    } catch (err) { next(err); }
  }
);

module.exports = router;
