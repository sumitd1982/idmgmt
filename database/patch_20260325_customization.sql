-- ============================================================
-- Patch: Customization Tables (Menu, Dashboard Widgets, Review Templates)
-- Date: 2026-03-25
-- ============================================================

-- ── 1. Menu Config ───────────────────────────────────────────
-- Stores per-role menu visibility & order, scoped to school or global.
-- _scope_key is a computed column to allow UNIQUE across (NULL school_id, role).
CREATE TABLE IF NOT EXISTS menu_config (
  id          VARCHAR(36) COLLATE utf8mb4_unicode_ci  NOT NULL,
  school_id   VARCHAR(36) COLLATE utf8mb4_unicode_ci  NULL COMMENT 'NULL = global default (superadmin only)',
  role        VARCHAR(50) COLLATE utf8mb4_unicode_ci  NOT NULL,
  items       JSON                                    NOT NULL COMMENT '[{key, label, path, visible, sort_order}]',
  _scope_key  VARCHAR(36) COLLATE utf8mb4_unicode_ci  GENERATED ALWAYS AS (IFNULL(school_id, '__global__')) STORED,
  updated_by  VARCHAR(36) COLLATE utf8mb4_unicode_ci  NOT NULL,
  updated_at  DATETIME                                NOT NULL DEFAULT NOW() ON UPDATE NOW(),
  PRIMARY KEY (id),
  UNIQUE KEY uq_menu_config (_scope_key, role),
  FOREIGN KEY (updated_by) REFERENCES users(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ── 2. Dashboard Widget Config ───────────────────────────────
-- Stores per-role dashboard widget layout, scoped to school or global.
-- Available widget keys: welcome_header, stats_row, onboarding_guide,
--   quick_actions, recent_requests, class_chart, overview,
--   notification_feed, workflow_summary
CREATE TABLE IF NOT EXISTS dashboard_widget_config (
  id          VARCHAR(36) COLLATE utf8mb4_unicode_ci  NOT NULL,
  school_id   VARCHAR(36) COLLATE utf8mb4_unicode_ci  NULL COMMENT 'NULL = global default (superadmin only)',
  role        VARCHAR(50) COLLATE utf8mb4_unicode_ci  NOT NULL,
  widgets     JSON                                    NOT NULL COMMENT '[{key, label, visible, sort_order, col_span}]',
  _scope_key  VARCHAR(36) COLLATE utf8mb4_unicode_ci  GENERATED ALWAYS AS (IFNULL(school_id, '__global__')) STORED,
  updated_by  VARCHAR(36) COLLATE utf8mb4_unicode_ci  NOT NULL,
  updated_at  DATETIME                                NOT NULL DEFAULT NOW() ON UPDATE NOW(),
  PRIMARY KEY (id),
  UNIQUE KEY uq_dashboard_config (_scope_key, role),
  FOREIGN KEY (updated_by) REFERENCES users(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ── 3. Review Screen Templates ───────────────────────────────
-- Multi-template system for prior-value vs new-value comparison screens.
-- school_id NULL = system default (read-only; schools clone to customize).
CREATE TABLE IF NOT EXISTS review_screen_templates (
  id           VARCHAR(36) COLLATE utf8mb4_unicode_ci                NOT NULL,
  school_id    VARCHAR(36) COLLATE utf8mb4_unicode_ci                NULL COMMENT 'NULL = system default',
  entity_type  ENUM('student','teacher')                             NOT NULL,
  name         VARCHAR(255) COLLATE utf8mb4_unicode_ci               NOT NULL,
  description  TEXT COLLATE utf8mb4_unicode_ci                       NULL,
  layout_style ENUM('side_by_side','stacked','card')                 NOT NULL DEFAULT 'side_by_side',
  sections     JSON                                                  NOT NULL
               COMMENT '[{section_name, sort_order, fields:[{field_key,label,visible,required}]}]',
  is_default   TINYINT(1)                                            NOT NULL DEFAULT 0,
  is_active    TINYINT(1)                                            NOT NULL DEFAULT 1,
  created_by   VARCHAR(36) COLLATE utf8mb4_unicode_ci                NULL COMMENT 'NULL for system defaults',
  updated_by   VARCHAR(36) COLLATE utf8mb4_unicode_ci                NULL,
  created_at   DATETIME                                              NOT NULL DEFAULT NOW(),
  updated_at   DATETIME                                              NOT NULL DEFAULT NOW() ON UPDATE NOW(),
  PRIMARY KEY (id),
  FOREIGN KEY (updated_by) REFERENCES users(id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ── 4. Seed: System Default Student Template ─────────────────
INSERT IGNORE INTO review_screen_templates
  (id, school_id, entity_type, name, description, layout_style, sections, is_default, is_active, created_by)
VALUES (
  'sys-review-student-default-0001',
  NULL,
  'student',
  'Default Student Template',
  'System default template covering all student fields in a side-by-side comparison layout.',
  'side_by_side',
  JSON_ARRAY(
    JSON_OBJECT('section_name','Identity','sort_order',0,'fields',JSON_ARRAY(
      JSON_OBJECT('field_key','student_name','label','Student Name','visible',true,'required',false),
      JSON_OBJECT('field_key','date_of_birth','label','Date of Birth','visible',true,'required',false),
      JSON_OBJECT('field_key','gender','label','Gender','visible',true,'required',false),
      JSON_OBJECT('field_key','blood_group','label','Blood Group','visible',true,'required',false),
      JSON_OBJECT('field_key','nationality','label','Nationality','visible',true,'required',false),
      JSON_OBJECT('field_key','religion','label','Religion','visible',true,'required',false),
      JSON_OBJECT('field_key','category','label','Category','visible',true,'required',false)
    )),
    JSON_OBJECT('section_name','Enrollment','sort_order',1,'fields',JSON_ARRAY(
      JSON_OBJECT('field_key','class_name','label','Class','visible',true,'required',false),
      JSON_OBJECT('field_key','section','label','Section','visible',true,'required',false),
      JSON_OBJECT('field_key','roll_number','label','Roll Number','visible',true,'required',false),
      JSON_OBJECT('field_key','academic_year','label','Academic Year','visible',true,'required',false),
      JSON_OBJECT('field_key','admission_no','label','Admission No','visible',true,'required',false)
    )),
    JSON_OBJECT('section_name','Photos','sort_order',2,'fields',JSON_ARRAY(
      JSON_OBJECT('field_key','photo_url','label','Photo','visible',true,'required',false)
    )),
    JSON_OBJECT('section_name','Contact & Address','sort_order',3,'fields',JSON_ARRAY(
      JSON_OBJECT('field_key','address','label','Address','visible',true,'required',false),
      JSON_OBJECT('field_key','city','label','City','visible',true,'required',false),
      JSON_OBJECT('field_key','state','label','State','visible',true,'required',false),
      JSON_OBJECT('field_key','zip_code','label','Zip Code','visible',true,'required',false)
    )),
    JSON_OBJECT('section_name','Government IDs','sort_order',4,'fields',JSON_ARRAY(
      JSON_OBJECT('field_key','student_aadhaar','label','Student Aadhaar','visible',true,'required',false),
      JSON_OBJECT('field_key','student_pan','label','Student PAN','visible',true,'required',false)
    )),
    JSON_OBJECT('section_name','Transport','sort_order',5,'fields',JSON_ARRAY(
      JSON_OBJECT('field_key','bus_route','label','Bus Route','visible',true,'required',false),
      JSON_OBJECT('field_key','bus_stop','label','Bus Stop','visible',true,'required',false),
      JSON_OBJECT('field_key','bus_number','label','Bus Number','visible',true,'required',false)
    )),
    JSON_OBJECT('section_name','Mother','sort_order',6,'fields',JSON_ARRAY(
      JSON_OBJECT('field_key','mother_name','label','Mother Name','visible',true,'required',false),
      JSON_OBJECT('field_key','mother_phone','label','Mother Phone','visible',true,'required',false),
      JSON_OBJECT('field_key','mother_email','label','Mother Email','visible',true,'required',false),
      JSON_OBJECT('field_key','mother_photo','label','Mother Photo','visible',true,'required',false),
      JSON_OBJECT('field_key','mother_aadhaar','label','Mother Aadhaar','visible',true,'required',false),
      JSON_OBJECT('field_key','mother_pan','label','Mother PAN','visible',true,'required',false)
    )),
    JSON_OBJECT('section_name','Father','sort_order',7,'fields',JSON_ARRAY(
      JSON_OBJECT('field_key','father_name','label','Father Name','visible',true,'required',false),
      JSON_OBJECT('field_key','father_phone','label','Father Phone','visible',true,'required',false),
      JSON_OBJECT('field_key','father_email','label','Father Email','visible',true,'required',false),
      JSON_OBJECT('field_key','father_photo','label','Father Photo','visible',true,'required',false),
      JSON_OBJECT('field_key','father_aadhaar','label','Father Aadhaar','visible',true,'required',false),
      JSON_OBJECT('field_key','father_pan','label','Father PAN','visible',true,'required',false)
    )),
    JSON_OBJECT('section_name','Guardian','sort_order',8,'fields',JSON_ARRAY(
      JSON_OBJECT('field_key','guardian_name','label','Guardian Name','visible',true,'required',false),
      JSON_OBJECT('field_key','guardian_phone','label','Guardian Phone','visible',true,'required',false),
      JSON_OBJECT('field_key','guardian_email','label','Guardian Email','visible',true,'required',false),
      JSON_OBJECT('field_key','guardian_photo','label','Guardian Photo','visible',true,'required',false),
      JSON_OBJECT('field_key','guardian_aadhaar','label','Guardian Aadhaar','visible',true,'required',false)
    ))
  ),
  1, 1, NULL
);

-- ── 5. Seed: System Default Teacher Template ─────────────────
INSERT IGNORE INTO review_screen_templates
  (id, school_id, entity_type, name, description, layout_style, sections, is_default, is_active, created_by)
VALUES (
  'sys-review-teacher-default-0001',
  NULL,
  'teacher',
  'Default Teacher Template',
  'System default template covering all teacher fields in a side-by-side comparison layout.',
  'side_by_side',
  JSON_ARRAY(
    JSON_OBJECT('section_name','Identity','sort_order',0,'fields',JSON_ARRAY(
      JSON_OBJECT('field_key','teacher_name','label','Teacher Name','visible',true,'required',false),
      JSON_OBJECT('field_key','employee_id','label','Employee ID','visible',true,'required',false),
      JSON_OBJECT('field_key','date_of_birth','label','Date of Birth','visible',true,'required',false),
      JSON_OBJECT('field_key','gender','label','Gender','visible',true,'required',false)
    )),
    JSON_OBJECT('section_name','Role','sort_order',1,'fields',JSON_ARRAY(
      JSON_OBJECT('field_key','designation','label','Designation','visible',true,'required',false),
      JSON_OBJECT('field_key','assigned_classes','label','Assigned Classes','visible',true,'required',false)
    )),
    JSON_OBJECT('section_name','Photos','sort_order',2,'fields',JSON_ARRAY(
      JSON_OBJECT('field_key','photo_url','label','Photo','visible',true,'required',false)
    )),
    JSON_OBJECT('section_name','Contact','sort_order',3,'fields',JSON_ARRAY(
      JSON_OBJECT('field_key','email','label','Email','visible',true,'required',false),
      JSON_OBJECT('field_key','phone','label','Phone','visible',true,'required',false),
      JSON_OBJECT('field_key','whatsapp_no','label','WhatsApp No','visible',true,'required',false),
      JSON_OBJECT('field_key','address','label','Address','visible',true,'required',false)
    )),
    JSON_OBJECT('section_name','Government IDs','sort_order',4,'fields',JSON_ARRAY(
      JSON_OBJECT('field_key','aadhaar_no','label','Aadhaar No','visible',true,'required',false),
      JSON_OBJECT('field_key','pan_no','label','PAN No','visible',true,'required',false)
    )),
    JSON_OBJECT('section_name','Professional','sort_order',5,'fields',JSON_ARRAY(
      JSON_OBJECT('field_key','qualification','label','Qualification','visible',true,'required',false),
      JSON_OBJECT('field_key','specialization','label','Specialization','visible',true,'required',false),
      JSON_OBJECT('field_key','experience_years','label','Experience (Years)','visible',true,'required',false),
      JSON_OBJECT('field_key','date_of_joining','label','Date of Joining','visible',true,'required',false)
    ))
  ),
  1, 1, NULL
);
