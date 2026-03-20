-- Migration: Dynamic Roles and Attendance Modules

-- 1. Add permissions JSON to org_roles
ALTER TABLE org_roles ADD COLUMN permissions JSON COMMENT '{"can_manage_attendance": true, ...}' AFTER description;

-- 2. Employee Extra Roles Mapping
CREATE TABLE IF NOT EXISTS employee_extra_roles (
    employee_id VARCHAR(36) NOT NULL,
    org_role_id VARCHAR(36) NOT NULL,
    PRIMARY KEY (employee_id, org_role_id),
    FOREIGN KEY (employee_id) REFERENCES employees(id) ON DELETE CASCADE,
    FOREIGN KEY (org_role_id) REFERENCES org_roles(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 3. Attendance Modules Configuration
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

-- 4. Attendance Records
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

-- 5. Student Module Mapping (for custom lists like Bus/Picnic)
CREATE TABLE IF NOT EXISTS student_module_mapping (
    student_id VARCHAR(36) NOT NULL,
    module_id VARCHAR(36) NOT NULL,
    PRIMARY KEY (student_id, module_id),
    FOREIGN KEY (student_id) REFERENCES students(id) ON DELETE CASCADE,
    FOREIGN KEY (module_id) REFERENCES attendance_modules(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
