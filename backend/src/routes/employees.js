const router = require('express').Router();
const { v4: uuid } = require('uuid');
const multer  = require('multer');
const xlsx    = require('xlsx');
const path    = require('path');
const fs      = require('fs');
const { query, transaction } = require('../models/db');
const { authenticate, requireRole } = require('../middleware/auth');

const upload = multer({ dest: path.join(__dirname, '../../uploads/temp'), limits: { fileSize: 20 * 1024 * 1024 } });

router.get('/', authenticate, async (req, res, next) => {
  try {
    const { school_id, branch_id, org_role_id, reports_to, level_min, level_max, search,
            include_inactive, include_hidden } = req.query;
    let where = [];
    let params = [];
    // By default only show active; pass include_inactive=true to show all
    if (include_inactive !== 'true') where.push('e.is_active = TRUE');
    // By default hide hidden employees; pass include_hidden=true to show them
    if (include_hidden !== 'true') where.push('(e.is_hidden IS NULL OR e.is_hidden = FALSE)');

    // Security: Only super_admin can override the school context
    const isSchoolScoped = req.user.role === 'super_admin' || req.user.role === 'school_owner';
    const effectiveSchoolId = isSchoolScoped
      ? (school_id || req.employee?.school_id || req.user.school_id)
      : req.employee?.school_id;

    // Non-super_admin with no school context sees nothing
    if (req.user.role !== 'super_admin' && !effectiveSchoolId) {
      return res.json({ success: true, data: [] });
    }

    if (effectiveSchoolId) { where.push('e.school_id = ?');    params.push(effectiveSchoolId); }
    if (branch_id)   { where.push('e.branch_id = ?');    params.push(branch_id); }
    if (org_role_id) { where.push('e.org_role_id = ?');  params.push(org_role_id); }
    if (reports_to)  { where.push('e.reports_to_emp_id = ?'); params.push(reports_to); }
    if (level_min)   { where.push('r.level >= ?');       params.push(level_min); }
    if (level_max)   { where.push('r.level <= ?');       params.push(level_max); }
    if (search)      { where.push('(e.first_name LIKE ? OR e.last_name LIKE ? OR e.employee_id LIKE ?)');
                       params.push(`%${search}%`,`%${search}%`,`%${search}%`); }

    const whereClause = where.length > 0 ? `WHERE ${where.join(' AND ')}` : '';
    const employees = await query(
      `SELECT e.*, r.name AS role_name, r.level AS role_level, r.can_approve, r.can_upload_bulk,
              b.name AS branch_name,
              CONCAT(m.first_name,' ',m.last_name) AS manager_name,
              IFNULL((SELECT JSON_ARRAYAGG(org_role_id) FROM employee_extra_roles WHERE employee_id = e.id), JSON_ARRAY()) AS extra_roles
       FROM employees e
       JOIN org_roles r ON r.id = e.org_role_id
       LEFT JOIN branches b ON b.id = e.branch_id
       LEFT JOIN employees m ON m.id = e.reports_to_emp_id
       ${whereClause}
       ORDER BY r.level, e.last_name, e.first_name`, params
    );
    res.json({ success: true, data: employees });
  } catch (err) { next(err); }
});

router.get('/:id', authenticate, async (req, res, next) => {
  try {
    const [emp] = await query(
      `SELECT e.*, r.name AS role_name, r.level AS role_level,
              b.name AS branch_name, sch.name AS school_name,
              IFNULL((SELECT JSON_ARRAYAGG(org_role_id) FROM employee_extra_roles WHERE employee_id = e.id), JSON_ARRAY()) AS extra_roles
       FROM employees e
       JOIN org_roles r ON r.id = e.org_role_id
       LEFT JOIN branches b ON b.id = e.branch_id
       JOIN schools sch ON sch.id = e.school_id
       WHERE e.id = ?`, [req.params.id]
    );
    if (!emp) return res.status(404).json({ success: false, message: 'Employee not found' });
    res.json({ success: true, data: emp });
  } catch (err) { next(err); }
});

