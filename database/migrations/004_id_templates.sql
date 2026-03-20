-- ============================================================
-- Migration 004: ID Card Templates System
-- ============================================================

-- ID Card Templates
CREATE TABLE IF NOT EXISTS id_templates (
  id              VARCHAR(36)  PRIMARY KEY,
  school_id       VARCHAR(36)  NOT NULL,
  branch_id       VARCHAR(36)  NULL,
  name            VARCHAR(255) NOT NULL,
  template_type   ENUM('student','teacher') NOT NULL DEFAULT 'student',
  status          ENUM('draft','pending_check','pending_approval','approved','rejected','active') NOT NULL DEFAULT 'draft',
  card_width_mm   FLOAT        NOT NULL DEFAULT 85.6,
  card_height_mm  FLOAT        NOT NULL DEFAULT 54.0,
  -- Maker-checker-approver
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

-- Template Elements (each draggable field/image on front or back)
CREATE TABLE IF NOT EXISTS id_template_elements (
  id              VARCHAR(36)  PRIMARY KEY,
  template_id     VARCHAR(36)  NOT NULL,
  side            ENUM('front','back') NOT NULL DEFAULT 'front',
  element_type    ENUM('data_field','photo','logo','qr_code','barcode','static_text','shape','background_image') NOT NULL,
  -- Data binding
  field_source    ENUM('student','school','employee','custom') NULL,
  field_key       VARCHAR(100) NULL,   -- e.g. 'first_name', 'class_name'
  label           VARCHAR(255) NULL,   -- shown label prefix
  static_content  TEXT         NULL,   -- for static_text, terms, policy
  -- Position & geometry (% of card dimensions, 0-100)
  x_pct           FLOAT NOT NULL DEFAULT 5,
  y_pct           FLOAT NOT NULL DEFAULT 5,
  w_pct           FLOAT NOT NULL DEFAULT 30,
  h_pct           FLOAT NOT NULL DEFAULT 10,
  rotation_deg    FLOAT NOT NULL DEFAULT 0,
  z_index         INT   NOT NULL DEFAULT 1,
  -- Typography
  font_size       FLOAT NOT NULL DEFAULT 10,
  font_weight     VARCHAR(20) NOT NULL DEFAULT 'normal',
  font_color      VARCHAR(20) NOT NULL DEFAULT '#1A237E',
  text_align      VARCHAR(10) NOT NULL DEFAULT 'left',
  font_italic     TINYINT(1)  NOT NULL DEFAULT 0,
  -- Appearance
  bg_color        VARCHAR(20) NULL,
  border_color    VARCHAR(20) NULL,
  border_width    FLOAT       NOT NULL DEFAULT 0,
  border_radius   FLOAT       NOT NULL DEFAULT 0,
  opacity         FLOAT       NOT NULL DEFAULT 1.0,
  -- For image elements
  image_url       TEXT        NULL,
  object_fit      VARCHAR(20) NOT NULL DEFAULT 'cover',
  -- Shape type
  shape_type      VARCHAR(20) NULL,  -- rect | circle | line
  fill_color      VARCHAR(20) NULL,
  sort_order      INT         NOT NULL DEFAULT 0,
  FOREIGN KEY (template_id) REFERENCES id_templates(id) ON DELETE CASCADE
);

-- Print Jobs
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
