// ============================================================
// Students CRUD + Bulk Upload + Review Status Routes
// ============================================================
const router  = require('express').Router();
const { v4: uuid } = require('uuid');
const multer  = require('multer');
const xlsx    = require('xlsx');
const path    = require('path');
const fs      = require('fs');
const { query, transaction } = require('../models/db');
const { authenticate, requireRole } = require('../middleware/auth');
const logger  = require('../utils/logger');

const upload = multer({
  dest: path.join(__dirname, '../../uploads/temp'),
  limits: { fileSize: 20 * 1024 * 1024 }, // 20MB
  fileFilter: (req, file, cb) => {
    const allowed = ['.xlsx', '.xls', '.csv'];
    const ext = path.extname(file.originalname).toLowerCase();
    cb(null, allowed.includes(ext));
  }
});

// ── GET /students ─────────────────────────────────────────────
router.get('/', authenticate, async (req, res, next) => {
  try {
    const { school_id, branch_id, class_name, section, status_color,
            search, page = 1, limit = 50 } = req.query;
    const offset = (page - 1) * limit;

    let where = ['s.is_active = TRUE'];
    let params = [];

    // Security: Only super_admin/school_owner can override the school context
    const isSchoolScoped = req.user.role === 'super_admin' || req.user.role === 'school_owner';
    const effectiveSchoolId = isSchoolScoped
      ? (school_id || req.employee?.school_id || req.user.school_id)
      : req.employee?.school_id;

    // Non-super_admin with no school context sees nothing
    if (req.user.role !== 'super_admin' && !effectiveSchoolId) {
      return res.json({ success: true, data: [], meta: { total: 0, page: +page, limit: +limit } });
    }

    if (effectiveSchoolId) { where.push('s.school_id = ?'); params.push(effectiveSchoolId); }
    if (branch_id)    { where.push('s.branch_id = ?');  params.push(branch_id); }
    if (class_name)   { where.push('s.class_name = ?'); params.push(class_name); }
    if (section)      { where.push('s.section = ?');    params.push(section); }
    if (status_color) { where.push('s.status_color = ?'); params.push(status_color); }
    if (search) {
      where.push('(s.first_name LIKE ? OR s.last_name LIKE ? OR s.student_id LIKE ?)');
      params.push(`%${search}%`, `%${search}%`, `%${search}%`);
    }

    // ── Teacher visibility filter ──────────────────────────────
    // Level 5+ (Class/Subject/Backup/Temp teachers): only their assigned_classes
    // Level 4  (Senior Teacher): own + all subordinates' assigned_classes
    // Level 1-3 (Principal/VP/Head Teacher): see all students in school
    if (req.employee && !class_name) {
      const level = req.employee.role_level;
      if (level >= 5) {
        const ac = req.employee.assigned_classes;
        const classes = typeof ac === 'string' ? JSON.parse(ac || '[]') : (ac || []);
        if (classes.length > 0) {
          where.push(`s.class_name IN (${classes.map(() => '?').join(',')})`);
          params.push(...classes);
        } else {
          where.push('1=0'); // no assigned classes → see nothing
        }
      } else if (level === 4) {
        // Senior teacher: their own classes + all subordinate teachers' classes
        const ac = req.employee.assigned_classes;
        const ownClasses = typeof ac === 'string' ? JSON.parse(ac || '[]') : (ac || []);
        const subs = await query(
          `WITH RECURSIVE sub AS (
             SELECT id, assigned_classes FROM employees
             WHERE reports_to_emp_id = ? AND is_active = TRUE
             UNION ALL
             SELECT e.id, e.assigned_classes FROM employees e
             INNER JOIN sub s ON e.reports_to_emp_id = s.id
             WHERE e.is_active = TRUE
           ) SELECT assigned_classes FROM sub`,
          [req.employee.id]
        );
        const allClasses = new Set(ownClasses);
        for (const s of subs) {
          const sc = typeof s.assigned_classes === 'string'
            ? JSON.parse(s.assigned_classes || '[]')
            : (s.assigned_classes || []);
          sc.forEach(c => allClasses.add(c));
        }
        if (allClasses.size > 0) {
          where.push(`s.class_name IN (${[...allClasses].map(() => '?').join(',')})`);
          params.push(...allClasses);
        }
      }
      // Level 1-3: no extra filter — sees all students in school
    }

    const students = await query(
      `SELECT s.*,
              b.name AS branch_name,
              g_m.first_name AS mother_first, g_m.last_name AS mother_last,
              g_m.phone AS mother_phone, g_m.whatsapp_no AS mother_whatsapp,
              g_f.first_name AS father_first, g_f.last_name AS father_last,
              g_f.phone AS father_phone
       FROM students s
       JOIN branches b ON b.id = s.branch_id
       LEFT JOIN guardians g_m ON g_m.student_id = s.id AND g_m.guardian_type = 'mother'
       LEFT JOIN guardians g_f ON g_f.student_id = s.id AND g_f.guardian_type = 'father'
       WHERE ${where.join(' AND ')}
       ORDER BY s.class_name, s.section, s.roll_number
       LIMIT ? OFFSET ?`,
      [...params, parseInt(limit), parseInt(offset)]
    );

    const [{ total }] = await query(
      `SELECT COUNT(*) AS total FROM students s WHERE ${where.join(' AND ')}`, params
    );

    res.json({ success: true, data: students, meta: { total, page: +page, limit: +limit } });
  } catch (err) { next(err); }
});

