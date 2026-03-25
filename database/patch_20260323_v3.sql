-- ============================================================
-- Patch: 2026-03-23 v3
-- 1. Denormalize class_sections (school_id, branch_id, class_name, class_section)
-- 2. subjects table
-- 3. employee permissions + updated_by
-- 4. employee_history table
-- ============================================================

-- ── 1. class_sections: add denormalised lookup columns ─────────
SET @col := (SELECT COUNT(*) FROM information_schema.COLUMNS
  WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='class_sections' AND COLUMN_NAME='class_name');
SET @sql = IF(@col=0,
  'ALTER TABLE class_sections ADD COLUMN class_name VARCHAR(20) NULL AFTER section',
  'SELECT 1');
PREPARE s FROM @sql; EXECUTE s; DEALLOCATE PREPARE s;

SET @col := (SELECT COUNT(*) FROM information_schema.COLUMNS
  WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='class_sections' AND COLUMN_NAME='branch_id');
SET @sql = IF(@col=0,
  'ALTER TABLE class_sections ADD COLUMN branch_id VARCHAR(36) NULL AFTER class_name',
  'SELECT 1');
PREPARE s FROM @sql; EXECUTE s; DEALLOCATE PREPARE s;

SET @col := (SELECT COUNT(*) FROM information_schema.COLUMNS
  WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='class_sections' AND COLUMN_NAME='school_id');
SET @sql = IF(@col=0,
  'ALTER TABLE class_sections ADD COLUMN school_id VARCHAR(36) NULL AFTER branch_id',
  'SELECT 1');
PREPARE s FROM @sql; EXECUTE s; DEALLOCATE PREPARE s;

-- class_section generated column e.g. "4A"
SET @col := (SELECT COUNT(*) FROM information_schema.COLUMNS
  WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='class_sections' AND COLUMN_NAME='class_section');
SET @sql = IF(@col=0,
  'ALTER TABLE class_sections ADD COLUMN class_section VARCHAR(30) GENERATED ALWAYS AS (CONCAT(UPPER(class_name), UPPER(section))) STORED',
  'SELECT 1');
PREPARE s FROM @sql; EXECUTE s; DEALLOCATE PREPARE s;

-- Back-fill denormalised columns for any existing rows
UPDATE class_sections cs
  JOIN classes c  ON c.id  = cs.class_id
  JOIN branches b ON b.id  = c.branch_id
SET cs.class_name = c.name,
    cs.branch_id  = c.branch_id,
    cs.school_id  = b.school_id
WHERE cs.class_name IS NULL;

-- Index for fast lookup by school/branch
SET @idx := (SELECT COUNT(*) FROM information_schema.STATISTICS
  WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='class_sections' AND INDEX_NAME='idx_cs_school_branch');
SET @sql = IF(@idx=0,
  'ALTER TABLE class_sections ADD INDEX idx_cs_school_branch (school_id, branch_id)',
  'SELECT 1');
PREPARE s FROM @sql; EXECUTE s; DEALLOCATE PREPARE s;

-- ── 2. subjects table ──────────────────────────────────────────
CREATE TABLE IF NOT EXISTS subjects (
    id          VARCHAR(36)  NOT NULL DEFAULT (UUID()) PRIMARY KEY,
    school_id   VARCHAR(36)  NULL COMMENT 'NULL = global/system subject',
    name        VARCHAR(100) NOT NULL,
    code        VARCHAR(20)  NULL,
    is_active   BOOLEAN      NOT NULL DEFAULT TRUE,
    sort_order  SMALLINT     DEFAULT 0,
    UNIQUE KEY uq_subject_school_name (school_id, name),
    INDEX idx_subjects_school (school_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Seed global subjects (school_id = NULL)
INSERT IGNORE INTO subjects (name, code, sort_order) VALUES
  ('Mathematics','MATH',10),('Science','SCI',20),('Physics','PHY',30),
  ('Chemistry','CHEM',40),('Biology','BIO',50),('English','ENG',60),
  ('Hindi','HIN',70),('Social Studies','SS',80),('History','HIST',90),
  ('Geography','GEO',100),('Civics','CIV',110),('Computer Science','CS',120),
  ('Physical Education','PE',130),('Art & Craft','ART',140),('Music','MUS',150),
  ('Sanskrit','SANS',160),('Economics','ECO',170),('Commerce','COM',180),
  ('Accountancy','ACC',190),('Business Studies','BS',200),
  ('Political Science','POL',210),('Psychology','PSY',220),
  ('Sociology','SOC',230),('Environmental Science','EVS',240),
  ('Moral Science','MS',250);

-- ── 3. Employee: new permissions + updated_by ─────────────────
SET @col := (SELECT COUNT(*) FROM information_schema.COLUMNS
  WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='employees' AND COLUMN_NAME='permissions');
SET @sql = IF(@col=0,
  'ALTER TABLE employees ADD COLUMN permissions JSON NULL COMMENT ''Extra per-employee permission overrides'' AFTER subject_ids',
  'SELECT 1');
PREPARE s FROM @sql; EXECUTE s; DEALLOCATE PREPARE s;

SET @col := (SELECT COUNT(*) FROM information_schema.COLUMNS
  WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='employees' AND COLUMN_NAME='updated_by');
SET @sql = IF(@col=0,
  'ALTER TABLE employees ADD COLUMN updated_by VARCHAR(36) NULL AFTER bulk_upload_batch',
  'SELECT 1');
PREPARE s FROM @sql; EXECUTE s; DEALLOCATE PREPARE s;

-- ── 4. employee_history ────────────────────────────────────────
CREATE TABLE IF NOT EXISTS employee_history (
    id                  VARCHAR(36)   NOT NULL DEFAULT (UUID()) PRIMARY KEY,
    employee_id         VARCHAR(36)   NOT NULL COMMENT 'The employee record id (source row)',
    school_id           VARCHAR(36)   NOT NULL,
    branch_id           VARCHAR(36),
    emp_code            VARCHAR(50)   COMMENT 'School-assigned employee ID',
    org_role_id         VARCHAR(36),
    reports_to_emp_id   VARCHAR(36),
    first_name          VARCHAR(100),
    last_name           VARCHAR(100),
    display_name        VARCHAR(255),
    email               VARCHAR(255),
    phone               VARCHAR(20),
    whatsapp_no         VARCHAR(20),
    alt_phone           VARCHAR(20),
    address_line1       VARCHAR(255),
    address_line2       VARCHAR(255),
    city                VARCHAR(100),
    state               VARCHAR(100),
    country             VARCHAR(100),
    zip_code            VARCHAR(20),
    gender              VARCHAR(20),
    date_of_birth       DATE,
    date_of_joining     DATE,
    qualification       VARCHAR(255),
    specialization      VARCHAR(255),
    experience_years    DECIMAL(4,1),
    assigned_classes    JSON,
    subject_ids         JSON,
    photo_url           VARCHAR(1024),
    can_approve         BOOLEAN,
    can_upload_bulk     BOOLEAN,
    permissions         JSON,
    is_active           BOOLEAN,
    changed_by          VARCHAR(36)   NOT NULL,
    changed_at          DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    change_note         VARCHAR(500),
    INDEX idx_emp_hist_employee (employee_id),
    INDEX idx_emp_hist_school   (school_id),
    INDEX idx_emp_hist_changed  (changed_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