router.post('/', authenticate, requireRole('super_admin','school_owner','principal','vp','head_teacher'), async (req, res, next) => {
  try {
    const id = uuid();
    const { branch_id, employee_id, org_role_id, reports_to_emp_id,
      first_name, last_name, email, phone, whatsapp_no, alt_phone,
      date_of_joining, gender, date_of_birth, address_line1, city, state, country, zip_code,
      qualification, specialization, experience_years, assigned_classes, is_temp, extra_roles } = req.body;

    // Auto-resolve school_id from employee context if not provided
    const effectiveSchoolId = req.user.role === 'super_admin' 
      ? (req.body.school_id || req.employee?.school_id) 
      : req.employee?.school_id;
    const effectiveBranchId = branch_id || req.employee?.branch_id;

    if (!effectiveSchoolId) {
      return res.status(422).json({ success: false, message: 'school_id is required' });
    }

    // Resolve org_role_id from role_level if not provided directly
    let effectiveOrgRoleId = org_role_id;
    if (!effectiveOrgRoleId && req.body.role_level) {
      const [roleRow] = await query(
        'SELECT id FROM org_roles WHERE school_id = ? AND level = ? AND is_active = TRUE LIMIT 1',
        [effectiveSchoolId, req.body.role_level]
      );
      if (roleRow) effectiveOrgRoleId = roleRow.id;
    }
    if (!effectiveOrgRoleId) {
      return res.status(422).json({ success: false, message: 'org_role_id or role_level is required' });
    }

    await query(
      `INSERT INTO employees (id,school_id,branch_id,employee_id,org_role_id,reports_to_emp_id,
         first_name,last_name,email,phone,whatsapp_no,alt_phone,
         date_of_joining,gender,date_of_birth,address_line1,city,state,country,zip_code,
         qualification,specialization,experience_years,assigned_classes,is_temp)
       VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)`,
      [id,effectiveSchoolId,effectiveBranchId,employee_id,effectiveOrgRoleId,reports_to_emp_id,
       first_name,last_name,email,phone,whatsapp_no,alt_phone,
       date_of_joining,gender,date_of_birth,address_line1,city,state,country || 'India',zip_code,
       qualification,specialization,experience_years,
       JSON.stringify(assigned_classes || []), is_temp || false]
    );

    // Insert extra roles if provided
    if (Array.isArray(extra_roles) && extra_roles.length > 0) {
      const roleValues = extra_roles.filter(Boolean).map(roleId => [id, roleId]);
      if (roleValues.length > 0) {
        await query('INSERT IGNORE INTO employee_extra_roles (employee_id, org_role_id) VALUES ?', [roleValues]);
      }
    }

    const [emp] = await query('SELECT * FROM employees WHERE id = ?', [id]);
    res.status(201).json({ success: true, data: emp });
  } catch (err) { next(err); }
});

router.put('/:id', authenticate, async (req, res, next) => {
  try {
    const allowed = ['branch_id','org_role_id','reports_to_emp_id','first_name','last_name',
      'email','phone','whatsapp_no','alt_phone','address_line1','address_line2',
      'city','state','country','zip_code','gender','date_of_birth',
      'qualification','specialization','experience_years','date_of_joining','date_of_leaving',
      'assigned_classes','is_active','is_hidden','photo_url','display_name'];
    const fields = Object.keys(req.body).filter(k => allowed.includes(k));
    
    // Execute updates in a transaction since we might be updating extra roles too
    await transaction(async (connection) => {
      if (fields.length) {
        await connection.query(`UPDATE employees SET ${fields.map(f => `${f}=?`).join(',')} WHERE id=?`,
          [...fields.map(f => req.body[f]), req.params.id]);
      }

      // Handle extra_roles update if provided in request
      if (req.body.extra_roles !== undefined) {
        await connection.query('DELETE FROM employee_extra_roles WHERE employee_id = ?', [req.params.id]);
        if (Array.isArray(req.body.extra_roles) && req.body.extra_roles.length > 0) {
          const roleValues = req.body.extra_roles.filter(Boolean).map(roleId => [req.params.id, roleId]);
          if (roleValues.length > 0) {
            await connection.query('INSERT IGNORE INTO employee_extra_roles (employee_id, org_role_id) VALUES ?', [roleValues]);
          }
        }
      }
    });

    const [emp] = await query('SELECT *, IFNULL((SELECT JSON_ARRAYAGG(org_role_id) FROM employee_extra_roles WHERE employee_id = e.id), JSON_ARRAY()) AS extra_roles FROM employees e WHERE id = ?', [req.params.id]);
    res.json({ success: true, data: emp });
  } catch (err) { next(err); }
});

