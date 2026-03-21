-- Final patch to fix all missing DB objects
USE idmgmt;
SET FOREIGN_KEY_CHECKS = 0;

-- Fix 1: Add missing is_hidden column to employees
ALTER TABLE employees ADD COLUMN IF NOT EXISTS is_hidden BOOLEAN DEFAULT FALSE COMMENT 'Hidden from normal views';
ALTER TABLE employees ADD COLUMN IF NOT EXISTS preferences JSON NULL;

-- Fix 2: Fix users.role ENUM to include onboarding
ALTER TABLE users MODIFY COLUMN role ENUM(
    'super_admin', 'school_owner', 'school_admin', 'branch_admin', 'principal', 'vp',
    'head_teacher', 'senior_teacher', 'class_teacher',
    'backup_teacher', 'temp_teacher', 'parent', 'viewer', 'onboarding'
) NOT NULL DEFAULT 'viewer';

-- Fix 3: Create invites table if missing
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
