// ============================================================
// Students CRUD + SCD Type 2 + Staging-Based Bulk Upload
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
  limits: { fileSize: 20 * 1024 * 1024 },
  fileFilter: (req, file, cb) => {
    const ext = path.extname(file.originalname).toLowerCase();
    cb(null, ['.xlsx', '.xls', '.csv'].includes(ext));
  }
});

// ── Validation constants ───────────────────────────────────────
const VALID_BLOOD_GROUPS = new Set(['A+','A-','B+','B-','O+','O-','AB+','AB-']);
const VALID_CATEGORIES   = new Set(['General','SC','ST','OBC','EWS']);
const VALID_GENDERS      = new Set(['male','female','other']);
const VALID_GUARDIAN_TYPES = new Set(['father','mother','guardian1','guardian2']);

const INDIAN_STATES = new Set([
  'Andhra Pradesh','Arunachal Pradesh','Assam','Bihar','Chhattisgarh','Goa','Gujarat',
  'Haryana','Himachal Pradesh','Jharkhand','Karnataka','Kerala','Madhya Pradesh',
  'Maharashtra','Manipur','Meghalaya','Mizoram','Nagaland','Odisha','Punjab',
  'Rajasthan','Sikkim','Tamil Nadu','Telangana','Tripura','Uttar Pradesh',
  'Uttarakhand','West Bengal',
  // Union Territories
  'Andaman and Nicobar Islands','Chandigarh','Dadra and Nagar Haveli and Daman and Diu',
  'Delhi','Jammu and Kashmir','Ladakh','Lakshadweep','Puducherry',
]);

const PHOTO_URL_RE = /^images\/students\/\d{4}\//;
const PHONE_RE     = /^[+]?[6-9]\d{9,14}$/;
const AADHAAR_RE   = /^\d{12}$/;
const ZIP_RE_IN    = /^\d{6}$/;

// ── Helpers ───────────────────────────────────────────────────
function getField(row, ...keys) {
  for (const k of keys) {
    const v = row[k];
    if (v !== undefined && v !== null) {
      // Excel date cells come back as JS Date objects — convert to YYYY-MM-DD
      if (v instanceof Date) return isNaN(v) ? '' : v.toISOString().split('T')[0];
      const s = String(v).trim();
      if (s !== '') return s;
    }
  }
  return '';
}

function parseBool(val) {
  if (val === true || val === 1) return true;
  if (val === false || val === 0) return false;
  const s = String(val).trim().toLowerCase();
  return ['1','yes','y','true'].includes(s);
}

function excelSerialToDate(serial) {
  // Excel epoch is 1899-12-30 (accounts for Lotus 1-2-3 leap year bug)
  const d = new Date(Date.UTC(1899, 11, 30) + serial * 86400000);
  return isNaN(d) ? null : d.toISOString().split('T')[0];
}

function parseDate(raw) {
  if (raw === null || raw === undefined || raw === '') return null;
  // Numeric type — Excel serial (e.g. 45748)
  if (typeof raw === 'number') return excelSerialToDate(raw);
  if (raw instanceof Date) return isNaN(raw) ? null : raw.toISOString().split('T')[0];
  const s = String(raw).trim();
  if (!s) return null;
  // Numeric string — Excel serial stored as text (e.g. "45748")
  if (/^\d{4,6}$/.test(s)) {
    const n = Number(s);
    // Sanity: valid Excel serials for years 1900–2100 are roughly 1–73050
    if (n >= 1 && n <= 73050) return excelSerialToDate(n);
  }
  // DD/MM/YYYY
  const dmy = s.match(/^(\d{1,2})\/(\d{1,2})\/(\d{4})$/);
  if (dmy) return `${dmy[3]}-${dmy[2].padStart(2,'0')}-${dmy[1].padStart(2,'0')}`;
  // YYYY-MM-DD passthrough
  if (/^\d{4}-\d{2}-\d{2}$/.test(s)) return s;
  // DD-MM-YYYY
  const dmy2 = s.match(/^(\d{1,2})-(\d{1,2})-(\d{4})$/);
  if (dmy2) return `${dmy2[3]}-${dmy2[2].padStart(2,'0')}-${dmy2[1].padStart(2,'0')}`;
  return null;
}