// ── GET /students/:id ─────────────────────────────────────────
router.get('/:id', authenticate, async (req, res, next) => {
  try {
    const [student] = await query(
      `SELECT s.*, b.name AS branch_name, sch.name AS school_name
       FROM students s
       JOIN branches b ON b.id = s.branch_id
       JOIN schools sch ON sch.id = s.school_id
       WHERE s.id = ?`, [req.params.id]
    );
    if (!student) return res.status(404).json({ success: false, message: 'Student not found' });

    // Non-super_admin/school_owner can only view students in their own school
    if (req.user.role !== 'super_admin' && req.user.role !== 'school_owner') {
      if (!req.employee || req.employee.school_id !== student.school_id) {
        return res.status(403).json({ success: false, message: 'Not authorized to view this student' });
      }
    } else if (req.user.role === 'school_owner') {
      if (req.user.school_id !== student.school_id) {
         return res.status(403).json({ success: false, message: 'Not authorized to view this student' });
      }
    }

    const guardians = await query('SELECT * FROM guardians WHERE student_id = ?', [req.params.id]);
    res.json({ success: true, data: { ...student, guardians } });
  } catch (err) { next(err); }
});

// ── POST /students ────────────────────────────────────────────
router.post('/', authenticate, async (req, res, next) => {
  try {
    const { school_id, branch_id, student_id, first_name, last_name, gender, date_of_birth,
            roll_number, class_name, section, admission_no, aadhaar_no, phone,
            email, address_line1, city, state, zip_code, guardians = [] } = req.body;

    // Security: Only super_admin/school_owner can specify a school_id for other schools
    let effectiveSchoolId;
    if (req.user.role === 'super_admin') {
      effectiveSchoolId = school_id || req.employee?.school_id;
    } else if (['school_admin', 'school_owner', 'principal'].includes(req.user.role)) {
      effectiveSchoolId = req.user.role === 'school_owner' ? (req.user.school_id || school_id) : req.employee?.school_id;
      if (school_id && school_id !== effectiveSchoolId) {
        return res.status(403).json({ success: false, message: 'Not authorized to create students in other schools' });
      }
    } else {
      effectiveSchoolId = req.employee?.school_id;
    }

    const effectiveBranchId = branch_id || req.employee?.branch_id;

    if (!effectiveSchoolId || !effectiveBranchId || !first_name || !gender || !class_name || !section) {
      console.error('[Validation Error] POST /students missing fields:', {
        effectiveSchoolId, effectiveBranchId, first_name, gender, class_name, section
      });
      return res.status(422).json({ 
        success: false, 
        message: 'Required fields missing: school_id, branch_id, first_name, gender, class_name, section',
        missing: {
          school_id: !effectiveSchoolId,
          branch_id: !effectiveBranchId,
          first_name: !first_name,
          gender: !gender,
          class_name: !class_name,
          section: !section
        }
      });
    }

    const id = uuid();
    await transaction(async (conn) => {
      await conn.execute(
        `INSERT INTO students (id, school_id, branch_id, student_id, roll_number,
           class_name, section, first_name, last_name, middle_name, date_of_birth, gender,
           blood_group, nationality, religion, category, aadhaar_no, admission_no,
           address_line1, address_line2, city, state, country, zip_code,
           bus_route, bus_stop, bus_number)
         VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)`,
        [id, effectiveSchoolId, effectiveBranchId, student_id, roll_number,
         class_name, section, first_name, last_name, middle_name, date_of_birth, gender,
         blood_group, nationality, religion, category, aadhaar_no, admission_no,
         address_line1, address_line2, city, state, country || 'India', zip_code,
         bus_route, bus_stop, bus_number]
      );

      for (const g of guardians) {
        if (g.guardian_type && (g.first_name || g.phone)) {
          await conn.execute(
            `INSERT INTO guardians (id, student_id, guardian_type, first_name, last_name,
               relation, photo_url, email, phone, whatsapp_no, alt_phone,
               occupation, organization, is_primary, same_as_student)
             VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)`,
            [uuid(), id, g.guardian_type, g.first_name, g.last_name,
             g.relation, g.photo_url, g.email, g.phone, g.whatsapp_no, g.alt_phone,
             g.occupation, g.organization, g.is_primary || false, g.same_as_student ?? true]
          );
        }
      }
    });

    const [student] = await query('SELECT * FROM students WHERE id = ?', [id]);
    const gList = await query('SELECT * FROM guardians WHERE student_id = ?', [id]);
    res.status(201).json({ success: true, data: { ...student, guardians: gList } });
  } catch (err) { next(err); }
});

