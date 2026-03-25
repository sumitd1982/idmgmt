// ============================================================
// Customization Route — Menu Config, Dashboard Widgets,
//                       Review Screen Templates
// ============================================================
const router    = require('express').Router();
const { v4: uuid } = require('uuid');
const { query } = require('../models/db');
const { authenticate, requireRole, requireSchoolAccess } = require('../middleware/auth');
const logger    = require('../utils/logger');

// ─────────────────────────────────────────────────────────────
// Hardcoded defaults (fallback when no DB config exists)
// ─────────────────────────────────────────────────────────────

const DEFAULT_MENU_ITEMS = [
  { key: 'dashboard',      label: 'Dashboard',     path: '/dashboard',        visible: true,  sort_order: 0  },
  { key: 'schools',        label: 'Schools',        path: '/schools',          visible: true,  sort_order: 1  },
  { key: 'branches',       label: 'Branches',       path: '/branches',         visible: true,  sort_order: 2  },
  { key: 'org_structure',  label: 'Org Structure',  path: '/org-structure',    visible: true,  sort_order: 3  },
  { key: 'employees',      label: 'Employees',      path: '/employees',        visible: true,  sort_order: 4  },
  { key: 'students',       label: 'Students',       path: '/students',         visible: true,  sort_order: 5  },
  { key: 'id_cards',       label: 'ID Cards',       path: '/id-templates',     visible: true,  sort_order: 6  },
  { key: 'reports',        label: 'Reports',        path: '/reports',          visible: true,  sort_order: 7  },
  { key: 'attendance',     label: 'Attendance',     path: '/take-attendance',  visible: true,  sort_order: 8  },
  { key: 'messaging',      label: 'Inbox',          path: '/messaging',        visible: true,  sort_order: 9  },
  { key: 'trackers',       label: 'Trackers',       path: '/attendance-config',visible: true,  sort_order: 10 },
  { key: 'permissions',    label: 'Permissions',    path: '/roles-settings',   visible: true,  sort_order: 11 },
  { key: 'requests',       label: 'Requests',       path: '/requests',         visible: true,  sort_order: 12 },
  { key: 'workflows',      label: 'Workflows',      path: '/workflow',         visible: true,  sort_order: 13 },
  { key: 'settings',       label: 'Settings',       path: '/settings',         visible: true,  sort_order: 14 },
  { key: 'parent_portal',  label: 'My Children',    path: '/parent-portal',    visible: false, sort_order: 15 },
];

// Default visible paths per role (mirrors app_shell.dart logic)
const ROLE_DEFAULT_VISIBLE = {
  super_admin:   null, // all visible
  school_owner:  ['/dashboard', '/branches', '/org-structure', '/employees', '/students', '/id-templates', '/reports', '/take-attendance', '/messaging', '/attendance-config', '/roles-settings', '/requests', '/workflow', '/settings'],
  school_admin:  null, // all visible
  branch_admin:  null, // all visible
  principal:     ['/dashboard', '/branches', '/org-structure', '/employees', '/students', '/id-templates', '/reports', '/take-attendance', '/messaging', '/attendance-config', '/roles-settings', '/requests', '/workflow', '/settings'],
  vp:            ['/dashboard', '/branches', '/org-structure', '/employees', '/students', '/id-templates', '/reports', '/take-attendance', '/messaging', '/attendance-config', '/roles-settings', '/requests', '/workflow', '/settings'],
  head_teacher:  ['/dashboard', '/employees', '/students', '/take-attendance', '/messaging', '/reports', '/requests', '/settings'],
  parent:        ['/dashboard', '/parent-portal', '/settings'],
};

function buildDefaultMenuForRole(role) {
  const visiblePaths = ROLE_DEFAULT_VISIBLE[role] ?? null;
  return DEFAULT_MENU_ITEMS.map((item, idx) => ({
    ...item,
    visible: visiblePaths === null ? true : visiblePaths.includes(item.path),
    sort_order: idx,
  }));
}

