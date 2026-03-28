const router = require('express').Router();
const { v4: uuid } = require('uuid');
const { query } = require('../models/db');
const { authenticate, requireRole } = require('../middleware/auth');

router.get('/', authenticate, async (req, res, next) => {
  try {
    const { school_id, city, country, search } = req.query;
    let where = ['b.is_active = TRUE'];
    let params = [];

    // Security: Only super_admin can override the school context via query params
    const effectiveSchoolId = req.user.role === 'super_admin'
      ? (school_id || req.employee?.school_id || req.user.school_id)
      : (req.employee?.school_id || req.user.school_id);

    // Non-super_admin with no school context sees nothing
    if (req.user.role !== 'super_admin' && !effectiveSchoolId) {
      return res.json({ success: true, data: [] });
    }

    if (effectiveSchoolId) { where.push('b.school_id = ?'); params.push(effectiveSchoolId); }
    if (city)   { where.push('b.city = ?');      params.push(city); }
    if (country){ where.push('b.country = ?');   params.push(country); }
    if (search) { where.push('b.name LIKE ?');   params.push(`%${search}%`); }

    const branches = await query(
      `SELECT b.*, s.name AS school_name,
              COUNT(DISTINCT e.id) AS employee_count,
              COUNT(DISTINCT st.id) AS student_count
       FROM branches b
       JOIN schools s ON s.id = b.school_id
       LEFT JOIN employees e ON e.branch_id = b.id AND e.is_active = TRUE
       LEFT JOIN students st ON st.branch_id = b.id AND st.is_active = TRUE
       WHERE ${where.join(' AND ')}
       GROUP BY b.id ORDER BY b.name`, params
    );
    res.json({ success: true, data: branches });
  } catch (err) { next(err); }
});

router.post('/', authenticate, requireRole('super_admin','school_owner','principal','vp'), async (req, res, next) => {
  try {
    const id = uuid();
    const { short_name, logo_url,
      address_line1, address_line2, city, state, country, zip_code,
      phone1, phone2, email, website, whatsapp_no } = req.body;

    // Trim and validate required string fields
    const name = typeof req.body.name === 'string' ? req.body.name.trim() : '';
    // Accept 'code' or 'branch_code' from frontend, then trim
    const rawCode = req.body.code || req.body.branch_code;
    const code = typeof rawCode === 'string' ? rawCode.trim() : '';

    // Security: Only super_admin can specify a school_id for other schools
    const effectiveSchoolId = req.user.role === 'super_admin'
      ? (req.body.school_id || req.employee?.school_id || req.user.school_id)
      : (req.employee?.school_id || req.user.school_id);

    if (!effectiveSchoolId) {
      return res.status(422).json({ success: false, message: 'school_id is required' });
    }
    if (!name) {
      return res.status(422).json({ success: false, message: 'name and code are required' });
    }
    if (!code) {
      return res.status(422).json({ success: false, message: 'name and code are required' });
    }

    // Length guards (prevent silent DB truncation / 5xx)
    if (name.length > 255) {
      return res.status(422).json({ success: false, message: 'name must be 255 characters or fewer' });
    }
    if (code.length > 20) {
      return res.status(422).json({ success: false, message: 'code must be 20 characters or fewer' });
    }
    if (logo_url != null && String(logo_url).length > 1024) {
      return res.status(422).json({ success: false, message: 'logo_url must be 1024 characters or fewer' });
    }
    for (const [field, val] of [['phone1', phone1], ['phone2', phone2], ['whatsapp_no', whatsapp_no]]) {
      if (val != null && String(val).length > 20) {
        return res.status(422).json({ success: false, message: `${field} must be 20 characters or fewer` });
      }
    }

    // short_name: cap at 50 chars to match VARCHAR(50), fall back to null (not name)
    const effectiveShortName = short_name ? String(short_name).slice(0, 50) : null;

    await query(
      `INSERT INTO branches (id,school_id,name,short_name,code,logo_url,
         address_line1,address_line2,city,state,country,zip_code,
         phone1,phone2,email,website,whatsapp_no,created_by)
       VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)`,
      [id, effectiveSchoolId, name, effectiveShortName, code, logo_url || null,
       address_line1 || '', address_line2 || null, city || '', state || '', country || 'India', zip_code || '',
       phone1 || '', phone2 || null, email || '', website || null, whatsapp_no || null, req.user.id]
    );
    const [branch] = await query('SELECT * FROM branches WHERE id = ?', [id]);

    // ── Seed default class sections ───────────────────────────
    // Pre-load Nursery/LKG/UKG/1–12 each with sections A and B
    const defaultClasses = [
      { name: 'Nursery', level: 0 }, { name: 'LKG', level: 0 }, { name: 'UKG', level: 0 },
      { name: '1', level: 1 }, { name: '2', level: 2 }, { name: '3', level: 3 },
      { name: '4', level: 4 }, { name: '5', level: 5 }, { name: '6', level: 6 },
      { name: '7', level: 7 }, { name: '8', level: 8 }, { name: '9', level: 9 },
      { name: '10', level: 10 }, { name: '11', level: 11 }, { name: '12', level: 12 },
    ];
    const defaultSections = ['A', 'B'];

    for (const cls of defaultClasses) {
      const classId = uuid();
      await query(
        `INSERT IGNORE INTO classes (id, branch_id, name, numeric_level, sections)
         VALUES (?, ?, ?, ?, ?)`,
        [classId, id, cls.name, cls.level || null, JSON.stringify(defaultSections)]
      );
      // Fetch the actual id (might already exist via IGNORE)
      const [row] = await query('SELECT id FROM classes WHERE branch_id = ? AND name = ?', [id, cls.name]);
      const cid = row?.id || classId;
      for (const sec of defaultSections) {
        await query(
          `INSERT IGNORE INTO class_sections (id, class_id, section, class_name, branch_id, school_id)
           VALUES (?, ?, ?, ?, ?, ?)`,
          [uuid(), cid, sec, cls.name, id, effectiveSchoolId]
        );
      }
    }

    res.status(201).json({ success: true, data: branch });
  } catch (err) { next(err); }
});

