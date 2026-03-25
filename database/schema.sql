-- ============================================================
-- ID MANAGEMENT SYSTEM - Complete Database Schema
-- MySQL 8.0 Compatible
-- ============================================================

SET FOREIGN_KEY_CHECKS = 0;

-- ============================================================
-- CORE CONFIGURATION
-- ============================================================
CREATE DATABASE IF NOT EXISTS idmgmt CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE idmgmt;

-- ============================================================
-- USERS & AUTH
-- ============================================================
CREATE TABLE IF NOT EXISTS users (
    id            VARCHAR(36)   NOT NULL DEFAULT (UUID()) PRIMARY KEY,
    firebase_uid  VARCHAR(128)  UNIQUE,
    email         VARCHAR(255)  UNIQUE,
    phone         VARCHAR(20)   UNIQUE,
    full_name     VARCHAR(255)  NOT NULL,
    display_name  VARCHAR(255),
    photo_url     VARCHAR(1024),
    role          ENUM('super_admin','school_owner','school_admin','branch_admin','principal','vp',
                       'head_teacher','senior_teacher','class_teacher',
                       'backup_teacher','temp_teacher','parent','viewer','onboarding')
                  NOT NULL DEFAULT 'viewer',
    is_active     BOOLEAN       NOT NULL DEFAULT TRUE,
    preferences   JSON          NULL COMMENT '{"theme_mode": "system", "layout": "modern"}',
    school_id     VARCHAR(36)   CHARSET utf8mb4 COLLATE utf8mb4_unicode_ci NULL,
    last_login    DATETIME,
    created_at    DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at    DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_users_email (email),
    INDEX idx_users_phone (phone),
    INDEX idx_users_firebase (firebase_uid),
    INDEX idx_users_role (role)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================
-- SCHOOLS (Root tenants)
-- ============================================================
CREATE TABLE IF NOT EXISTS schools (
    id              VARCHAR(36)   NOT NULL DEFAULT (UUID()) PRIMARY KEY,
    name            VARCHAR(255)  NOT NULL,
    short_name      VARCHAR(50),
    code            VARCHAR(20)   UNIQUE NOT NULL,
    logo_url        VARCHAR(1024),
    banner_url      VARCHAR(1024),
    affiliation_no  VARCHAR(100),
    affiliation_board VARCHAR(100),
    school_type     ENUM('primary','secondary','higher_secondary','k12') DEFAULT 'primary',
    -- Address
    address_line1   VARCHAR(255)  NOT NULL,
    address_line2   VARCHAR(255),
    city            VARCHAR(100)  NOT NULL,
    state           VARCHAR(100)  NOT NULL,
    country         VARCHAR(100)  NOT NULL DEFAULT 'India',
    zip_code        VARCHAR(20)   NOT NULL,
    -- Contact
    phone1          VARCHAR(20)   NOT NULL,
    phone2          VARCHAR(20),
    email           VARCHAR(255)  NOT NULL,
    website         VARCHAR(255),
    whatsapp_no     VARCHAR(20),
    -- Social
    facebook_url    VARCHAR(255),
    twitter_url     VARCHAR(255),
    instagram_url   VARCHAR(255),
    -- Settings
    academic_year   VARCHAR(20)   DEFAULT '2025-26',
    timezone        VARCHAR(50)   DEFAULT 'Asia/Kolkata',
    currency        VARCHAR(10)   DEFAULT 'INR',
    settings        JSON          NULL COMMENT '{"is_messaging_enabled": true, "default_theme": "dark", "primary_color": "#1A237E"}',
    -- Status
    is_active       BOOLEAN       NOT NULL DEFAULT TRUE,
    created_by      VARCHAR(36)   NOT NULL,
    created_at      DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at      DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (created_by) REFERENCES users(id),
    INDEX idx_schools_code (code),
    INDEX idx_schools_city (city),
    INDEX idx_schools_country (country)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================
-- BRANCHES
-- ============================================================
CREATE TABLE IF NOT EXISTS branches (
    id              VARCHAR(36)   NOT NULL DEFAULT (UUID()) PRIMARY KEY,
    school_id       VARCHAR(36)   NOT NULL,
    name            VARCHAR(255)  NOT NULL,
    short_name      VARCHAR(50),
    code            VARCHAR(20)   NOT NULL,
    logo_url        VARCHAR(1024),
    -- Address
    address_line1   VARCHAR(255)  NOT NULL,
    address_line2   VARCHAR(255),
    city            VARCHAR(100)  NOT NULL,
    state           VARCHAR(100)  NOT NULL,
    country         VARCHAR(100)  NOT NULL DEFAULT 'India',
    zip_code        VARCHAR(20)   NOT NULL,
    -- Contact
    phone1          VARCHAR(20)   NOT NULL,
    phone2          VARCHAR(20),
    email           VARCHAR(255)  NOT NULL,
    website         VARCHAR(255),
    whatsapp_no     VARCHAR(20),
    -- Status
    is_active       BOOLEAN       NOT NULL DEFAULT TRUE,
    created_by      VARCHAR(36)   NOT NULL,
    created_at      DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at      DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (school_id) REFERENCES schools(id) ON DELETE CASCADE,
    FOREIGN KEY (created_by) REFERENCES users(id),
    UNIQUE KEY uq_branch_code (school_id, code),
    INDEX idx_branches_school (school_id),
    INDEX idx_branches_city (city)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================
-- ORGANIZATIONAL ROLES / POSITIONS
-- ============================================================
CREATE TABLE IF NOT EXISTS org_roles (
    id              VARCHAR(36)   NOT NULL DEFAULT (UUID()) PRIMARY KEY,
    school_id       VARCHAR(36)   NOT NULL,
    name            VARCHAR(100)  NOT NULL,
    code            VARCHAR(50)   NOT NULL,
    level           TINYINT       NOT NULL COMMENT '1=principal,2=vp,...,8=temp',
    description     TEXT,
    can_approve     BOOLEAN       DEFAULT FALSE,
    can_upload_bulk BOOLEAN       DEFAULT FALSE,
    permissions     JSON          NULL COMMENT '{"can_manage_attendance": true}',
    is_active       BOOLEAN       DEFAULT TRUE,
    sort_order      TINYINT       DEFAULT 0,
    FOREIGN KEY (school_id) REFERENCES schools(id) ON DELETE CASCADE,
    UNIQUE KEY uq_role_code (school_id, code),
    INDEX idx_org_roles_school (school_id),
    INDEX idx_org_roles_level (level)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================
-- EMPLOYEES (All staff)
-- ============================================================
CREATE TABLE IF NOT EXISTS employees (
    id                VARCHAR(36)   NOT NULL DEFAULT (UUID()) PRIMARY KEY,
    school_id         VARCHAR(36)   NOT NULL,
    branch_id         VARCHAR(36),
    employee_id       VARCHAR(50)   NOT NULL COMMENT 'School-assigned emp ID',
    org_role_id       VARCHAR(36)   NOT NULL,
    reports_to_emp_id VARCHAR(36)   COMMENT 'Manager employee ID',
    user_id           VARCHAR(36)   COMMENT 'Link to user account',
    -- Personal
    first_name        VARCHAR(100)  NOT NULL,
    last_name         VARCHAR(100)  NOT NULL,
    display_name      VARCHAR(255),
    date_of_birth     DATE,
    gender            ENUM('male','female','other'),
    photo_url         VARCHAR(1024),
    -- Contact
    email             VARCHAR(255),
    phone             VARCHAR(20),
    whatsapp_no       VARCHAR(20),
    alt_phone         VARCHAR(20),
    -- Address
    address_line1     VARCHAR(255),
    address_line2     VARCHAR(255),
    city              VARCHAR(100),
    state             VARCHAR(100),
    country           VARCHAR(100),
    zip_code          VARCHAR(20),
    -- Professional
    date_of_joining   DATE,
    date_of_leaving   DATE,
    qualification     VARCHAR(255),
    specialization    VARCHAR(255),
    experience_years  DECIMAL(4,1),
    -- Classes they teach (for teachers)
    assigned_classes  JSON          COMMENT '["10A","10B","11A"]',
    subject_ids       JSON          COMMENT 'Array of subject IDs',
    -- Status
    is_active         BOOLEAN       NOT NULL DEFAULT TRUE,
    is_hidden         BOOLEAN       DEFAULT FALSE COMMENT 'Hidden from normal views',
    is_temp           BOOLEAN       DEFAULT FALSE,
    bulk_upload_batch VARCHAR(36),
    created_at        DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at        DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (school_id)         REFERENCES schools(id) ON DELETE CASCADE,
    FOREIGN KEY (branch_id)         REFERENCES branches(id) ON DELETE SET NULL,
    FOREIGN KEY (org_role_id)       REFERENCES org_roles(id),
    FOREIGN KEY (reports_to_emp_id) REFERENCES employees(id) ON DELETE SET NULL,
    FOREIGN KEY (user_id)           REFERENCES users(id) ON DELETE SET NULL,
    UNIQUE KEY uq_employee_id (school_id, employee_id),
    INDEX idx_emp_school (school_id),
    INDEX idx_emp_branch (branch_id),
    INDEX idx_emp_role (org_role_id),
    INDEX idx_emp_reports_to (reports_to_emp_id),
    INDEX idx_emp_email (email),
    FULLTEXT idx_emp_name (first_name, last_name)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Employee Extra Roles Mapping
CREATE TABLE IF NOT EXISTS employee_extra_roles (
    employee_id VARCHAR(36) NOT NULL,
    org_role_id VARCHAR(36) NOT NULL,
    PRIMARY KEY (employee_id, org_role_id),
    FOREIGN KEY (employee_id) REFERENCES employees(id) ON DELETE CASCADE,
    FOREIGN KEY (org_role_id) REFERENCES org_roles(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================
-- CLASSES & SECTIONS
-- ============================================================
CREATE TABLE IF NOT EXISTS classes (
    id              VARCHAR(36)   NOT NULL DEFAULT (UUID()) PRIMARY KEY,
    branch_id       VARCHAR(36)   NOT NULL,
    name            VARCHAR(50)   NOT NULL COMMENT 'e.g. "Class 10"',
    numeric_level   TINYINT       COMMENT 'e.g. 10',
    sections        JSON          NOT NULL COMMENT '["A","B","C","D"]',
    class_teacher_id VARCHAR(36),
    is_active       BOOLEAN       DEFAULT TRUE,
    FOREIGN KEY (branch_id)       REFERENCES branches(id) ON DELETE CASCADE,
    FOREIGN KEY (class_teacher_id) REFERENCES employees(id) ON DELETE SET NULL,
    UNIQUE KEY uq_class_branch (branch_id, name),
    INDEX idx_classes_branch (branch_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================
-- STUDENTS
-- ============================================================
CREATE TABLE IF NOT EXISTS students (
    id                  VARCHAR(36)   NOT NULL DEFAULT (UUID()) PRIMARY KEY,
    school_id           VARCHAR(36)   NOT NULL,
    branch_id           VARCHAR(36)   NOT NULL,
    student_id          VARCHAR(50)   NOT NULL COMMENT 'School-assigned student ID',
    roll_number         VARCHAR(20),
    class_name          VARCHAR(50)   NOT NULL,
    section             VARCHAR(10)   NOT NULL,
    academic_year       VARCHAR(20)   NOT NULL DEFAULT '2025-26',
    -- Personal
    first_name          VARCHAR(100)  NOT NULL,
    last_name           VARCHAR(100)  NOT NULL,
    middle_name         VARCHAR(100),
    date_of_birth       DATE,
    gender              ENUM('male','female','other') NOT NULL,
    blood_group         VARCHAR(10),
    nationality         VARCHAR(100)  DEFAULT 'Indian',
    religion            VARCHAR(100),
    category            VARCHAR(50)   COMMENT 'SC/ST/OBC/General',
    -- IDs
    aadhaar_no          VARCHAR(20),
    admission_no        VARCHAR(50),
    -- Photos
    photo_url           VARCHAR(1024),
    -- Address
    address_line1       VARCHAR(255),
    address_line2       VARCHAR(255),
    city                VARCHAR(100),
    state               VARCHAR(100),
    country             VARCHAR(100)  DEFAULT 'India',
    zip_code            VARCHAR(20),
    -- Transport
    bus_route           VARCHAR(100),
    bus_stop            VARCHAR(100),
    bus_number          VARCHAR(50),
    -- Status
    is_active           BOOLEAN       NOT NULL DEFAULT TRUE,
    review_status       ENUM('pending','parent_reviewed','approved','rejected') DEFAULT 'pending',
    status_color        ENUM('red','blue','green') DEFAULT 'red' COMMENT 'red=pending,blue=changed,green=approved',
    bulk_upload_batch   VARCHAR(36),
    created_at          DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at          DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (school_id) REFERENCES schools(id) ON DELETE CASCADE,
    FOREIGN KEY (branch_id) REFERENCES branches(id) ON DELETE CASCADE,
    UNIQUE KEY uq_student_id (school_id, student_id),
    INDEX idx_students_school (school_id),
    INDEX idx_students_branch (branch_id),
    INDEX idx_students_class (class_name, section),
    INDEX idx_students_status (review_status),
    INDEX idx_students_color (status_color),
    FULLTEXT idx_students_name (first_name, last_name, middle_name)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================
-- GUARDIANS (Mother, Father, Guardian 1, Guardian 2)
-- ============================================================
CREATE TABLE IF NOT EXISTS guardians (
    id                VARCHAR(36)   NOT NULL DEFAULT (UUID()) PRIMARY KEY,
    student_id        VARCHAR(36)   NOT NULL,
    guardian_type     ENUM('mother','father','guardian1','guardian2') NOT NULL,
    first_name        VARCHAR(100),
    last_name         VARCHAR(100),
    relation          VARCHAR(50),
    photo_url         VARCHAR(1024),
    email             VARCHAR(255),
    phone             VARCHAR(20),
    whatsapp_no       VARCHAR(20),
    alt_phone         VARCHAR(20),
    -- Professional
    occupation        VARCHAR(100),
    organization      VARCHAR(255),
    annual_income     DECIMAL(12,2),
    -- Address (if different)
    same_as_student   BOOLEAN       DEFAULT TRUE,
    address_line1     VARCHAR(255),
    address_line2     VARCHAR(255),
    city              VARCHAR(100),
    state             VARCHAR(100),
    country           VARCHAR(100),
    zip_code          VARCHAR(20),
    -- ID
    aadhaar_no        VARCHAR(20),
    is_primary        BOOLEAN       DEFAULT FALSE,
    user_id           VARCHAR(36)   NULL COMMENT 'linked users.id for parent portal login',
    created_at        DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at        DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (student_id) REFERENCES students(id) ON DELETE CASCADE,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE SET NULL,
    UNIQUE KEY uq_guardian_type (student_id, guardian_type),
    INDEX idx_guardians_student (student_id),
    INDEX idx_guardians_phone (phone),
    INDEX idx_guardians_whatsapp (whatsapp_no),
    INDEX idx_guardians_user (user_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- ============================================================
-- ATTENDANCE MODULES & RECORDS
-- ============================================================
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

CREATE TABLE IF NOT EXISTS student_module_mapping (
    student_id VARCHAR(36) NOT NULL,
    module_id VARCHAR(36) NOT NULL,
    PRIMARY KEY (student_id, module_id),
    FOREIGN KEY (student_id) REFERENCES students(id) ON DELETE CASCADE,
    FOREIGN KEY (module_id) REFERENCES attendance_modules(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- ============================================================
-- MESSAGING & CONVERSATIONS
-- ============================================================
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

-- ============================================================
-- PARENT REVIEW SUBMISSIONS (pending changes)
-- ============================================================
CREATE TABLE IF NOT EXISTS parent_reviews (
    id                VARCHAR(36)   NOT NULL DEFAULT (UUID()) PRIMARY KEY,
    student_id        VARCHAR(36)   NOT NULL,
    review_token      VARCHAR(128)  UNIQUE NOT NULL,
    link_sent_by      VARCHAR(36)   NOT NULL COMMENT 'Employee ID of teacher',
    link_sent_at      DATETIME,
    link_expires_at   DATETIME      NOT NULL,
    submitted_at      DATETIME,
    -- Parent submission data (JSON diff)
    original_data     JSON          NOT NULL COMMENT 'Snapshot at time of sending',
    submitted_data    JSON          COMMENT 'What parent submitted',
    changes_summary   JSON          COMMENT 'Field-level diff',
    -- Approval
    reviewed_by       VARCHAR(36)   COMMENT 'Employee who approved/rejected/returned',
    reviewed_at       DATETIME,
    review_notes      TEXT,
    return_reason     TEXT          COMMENT 'Reason when teacher returns to parent',
    document_required BOOLEAN       DEFAULT FALSE COMMENT 'Teacher flag: parent must upload docs',
    document_instructions TEXT      NULL COMMENT 'What documents to upload',
    status            ENUM('link_sent','parent_submitted','returned','approved','rejected','expired') DEFAULT 'link_sent',
    created_at        DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at        DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (student_id)  REFERENCES students(id) ON DELETE CASCADE,
    FOREIGN KEY (link_sent_by) REFERENCES employees(id),
    FOREIGN KEY (reviewed_by) REFERENCES employees(id) ON DELETE SET NULL,
    INDEX idx_reviews_student (student_id),
    INDEX idx_reviews_token (review_token),
    INDEX idx_reviews_status (status)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================
-- REVIEW DOCUMENTS (parent-uploaded files per review)
-- ============================================================
CREATE TABLE IF NOT EXISTS review_documents (
    id            VARCHAR(36)   NOT NULL DEFAULT (UUID()) PRIMARY KEY,
    review_id     VARCHAR(36)   NOT NULL,
    uploader_id   VARCHAR(36)   NOT NULL COMMENT 'users.id of uploader',
    file_name     VARCHAR(255)  NOT NULL,
    file_type     ENUM('pdf','docx','image','other') NOT NULL DEFAULT 'other',
    file_url      VARCHAR(1024) NOT NULL,
    file_size_kb  INT           NULL,
    description   VARCHAR(255)  NULL,
    uploaded_at   DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (review_id) REFERENCES parent_reviews(id) ON DELETE CASCADE,
    INDEX idx_rdoc_review (review_id),
    INDEX idx_rdoc_uploader (uploader_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================
-- ID CARD THEMES
-- ============================================================
CREATE TABLE IF NOT EXISTS id_card_themes (
    id                  VARCHAR(36)   NOT NULL DEFAULT (UUID()) PRIMARY KEY,
    school_id           VARCHAR(36)   NOT NULL,
    name                VARCHAR(100)  NOT NULL,
    description         TEXT,
    thumbnail_url       VARCHAR(1024),
    -- Colors
    primary_color       VARCHAR(20)   DEFAULT '#1565C0',
    secondary_color     VARCHAR(20)   DEFAULT '#42A5F5',
    accent_color        VARCHAR(20)   DEFAULT '#FFC107',
    text_color          VARCHAR(20)   DEFAULT '#212121',
    bg_color            VARCHAR(20)   DEFAULT '#FFFFFF',
    -- Layout config (JSON)
    front_layout        JSON          NOT NULL COMMENT 'Header, body, footer component config',
    back_layout         JSON          NOT NULL COMMENT 'Back side layout config',
    -- Dimensions
    width_mm            DECIMAL(6,2)  DEFAULT 85.6,
    height_mm           DECIMAL(6,2)  DEFAULT 53.98,
    -- Custom fields
    custom_fields       JSON          COMMENT 'Array of {label, field_key, x, y}',
    is_default          BOOLEAN       DEFAULT FALSE,
    is_active           BOOLEAN       DEFAULT TRUE,
    created_at          DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at          DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (school_id) REFERENCES schools(id) ON DELETE CASCADE,
    INDEX idx_themes_school (school_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================
-- ID CARD ASSIGNMENTS (School/Branch uses which theme)
-- ============================================================
CREATE TABLE IF NOT EXISTS id_card_assignments (
    id              VARCHAR(36)   NOT NULL DEFAULT (UUID()) PRIMARY KEY,
    school_id       VARCHAR(36),
    branch_id       VARCHAR(36),
    theme_id        VARCHAR(36)   NOT NULL,
    employee_type   ENUM('all','teacher','student','admin') DEFAULT 'all',
    is_active       BOOLEAN       DEFAULT TRUE,
    created_at      DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (school_id) REFERENCES schools(id) ON DELETE CASCADE,
    FOREIGN KEY (branch_id) REFERENCES branches(id) ON DELETE CASCADE,
    FOREIGN KEY (theme_id)  REFERENCES id_card_themes(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- ============================================================
-- ID CARD TEMPLATES SYSTEM (Upgraded)
-- ============================================================
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
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

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
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

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
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================
-- REVIEW REQUESTS (N+1 workflow - general requests)
-- ============================================================
CREATE TABLE IF NOT EXISTS review_requests (
    id                  VARCHAR(36)   NOT NULL DEFAULT (UUID()) PRIMARY KEY,
    school_id           VARCHAR(36)   NOT NULL,
    branch_id           VARCHAR(36),
    requested_by        VARCHAR(36)   NOT NULL COMMENT 'Employee ID',
    assigned_to         VARCHAR(36)   COMMENT 'N+1 employee',
    title               VARCHAR(255)  NOT NULL,
    description         TEXT          NOT NULL,
    priority            ENUM('low','medium','high','urgent') DEFAULT 'medium',
    status              ENUM('open','in_review','approved','rejected','closed') DEFAULT 'open',
    -- Attachments
    attachments         JSON          COMMENT '[{filename,url,type,size}]',
    -- Approval chain
    approval_chain      JSON          COMMENT '[{emp_id, action, timestamp, note}]',
    -- Response
    response_text       TEXT,
    responded_at        DATETIME,
    created_at          DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at          DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (school_id)    REFERENCES schools(id) ON DELETE CASCADE,
    FOREIGN KEY (branch_id)    REFERENCES branches(id) ON DELETE SET NULL,
    FOREIGN KEY (requested_by) REFERENCES employees(id),
    FOREIGN KEY (assigned_to)  REFERENCES employees(id) ON DELETE SET NULL,
    INDEX idx_requests_school (school_id),
    INDEX idx_requests_status (status),
    INDEX idx_requests_assigned (assigned_to)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================
-- NOTIFICATION LOG
-- ============================================================
CREATE TABLE IF NOT EXISTS notifications (
    id              VARCHAR(36)   NOT NULL DEFAULT (UUID()) PRIMARY KEY,
    school_id       VARCHAR(36)   NOT NULL,
    recipient_type  ENUM('employee','guardian','user') NOT NULL,
    recipient_id    VARCHAR(36)   NOT NULL,
    channel         ENUM('email','sms','whatsapp','push') NOT NULL,
    subject         VARCHAR(255),
    message         TEXT          NOT NULL,
    status          ENUM('pending','sent','failed','delivered') DEFAULT 'pending',
    provider_ref    VARCHAR(255)  COMMENT 'MSG91 message ID',
    sent_at         DATETIME,
    error_msg       TEXT,
    created_at      DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_notif_school (school_id),
    INDEX idx_notif_recipient (recipient_type, recipient_id),
    INDEX idx_notif_status (status)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================
-- BULK UPLOAD BATCHES
-- ============================================================
CREATE TABLE IF NOT EXISTS bulk_batches (
    id              VARCHAR(36)   NOT NULL DEFAULT (UUID()) PRIMARY KEY,
    school_id       VARCHAR(36)   NOT NULL,
    branch_id       VARCHAR(36),
    type            ENUM('employees','students') NOT NULL,
    filename        VARCHAR(255)  NOT NULL,
    file_url        VARCHAR(1024),
    total_rows      INT           DEFAULT 0,
    success_rows    INT           DEFAULT 0,
    failed_rows     INT           DEFAULT 0,
    status          ENUM('pending','processing','completed','failed') DEFAULT 'pending',
    validation_report JSON        COMMENT 'Array of row errors',
    uploaded_by     VARCHAR(36)   NOT NULL,
    created_at      DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at      DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (school_id) REFERENCES schools(id) ON DELETE CASCADE,
    FOREIGN KEY (uploaded_by) REFERENCES users(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================
-- AUDIT LOG
-- ============================================================
CREATE TABLE IF NOT EXISTS audit_logs (
    id              VARCHAR(36)   NOT NULL DEFAULT (UUID()) PRIMARY KEY,
    school_id       VARCHAR(36),
    user_id         VARCHAR(36),
    entity_type     VARCHAR(50)   NOT NULL COMMENT 'school/branch/student/employee',
    entity_id       VARCHAR(36)   NOT NULL,
    action          VARCHAR(50)   NOT NULL COMMENT 'create/update/delete/login',
    old_values      JSON,
    new_values      JSON,
    ip_address      VARCHAR(45),
    user_agent      VARCHAR(500),
    created_at      DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_audit_entity (entity_type, entity_id),
    INDEX idx_audit_school (school_id),
    INDEX idx_audit_user (user_id),
    INDEX idx_audit_created (created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================
-- INVITES (onboarding invite links for staff)
-- ============================================================
CREATE TABLE IF NOT EXISTS invites (
    id          VARCHAR(36)   NOT NULL DEFAULT (UUID()) PRIMARY KEY,
    school_id   VARCHAR(36),
    phone       VARCHAR(20)   NOT NULL,
    role_level  TINYINT       DEFAULT 5,
    invited_by  VARCHAR(36),
    invite_url  VARCHAR(1024),
    status      ENUM('pending','accepted','expired') DEFAULT 'pending',
    created_at  DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (school_id)  REFERENCES schools(id) ON DELETE CASCADE,
    FOREIGN KEY (invited_by) REFERENCES users(id) ON DELETE SET NULL,
    UNIQUE KEY uq_invite_phone_school (school_id, phone)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ── Customization: Menu Config ───────────────────────────────
CREATE TABLE IF NOT EXISTS menu_config (
  id          VARCHAR(36)  NOT NULL,
  school_id   VARCHAR(36)  NULL COMMENT 'NULL = global default (superadmin only)',
  role        VARCHAR(50)  NOT NULL,
  items       JSON         NOT NULL COMMENT '[{key, label, path, visible, sort_order}]',
  _scope_key  VARCHAR(36)  GENERATED ALWAYS AS (IFNULL(school_id, '__global__')) STORED,
  updated_by  VARCHAR(36)  NOT NULL,
  updated_at  DATETIME     NOT NULL DEFAULT NOW() ON UPDATE NOW(),
  PRIMARY KEY (id),
  UNIQUE KEY uq_menu_config (_scope_key, role),
  FOREIGN KEY (updated_by) REFERENCES users(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ── Customization: Dashboard Widget Config ───────────────────
CREATE TABLE IF NOT EXISTS dashboard_widget_config (
  id          VARCHAR(36)  NOT NULL,
  school_id   VARCHAR(36)  NULL COMMENT 'NULL = global default (superadmin only)',
  role        VARCHAR(50)  NOT NULL,
  widgets     JSON         NOT NULL COMMENT '[{key, label, visible, sort_order, col_span}]',
  _scope_key  VARCHAR(36)  GENERATED ALWAYS AS (IFNULL(school_id, '__global__')) STORED,
  updated_by  VARCHAR(36)  NOT NULL,
  updated_at  DATETIME     NOT NULL DEFAULT NOW() ON UPDATE NOW(),
  PRIMARY KEY (id),
  UNIQUE KEY uq_dashboard_config (_scope_key, role),
  FOREIGN KEY (updated_by) REFERENCES users(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ── Customization: Review Screen Templates ───────────────────
CREATE TABLE IF NOT EXISTS review_screen_templates (
  id           VARCHAR(36)                             NOT NULL,
  school_id    VARCHAR(36)                             NULL COMMENT 'NULL = system default',
  entity_type  ENUM('student','teacher')               NOT NULL,
  name         VARCHAR(255)                            NOT NULL,
  description  TEXT                                    NULL,
  layout_style ENUM('side_by_side','stacked','card')   NOT NULL DEFAULT 'side_by_side',
  sections     JSON                                    NOT NULL,
  is_default   TINYINT(1)                              NOT NULL DEFAULT 0,
  is_active    TINYINT(1)                              NOT NULL DEFAULT 1,
  created_by   VARCHAR(36)                             NULL,
  updated_by   VARCHAR(36)                             NULL,
  created_at   DATETIME                                NOT NULL DEFAULT NOW(),
  updated_at   DATETIME                                NOT NULL DEFAULT NOW() ON UPDATE NOW(),
  PRIMARY KEY (id),
  FOREIGN KEY (updated_by) REFERENCES users(id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

SET FOREIGN_KEY_CHECKS = 1;