const DEFAULT_DASHBOARD_WIDGETS = [
  { key: 'welcome_header',     label: 'Welcome Header',      visible: true,  sort_order: 0,  col_span: 2 },
  { key: 'stats_row',          label: 'Stats Row',           visible: true,  sort_order: 1,  col_span: 2 },
  { key: 'onboarding_guide',   label: 'Onboarding Guide',    visible: true,  sort_order: 2,  col_span: 2 },
  { key: 'quick_actions',      label: 'Quick Actions',       visible: true,  sort_order: 3,  col_span: 2 },
  { key: 'recent_requests',    label: 'Recent Requests',     visible: true,  sort_order: 4,  col_span: 2 },
  { key: 'class_chart',        label: 'Class Chart',         visible: true,  sort_order: 5,  col_span: 2 },
  { key: 'overview',           label: 'Class Overview',      visible: true,  sort_order: 6,  col_span: 2 },
  { key: 'notification_feed',  label: 'Notification Feed',   visible: true,  sort_order: 7,  col_span: 1 },
  { key: 'workflow_summary',   label: 'Workflow Summary',    visible: true,  sort_order: 8,  col_span: 2 },
];

// ─────────────────────────────────────────────────────────────
// Helper: merge global + school configs (school overrides global)
// ─────────────────────────────────────────────────────────────

async function getMergedMenuConfig(role, schoolId) {
  // 1. Try school-specific config
  if (schoolId) {
    const rows = await query(
      `SELECT items FROM menu_config WHERE school_id = ? AND role = ? LIMIT 1`,
      [schoolId, role]
    );
    if (rows.length) return JSON.parse(rows[0].items);
  }
  // 2. Try global config
  const globalRows = await query(
    `SELECT items FROM menu_config WHERE school_id IS NULL AND role = ? LIMIT 1`,
    [role]
  );
  if (globalRows.length) return JSON.parse(globalRows[0].items);
  // 3. Hardcoded fallback
  return buildDefaultMenuForRole(role);
}

async function getMergedDashboardConfig(role, schoolId) {
  if (schoolId) {
    const rows = await query(
      `SELECT widgets FROM dashboard_widget_config WHERE school_id = ? AND role = ? LIMIT 1`,
      [schoolId, role]
    );
    if (rows.length) return JSON.parse(rows[0].widgets);
  }
  const globalRows = await query(
    `SELECT widgets FROM dashboard_widget_config WHERE school_id IS NULL AND role = ? LIMIT 1`,
    [role]
  );
  if (globalRows.length) return JSON.parse(globalRows[0].widgets);
  return DEFAULT_DASHBOARD_WIDGETS;
}

// ─────────────────────────────────────────────────────────────
// Helpers: role-permission checks
// ─────────────────────────────────────────────────────────────

const MENU_WRITE_ROLES    = ['super_admin', 'school_admin', 'school_owner', 'principal'];
const DASHBOARD_WRITE_ROLES = ['super_admin', 'school_owner', 'principal', 'branch_admin'];
const TEMPLATE_WRITE_ROLES  = ['super_admin', 'school_admin', 'school_owner', 'branch_admin'];

function canWriteMenu(userRole)     { return MENU_WRITE_ROLES.includes(userRole); }
function canWriteDashboard(userRole){ return DASHBOARD_WRITE_ROLES.includes(userRole); }
function canWriteTemplate(userRole) { return TEMPLATE_WRITE_ROLES.includes(userRole); }

// ═════════════════════════════════════════════════════════════
// MENU CONFIG
// ═════════════════════════════════════════════════════════════

// GET /customization/menu-config?role=&school_id=
router.get('/menu-config', authenticate, async (req, res) => {
  try {
    const { role, school_id } = req.query;
    if (!role) return res.status(400).json({ success: false, message: 'role is required' });

    const items = await getMergedMenuConfig(role, school_id || null);
    return res.json({ success: true, data: { role, school_id: school_id || null, items } });
  } catch (err) {
    logger.error(`[CUSTOMIZATION] menu-config GET error: ${err.message}`);
    return res.status(500).json({ success: false, message: 'Internal server error' });
  }
});

