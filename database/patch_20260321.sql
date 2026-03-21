-- ============================================================
-- PATCH 2026-03-21: Support for Roles, Attendance, and ID Templates
-- ============================================================
USE idmgmt;

SET FOREIGN_KEY_CHECKS = 0;

-- 1. Add permissions JSON to org_roles
ALTER TABLE org_roles ADD COLUMN IF NOT EXISTS permissions JSON NULL COMMENT '{"can_manage_attendance": true, ...}' AFTER description;

-- 2. Add settings JSON to schools
ALTER TABLE schools ADD COLUMN IF NOT EXISTS settings JSON NULL COMMENT '{"is_messaging_enabled": true}';

-- 3. Employee Extra Roles Mapping
CREATE TABLE IF NOT EXISTS employee_extra_roles (
    employee_id VARCHAR(36) NOT NULL,
    org_role_id VARCHAR(36) NOT NULL,
    PRIMARY KEY (employee_id, org_role_id),
    FOREIGN KEY (employee_id) REFERENCES employees(id) ON DELETE CASCADE,
    FOREIGN KEY (org_role_id) REFERENCES org_roles(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 4. Attendance Modules Configuration
CREATE TABLE IF NOT EXISTS attendance_modules (
    id VARCHAR(36) NOT NULL DEFAULT (UUID()) PRIMARY KEY,
    school_id VARCHAR(36) NOT NULL,
    name VARCHAR(100) NOT NULL,
    type ENUM('daily_class', 'transport', 'event', 'other') NOT NULL,
    is_active BOOLEAN DEFAULT TRUE,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (school_id) REFERENCES schools(id) ON DELETE CASCADE,
    INDEX idx_attendance_mod_school (school_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 5. Attendance Records
CREATE TABLE IF NOT EXISTS attendance_records (
    id VARCHAR(36) NOT NULL DEFAULT (UUID()) PRIMARY KEY,
    module_id VARCHAR(36) NOT NULL,
    date DATE NOT NULL,
    student_id VARCHAR(36) NOT NULL,
    status ENUM('present', 'absent', 'late', 'half_day', 'excused') NOT NULL,
    remarks VARCHAR(255),
    recorded_by VARCHAR(36) NOT NULL,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (module_id) REFERENCES attendance_modules(id) ON DELETE CASCADE,
    FOREIGN KEY (student_id) REFERENCES students(id) ON DELETE CASCADE,
    FOREIGN KEY (recorded_by) REFERENCES employees(id) ON DELETE CASCADE,
    UNIQUE KEY uq_attendance (module_id, date, student_id),
    INDEX idx_att_date (date),
    INDEX idx_att_student (student_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 6. Student Module Mapping
CREATE TABLE IF NOT EXISTS student_module_mapping (
    student_id VARCHAR(36) NOT NULL,
    module_id VARCHAR(36) NOT NULL,
    PRIMARY KEY (student_id, module_id),
    FOREIGN KEY (student_id) REFERENCES students(id) ON DELETE CASCADE,
    FOREIGN KEY (module_id) REFERENCES attendance_modules(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 7. Messaging: Conversations & Messages
CREATE TABLE IF NOT EXISTS conversations (
    id            VARCHAR(36) NOT NULL DEFAULT (UUID()) PRIMARY KEY,
    school_id     VARCHAR(36) NOT NULL,
    student_id    VARCHAR(36) NOT NULL,
    employee_id   VARCHAR(36) NOT NULL,
    parent_id     VARCHAR(36) NOT NULL,
    subject       VARCHAR(255) NOT NULL,
    status        ENUM('open', 'resolved', 'closed') DEFAULT 'open',
    created_at    DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at    DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (school_id) REFERENCES schools(id) ON DELETE CASCADE,
    FOREIGN KEY (student_id) REFERENCES students(id) ON DELETE CASCADE,
    FOREIGN KEY (employee_id) REFERENCES employees(id) ON DELETE CASCADE,
    FOREIGN KEY (parent_id) REFERENCES users(id) ON DELETE CASCADE,
    INDEX idx_conv_school (school_id),
    INDEX idx_conv_parent (parent_id),
    INDEX idx_conv_employee (employee_id),
    INDEX idx_conv_status (status)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS messages (
    id                VARCHAR(36) NOT NULL DEFAULT (UUID()) PRIMARY KEY,
    conversation_id   VARCHAR(36) NOT NULL,
    sender_id         VARCHAR(36) NOT NULL,
    sender_type       ENUM('parent', 'employee') NOT NULL,
    body              TEXT NOT NULL,
    read_at           DATETIME NULL,
    created_at        DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (conversation_id) REFERENCES conversations(id) ON DELETE CASCADE,
    INDEX idx_msg_conv (conversation_id),
    INDEX idx_msg_sender (sender_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 8. ID Card Templates System
CREATE TABLE IF NOT EXISTS id_templates (
  id              VARCHAR(36)  PRIMARY KEY,
  school_id       VARCHAR(36)  NOT NULL,
  branch_id       VARCHAR(36)  NULL,
  name            VARCHAR(255) NOT NULL,
  template_type   ENUM('student','teacher') NOT NULL DEFAULT 'student',
  status          ENUM('draft','pending_check','pending_approval','approved','rejected','active') NOT NULL DEFAULT 'draft',
  card_width_mm   FLOAT        NOT NULL DEFAULT 85.6,
  card_height_mm  FLOAT        NOT NULL DEFAULT 54.0,
  created_by      VARCHAR(36)  NOT NULL,
  submitted_by    VARCHAR(36)  NULL,
  checked_by      VARCHAR(36)  NULL,
  approved_by     VARCHAR(36)  NULL,
  submitted_at    DATETIME     NULL,
  checked_at      DATETIME     NULL,
  approved_at     DATETIME     NULL,
  check_notes     TEXT         NULL,
  approval_notes  TEXT         NULL,
  version         INT          NOT NULL DEFAULT 1,
  is_active       TINYINT(1)   NOT NULL DEFAULT 1,
  created_at      DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at      DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  FOREIGN KEY (school_id)  REFERENCES schools(id)  ON DELETE CASCADE,
  FOREIGN KEY (branch_id)  REFERENCES branches(id) ON DELETE SET NULL,
  FOREIGN KEY (created_by) REFERENCES users(id)    ON DELETE RESTRICT
);

CREATE TABLE IF NOT EXISTS id_template_elements (
  id              VARCHAR(36)  PRIMARY KEY,
  template_id     VARCHAR(36)  NOT NULL,
  side            ENUM('front','back') NOT NULL DEFAULT 'front',
  element_type    ENUM('data_field','photo','logo','qr_code','barcode','static_text','shape','background_image') NOT NULL,
  field_source    ENUM('student','school','employee','custom') NULL,
  field_key       VARCHAR(100) NULL,
  label           VARCHAR(255) NULL,
  static_content  TEXT         NULL,
  x_pct           FLOAT NOT NULL DEFAULT 5,
  y_pct           FLOAT NOT NULL DEFAULT 5,
  w_pct           FLOAT NOT NULL DEFAULT 30,
  h_pct           FLOAT NOT NULL DEFAULT 10,
  rotation_deg    FLOAT NOT NULL DEFAULT 0,
  z_index         INT   NOT NULL DEFAULT 1,
  font_size       FLOAT NOT NULL DEFAULT 10,
  font_weight     VARCHAR(20) NOT NULL DEFAULT 'normal',
  font_color      VARCHAR(20) NOT NULL DEFAULT '#1A237E',
  text_align      VARCHAR(10) NOT NULL DEFAULT 'left',
  font_italic     TINYINT(1)  NOT NULL DEFAULT 0,
  bg_color        VARCHAR(20) NULL,
  border_color    VARCHAR(20) NULL,
  border_width    FLOAT       NOT NULL DEFAULT 0,
  border_radius   FLOAT       NOT NULL DEFAULT 0,
  opacity         FLOAT       NOT NULL DEFAULT 1.0,
  image_url       TEXT        NULL,
  object_fit      VARCHAR(20) NOT NULL DEFAULT 'cover',
  shape_type      VARCHAR(20) NULL,
  fill_color      VARCHAR(20) NULL,
  sort_order      INT         NOT NULL DEFAULT 0,
  FOREIGN KEY (template_id) REFERENCES id_templates(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS print_jobs (
  id              VARCHAR(36)  PRIMARY KEY,
  template_id     VARCHAR(36)  NOT NULL,
  school_id       VARCHAR(36)  NOT NULL,
  branch_id       VARCHAR(36)  NULL,
  target_type     ENUM('student','teacher','all') NOT NULL,
  status          ENUM('pending','processing','done','failed') NOT NULL DEFAULT 'pending',
  total_cards     INT          NOT NULL DEFAULT 0,
  printed_cards   INT          NOT NULL DEFAULT 0,
  created_by      VARCHAR(36)  NOT NULL,
  created_at      DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  completed_at    DATETIME     NULL,
  FOREIGN KEY (template_id) REFERENCES id_templates(id) ON DELETE RESTRICT,
  FOREIGN KEY (school_id)   REFERENCES schools(id)      ON DELETE CASCADE
);

SET FOREIGN_KEY_CHECKS = 1;
