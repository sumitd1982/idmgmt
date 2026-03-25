const router = require('express').Router();
const { v4: uuid } = require('uuid');
const multer  = require('multer');
const xlsx    = require('xlsx');
const path    = require('path');
const fs      = require('fs');
const { query, transaction } = require('../models/db');
const { authenticate, requireRole } = require('../middleware/auth');

const BULK_UPLOAD_DIR = path.join(__dirname, '../../uploads/bulk_uploads');
if (!fs.existsSync(BULK_UPLOAD_DIR)) fs.mkdirSync(BULK_UPLOAD_DIR, { recursive: true });

const upload = multer({ dest: path.join(__dirname, '../../uploads/temp'), limits: { fileSize: 20 * 1024 * 1024 } });

/**
 * Parse a date value from any of the supported formats into YYYY-MM-DD.
 * Handles: JS Date objects, YYYY-MM-DD, DD-MM-YYYY, YYYY-DD-MM,
 *          DD/MM/YYYY, YYYY/MM/DD (and dash/slash variants).
 * Returns '' for empty/null, or the original string if unrecognised
 * (so the caller's regex validator can surface a clear error).
 */
function excelSerialToDate(serial) {
  // Excel epoch is 1899-12-30 (accounts for Lotus 1-2-3 leap year bug)
  const d = new Date(Date.UTC(1899, 11, 30) + serial * 86400000);
  return isNaN(d) ? '' : d.toISOString().split('T')[0];
}

function parseFlexDate(raw) {
  if (raw == null || raw === '') return '';
  // Numeric type — Excel serial (e.g. 45748)
  if (typeof raw === 'number') return excelSerialToDate(raw);
  if (raw instanceof Date) return isNaN(raw) ? '' : raw.toISOString().split('T')[0];

  const ds = String(raw).trim();
  if (!ds) return '';

  // Numeric string — Excel serial stored as text (e.g. "45748")
  if (/^\d{4,6}$/.test(ds)) {
    const n = Number(ds);
    // Valid Excel serials for years 1900–2100 are roughly 1–73050
    if (n >= 1 && n <= 73050) return excelSerialToDate(n);
  }

  // YYYY-MM-DD or YYYY/MM/DD or YYYY-DD-MM or YYYY/DD/MM  (year is 4 digits first)
  let m = ds.match(/^(\d{4})[-/](\d{1,2})[-/](\d{1,2})$/);
  if (m) {
    const [, y, a, b] = m.map(Number);
    // If a > 12 it must be the day  → format is YYYY-DD-MM
    // If b > 12 it must be the day  → format is YYYY-MM-DD
    // If both ≤ 12 default to YYYY-MM-DD (ISO standard)
    const [mo, dy] = a > 12 ? [b, a] : [a, b];
    return `${y}-${String(mo).padStart(2,'0')}-${String(dy).padStart(2,'0')}`;
  }

  // DD-MM-YYYY or DD/MM/YYYY  (day is 1-2 digits first, year is 4 digits last)
  m = ds.match(/^(\d{1,2})[-/](\d{1,2})[-/](\d{4})$/);
  if (m) {
    const [, d, mo, y] = m;
    return `${y}-${mo.padStart(2,'0')}-${d.padStart(2,'0')}`;
  }

  return ds; // unrecognised — pass through so the validator can flag it
}

/**
 * Ensure a user account exists for an employee phone.
 * If no user exists yet, creates one and links employee.user_id.
 * Returns the user id.
 */