// PUT /customization/menu-config
router.put('/menu-config', authenticate, async (req, res) => {
  try {
    const userRole = req.user.role;
    if (!canWriteMenu(userRole)) {
      return res.status(403).json({ success: false, message: 'Access denied' });
    }

    const { school_id, role, items } = req.body;
    if (!role || !Array.isArray(items)) {
      return res.status(400).json({ success: false, message: 'role and items[] are required' });
    }

    // Only superadmin can set global config (no school_id)
    if (!school_id && userRole !== 'super_admin') {
      return res.status(403).json({ success: false, message: 'Only superadmin can set global config' });
    }

    // Non-superadmin can only configure their own school
    if (school_id && userRole !== 'super_admin') {
      const userSchoolId = req.user.school_id ?? req.employee?.school_id;
      if (userSchoolId !== school_id) {
        return res.status(403).json({ success: false, message: 'Not authorized for this school' });
      }
    }

    // Validate items structure
    for (const item of items) {
      if (!item.key || !item.path || typeof item.visible !== 'boolean' || typeof item.sort_order !== 'number') {
        return res.status(400).json({ success: false, message: 'Each item must have key, path, visible (bool), sort_order (int)' });
      }
    }

    // Upsert
    const existing = await query(
      school_id
        ? `SELECT id FROM menu_config WHERE school_id = ? AND role = ? LIMIT 1`
        : `SELECT id FROM menu_config WHERE school_id IS NULL AND role = ? LIMIT 1`,
      school_id ? [school_id, role] : [role]
    );

    if (existing.length) {
      await query(
        `UPDATE menu_config SET items = ?, updated_by = ?, updated_at = NOW() WHERE id = ?`,
        [JSON.stringify(items), req.user.id, existing[0].id]
      );
    } else {
      await query(
        `INSERT INTO menu_config (id, school_id, role, items, updated_by) VALUES (?, ?, ?, ?, ?)`,
        [uuid(), school_id || null, role, JSON.stringify(items), req.user.id]
      );
    }

    return res.json({ success: true, message: 'Menu config saved' });
  } catch (err) {
    logger.error(`[CUSTOMIZATION] menu-config PUT error: ${err.message}`);
    return res.status(500).json({ success: false, message: 'Internal server error' });
  }
});

// ═════════════════════════════════════════════════════════════
// DASHBOARD WIDGET CONFIG
// ═════════════════════════════════════════════════════════════

// GET /customization/dashboard-config?role=&school_id=
router.get('/dashboard-config', authenticate, async (req, res) => {
  try {
    const { role, school_id } = req.query;
    if (!role) return res.status(400).json({ success: false, message: 'role is required' });

    const widgets = await getMergedDashboardConfig(role, school_id || null);
    return res.json({ success: true, data: { role, school_id: school_id || null, widgets } });
  } catch (err) {
    logger.error(`[CUSTOMIZATION] dashboard-config GET error: ${err.message}`);
    return res.status(500).json({ success: false, message: 'Internal server error' });
  }
});