router.put('/:id', authenticate, requireRole('super_admin','school_owner','principal','vp'), async (req, res, next) => {
  try {
    const allowed = ['name','short_name','logo_url','address_line1','address_line2','city','state',
                     'country','zip_code','phone1','phone2','email','website','whatsapp_no','is_active'];
    const fields = Object.keys(req.body).filter(k => allowed.includes(k));
    if (!fields.length) return res.status(400).json({ success: false, message: 'No valid fields' });

    // Length guards for PUT
    if (req.body.logo_url != null && String(req.body.logo_url).length > 1024) {
      return res.status(422).json({ success: false, message: 'logo_url must be 1024 characters or fewer' });
    }
    for (const phoneField of ['phone1', 'phone2', 'whatsapp_no']) {
      if (req.body[phoneField] != null && String(req.body[phoneField]).length > 20) {
        return res.status(422).json({ success: false, message: `${phoneField} must be 20 characters or fewer` });
      }
    }
    if (req.body.name != null && String(req.body.name).length > 255) {
      return res.status(422).json({ success: false, message: 'name must be 255 characters or fewer' });
    }
    if (req.body.code != null && String(req.body.code).length > 20) {
      return res.status(422).json({ success: false, message: 'code must be 20 characters or fewer' });
    }

    const result = await query(
      `UPDATE branches SET ${fields.map(f => `${f}=?`).join(',')} WHERE id=?`,
      [...fields.map(f => req.body[f]), req.params.id]
    );

    if (result.affectedRows === 0) {
      return res.status(404).json({ success: false, message: 'Branch not found' });
    }

    const [branch] = await query('SELECT * FROM branches WHERE id = ?', [req.params.id]);
    res.json({ success: true, data: branch });
  } catch (err) { next(err); }
});

module.exports = router;