async function ensureUserForEmployee(empId, phone, firstName, lastName, roleCode) {
  if (!phone) return null;
  const last10 = phone.replace(/\D/g, '').slice(-10);
  if (!last10) return null;

  // Check for existing user by phone (last-10 match)
  const users = await query(
    'SELECT id, role FROM users WHERE phone LIKE ? OR phone LIKE ? LIMIT 1',
    [`%${last10}`, last10]
  );

  let userId;
  if (users.length) {
    userId = users[0].id;
    // Upgrade role if still viewer
    if (users[0].role === 'viewer') {
      await query('UPDATE users SET role = ?, full_name = CASE WHEN full_name = \'\' THEN ? ELSE full_name END WHERE id = ?',
        [roleCode, `${firstName} ${lastName}`.trim(), userId]);
    }
  } else {
    userId = uuid();
    await query(
      'INSERT INTO users (id, phone, full_name, display_name, role) VALUES (?, ?, ?, ?, ?)',
      [userId, last10, `${firstName} ${lastName}`.trim(), `${firstName} ${lastName}`.trim(), roleCode]
    );
  }

  await query('UPDATE employees SET user_id = ? WHERE id = ? AND user_id IS NULL', [userId, empId]);
  return userId;
}

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
      `SELECT e.*, r.name AS role_name, r.level AS role_level,
              COALESCE(e.can_approve, r.can_approve) AS can_approve,
              COALESCE(e.can_upload_bulk, r.can_upload_bulk) AS can_upload_bulk,
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

router.post('/', authenticate, requireRole('super_admin','school_owner','principal','vp','head_teacher'), async (req, res, next) => {
  try {
    const id = uuid();
    const { branch_id, employee_id, org_role_id, reports_to_emp_id,
      first_name, last_name, display_name, email, phone, whatsapp_no, alt_phone,
      date_of_joining, date_of_birth, gender,
      address_line1, address_line2, city, state, country, zip_code,
      qualification, specialization, experience_years,
      assigned_classes, subject_ids, photo_url,
      is_temp, extra_roles, permissions,
      can_approve, can_upload_bulk } = req.body;

    // Auto-resolve school_id from employee context if not provided
    const effectiveSchoolId = req.user.role === 'super_admin'
      ? (req.body.school_id || req.employee?.school_id)
      : req.user.role === 'school_owner'
        ? (req.employee?.school_id || req.user.school_id)
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

    const permsJson = permissions ? JSON.stringify(permissions) : null;
    await query(
      `INSERT INTO employees (id,school_id,branch_id,employee_id,org_role_id,reports_to_emp_id,
         first_name,last_name,display_name,email,phone,whatsapp_no,alt_phone,
         date_of_joining,gender,date_of_birth,
         address_line1,address_line2,city,state,country,zip_code,
         qualification,specialization,experience_years,
         assigned_classes,subject_ids,photo_url,
         can_approve,can_upload_bulk,permissions,is_temp)
       VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)`,
      [id,effectiveSchoolId,effectiveBranchId,employee_id,effectiveOrgRoleId,reports_to_emp_id,
       first_name,last_name,display_name||null,email,phone,whatsapp_no,alt_phone,
       date_of_joining,gender,date_of_birth,
       address_line1,address_line2||null,city,state,country||'India',zip_code,
       qualification,specialization,experience_years,
       JSON.stringify(assigned_classes||[]),
       JSON.stringify(subject_ids||[]),
       photo_url||null,
       can_approve??null, can_upload_bulk??null,
       permsJson, is_temp||false]
    );

    // Auto-link user_id if the new employee's phone or email matches the creating user.
    // This lets a school_owner (or any role) add themselves and immediately get linked.
    const userPhone = req.user.phone?.replace(/\D/g, '').slice(-10);
    const empPhone  = (phone || '').replace(/\D/g, '').slice(-10);
    const emailMatch = req.user.email && email &&
      req.user.email.toLowerCase() === email.toLowerCase();
    const phoneMatch = userPhone && empPhone && userPhone === empPhone;
    if ((emailMatch || phoneMatch) && !req.employee) {
      await query('UPDATE employees SET user_id = ? WHERE id = ? AND user_id IS NULL', [req.user.id, id]);
    }

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

// Type-2 SCD edit: mark old record inactive, insert new record with changes applied
router.put('/:id', authenticate, async (req, res, next) => {
  try {
    const [existing] = await query(
      `SELECT e.*, IFNULL((SELECT JSON_ARRAYAGG(org_role_id) FROM employee_extra_roles WHERE employee_id = e.id), JSON_ARRAY()) AS extra_roles
       FROM employees e WHERE e.id = ?`, [req.params.id]
    );
    if (!existing) return res.status(404).json({ success: false, message: 'Employee not found' });

    const allowed = ['branch_id','org_role_id','reports_to_emp_id','first_name','last_name','display_name',
      'email','phone','whatsapp_no','alt_phone','address_line1','address_line2',
      'city','state','country','zip_code','gender','date_of_birth',
      'qualification','specialization','experience_years','date_of_joining',
      'assigned_classes','subject_ids','is_hidden','photo_url',
      'can_approve','can_upload_bulk','permissions'];
    const changes = Object.fromEntries(Object.keys(req.body).filter(k => allowed.includes(k)).map(k => [k, req.body[k]]));

    // Resolve role_level → org_role_id (same as POST route)
    let resolvedOrgRoleId = changes.org_role_id ?? existing.org_role_id;
    if (!changes.org_role_id && req.body.role_level) {
      const [roleRow] = await query(
        'SELECT id FROM org_roles WHERE school_id = ? AND level = ? AND is_active = TRUE LIMIT 1',
        [existing.school_id, req.body.role_level]
      );
      if (roleRow) resolvedOrgRoleId = roleRow.id;
    }

    // Respect is_active from body; default to keeping existing value
    const isActive = req.body.is_active !== undefined
      ? (req.body.is_active === false || req.body.is_active === 0 || req.body.is_active === '0' ? false : true)
      : existing.is_active;

    const newId = uuid();
    const newRecord = {
      id: newId,
      school_id: existing.school_id,
      branch_id:              changes.branch_id              ?? existing.branch_id,
      employee_id:            existing.employee_id,
      org_role_id:            resolvedOrgRoleId,
      reports_to_emp_id:      changes.reports_to_emp_id      ?? existing.reports_to_emp_id,
      first_name:             changes.first_name             ?? existing.first_name,
      last_name:              changes.last_name              ?? existing.last_name,
      display_name:           changes.display_name           ?? existing.display_name,
      email:                  changes.email                  ?? existing.email,
      phone:                  changes.phone                  ?? existing.phone,
      whatsapp_no:            changes.whatsapp_no            ?? existing.whatsapp_no,
      alt_phone:              changes.alt_phone              ?? existing.alt_phone,
      address_line1:          changes.address_line1          ?? existing.address_line1,
      address_line2:          changes.address_line2          ?? existing.address_line2,
      city:                   changes.city                   ?? existing.city,
      state:                  changes.state                  ?? existing.state,
      country:                changes.country                ?? existing.country,
      zip_code:               changes.zip_code               ?? existing.zip_code,
      gender:                 changes.gender                 ?? existing.gender,
      date_of_birth:          changes.date_of_birth          ?? existing.date_of_birth,
      qualification:          changes.qualification          ?? existing.qualification,
      specialization:         changes.specialization         ?? existing.specialization,
      experience_years:       changes.experience_years       ?? existing.experience_years,
      date_of_joining:        changes.date_of_joining        ?? existing.date_of_joining,
      assigned_classes:       changes.assigned_classes != null
        ? JSON.stringify(changes.assigned_classes)
        : (Array.isArray(existing.assigned_classes)
            ? JSON.stringify(existing.assigned_classes)
            : (existing.assigned_classes || '[]')),
      subject_ids:            changes.subject_ids != null
        ? JSON.stringify(changes.subject_ids)
        : (Array.isArray(existing.subject_ids)
            ? JSON.stringify(existing.subject_ids)
            : (existing.subject_ids || '[]')),
      is_hidden:              changes.is_hidden              ?? existing.is_hidden ?? false,
      photo_url:              changes.photo_url              ?? existing.photo_url,
      can_approve:            changes.can_approve            !== undefined ? changes.can_approve : existing.can_approve ?? null,
      can_upload_bulk:        changes.can_upload_bulk        !== undefined ? changes.can_upload_bulk : existing.can_upload_bulk ?? null,
      permissions:            changes.permissions != null
        ? JSON.stringify(changes.permissions)
        : (existing.permissions ? JSON.stringify(existing.permissions) : null),
      is_temp:                existing.is_temp,
      user_id:                existing.user_id,
      is_active:              true,
      created_by:             req.user.id,
      updated_by:             req.user.id,
    };

    // Insert history snapshot before making changes
    await query(
      `INSERT INTO employee_history
         (employee_id,school_id,branch_id,emp_code,org_role_id,reports_to_emp_id,
          first_name,last_name,display_name,email,phone,whatsapp_no,alt_phone,
          address_line1,address_line2,city,state,country,zip_code,gender,date_of_birth,
          date_of_joining,qualification,specialization,experience_years,
          assigned_classes,subject_ids,photo_url,can_approve,can_upload_bulk,permissions,is_active,changed_by)
       VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)`,
      [req.params.id, existing.school_id, existing.branch_id, existing.employee_id,
       existing.org_role_id, existing.reports_to_emp_id,
       existing.first_name, existing.last_name, existing.display_name,
       existing.email, existing.phone, existing.whatsapp_no, existing.alt_phone,
       existing.address_line1, existing.address_line2, existing.city, existing.state,
       existing.country, existing.zip_code, existing.gender, existing.date_of_birth,
       existing.date_of_joining, existing.qualification, existing.specialization, existing.experience_years,
       Array.isArray(existing.assigned_classes) ? JSON.stringify(existing.assigned_classes) : (existing.assigned_classes || '[]'),
       Array.isArray(existing.subject_ids) ? JSON.stringify(existing.subject_ids) : (existing.subject_ids || '[]'),
       existing.photo_url,
       existing.can_approve, existing.can_upload_bulk, existing.permissions, existing.is_active,
       req.user.id]
    );

    await transaction(async (connection) => {
      // Mark old record inactive; employee_id is preserved unchanged on the historical record
      await connection.query(
        'UPDATE employees SET is_active = FALSE, date_of_leaving = CURDATE() WHERE id = ?',
        [req.params.id]
      );

      await connection.query(
        `INSERT INTO employees
           (id, school_id, branch_id, employee_id, org_role_id, reports_to_emp_id,
            first_name, last_name, display_name, email, phone, whatsapp_no, alt_phone,
            address_line1, address_line2, city, state, country, zip_code,
            gender, date_of_birth, qualification, specialization, experience_years,
            date_of_joining, assigned_classes, subject_ids, is_hidden, photo_url,
            is_temp, is_active, can_approve, can_upload_bulk, permissions,
            user_id, created_by, updated_by)
         VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)`,
        [newRecord.id, newRecord.school_id, newRecord.branch_id, newRecord.employee_id,
         newRecord.org_role_id, newRecord.reports_to_emp_id,
         newRecord.first_name, newRecord.last_name, newRecord.display_name,
         newRecord.email, newRecord.phone, newRecord.whatsapp_no, newRecord.alt_phone,
         newRecord.address_line1, newRecord.address_line2, newRecord.city, newRecord.state,
         newRecord.country, newRecord.zip_code, newRecord.gender, newRecord.date_of_birth,
         newRecord.qualification, newRecord.specialization, newRecord.experience_years,
         newRecord.date_of_joining, newRecord.assigned_classes, newRecord.subject_ids,
         newRecord.is_hidden ? 1 : 0, newRecord.photo_url,
         newRecord.is_temp ? 1 : 0, isActive ? 1 : 0,
         newRecord.can_approve, newRecord.can_upload_bulk, newRecord.permissions,
         newRecord.user_id, newRecord.created_by, newRecord.updated_by]
      );

      // Re-point class_sections to the new employee UUID (SCD Type-2 creates a new id)
      await connection.query(
        'UPDATE class_sections SET class_teacher_id = ? WHERE class_teacher_id = ?',
        [newId, req.params.id]
      );

      // If phone changed and employee has a linked user, sync the new phone to users table
      if (newRecord.user_id && changes.phone && changes.phone !== existing.phone) {
        await connection.query(
          'UPDATE users SET phone = ? WHERE id = ?',
          [newRecord.phone, newRecord.user_id]
        );
      }

      // Copy extra roles
      const extraRoles = req.body.extra_roles !== undefined
        ? (Array.isArray(req.body.extra_roles) ? req.body.extra_roles : [])
        : (Array.isArray(existing.extra_roles) ? existing.extra_roles : JSON.parse(existing.extra_roles || '[]'));
      if (extraRoles.length > 0) {
        const roleValues = extraRoles.filter(Boolean).map(roleId => [newId, roleId]);
        if (roleValues.length > 0) {
          await connection.query('INSERT IGNORE INTO employee_extra_roles (employee_id, org_role_id) VALUES ?', [roleValues]);
        }
      }
    });

    const [emp] = await query(
      `SELECT e.*, IFNULL((SELECT JSON_ARRAYAGG(org_role_id) FROM employee_extra_roles WHERE employee_id = e.id), JSON_ARRAY()) AS extra_roles
       FROM employees e WHERE e.id = ?`, [newId]
    );
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
      ['EMPLOYEE BULK UPLOAD TEMPLATE — v2'],
      [''],
      ['Fields marked * are MANDATORY. Others are optional.'],
      [''],
      ['COLUMN',             'DESCRIPTION',                                               'FORMAT / EXAMPLES'],
      ['employee_id*',       'Unique Employee ID in your school',                         'Alphanumeric, no spaces. E.g. EMP-001'],
      ['first_name*',        'Employee first name',                                       'Text, max 100 chars'],
      ['last_name*',         'Employee last name',                                        'Text, max 100 chars'],
      ['display_name',       'Name shown in UI (defaults to first_name + last_name)',      'Text, max 150 chars'],
      ['gender*',            'Employee gender',                                            'male | female | other'],
      ['email*',             'Work email address',                                         'Valid email, e.g. john@school.edu'],
      ['phone*',             'Primary mobile number',                                      '10-digit India mobile (starts 6–9), or +91…'],
      ['alt_phone',          'Alternate phone number',                                     'Same format as phone (optional)'],
      ['whatsapp_no',        'WhatsApp number (defaults to phone if blank)',                'Same format as phone'],
      ['date_of_birth',      'Date of birth for age record',                               'YYYY-MM-DD, e.g. 1990-05-14. Age must be ≥18'],
      ['date_of_joining*',   'Date employee joined this school',                           'YYYY-MM-DD, e.g. 2024-06-01'],
      ['org_role_level*',    'Organisational role level (1=Principal, 10=Lab Staff)',       '1 to 10'],
      ['org_role_code',      'Specific role code (optional, overrides level)',              'E.g. SR_TEACHER, CL_TEACHER'],
      ['org_role_name',      'Role label (informational only)',                             'E.g. Senior Teacher'],
      ['reports_to_emp_id',  'Employee ID of direct manager (blank = top-level)',          'Must match an existing or uploaded employee_id'],
      ['branch_code',        'Branch code if multi-branch school',                         'Must match a configured branch code'],
      ['address_line1',      'House / flat / building number and street',                  'Text, max 255 chars'],
      ['address_line2',      'Locality / landmark (optional)',                             'Text, max 255 chars'],
      ['city',               'City of residence',                                          'Text, e.g. Noida'],
      ['state',              'State of residence (India)',                                  'Full name, e.g. Uttar Pradesh'],
      ['country',            'Country of residence (defaults to India)',                   'Full name, e.g. India'],
      ['zip_code',           'PIN / ZIP code',                                             '6-digit PIN, e.g. 201301'],
      ['qualification',      'Highest academic qualification',                             'E.g. B.Ed, M.Sc, PhD (max 100 chars)'],
      ['specialization',     'Subject or area of specialisation',                          'E.g. Mathematics (max 100 chars)'],
      ['experience_years',   'Total teaching / work experience in years',                  'Integer 0–50'],
      ['assigned_classes',   'Class-sections taught (comma-separated, no spaces)',         'E.g. 4A,5B,6C  (must match configured sections)'],
      ['subject_specialty',  'Primary subject specialty',                                  'E.g. Mathematics'],
      ['is_temp',            'Mark as temporary staff',                                    'TRUE | FALSE (default FALSE)'],
    ];
    const instrWs = xlsx.utils.aoa_to_sheet(instr);
    xlsx.utils.book_append_sheet(wb, instrWs, 'Instructions');

    // Sample data sheet
    const headers = [
      'employee_id*', 'first_name*', 'last_name*', 'display_name', 'gender*',
      'email*', 'phone*', 'alt_phone', 'whatsapp_no',
      'date_of_birth', 'date_of_joining*',
      'org_role_level*', 'org_role_code', 'org_role_name',
      'reports_to_emp_id',
      'address_line1', 'address_line2', 'city', 'state', 'country', 'zip_code',
      'qualification', 'specialization', 'experience_years',
      'assigned_classes', 'subject_specialty',
      'is_temp',
    ];

    const FIRST = ['Aarav','Priya','Rahul','Sunita','Amit','Kavita','Rohit','Neha','Vivaan','Meena'];
    const LAST  = ['Sharma','Verma','Gupta','Singh','Patel','Kumar','Mehta','Joshi','Yadav','Tiwari'];
    const ROLES = [
      [1,'PRINCIPAL','Principal'],[2,'VP','Vice Principal'],[3,'HEAD_TEACHER','Head Teacher'],
      [4,'SR_TEACHER','Senior Teacher'],[5,'CL_TEACHER','Class Teacher'],
      [6,'SUB_TEACHER','Subject Teacher'],[7,'BAK_TEACHER','Backup Teacher'],
      [8,'TMP_TEACHER','Temp Teacher'],[9,'ASST_TEACHER','Teaching Asst'],[10,'LAB_ASST','Lab Staff'],
    ];
    const STATES = ['Uttar Pradesh','Maharashtra','Karnataka','Tamil Nadu','Rajasthan',
                     'Gujarat','West Bengal','Telangana','Andhra Pradesh','Punjab'];
    const QUALS  = ['B.Ed','M.Ed','M.Sc','M.A','B.Sc','B.A','M.Phil','PhD','B.Tech','Diploma'];
    const SPECS  = ['Mathematics','Science','English','Hindi','Social Studies',
                    'Computer Science','Physical Education','Art','Music','Sanskrit'];
    const rows = [headers];
    for (let i = 1; i <= 100; i++) {
      const fn = FIRST[i % 10]; const ln = LAST[i % 10];
      const [lv, lc, lname] = ROLES[(i - 1) % 10];
      const birthYear = 1970 + (i % 30);
      rows.push([
        `EMP-T${String(i).padStart(3,'0')}`, fn, ln, `${fn} ${ln}`, i%2===0?'male':'female',
        `${fn.toLowerCase()}.${ln.toLowerCase()}${i}@school.edu.in`,
        `+9198${String(i).padStart(8,'0')}`,
        '',
        `+9198${String(i).padStart(8,'0')}`,
        `${birthYear}-${String((i%12)+1).padStart(2,'0')}-15`,
        `2024-0${(i%9)+1}-01`,
        lv, lc, lname,
        i > 1 ? `EMP-T${String(Math.max(1,i-5)).padStart(3,'0')}` : '',
        `House ${i}, Sector ${(i%30)+1}`, '', 'Noida', STATES[i%10], 'India',
        `201${String((i%900)+100)}`,
        QUALS[i%10], SPECS[i%10], (i % 20) + 1,
        lv >= 5 ? `${(i%12)+1}${['A','B','C'][i%3]}` : '',
        lv >= 4 ? SPECS[i%10] : '',
        lv === 8 ? 'TRUE' : 'FALSE',
      ]);
    }
    xlsx.utils.book_append_sheet(wb, xlsx.utils.aoa_to_sheet(rows), 'Employees (100 samples)');

    const buf = xlsx.write(wb, { type: 'buffer', bookType: 'xlsx' });
    res.setHeader('Content-Disposition', 'attachment; filename="employee_bulk_template.xlsx"');
    res.setHeader('Content-Type', 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
    res.send(buf);
  } catch (err) { next(err); }
});

// POST /employees/validate-bulk  → per-row validation (saves file, creates batch record)
router.post('/validate-bulk', authenticate, upload.single('file'), async (req, res, next) => {
  try {
    if (!req.file) return res.status(400).json({ success: false, message: 'No file uploaded' });

    const effectiveSchoolId = req.employee?.school_id || req.user.school_id;
    if (!effectiveSchoolId) {
      fs.unlink(req.file.path, () => {});
      return res.status(422).json({ success: false, message: 'school_id context required' });
    }

    // Save file permanently (used by submit endpoint via batch_id)
    const batchId   = uuid();
    const safeFilename = `${batchId}_${req.file.originalname.replace(/[^a-zA-Z0-9._-]/g, '_')}`;
    const savedPath = path.join(BULK_UPLOAD_DIR, safeFilename);
    fs.renameSync(req.file.path, savedPath);

    // Load validation messages from DB (graceful: empty object if table missing)
    let msg = {};
    try {
      const dbMsgs = await query('SELECT code, message_en FROM validation_messages WHERE entity IN (?,?)', ['employee','general']);
      dbMsgs.forEach(r => { msg[r.code] = r.message_en; });
    } catch (_) {}
    const m = (code, fallback) => msg[code] || fallback;

    const wb = xlsx.readFile(savedPath, { cellDates: true });
    const sheetName = wb.SheetNames.find(n => n !== 'Instructions') || wb.SheetNames[0];
    const rows = xlsx.utils.sheet_to_json(wb.Sheets[sheetName], { defval: '' });

    // Fetch existing employee IDs for duplicate/manager checks
    const existingIds = new Set(
      (await query('SELECT employee_id FROM employees WHERE school_id = ? AND is_active = TRUE', [effectiveSchoolId]))
        .map(r => r.employee_id)
    );
    // Also build set of empIds being uploaded (for same-batch reports_to_emp_id resolution)
    const uploadedEmpIds = new Set(
      rows.map(row => String(row['employee_id*'] || row['employee_id'] || '').trim()).filter(Boolean)
    );

    const branches = await query('SELECT id, code FROM branches WHERE school_id = ?', [effectiveSchoolId]);
    const branchByCode = {};
    branches.forEach(b => { branchByCode[b.code.toUpperCase()] = b.id; });

    const phoneRe = /^[+]?[6-9]\d{9,14}$/;
    const emailRe = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    const dateRe  = /^\d{4}-\d{2}-\d{2}$/;
    const VALID_STATES = new Set([
      'Andaman and Nicobar Islands','Andhra Pradesh','Arunachal Pradesh','Assam','Bihar',
      'Chandigarh','Chhattisgarh','Dadra and Nagar Haveli and Daman and Diu','Delhi','Goa',
      'Gujarat','Haryana','Himachal Pradesh','Jammu and Kashmir','Jharkhand','Karnataka',
      'Kerala','Ladakh','Lakshadweep','Madhya Pradesh','Maharashtra','Manipur','Meghalaya',
      'Mizoram','Nagaland','Odisha','Puducherry','Punjab','Rajasthan','Sikkim','Tamil Nadu',
      'Telangana','Tripura','Uttar Pradesh','Uttarakhand','West Bengal',
    ]);

    const results = rows.map((row, idx) => {
      const errors = []; const warnings = []; const notes = [];
      const empId     = String(row['employee_id*'] || row['employee_id'] || '').trim();
      const firstName = String(row['first_name*']  || row['first_name']  || '').trim();
      const lastName  = String(row['last_name*']   || row['last_name']   || '').trim();
      const displayName = String(row['display_name'] || '').trim();
      const email     = String(row['email*']       || row['email']       || '').trim();
      const phone     = String(row['phone*']       || row['phone']       || '').trim();
      const altPhone  = String(row['alt_phone']    || '').trim();
      const gender    = String(row['gender*']      || row['gender']      || '').trim().toLowerCase();
      const roleLevel = parseInt(row['org_role_level*'] || row['org_role_level'] || 0);
      const dob       = parseFlexDate(row['date_of_birth']);
      const doj       = parseFlexDate(row['date_of_joining*'] || row['date_of_joining']);
      const branchCode= String(row['branch_code'] || '').toUpperCase();
      const reportsTo = String(row['reports_to_emp_id'] || '').trim();
      const state     = String(row['state']   || '').trim();
      const country   = String(row['country'] || 'India').trim();
      const zipCode   = String(row['zip_code'] || '').trim();
      const qual      = String(row['qualification']  || '').trim();
      const spec      = String(row['specialization'] || '').trim();
      const expYrs    = row['experience_years'] !== '' ? parseInt(row['experience_years']) : NaN;

      // Mandatory checks
      if (!empId)                                          errors.push(m('ERR_EMP_ID_REQUIRED', 'Employee ID is required'));
      else if (!/^[A-Za-z0-9\-_]+$/.test(empId))          errors.push(m('ERR_EMP_ID_FORMAT', 'Employee ID must be alphanumeric (hyphens/underscores allowed)'));
      else if (existingIds.has(empId))                     notes.push('Employee ID already exists — existing record will be updated.');

      if (!firstName)                                      errors.push(m('ERR_FIRST_NAME_REQUIRED', 'First name is required'));
      else if (firstName.length > 100)                     errors.push(m('ERR_FIRST_NAME_LEN', 'First name must be ≤100 characters'));
      if (!lastName)                                       errors.push(m('ERR_LAST_NAME_REQUIRED', 'Last name is required'));
      else if (lastName.length > 100)                      errors.push(m('ERR_LAST_NAME_LEN', 'Last name must be ≤100 characters'));
      if (displayName && displayName.length > 150)         errors.push(m('ERR_DISPLAY_NAME_LEN', 'Display name must be ≤150 characters'));

      if (!email || !emailRe.test(email))                  errors.push(m('ERR_EMAIL_FORMAT', 'Invalid email address'));
      else if (email.length > 255)                         errors.push(m('ERR_EMAIL_LEN', 'Email must be ≤255 characters'));
      if (!phone || !phoneRe.test(phone))                  errors.push(m('ERR_PHONE_REQUIRED', 'Phone required (10-digit India mobile starting 6–9, or +91…)'));
      if (altPhone && !phoneRe.test(altPhone))             errors.push(m('ERR_ALT_PHONE_FORMAT', 'Alt phone format invalid (10-digit, starts 6-9, or +91…)'));

      if (!['male','female','other'].includes(gender))     errors.push(m('ERR_GENDER_INVALID', 'Gender must be male / female / other'));
      if (!roleLevel || roleLevel < 1 || roleLevel > 10)  errors.push(m('ERR_ROLE_LEVEL_INVALID', 'Role level must be 1–10'));
      if (branchCode && !branchByCode[branchCode])         errors.push(m('ERR_BRANCH_NOT_FOUND', `Branch code "${branchCode}" not found`));

      // Date validations
      if (dob) {
        if (!dateRe.test(dob) || isNaN(new Date(dob)))    errors.push(m('ERR_DOB_FORMAT', 'Date of birth must be YYYY-MM-DD'));
        else {
          const age = Math.floor((Date.now() - new Date(dob)) / (365.25 * 24 * 3600 * 1000));
          if (age < 18)                                    errors.push(m('ERR_DOB_UNDERAGE', 'Employee must be at least 18 years old'));
          if (age > 80)                                    warnings.push(m('WARN_DOB_VERY_OLD', 'Date of birth indicates age > 80 — please verify'));
        }
      }
      if (!doj)                                            errors.push(m('ERR_DOJ_REQUIRED', 'Date of joining is required'));
      else if (!dateRe.test(doj) || isNaN(new Date(doj))) errors.push(m('ERR_DOJ_FORMAT', 'Date of joining must be YYYY-MM-DD'));
      else if (new Date(doj) > new Date())                 warnings.push(m('WARN_DOJ_FUTURE', 'Date of joining is in the future — please verify'));

      // Optional field validation
      if (state && !VALID_STATES.has(state))               warnings.push(m('WARN_STATE_UNKNOWN', `State "${state}" is not a recognised Indian state/UT`));
      if (zipCode && !/^\d{6}$/.test(zipCode))             warnings.push(m('WARN_ZIP_FORMAT', 'ZIP/PIN should be 6 digits'));
      if (qual  && qual.length  > 100)                     errors.push(m('ERR_QUAL_LEN',  'Qualification must be ≤100 characters'));
      if (spec  && spec.length  > 100)                     errors.push(m('ERR_SPEC_LEN',  'Specialization must be ≤100 characters'));
      if (!isNaN(expYrs) && (expYrs < 0 || expYrs > 50))  errors.push(m('ERR_EXP_RANGE', 'Experience years must be 0–50'));

      // reports_to_emp_id
      if (!reportsTo) {
        notes.push('reports_to_emp_id is blank — employee will be top-level (no manager).');
      } else if (!existingIds.has(reportsTo) && !uploadedEmpIds.has(reportsTo)) {
        warnings.push(m('WARN_REPORTS_TO_MISSING', 'reports_to_emp_id not found — manager will not be linked'));
      } else if (!existingIds.has(reportsTo) && uploadedEmpIds.has(reportsTo)) {
        notes.push('reports_to_emp_id found in this upload batch — will be linked after all rows are inserted.');
      }

      return {
        row: idx + 2,
        status: errors.length > 0 ? 'failed' : warnings.length > 0 ? 'warning' : 'success',
        errors,
        warnings,
        notes,
        data: { empId, firstName, lastName, email, phone, gender, roleLevel, doj, branchCode, reportsTo,
                branchId: branchByCode[branchCode] || null, raw: row },
      };
    });

    const totalOk   = results.filter(r => r.status !== 'failed').length;
    const totalFail = results.filter(r => r.status === 'failed').length;
    const canSubmit = totalFail === 0;

    // Persist batch record so submit can use saved file (status='processing' until submitted)
    await query(
      `INSERT INTO bulk_batches (id, school_id, type, filename, file_url, total_rows, status, uploaded_by)
       VALUES (?, ?, 'employees', ?, ?, ?, 'processing', ?)`,
      [batchId, effectiveSchoolId, req.file.originalname, savedPath, rows.length, req.user.id]
    );

    res.json({ success: true, data: { results, totalOk, totalFail, canSubmit, batchId } });
  } catch (err) {
    try { if (req.file) fs.unlinkSync(req.file.path); } catch (_) {}
    next(err);
  }
});

// POST /employees/bulk  → insert rows from previously validated batch (uses saved file)
router.post('/bulk', authenticate, requireRole('super_admin','school_owner','principal','vp'), async (req, res, next) => {
  try {
    const { batch_id } = req.body;
    if (!batch_id) return res.status(400).json({ success: false, message: 'batch_id is required' });

    const [batch] = await query('SELECT * FROM bulk_batches WHERE id = ?', [batch_id]);
    if (!batch) return res.status(404).json({ success: false, message: 'Batch not found' });
    if (batch.status === 'completed') return res.status(409).json({ success: false, message: 'Batch already submitted' });

    const effectiveSchoolId = batch.school_id;
    const uploadedBy = req.user.id;

    await query('UPDATE bulk_batches SET status = ? WHERE id = ?', ['processing', batch_id]);

    const wb = xlsx.readFile(batch.file_url, { cellDates: true });
    const sheetName = wb.SheetNames.find(n => n !== 'Instructions') || wb.SheetNames[0];
    const rows = xlsx.utils.sheet_to_json(wb.Sheets[sheetName], { defval: '' });

    const branches = await query('SELECT id, code FROM branches WHERE school_id = ?', [effectiveSchoolId]);
    const branchByCode = {};
    branches.forEach(b => { branchByCode[b.code.toUpperCase()] = b.id; });

    const orgRoles = await query('SELECT id, level, code FROM org_roles WHERE school_id = ? AND is_active = TRUE', [effectiveSchoolId]);
    const roleByLevel = {}; const roleByCode = {};
    orgRoles.forEach(r => { roleByLevel[r.level] = r.id; if (r.code) roleByCode[r.code.toUpperCase()] = r.id; });

    // Build map of existing active employee_id → uuid for reports_to_emp_id resolution
    const existingEmps = await query('SELECT id, employee_id FROM employees WHERE school_id = ? AND is_active = TRUE', [effectiveSchoolId]);
    const empIdToUuid = {};
    existingEmps.forEach(e => { empIdToUuid[e.employee_id] = e.id; });

    let inserted = 0; let skipped = 0; let replaced = 0;
    for (const row of rows) {
      try {
        const empId  = String(row['employee_id*'] || row['employee_id'] || '').trim();
        const fn     = String(row['first_name*']  || row['first_name']  || '').trim();
        const ln     = String(row['last_name*']   || row['last_name']   || '').trim();
        const dn     = String(row['display_name'] || '').trim() || `${fn} ${ln}`.trim();
        const email  = String(row['email*']       || row['email']       || '').trim();
        const phone  = String(row['phone*']       || row['phone']       || '').trim();
        const altPh  = String(row['alt_phone']    || '').trim() || null;
        const wapp   = String(row['whatsapp_no']  || phone).trim();
        const gender = String(row['gender*']      || row['gender']      || 'other').trim().toLowerCase();

        const doj    = parseFlexDate(row['date_of_joining*'] || row['date_of_joining']) || null;
        const dob    = parseFlexDate(row['date_of_birth']) || null;
        const lvl    = parseInt(row['org_role_level*'] || row['org_role_level'] || 0);
        const rc     = String(row['org_role_code'] || '').toUpperCase();
        const bc     = String(row['branch_code']  || '').toUpperCase();
        const reportsToEmpId = String(row['reports_to_emp_id'] || '').trim();
        const isTemp = String(row['is_temp'] || '').toUpperCase() === 'TRUE';
        const classes = String(row['assigned_classes'] || '').trim();
        const addr1  = String(row['address_line1'] || '').trim() || null;
        const addr2  = String(row['address_line2'] || '').trim() || null;
        const city   = String(row['city']   || '').trim() || null;
        const state  = String(row['state']  || '').trim() || null;
        const country= String(row['country'] || 'India').trim();
        const zip    = String(row['zip_code'] || '').trim() || null;
        const qual   = String(row['qualification']  || '').trim() || null;
        const spec   = String(row['specialization'] || '').trim() || null;
        const expRaw = row['experience_years'];
        const expYrs = expRaw !== '' && expRaw !== undefined ? parseInt(expRaw) : null;

        if (!empId || !fn || !ln || !email || !phone) { skipped++; continue; }
        const orgRoleId = roleByCode[rc] || roleByLevel[lvl];
        if (!orgRoleId) { skipped++; continue; }

        const branchId = branchByCode[bc] || null;
        // Resolve reports_to_emp_id — includes employees inserted earlier in this same loop
        const reportsToUuid = reportsToEmpId ? (empIdToUuid[reportsToEmpId] || null) : null;

        const assignedClassesJson = JSON.stringify(classes ? classes.split(',').map(c => c.trim()).filter(Boolean) : []);

        if (empIdToUuid[empId]) {
          // Employee already exists — UPDATE in place (bulk upload = upsert)
          await query(
            `UPDATE employees SET branch_id=?, org_role_id=?, reports_to_emp_id=?,
              first_name=?, last_name=?, display_name=?, email=?, phone=?, alt_phone=?, whatsapp_no=?,
              gender=?, date_of_birth=?, date_of_joining=?,
              address_line1=?, address_line2=?, city=?, state=?, country=?, zip_code=?,
              qualification=?, specialization=?, experience_years=?,
              assigned_classes=?, is_temp=?,
              bulk_upload_batch=?, is_active=TRUE, date_of_leaving=NULL
             WHERE school_id=? AND employee_id=?`,
            [branchId, orgRoleId, reportsToUuid,
             fn, ln, dn, email, phone, altPh, wapp,
             gender, dob, doj,
             addr1, addr2, city, state, country, zip,
             qual, spec, isNaN(expYrs) ? null : expYrs,
             assignedClassesJson, isTemp,
             batch_id, effectiveSchoolId, empId]
          );
          replaced++;
        } else {
          const newId = uuid();
          await query(
            `INSERT INTO employees
               (id, school_id, branch_id, employee_id, org_role_id,
                reports_to_emp_id, first_name, last_name, display_name, email, phone, alt_phone, whatsapp_no,
                gender, date_of_birth, date_of_joining,
                address_line1, address_line2, city, state, country, zip_code,
                qualification, specialization, experience_years,
                assigned_classes, is_temp,
                is_active, bulk_upload_batch, created_by)
             VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,TRUE,?,?)`,
            [newId, effectiveSchoolId, branchId, empId, orgRoleId,
             reportsToUuid, fn, ln, dn, email, phone, altPh, wapp,
             gender, dob, doj,
             addr1, addr2, city, state, country, zip,
             qual, spec, isNaN(expYrs) ? null : expYrs,
             assignedClassesJson, isTemp,
             batch_id, uploadedBy]
          );
          empIdToUuid[empId] = newId;
        }
        inserted++;
      } catch (rowErr) {
        console.error('[bulk] row skipped:', rowErr.message);
        skipped++;
      }
    }

    await query(
      `UPDATE bulk_batches SET status='completed', success_rows=?, failed_rows=? WHERE id=?`,
      [inserted, skipped, batch_id]
    );

    res.json({ success: true, data: { inserted, replaced, skipped, total: rows.length, batch_id } });
  } catch (err) {
    try { await query('UPDATE bulk_batches SET status=? WHERE id=?', ['failed', req.body?.batch_id]); } catch (_) {}
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
              e.branch_id, b.name AS branch_name
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

// GET /employees/bulk-history  → upload history for school
router.get('/bulk-history', authenticate, async (req, res, next) => {
  try {
    const effectiveSchoolId = req.employee?.school_id || req.user.school_id;
    if (!effectiveSchoolId) return res.json({ success: true, data: [] });
    const batches = await query(
      `SELECT bb.id, bb.filename, bb.total_rows, bb.success_rows, bb.failed_rows,
              bb.status, bb.created_at,
              CONCAT(u.first_name, ' ', u.last_name) AS uploaded_by_name,
              u.email AS uploaded_by_email
       FROM bulk_batches bb
       JOIN users u ON u.id = bb.uploaded_by
       WHERE bb.school_id = ? AND bb.type = 'employees'
       ORDER BY bb.created_at DESC
       LIMIT 100`,
      [effectiveSchoolId]
    );
    res.json({ success: true, data: batches });
  } catch (err) { next(err); }
});

// GET /employees/bulk-history/:batchId/report  → download validation report as XLSX
router.get('/bulk-history/:batchId/report', authenticate, async (req, res, next) => {
  try {
    const [batch] = await query('SELECT * FROM bulk_batches WHERE id = ?', [req.params.batchId]);
    if (!batch) return res.status(404).json({ success: false, message: 'Batch not found' });

    if (!batch.file_url || !fs.existsSync(batch.file_url)) {
      return res.status(404).json({ success: false, message: 'File no longer available' });
    }

    const wb = xlsx.readFile(batch.file_url, { cellDates: true });
    const sheetName = wb.SheetNames.find(n => n !== 'Instructions') || wb.SheetNames[0];
    const rows = xlsx.utils.sheet_to_json(wb.Sheets[sheetName], { defval: '' });

    const effectiveSchoolId = batch.school_id;
    const existingIds = new Set(
      (await query('SELECT employee_id FROM employees WHERE school_id = ? AND is_active = TRUE', [effectiveSchoolId]))
        .map(r => r.employee_id)
    );
    const uploadedEmpIds = new Set(
      rows.map(row => String(row['employee_id*'] || row['employee_id'] || '').trim()).filter(Boolean)
    );
    const branches = await query('SELECT id, code FROM branches WHERE school_id = ?', [effectiveSchoolId]);
    const branchByCode = {};
    branches.forEach(b => { branchByCode[b.code.toUpperCase()] = b.id; });

    const phoneRe = /^[+]?[6-9]\d{9,14}$/;
    const emailRe = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    const dateRe2 = /^\d{4}-\d{2}-\d{2}$/;
    const VALID_STATES2 = new Set([
      'Andaman and Nicobar Islands','Andhra Pradesh','Arunachal Pradesh','Assam','Bihar',
      'Chandigarh','Chhattisgarh','Dadra and Nagar Haveli and Daman and Diu','Delhi','Goa',
      'Gujarat','Haryana','Himachal Pradesh','Jammu and Kashmir','Jharkhand','Karnataka',
      'Kerala','Ladakh','Lakshadweep','Madhya Pradesh','Maharashtra','Manipur','Meghalaya',
      'Mizoram','Nagaland','Odisha','Puducherry','Punjab','Rajasthan','Sikkim','Tamil Nadu',
      'Telangana','Tripura','Uttar Pradesh','Uttarakhand','West Bengal',
    ]);

    const reportRows = [['Row', 'Employee ID', 'Name', 'Status', 'Errors', 'Warnings', 'Notes']];
    rows.forEach((row, idx) => {
      const errors = []; const warnings = []; const notes = [];
      const empId     = String(row['employee_id*'] || row['employee_id'] || '').trim();
      const firstName = String(row['first_name*']  || row['first_name']  || '').trim();
      const lastName  = String(row['last_name*']   || row['last_name']   || '').trim();
      const email     = String(row['email*']       || row['email']       || '').trim();
      const phone     = String(row['phone*']       || row['phone']       || '').trim();
      const altPhone  = String(row['alt_phone']    || '').trim();
      const gender    = String(row['gender*']      || row['gender']      || '').trim().toLowerCase();
      const roleLevel = parseInt(row['org_role_level*'] || row['org_role_level'] || 0);
      const dob       = parseFlexDate(row['date_of_birth']);
      const doj       = parseFlexDate(row['date_of_joining*'] || row['date_of_joining']);
      const branchCode= String(row['branch_code'] || '').toUpperCase();
      const reportsTo = String(row['reports_to_emp_id'] || '').trim();
      const state     = String(row['state'] || '').trim();
      const zipCode   = String(row['zip_code'] || '').trim();
      const qual      = String(row['qualification']  || '').trim();
      const spec      = String(row['specialization'] || '').trim();
      const expYrs    = row['experience_years'] !== '' ? parseInt(row['experience_years']) : NaN;

      if (!empId)                                         errors.push('Employee ID is required');
      else if (!/^[A-Za-z0-9\-_]+$/.test(empId))         errors.push('Employee ID must be alphanumeric');
      else if (existingIds.has(empId))                    notes.push('Existing record will be updated.');
      if (!firstName)                                     errors.push('First name is required');
      else if (firstName.length > 100)                    errors.push('First name must be ≤100 characters');
      if (!lastName)                                      errors.push('Last name is required');
      else if (lastName.length > 100)                     errors.push('Last name must be ≤100 characters');
      if (!email || !emailRe.test(email))                 errors.push('Invalid email address');
      if (!phone || !phoneRe.test(phone))                 errors.push('Phone required (10-digit India mobile, starts 6-9)');
      if (altPhone && !phoneRe.test(altPhone))            errors.push('Alt phone format invalid');
      if (!['male','female','other'].includes(gender))    errors.push('Gender must be male/female/other');
      if (!roleLevel || roleLevel < 1 || roleLevel > 10) errors.push('Role level must be 1–10');
      if (branchCode && !branchByCode[branchCode])        errors.push(`Branch code "${branchCode}" not found`);
      if (dob) {
        if (!dateRe2.test(dob) || isNaN(new Date(dob)))  errors.push('Date of birth must be YYYY-MM-DD');
        else {
          const age = Math.floor((Date.now() - new Date(dob)) / (365.25 * 24 * 3600 * 1000));
          if (age < 18)                                   errors.push('Employee must be at least 18 years old');
          if (age > 80)                                   warnings.push('Date of birth indicates age > 80 — verify');
        }
      }
      if (!doj)                                           errors.push('Date of joining is required');
      else if (!dateRe2.test(doj) || isNaN(new Date(doj))) errors.push('Date of joining must be YYYY-MM-DD');
      else if (new Date(doj) > new Date())                warnings.push('Date of joining is in the future');
      if (state && !VALID_STATES2.has(state))             warnings.push(`State "${state}" not a recognised Indian state/UT`);
      if (zipCode && !/^\d{6}$/.test(zipCode))            warnings.push('ZIP/PIN should be 6 digits');
      if (qual && qual.length > 100)                      errors.push('Qualification must be ≤100 characters');
      if (spec && spec.length > 100)                      errors.push('Specialization must be ≤100 characters');
      if (!isNaN(expYrs) && (expYrs < 0 || expYrs > 50)) errors.push('Experience years must be 0–50');
      if (!reportsTo) {
        notes.push('No manager — top-level employee.');
      } else if (!existingIds.has(reportsTo) && !uploadedEmpIds.has(reportsTo)) {
        warnings.push('reports_to_emp_id not found — will be left blank');
      } else if (!existingIds.has(reportsTo) && uploadedEmpIds.has(reportsTo)) {
        notes.push('Manager is in this upload batch — will be linked after insertion.');
      }

      const status = errors.length > 0 ? 'FAILED' : warnings.length > 0 ? 'WARNING' : 'OK';
      reportRows.push([
        idx + 2,
        empId,
        `${firstName} ${lastName}`.trim(),
        status,
        errors.join('; '),
        warnings.join('; '),
        notes.join('; '),
      ]);
    });

    const reportWb = xlsx.utils.book_new();
    xlsx.utils.book_append_sheet(reportWb, xlsx.utils.aoa_to_sheet(reportRows), 'Validation Report');
    const buf = xlsx.write(reportWb, { type: 'buffer', bookType: 'xlsx' });
    const reportName = `validation_report_${batch.filename.replace(/[^a-zA-Z0-9._-]/g,'_')}`;
    res.setHeader('Content-Disposition', `attachment; filename="${reportName}"`);
    res.setHeader('Content-Type', 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
    res.send(buf);
  } catch (err) { next(err); }
});

// Export employees as XLSX
router.get('/export', authenticate, async (req, res, next) => {
  try {
    const { school_id, branch_id, org_role_id, search, include_inactive, include_hidden, ids } = req.query;
    let where = [];
    let params = [];

    if (include_inactive !== 'true') where.push('e.is_active = TRUE');
    if (include_hidden !== 'true') where.push('(e.is_hidden IS NULL OR e.is_hidden = FALSE)');

    const isSchoolScoped = req.user.role === 'super_admin' || req.user.role === 'school_owner';
    const effectiveSchoolId = isSchoolScoped
      ? (school_id || req.employee?.school_id || req.user.school_id)
      : req.employee?.school_id;

    if (req.user.role !== 'super_admin' && !effectiveSchoolId) {
      return res.status(422).json({ success: false, message: 'school_id required' });
    }

    if (effectiveSchoolId) { where.push('e.school_id = ?'); params.push(effectiveSchoolId); }
    if (branch_id)   { where.push('e.branch_id = ?');   params.push(branch_id); }
    if (org_role_id) { where.push('e.org_role_id = ?'); params.push(org_role_id); }
    if (search)      { where.push('(e.first_name LIKE ? OR e.last_name LIKE ? OR e.employee_id LIKE ?)'); params.push(`%${search}%`, `%${search}%`, `%${search}%`); }
    if (ids) {
      const idList = ids.split(',').filter(Boolean);
      if (idList.length > 0) {
        where.push(`e.id IN (${idList.map(() => '?').join(',')})`);
        params.push(...idList);
      }
    }

    const whereClause = where.length > 0 ? `WHERE ${where.join(' AND ')}` : '';
    const employees = await query(
      `SELECT e.employee_id, e.first_name, e.last_name, e.email, e.phone,
              r.name AS role_name, r.level AS role_level,
              b.name AS branch_name, sch.name AS school_name,
              CONCAT(IFNULL(m.first_name,''),' ',IFNULL(m.last_name,'')) AS manager_name,
              e.gender, e.date_of_birth, e.date_of_joining,
              e.qualification, e.specialization, e.experience_years,
              e.address_line1, e.city, e.state, e.country,
              e.is_active
       FROM employees e
       JOIN org_roles r ON r.id = e.org_role_id
       JOIN schools sch ON sch.id = e.school_id
       LEFT JOIN branches b ON b.id = e.branch_id
       LEFT JOIN employees m ON m.id = e.reports_to_emp_id
       ${whereClause}
       ORDER BY r.level, e.last_name, e.first_name`, params
    );

    const wb = xlsx.utils.book_new();
    const headers = [
      'Employee ID','First Name','Last Name','Email','Phone',
      'Role','Level','Branch','School','Manager',
      'Gender','Date of Birth','Date of Joining',
      'Qualification','Specialization','Experience Yrs',
      'Address','City','State','Country','Status'
    ];
    const rows = employees.map(e => [
      e.employee_id, e.first_name, e.last_name, e.email, e.phone,
      e.role_name, e.role_level, e.branch_name || '', e.school_name, (e.manager_name || '').trim(),
      e.gender || '', e.date_of_birth || '', e.date_of_joining || '',
      e.qualification || '', e.specialization || '', e.experience_years || '',
      e.address_line1 || '', e.city || '', e.state || '', e.country || '',
      e.is_active ? 'Active' : 'Inactive'
    ]);

    const ws = xlsx.utils.aoa_to_sheet([headers, ...rows]);
    ws['!cols'] = headers.map(() => ({ wch: 18 }));
    xlsx.utils.book_append_sheet(wb, ws, 'Employees');

    const buf = xlsx.write(wb, { type: 'buffer', bookType: 'xlsx' });
    res.setHeader('Content-Type', 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
    res.setHeader('Content-Disposition', `attachment; filename=employees_export.xlsx`);
    res.send(buf);
  } catch (err) { next(err); }
});

// GET /:id — placed AFTER all static routes to avoid shadowing them
router.get('/:id', authenticate, async (req, res, next) => {
  try {
    const [emp] = await query(
      `SELECT e.*, r.name AS role_name, r.level AS role_level,
              COALESCE(e.can_approve, r.can_approve) AS can_approve,
              COALESCE(e.can_upload_bulk, r.can_upload_bulk) AS can_upload_bulk,
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

      const wb = xlsx.readFile(req.file.path, { cellDates: true });
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

        // If employee already exists for this school, mark prior record inactive
        const [dup] = await query(
          'SELECT id FROM employees WHERE school_id = ? AND employee_id = ? AND is_active = TRUE',
          [effectiveSchoolId, row.employee_id.toString().trim()]
        );
        if (dup) {
          await query(
            'UPDATE employees SET is_active = FALSE WHERE school_id = ? AND employee_id = ? AND is_active = TRUE',
            [effectiveSchoolId, row.employee_id.toString().trim()]
          );
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
               qualification, specialization, bulk_upload_batch, is_active, created_by)
             VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,TRUE,?)`,
            [empId, effectiveSchoolId, branch_id,
             row.employee_id.toString().trim(),
             roleRow.id,
             row.first_name.toString().trim(),
             row.last_name.toString().trim(),
             row.gender?.toLowerCase() || null,
             parseFlexDate(row.date_of_birth) || null,
             row.email || null,
             row.phone || null,
             row.whatsapp_no || row.phone || null,
             parseFlexDate(row.date_of_joining) || null,
             row.address || null,
             row.city || null,
             row.state || null,
             row.country || 'India',
             row.zip_code || null,
             row.qualification || null,
             row.specialization || null,
             batchId,
             req.user.id]
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

// ============================================================
// STAGING-BASED BULK UPLOAD (New flow: stage → validate → report → confirm)
// POST /employees/bulk-upload/stage
// GET  /employees/bulk-upload/:batchId/results
// GET  /employees/bulk-upload/:batchId/report  (also served via legacy bulk-history/:id/report)
// POST /employees/bulk-upload/:batchId/confirm
// GET  /employees/bulk-upload/history
// ============================================================

router.post('/bulk-upload/stage',
  authenticate,
  requireRole('super_admin','school_owner','principal','vp','head_teacher'),
  upload.single('file'),
  async (req, res, next) => {
    if (!req.file) return res.status(400).json({ success: false, message: 'No file uploaded' });

    const batchId = uuid();
    const effectiveSchoolId = req.user.role === 'super_admin'
      ? (req.body.school_id || req.employee?.school_id || req.user.school_id)
      : (req.employee?.school_id || req.user.school_id);
    const branchId = req.body.branch_id || req.employee?.branch_id || null;

    if (!effectiveSchoolId) {
      fs.unlink(req.file.path, () => {});
      return res.status(422).json({ success: false, message: 'school_id context required' });
    }

    try {
      const dbMsgs = await query('SELECT code, message_en FROM validation_messages WHERE entity IN (?,?)', ['employee','general']);
      const msg = {}; dbMsgs.forEach(r => { msg[r.code] = r.message_en; });
      const m = (code, fallback) => msg[code] || fallback;

      const wb = xlsx.readFile(req.file.path, { cellDates: true });
      const sheetName = wb.SheetNames.find(n => n !== 'Instructions') || wb.SheetNames[0];
      const rows = xlsx.utils.sheet_to_json(wb.Sheets[sheetName], { defval: '' });
      try { fs.unlinkSync(req.file.path); } catch (_) {}

      if (!rows.length) return res.status(400).json({ success: false, message: 'File contains no data rows' });

      // Pre-load reference data
      const existingEmps = new Set(
        (await query('SELECT employee_id FROM employees WHERE school_id = ? AND is_active = TRUE', [effectiveSchoolId]))
          .map(r => r.employee_id)
      );
      const uploadedEmpIds = new Set(
        rows.map(row => String(row['employee_id*'] || row['employee_id'] || '').trim()).filter(Boolean)
      );
      const branches = await query('SELECT id, code FROM branches WHERE school_id = ?', [effectiveSchoolId]);
      const branchByCode = {}; branches.forEach(b => { branchByCode[b.code.toUpperCase()] = b.id; });
      const orgRoles = await query('SELECT id, code, level FROM org_roles WHERE school_id = ? AND is_active = TRUE', [effectiveSchoolId]);
      const roleByCode = {}; const roleById = {};
      orgRoles.forEach(r => { if (r.code) roleByCode[r.code.toUpperCase()] = r; roleById[r.id] = r; });

      const phoneRe = /^[+]?[6-9]\d{9,14}$/;
      const emailRe = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

      await query(
        `INSERT INTO bulk_batches (id, school_id, branch_id, type, filename, status, uploaded_by)
         VALUES (?, ?, ?, 'employees', ?, 'staged', ?)`,
        [batchId, effectiveSchoolId, branchId, req.file.originalname, req.user.id]
      );

      let successCount = 0; let warningCount = 0; let failCount = 0;
      const validationResults = [];

      for (let idx = 0; idx < rows.length; idx++) {
        const row = rows[idx];
        const rowNo = idx + 2;

        const empId     = String(row['employee_id*'] || row['employee_id'] || '').trim();
        const firstName = String(row['first_name*']  || row['first_name']  || '').trim();
        const lastName  = String(row['last_name*']   || row['last_name']   || '').trim();
        const email     = String(row['email*']       || row['email']       || '').trim();
        const phone     = String(row['phone*']       || row['phone']       || '').trim();
        const gender    = String(row['gender*']      || row['gender']      || '').trim().toLowerCase();
        const roleCode  = String(row['org_role_code*']|| row['org_role_code'] || '').trim().toUpperCase();
        const branchCode= String(row['branch_code']  || '').trim().toUpperCase();
        const doj       = parseFlexDate(row['date_of_joining*'] || row['date_of_joining']);
        const reportsTo = String(row['reports_to_emp_id'] || '').trim();

        const errors = []; const warnings = []; const notes = [];

        if (!empId)   errors.push(m('ERR_EMP_ID_REQUIRED', 'Employee ID is required'));
        else if (!/^[A-Za-z0-9\-_]+$/.test(empId)) errors.push(m('ERR_EMP_ID_FORMAT', 'Employee ID must be alphanumeric'));

        if (!firstName) errors.push(m('ERR_FIRST_NAME_REQUIRED', 'First name is required'));
        if (!lastName)  errors.push(m('ERR_LAST_NAME_REQUIRED',  'Last name is required'));
        if (!email || !emailRe.test(email))  errors.push(m('ERR_EMAIL_FORMAT', 'Invalid email address'));
        if (!phone || !phoneRe.test(phone))  errors.push(m('ERR_PHONE_REQUIRED', 'Phone number required (10 digits, starts 6-9)'));
        if (!['male','female','other'].includes(gender)) errors.push(m('ERR_GENDER_INVALID', 'Gender must be male/female/other'));
        if (!roleCode || !roleByCode[roleCode]) errors.push(m('ERR_ROLE_CODE_INVALID', `org_role_code "${roleCode}" not found`));
        if (branchCode && !branchByCode[branchCode]) errors.push(m('ERR_BRANCH_NOT_FOUND', 'Branch code not found'));
        if (doj && new Date(doj) > new Date()) warnings.push(m('WARN_DOJ_FUTURE', 'Date of joining is in the future'));

        if (empId && existingEmps.has(empId)) {
          notes.push('Employee ID exists — existing record will be updated (SCD: old marked inactive)');
        }
        if (!reportsTo) {
          notes.push('No manager assigned — employee will be top-level');
        } else if (!existingEmps.has(reportsTo) && !uploadedEmpIds.has(reportsTo)) {
          warnings.push('reports_to_emp_id not found — will be left blank');
        } else if (!existingEmps.has(reportsTo) && uploadedEmpIds.has(reportsTo)) {
          notes.push('Manager is in this upload batch — will be linked after insertion');
        }

        const resolvedRoleId = roleByCode[roleCode]?.id || null;
        const resolvedBranchId = branchByCode[branchCode] || branchId || null;

        const status = errors.length > 0 ? 'failed' : warnings.length > 0 ? 'warning' : 'success';
        if (status === 'success') successCount++;
        else if (status === 'warning') warningCount++;
        else failCount++;

        await query(
          `INSERT INTO employee_staging
             (id, batch_id, row_number, school_id, branch_id, branch_code,
              employee_id, first_name, last_name, gender, email, phone,
              date_of_joining, org_role_code, org_role_id, reports_to_emp_id,
              qualification, specialization,
              address_line1, city, state, country, zip_code,
              effective_start_date, change_reason,
              validation_status, validation_errors, validation_warnings, validation_notes, raw_row)
           VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)`,
          [uuid(), batchId, rowNo, effectiveSchoolId, resolvedBranchId, branchCode || null,
           empId || null, firstName || null, lastName || null, gender || null,
           email || null, phone || null,
           doj || null, roleCode || null, resolvedRoleId,
           reportsTo || null,
           String(row['qualification'] || '').trim() || null,
           String(row['specialization'] || '').trim() || null,
           String(row['address_line1'] || row['address'] || '').trim() || null,
           String(row['city'] || '').trim() || null,
           String(row['state'] || '').trim() || null,
           String(row['country'] || 'India').trim(),
           String(row['zip_code'] || '').trim() || null,
           String(row['effective_start_date'] || '').trim() || null,
           String(row['change_reason'] || '').trim() || null,
           status, JSON.stringify(errors), JSON.stringify(warnings), JSON.stringify(notes),
           JSON.stringify(row)]
        );

        validationResults.push({
          row: rowNo, status, errors, warnings, notes,
          data: { empId, firstName, lastName, email, phone, gender, roleCode, branchCode, reportsTo, raw: row },
        });
      }

      await query(
        `UPDATE bulk_batches SET status='validated', total_rows=?, success_rows=?, warning_rows=?, failed_rows=? WHERE id=?`,
        [rows.length, successCount, warningCount, failCount, batchId]
      );

      res.json({
        success: true,
        data: {
          batchId,
          results: validationResults,
          totalOk: successCount,
          totalWarn: warningCount,
          totalFail: failCount,
          canSubmit: (successCount + warningCount) > 0,
        },
      });
    } catch (err) {
      try { fs.unlinkSync(req.file.path); } catch (_) {}
      try { await query("UPDATE bulk_batches SET status='failed' WHERE id=?", [batchId]); } catch (_) {}
      next(err);
    }
  }
);

router.get('/bulk-upload/history', authenticate, async (req, res, next) => {
  try {
    const effectiveSchoolId = req.employee?.school_id || req.user.school_id;
    if (!effectiveSchoolId) return res.json({ success: true, data: [] });
    const batches = await query(
      `SELECT bb.id, bb.filename, bb.total_rows, bb.success_rows, bb.warning_rows, bb.failed_rows,
              bb.status, bb.created_at, bb.confirmed_at,
              u1.display_name AS uploaded_by_name, u2.display_name AS confirmed_by_name
       FROM bulk_batches bb
       LEFT JOIN users u1 ON u1.id = bb.uploaded_by
       LEFT JOIN users u2 ON u2.id = bb.confirmed_by
       WHERE bb.school_id = ? AND bb.type = 'employees'
       ORDER BY bb.created_at DESC LIMIT 100`,
      [effectiveSchoolId]
    );
    res.json({ success: true, data: batches });
  } catch (err) { next(err); }
});

router.get('/bulk-upload/:batchId/results', authenticate, async (req, res, next) => {
  try {
    const { status, page = 1, limit = 100 } = req.query;
    const offset = (page - 1) * limit;
    let where = ['batch_id = ?']; const params = [req.params.batchId];
    if (status) { where.push('validation_status = ?'); params.push(status); }
    const rows = await query(
      `SELECT id, row_number, employee_id, first_name, last_name, org_role_code,
              validation_status, validation_errors, validation_warnings, validation_notes
       FROM employee_staging WHERE ${where.join(' AND ')} ORDER BY row_number LIMIT ? OFFSET ?`,
      [...params, +limit, +offset]
    );
    const [{ total }] = await query(`SELECT COUNT(*) AS total FROM employee_staging WHERE ${where.join(' AND ')}`, params);
    res.json({ success: true, data: rows, meta: { total, page: +page, limit: +limit } });
  } catch (err) { next(err); }
});

router.get('/bulk-upload/:batchId/report', authenticate, async (req, res, next) => {
  try {
    const [batch] = await query('SELECT * FROM bulk_batches WHERE id = ?', [req.params.batchId]);
    if (!batch) return res.status(404).json({ success: false, message: 'Batch not found' });

    const stagingRows = await query(
      `SELECT row_number, employee_id, first_name, last_name, email, phone, gender,
              org_role_code, branch_code, date_of_joining, reports_to_emp_id,
              validation_status, validation_errors, validation_warnings, validation_notes
       FROM employee_staging WHERE batch_id = ? ORDER BY row_number`,
      [req.params.batchId]
    );

    const wb = xlsx.utils.book_new();
    xlsx.utils.book_append_sheet(wb, xlsx.utils.aoa_to_sheet([
      ['Batch ID', batch.id], ['Filename', batch.filename],
      ['Uploaded On', batch.created_at], ['Total Rows', batch.total_rows],
      ['Success', batch.success_rows], ['Warning', batch.warning_rows],
      ['Failed', batch.failed_rows], ['Status', batch.status],
    ]), 'Summary');

    const headers = ['Row','Employee ID','First Name','Last Name','Email','Phone','Gender','Role Code','Branch','DOJ','Manager ID','Status','Errors','Warnings','Notes'];
    const allRows = [headers, ...stagingRows.map(r => [
      r.row_number, r.employee_id, r.first_name, r.last_name, r.email, r.phone, r.gender,
      r.org_role_code, r.branch_code, r.date_of_joining, r.reports_to_emp_id,
      r.validation_status.toUpperCase(),
      (JSON.parse(r.validation_errors || '[]')).join('; '),
      (JSON.parse(r.validation_warnings || '[]')).join('; '),
      (JSON.parse(r.validation_notes || '[]')).join('; '),
    ])];
    const ws = xlsx.utils.aoa_to_sheet(allRows);
    ws['!cols'] = headers.map(() => ({ wch: 16 }));
    xlsx.utils.book_append_sheet(wb, ws, 'All Rows');

    const failedRows = stagingRows.filter(r => r.validation_status === 'failed');
    if (failedRows.length) {
      xlsx.utils.book_append_sheet(wb,
        xlsx.utils.aoa_to_sheet([headers, ...failedRows.map(r => [
          r.row_number, r.employee_id, r.first_name, r.last_name, r.email, r.phone, r.gender,
          r.org_role_code, r.branch_code, r.date_of_joining, r.reports_to_emp_id,
          'FAILED', (JSON.parse(r.validation_errors || '[]')).join('; '), '', '',
        ])]),
        'Failed Rows'
      );
    }

    const buf = xlsx.write(wb, { type: 'buffer', bookType: 'xlsx' });
    const name = `employee_validation_${batch.filename.replace(/[^a-zA-Z0-9._-]/g,'_')}`;
    res.setHeader('Content-Disposition', `attachment; filename="${name}"`);
    res.setHeader('Content-Type', 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
    res.send(buf);
  } catch (err) { next(err); }
});

router.post('/bulk-upload/:batchId/confirm',
  authenticate,
  requireRole('super_admin','school_owner','principal','vp'),
  async (req, res, next) => {
    try {
      const [batch] = await query('SELECT * FROM bulk_batches WHERE id = ?', [req.params.batchId]);
      if (!batch) return res.status(404).json({ success: false, message: 'Batch not found' });
      if (batch.status === 'completed') return res.status(409).json({ success: false, message: 'Batch already confirmed' });

      const userId = req.user?.id;
      await query("UPDATE bulk_batches SET status='processing' WHERE id=?", [req.params.batchId]);

      const stagingRows = await query(
        `SELECT * FROM employee_staging WHERE batch_id = ? AND validation_status IN ('success','warning') ORDER BY row_number`,
        [req.params.batchId]
      );

      const orgRoles = await query('SELECT id, code, level FROM org_roles WHERE school_id = ? AND is_active = TRUE', [batch.school_id]);
      const roleByCode = {}; orgRoles.forEach(r => { if (r.code) roleByCode[r.code.toUpperCase()] = r.id; });

      // Build existing emp map for reports_to resolution
      const existingEmps = await query('SELECT id, employee_id FROM employees WHERE school_id = ? AND is_active = TRUE', [batch.school_id]);
      const empIdToUuid = {}; existingEmps.forEach(e => { empIdToUuid[e.employee_id] = e.id; });

      let inserted = 0; let replaced = 0; let skipped = 0;

      for (const stg of stagingRows) {
        try {
          const orgRoleId = stg.org_role_id || roleByCode[stg.org_role_code?.toUpperCase()];
          if (!orgRoleId) { skipped++; continue; }

          const reportsToUuid = stg.reports_to_emp_id ? (empIdToUuid[stg.reports_to_emp_id] || null) : null;

          if (empIdToUuid[stg.employee_id]) {
            // SCD: mark old inactive, insert new
            await query(
              `UPDATE employees SET is_active = FALSE, effective_end_date = NOW()
               WHERE school_id = ? AND employee_id = ? AND is_active = TRUE`,
              [batch.school_id, stg.employee_id]
            );
            replaced++;
          } else {
            inserted++;
          }

          const newId = uuid();
          await query(
            `INSERT INTO employees
               (id, school_id, branch_id, employee_id, org_role_id,
                reports_to_emp_id, first_name, last_name, email, phone, whatsapp_no,
                gender, date_of_joining, qualification, specialization,
                address_line1, city, state, country, zip_code,
                effective_start_date, is_active, bulk_upload_batch, created_by)
             VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,TRUE,?,?)`,
            [newId, batch.school_id, stg.branch_id, stg.employee_id, orgRoleId,
             reportsToUuid, stg.first_name, stg.last_name, stg.email, stg.phone, stg.phone,
             stg.gender, stg.date_of_joining || null,
             stg.qualification, stg.specialization,
             stg.address_line1, stg.city, stg.state, stg.country || 'India', stg.zip_code,
             stg.effective_start_date || null,
             req.params.batchId, userId]
          );
          empIdToUuid[stg.employee_id] = newId;
        } catch (rowErr) {
          skipped++;
          if (inserted > 0) inserted--; else if (replaced > 0) replaced--;
        }
      }

      await query(
        `UPDATE bulk_batches SET status='completed', success_rows=?, confirmed_at=NOW(), confirmed_by=? WHERE id=?`,
        [inserted + replaced, userId, req.params.batchId]
      );

      res.json({ success: true, data: { inserted, replaced, skipped, total: stagingRows.length, batchId: req.params.batchId } });
    } catch (err) { next(err); }
  }
);

// POST /employees/sync-users — create user accounts for all active employees that don't have one
router.post('/sync-users', authenticate, requireRole('super_admin', 'school_owner'), async (req, res, next) => {
  try {
    const employees = await query(
      `SELECT e.id, e.phone, e.first_name, e.last_name, e.user_id, r.code AS role_code
       FROM employees e
       JOIN org_roles r ON r.id = e.org_role_id
       WHERE e.is_active = TRUE AND e.phone IS NOT NULL AND e.phone != ''`
    );

    let created = 0, linked = 0, skipped = 0;
    for (const emp of employees) {
      if (emp.user_id) { skipped++; continue; }
      const userId = await ensureUserForEmployee(emp.id, emp.phone, emp.first_name, emp.last_name, emp.role_code);
      if (userId) {
        // Check if this was a new user or existing
        const [u] = await query('SELECT created_at FROM users WHERE id = ? LIMIT 1', [userId]);
        const ageMs = u ? Date.now() - new Date(u.created_at).getTime() : 0;
        if (ageMs < 5000) created++; else linked++;
      } else {
        skipped++;
      }
    }

    res.json({ success: true, data: { total: employees.length, created, linked, skipped } });
  } catch (err) { next(err); }
});

module.exports = router;
