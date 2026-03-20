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
  requireRole('super_admin', 'principal', 'vp'),
  [
    body('name').notEmpty().trim().isLength({ max: 255 }),
    body('code').notEmpty().trim().toUpperCase().isAlphanumeric().isLength({ max: 20 }),
    body('address_line1').notEmpty().trim(),
    body('city').notEmpty().trim(),
    body('state').notEmpty().trim(),
    body('country').notEmpty().trim(),
    body('zip_code').notEmpty().trim(),
    body('phone1').notEmpty().trim().isMobilePhone(),
    body('email').notEmpty().trim().isEmail().normalizeEmail(),
  ],
  validate,
  async (req, res, next) => {
    try {
      const id = uuid();
      const {
        name, short_name, code, affiliation_no, affiliation_board, school_type,
        address_line1, address_line2, city, state, country, zip_code,
        phone1, phone2, email, website, whatsapp_no,
        facebook_url, twitter_url, instagram_url,
        academic_year, timezone
      } = req.body;

      // Check code uniqueness
      const [existing] = await query('SELECT id FROM schools WHERE code = ?', [code]);
      if (existing) return res.status(409).json({ success: false, message: 'School code already exists' });

      await query(
        `INSERT INTO schools (id, name, short_name, code, affiliation_no, affiliation_board,
          school_type, address_line1, address_line2, city, state, country, zip_code,
          phone1, phone2, email, website, whatsapp_no, facebook_url, twitter_url,
          instagram_url, academic_year, timezone, created_by)
         VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)`,
        [id, name, short_name, code, affiliation_no, affiliation_board,
         school_type || 'private', address_line1, address_line2, city, state, country, zip_code,
         phone1, phone2, email, website, whatsapp_no, facebook_url, twitter_url,
         instagram_url, academic_year || '2025-26', timezone || 'Asia/Kolkata', req.user.id]
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
        'address_line1','address_line2','city','state','country','zip_code',
        'phone1','phone2','email','website','whatsapp_no',
        'facebook_url','twitter_url','instagram_url','logo_url','banner_url',
        'academic_year','timezone','is_active', 'settings'];

      if (req.body.settings && typeof req.body.settings === 'object') {
        req.body.settings = JSON.stringify(req.body.settings);
      }

      const fields = Object.keys(req.body).filter(k => allowed.includes(k));
      if (!fields.length) return res.status(400).json({ success: false, message: 'No valid fields to update' });

      const sql = `UPDATE schools SET ${fields.map(f => `${f} = ?`).join(', ')} WHERE id = ?`;
      await query(sql, [...fields.map(f => req.body[f]), req.params.id]);

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
