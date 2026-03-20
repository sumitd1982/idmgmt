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
    role          ENUM('super_admin','school_admin','branch_admin','principal','vp',
                       'head_teacher','senior_teacher','class_teacher',
                       'backup_teacher','temp_teacher','parent','viewer')
                  NOT NULL DEFAULT 'viewer',
    is_active     BOOLEAN       NOT NULL DEFAULT TRUE,
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
    school_type     ENUM('government','private','aided','international') DEFAULT 'private',
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
    created_at        DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at        DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (student_id) REFERENCES students(id) ON DELETE CASCADE,
    UNIQUE KEY uq_guardian_type (student_id, guardian_type),
    INDEX idx_guardians_student (student_id),
    INDEX idx_guardians_phone (phone),
    INDEX idx_guardians_whatsapp (whatsapp_no)
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
    reviewed_by       VARCHAR(36)   COMMENT 'Employee who approved/rejected',
    reviewed_at       DATETIME,
    review_notes      TEXT,
    status            ENUM('link_sent','parent_submitted','approved','rejected','expired') DEFAULT 'link_sent',
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

SET FOREIGN_KEY_CHECKS = 1;
