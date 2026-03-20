// ============================================================
// ID Card Templates — CRUD + Maker-Checker-Approver Workflow
// ============================================================
const router      = require('express').Router();
const { v4: uuid } = require('uuid');
const { query, transaction } = require('../models/db');
const { authenticate, requireRole } = require('../middleware/auth');
const logger      = require('../utils/logger');

// ── Helpers ───────────────────────────────────────────────────
const VALID_STATUSES = ['draft','pending_check','pending_approval','approved','rejected','active'];

function mapElement(row) {
  return {
    id:             row.id,
    templateId:     row.template_id,
    side:           row.side,
    elementType:    row.element_type,
    fieldSource:    row.field_source,
    fieldKey:       row.field_key,
    label:          row.label,
    staticContent:  row.static_content,
    xPct:           row.x_pct,
    yPct:           row.y_pct,
    wPct:           row.w_pct,
    hPct:           row.h_pct,
    rotationDeg:    row.rotation_deg,
    zIndex:         row.z_index,
    fontSize:       row.font_size,
    fontWeight:     row.font_weight,
    fontColor:      row.font_color,
    textAlign:      row.text_align,
    fontItalic:     !!row.font_italic,
    bgColor:        row.bg_color,
    borderColor:    row.border_color,
    borderWidth:    row.border_width,
    borderRadius:   row.border_radius,
    opacity:        row.opacity,
    imageUrl:       row.image_url,
    objectFit:      row.object_fit,
    shapeType:      row.shape_type,
    fillColor:      row.fill_color,
    sortOrder:      row.sort_order,
  };
}

function mapTemplate(row, elements = []) {
  return {
    id:            row.id,
    schoolId:      row.school_id,
    branchId:      row.branch_id,
    name:          row.name,
    templateType:  row.template_type,
    status:        row.status,
    cardWidthMm:   row.card_width_mm,
    cardHeightMm:  row.card_height_mm,
    createdBy:     row.created_by,
    submittedBy:   row.submitted_by,
    checkedBy:     row.checked_by,
    approvedBy:    row.approved_by,
    submittedAt:   row.submitted_at,
    checkedAt:     row.checked_at,
    approvedAt:    row.approved_at,
    checkNotes:    row.check_notes,
    approvalNotes: row.approval_notes,
    version:       row.version,
    isActive:      !!row.is_active,
    createdAt:     row.created_at,
    updatedAt:     row.updated_at,
    elements,
  };
}

// ── GET /id-templates ─────────────────────────────────────────
router.get('/', authenticate, async (req, res, next) => {
  try {
    const { school_id, branch_id, template_type, status, search,
            page = 1, limit = 50 } = req.query;
    const offset = (Number(page) - 1) * Number(limit);

    let where  = ['t.is_active = 1'];
    let params = [];

    const effectiveSchoolId = school_id || req.employee?.school_id;
    if (effectiveSchoolId) { where.push('t.school_id = ?');    params.push(effectiveSchoolId); }
    if (branch_id)         { where.push('t.branch_id = ?');    params.push(branch_id); }
    if (template_type)     { where.push('t.template_type = ?'); params.push(template_type); }
    if (status)            { where.push('t.status = ?');       params.push(status); }
    if (search)            {
      where.push('t.name LIKE ?');
      params.push(`%${search}%`);
    }

    const whereClause = where.join(' AND ');

    const [{ total }] = await query(
      `SELECT COUNT(*) AS total FROM id_templates t WHERE ${whereClause}`,
      params
    );

    const rows = await query(
      `SELECT t.*,
              u1.display_name AS created_by_name,
              u2.display_name AS submitted_by_name,
              u3.display_name AS checked_by_name,
              u4.display_name AS approved_by_name
       FROM id_templates t
       LEFT JOIN users u1 ON u1.id = t.created_by
       LEFT JOIN users u2 ON u2.id = t.submitted_by
       LEFT JOIN users u3 ON u3.id = t.checked_by
       LEFT JOIN users u4 ON u4.id = t.approved_by
       WHERE ${whereClause}
       ORDER BY t.created_at DESC
       LIMIT ? OFFSET ?`,
      [...params, Number(limit), offset]
    );

    res.json({
      success: true,
      data: rows.map(r => mapTemplate(r)),
      pagination: { total, page: Number(page), limit: Number(limit), pages: Math.ceil(total / limit) }
    });
  } catch (err) { next(err); }
});