// ── PUT /students/:id ─────────────────────────────────────────
router.put('/:id', authenticate, async (req, res, next) => {
  try {
    // Non-super_admin/school_owner can only edit students in their own school
    if (req.user.role !== 'super_admin' && req.user.role !== 'school_owner') {
      const [existing] = await query('SELECT school_id FROM students WHERE id = ?', [req.params.id]);
      if (!existing || !req.employee || req.employee.school_id !== existing.school_id) {
        return res.status(403).json({ success: false, message: 'Not authorized to edit this student' });
      }
    } else if (req.user.role === 'school_owner') {
       const [existing] = await query('SELECT school_id FROM students WHERE id = ?', [req.params.id]);
       if (!existing || existing.school_id !== req.user.school_id) {
         return res.status(403).json({ success: false, message: 'Not authorized to edit this student' });
       }
    }
    const allowed = ['roll_number','class_name','section','first_name','last_name','middle_name',
      'date_of_birth','gender','blood_group','nationality','religion','category','aadhaar_no',
      'photo_url','address_line1','address_line2','city','state','country','zip_code',
      'bus_route','bus_stop','bus_number','is_active'];

    const fields = Object.keys(req.body).filter(k => allowed.includes(k));
    if (!fields.length && !Array.isArray(req.body.guardians)) {
      return res.status(400).json({ success: false, message: 'No valid fields' });
    }

    if (fields.length) {
      await query(
        `UPDATE students SET ${fields.map(f => `${f} = ?`).join(', ')} WHERE id = ?`,
        [...fields.map(f => req.body[f]), req.params.id]
      );
    }

    // Update guardians: replace all existing ones
    if (Array.isArray(req.body.guardians)) {
      await query('DELETE FROM guardians WHERE student_id = ?', [req.params.id]);
      for (const g of req.body.guardians) {
        if (g.guardian_type && (g.first_name || g.phone)) {
          await query(
            `INSERT INTO guardians (id, student_id, guardian_type, first_name, last_name,
               email, phone, whatsapp_no, occupation, is_primary, same_as_student)
             VALUES (?,?,?,?,?,?,?,?,?,?,?)`,
            [uuid(), req.params.id, g.guardian_type, g.first_name || '', g.last_name || '',
             g.email || null, g.phone || null, g.whatsapp_no || null, g.occupation || null,
             g.is_primary || false, g.same_as_student ?? true]
          );
        }
      }
    }

    const [student]  = await query('SELECT * FROM students WHERE id = ?', [req.params.id]);
    const guardians  = await query('SELECT * FROM guardians WHERE student_id = ?', [req.params.id]);
    res.json({ success: true, data: { ...student, guardians } });
  } catch (err) { next(err); }
});