// PUT /customization/dashboard-config
router.put('/dashboard-config', authenticate, async (req, res) => {
  try {
    const userRole = req.user.role;
    if (!canWriteDashboard(userRole)) {
      return res.status(403).json({ success: false, message: 'Access denied' });
    }

    const { school_id, role, widgets } = req.body;
    if (!role || !Array.isArray(widgets)) {
      return res.status(400).json({ success: false, message: 'role and widgets[] are required' });
    }

    if (!school_id && userRole !== 'super_admin') {
      return res.status(403).json({ success: false, message: 'Only superadmin can set global config' });
    }

    if (school_id && userRole !== 'super_admin') {
      const userSchoolId = req.user.school_id ?? req.employee?.school_id;
      if (userSchoolId !== school_id) {
        return res.status(403).json({ success: false, message: 'Not authorized for this school' });
      }
    }

    for (const w of widgets) {
      if (!w.key || typeof w.visible !== 'boolean' || typeof w.sort_order !== 'number') {
        return res.status(400).json({ success: false, message: 'Each widget must have key, visible (bool), sort_order (int)' });
      }
    }

    const existing = await query(
      school_id
        ? `SELECT id FROM dashboard_widget_config WHERE school_id = ? AND role = ? LIMIT 1`
        : `SELECT id FROM dashboard_widget_config WHERE school_id IS NULL AND role = ? LIMIT 1`,
      school_id ? [school_id, role] : [role]
    );

    if (existing.length) {
      await query(
        `UPDATE dashboard_widget_config SET widgets = ?, updated_by = ?, updated_at = NOW() WHERE id = ?`,
        [JSON.stringify(widgets), req.user.id, existing[0].id]
      );
    } else {
      await query(
        `INSERT INTO dashboard_widget_config (id, school_id, role, widgets, updated_by) VALUES (?, ?, ?, ?, ?)`,
        [uuid(), school_id || null, role, JSON.stringify(widgets), req.user.id]
      );
    }

    return res.json({ success: true, message: 'Dashboard config saved' });
  } catch (err) {
    logger.error(`[CUSTOMIZATION] dashboard-config PUT error: ${err.message}`);
    return res.status(500).json({ success: false, message: 'Internal server error' });
  }
});

// ═════════════════════════════════════════════════════════════
// REVIEW SCREEN TEMPLATES
// ═════════════════════════════════════════════════════════════

// GET /customization/review-templates?type=student|teacher&school_id=
router.get('/review-templates', authenticate, async (req, res) => {
  try {
    const { type, school_id } = req.query;
    if (!type) return res.status(400).json({ success: false, message: 'type (student|teacher) is required' });

    // Return system defaults + school's custom templates
    const rows = await query(
      `SELECT id, school_id, entity_type, name, description, layout_style, sections,
              is_default, is_active, created_by, updated_by, created_at, updated_at
       FROM review_screen_templates
       WHERE entity_type = ? AND is_active = 1
         AND (school_id IS NULL OR school_id = ?)
       ORDER BY (school_id IS NULL) ASC, is_default DESC, created_at ASC`,
      [type, school_id || '']
    );

    const templates = rows.map(r => ({
      ...r,
      sections: typeof r.sections === 'string' ? JSON.parse(r.sections) : r.sections,
      is_default: r.is_default === 1,
      is_active:  r.is_active === 1,
      is_system:  r.school_id === null,
    }));

    return res.json({ success: true, data: templates });
  } catch (err) {
    logger.error(`[CUSTOMIZATION] review-templates GET error: ${err.message}`);
    return res.status(500).json({ success: false, message: 'Internal server error' });
  }
});

// POST /customization/review-templates — create new template
router.post('/review-templates', authenticate, async (req, res) => {
  try {
    const userRole = req.user.role;
    if (!canWriteTemplate(userRole)) {
      return res.status(403).json({ success: false, message: 'Access denied' });
    }

    const { school_id, entity_type, name, description, layout_style, sections } = req.body;

    if (!school_id) {
      return res.status(400).json({ success: false, message: 'school_id is required (cannot create system templates)' });
    }
    if (!entity_type || !['student', 'teacher'].includes(entity_type)) {
      return res.status(400).json({ success: false, message: 'entity_type must be student or teacher' });
    }
    if (!name?.trim()) {
      return res.status(400).json({ success: false, message: 'name is required' });
    }
    if (!Array.isArray(sections) || sections.length === 0) {
      return res.status(400).json({ success: false, message: 'sections[] is required and must not be empty' });
    }

    // Non-superadmin can only create templates for their school
    if (userRole !== 'super_admin') {
      const userSchoolId = req.user.school_id ?? req.employee?.school_id;
      if (userSchoolId !== school_id) {
        return res.status(403).json({ success: false, message: 'Not authorized for this school' });
      }
    }

    const id = uuid();
    await query(
      `INSERT INTO review_screen_templates
         (id, school_id, entity_type, name, description, layout_style, sections, is_default, is_active, created_by)
       VALUES (?, ?, ?, ?, ?, ?, ?, 0, 1, ?)`,
      [
        id,
        school_id,
        entity_type,
        name.trim(),
        description?.trim() || null,
        layout_style || 'side_by_side',
        JSON.stringify(sections),
        req.user.id,
      ]
    );

    return res.status(201).json({ success: true, message: 'Template created', data: { id } });
  } catch (err) {
    logger.error(`[CUSTOMIZATION] review-templates POST error: ${err.message}`);
    return res.status(500).json({ success: false, message: 'Internal server error' });
  }
});