// ── GET /id-templates/:id ─────────────────────────────────────
router.get('/:id', authenticate, async (req, res, next) => {
  try {
    const [row] = await query(
      `SELECT t.*,
              u1.display_name AS created_by_name,
              u2.display_name AS submitted_by_name,
              u3.display_name AS checked_by_name,
              u4.display_name AS approved_by_name
       FROM id_templates t
       LEFT JOIN users u1 ON u1.id = t.created_by
       LEFT JOIN users u2 ON u2.id = t.submitted_by
       LEFT JOIN users u3 ON u3.id = t.checked_by
       LEFT JOIN users u4 ON u4.id = t.approved_by
       WHERE t.id = ? AND t.is_active = 1`,
      [req.params.id]
    );
    if (!row) return res.status(404).json({ success: false, message: 'Template not found' });

    const elementRows = await query(
      'SELECT * FROM id_template_elements WHERE template_id = ? ORDER BY z_index, sort_order',
      [req.params.id]
    );

    res.json({ success: true, data: mapTemplate(row, elementRows.map(mapElement)) });
  } catch (err) { next(err); }
});

// ── POST /id-templates ─────────────────────────────────────────
router.post('/', authenticate, async (req, res, next) => {
  try {
    const { school_id, branch_id, name, template_type, card_width_mm, card_height_mm, elements = [] } = req.body;

    if (!name || !school_id) {
      return res.status(400).json({ success: false, message: 'name and school_id are required' });
    }

    const id      = uuid();
    const userId  = req.user?.uid || req.employee?.user_id;

    await transaction(async (conn) => {
      await conn.query(
        `INSERT INTO id_templates
           (id, school_id, branch_id, name, template_type, status, card_width_mm, card_height_mm, created_by)
         VALUES (?, ?, ?, ?, ?, 'draft', ?, ?, ?)`,
        [id, school_id, branch_id || null, name, template_type || 'student',
         card_width_mm || 85.6, card_height_mm || 54.0, userId]
      );

      for (const el of elements) {
        const elId = uuid();
        await conn.query(
          `INSERT INTO id_template_elements
             (id, template_id, side, element_type, field_source, field_key, label, static_content,
              x_pct, y_pct, w_pct, h_pct, rotation_deg, z_index,
              font_size, font_weight, font_color, text_align, font_italic,
              bg_color, border_color, border_width, border_radius, opacity,
              image_url, object_fit, shape_type, fill_color, sort_order)
           VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)`,
          [elId, id, el.side || 'front', el.elementType, el.fieldSource || null,
           el.fieldKey || null, el.label || null, el.staticContent || null,
           el.xPct ?? 5, el.yPct ?? 5, el.wPct ?? 30, el.hPct ?? 10,
           el.rotationDeg ?? 0, el.zIndex ?? 1,
           el.fontSize ?? 10, el.fontWeight || 'normal', el.fontColor || '#1A237E',
           el.textAlign || 'left', el.fontItalic ? 1 : 0,
           el.bgColor || null, el.borderColor || null, el.borderWidth ?? 0,
           el.borderRadius ?? 0, el.opacity ?? 1.0,
           el.imageUrl || null, el.objectFit || 'cover',
           el.shapeType || null, el.fillColor || null, el.sortOrder ?? 0]
        );
      }
    });

    const [created] = await query('SELECT * FROM id_templates WHERE id = ?', [id]);
    const elRows    = await query('SELECT * FROM id_template_elements WHERE template_id = ? ORDER BY z_index, sort_order', [id]);

    logger.info(`ID template created: ${id} by ${userId}`);
    res.status(201).json({ success: true, data: mapTemplate(created, elRows.map(mapElement)) });
  } catch (err) { next(err); }
});

