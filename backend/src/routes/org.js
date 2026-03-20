const router = require('express').Router();
const { v4: uuid } = require('uuid');
const { query } = require('../models/db');
const { authenticate, requireRole } = require('../middleware/auth');

router.get('/roles/:school_id', authenticate, async (req, res, next) => {
  try {
    const schoolId = req.params.school_id;
    // Security: Only super_admin can override the school context
    const effectiveSchoolId = req.user.role === 'super_admin' 
      ? (schoolId || req.employee?.school_id) 
      : req.employee?.school_id;

    if (!effectiveSchoolId || (req.user.role !== 'super_admin' && effectiveSchoolId !== schoolId)) {
      // If non-super_admin requested a different school, return their own school's data instead or empty
      // To match frontend expectations, we'll return data for the effective school
      const roles = await query(
        'SELECT * FROM org_roles WHERE school_id=? ORDER BY sort_order', [effectiveSchoolId]
      );
      return res.json({ success: true, data: roles });
    }

    const roles = await query(
      'SELECT * FROM org_roles WHERE school_id=? ORDER BY sort_order', [effectiveSchoolId]
    );
    res.json({ success: true, data: roles });
  } catch (err) { next(err); }
});

router.post('/roles', authenticate, requireRole('super_admin','principal','vp'), async (req, res, next) => {
  try {
    const id = uuid();
    const { school_id, name, code, level, description, can_approve, can_upload_bulk, permissions = {} } = req.body;
    await query(
      `INSERT INTO org_roles (id,school_id,name,code,level,description,can_approve,can_upload_bulk,sort_order,permissions)
       VALUES (?,?,?,?,?,?,?,?,?,?)`,
      [id, school_id, name, code, level, description, can_approve, can_upload_bulk, level, JSON.stringify(permissions)]
    );
    const [role] = await query('SELECT * FROM org_roles WHERE id=?', [id]);
    res.status(201).json({ success: true, data: role });
  } catch (err) { next(err); }
});

router.put('/roles/:id', authenticate, requireRole('super_admin','principal','vp'), async (req, res, next) => {
  try {
    const { name, description, can_approve, can_upload_bulk, is_active, permissions } = req.body;
    
    // If permissions is provided, serialize it. Otherwise leave it alone (or update if needed, but standard is override).
    let updateQuery = 'UPDATE org_roles SET name=?,description=?,can_approve=?,can_upload_bulk=?,is_active=?';
    let params = [name, description, can_approve, can_upload_bulk, is_active];
    
    if (permissions !== undefined) {
      updateQuery += ', permissions=?';
      params.push(JSON.stringify(permissions));
    }
    
    updateQuery += ' WHERE id=?';
    params.push(req.params.id);

    await query(updateQuery, params);
    
    const [role] = await query('SELECT * FROM org_roles WHERE id=?', [req.params.id]);
    res.json({ success: true, data: role });
  } catch (err) { next(err); }
});

module.exports = router;