// ── GET /students ─────────────────────────────────────────────
router.get('/', authenticate, async (req, res, next) => {
  try {
    const { school_id, branch_id, class_name, section, status_color,
            search, page = 1, limit = 50 } = req.query;
    const offset = (page - 1) * limit;

    let where = ['s.is_active = TRUE', 's.is_current = TRUE'];
    let params = [];

    const isSchoolScoped = req.user.role === 'super_admin' || req.user.role === 'school_owner';
    const effectiveSchoolId = isSchoolScoped
      ? (school_id || req.employee?.school_id || req.user.school_id)
      : req.employee?.school_id;

    if (req.user.role !== 'super_admin' && !effectiveSchoolId) {
      return res.json({ success: true, data: [], meta: { total: 0, page: +page, limit: +limit } });
    }

    if (effectiveSchoolId) { where.push('s.school_id = ?'); params.push(effectiveSchoolId); }
    if (branch_id)    { where.push('s.branch_id = ?');    params.push(branch_id); }
    if (class_name)   { where.push('s.class_name = ?');   params.push(class_name); }
    if (section)      { where.push('s.section = ?');      params.push(section); }
    if (status_color) { where.push('s.status_color = ?'); params.push(status_color); }
    if (search) {
      where.push('(s.first_name LIKE ? OR s.last_name LIKE ? OR s.student_id LIKE ?)');
      params.push(`%${search}%`, `%${search}%`, `%${search}%`);
    }

    // Teacher visibility filter
    if (req.employee && !class_name) {
      const level = req.employee.role_level;
      if (level >= 5) {
        const ac = req.employee.assigned_classes;
        const classes = typeof ac === 'string' ? JSON.parse(ac || '[]') : (ac || []);
        if (classes.length > 0) {
          where.push(`s.class_name IN (${classes.map(() => '?').join(',')})`);
          params.push(...classes);
        } else {
          where.push('1=0');
        }
      } else if (level === 4) {
        const ac = req.employee.assigned_classes;
        const ownClasses = typeof ac === 'string' ? JSON.parse(ac || '[]') : (ac || []);
        const subs = await query(
          `WITH RECURSIVE sub AS (
             SELECT id, assigned_classes FROM employees WHERE reports_to_emp_id = ? AND is_active = TRUE
             UNION ALL
             SELECT e.id, e.assigned_classes FROM employees e
             INNER JOIN sub s ON e.reports_to_emp_id = s.id WHERE e.is_active = TRUE
           ) SELECT assigned_classes FROM sub`,
          [req.employee.id]
        );
        const allClasses = new Set(ownClasses);
        for (const s of subs) {
          const sc = typeof s.assigned_classes === 'string'
            ? JSON.parse(s.assigned_classes || '[]') : (s.assigned_classes || []);
          sc.forEach(c => allClasses.add(c));
        }
        if (allClasses.size > 0) {
          where.push(`s.class_name IN (${[...allClasses].map(() => '?').join(',')})`);
          params.push(...allClasses);
        }
      }
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

// ── GET /students/bulk-upload/history — must be before /:id/history ─
// (Defined here to prevent /:id/history from intercepting this path)
router.get('/bulk-upload/history', authenticate, async (req, res, next) => {
  try {
    const effectiveSchoolId = req.employee?.school_id || req.user.school_id;
    if (!effectiveSchoolId) return res.json({ success: true, data: [] });

    const batches = await query(
      `SELECT bb.id, bb.filename, bb.total_rows, bb.success_rows, bb.warning_rows, bb.failed_rows,
              bb.status, bb.created_at, bb.confirmed_at,
              u1.display_name AS uploaded_by_name,
              u2.display_name AS confirmed_by_name
       FROM bulk_batches bb
       LEFT JOIN users u1 ON u1.id = bb.uploaded_by
       LEFT JOIN users u2 ON u2.id = bb.confirmed_by
       WHERE bb.school_id = ? AND bb.type = 'students'
       ORDER BY bb.created_at DESC LIMIT 100`,
      [effectiveSchoolId]
    );
    res.json({ success: true, data: batches });
  } catch (err) { next(err); }
});

// ── GET /students/:id/history — SCD version history ───────────
router.get('/:id/history', authenticate, async (req, res, next) => {
  try {
    const [anchor] = await query(
      'SELECT school_id, student_id FROM students WHERE id = ?', [req.params.id]
    );
    if (!anchor) return res.status(404).json({ success: false, message: 'Student not found' });

    const versions = await query(
      `SELECT s.id, s.is_current, s.effective_start_date, s.effective_end_date,
              s.change_reason, s.created_at,
              CONCAT(u.display_name) AS changed_by_name,
              s.class_name, s.section, s.roll_number,
              s.first_name, s.last_name, s.gender, s.date_of_birth,
              s.blood_group, s.nationality, s.category, s.is_active
       FROM students s
       LEFT JOIN users u ON u.id = s.created_by
       WHERE s.school_id = ? AND s.student_id = ?
       ORDER BY s.effective_start_date DESC`,
      [anchor.school_id, anchor.student_id]
    );

    res.json({ success: true, data: versions, total: versions.length });
  } catch (err) { next(err); }
});

// ── POST /students ─────────────────────────────────────────────
router.post('/', authenticate, async (req, res, next) => {
  try {
    const {
      school_id, branch_id, student_id, first_name, middle_name = null, last_name,
      gender, date_of_birth, roll_number, class_name, section, admission_no, aadhaar_no,
      address_line1, address_line2 = null, city, state, country = 'India', zip_code,
      blood_group = null, nationality = null, religion = null, category = null,
      photo_url = null,
      bus_route = null, bus_stop = null, bus_number = null,
      private_cab_flag = false, parents_personally_pick = false,
      private_cab_regn_no = null, private_cab_model = null,
      private_cab_driver_name = null, private_cab_driver_license_no = null,
      private_cab_license_expiry_dt = null,
      school_house_name = null,
      effective_start_date = null, change_reason = null,
      guardians = [],
    } = req.body;

    let effectiveSchoolId;
    if (req.user.role === 'super_admin') {
      effectiveSchoolId = school_id || req.employee?.school_id;
    } else if (['school_admin', 'school_owner', 'principal'].includes(req.user.role)) {
      effectiveSchoolId = req.user.role === 'school_owner'
        ? (req.user.school_id || school_id)
        : req.employee?.school_id;
      if (school_id && school_id !== effectiveSchoolId) {
        return res.status(403).json({ success: false, message: 'Not authorized to create students in other schools' });
      }
    } else {
      effectiveSchoolId = req.employee?.school_id;
    }

    const effectiveBranchId = branch_id || req.employee?.branch_id;
    const userId = req.user?.id;

    if (!effectiveSchoolId || !effectiveBranchId || !first_name || !gender || !class_name || !section) {
      return res.status(422).json({
        success: false,
        message: 'Required fields missing: school_id, branch_id, first_name, gender, class_name, section',
      });
    }

    // ── Field validations ──────────────────────────────────────
    const valErrors = [];

    if (!VALID_GENDERS.has((gender || '').toLowerCase())) {
      valErrors.push('gender must be male/female/other');
    }
    if (blood_group && !VALID_BLOOD_GROUPS.has(blood_group)) {
      valErrors.push('blood_group must be A+/A-/B+/B-/O+/O-/AB+/AB-');
    }
    if (category && !VALID_CATEGORIES.has(category)) {
      valErrors.push('category must be General/SC/ST/OBC/EWS');
    }
    if (aadhaar_no && !AADHAAR_RE.test(String(aadhaar_no).replace(/\s/g, ''))) {
      valErrors.push('aadhaar_no must be exactly 12 digits');
    }
    if (zip_code && country === 'India' && !ZIP_RE_IN.test(zip_code)) {
      valErrors.push('zip_code must be 6 digits for India');
    }
    if (state && country === 'India' && !INDIAN_STATES.has(state)) {
      valErrors.push(`state "${state}" is not a recognised Indian state/UT`);
    }
    if (photo_url && !PHOTO_URL_RE.test(photo_url)) {
      valErrors.push('photo_url must start with images/students/YYYY/');
    }
    if (private_cab_flag) {
      if (!private_cab_regn_no) valErrors.push('private_cab_regn_no is required when private_cab_flag is true');
      if (!private_cab_driver_license_no) valErrors.push('private_cab_driver_license_no is required when private_cab_flag is true');
      if (private_cab_license_expiry_dt && new Date(private_cab_license_expiry_dt) < new Date()) {
        valErrors.push('private_cab_license_expiry_dt must be a future date');
      }
    }
    // Validate class+section exists for this school/branch
    const [csRow] = await query(
      `SELECT cs.id FROM class_sections cs
       JOIN classes c ON c.id = cs.class_id
       JOIN branches b ON b.id = c.branch_id
       WHERE b.school_id = ? AND b.id = ? AND c.name = ? AND cs.section = ? AND c.is_active = TRUE LIMIT 1`,
      [effectiveSchoolId, effectiveBranchId, class_name, section]
    );
    if (!csRow) {
      valErrors.push(`class_name "${class_name}" section "${section}" not found for this school/branch`);
    }

    for (const g of guardians) {
      if (g.guardian_type && !VALID_GUARDIAN_TYPES.has(g.guardian_type)) {
        valErrors.push(`guardian_type "${g.guardian_type}" must be father/mother/guardian1/guardian2`);
      }
      if (g.phone && !PHONE_RE.test(g.phone)) {
        valErrors.push(`guardian phone "${g.phone}" must be 10+ digits starting 6-9`);
      }
      if (g.email && !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(g.email)) {
        valErrors.push(`guardian email "${g.email}" is not valid`);
      }
    }

    if (valErrors.length > 0) {
      return res.status(422).json({ success: false, message: 'Validation failed', errors: valErrors });
    }

    const id = uuid();
    const effStart = effective_start_date || new Date().toISOString().split('T')[0];

    await transaction(async (conn) => {
      await conn.execute(
        `INSERT INTO students
           (id, school_id, branch_id, student_id, roll_number, class_name, section,
            first_name, last_name, middle_name, date_of_birth, gender,
            blood_group, nationality, religion, category, aadhaar_no, admission_no,
            photo_url,
            address_line1, address_line2, city, state, country, zip_code,
            bus_route, bus_stop, bus_number,
            private_cab_flag, parents_personally_pick,
            private_cab_regn_no, private_cab_model, private_cab_driver_name,
            private_cab_driver_license_no, private_cab_license_expiry_dt,
            school_house_name,
            effective_start_date, is_current, is_active, created_by, change_reason)
         VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,TRUE,TRUE,?,?)`,
        [id, effectiveSchoolId, effectiveBranchId, student_id, roll_number,
         class_name, section, first_name, last_name, middle_name, date_of_birth, gender,
         blood_group || null, nationality || 'Indian', religion || null,
         category || 'General', aadhaar_no || null, admission_no || null,
         photo_url || null,
         address_line1 || null, address_line2 || null, city || null,
         state || null, country || 'India', zip_code || null,
         bus_route || null, bus_stop || null, bus_number || null,
         private_cab_flag ? 1 : 0, parents_personally_pick ? 1 : 0,
         private_cab_regn_no || null, private_cab_model || null,
         private_cab_driver_name || null, private_cab_driver_license_no || null,
         private_cab_license_expiry_dt || null,
         school_house_name || null,
         effStart, userId, change_reason || null]
      );

      for (const g of guardians) {
        if (g.guardian_type && (g.first_name || g.phone)) {
          await conn.execute(
            `INSERT INTO guardians
               (id, student_id, guardian_type, first_name, last_name,
                relation, photo_url, email, phone, whatsapp_no, alt_phone,
                occupation, organization, annual_income,
                same_as_student, address_line1, address_line2, city, state, country, zip_code,
                aadhaar_no, is_primary)
             VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)`,
            [uuid(), id, g.guardian_type,
             g.first_name || null, g.last_name || null,
             g.relation || null, g.photo_url || null,
             g.email || null, g.phone || null, g.whatsapp_no || null, g.alt_phone || null,
             g.occupation || null, g.organization || null, g.annual_income || null,
             g.same_as_student !== false ? 1 : 0,
             g.address_line1 || null, g.address_line2 || null, g.city || null,
             g.state || null, g.country || null, g.zip_code || null,
             g.aadhaar_no || null, g.is_primary ? 1 : 0]
          );
        }
      }
    });

    const [student] = await query('SELECT * FROM students WHERE id = ?', [id]);
    const gList = await query('SELECT * FROM guardians WHERE student_id = ?', [id]);
    res.status(201).json({ success: true, data: { ...student, guardians: gList } });
  } catch (err) { next(err); }
});

// ── PUT /students/:id — SCD Type 2 update ────────────────────
router.put('/:id', authenticate, async (req, res, next) => {
  try {
    // Auth check
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

    const [current] = await query('SELECT * FROM students WHERE id = ?', [req.params.id]);
    if (!current) return res.status(404).json({ success: false, message: 'Student not found' });

    const userId = req.user?.id;
    const changeReason = req.body.change_reason || null;

    // change_reason is required on update
    if (!changeReason) {
      return res.status(422).json({ success: false, message: 'change_reason is required when updating a student' });
    }

    const effStart = req.body.effective_start_date || new Date().toISOString().split('T')[0];

    const allowed = [
      'roll_number','class_name','section','first_name','last_name','middle_name',
      'date_of_birth','gender','blood_group','nationality','religion','category',
      'aadhaar_no','admission_no','photo_url',
      'address_line1','address_line2','city','state','country','zip_code',
      'bus_route','bus_stop','bus_number',
      'private_cab_flag','parents_personally_pick',
      'private_cab_regn_no','private_cab_model','private_cab_driver_name',
      'private_cab_driver_license_no','private_cab_license_expiry_dt',
      'school_house_name','is_active',
    ];

    // Build new record data by merging current + updates
    const newData = {};
    for (const f of allowed) {
      newData[f] = req.body[f] !== undefined ? req.body[f] : current[f];
    }

    // ── Field validations ──────────────────────────────────────
    const valErrors = [];
    const g = newData.gender ? newData.gender.toLowerCase() : '';
    if (g && !VALID_GENDERS.has(g)) valErrors.push('gender must be male/female/other');
    if (newData.blood_group && !VALID_BLOOD_GROUPS.has(newData.blood_group)) {
      valErrors.push('blood_group must be A+/A-/B+/B-/O+/O-/AB+/AB-');
    }
    if (newData.category && !VALID_CATEGORIES.has(newData.category)) {
      valErrors.push('category must be General/SC/ST/OBC/EWS');
    }
    if (newData.aadhaar_no && !AADHAAR_RE.test(String(newData.aadhaar_no).replace(/\s/g, ''))) {
      valErrors.push('aadhaar_no must be exactly 12 digits');
    }
    if (newData.zip_code && newData.country === 'India' && !ZIP_RE_IN.test(newData.zip_code)) {
      valErrors.push('zip_code must be 6 digits for India');
    }
    if (newData.state && newData.country === 'India' && !INDIAN_STATES.has(newData.state)) {
      valErrors.push(`state "${newData.state}" is not a recognised Indian state/UT`);
    }
    if (newData.photo_url && !PHOTO_URL_RE.test(newData.photo_url)) {
      valErrors.push('photo_url must start with images/students/YYYY/');
    }
    if (newData.private_cab_flag) {
      if (!newData.private_cab_regn_no) valErrors.push('private_cab_regn_no required when private_cab_flag is true');
      if (!newData.private_cab_driver_license_no) valErrors.push('private_cab_driver_license_no required when private_cab_flag is true');
      if (newData.private_cab_license_expiry_dt && new Date(newData.private_cab_license_expiry_dt) < new Date()) {
        valErrors.push('private_cab_license_expiry_dt must be a future date');
      }
    }
    // Validate class+section if being changed
    if (req.body.class_name !== undefined || req.body.section !== undefined) {
      const [csRow] = await query(
        `SELECT cs.id FROM class_sections cs
         JOIN classes c ON c.id = cs.class_id
         JOIN branches b ON b.id = c.branch_id
         WHERE b.school_id = ? AND b.id = ? AND c.name = ? AND cs.section = ? AND c.is_active = TRUE LIMIT 1`,
        [current.school_id, current.branch_id, newData.class_name, newData.section]
      );
      if (!csRow) {
        valErrors.push(`class_name "${newData.class_name}" section "${newData.section}" not found for this school/branch`);
      }
    }

    if (valErrors.length > 0) {
      return res.status(422).json({ success: false, message: 'Validation failed', errors: valErrors });
    }

    const newId = uuid();

    await transaction(async (conn) => {
      // Snapshot existing guardians into guardian_history before changing
      const existingGuardians = await conn.query(
        'SELECT * FROM guardians WHERE student_id = ?', [current.id]
      );
      const guardianRows = Array.isArray(existingGuardians) && Array.isArray(existingGuardians[0])
        ? existingGuardians[0] : existingGuardians;
      for (const eg of guardianRows) {
        await conn.query(
          `INSERT INTO guardian_history
             (guardian_id, student_id, guardian_type, first_name, last_name, relation,
              email, phone, whatsapp_no, alt_phone, occupation, organization, annual_income,
              aadhaar_no, same_as_student, address_line1, address_line2, city, state, country,
              zip_code, is_primary, changed_by, change_note)
           VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)`,
          [eg.id, eg.student_id, eg.guardian_type, eg.first_name, eg.last_name, eg.relation,
           eg.email, eg.phone, eg.whatsapp_no, eg.alt_phone, eg.occupation, eg.organization,
           eg.annual_income, eg.aadhaar_no, eg.same_as_student,
           eg.address_line1, eg.address_line2, eg.city, eg.state, eg.country, eg.zip_code,
           eg.is_primary, userId, changeReason]
        );
      }

      // Close current version
      await conn.query(
        `UPDATE students SET is_current = FALSE, effective_end_date = NOW(), updated_by = ?
         WHERE id = ?`,
        [userId, current.id]
      );

      // Insert new SCD version
      await conn.query(
        `INSERT INTO students
           (id, school_id, branch_id, student_id, roll_number, class_name, section,
            first_name, last_name, middle_name, date_of_birth, gender,
            blood_group, nationality, religion, category, aadhaar_no, admission_no,
            photo_url, address_line1, address_line2, city, state, country, zip_code,
            bus_route, bus_stop, bus_number,
            private_cab_flag, parents_personally_pick,
            private_cab_regn_no, private_cab_model, private_cab_driver_name,
            private_cab_driver_license_no, private_cab_license_expiry_dt,
            school_house_name,
            review_status, status_color, bulk_upload_batch,
            effective_start_date, is_current, is_active, created_by, change_reason)
         VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,TRUE,?,?,?)`,
        [newId, current.school_id, current.branch_id, current.student_id,
         newData.roll_number, newData.class_name, newData.section,
         newData.first_name, newData.last_name, newData.middle_name,
         newData.date_of_birth, newData.gender,
         newData.blood_group, newData.nationality, newData.religion,
         newData.category, newData.aadhaar_no, newData.admission_no,
         newData.photo_url,
         newData.address_line1, newData.address_line2, newData.city,
         newData.state, newData.country, newData.zip_code,
         newData.bus_route, newData.bus_stop, newData.bus_number,
         newData.private_cab_flag ? 1 : 0, newData.parents_personally_pick ? 1 : 0,
         newData.private_cab_regn_no, newData.private_cab_model, newData.private_cab_driver_name,
         newData.private_cab_driver_license_no, newData.private_cab_license_expiry_dt,
         newData.school_house_name,
         current.review_status, current.status_color, current.bulk_upload_batch,
         effStart, newData.is_active ?? true, userId, changeReason]
      );

      // Handle guardians
      if (Array.isArray(req.body.guardians)) {
        // Replace with new guardian data
        await conn.query('DELETE FROM guardians WHERE student_id = ?', [newId]);
        for (const g of req.body.guardians) {
          if (g.guardian_type && (g.first_name || g.phone)) {
            if (g.guardian_type && !VALID_GUARDIAN_TYPES.has(g.guardian_type)) continue;
            await conn.query(
              `INSERT INTO guardians
                 (id, student_id, guardian_type, first_name, last_name, relation, photo_url,
                  email, phone, whatsapp_no, alt_phone,
                  occupation, organization, annual_income,
                  same_as_student, address_line1, address_line2, city, state, country, zip_code,
                  aadhaar_no, is_primary)
               VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)`,
              [uuid(), newId, g.guardian_type,
               g.first_name || null, g.last_name || null,
               g.relation || null, g.photo_url || null,
               g.email || null, g.phone || null, g.whatsapp_no || null, g.alt_phone || null,
               g.occupation || null, g.organization || null, g.annual_income || null,
               g.same_as_student !== false ? 1 : 0,
               g.address_line1 || null, g.address_line2 || null, g.city || null,
               g.state || null, g.country || null, g.zip_code || null,
               g.aadhaar_no || null, g.is_primary ? 1 : 0]
            );
          }
        }
      } else {
        // Move existing guardians to new version
        await conn.query(
          'UPDATE guardians SET student_id = ? WHERE student_id = ?',
          [newId, current.id]
        );
      }
    });

    const [student] = await query('SELECT * FROM students WHERE id = ?', [newId]);
    const guardians = await query('SELECT * FROM guardians WHERE student_id = ?', [newId]);
    res.json({ success: true, data: { ...student, guardians }, previous_version_id: current.id });
  } catch (err) { next(err); }
});

// ── DELETE /students/:id (soft delete — marks all versions inactive) ──
router.delete('/:id',
  authenticate,
  requireRole('super_admin','school_owner','principal','vp','head_teacher'),
  async (req, res, next) => {
    try {
      const [student] = await query('SELECT school_id, student_id FROM students WHERE id = ?', [req.params.id]);
      if (!student) return res.status(404).json({ success: false, message: 'Student not found' });

      await query(
        'UPDATE students SET is_active = FALSE, is_current = FALSE WHERE school_id = ? AND student_id = ?',
        [student.school_id, student.student_id]
      );
      res.json({ success: true, message: 'Student deactivated' });
    } catch (err) { next(err); }
  }
);

// ── PATCH /students/:id/status ────────────────────────────────
router.patch('/:id/status', authenticate, async (req, res, next) => {
  try {
    if (req.user.role !== 'super_admin') {
      const [existing] = await query('SELECT school_id FROM students WHERE id = ?', [req.params.id]);
      if (!existing || !req.employee || req.employee.school_id !== existing.school_id) {
        return res.status(403).json({ success: false, message: 'Not authorized' });
      }
    }
    const { status_color, review_status } = req.body;
    await query('UPDATE students SET status_color=?, review_status=? WHERE id=?',
      [status_color, review_status, req.params.id]);
    res.json({ success: true, message: 'Status updated' });
  } catch (err) { next(err); }
});

// ============================================================
// BULK UPLOAD — Staging-Based Flow
// ============================================================

// ── Template download ─────────────────────────────────────────
router.get('/bulk-template/download', authenticate, async (req, res, next) => {
  try {
    const wb = xlsx.utils.book_new();

    const instr = [
      ['STUDENT BULK UPLOAD TEMPLATE — v3'],
      ['Fields marked * are mandatory.'],
      ['Date format: YYYY-MM-DD'],
      ['gender: male | female | other'],
      ['blood_group: A+ | A- | B+ | B- | O+ | O- | AB+ | AB-'],
      ['category: General | SC | ST | OBC | EWS'],
      ['guardian_type: father | mother | guardian1 | guardian2'],
      ['guardian_phone: 10-digit Indian mobile (starts 6-9)'],
      ['private_cab_flag: Y | N  (if Y, cab details are required)'],
      ['parents_personally_pick: Y | N'],
      ['photo_url: must start with images/students/YYYY/ (e.g. images/students/2026/filename.jpg)'],
      ['state: must match official Indian state/UT name'],
      ['country: defaults to India if blank'],
      ['change_reason: required when updating existing student records'],
    ];
    xlsx.utils.book_append_sheet(wb, xlsx.utils.aoa_to_sheet(instr), 'Instructions');

    const headers = [
      'student_id*','first_name*','last_name*','middle_name','gender*','date_of_birth*',
      'class_name*','section*','roll_number','academic_year',
      'admission_no','blood_group','nationality','religion','category','aadhaar_no',
      'photo_url',
      'address_line1','address_line2','city','state*','country','zip_code',
      'bus_route','bus_stop','bus_number',
      'private_cab_flag','parents_personally_pick',
      'private_cab_regn_no','private_cab_model',
      'private_cab_driver_name','private_cab_driver_license_no','private_cab_license_expiry_dt',
      'school_house_name',
      'guardian_type*','guardian_first_name*','guardian_last_name','guardian_phone*',
      'guardian_email','guardian_relation','guardian_whatsapp','guardian_occupation',
      'guardian2_type','guardian2_first_name','guardian2_last_name','guardian2_phone',
      'guardian2_email',
      'effective_start_date','change_reason',
    ];

    const FIRST = ['Aarav','Priya','Rahul','Sunita','Amit','Kavita','Rohit','Neha','Vivaan','Meena'];
    const LAST  = ['Sharma','Verma','Gupta','Singh','Patel','Kumar','Mehta','Joshi','Yadav','Tiwari'];
    const STATES = ['Uttar Pradesh','Maharashtra','Delhi','Karnataka','Tamil Nadu'];
    const HOUSES = ['Red House','Blue House','Green House','Yellow House'];
    const rows = [headers];
    for (let i = 1; i <= 5; i++) {
      const fn = FIRST[i % 10]; const ln = LAST[i % 10];
      const cls = (i % 5) + 1; const sec = ['A','B','C'][i % 3];
      rows.push([
        `STU-2026-${String(i).padStart(4,'0')}`, fn, ln, '',
        i%2===0?'male':'female', `201${(i%5)+2}-0${(i%9)+1}-15`,
        `Class ${cls}`, sec, i, '2025-26',
        `ADM${String(i).padStart(4,'0')}`,
        ['A+','B+','O+','AB+'][i%4], 'Indian', 'Hindu',
        ['General','SC','ST','OBC','EWS'][i%5],
        `${String(100000000000 + i)}`,
        `images/students/2026/stu_${i}.jpg`,
        `House ${i}, Sector ${(i%30)+1}`, '', 'Noida',
        STATES[i % 5], 'India', `20110${i}`,
        '', '', '',
        'N', 'N', '', '', '', '', '',
        HOUSES[i % 4],
        'father', `${FIRST[(i+1)%10]} ${ln}`, ln,
        `98${String(i).padStart(8,'0')}`,
        `parent${i}@example.com`, 'Father', '', 'Business',
        'mother', `${FIRST[(i+2)%10]} ${ln}`, ln,
        `97${String(i).padStart(8,'0')}`, `mother${i}@example.com`,
        '2026-04-01', 'Annual roll update 2026-27',
      ]);
    }
    xlsx.utils.book_append_sheet(wb, xlsx.utils.aoa_to_sheet(rows), 'Students');

    const buf = xlsx.write(wb, { type: 'buffer', bookType: 'xlsx' });
    res.setHeader('Content-Disposition', 'attachment; filename="student_bulk_template_v3.xlsx"');
    res.setHeader('Content-Type', 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
    res.send(buf);
  } catch (err) { next(err); }
});

// ── Stage + Validate ──────────────────────────────────────────
router.post('/bulk-upload/stage',
  authenticate,
  requireRole('super_admin','school_owner','principal','vp'),
  upload.single('file'),
  async (req, res, next) => {
    if (!req.file) return res.status(400).json({ success: false, message: 'No file uploaded' });

    const batchId = uuid();
    const effectiveSchoolId = req.user.role === 'super_admin'
      ? (req.body.school_id || req.employee?.school_id || req.user.school_id)
      : (req.employee?.school_id || req.user.school_id);
    const branchId = req.body.branch_id || req.employee?.branch_id || null;

    if (!effectiveSchoolId) {
      try { fs.unlinkSync(req.file.path); } catch (_) {}
      return res.status(422).json({ success: false, message: 'school_id context required' });
    }

    try {
      // Load validation messages from DB
      const dbMsgs = await query('SELECT code, message_en FROM validation_messages WHERE entity IN (?,?)', ['student','general']);
      const msg = {};
      dbMsgs.forEach(r => { msg[r.code] = r.message_en; });
      const m = (code, fallback) => msg[code] || fallback;

      const wb = xlsx.readFile(req.file.path);
      const sheetName = wb.SheetNames.find(n => n !== 'Instructions') || wb.SheetNames[0];
      const rows = xlsx.utils.sheet_to_json(wb.Sheets[sheetName], { defval: '' });
      try { fs.unlinkSync(req.file.path); } catch (_) {}

      if (!rows.length) return res.status(400).json({ success: false, message: 'File contains no data rows' });

      // ── Pre-load reference data ──────────────────────────────
      const existingStudents = new Set(
        (await query('SELECT student_id FROM students WHERE school_id = ? AND is_current = TRUE', [effectiveSchoolId]))
          .map(r => r.student_id)
      );

      // Build set of valid class+section combinations for school
      const classSectionRows = await query(
        `SELECT c.name AS class_name, cs.section
         FROM class_sections cs
         JOIN classes c ON c.id = cs.class_id
         JOIN branches b ON b.id = c.branch_id
         WHERE b.school_id = ? AND c.is_active = TRUE`,
        [effectiveSchoolId]
      );
      const validClassSections = new Set(
        classSectionRows.map(r => `${r.class_name}|||${r.section}`)
      );
      // Also build branch-scoped set if branchId provided
      let validClassSectionsBranch = null;
      if (branchId) {
        const branchCSRows = await query(
          `SELECT c.name AS class_name, cs.section
           FROM class_sections cs
           JOIN classes c ON c.id = cs.class_id
           WHERE c.branch_id = ? AND c.is_active = TRUE`,
          [branchId]
        );
        validClassSectionsBranch = new Set(branchCSRows.map(r => `${r.class_name}|||${r.section}`));
      }

      // Create batch record
      await query(
        `INSERT INTO bulk_batches (id, school_id, branch_id, type, filename, status, uploaded_by)
         VALUES (?, ?, ?, 'students', ?, 'staged', ?)`,
        [batchId, effectiveSchoolId, branchId, req.file.originalname, req.user.id]
      );

      let successCount = 0; let warningCount = 0; let failCount = 0;
      const validationResults = [];

      for (let idx = 0; idx < rows.length; idx++) {
        const row = rows[idx];
        const rowNo = idx + 2;

        // ── Extract fields ───────────────────────────────────
        const stuId      = getField(row, 'student_id*', 'student_id');
        const firstName  = getField(row, 'first_name*', 'first_name');
        const lastName   = getField(row, 'last_name*', 'last_name');
        const middleName = getField(row, 'middle_name');
        const rawGender  = getField(row, 'gender*', 'gender');
        const gender     = rawGender.toLowerCase();
        const dob        = getField(row, 'date_of_birth*', 'date_of_birth');
        const cls        = getField(row, 'class_name*', 'class_name');
        const sec        = getField(row, 'section*', 'section');
        const rollNo     = getField(row, 'roll_number');
        const acYear     = getField(row, 'academic_year') || '2025-26';
        const admNo      = getField(row, 'admission_no');
        const bloodGrp   = getField(row, 'blood_group');
        const nationality= getField(row, 'nationality') || 'Indian';
        const religion   = getField(row, 'religion');
        const category   = getField(row, 'category');
        const aadhaar    = getField(row, 'aadhaar_no').replace(/\s/g, '');
        const photoUrl   = getField(row, 'photo_url');
        const addr1      = getField(row, 'address_line1');
        const addr2      = getField(row, 'address_line2');
        const city       = getField(row, 'city');
        const state      = getField(row, 'state*', 'state');
        const country    = getField(row, 'country') || 'India';
        const zip        = getField(row, 'zip_code');
        const busRoute   = getField(row, 'bus_route');
        const busStop    = getField(row, 'bus_stop');
        const busNum     = getField(row, 'bus_number');
        const cabFlag    = parseBool(getField(row, 'private_cab_flag'));
        const parentPick = parseBool(getField(row, 'parents_personally_pick'));
        const cabRegn    = getField(row, 'private_cab_regn_no');
        const cabModel   = getField(row, 'private_cab_model');
        const cabDriver  = getField(row, 'private_cab_driver_name');
        const cabLicNo   = getField(row, 'private_cab_driver_license_no');
        const cabLicExp  = getField(row, 'private_cab_license_expiry_dt');
        const houseNm    = getField(row, 'school_house_name');
        // Guardian 1
        const gType      = getField(row, 'guardian_type*', 'guardian_type') || 'father';
        const gFirst     = getField(row, 'guardian_first_name*', 'guardian_name*', 'guardian_name', 'guardian_first_name');
        const gLast      = getField(row, 'guardian_last_name');
        const gPhone     = getField(row, 'guardian_phone*', 'guardian_phone');
        const gEmail     = getField(row, 'guardian_email');
        const gRelation  = getField(row, 'guardian_relation');
        const gWhatsapp  = getField(row, 'guardian_whatsapp');
        const gOccup     = getField(row, 'guardian_occupation');
        // Guardian 2
        const g2Type     = getField(row, 'guardian2_type');
        const g2First    = getField(row, 'guardian2_first_name');
        const g2Last     = getField(row, 'guardian2_last_name');
        const g2Phone    = getField(row, 'guardian2_phone');
        const g2Email    = getField(row, 'guardian2_email');

        const effStart   = getField(row, 'effective_start_date');
        const chgReason  = getField(row, 'change_reason');

        const errors = []; const warnings = []; const notes = [];

        // ── Completeness checks ───────────────────────────────
        if (!stuId)      errors.push(m('ERR_STU_ID_REQUIRED', 'Student ID is required'));
        if (!firstName)  errors.push(m('ERR_FIRST_NAME_REQUIRED', 'First name is required'));
        if (!cls)        errors.push(m('ERR_CLASS_REQUIRED', 'Class name is required'));
        if (!sec)        errors.push(m('ERR_SECTION_REQUIRED', 'Section is required'));
        if (!gender)     errors.push(m('ERR_GENDER_INVALID', 'Gender is required'));

        // ── Datatype / enum / length / format checks ─────────
        if (gender && !VALID_GENDERS.has(gender)) {
          errors.push(m('ERR_GENDER_INVALID', 'Gender must be male/female/other'));
        }
        if (dob && isNaN(Date.parse(dob))) {
          errors.push(m('ERR_DOB_FORMAT', 'Date of birth must be YYYY-MM-DD'));
        }
        if (dob && !isNaN(Date.parse(dob))) {
          const age = (new Date() - new Date(dob)) / (365.25 * 24 * 3600 * 1000);
          if (age < 3 || age > 25) warnings.push('Date of birth gives unusual age (expected 3–25 years)');
        }
        if (bloodGrp && !VALID_BLOOD_GROUPS.has(bloodGrp)) {
          errors.push(m('ERR_BLOOD_GROUP_INVALID', 'Blood group must be A+/A-/B+/B-/O+/O-/AB+/AB-'));
        }
        if (!bloodGrp) warnings.push(m('WARN_BLOOD_GROUP', 'Blood group not provided'));
        if (category && !VALID_CATEGORIES.has(category)) {
          errors.push(m('ERR_CATEGORY_INVALID', 'Category must be General/SC/ST/OBC/EWS'));
        }
        if (!category) warnings.push(m('WARN_CATEGORY_DEFAULT', 'Category not provided — defaults to General'));
        if (aadhaar && !AADHAAR_RE.test(aadhaar)) {
          errors.push(m('ERR_AADHAAR_FORMAT', 'Aadhaar must be exactly 12 digits'));
        }
        if (zip && country === 'India' && !ZIP_RE_IN.test(zip)) {
          errors.push(m('ERR_ZIP_FORMAT', 'ZIP/PIN code must be 6 digits for India'));
        }
        if (state && country === 'India' && !INDIAN_STATES.has(state)) {
          errors.push(m('ERR_STATE_INVALID', `State "${state}" not recognised`));
        }
        if (!state)  warnings.push(m('WARN_STATE', 'State not provided'));
        if (!city)   warnings.push(m('WARN_CITY', 'City not provided'));
        if (!addr1)  warnings.push(m('WARN_ADDRESS', 'Address not provided'));
        if (!admNo)  warnings.push(m('WARN_ADMISSION_NO', 'Admission number not provided'));
        if (!houseNm) warnings.push(m('WARN_SCHOOL_HOUSE', 'School house not provided'));

        if (photoUrl && !PHOTO_URL_RE.test(photoUrl)) {
          errors.push(m('ERR_PHOTO_URL_FORMAT', 'Photo URL must start with images/students/YYYY/'));
        }

        // firstName / lastName length
        if (firstName && firstName.length > 100) errors.push('First name exceeds 100 characters');
        if (lastName && lastName.length > 100)   errors.push('Last name exceeds 100 characters');
        if (middleName && middleName.length > 100) errors.push('Middle name exceeds 100 characters');
        if (admNo && admNo.length > 50) errors.push('Admission number exceeds 50 characters');
        if (stuId && stuId.length > 50) errors.push('Student ID exceeds 50 characters');

        // ── Class+Section lookup ──────────────────────────────
        if (cls && sec) {
          const csKey = `${cls}|||${sec}`;
          const lookupSet = validClassSectionsBranch || validClassSections;
          if (lookupSet.size > 0 && !lookupSet.has(csKey)) {
            errors.push(m('ERR_CLASS_SECTION_INVALID', `Class "${cls}" Section "${sec}" not found in school`));
          }
        }

        // ── Private cab validations ───────────────────────────
        if (cabFlag) {
          if (!cabRegn)   errors.push(m('ERR_CAB_DETAILS_REQUIRED', 'Private cab registration number required'));
          if (!cabLicNo)  errors.push(m('ERR_CAB_DRIVER_LICENSE_REQUIRED', 'Driver licence number required'));
          if (cabLicExp && !isNaN(Date.parse(cabLicExp)) && new Date(cabLicExp) < new Date()) {
            errors.push(m('ERR_CAB_LICENSE_EXPIRY', 'Driver licence expiry date must be today or a future date'));
          }
        }

        // ── Guardian validations ──────────────────────────────
        if (!gPhone) {
          warnings.push('Guardian phone missing — parent login will not be possible');
        } else if (!PHONE_RE.test(gPhone)) {
          errors.push(m('ERR_GUARDIAN_PHONE', 'Guardian phone must be 10+ digits starting 6-9'));
        }
        if (gType && !VALID_GUARDIAN_TYPES.has(gType)) {
          errors.push(`guardian_type "${gType}" must be father/mother/guardian1/guardian2`);
        }
        if (gEmail && !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(gEmail)) {
          errors.push(m('ERR_EMAIL_FORMAT', `Guardian email "${gEmail}" is not valid`));
        }
        if (g2Type && !VALID_GUARDIAN_TYPES.has(g2Type)) {
          errors.push(`guardian2_type "${g2Type}" must be father/mother/guardian1/guardian2`);
        }
        if (g2Phone && !PHONE_RE.test(g2Phone)) {
          warnings.push(`Guardian 2 phone "${g2Phone}" format is invalid`);
        }

        // ── SCD duplicate check ───────────────────────────────
        if (stuId && existingStudents.has(stuId)) {
          if (!chgReason) {
            errors.push(m('ERR_CHANGE_REASON_REQUIRED', 'change_reason is required for existing student'));
          }
          notes.push(`Student "${stuId}" exists — a new SCD version will be created`);
        }

        const status = errors.length > 0 ? 'failed' : warnings.length > 0 ? 'warning' : 'success';
        if (status === 'success') successCount++;
        else if (status === 'warning') warningCount++;
        else failCount++;

        // Build guardian_data JSON
        const guardianArr = [];
        if (gFirst || gPhone) {
          guardianArr.push({
            guardian_type: gType || 'father',
            first_name: gFirst || null, last_name: gLast || null,
            phone: gPhone || null, email: gEmail || null,
            relation: gRelation || null, whatsapp_no: gWhatsapp || null,
            occupation: gOccup || null, is_primary: true,
          });
        }
        if ((g2First || g2Phone) && g2Type) {
          guardianArr.push({
            guardian_type: g2Type,
            first_name: g2First || null, last_name: g2Last || null,
            phone: g2Phone || null, email: g2Email || null,
            is_primary: false,
          });
        }

        await query(
          `INSERT INTO student_staging
             (id, batch_id, \`row_number\`, school_id, branch_id,
              student_id, first_name, middle_name, last_name, gender, date_of_birth,
              class_name, section, roll_number, academic_year,
              admission_no, blood_group, nationality, religion, category, aadhaar_no,
              photo_url,
              address_line1, address_line2, city, state, country, zip_code,
              bus_route, bus_stop, bus_number,
              private_cab_flag, parents_personally_pick,
              private_cab_regn_no, private_cab_model, private_cab_driver_name,
              private_cab_driver_license_no, private_cab_license_expiry_dt,
              school_house_name,
              effective_start_date, change_reason,
              guardian_data, validation_status, validation_errors, validation_warnings, validation_notes, raw_row)
           VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)`,
          [uuid(), batchId, rowNo, effectiveSchoolId, branchId,
           stuId || null, firstName || null, middleName || null,
           lastName || null, gender || null, parseDate(dob) || null,
           cls || null, sec || null, rollNo || null, acYear,
           admNo || null, bloodGrp || null, nationality,
           religion || null, category || 'General', aadhaar || null,
           photoUrl || null,
           addr1 || null, addr2 || null, city || null, state || null,
           country || 'India', zip || null,
           busRoute || null, busStop || null, busNum || null,
           cabFlag ? 1 : 0, parentPick ? 1 : 0,
           cabRegn || null, cabModel || null, cabDriver || null,
           cabLicNo || null, parseDate(cabLicExp) || null,
           houseNm || null,
           parseDate(effStart) || null, chgReason || null,
           guardianArr.length ? JSON.stringify(guardianArr) : null,
           status, JSON.stringify(errors), JSON.stringify(warnings), JSON.stringify(notes),
           JSON.stringify(row)]
        );

        validationResults.push({
          row: rowNo, status,
          errors, warnings, notes,
          data: { stuId, firstName, lastName, gender, dob, cls, sec, gPhone },
        });
      }

      // Update batch summary
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

// ── Staging results (paginated) ───────────────────────────────
router.get('/bulk-upload/:batchId/results', authenticate, async (req, res, next) => {
  try {
    const { status, page = 1, limit = 100 } = req.query;
    const offset = (page - 1) * limit;

    let where = ['batch_id = ?'];
    const params = [req.params.batchId];
    if (status) { where.push('validation_status = ?'); params.push(status); }

    const rows = await query(
      `SELECT id, \`row_number\`, student_id, first_name, last_name, class_name, section,
              validation_status, validation_errors, validation_warnings, validation_notes
       FROM student_staging WHERE ${where.join(' AND ')}
       ORDER BY \`row_number\` LIMIT ? OFFSET ?`,
      [...params, +limit, +offset]
    );

    const [{ total }] = await query(`SELECT COUNT(*) AS total FROM student_staging WHERE ${where.join(' AND ')}`, params);
    res.json({ success: true, data: rows, meta: { total, page: +page, limit: +limit } });
  } catch (err) { next(err); }
});

// ── Download XLSX validation report ──────────────────────────
router.get('/bulk-upload/:batchId/report', authenticate, async (req, res, next) => {
  try {
    const [batch] = await query('SELECT * FROM bulk_batches WHERE id = ?', [req.params.batchId]);
    if (!batch) return res.status(404).json({ success: false, message: 'Batch not found' });

    const stagingRows = await query(
      `SELECT \`row_number\`, student_id, first_name, last_name, class_name, section,
              roll_number, gender, date_of_birth, guardian_data,
              validation_status, validation_errors, validation_warnings, validation_notes,
              effective_start_date, change_reason
       FROM student_staging WHERE batch_id = ? ORDER BY \`row_number\``,
      [req.params.batchId]
    );

    const wb = xlsx.utils.book_new();

    const summaryData = [
      ['Batch ID', batch.id],
      ['Filename', batch.filename],
      ['Uploaded On', batch.created_at],
      ['Total Rows', batch.total_rows],
      ['Success', batch.success_rows],
      ['Warning', batch.warning_rows],
      ['Failed', batch.failed_rows],
      ['Status', batch.status],
    ];
    xlsx.utils.book_append_sheet(wb, xlsx.utils.aoa_to_sheet(summaryData), 'Summary');

    const allHeaders = ['Row','Student ID','First Name','Last Name','Class','Section','Gender','DOB','Status','Errors','Warnings','Notes'];
    const allRows = [allHeaders, ...stagingRows.map(r => [
      r.row_number, r.student_id, r.first_name, r.last_name,
      r.class_name, r.section, r.gender, r.date_of_birth,
      r.validation_status.toUpperCase(),
      (JSON.parse(r.validation_errors || '[]')).join('; '),
      (JSON.parse(r.validation_warnings || '[]')).join('; '),
      (JSON.parse(r.validation_notes || '[]')).join('; '),
    ])];
    const ws2 = xlsx.utils.aoa_to_sheet(allRows);
    ws2['!cols'] = allHeaders.map((_, i) => ({ wch: [6,14,14,14,12,10,8,12,10,40,40,40][i] || 14 }));
    xlsx.utils.book_append_sheet(wb, ws2, 'All Rows');

    const failedRows = stagingRows.filter(r => r.validation_status === 'failed');
    if (failedRows.length) {
      const failData = [allHeaders, ...failedRows.map(r => [
        r.row_number, r.student_id, r.first_name, r.last_name,
        r.class_name, r.section, r.gender, r.date_of_birth,
        'FAILED',
        (JSON.parse(r.validation_errors || '[]')).join('; '),
        (JSON.parse(r.validation_warnings || '[]')).join('; '),
        '',
      ])];
      xlsx.utils.book_append_sheet(wb, xlsx.utils.aoa_to_sheet(failData), 'Failed Rows');
    }

    const buf = xlsx.write(wb, { type: 'buffer', bookType: 'xlsx' });
    const name = `student_validation_${batch.filename.replace(/[^a-zA-Z0-9._-]/g,'_')}`;
    res.setHeader('Content-Disposition', `attachment; filename="${name}"`);
    res.setHeader('Content-Type', 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
    res.send(buf);
  } catch (err) { next(err); }
});

// ── Confirm — commit staging to main table (SCD-aware) ────────
router.post('/bulk-upload/:batchId/confirm',
  authenticate,
  requireRole('super_admin','school_owner','principal','vp'),
  async (req, res, next) => {
    try {
      const [batch] = await query('SELECT * FROM bulk_batches WHERE id = ?', [req.params.batchId]);
      if (!batch) return res.status(404).json({ success: false, message: 'Batch not found' });
      if (batch.status === 'completed') return res.status(409).json({ success: false, message: 'Batch already confirmed' });

      const overrideEffStart = req.body.effective_start_date || null;
      const overrideReason   = req.body.change_reason || null;
      const userId = req.user?.id;

      await query("UPDATE bulk_batches SET status='processing' WHERE id=?", [req.params.batchId]);

      const stagingRows = await query(
        `SELECT * FROM student_staging
         WHERE batch_id = ? AND validation_status IN ('success','warning')
         ORDER BY \`row_number\``,
        [req.params.batchId]
      );

      let inserted = 0; let replaced = 0; let skipped = 0;

      for (const stg of stagingRows) {
        try {
          const effStart = overrideEffStart || stg.effective_start_date
            || new Date().toISOString().split('T')[0];
          const reason = overrideReason || stg.change_reason || null;

          await transaction(async (conn) => {
            const [existing] = await conn.query(
              'SELECT id FROM students WHERE school_id = ? AND student_id = ? AND is_current = TRUE LIMIT 1',
              [stg.school_id, stg.student_id]
            );

            if (existing) {
              // Snapshot guardians before closing
              const prevGuardians = await conn.query(
                'SELECT * FROM guardians WHERE student_id = ?', [existing.id]
              );
              const pgRows = Array.isArray(prevGuardians) && Array.isArray(prevGuardians[0])
                ? prevGuardians[0] : prevGuardians;
              for (const eg of pgRows) {
                await conn.query(
                  `INSERT INTO guardian_history
                     (guardian_id, student_id, guardian_type, first_name, last_name, relation,
                      email, phone, whatsapp_no, alt_phone, occupation, organization, annual_income,
                      aadhaar_no, same_as_student, address_line1, address_line2, city, state, country,
                      zip_code, is_primary, changed_by, change_note)
                   VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)`,
                  [eg.id, eg.student_id, eg.guardian_type, eg.first_name, eg.last_name, eg.relation,
                   eg.email, eg.phone, eg.whatsapp_no, eg.alt_phone, eg.occupation, eg.organization,
                   eg.annual_income, eg.aadhaar_no, eg.same_as_student,
                   eg.address_line1, eg.address_line2, eg.city, eg.state, eg.country, eg.zip_code,
                   eg.is_primary, userId, reason || 'Bulk upload']
                );
              }

              await conn.query(
                'UPDATE students SET is_current = FALSE, effective_end_date = ?, updated_by = ? WHERE id = ?',
                [effStart, userId, existing.id]
              );
              replaced++;
            } else {
              inserted++;
            }

            const newId = uuid();
            await conn.query(
              `INSERT INTO students
                 (id, school_id, branch_id, student_id, roll_number, class_name, section,
                  first_name, last_name, middle_name, date_of_birth, gender,
                  blood_group, nationality, religion, category, aadhaar_no, admission_no,
                  photo_url,
                  address_line1, address_line2, city, state, country, zip_code,
                  bus_route, bus_stop, bus_number,
                  private_cab_flag, parents_personally_pick,
                  private_cab_regn_no, private_cab_model, private_cab_driver_name,
                  private_cab_driver_license_no, private_cab_license_expiry_dt,
                  school_house_name,
                  academic_year, effective_start_date, is_current, is_active,
                  bulk_upload_batch, created_by, change_reason)
               VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,TRUE,TRUE,?,?,?)`,
              [newId, stg.school_id, stg.branch_id, stg.student_id, stg.roll_number,
               stg.class_name, stg.section, stg.first_name, stg.last_name, stg.middle_name,
               stg.date_of_birth, stg.gender,
               stg.blood_group || null, stg.nationality || 'Indian',
               stg.religion || null, stg.category || 'General',
               stg.aadhaar_no || null, stg.admission_no || null,
               stg.photo_url || null,
               stg.address_line1 || null, stg.address_line2 || null,
               stg.city || null, stg.state || null, stg.country || 'India', stg.zip_code || null,
               stg.bus_route || null, stg.bus_stop || null, stg.bus_number || null,
               stg.private_cab_flag ? 1 : 0, stg.parents_personally_pick ? 1 : 0,
               stg.private_cab_regn_no || null, stg.private_cab_model || null,
               stg.private_cab_driver_name || null, stg.private_cab_driver_license_no || null,
               stg.private_cab_license_expiry_dt || null,
               stg.school_house_name || null,
               stg.academic_year || '2025-26',
               effStart, req.params.batchId, userId, reason]
            );

            // Move existing guardians to new student version
            if (existing) {
              await conn.query(
                'UPDATE guardians SET student_id = ? WHERE student_id = ?',
                [newId, existing.id]
              );
            }

            // Insert guardian from staging
            if (stg.guardian_data) {
              const guardians = typeof stg.guardian_data === 'string'
                ? JSON.parse(stg.guardian_data) : stg.guardian_data;
              for (const g of (Array.isArray(guardians) ? guardians : [])) {
                if (g.phone || g.first_name) {
                  await conn.query(
                    `INSERT INTO guardians
                       (id, student_id, guardian_type, first_name, last_name,
                        relation, phone, whatsapp_no, email, occupation, is_primary)
                     VALUES (?,?,?,?,?,?,?,?,?,?,?)
                     ON DUPLICATE KEY UPDATE phone = VALUES(phone)`,
                    [uuid(), newId, g.guardian_type || 'father',
                     g.first_name || 'Guardian', g.last_name || null,
                     g.relation || null, g.phone || null,
                     g.whatsapp_no || null, g.email || null,
                     g.occupation || null, g.is_primary ? 1 : 0]
                  );
                }
              }
            }
          });
        } catch (rowErr) {
          logger.warn(`[bulk confirm] row ${stg.row_number} skipped: ${rowErr.message}`);
          skipped++;
          if (inserted > 0) inserted--;
          else if (replaced > 0) replaced--;
        }
      }

      await query(
        `UPDATE bulk_batches SET status='completed', success_rows=?, confirmed_at=NOW(), confirmed_by=? WHERE id=?`,
        [inserted + replaced, userId, req.params.batchId]
      );

      logger.info(`[bulk students] batch ${req.params.batchId} confirmed: +${inserted} new, ${replaced} replaced, ${skipped} skipped`);
      res.json({ success: true, data: { inserted, replaced, skipped, total: stagingRows.length, batchId: req.params.batchId } });
    } catch (err) { next(err); }
  }
);

// ── Upload history — registered earlier (before /:id/history) ──
// See the /bulk-upload/history route above near line 214.

// ── Legacy: POST /students/validate-bulk (kept for backward compat) ──
router.post('/validate-bulk', authenticate, upload.single('file'), async (req, res, next) => {
  try {
    if (!req.file) return res.status(400).json({ success: false, message: 'No file uploaded' });
    const wb = xlsx.readFile(req.file.path);
    const sheetName = wb.SheetNames.find(n => n !== 'Instructions') || wb.SheetNames[0];
    const rows = xlsx.utils.sheet_to_json(wb.Sheets[sheetName], { defval: '' });
    try { fs.unlinkSync(req.file.path); } catch (_) {}

    const effectiveSchoolId = req.employee?.school_id || req.user.school_id;
    const existingIds = new Set(
      (await query('SELECT student_id FROM students WHERE school_id = ? AND is_current = TRUE', [effectiveSchoolId]))
        .map(r => r.student_id)
    );

    const results = rows.map((row, idx) => {
      const errors = []; const warnings = [];
      const stuId = getField(row,'student_id*','student_id');
      const fn    = getField(row,'first_name*','first_name');
      const gender= getField(row,'gender*','gender').toLowerCase();
      const cls   = getField(row,'class_name*','class_name');
      const sec   = getField(row,'section*','section');
      const gPhone= getField(row,'guardian_phone*','guardian_phone');
      const dob   = getField(row,'date_of_birth*','date_of_birth');

      if (!stuId)   errors.push('Student ID is required');
      if (!fn)      errors.push('First name is required');
      if (!cls)     errors.push('Class name is required');
      if (!sec)     errors.push('Section is required');
      if (!VALID_GENDERS.has(gender)) errors.push('Gender must be male/female/other');
      if (dob && isNaN(Date.parse(dob))) errors.push('Invalid date of birth format');
      if (gPhone && !PHONE_RE.test(gPhone)) errors.push('Guardian phone: 10 digits starting 6-9');
      if (stuId && existingIds.has(stuId)) warnings.push('Existing student — new SCD version will be created');
      if (!row['blood_group']) warnings.push('Blood group missing');
      if (!row['category'])    warnings.push('Category missing — defaults to General');

      return {
        row: idx + 2,
        status: errors.length > 0 ? 'failed' : warnings.length > 0 ? 'warning' : 'success',
        errors, warnings,
        data: { stuId, firstName: fn, gender, cls, sec, gPhone },
      };
    });

    const totalOk   = results.filter(r => r.status !== 'failed').length;
    const totalFail = results.filter(r => r.status === 'failed').length;
    res.json({ success: true, data: { results, totalOk, totalFail, canSubmit: totalFail === 0 } });
  } catch (err) {
    try { if (req.file) fs.unlinkSync(req.file.path); } catch (_) {}
    next(err);
  }
});

module.exports = router;