// ── PUT /id-templates/:id ─────────────────────────────────────
router.put('/:id', authenticate, async (req, res, next) => {
  try {
    const [existing] = await query('SELECT * FROM id_templates WHERE id = ? AND is_active = 1', [req.params.id]);
    if (!existing) return res.status(404).json({ success: false, message: 'Template not found' });

    if (!['draft','rejected'].includes(existing.status)) {
      return res.status(400).json({ success: false, message: `Cannot edit template in status: ${existing.status}` });
    }

    const { name, branch_id, template_type, card_width_mm, card_height_mm, elements = [] } = req.body;

    await transaction(async (conn) => {
      await conn.query(
        `UPDATE id_templates SET
           name = COALESCE(?, name),
           branch_id = ?,
           template_type = COALESCE(?, template_type),
           card_width_mm = COALESCE(?, card_width_mm),
           card_height_mm = COALESCE(?, card_height_mm),
           version = version + 1
         WHERE id = ?`,
        [name || null, branch_id !== undefined ? (branch_id || null) : existing.branch_id,
         template_type || null, card_width_mm || null, card_height_mm || null, req.params.id]
      );

      // Full replace of elements
      await conn.query('DELETE FROM id_template_elements WHERE template_id = ?', [req.params.id]);

      for (const el of elements) {
        const elId = uuid();
        await conn.query(
          `INSERT INTO id_template_elements
             (id, template_id, side, element_type, field_source, field_key, label, static_content,
              x_pct, y_pct, w_pct, h_pct, rotation_deg, z_index,
              font_size, font_weight, font_color, text_align, font_italic,
              bg_color, border_color, border_width, border_radius, opacity,
              image_url, object_fit, shape_type, fill_color, sort_order)
           VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)`,
          [elId, req.params.id, el.side || 'front', el.elementType, el.fieldSource || null,
           el.fieldKey || null, el.label || null, el.staticContent || null,
           el.xPct ?? 5, el.yPct ?? 5, el.wPct ?? 30, el.hPct ?? 10,
           el.rotationDeg ?? 0, el.zIndex ?? 1,
           el.fontSize ?? 10, el.fontWeight || 'normal', el.fontColor || '#1A237E',
           el.textAlign || 'left', el.fontItalic ? 1 : 0,
           el.bgColor || null, el.borderColor || null, el.borderWidth ?? 0,
           el.borderRadius ?? 0, el.opacity ?? 1.0,
           el.imageUrl || null, el.objectFit || 'cover',
           el.shapeType || null, el.fillColor || null, el.sortOrder ?? 0]
        );
      }
    });

    const [updated] = await query('SELECT * FROM id_templates WHERE id = ?', [req.params.id]);
    const elRows    = await query('SELECT * FROM id_template_elements WHERE template_id = ? ORDER BY z_index, sort_order', [req.params.id]);

    res.json({ success: true, data: mapTemplate(updated, elRows.map(mapElement)) });
  } catch (err) { next(err); }
});

// ── DELETE /id-templates/:id ───────────────────────────────────
router.delete('/:id', authenticate, async (req, res, next) => {
  try {
    const [existing] = await query('SELECT * FROM id_templates WHERE id = ? AND is_active = 1', [req.params.id]);
    if (!existing) return res.status(404).json({ success: false, message: 'Template not found' });

    await query('UPDATE id_templates SET is_active = 0 WHERE id = ?', [req.params.id]);
    logger.info(`ID template soft-deleted: ${req.params.id}`);
    res.json({ success: true, message: 'Template deleted' });
  } catch (err) { next(err); }
});

// ── POST /id-templates/:id/submit ─────────────────────────────
router.post('/:id/submit', authenticate, async (req, res, next) => {
  try {
    const [tmpl] = await query('SELECT * FROM id_templates WHERE id = ? AND is_active = 1', [req.params.id]);
    if (!tmpl) return res.status(404).json({ success: false, message: 'Template not found' });

    if (tmpl.status !== 'draft' && tmpl.status !== 'rejected') {
      return res.status(400).json({ success: false, message: `Cannot submit from status: ${tmpl.status}` });
    }

    const userId = req.user?.uid || req.employee?.user_id;
    await query(
      `UPDATE id_templates SET status='pending_check', submitted_by=?, submitted_at=NOW() WHERE id=?`,
      [userId, req.params.id]
    );

    const [updated] = await query('SELECT * FROM id_templates WHERE id=?', [req.params.id]);
    res.json({ success: true, data: mapTemplate(updated), message: 'Template submitted for review' });
  } catch (err) { next(err); }
});

// ── POST /id-templates/:id/check ──────────────────────────────
router.post('/:id/check', authenticate, async (req, res, next) => {
  try {
    const [tmpl] = await query('SELECT * FROM id_templates WHERE id = ? AND is_active = 1', [req.params.id]);
    if (!tmpl) return res.status(404).json({ success: false, message: 'Template not found' });

    if (tmpl.status !== 'pending_check') {
      return res.status(400).json({ success: false, message: `Cannot check from status: ${tmpl.status}` });
    }

    const { approved, notes } = req.body;
    const newStatus = approved ? 'pending_approval' : 'rejected';
    const userId    = req.user?.uid || req.employee?.user_id;

    await query(
      `UPDATE id_templates SET status=?, checked_by=?, checked_at=NOW(), check_notes=? WHERE id=?`,
      [newStatus, userId, notes || null, req.params.id]
    );

    const [updated] = await query('SELECT * FROM id_templates WHERE id=?', [req.params.id]);
    res.json({
      success: true,
      data: mapTemplate(updated),
      message: approved ? 'Template sent for approval' : 'Template rejected at check stage'
    });
  } catch (err) { next(err); }
});

