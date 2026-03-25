-- ============================================================
-- Migration 004: Workflow Request Templates System
-- SchoolID Pro — Industry-grade data review workflow
-- Run: mysql -u root -p idmgmt < 004_workflow_requests.sql
-- ============================================================

SET FOREIGN_KEY_CHECKS = 0;
USE idmgmt;

-- ============================================================
-- REQUEST TEMPLATES (standard + school-specific clones)
-- ============================================================
CREATE TABLE IF NOT EXISTS request_templates (
    id              VARCHAR(64)   NOT NULL PRIMARY KEY,
    school_id       VARCHAR(36)   NULL COMMENT 'NULL = global standard template',
    name            VARCHAR(255)  NOT NULL,
    template_type   ENUM('student_info','teacher_info','document') NOT NULL,
    description     TEXT,
    is_standard     BOOLEAN       NOT NULL DEFAULT FALSE,
    parent_id       VARCHAR(64)   NULL COMMENT 'Cloned from this template',
    default_fields  JSON          NOT NULL COMMENT 'Array of field keys pre-selected',
    notify_channels JSON          NOT NULL,
    is_active       BOOLEAN       DEFAULT TRUE,
    created_by      VARCHAR(36),
    created_at      DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at      DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_tmpl_school    (school_id),
    INDEX idx_tmpl_type      (template_type),
    INDEX idx_tmpl_standard  (is_standard)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================
-- WORKFLOW REQUEST INSTANCES
-- ============================================================
CREATE TABLE IF NOT EXISTS workflow_requests (
    id                VARCHAR(36)   NOT NULL DEFAULT (UUID()) PRIMARY KEY,
    school_id         VARCHAR(36)   NOT NULL,
    branch_id         VARCHAR(36),
    template_id       VARCHAR(64)   NOT NULL,
    title             VARCHAR(255)  NOT NULL,
    description       TEXT,
    request_type      ENUM('student_info','teacher_info','document') NOT NULL,
    status            ENUM('draft','active','in_progress','completed','cancelled') DEFAULT 'draft',
    -- Fields selected for this request
    selected_fields   JSON          NOT NULL,
    -- Class-sections included (for student_info type)
    selected_classes  JSON          COMMENT '[{"class_name":"10","section":"A"},...]',
    -- Schedule
    start_date        DATE          NOT NULL,
    due_date          DATE,
    extended_due_date DATE          NULL COMMENT 'If requestor extends the deadline',
    -- Options
    send_to_parent    BOOLEAN       DEFAULT FALSE COMMENT 'Skip teacher; send directly to parent',
    notify_channels   JSON          NOT NULL,
    -- Stats
    total_items       INT           DEFAULT 0,
    pending_items     INT           DEFAULT 0,
    completed_items   INT           DEFAULT 0,
    -- Ownership
    requested_by      VARCHAR(36)   NOT NULL,
    launched_at       DATETIME,
    completed_at      DATETIME,
    created_at        DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at        DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (school_id)    REFERENCES schools(id)    ON DELETE CASCADE,
    FOREIGN KEY (branch_id)    REFERENCES branches(id)   ON DELETE SET NULL,
    FOREIGN KEY (requested_by) REFERENCES employees(id),
    INDEX idx_wr_school  (school_id),
    INDEX idx_wr_status  (status),
    INDEX idx_wr_type    (request_type),
    INDEX idx_wr_by      (requested_by)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================
-- TEACHER ASSIGNMENTS PER CLASS-SECTION
-- ============================================================
CREATE TABLE IF NOT EXISTS workflow_request_assignments (
    id          VARCHAR(36)   NOT NULL DEFAULT (UUID()) PRIMARY KEY,
    request_id  VARCHAR(36)   NOT NULL,
    class_name  VARCHAR(50)   NOT NULL,
    section     VARCHAR(10)   NOT NULL,
    teacher_id  VARCHAR(36)   NOT NULL,
    is_primary  BOOLEAN       DEFAULT TRUE,
    assigned_at DATETIME      DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (request_id) REFERENCES workflow_requests(id) ON DELETE CASCADE,
    FOREIGN KEY (teacher_id) REFERENCES employees(id),
    UNIQUE KEY uq_wra  (request_id, class_name, section, teacher_id),
    INDEX idx_wra_req  (request_id),
    INDEX idx_wra_tch  (teacher_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================
-- WORKFLOW ITEMS (per-student or per-employee)
-- ============================================================
CREATE TABLE IF NOT EXISTS workflow_request_items (
    id                  VARCHAR(36)   NOT NULL DEFAULT (UUID()) PRIMARY KEY,
    request_id          VARCHAR(36)   NOT NULL,
    item_type           ENUM('student','employee') NOT NULL DEFAULT 'student',
    student_id          VARCHAR(36)   NULL,
    employee_id         VARCHAR(36)   NULL,
    -- Denormalised for fast filtering / sorting
    class_name          VARCHAR(50),
    section             VARCHAR(10),
    roll_number         VARCHAR(20),
    subject_name        VARCHAR(100),
    -- Assignment
    assigned_teacher_id VARCHAR(36)   NULL,
    -- Parent review link (if send_to_parent)
    parent_review_id    VARCHAR(36)   NULL,
    -- Status flow
    status              ENUM(
                          'pending',
                          'sent_to_parent',
                          'parent_submitted',
                          'teacher_under_review',
                          'approved',
                          'rejected',
                          'resubmit_requested'
                        ) DEFAULT 'pending',
    -- Notifications
    last_notified_at    DATETIME      NULL,
    reminder_count      INT           DEFAULT 0,
    -- Timestamps
    submitted_at        DATETIME      NULL,
    reviewed_at         DATETIME      NULL,
    teacher_notes       TEXT          NULL,
    created_at          DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at          DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (request_id)          REFERENCES workflow_requests(id)  ON DELETE CASCADE,
    FOREIGN KEY (student_id)          REFERENCES students(id)           ON DELETE CASCADE,
    FOREIGN KEY (employee_id)         REFERENCES employees(id)          ON DELETE CASCADE,
    FOREIGN KEY (assigned_teacher_id) REFERENCES employees(id)          ON DELETE SET NULL,
    INDEX idx_wri_req    (request_id),
    INDEX idx_wri_stu    (student_id),
    INDEX idx_wri_emp    (employee_id),
    INDEX idx_wri_status (status),
    INDEX idx_wri_tch    (assigned_teacher_id),
    INDEX idx_wri_class  (class_name, section)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================
-- ITEM-LEVEL COMMENTS (teacher + parent)
-- ============================================================
CREATE TABLE IF NOT EXISTS workflow_item_comments (
    id              VARCHAR(36)   NOT NULL DEFAULT (UUID()) PRIMARY KEY,
    item_id         VARCHAR(36)   NOT NULL,
    commenter_id    VARCHAR(36)   NOT NULL COMMENT 'users.id',
    commenter_name  VARCHAR(255)  NOT NULL,
    commenter_type  ENUM('teacher','parent','admin','requestor') NOT NULL,
    comment_text    TEXT          NOT NULL,
    created_at      DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (item_id) REFERENCES workflow_request_items(id) ON DELETE CASCADE,
    INDEX idx_wic_item (item_id),
    INDEX idx_wic_commenter (commenter_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================
-- SEED: Standard Templates (fixed IDs prevent duplicate inserts)
-- ============================================================
INSERT IGNORE INTO request_templates
    (id, school_id, name, template_type, description, is_standard, parent_id, default_fields, notify_channels)
VALUES
(
    'std-tmpl-0001-student-info',
    NULL,
    'Review Student Info',
    'student_info',
    'Standard template for reviewing student information for ID card or data verification. Pre-selected: student photo, class teacher name, class, section, parent/guardian photos, Aadhaar, PAN.',
    TRUE,
    NULL,
    JSON_ARRAY(
        'student_name', 'class_name', 'section', 'roll_number',
        'photo_url',
        'date_of_birth', 'gender', 'blood_group',
        'mother_name', 'mother_photo', 'mother_aadhaar',
        'father_name', 'father_photo', 'father_aadhaar',
        'guardian_name', 'guardian_photo',
        'student_aadhaar', 'student_pan',
        'address'
    ),
    JSON_ARRAY('sms','whatsapp','email')
),
(
    'std-tmpl-0002-teacher-info',
    NULL,
    'Review Teacher Info',
    'teacher_info',
    'Standard template for reviewing teacher information for ID card or data verification. Pre-selected: teacher photo, class, section, Aadhaar, PAN.',
    TRUE,
    NULL,
    JSON_ARRAY(
        'teacher_name', 'employee_id', 'designation',
        'assigned_classes',
        'photo_url',
        'aadhaar_no', 'pan_no',
        'date_of_birth', 'gender',
        'qualification', 'specialization',
        'phone', 'email'
    ),
    JSON_ARRAY('sms','whatsapp','email')
),
(
    'std-tmpl-0003-document-review',
    NULL,
    'Review Aadhaar / PAN / Documents',
    'document',
    'Standard template for collecting and verifying Aadhaar, PAN, or any other important identity documents. Supports file attachments.',
    TRUE,
    NULL,
    JSON_ARRAY(
        'name', 'aadhaar_no', 'pan_no',
        'photo_url', 'document_attachment'
    ),
    JSON_ARRAY('sms','whatsapp','email')
);

SET FOREIGN_KEY_CHECKS = 1;
