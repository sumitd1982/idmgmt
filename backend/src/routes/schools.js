// ============================================================
// Schools CRUD + Management Routes
// ============================================================
const router  = require('express').Router();
const { v4: uuid } = require('uuid');
const { query, transaction } = require('../models/db');
const { authenticate, requireRole, requireSchoolAccess } = require('../middleware/auth');
const { body, param, query: qv, validationResult } = require('express-validator');

const validate = (req, res, next) => {
  const errors = validationResult(req);
  if (!errors.isEmpty()) {
    console.error('Validation Errors for School Creation:', JSON.stringify(errors.array(), null, 2));
    return res.status(422).json({ success: false, errors: errors.array() });
  }
  next();
};

// ── GET /schools — list all schools ───────────────────────────
router.get('/', authenticate, async (req, res, next) => {
  try {
    const { page = 1, limit = 20, search, city, country } = req.query;
    const offset = (page - 1) * limit;
    let where = ['1=1'];
    let params = [];

    if (req.user.role !== 'super_admin') {
      if (!req.employee) {
        // Viewer with no employee record — no school access at all
        return res.json({ success: true, data: [], meta: { total: 0, page: +page, limit: +limit } });
      }
      where.push('s.id = ?');
      params.push(req.employee.school_id);
    }
    if (search) { where.push('(s.name LIKE ? OR s.code LIKE ?)'); params.push(`%${search}%`, `%${search}%`); }
    if (city)   { where.push('s.city = ?'); params.push(city); }
    if (country){ where.push('s.country = ?'); params.push(country); }

    const schools = await query(
      `SELECT s.*,
              COUNT(DISTINCT b.id) AS branch_count,
              COUNT(DISTINCT e.id) AS employee_count
       FROM schools s
       LEFT JOIN branches b ON b.school_id = s.id AND b.is_active = TRUE
       LEFT JOIN employees e ON e.school_id = s.id AND e.is_active = TRUE
       WHERE ${where.join(' AND ')}
       GROUP BY s.id
       ORDER BY s.name
       LIMIT ? OFFSET ?`,
      [...params, parseInt(limit), parseInt(offset)]
    );

    const [{ total }] = await query(
      `SELECT COUNT(*) AS total FROM schools s WHERE ${where.join(' AND ')}`,
      params
    );

    res.json({ success: true, data: schools, meta: { total, page: +page, limit: +limit } });
  } catch (err) { next(err); }
});

// ── GET /schools/:id ──────────────────────────────────────────
router.get('/:id', authenticate, async (req, res, next) => {
  try {
    // Non-super_admin users can only view their own school
    if (req.user.role !== 'super_admin') {
      if (!req.employee || req.employee.school_id !== req.params.id) {
        return res.status(403).json({ success: false, message: 'Not authorized for this school' });
      }
    }
    const [school] = await query(
      `SELECT s.*, u.full_name AS created_by_name
       FROM schools s
       JOIN users u ON u.id = s.created_by
       WHERE s.id = ?`, [req.params.id]
    );
    if (!school) return res.status(404).json({ success: false, message: 'School not found' });
    res.json({ success: true, data: school });
  } catch (err) { next(err); }
});

// ── POST /schools — create school ────────────────────────────
router.post('/',
  authenticate,
  requireRole('super_admin', 'viewer', 'onboarding'),
  [
    body('name').notEmpty().trim().isLength({ max: 255 }),
    body('code').notEmpty().trim().toUpperCase().isLength({ max: 20 }),
    body('address_line1').notEmpty().trim(),
    body('city').notEmpty().trim(),
    body('state').notEmpty().trim(),
    body('country').notEmpty().trim(),
    body('zip_code').notEmpty().trim(),
    body('phone1').notEmpty().trim(),
    body('email').notEmpty().trim().isEmail().normalizeEmail(),
  ],
  validate,
  async (req, res, next) => {
    try {
      const id = uuid();
      const {
        name, short_name, code, affiliation_no, affiliation_board, school_type,
        address_line1, address_line2, city, district, state, country, zip_code,
        phone1, phone2, email, website, principal_name, whatsapp_no,
        facebook_url, twitter_url, instagram_url,
        academic_year, timezone
      } = req.body;

      // Check code uniqueness
      const [existing] = await query('SELECT id FROM schools WHERE code = ?', [code]);
      if (existing) return res.status(409).json({ success: false, message: 'School code already exists' });

      await query(
        `INSERT INTO schools (id, name, short_name, code, affiliation_no, affiliation_board,
          school_type, address_line1, address_line2, city, district, state, country, zip_code,
          phone1, phone2, email, website, principal_name, whatsapp_no, facebook_url, twitter_url,
          instagram_url, academic_year, timezone, created_by)
         VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)`,
        [id, name, short_name ?? null, code, affiliation_no ?? null, affiliation_board ?? null,
         school_type || 'private', address_line1, address_line2 ?? null, city, district ?? null,
         state, country, zip_code,
         phone1, phone2 ?? null, email, website ?? null, principal_name ?? null,
         whatsapp_no ?? null, facebook_url ?? null, twitter_url ?? null,
         instagram_url ?? null, academic_year || '2025-26', timezone || 'Asia/Kolkata', req.user.id]
      );

      // Default org roles for new school
      const roles = [
        ['PRINCIPAL','Principal',1,true,true],['VP','Vice Principal',2,true,true],
        ['HEAD_TEACHER','Head Teacher',3,true,true],['SR_TEACHER','Senior Teacher',4,true,false],
        ['CL_TEACHER','Class Teacher',5,true,false],['SUB_TEACHER','Subject Teacher',6,false,false],
        ['BAK_TEACHER','Backup Teacher',7,false,false],['TMP_TEACHER','Temp Teacher',8,false,false]
      ];
      for (const [code2, rname, level, can_approve, can_upload] of roles) {
        await query(
          'INSERT INTO org_roles (id,school_id,name,code,level,can_approve,can_upload_bulk,sort_order) VALUES (?,?,?,?,?,?,?,?)',
          [uuid(), id, rname, code2, level, can_approve, can_upload, level]
        );
      }

      // If a non-super_admin created this school, promote them to school_owner + Principal
      if (req.user.role !== 'super_admin') {
        await query(
          'UPDATE users SET role = "school_owner", school_id = ?, updated_at = CURRENT_TIMESTAMP WHERE id = ?',
          [id, req.user.id]
        );
        
        // Also create Principal employee record for them
        const empId = uuid();
        const [principalRole] = await query('SELECT id FROM org_roles WHERE school_id = ? AND code = "PRINCIPAL"', [id]);
        
        if (principalRole) {
          await query(
            `INSERT INTO employees (id, user_id, school_id, org_role_id, employee_id, first_name, last_name, email, is_active)
             VALUES (?, ?, ?, ?, ?, ?, ?, ?, TRUE)`,
            [empId, req.user.id, id, principalRole.id, 'PRIN001', req.user.full_name.split(' ')[0], req.user.full_name.split(' ').slice(1).join(' ') || 'Owner', req.user.email]
          );
        }
      }

      const [school] = await query('SELECT * FROM schools WHERE id = ?', [id]);
      res.status(201).json({ success: true, data: school, message: 'School created successfully' });
    } catch (err) { next(err); }
  }
);

