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
    const { name, short_name, logo_url,
      address_line1, address_line2, city, state, country, zip_code,
      phone1, phone2, email, website, whatsapp_no } = req.body;

    // Accept 'code' or 'branch_code' from frontend
    const code = req.body.code || req.body.branch_code;
    // Security: Only super_admin can specify a school_id for other schools
    const effectiveSchoolId = req.user.role === 'super_admin' 
      ? (req.body.school_id || req.employee?.school_id || req.user.school_id) 
      : (req.employee?.school_id || req.user.school_id);

    if (!effectiveSchoolId) {
      return res.status(422).json({ success: false, message: 'school_id is required' });
    }
    if (!name || !code) {
      return res.status(422).json({ success: false, message: 'name and code are required' });
    }

    await query(
      `INSERT INTO branches (id,school_id,name,short_name,code,logo_url,
         address_line1,address_line2,city,state,country,zip_code,
         phone1,phone2,email,website,whatsapp_no,created_by)
       VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)`,
      [id, effectiveSchoolId, name, short_name || name, code, logo_url,
       address_line1 || '', address_line2, city || '', state || '', country || 'India', zip_code || '',
       phone1 || '', phone2, email || '', website, whatsapp_no, req.user.id]
    );
    const [branch] = await query('SELECT * FROM branches WHERE id = ?', [id]);
    res.status(201).json({ success: true, data: branch });
  } catch (err) { next(err); }
});

router.put('/:id', authenticate, requireRole('super_admin','school_owner','principal','vp'), async (req, res, next) => {
  try {
    const allowed = ['name','short_name','logo_url','address_line1','address_line2','city','state',
                     'country','zip_code','phone1','phone2','email','website','whatsapp_no','is_active'];
    const fields = Object.keys(req.body).filter(k => allowed.includes(k));
    if (!fields.length) return res.status(400).json({ success: false, message: 'No valid fields' });
    await query(`UPDATE branches SET ${fields.map(f => `${f}=?`).join(',')} WHERE id=?`,
      [...fields.map(f => req.body[f]), req.params.id]);
    const [branch] = await query('SELECT * FROM branches WHERE id = ?', [req.params.id]);
    res.json({ success: true, data: branch });
  } catch (err) { next(err); }
});

module.exports = router;
