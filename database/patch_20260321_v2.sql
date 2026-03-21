-- ============================================================
-- PATCH 2026-03-21 V2: Add school_owner role
-- ============================================================
USE idmgmt;

-- Add 'school_owner' to users.role ENUM
-- (Using standard ALTER TABLE. Run with -f if already applied)
ALTER TABLE users MODIFY COLUMN role ENUM(
    'super_admin', 'school_admin', 'branch_admin', 'principal', 'vp',
    'head_teacher', 'senior_teacher', 'class_teacher',
    'backup_teacher', 'temp_teacher', 'parent', 'viewer',
    'school_owner'
) NOT NULL DEFAULT 'viewer';
