const router = require('express').Router();
const { v4: uuid } = require('uuid');
const multer = require('multer');
const path   = require('path');
const fs     = require('fs');
const { query } = require('../models/db');
const { authenticate } = require('../middleware/auth');

const ALLOWED_TYPES = ['.pdf','.docx','.doc','.jpg','.jpeg','.png'];

const upload = multer({
  dest: path.join(__dirname, '../../uploads/attachments'),
  limits: { fileSize: 20 * 1024 * 1024, files: 5 },
  fileFilter: (req, file, cb) => {
    const ext = path.extname(file.originalname).toLowerCase();
    if (ALLOWED_TYPES.includes(ext)) { cb(null, true); }
    else { cb(new Error(`Invalid file type. Allowed: ${ALLOWED_TYPES.join(', ')}`)); }
  }
});

router.get('/', authenticate, async (req, res, next) => {
  try {
    const { status, school_id } = req.query;
    const sid = school_id || req.employee?.school_id || null;
    let where = ['rq.school_id = ?'];
    let params = [sid];
    if (status) { where.push('rq.status = ?'); params.push(status); }
    if (req.employee) { where.push('(rq.requested_by = ? OR rq.assigned_to = ?)'); params.push(req.employee.id, req.employee.id); }

    const requests = await query(
      `SELECT rq.*,
              CONCAT(e1.first_name,' ',e1.last_name) AS requester_name,
              CONCAT(e2.first_name,' ',e2.last_name) AS assignee_name
       FROM review_requests rq
       JOIN employees e1 ON e1.id = rq.requested_by
       LEFT JOIN employees e2 ON e2.id = rq.assigned_to
       WHERE ${where.join(' AND ')}
       ORDER BY rq.created_at DESC`, params
    );
    res.json({ success: true, data: requests });
  } catch (err) { next(err); }
});

router.post('/', authenticate, upload.array('attachments', 5), async (req, res, next) => {
  try {
    const id = uuid();
    const { school_id, branch_id, title, description, priority } = req.body;
    const employeeId = req.employee?.id;
    if (!employeeId) return res.status(403).json({ success: false, message: 'Not an employee' });

    // Process attachments
    const attachments = (req.files || []).map(f => ({
      filename: f.originalname,
      url: `/idmgmt/api/static/attachments/${path.basename(f.path)}`,
      type: path.extname(f.originalname).toLowerCase(),
      size: f.size
    }));

    // Move files from temp to attachments
    for (const f of req.files || []) {
      fs.renameSync(f.path, path.join(__dirname, '../../uploads/attachments', path.basename(f.path)));
    }

    // Find N+1 manager
    const [manager] = await query(
      'SELECT reports_to_emp_id FROM employees WHERE id=?', [employeeId]
    );
    const assignedTo = manager?.reports_to_emp_id || null;

    await query(
      `INSERT INTO review_requests (id,school_id,branch_id,requested_by,assigned_to,title,description,priority,attachments)
       VALUES (?,?,?,?,?,?,?,?,?)`,
      [id, school_id, branch_id, employeeId, assignedTo, title, description, priority || 'medium',
       JSON.stringify(attachments)]
    );

    const [request] = await query('SELECT * FROM review_requests WHERE id=?', [id]);
    res.status(201).json({ success: true, data: request });
  } catch (err) { next(err); }
});

router.patch('/:id/status', authenticate, async (req, res, next) => {
  try {
    const { status, response_text } = req.body;
    await query(
      'UPDATE review_requests SET status=?,response_text=?,responded_at=NOW() WHERE id=?',
      [status, response_text, req.params.id]
    );
    res.json({ success: true, message: 'Status updated' });
  } catch (err) { next(err); }
});

module.exports = router;
