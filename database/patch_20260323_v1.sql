-- ============================================================
-- patch_20260323_v1.sql
-- Changes:
--   1. class_sections table  — per-section class teacher assignment
--   2. Students SCD Type 2   — is_current, created_by, updated_by, change_reason
--   3. student_staging table — bulk upload staging
--   4. employee_staging table
--   5. bulk_batches enhancements — warning_rows, confirmed_at/by, status enum update
-- ============================================================

-- ============================================================
-- 1. PER-SECTION CLASS TEACHER
-- A teacher can be class teacher for multiple sections,
-- different teachers can be assigned to different sections of the same class.
-- ============================================================
CREATE TABLE IF NOT EXISTS class_sections (
    id               VARCHAR(36)  NOT NULL DEFAULT (UUID()) PRIMARY KEY,
    class_id         VARCHAR(36)  NOT NULL,
    section          VARCHAR(10)  NOT NULL,
    class_teacher_id VARCHAR(36)  NULL COMMENT 'Employee id of the class teacher for this section',
    is_active        BOOLEAN      NOT NULL DEFAULT TRUE,
    created_at       DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at       DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (class_id)         REFERENCES classes(id)   ON DELETE CASCADE,
    FOREIGN KEY (class_teacher_id) REFERENCES employees(id) ON DELETE SET NULL,
    UNIQUE KEY uq_class_section (class_id, section),
    INDEX idx_cs_teacher (class_teacher_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Back-fill: seed one row per section in each existing class,
-- assigning the existing class_teacher_id (if any) to every section.
-- JSON_TABLE requires MySQL 8.0+.
INSERT IGNORE INTO class_sections (id, class_id, section, class_teacher_id)
SELECT UUID(), c.id, jt.section, c.class_teacher_id
FROM   classes c
CROSS JOIN JSON_TABLE(
    CASE WHEN JSON_VALID(c.sections) THEN c.sections ELSE '[]' END,
    '$[*]' COLUMNS (section VARCHAR(10) PATH '$')
) AS jt
WHERE  c.is_active = TRUE;

-- ============================================================
-- 2. STUDENT SCD TYPE 2
-- ============================================================

-- Add SCD tracking columns
ALTER TABLE students
    ADD COLUMN IF NOT EXISTS is_current    BOOLEAN      NOT NULL DEFAULT TRUE  COMMENT 'FALSE for historical versions' AFTER effective_end_date,
    ADD COLUMN IF NOT EXISTS created_by    VARCHAR(36)  NULL                   AFTER updated_at,
    ADD COLUMN IF NOT EXISTS updated_by    VARCHAR(36)  NULL                   AFTER created_by,
    ADD COLUMN IF NOT EXISTS change_reason VARCHAR(255) NULL COMMENT 'Why this version was created' AFTER updated_by;

-- Mark all existing rows as current
UPDATE students SET is_current = TRUE WHERE is_current = FALSE OR is_current IS NULL;

-- Drop the old unique key (SCD allows multiple rows per student_id — one per version)
ALTER TABLE students DROP INDEX IF EXISTS uq_student_id;

-- New unique key: no two versions can share the same start date
ALTER TABLE students ADD UNIQUE KEY IF NOT EXISTS uq_student_version (school_id, student_id, effective_start_date);

-- Fast lookup of current records per school
ALTER TABLE students ADD INDEX IF NOT EXISTS idx_students_current (school_id, is_current);

-- ============================================================
-- 3. STUDENT STAGING TABLE
-- ============================================================
CREATE TABLE IF NOT EXISTS student_staging (
    id                   VARCHAR(36)   NOT NULL DEFAULT (UUID()) PRIMARY KEY,
    batch_id             VARCHAR(36)   NOT NULL,
    row_number           INT           NOT NULL,
    -- Context
    school_id            VARCHAR(36)   NULL,
    branch_id            VARCHAR(36)   NULL,
    -- Student fields (all nullable — raw from spreadsheet)
    student_id           VARCHAR(50)   NULL,
    first_name           VARCHAR(100)  NULL,
    middle_name          VARCHAR(100)  NULL,
    last_name            VARCHAR(100)  NULL,
    gender               VARCHAR(20)   NULL,
    date_of_birth        VARCHAR(20)   NULL,
    class_name           VARCHAR(50)   NULL,
    section              VARCHAR(10)   NULL,
    roll_number          VARCHAR(20)   NULL,
    academic_year        VARCHAR(20)   NULL,
    blood_group          VARCHAR(10)   NULL,
    nationality          VARCHAR(100)  NULL,
    religion             VARCHAR(100)  NULL,
    category             VARCHAR(50)   NULL,
    aadhaar_no           VARCHAR(20)   NULL,
    admission_no         VARCHAR(50)   NULL,
    address_line1        VARCHAR(255)  NULL,
    address_line2        VARCHAR(255)  NULL,
    city                 VARCHAR(100)  NULL,
    state                VARCHAR(100)  NULL,
    country              VARCHAR(100)  NULL,
    zip_code             VARCHAR(20)   NULL,
    bus_route            VARCHAR(100)  NULL,
    bus_stop             VARCHAR(100)  NULL,
    bus_number           VARCHAR(50)   NULL,
    effective_start_date DATE          NULL,
    change_reason        VARCHAR(255)  NULL,
    -- Guardian data (array of objects serialised from multi-row CSV)
    guardian_data        JSON          NULL COMMENT 'Array: [{guardian_type,first_name,phone,email,...}]',
    -- Validation results
    validation_status    ENUM('pending','success','warning','failed') NOT NULL DEFAULT 'pending',
    validation_errors    JSON          NULL COMMENT 'Array of error strings',
    validation_warnings  JSON          NULL COMMENT 'Array of warning strings',
    validation_notes     JSON          NULL COMMENT 'Array of informational strings',
    -- Raw spreadsheet row preserved for re-validation
    raw_row              JSON          NULL,
    created_at           DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_stu_stg_batch  (batch_id),
    INDEX idx_stu_stg_status (batch_id, validation_status)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================
-- 4. EMPLOYEE STAGING TABLE
-- ============================================================
CREATE TABLE IF NOT EXISTS employee_staging (
    id                   VARCHAR(36)   NOT NULL DEFAULT (UUID()) PRIMARY KEY,
    batch_id             VARCHAR(36)   NOT NULL,
    row_number           INT           NOT NULL,
    -- Context
    school_id            VARCHAR(36)   NULL,
    branch_id            VARCHAR(36)   NULL,
    branch_code          VARCHAR(50)   NULL,
    -- Employee fields (raw from spreadsheet)
    employee_id          VARCHAR(50)   NULL,
    first_name           VARCHAR(100)  NULL,
    last_name            VARCHAR(100)  NULL,
    gender               VARCHAR(20)   NULL,
    date_of_birth        VARCHAR(20)   NULL,
    email                VARCHAR(255)  NULL,
    phone                VARCHAR(20)   NULL,
    whatsapp_no          VARCHAR(20)   NULL,
    date_of_joining      VARCHAR(20)   NULL,
    org_role_code        VARCHAR(50)   NULL,
    org_role_id          VARCHAR(36)   NULL COMMENT 'Resolved from org_role_code during validation',
    reports_to_emp_id    VARCHAR(50)   NULL COMMENT 'employee_id string — resolved to UUID on confirm',
    qualification        VARCHAR(255)  NULL,
    specialization       VARCHAR(255)  NULL,
    experience_years     TINYINT       NULL,
    assigned_classes     JSON          NULL,
    address_line1        VARCHAR(255)  NULL,
    city                 VARCHAR(100)  NULL,
    state                VARCHAR(100)  NULL,
    country              VARCHAR(100)  NULL,
    zip_code             VARCHAR(20)   NULL,
    effective_start_date DATE          NULL,
    change_reason        VARCHAR(255)  NULL,
    -- Validation results
    validation_status    ENUM('pending','success','warning','failed') NOT NULL DEFAULT 'pending',
    validation_errors    JSON          NULL,
    validation_warnings  JSON          NULL,
    validation_notes     JSON          NULL,
    raw_row              JSON          NULL,
    created_at           DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_emp_stg_batch  (batch_id),
    INDEX idx_emp_stg_status (batch_id, validation_status)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================
-- 5. BULK BATCHES ENHANCEMENTS
-- ============================================================
ALTER TABLE bulk_batches
    ADD COLUMN IF NOT EXISTS warning_rows  INT         NOT NULL DEFAULT 0 AFTER failed_rows,
    ADD COLUMN IF NOT EXISTS confirmed_at  DATETIME    NULL               AFTER warning_rows,
    ADD COLUMN IF NOT EXISTS confirmed_by  VARCHAR(36) NULL               AFTER confirmed_at;

-- Extend status enum to include 'staged' (file parsed into staging) and 'validated' (validation complete, awaiting confirm)
ALTER TABLE bulk_batches
    MODIFY COLUMN status ENUM('processing','staged','validated','completed','failed') NOT NULL DEFAULT 'processing';