// ── POST /id-templates/:id/approve ────────────────────────────
router.post('/:id/approve', authenticate, async (req, res, next) => {
  try {
    const [tmpl] = await query('SELECT * FROM id_templates WHERE id = ? AND is_active = 1', [req.params.id]);
    if (!tmpl) return res.status(404).json({ success: false, message: 'Template not found' });

    if (tmpl.status !== 'pending_approval') {
      return res.status(400).json({ success: false, message: `Cannot approve from status: ${tmpl.status}` });
    }

    const { approved, notes } = req.body;
    const newStatus = approved ? 'approved' : 'rejected';
    const userId    = req.user?.uid || req.employee?.user_id;

    await query(
      `UPDATE id_templates SET status=?, approved_by=?, approved_at=NOW(), approval_notes=? WHERE id=?`,
      [newStatus, userId, notes || null, req.params.id]
    );

    const [updated] = await query('SELECT * FROM id_templates WHERE id=?', [req.params.id]);
    res.json({
      success: true,
      data: mapTemplate(updated),
      message: approved ? 'Template approved' : 'Template rejected at approval stage'
    });
  } catch (err) { next(err); }
});

// ── POST /id-templates/:id/activate ───────────────────────────
router.post('/:id/activate', authenticate, async (req, res, next) => {
  try {
    const [tmpl] = await query('SELECT * FROM id_templates WHERE id = ? AND is_active = 1', [req.params.id]);
    if (!tmpl) return res.status(404).json({ success: false, message: 'Template not found' });

    if (tmpl.status !== 'approved') {
      return res.status(400).json({ success: false, message: 'Only approved templates can be activated' });
    }

    // Deactivate other active templates of same type for same school
    await query(
      `UPDATE id_templates SET status='approved'
       WHERE school_id=? AND template_type=? AND status='active' AND id != ?`,
      [tmpl.school_id, tmpl.template_type, req.params.id]
    );

    await query(`UPDATE id_templates SET status='active' WHERE id=?`, [req.params.id]);

    const [updated] = await query('SELECT * FROM id_templates WHERE id=?', [req.params.id]);
    res.json({ success: true, data: mapTemplate(updated), message: 'Template activated' });
  } catch (err) { next(err); }
});

// ── POST /id-templates/:id/duplicate ──────────────────────────
router.post('/:id/duplicate', authenticate, async (req, res, next) => {
  try {
    const [tmpl] = await query('SELECT * FROM id_templates WHERE id = ? AND is_active = 1', [req.params.id]);
    if (!tmpl) return res.status(404).json({ success: false, message: 'Template not found' });

    const elements = await query('SELECT * FROM id_template_elements WHERE template_id = ?', [req.params.id]);

    const newId  = uuid();
    const userId = req.user?.uid || req.employee?.user_id;
    const { name } = req.body;

    await transaction(async (conn) => {
      await conn.query(
        `INSERT INTO id_templates
           (id, school_id, branch_id, name, template_type, status, card_width_mm, card_height_mm, created_by)
         VALUES (?, ?, ?, ?, ?, 'draft', ?, ?, ?)`,
        [newId, tmpl.school_id, tmpl.branch_id,
         name || `${tmpl.name} (Copy)`, tmpl.template_type,
         tmpl.card_width_mm, tmpl.card_height_mm, userId]
      );

      for (const el of elements) {
        const elId = uuid();
        await conn.query(
          `INSERT INTO id_template_elements
             (id, template_id, side, element_type, field_source, field_key, label, static_content,
              x_pct, y_pct, w_pct, h_pct, rotation_deg, z_index,
              font_size, font_weight, font_color, text_align, font_italic,
              bg_color, border_color, border_width, border_radius, opacity,
              image_url, object_fit, shape_type, fill_color, sort_order)
           VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)`,
          [elId, newId, el.side, el.element_type, el.field_source,
           el.field_key, el.label, el.static_content,
           el.x_pct, el.y_pct, el.w_pct, el.h_pct,
           el.rotation_deg, el.z_index,
           el.font_size, el.font_weight, el.font_color, el.text_align, el.font_italic,
           el.bg_color, el.border_color, el.border_width, el.border_radius, el.opacity,
           el.image_url, el.object_fit, el.shape_type, el.fill_color, el.sort_order]
        );
      }
    });

    const [created] = await query('SELECT * FROM id_templates WHERE id = ?', [newId]);
    const elRows    = await query('SELECT * FROM id_template_elements WHERE template_id = ? ORDER BY z_index, sort_order', [newId]);

    logger.info(`ID template duplicated: ${req.params.id} → ${newId}`);
    res.status(201).json({ success: true, data: mapTemplate(created, elRows.map(mapElement)) });
  } catch (err) { next(err); }
});

module.exports = router;
