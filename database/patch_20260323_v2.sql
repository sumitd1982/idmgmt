-- ============================================================
-- Patch: 2026-03-23 v2
-- Add principal_name, district, updated_by to schools
-- Create school_history table
-- ============================================================

-- Add principal_name if not exists
SET @col_exists = (SELECT COUNT(*) FROM information_schema.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'schools' AND COLUMN_NAME = 'principal_name');
SET @sql = IF(@col_exists = 0,
  'ALTER TABLE schools ADD COLUMN principal_name VARCHAR(255) NULL AFTER website',
  'SELECT ''principal_name already exists'' AS info');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

-- Add district if not exists
SET @col_exists = (SELECT COUNT(*) FROM information_schema.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'schools' AND COLUMN_NAME = 'district');
SET @sql = IF(@col_exists = 0,
  'ALTER TABLE schools ADD COLUMN district VARCHAR(100) NULL AFTER city',
  'SELECT ''district already exists'' AS info');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

-- Add updated_by if not exists
SET @col_exists = (SELECT COUNT(*) FROM information_schema.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'schools' AND COLUMN_NAME = 'updated_by');
SET @sql = IF(@col_exists = 0,
  'ALTER TABLE schools ADD COLUMN updated_by VARCHAR(36) NULL AFTER created_by',
  'SELECT ''updated_by already exists'' AS info');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

-- Add FK for updated_by if not exists
SET @fk_exists = (SELECT COUNT(*) FROM information_schema.TABLE_CONSTRAINTS
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'schools'
  AND CONSTRAINT_NAME = 'fk_schools_updated_by');
SET @sql = IF(@fk_exists = 0,
  'ALTER TABLE schools ADD CONSTRAINT fk_schools_updated_by FOREIGN KEY (updated_by) REFERENCES users(id)',
  'SELECT ''fk_schools_updated_by already exists'' AS info');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

-- School history table (audit trail)
CREATE TABLE IF NOT EXISTS school_history (
    id              VARCHAR(36)   NOT NULL DEFAULT (UUID()) PRIMARY KEY,
    school_id       VARCHAR(36)   NOT NULL,
    name            VARCHAR(255),
    short_name      VARCHAR(50),
    code            VARCHAR(20),
    logo_url        VARCHAR(1024),
    banner_url      VARCHAR(1024),
    affiliation_no  VARCHAR(100),
    affiliation_board VARCHAR(100),
    school_type     VARCHAR(50),
    principal_name  VARCHAR(255),
    address_line1   VARCHAR(255),
    address_line2   VARCHAR(255),
    city            VARCHAR(100),
    district        VARCHAR(100),
    state           VARCHAR(100),
    country         VARCHAR(100),
    zip_code        VARCHAR(20),
    phone1          VARCHAR(20),
    phone2          VARCHAR(20),
    email           VARCHAR(255),
    website         VARCHAR(255),
    whatsapp_no     VARCHAR(20),
    facebook_url    VARCHAR(255),
    twitter_url     VARCHAR(255),
    instagram_url   VARCHAR(255),
    academic_year   VARCHAR(20),
    settings        JSON,
    changed_by      VARCHAR(36)   NOT NULL,
    changed_at      DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    change_note     VARCHAR(500),
    FOREIGN KEY (school_id)  REFERENCES schools(id) ON DELETE CASCADE,
    FOREIGN KEY (changed_by) REFERENCES users(id),
    INDEX idx_school_history_school (school_id),
    INDEX idx_school_history_changed_at (changed_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
