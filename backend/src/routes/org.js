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
    const { school_id, name, code, level, description, can_approve, can_upload_bulk } = req.body;
    await query(
      `INSERT INTO org_roles (id,school_id,name,code,level,description,can_approve,can_upload_bulk,sort_order)
       VALUES (?,?,?,?,?,?,?,?,?)`,
      [id, school_id, name, code, level, description, can_approve, can_upload_bulk, level]
    );
    const [role] = await query('SELECT * FROM org_roles WHERE id=?', [id]);
    res.status(201).json({ success: true, data: role });
  } catch (err) { next(err); }
});

router.put('/roles/:id', authenticate, requireRole('super_admin','principal','vp'), async (req, res, next) => {
  try {
    const { name, description, can_approve, can_upload_bulk, is_active } = req.body;
    await query(
      'UPDATE org_roles SET name=?,description=?,can_approve=?,can_upload_bulk=?,is_active=? WHERE id=?',
      [name, description, can_approve, can_upload_bulk, is_active, req.params.id]
    );
    const [role] = await query('SELECT * FROM org_roles WHERE id=?', [req.params.id]);
    res.json({ success: true, data: role });
  } catch (err) { next(err); }
});

module.exports = router;