// PUT /customization/review-templates/:id — update template
router.put('/review-templates/:id', authenticate, async (req, res) => {
  try {
    const userRole = req.user.role;
    if (!canWriteTemplate(userRole)) {
      return res.status(403).json({ success: false, message: 'Access denied' });
    }

    const [tpl] = await query(
      `SELECT id, school_id FROM review_screen_templates WHERE id = ? AND is_active = 1 LIMIT 1`,
      [req.params.id]
    );
    if (!tpl) return res.status(404).json({ success: false, message: 'Template not found' });
    if (tpl.school_id === null) {
      return res.status(403).json({ success: false, message: 'Cannot edit system default templates. Clone it first.' });
    }

    // School ownership check
    if (userRole !== 'super_admin') {
      const userSchoolId = req.user.school_id ?? req.employee?.school_id;
      if (userSchoolId !== tpl.school_id) {
        return res.status(403).json({ success: false, message: 'Not authorized for this template' });
      }
    }

    const { name, description, layout_style, sections } = req.body;
    const updates = [];
    const values  = [];

    if (name !== undefined)         { updates.push('name = ?');         values.push(name.trim()); }
    if (description !== undefined)  { updates.push('description = ?');  values.push(description?.trim() || null); }
    if (layout_style !== undefined) { updates.push('layout_style = ?'); values.push(layout_style); }
    if (sections !== undefined)     { updates.push('sections = ?');     values.push(JSON.stringify(sections)); }

    if (!updates.length) return res.status(400).json({ success: false, message: 'No fields to update' });

    updates.push('updated_by = ?');
    updates.push('updated_at = NOW()');
    values.push(req.user.id, req.params.id);

    await query(`UPDATE review_screen_templates SET ${updates.join(', ')} WHERE id = ?`, values);
    return res.json({ success: true, message: 'Template updated' });
  } catch (err) {
    logger.error(`[CUSTOMIZATION] review-templates PUT error: ${err.message}`);
    return res.status(500).json({ success: false, message: 'Internal server error' });
  }
});

// DELETE /customization/review-templates/:id — soft delete
router.delete('/review-templates/:id', authenticate, async (req, res) => {
  try {
    const userRole = req.user.role;
    if (!canWriteTemplate(userRole)) {
      return res.status(403).json({ success: false, message: 'Access denied' });
    }

    const [tpl] = await query(
      `SELECT id, school_id, is_default FROM review_screen_templates WHERE id = ? AND is_active = 1 LIMIT 1`,
      [req.params.id]
    );
    if (!tpl) return res.status(404).json({ success: false, message: 'Template not found' });
    if (tpl.school_id === null) {
      return res.status(403).json({ success: false, message: 'Cannot delete system templates' });
    }
    if (tpl.is_default) {
      return res.status(400).json({ success: false, message: 'Cannot delete the default template. Set another as default first.' });
    }

    if (userRole !== 'super_admin') {
      const userSchoolId = req.user.school_id ?? req.employee?.school_id;
      if (userSchoolId !== tpl.school_id) {
        return res.status(403).json({ success: false, message: 'Not authorized for this template' });
      }
    }

    await query(`UPDATE review_screen_templates SET is_active = 0 WHERE id = ?`, [req.params.id]);
    return res.json({ success: true, message: 'Template deleted' });
  } catch (err) {
    logger.error(`[CUSTOMIZATION] review-templates DELETE error: ${err.message}`);
    return res.status(500).json({ success: false, message: 'Internal server error' });
  }
});

