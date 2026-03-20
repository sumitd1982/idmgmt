const router = require('express').Router();
const { v4: uuid } = require('uuid');
const { query } = require('../models/db');
const { authenticate, requireRole } = require('../middleware/auth');

router.get('/roles/:school_id', authenticate, async (req, res, next) => {
  try {
    const roles = await query(
      'SELECT * FROM org_roles WHERE school_id=? ORDER BY sort_order', [req.params.school_id]
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
