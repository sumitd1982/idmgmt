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

// ── BULK UPLOAD ROUTES ────────────────────────────────────────

// GET /students/bulk-template/download  → 100-row sample XLSX
router.get('/bulk-template/download', authenticate, async (req, res, next) => {
  try {
    const wb = xlsx.utils.book_new();

    // Instructions sheet
    const instr = [
      ['STUDENT BULK UPLOAD TEMPLATE'],
      ['Fields marked * are mandatory.'],
      ['Date format: YYYY-MM-DD'],
      ['gender: male | female | other'],
      ['guardian_phone is required.'],
      ['country: defaults to India if blank'],
      [''],
    ];
    const instrWs = xlsx.utils.aoa_to_sheet(instr);
    xlsx.utils.book_append_sheet(wb, instrWs, 'Instructions');

    // Sample data sheet
    const headers = [
      'student_id*', 'first_name*', 'last_name*', 'gender*',
      'date_of_birth*', 'class_name*', 'section*', 'roll_number',
      'blood_group', 'nationality', 'religion', 'category', 'aadhaar_no',
      'address_line1', 'city', 'state', 'country', 'zip_code',
      'bus_route', 'bus_stop',
      'guardian_type*', 'guardian_name*', 'guardian_phone*', 'guardian_email',
      'effective_start_date', 'effective_end_date',
    ];

    const FIRST = ['Aarav','Priya','Rahul','Sunita','Amit','Kavita','Rohit','Neha','Vivaan','Meena'];
    const LAST  = ['Sharma','Verma','Gupta','Singh','Patel','Kumar','Mehta','Joshi','Yadav','Tiwari'];

    const rows = [headers];
    for (let i = 1; i <= 100; i++) {
      const fn = FIRST[i % 10]; const ln = LAST[i % 10];
      const cls = (i % 12) + 1;
      const sec = ['A','B','C'][i % 3];
      rows.push([
        `STU-2026-${String(i).padStart(4,'0')}`, fn, ln, i%2===0?'male':'female',
        `201${(i%5)+2}-0${(i%9)+1}-15`,
        `Class ${cls}`, sec, i,
        ['A+','B+','O+','AB+'][i%4], 'Indian', 'Hindu', 'General', `1234567890${String(i).padStart(2,'0')}`,
        `House ${i}, Sector ${(i%30)+1}`, 'Noida', 'Uttar Pradesh', 'India',
        `201${String((i%900)+100)}`,
        i%2===0 ? 'Route A' : '', i%2===0 ? 'Stop X' : '',
        'father', `${FIRST[(i+1)%10]} ${ln}`, `+9198${String(i).padStart(8,'0')}`,
        `${fn.toLowerCase()}_parent@example.com`,
        '2026-04-01', '2027-03-31',
      ]);
    }
    xlsx.utils.book_append_sheet(wb, xlsx.utils.aoa_to_sheet(rows), 'Students (100 samples)');

    const buf = xlsx.write(wb, { type: 'buffer', bookType: 'xlsx' });
    res.setHeader('Content-Disposition', 'attachment; filename="student_bulk_template.xlsx"');
    res.setHeader('Content-Type', 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
    res.send(buf);
  } catch (err) { next(err); }
});

// POST /students/validate-bulk  → per-row validation (no DB write)
router.post('/validate-bulk', authenticate, upload.single('file'), async (req, res, next) => {
  try {
    if (!req.file) return res.status(400).json({ success: false, message: 'No file uploaded' });

    // Load validation messages from DB
    const dbMsgs = await query('SELECT code, message_en FROM validation_messages WHERE entity IN (?,?)', ['student','general']);
    const msg = {};
    dbMsgs.forEach(r => { msg[r.code] = r.message_en; });
    const m = (code, fallback) => msg[code] || fallback;

    const wb = xlsx.readFile(req.file.path);
    const sheetName = wb.SheetNames.find(n => n !== 'Instructions') || wb.SheetNames[0];
    const rows = xlsx.utils.sheet_to_json(wb.Sheets[sheetName], { defval: '' });

    const effectiveSchoolId = req.employee?.school_id || req.user.school_id;
    const existingIds = new Set(
      (await query('SELECT student_id FROM students WHERE school_id = ?', [effectiveSchoolId]))
        .map(r => r.student_id)
    );

    const phoneRe  = /^[+]?[6-9]\d{9,14}$/;

    const results = rows.map((row, idx) => {
      const errors = []; const warnings = [];
      const stuId    = String(row['student_id*'] || row['student_id'] || '').trim();
      const firstName= String(row['first_name*'] || row['first_name'] || '').trim();
      const lastName = String(row['last_name*']  || row['last_name']  || '').trim();
      const gender   = String(row['gender*']     || row['gender']     || '').trim().toLowerCase();
      const dob      = String(row['date_of_birth*'] || row['date_of_birth'] || '').trim();
      const cls      = String(row['class_name*'] || row['class_name'] || '').trim();
      const sec      = String(row['section*']    || row['section']    || '').trim();
      const gPhone   = String(row['guardian_phone*'] || row['guardian_phone'] || '').trim();

      if (!stuId)                 errors.push(m('ERR_STU_ID_REQUIRED',  'Student ID is required'));
      else if (existingIds.has(stuId)) errors.push(m('ERR_STU_ID_DUPLICATE','Student ID already exists'));

      if (!firstName)             errors.push(m('ERR_FIRST_NAME_REQUIRED','First name is required'));
      if (!cls)                   errors.push(m('ERR_CLASS_REQUIRED',   'Class name is required'));
      if (!sec)                   errors.push(m('ERR_SECTION_REQUIRED', 'Section is required'));
      if (!['male','female','other'].includes(gender)) errors.push(m('ERR_GENDER_INVALID','Gender must be male/female/other'));
      if (dob && isNaN(Date.parse(dob))) errors.push(m('ERR_DOB_FORMAT','Invalid date of birth format'));
      if (!gPhone || !phoneRe.test(gPhone)) errors.push(m('ERR_GUARDIAN_PHONE','Guardian phone required (10 digits)'));

      if (!row['blood_group']) warnings.push(m('WARN_BLOOD_GROUP','Blood group missing, will be set to Unknown'));
      if (!row['category'])    warnings.push(m('WARN_CATEGORY_DEFAULT','Category missing, defaulting to General'));

      return {
        row: idx + 2,
        status: errors.length > 0 ? 'failed' : warnings.length > 0 ? 'warning' : 'success',
        errors,
        warnings,
        data: { stuId, firstName, lastName, gender, dob, cls, sec, gPhone,
                effectiveStart: row['effective_start_date'] || null,
                effectiveEnd:   row['effective_end_date']   || null,
                raw: row },
      };
    });

    try { fs.unlinkSync(req.file.path); } catch (_) {}

    const totalOk   = results.filter(r => r.status !== 'failed').length;
    const totalFail = results.filter(r => r.status === 'failed').length;
    res.json({ success: true, data: { results, totalOk, totalFail, canSubmit: totalFail === 0 } });
  } catch (err) {
    try { if (req.file) fs.unlinkSync(req.file.path); } catch (_) {}
    next(err);
  }
});

// POST /students/bulk  → insert validated rows
router.post('/bulk', authenticate, requireRole('super_admin','school_owner','principal','vp'), upload.single('file'), async (req, res, next) => {
  try {
    if (!req.file) return res.status(400).json({ success: false, message: 'No file uploaded' });

    const wb = xlsx.readFile(req.file.path);
    const sheetName = wb.SheetNames.find(n => n !== 'Instructions') || wb.SheetNames[0];
    const rows = xlsx.utils.sheet_to_json(wb.Sheets[sheetName], { defval: '' });

    const effectiveSchoolId = req.employee?.school_id || req.user.school_id;
    const { branch_id, effective_start_date, effective_end_date } = req.body;
    const effectiveBranchId = branch_id || req.employee?.branch_id;

    if (!effectiveSchoolId || !effectiveBranchId) {
      return res.status(400).json({ success: false, message: 'school_id and branch_id are required context' });
    }

    let inserted = 0; let skipped = 0;
    
    // We process them one by one securely (bulk insert is fine too, but this handles guardians cleanly)
    for (const row of rows) {
      try {
        const stuId   = String(row['student_id*'] || row['student_id'] || '').trim();
        const fn      = String(row['first_name*'] || row['first_name'] || '').trim();
        const ln      = String(row['last_name*']  || row['last_name']  || '').trim();
        const gender  = String(row['gender*']     || row['gender']     || 'other').trim().toLowerCase();
        const cls     = String(row['class_name*'] || row['class_name'] || '').trim();
        const sec     = String(row['section*']    || row['section']    || '').trim();
        const dob     = String(row['date_of_birth*'] || row['date_of_birth'] || '').trim() || null;
        const gPhone  = String(row['guardian_phone*'] || row['guardian_phone'] || '').trim();
        
        if (!stuId || !fn || !cls || !sec || !gPhone) { skipped++; continue; }

        const id = uuid();
        await transaction(async (conn) => {
          await conn.execute(
            `INSERT IGNORE INTO students
               (id, school_id, branch_id, student_id, roll_number, class_name, section,
                first_name, last_name, gender, date_of_birth, blood_group, nationality, category,
                address_line1, city, state, country, zip_code,
                effective_start_date, effective_end_date, is_active)
             VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,TRUE)`,
            [id, effectiveSchoolId, effectiveBranchId, stuId, row['roll_number'] || null, cls, sec,
             fn, ln, gender, dob, row['blood_group'] || 'Unknown', row['nationality'] || 'Indian', row['category'] || 'General',
             row['address_line1'] || row['address'] || null, row['city'] || null, row['state'] || null, row['country'] || 'India', row['zip_code'] || null,
             effective_start_date || row['effective_start_date'] || null, effective_end_date || row['effective_end_date'] || null]
          );

          // Guardian (if the first insert worked, we insert guardian)
          await conn.execute(
            `INSERT INTO guardians (id, student_id, guardian_type, first_name, phone, email, is_primary)
             VALUES (?,?,COALESCE(?, 'other'),?,?,?,TRUE)`,
            [uuid(), id, row['guardian_type*'] || row['guardian_type'] || 'father',
             row['guardian_name*'] || row['guardian_name'] || 'Guardian', gPhone,
             row['guardian_email'] || null]
          );
        });
        inserted++;
      } catch (err) {
        skipped++; 
      }
    }

    try { fs.unlinkSync(req.file.path); } catch (_) {}
    res.json({ success: true, data: { inserted, skipped, total: rows.length } });
  } catch (err) {
    try { if (req.file) fs.unlinkSync(req.file.path); } catch (_) {}
    next(err);
  }
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