// POST /customization/review-templates/:id/clone — clone a template (including system defaults)
router.post('/review-templates/:id/clone', authenticate, async (req, res) => {
  try {
    const userRole = req.user.role;
    if (!canWriteTemplate(userRole)) {
      return res.status(403).json({ success: false, message: 'Access denied' });
    }

    const [source] = await query(
      `SELECT * FROM review_screen_templates WHERE id = ? AND is_active = 1 LIMIT 1`,
      [req.params.id]
    );
    if (!source) return res.status(404).json({ success: false, message: 'Template not found' });

    const { school_id, name } = req.body;
    if (!school_id) return res.status(400).json({ success: false, message: 'school_id is required' });
    if (!name?.trim()) return res.status(400).json({ success: false, message: 'name is required' });

    if (userRole !== 'super_admin') {
      const userSchoolId = req.user.school_id ?? req.employee?.school_id;
      if (userSchoolId !== school_id) {
        return res.status(403).json({ success: false, message: 'Not authorized for this school' });
      }
    }

    const newId = uuid();
    const sections = typeof source.sections === 'string' ? source.sections : JSON.stringify(source.sections);

    await query(
      `INSERT INTO review_screen_templates
         (id, school_id, entity_type, name, description, layout_style, sections, is_default, is_active, created_by)
       VALUES (?, ?, ?, ?, ?, ?, ?, 0, 1, ?)`,
      [
        newId,
        school_id,
        source.entity_type,
        name.trim(),
        source.description ? `${source.description} (copy)` : null,
        source.layout_style,
        sections,
        req.user.id,
      ]
    );

    return res.status(201).json({ success: true, message: 'Template cloned', data: { id: newId } });
  } catch (err) {
    logger.error(`[CUSTOMIZATION] review-templates clone error: ${err.message}`);
    return res.status(500).json({ success: false, message: 'Internal server error' });
  }
});

// PATCH /customization/review-templates/:id/set-default — set as default for school + type
router.patch('/review-templates/:id/set-default', authenticate, async (req, res) => {
  try {
    const userRole = req.user.role;
    if (!canWriteTemplate(userRole)) {
      return res.status(403).json({ success: false, message: 'Access denied' });
    }

    const [tpl] = await query(
      `SELECT id, school_id, entity_type FROM review_screen_templates WHERE id = ? AND is_active = 1 LIMIT 1`,
      [req.params.id]
    );
    if (!tpl) return res.status(404).json({ success: false, message: 'Template not found' });

    // Can set school template as default, or system template for that school (adds school-level default marker)
    // For system templates, the school_id in req.body is the school to apply the default for
    const targetSchoolId = tpl.school_id ?? req.body.school_id;
    if (!targetSchoolId) {
      return res.status(400).json({ success: false, message: 'school_id is required to set system template as school default' });
    }

    if (userRole !== 'super_admin') {
      const userSchoolId = req.user.school_id ?? req.employee?.school_id;
      if (userSchoolId !== targetSchoolId) {
        return res.status(403).json({ success: false, message: 'Not authorized for this school' });
      }
    }

    // Unset existing defaults for this school + entity_type
    await query(
      `UPDATE review_screen_templates
       SET is_default = 0, updated_by = ?, updated_at = NOW()
       WHERE school_id = ? AND entity_type = ? AND is_default = 1`,
      [req.user.id, targetSchoolId, tpl.entity_type]
    );

    // Set this template as default
    await query(
      `UPDATE review_screen_templates SET is_default = 1, updated_by = ?, updated_at = NOW() WHERE id = ?`,
      [req.user.id, req.params.id]
    );

    return res.json({ success: true, message: 'Default template updated' });
  } catch (err) {
    logger.error(`[CUSTOMIZATION] review-templates set-default error: ${err.message}`);
    return res.status(500).json({ success: false, message: 'Internal server error' });
  }
});

module.exports = router;
