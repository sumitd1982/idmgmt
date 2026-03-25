-- ============================================================
-- Patch: 2026-03-23 v4
-- 1. New transport / identity columns on students
-- 2. Same columns added to student_staging
-- 3. guardian_history audit table
-- 4. New validation messages for student fields
-- ============================================================

-- ── 1. students: private cab + school house ─────────────────────

SET @col := (SELECT COUNT(*) FROM information_schema.COLUMNS
  WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='students' AND COLUMN_NAME='private_cab_flag');
SET @sql = IF(@col=0,
  'ALTER TABLE students ADD COLUMN private_cab_flag BOOLEAN NOT NULL DEFAULT FALSE COMMENT ''Student travels by private cab'' AFTER bus_number',
  'SELECT 1');
PREPARE s FROM @sql; EXECUTE s; DEALLOCATE PREPARE s;

SET @col := (SELECT COUNT(*) FROM information_schema.COLUMNS
  WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='students' AND COLUMN_NAME='parents_personally_pick');
SET @sql = IF(@col=0,
  'ALTER TABLE students ADD COLUMN parents_personally_pick BOOLEAN NOT NULL DEFAULT FALSE COMMENT ''Parent personally picks up student'' AFTER private_cab_flag',
  'SELECT 1');
PREPARE s FROM @sql; EXECUTE s; DEALLOCATE PREPARE s;

SET @col := (SELECT COUNT(*) FROM information_schema.COLUMNS
  WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='students' AND COLUMN_NAME='private_cab_regn_no');
SET @sql = IF(@col=0,
  'ALTER TABLE students ADD COLUMN private_cab_regn_no VARCHAR(50) NULL AFTER parents_personally_pick',
  'SELECT 1');
PREPARE s FROM @sql; EXECUTE s; DEALLOCATE PREPARE s;

SET @col := (SELECT COUNT(*) FROM information_schema.COLUMNS
  WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='students' AND COLUMN_NAME='private_cab_model');
SET @sql = IF(@col=0,
  'ALTER TABLE students ADD COLUMN private_cab_model VARCHAR(100) NULL AFTER private_cab_regn_no',
  'SELECT 1');
PREPARE s FROM @sql; EXECUTE s; DEALLOCATE PREPARE s;

SET @col := (SELECT COUNT(*) FROM information_schema.COLUMNS
  WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='students' AND COLUMN_NAME='private_cab_driver_name');
SET @sql = IF(@col=0,
  'ALTER TABLE students ADD COLUMN private_cab_driver_name VARCHAR(100) NULL AFTER private_cab_model',
  'SELECT 1');
PREPARE s FROM @sql; EXECUTE s; DEALLOCATE PREPARE s;

SET @col := (SELECT COUNT(*) FROM information_schema.COLUMNS
  WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='students' AND COLUMN_NAME='private_cab_driver_license_no');
SET @sql = IF(@col=0,
  'ALTER TABLE students ADD COLUMN private_cab_driver_license_no VARCHAR(50) NULL AFTER private_cab_driver_name',
  'SELECT 1');
PREPARE s FROM @sql; EXECUTE s; DEALLOCATE PREPARE s;

SET @col := (SELECT COUNT(*) FROM information_schema.COLUMNS
  WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='students' AND COLUMN_NAME='private_cab_license_expiry_dt');
SET @sql = IF(@col=0,
  'ALTER TABLE students ADD COLUMN private_cab_license_expiry_dt DATE NULL AFTER private_cab_driver_license_no',
  'SELECT 1');
PREPARE s FROM @sql; EXECUTE s; DEALLOCATE PREPARE s;

SET @col := (SELECT COUNT(*) FROM information_schema.COLUMNS
  WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='students' AND COLUMN_NAME='school_house_name');
SET @sql = IF(@col=0,
  'ALTER TABLE students ADD COLUMN school_house_name VARCHAR(100) NULL COMMENT ''School house / colour house name'' AFTER private_cab_license_expiry_dt',
  'SELECT 1');
PREPARE s FROM @sql; EXECUTE s; DEALLOCATE PREPARE s;

-- ── 2. student_staging: same extra columns ──────────────────────

SET @col := (SELECT COUNT(*) FROM information_schema.COLUMNS
  WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='student_staging' AND COLUMN_NAME='private_cab_flag');
SET @sql = IF(@col=0,
  'ALTER TABLE student_staging ADD COLUMN private_cab_flag BOOLEAN NULL AFTER bus_number',
  'SELECT 1');
PREPARE s FROM @sql; EXECUTE s; DEALLOCATE PREPARE s;

SET @col := (SELECT COUNT(*) FROM information_schema.COLUMNS
  WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='student_staging' AND COLUMN_NAME='parents_personally_pick');
SET @sql = IF(@col=0,
  'ALTER TABLE student_staging ADD COLUMN parents_personally_pick BOOLEAN NULL AFTER private_cab_flag',
  'SELECT 1');
PREPARE s FROM @sql; EXECUTE s; DEALLOCATE PREPARE s;

SET @col := (SELECT COUNT(*) FROM information_schema.COLUMNS
  WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='student_staging' AND COLUMN_NAME='private_cab_regn_no');
SET @sql = IF(@col=0,
  'ALTER TABLE student_staging ADD COLUMN private_cab_regn_no VARCHAR(50) NULL AFTER parents_personally_pick',
  'SELECT 1');
PREPARE s FROM @sql; EXECUTE s; DEALLOCATE PREPARE s;

SET @col := (SELECT COUNT(*) FROM information_schema.COLUMNS
  WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='student_staging' AND COLUMN_NAME='private_cab_model');
SET @sql = IF(@col=0,
  'ALTER TABLE student_staging ADD COLUMN private_cab_model VARCHAR(100) NULL AFTER private_cab_regn_no',
  'SELECT 1');