// Soft delete (deactivate) employee
router.delete('/:id', authenticate, requireRole('super_admin','school_owner','principal','vp'), async (req, res, next) => {
  try {
    const [emp] = await query('SELECT id FROM employees WHERE id = ?', [req.params.id]);
    if (!emp) return res.status(404).json({ success: false, message: 'Employee not found' });
    await query('UPDATE employees SET is_active = FALSE WHERE id = ?', [req.params.id]);
    res.json({ success: true, message: 'Employee deactivated' });
  } catch (err) { next(err); }
});

// Toggle hidden status
router.patch('/:id/toggle-hidden', authenticate, requireRole('super_admin','principal','vp','head_teacher'), async (req, res, next) => {
  try {
    const [emp] = await query('SELECT id, is_hidden FROM employees WHERE id = ?', [req.params.id]);
    if (!emp) return res.status(404).json({ success: false, message: 'Employee not found' });
    const newHidden = !emp.is_hidden;
    await query('UPDATE employees SET is_hidden = ? WHERE id = ?', [newHidden, req.params.id]);
    res.json({ success: true, data: { is_hidden: newHidden } });
  } catch (err) { next(err); }
});

// ── BULK UPLOAD ROUTES ────────────────────────────────────────

// GET /employees/bulk-template/download  → 100-row sample XLSX
router.get('/bulk-template/download', authenticate, async (req, res, next) => {
  try {
    const wb = xlsx.utils.book_new();

    // Instructions sheet
    const instr = [
      ['EMPLOYEE BULK UPLOAD TEMPLATE'],
      ['Fields marked * are mandatory.'],
      ['Date format: YYYY-MM-DD'],
      ['gender: male | female | other'],
      ['org_role_level: 1(Principal) to 10(Lab Staff)'],
      ['country: defaults to India if blank'],
      [''],
    ];
    const instrWs = xlsx.utils.aoa_to_sheet(instr);
    xlsx.utils.book_append_sheet(wb, instrWs, 'Instructions');

    // Sample data sheet
    const headers = [
      'employee_id*', 'first_name*', 'last_name*', 'gender*',
      'email*', 'phone*', 'whatsapp_no',
      'org_role_level*', 'org_role_code', 'org_role_name',
      'reports_to_emp_id', 'date_of_joining*',
      'address_line1', 'city', 'state', 'country', 'zip_code',
      'assigned_classes', 'subject_specialty',
      'is_temp', 'effective_start_date', 'effective_end_date',
    ];

    const FIRST = ['Aarav','Priya','Rahul','Sunita','Amit','Kavita','Rohit','Neha','Vivaan','Meena'];
    const LAST  = ['Sharma','Verma','Gupta','Singh','Patel','Kumar','Mehta','Joshi','Yadav','Tiwari'];
    const ROLES = [
      [1,'PRINCIPAL','Principal'],[2,'VP','Vice Principal'],[3,'HEAD_TEACHER','Head Teacher'],
      [4,'SR_TEACHER','Senior Teacher'],[5,'CL_TEACHER','Class Teacher'],
      [6,'SUB_TEACHER','Subject Teacher'],[7,'BAK_TEACHER','Backup Teacher'],
      [8,'TMP_TEACHER','Temp Teacher'],[9,'ASST_TEACHER','Teaching Asst'],[10,'LAB_ASST','Lab Staff'],
    ];
    const rows = [headers];
    for (let i = 1; i <= 100; i++) {
      const fn = FIRST[i % 10]; const ln = LAST[i % 10];
      const [lv, lc, lname] = ROLES[(i - 1) % 10];
      rows.push([
        `EMP-T${String(i).padStart(3,'0')}`, fn, ln, i%2===0?'male':'female',
        `${fn.toLowerCase()}.${ln.toLowerCase()}${i}@school.edu.in`,
        `+9198${String(i).padStart(8,'0')}`,
        `+9198${String(i).padStart(8,'0')}`,
        lv, lc, lname,
        i > 1 ? `EMP-T${String(Math.max(1,i-5)).padStart(3,'0')}` : '',
        `2025-0${(i%9)+1}-01`,
        `House ${i}, Sector ${(i%30)+1}`, 'Noida', 'Uttar Pradesh', 'India',
        `201${String((i%900)+100)}`,
        lv >= 5 ? `Class ${(i%12)+1}${['A','B','C'][i%3]}` : '',
        lv >= 4 ? ['Maths','Science','English','Hindi','PE'][i%5] : '',
        lv === 8 ? 'TRUE' : 'FALSE',
        '2025-04-01', '2026-03-31',
      ]);
    }
    xlsx.utils.book_append_sheet(wb, xlsx.utils.aoa_to_sheet(rows), 'Employees (100 samples)');

    const buf = xlsx.write(wb, { type: 'buffer', bookType: 'xlsx' });
    res.setHeader('Content-Disposition', 'attachment; filename="employee_bulk_template.xlsx"');
    res.setHeader('Content-Type', 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
    res.send(buf);
  } catch (err) { next(err); }
});

// POST /employees/validate-bulk  → per-row validation (no DB write)
router.post('/validate-bulk', authenticate, upload.single('file'), async (req, res, next) => {
  try {
    if (!req.file) return res.status(400).json({ success: false, message: 'No file uploaded' });

    // Load validation messages from DB
    const dbMsgs = await query('SELECT code, message_en FROM validation_messages WHERE entity IN (?,?)', ['employee','general']);
    const msg = {};
    dbMsgs.forEach(r => { msg[r.code] = r.message_en; });
    const m = (code, fallback) => msg[code] || fallback;

    const wb = xlsx.readFile(req.file.path);
    // Find the data sheet (not Instructions)
    const sheetName = wb.SheetNames.find(n => n !== 'Instructions') || wb.SheetNames[0];
    const rows = xlsx.utils.sheet_to_json(wb.Sheets[sheetName], { defval: '' });

    // Fetch existing employee IDs and branch codes for duplicate checks
    const effectiveSchoolId = req.employee?.school_id || req.user.school_id;
    const existingIds = new Set(
      (await query('SELECT employee_id FROM employees WHERE school_id = ?', [effectiveSchoolId]))
        .map(r => r.employee_id)
    );
    const branches = await query('SELECT id, code FROM branches WHERE school_id = ?', [effectiveSchoolId]);
    const branchByCode = {};
    branches.forEach(b => { branchByCode[b.code.toUpperCase()] = b.id; });

    const phoneRe  = /^[+]?[6-9]\d{9,14}$/;
    const emailRe  = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

    const results = rows.map((row, idx) => {
      const errors = []; const warnings = [];
      const empId    = String(row['employee_id*'] || row['employee_id'] || '').trim();
      const firstName= String(row['first_name*']  || row['first_name']  || '').trim();
      const lastName = String(row['last_name*']   || row['last_name']   || '').trim();
      const email    = String(row['email*']       || row['email']       || '').trim();
      const phone    = String(row['phone*']       || row['phone']       || '').trim();
      const gender   = String(row['gender*']      || row['gender']      || '').trim().toLowerCase();
      const roleLevel= parseInt(row['org_role_level*'] || row['org_role_level'] || 0);
      const doj      = String(row['date_of_joining*']  || row['date_of_joining'] || '').trim();
      const branchCode=(String(row['branch_code'] || '')).toUpperCase();
      const reportsTo= String(row['reports_to_emp_id'] || '').trim();

      if (!empId)                 errors.push(m('ERR_EMP_ID_REQUIRED',  'Employee ID is required'));
      else if (!/^[A-Za-z0-9\-_]+$/.test(empId)) errors.push(m('ERR_EMP_ID_FORMAT','Employee ID must be alphanumeric'));
      else if (existingIds.has(empId))            errors.push(m('ERR_EMP_ID_DUPLICATE','Employee ID already exists'));

      if (!firstName)             errors.push(m('ERR_FIRST_NAME_REQUIRED','First name is required'));
      if (!lastName)              errors.push(m('ERR_LAST_NAME_REQUIRED', 'Last name is required'));
      if (!email || !emailRe.test(email)) errors.push(m('ERR_EMAIL_FORMAT','Invalid email address'));
      if (!phone || !phoneRe.test(phone)) errors.push(m('ERR_PHONE_REQUIRED','Phone number required (10 digits, starts 6-9)'));
      if (!['male','female','other'].includes(gender)) errors.push(m('ERR_GENDER_INVALID','Gender must be male/female/other'));
      if (!roleLevel || roleLevel < 1 || roleLevel > 10) errors.push(m('ERR_ROLE_LEVEL_INVALID','Role level must be 1–10'));
      if (branchCode && !branchByCode[branchCode]) errors.push(m('ERR_BRANCH_NOT_FOUND','Branch code not found'));
      if (doj && new Date(doj) > new Date()) warnings.push(m('WARN_DOJ_FUTURE','Date of joining is in the future'));
      if (reportsTo && !existingIds.has(reportsTo)) warnings.push(m('WARN_REPORTS_TO_MISSING','reports_to not found, will be blank'));

      return {
        row: idx + 2, // 1-indexed + header row
        status: errors.length > 0 ? 'failed' : warnings.length > 0 ? 'warning' : 'success',
        errors,
        warnings,
        data: { empId, firstName, lastName, email, phone, gender, roleLevel, doj, branchCode, reportsTo,
                branchId: branchByCode[branchCode] || null,
                effectiveStart: row['effective_start_date'] || null,
                effectiveEnd:   row['effective_end_date']   || null,
                raw: row },
      };
    });

    // Clean up temp file
    try { fs.unlinkSync(req.file.path); } catch (_) {}

    const totalOk   = results.filter(r => r.status !== 'failed').length;
    const totalFail = results.filter(r => r.status === 'failed').length;
    res.json({ success: true, data: { results, totalOk, totalFail, canSubmit: totalFail === 0 } });
  } catch (err) {
    try { if (req.file) fs.unlinkSync(req.file.path); } catch (_) {}
    next(err);
  }
});

// POST /employees/bulk  → insert validated rows
router.post('/bulk', authenticate, requireRole('super_admin','school_owner','principal','vp'), upload.single('file'), async (req, res, next) => {
  try {
    if (!req.file) return res.status(400).json({ success: false, message: 'No file uploaded' });

    const wb = xlsx.readFile(req.file.path);
    const sheetName = wb.SheetNames.find(n => n !== 'Instructions') || wb.SheetNames[0];
    const rows = xlsx.utils.sheet_to_json(wb.Sheets[sheetName], { defval: '' });

    const effectiveSchoolId = req.employee?.school_id || req.user.school_id;
    const { effective_start_date, effective_end_date } = req.body;

    const branches = await query('SELECT id, code FROM branches WHERE school_id = ?', [effectiveSchoolId]);
    const branchByCode = {};
    branches.forEach(b => { branchByCode[b.code.toUpperCase()] = b.id; });

    const orgRoles = await query('SELECT id, level, code FROM org_roles WHERE school_id = ? AND is_active = TRUE', [effectiveSchoolId]);
    const roleByLevel = {}; const roleByCode = {};
    orgRoles.forEach(r => { roleByLevel[r.level] = r.id; if (r.code) roleByCode[r.code.toUpperCase()] = r.id; });

    let inserted = 0; let skipped = 0;
    for (const row of rows) {
      try {
        const empId   = String(row['employee_id*'] || row['employee_id'] || '').trim();
        const fn      = String(row['first_name*']  || row['first_name']  || '').trim();
        const ln      = String(row['last_name*']   || row['last_name']   || '').trim();
        const email   = String(row['email*']       || row['email']       || '').trim();
        const phone   = String(row['phone*']       || row['phone']       || '').trim();
        const wapp    = String(row['whatsapp_no']  || phone).trim();
        const gender  = String(row['gender*']      || row['gender']      || 'other').trim().toLowerCase();
        const doj     = String(row['date_of_joining*'] || row['date_of_joining'] || '').trim() || null;
        const lvl     = parseInt(row['org_role_level*'] || row['org_role_level'] || 0);
        const rc      = String(row['org_role_code'] || '').toUpperCase();
        const bc      = String(row['branch_code']  || '').toUpperCase();
        const isTemp  = String(row['is_temp'] || '').toUpperCase() === 'TRUE';
        const classes = String(row['assigned_classes'] || '').trim();
        const subject = String(row['subject_specialty'] || '').trim();
        if (!empId || !fn || !ln || !email || !phone) { skipped++; continue; }

        const orgRoleId = roleByCode[rc] || roleByLevel[lvl];
        if (!orgRoleId) { skipped++; continue; }

        const branchId = branchByCode[bc] || null;

        await query(
          `INSERT IGNORE INTO employees
             (id, school_id, branch_id, employee_id, org_role_id,
              first_name, last_name, email, phone, whatsapp_no,
              gender, date_of_joining, assigned_classes, is_temp, country,
              effective_start_date, effective_end_date, is_active)
           VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,TRUE)`,
          [uuid(), effectiveSchoolId, branchId, empId, orgRoleId,
           fn, ln, email, phone, wapp,
           gender, doj || null, JSON.stringify(classes ? classes.split(',').map(c=>c.trim()) : []),
           isTemp, 'India',
           effective_start_date || null, effective_end_date || null]
        );
        inserted++;
      } catch (_) { skipped++; }
    }

    try { fs.unlinkSync(req.file.path); } catch (_) {}
    res.json({ success: true, data: { inserted, skipped, total: rows.length } });
  } catch (err) {
    try { if (req.file) fs.unlinkSync(req.file.path); } catch (_) {}
    next(err);
  }
});

// Org tree
router.get('/org-tree/:school_id', authenticate, async (req, res, next) => {
  try {
    const schoolId = req.params.school_id;
    // Security: Only super_admin/school_owner can override the school context
    const isSchoolScoped = req.user.role === 'super_admin' || req.user.role === 'school_owner';
    const effectiveSchoolId = isSchoolScoped
      ? (schoolId || req.employee?.school_id || req.user.school_id)
      : req.employee?.school_id;

    if (!effectiveSchoolId || (req.user.role !== 'super_admin' && effectiveSchoolId !== schoolId)) {
        // Handle mismatch or empty context
    }

    const employees = await query(
      `SELECT e.id, e.employee_id, e.first_name, e.last_name, e.photo_url,
              e.reports_to_emp_id, r.name AS role_name, r.level AS role_level,
              b.name AS branch_name
       FROM employees e
       JOIN org_roles r ON r.id = e.org_role_id
       LEFT JOIN branches b ON b.id = e.branch_id
       WHERE e.school_id = ? AND e.is_active = TRUE
       ORDER BY r.level, e.last_name`, [effectiveSchoolId]
    );

    // Build tree
    const map = {};
    employees.forEach(e => { map[e.id] = { ...e, children: [] }; });
    const roots = [];
    employees.forEach(e => {
      if (e.reports_to_emp_id && map[e.reports_to_emp_id]) {
        map[e.reports_to_emp_id].children.push(map[e.id]);
      } else {
        roots.push(map[e.id]);
      }
    });

    res.json({ success: true, data: roots });
  } catch (err) { next(err); }
});

// Employee Bulk Upload
router.post('/bulk-upload', authenticate,
  requireRole('super_admin','principal','vp','head_teacher'),
  upload.single('file'),
  async (req, res, next) => {
    if (!req.file) return res.status(400).json({ success: false, message: 'No file uploaded' });

    const batchId = uuid();
    const effectiveSchoolId = req.user.role === 'super_admin'
      ? (req.body.school_id || req.employee?.school_id)
      : req.employee?.school_id;
    const branch_id = req.body.branch_id || req.employee?.branch_id || null;

    if (!effectiveSchoolId) {
      fs.unlink(req.file.path, () => {});
      return res.status(422).json({ success: false, message: 'school_id is required' });
    }

    try {
      await query(
        `INSERT INTO bulk_batches (id, school_id, branch_id, type, filename, status, uploaded_by)
         VALUES (?, ?, ?, 'employees', ?, 'processing', ?)`,
        [batchId, effectiveSchoolId, branch_id, req.file.originalname, req.user.id]
      );

      const wb = xlsx.readFile(req.file.path);
      const ws = wb.Sheets[wb.SheetNames[0]];
      const rows = xlsx.utils.sheet_to_json(ws, { defval: '' });

      const errors = [];
      const success = [];
      const REQUIRED = ['employee_id', 'first_name', 'last_name', 'org_role_code'];

      for (let i = 0; i < rows.length; i++) {
        const row = rows[i];
        const rowNo = i + 2;

        const missing = REQUIRED.filter(f => !row[f]?.toString().trim());
        if (missing.length) {
          errors.push({ row: rowNo, error: `Missing: ${missing.join(', ')}`, data: row });
          continue;
        }

        // Check duplicate employee_id within school
        const [dup] = await query(
          'SELECT id FROM employees WHERE school_id = ? AND employee_id = ?',
          [effectiveSchoolId, row.employee_id.toString().trim()]
        );
        if (dup) {
          errors.push({ row: rowNo, error: `Duplicate employee_id: ${row.employee_id}`, data: row });
          continue;
        }

        // Resolve org_role by code
        const [roleRow] = await query(
          'SELECT id FROM org_roles WHERE school_id = ? AND code = ? AND is_active = TRUE LIMIT 1',
          [effectiveSchoolId, row.org_role_code?.toString().trim().toUpperCase()]
        );
        if (!roleRow) {
          errors.push({ row: rowNo, error: `Unknown org_role_code: ${row.org_role_code}`, data: row });
          continue;
        }

        try {
          const empId = uuid();
          await query(
            `INSERT INTO employees (id, school_id, branch_id, employee_id, org_role_id,
               first_name, last_name, gender, date_of_birth, email, phone, whatsapp_no,
               date_of_joining, address_line1, city, state, country, zip_code,
               qualification, specialization, bulk_upload_batch)
             VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)`,
            [empId, effectiveSchoolId, branch_id,
             row.employee_id.toString().trim(),
             roleRow.id,
             row.first_name.toString().trim(),
             row.last_name.toString().trim(),
             row.gender?.toLowerCase() || null,
             row.date_of_birth || null,
             row.email || null,
             row.phone || null,
             row.whatsapp_no || row.phone || null,
             row.date_of_joining || null,
             row.address || null,
             row.city || null,
             row.state || null,
             row.country || 'India',
             row.zip_code || null,
             row.qualification || null,
             row.specialization || null,
             batchId]
          );
          success.push(rowNo);
        } catch (insertErr) {
          errors.push({ row: rowNo, error: insertErr.message, data: row });
        }
      }

      fs.unlinkSync(req.file.path);

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
          errors: errors.slice(0, 50)
        }
      });
    } catch (err) {
      if (req.file) fs.unlink(req.file.path, () => {});
      await query('UPDATE bulk_batches SET status=\'failed\' WHERE id=?', [batchId]);
      next(err);
    }
  }
);

module.exports = router;