// ── DELETE /students/:id (soft delete) ────────────────────────
router.delete('/:id', authenticate, requireRole('super_admin','school_owner','principal','vp','head_teacher'), async (req, res, next) => {
  try {
    await query('UPDATE students SET is_active = FALSE WHERE id = ?', [req.params.id]);
    res.json({ success: true, message: 'Student deactivated' });
  } catch (err) { next(err); }
});

// ── POST /students/bulk-upload ────────────────────────────────
router.post('/bulk-upload', authenticate,
  requireRole('super_admin','principal','vp','head_teacher'),
  upload.single('file'),
  async (req, res, next) => {
    if (!req.file) return res.status(400).json({ success: false, message: 'No file uploaded' });

    const batchId  = uuid();
    const { school_id, branch_id } = req.body;

    try {
      // Record batch
      await query(
        `INSERT INTO bulk_batches (id, school_id, branch_id, type, filename, status, uploaded_by)
         VALUES (?, ?, ?, 'students', ?, 'processing', ?)`,
        [batchId, school_id, branch_id, req.file.originalname, req.user.id]
      );

      const wb   = xlsx.readFile(req.file.path);
      const ws   = wb.Sheets[wb.SheetNames[0]];
      const rows = xlsx.utils.sheet_to_json(ws, { defval: '' });

      const errors  = [];
      const success = [];

      const REQUIRED = ['first_name','last_name','gender','class_name','section','student_id'];

      for (let i = 0; i < rows.length; i++) {
        const row = rows[i];
        const rowNo = i + 2; // header is row 1

        // Validate required
        const missing = REQUIRED.filter(f => !row[f]?.toString().trim());
        if (missing.length) {
          errors.push({ row: rowNo, error: `Missing: ${missing.join(', ')}`, data: row });
          continue;
        }

        // Validate gender
        if (!['male','female','other'].includes(row.gender?.toLowerCase())) {
          errors.push({ row: rowNo, error: 'Invalid gender (male/female/other)', data: row });
          continue;
        }

        // Check duplicate student_id within school
        const [dup] = await query(
          'SELECT id FROM students WHERE school_id = ? AND student_id = ?',
          [school_id, row.student_id]
        );
        if (dup) {
          errors.push({ row: rowNo, error: `Duplicate student_id: ${row.student_id}`, data: row });
          continue;
        }

        try {
          const sid = uuid();
          await query(
            `INSERT INTO students (id, school_id, branch_id, student_id, roll_number,
               class_name, section, first_name, last_name, middle_name, date_of_birth,
               gender, blood_group, nationality, category, aadhaar_no,
               address_line1, city, state, country, zip_code,
               bus_route, bus_stop, bulk_upload_batch)
             VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)`,
            [sid, school_id, branch_id,
             row.student_id?.toString().trim(), row.roll_number?.toString().trim(),
             row.class_name?.toString().trim(), row.section?.toString().trim(),
             row.first_name?.toString().trim(), row.last_name?.toString().trim(),
             row.middle_name?.toString().trim() || null,
             row.date_of_birth || null,
             row.gender?.toLowerCase(), row.blood_group || null,
             row.nationality || 'Indian', row.category || null, row.aadhaar_no || null,
             row.address || null, row.city || null, row.state || null,
             row.country || 'India', row.zip_code || null,
             row.bus_route || null, row.bus_stop || null, batchId]
          );

          // Mother guardian
          if (row.mother_name || row.mother_phone) {
            const nameParts = (row.mother_name || '').split(' ');
            await query(
              `INSERT INTO guardians (id, student_id, guardian_type, first_name, last_name,
                 phone, whatsapp_no, email, is_primary, same_as_student)
               VALUES (?,?,'mother',?,?,?,?,?,TRUE,TRUE)`,
              [uuid(), sid, nameParts[0] || null, nameParts.slice(1).join(' ') || null,
               row.mother_phone || null, row.mother_whatsapp || row.mother_phone || null,
               row.mother_email || null]
            );
          }

          success.push(rowNo);
        } catch (insertErr) {
          errors.push({ row: rowNo, error: insertErr.message, data: row });
        }
      }

      // Clean up temp file
      fs.unlinkSync(req.file.path);

      // Update batch status
      await query(
        `UPDATE bulk_batches SET status='completed', total_rows=?, success_rows=?, failed_rows=?, validation_report=?
         WHERE id=?`,
        [rows.length, success.length, errors.length, JSON.stringify(errors), batchId]
      );

      res.json({
        success: true,
        data: {
          batch_id: batchId,
          total: rows.length,
          imported: success.length,
          failed: errors.length,
          errors: errors.slice(0, 50) // return first 50 errors
        }
      });
    } catch (err) {
      if (req.file) fs.unlink(req.file.path, () => {});
      await query('UPDATE bulk_batches SET status=\'failed\' WHERE id=?', [batchId]);
      next(err);
    }
  }
);