PREPARE s FROM @sql; EXECUTE s; DEALLOCATE PREPARE s;

SET @col := (SELECT COUNT(*) FROM information_schema.COLUMNS
  WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='student_staging' AND COLUMN_NAME='private_cab_driver_name');
SET @sql = IF(@col=0,
  'ALTER TABLE student_staging ADD COLUMN private_cab_driver_name VARCHAR(100) NULL AFTER private_cab_model',
  'SELECT 1');
PREPARE s FROM @sql; EXECUTE s; DEALLOCATE PREPARE s;

SET @col := (SELECT COUNT(*) FROM information_schema.COLUMNS
  WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='student_staging' AND COLUMN_NAME='private_cab_driver_license_no');
SET @sql = IF(@col=0,
  'ALTER TABLE student_staging ADD COLUMN private_cab_driver_license_no VARCHAR(50) NULL AFTER private_cab_driver_name',
  'SELECT 1');
PREPARE s FROM @sql; EXECUTE s; DEALLOCATE PREPARE s;

SET @col := (SELECT COUNT(*) FROM information_schema.COLUMNS
  WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='student_staging' AND COLUMN_NAME='private_cab_license_expiry_dt');
SET @sql = IF(@col=0,
  'ALTER TABLE student_staging ADD COLUMN private_cab_license_expiry_dt DATE NULL AFTER private_cab_driver_license_no',
  'SELECT 1');
PREPARE s FROM @sql; EXECUTE s; DEALLOCATE PREPARE s;

SET @col := (SELECT COUNT(*) FROM information_schema.COLUMNS
  WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='student_staging' AND COLUMN_NAME='school_house_name');
SET @sql = IF(@col=0,
  'ALTER TABLE student_staging ADD COLUMN school_house_name VARCHAR(100) NULL AFTER private_cab_license_expiry_dt',
  'SELECT 1');
PREPARE s FROM @sql; EXECUTE s; DEALLOCATE PREPARE s;

-- ── 3. guardian_history: full snapshot on every update ─────────

CREATE TABLE IF NOT EXISTS guardian_history (
    id                  VARCHAR(36)   NOT NULL DEFAULT (UUID()) PRIMARY KEY,
    guardian_id         VARCHAR(36)   NOT NULL COMMENT 'guardians.id snapshot was taken from',
    student_id          VARCHAR(36)   NOT NULL,
    guardian_type       VARCHAR(30),
    first_name          VARCHAR(100),
    last_name           VARCHAR(100),
    relation            VARCHAR(50),
    email               VARCHAR(255),
    phone               VARCHAR(20),
    whatsapp_no         VARCHAR(20),
    alt_phone           VARCHAR(20),
    occupation          VARCHAR(100),
    organization        VARCHAR(255),
    annual_income       DECIMAL(12,2),
    aadhaar_no          VARCHAR(20),
    same_as_student     BOOLEAN,
    address_line1       VARCHAR(255),
    address_line2       VARCHAR(255),
    city                VARCHAR(100),
    state               VARCHAR(100),
    country             VARCHAR(100),
    zip_code            VARCHAR(20),
    is_primary          BOOLEAN,
    changed_by          VARCHAR(36)   NOT NULL,
    changed_at          DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    change_note         VARCHAR(500),
    INDEX idx_grd_hist_guardian (guardian_id),
    INDEX idx_grd_hist_student  (student_id),
    INDEX idx_grd_hist_changed  (changed_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ── 4. New validation messages ──────────────────────────────────

INSERT IGNORE INTO validation_messages (code, level, field, entity, message_en) VALUES
('ERR_BLOOD_GROUP_INVALID',    'error',   'blood_group',               'student', 'Blood group must be A+/A-/B+/B-/O+/O-/AB+/AB-.'),
('ERR_CATEGORY_INVALID',       'error',   'category',                  'student', 'Category must be General/SC/ST/OBC/EWS.'),
('ERR_AADHAAR_FORMAT',         'error',   'aadhaar_no',                'student', 'Aadhaar number must be exactly 12 digits (numbers only).'),
('ERR_ZIP_FORMAT',             'error',   'zip_code',                  'student', 'PIN/ZIP code must be 6 digits.'),
('ERR_CLASS_SECTION_INVALID',  'error',   'section',                   'student', 'Class-section not found for this school/branch.'),
('ERR_STATE_INVALID',          'error',   'state',                     'student', 'State name not recognised. Use official state/UT name.'),
('ERR_PHOTO_URL_FORMAT',       'error',   'photo_url',                 'student', 'Photo URL must start with images/students/YYYY/.'),
('ERR_CAB_DETAILS_REQUIRED',   'error',   'private_cab_regn_no',       'student', 'Private cab registration number required when private_cab_flag is Y.'),
('ERR_CAB_LICENSE_EXPIRY',     'error',   'private_cab_license_expiry_dt', 'student', 'Driver licence expiry date must be today or a future date.'),
('ERR_CAB_DRIVER_LICENSE_REQUIRED', 'error', 'private_cab_driver_license_no', 'student', 'Driver licence number required when private_cab_flag is Y.'),
('ERR_CHANGE_REASON_REQUIRED', 'error',   'change_reason',             'student', 'Change reason is required when updating an existing student record.'),
('WARN_ADMISSION_NO',          'warning', 'admission_no',              'student', 'Admission number not provided.'),
('WARN_ADDRESS',               'warning', 'address_line1',             'student', 'Address not provided.'),
('WARN_CITY',                  'warning', 'city',                      'student', 'City not provided.'),
('WARN_STATE',                 'warning', 'state',                     'student', 'State not provided.'),
('WARN_SCHOOL_HOUSE',          'warning', 'school_house_name',         'student', 'School house not provided.');
