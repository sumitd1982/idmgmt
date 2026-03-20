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
    const sid = school_id || req.employee?.school_id;
    if (sid)         { where.push('e.school_id = ?');    params.push(sid); }
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
              CONCAT(m.first_name,' ',m.last_name) AS manager_name
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
              b.name AS branch_name, sch.name AS school_name
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

router.post('/', authenticate, requireRole('super_admin','principal','vp','head_teacher'), async (req, res, next) => {
  try {
    const id = uuid();
    const { branch_id, employee_id, org_role_id, reports_to_emp_id,
      first_name, last_name, email, phone, whatsapp_no, alt_phone,
      date_of_joining, gender, date_of_birth, address_line1, city, state, country, zip_code,
      qualification, specialization, experience_years, assigned_classes, is_temp } = req.body;

    // Auto-resolve school_id from employee context if not provided
    const effectiveSchoolId = req.body.school_id || req.employee?.school_id;
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
    if (!fields.length) return res.status(400).json({ success: false, message: 'No valid fields to update' });
    await query(`UPDATE employees SET ${fields.map(f => `${f}=?`).join(',')} WHERE id=?`,
      [...fields.map(f => req.body[f]), req.params.id]);
    const [emp] = await query('SELECT * FROM employees WHERE id = ?', [req.params.id]);
    res.json({ success: true, data: emp });
  } catch (err) { next(err); }
});

// Soft delete (deactivate) employee
router.delete('/:id', authenticate, requireRole('super_admin','principal','vp'), async (req, res, next) => {
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

// Bulk upload template
router.get('/bulk-template/download', authenticate, async (req, res, next) => {
  try {
    const wb = xlsx.utils.book_new();
    const headers = [['employee_id','first_name','last_name','gender','date_of_birth','email',
      'phone','whatsapp_no','org_role_code','reports_to_employee_id','date_of_joining',
      'address','city','state','zip_code','qualification','specialization','assigned_classes']];
    const ws = xlsx.utils.aoa_to_sheet(headers);
    xlsx.utils.book_append_sheet(wb, ws, 'Employees');
    const buf = xlsx.write(wb, { type: 'buffer', bookType: 'xlsx' });
    res.setHeader('Content-Disposition', 'attachment; filename="employee_upload_template.xlsx"');
    res.setHeader('Content-Type', 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
    res.send(buf);
  } catch (err) { next(err); }
});

// Org tree
router.get('/org-tree/:school_id', authenticate, async (req, res, next) => {
  try {
    const employees = await query(
      `SELECT e.id, e.employee_id, e.first_name, e.last_name, e.photo_url,
              e.reports_to_emp_id, r.name AS role_name, r.level AS role_level,
              b.name AS branch_name
       FROM employees e
       JOIN org_roles r ON r.id = e.org_role_id
       LEFT JOIN branches b ON b.id = e.branch_id
       WHERE e.school_id = ? AND e.is_active = TRUE
       ORDER BY r.level, e.last_name`, [req.params.school_id]
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

module.exports = router;