// ── GET /students/bulk-template ───────────────────────────────
router.get('/bulk-template/download', authenticate, async (req, res, next) => {
  try {
    const wb = xlsx.utils.book_new();
    const headers = [
      ['student_id','first_name','last_name','middle_name','gender','date_of_birth','class_name',
       'section','roll_number','blood_group','nationality','religion','category','aadhaar_no',
       'admission_no','address','city','state','zip_code','country','bus_route','bus_stop',
       'mother_name','mother_phone','mother_whatsapp','mother_email',
       'father_name','father_phone','father_email']
    ];
    const ws = xlsx.utils.aoa_to_sheet(headers);
    xlsx.utils.book_append_sheet(wb, ws, 'Students');
    const buf = xlsx.write(wb, { type: 'buffer', bookType: 'xlsx' });
    res.setHeader('Content-Disposition', 'attachment; filename="student_upload_template.xlsx"');
    res.setHeader('Content-Type', 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
    res.send(buf);
  } catch (err) { next(err); }
});

// ── PATCH /students/:id/status ────────────────────────────────
router.patch('/:id/status', authenticate, async (req, res, next) => {
  try {
    // Non-super_admin can only update status for students in their own school
    if (req.user.role !== 'super_admin') {
      const [existing] = await query('SELECT school_id FROM students WHERE id = ?', [req.params.id]);
      if (!existing || !req.employee || req.employee.school_id !== existing.school_id) {
        return res.status(403).json({ success: false, message: 'Not authorized to update this student' });
      }
    }
    const { status_color, review_status } = req.body;
    await query(
      'UPDATE students SET status_color=?, review_status=? WHERE id=?',
      [status_color, review_status, req.params.id]
    );
    res.json({ success: true, message: 'Status updated' });
  } catch (err) { next(err); }
});

module.exports = router;