// ── PUT /schools/:id ─────────────────────────────────────────
router.put('/:id',
  authenticate,
  requireRole('super_admin', 'principal', 'vp'),
  requireSchoolAccess,
  async (req, res, next) => {
    try {
      const allowed = ['name','short_name','affiliation_no','affiliation_board','school_type',
        'address_line1','address_line2','city','district','state','country','zip_code',
        'phone1','phone2','email','website','principal_name','whatsapp_no',
        'facebook_url','twitter_url','instagram_url','logo_url','banner_url',
        'academic_year','timezone','is_active', 'settings'];

      if (req.body.settings && typeof req.body.settings === 'object') {
        req.body.settings = JSON.stringify(req.body.settings);
      }

      const fields = Object.keys(req.body).filter(k => allowed.includes(k));
      if (!fields.length) return res.status(400).json({ success: false, message: 'No valid fields to update' });

      // Save history snapshot before update
      const [before] = await query('SELECT * FROM schools WHERE id = ?', [req.params.id]);
      if (before) {
        // Safely serialize settings: JSON column returns object from mysql2; history column is also JSON
        const settingsSnap = before.settings == null ? null
          : (typeof before.settings === 'object' ? JSON.stringify(before.settings) : before.settings);
        await query(
          `INSERT INTO school_history
            (school_id, name, short_name, code, logo_url, banner_url, affiliation_no, affiliation_board,
             school_type, principal_name, address_line1, address_line2, city, district, state, country,
             zip_code, phone1, phone2, email, website, whatsapp_no, facebook_url, twitter_url,
             instagram_url, academic_year, settings, changed_by)
           VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)`,
          [req.params.id, before.name, before.short_name, before.code, before.logo_url, before.banner_url,
           before.affiliation_no, before.affiliation_board, before.school_type, before.principal_name,
           before.address_line1, before.address_line2, before.city, before.district, before.state, before.country,
           before.zip_code, before.phone1, before.phone2, before.email, before.website, before.whatsapp_no,
           before.facebook_url, before.twitter_url, before.instagram_url, before.academic_year,
           settingsSnap, req.user.id]
        );
      }

      const sql = `UPDATE schools SET ${fields.map(f => `${f} = ?`).join(', ')}, updated_by = ? WHERE id = ?`;
      await query(sql, [...fields.map(f => req.body[f]), req.user.id, req.params.id]);

      const [school] = await query('SELECT * FROM schools WHERE id = ?', [req.params.id]);
      res.json({ success: true, data: school });
    } catch (err) { next(err); }
  }
);

// ── GET /schools/:id/stats ────────────────────────────────────
router.get('/:id/stats', authenticate, async (req, res, next) => {
  try {
    // Non-super_admin users can only view stats for their own school
    if (req.user.role !== 'super_admin') {
      if (!req.employee || req.employee.school_id !== req.params.id) {
        return res.status(403).json({ success: false, message: 'Not authorized for this school' });
      }
    }
    const [stats] = await query(
      `SELECT
         (SELECT COUNT(*) FROM branches WHERE school_id = ? AND is_active=1) AS branches,
         (SELECT COUNT(*) FROM employees WHERE school_id = ? AND is_active=1) AS employees,
         (SELECT COUNT(*) FROM students WHERE school_id = ? AND is_active=1) AS students,
         (SELECT COUNT(*) FROM students WHERE school_id = ? AND status_color='green') AS students_approved,
         (SELECT COUNT(*) FROM students WHERE school_id = ? AND status_color='blue') AS students_changed,
         (SELECT COUNT(*) FROM students WHERE school_id = ? AND status_color='red') AS students_pending`,
      Array(6).fill(req.params.id)
    );
    res.json({ success: true, data: stats });
  } catch (err) { next(err); }
});

module.exports = router;
