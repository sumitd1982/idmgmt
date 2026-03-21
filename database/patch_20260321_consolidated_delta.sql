-- ============================================================
-- PATCH 2026-03-21 CONSOLIDATED (delta only)
-- Run this on prod. Steps 1-8 from the original patch are
-- already applied. This file contains ONLY the new changes.
-- ============================================================
USE idmgmt;

SET FOREIGN_KEY_CHECKS = 0;

-- ── A. school_owner ENUM (from patch_20260321_v2.sql) ────────
-- Adds 'school_owner' role to users.role ENUM
-- Safe to re-run with -f flag if it fails on already-existing value
ALTER TABLE users MODIFY COLUMN role ENUM(
    'super_admin', 'school_admin', 'branch_admin', 'principal', 'vp',
    'head_teacher', 'senior_teacher', 'class_teacher',
    'backup_teacher', 'temp_teacher', 'parent', 'viewer',
    'school_owner'
) NOT NULL DEFAULT 'viewer';

-- ── B. school_id on users (from patch_20260321.sql §2.5) ─────
-- Links users to their school for permission sync
ALTER TABLE users
    ADD COLUMN school_id VARCHAR(36)
    CHARSET utf8mb4 COLLATE utf8mb4_unicode_ci;
--     NULL AFTER preferences;

-- ── C. user_id on guardians (from patch_20260321.sql §2.6) ───
-- Persists parent-login to guardian link for fast lookups
ALTER TABLE guardians
    ADD COLUMN user_id VARCHAR(36) NULL AFTER is_primary;

ALTER TABLE guardians
    ADD INDEX idx_guardians_user (user_id);

-- ── D. Document workflow columns on parent_reviews (§2.7) ────
ALTER TABLE parent_reviews
    ADD COLUMN document_required BOOLEAN DEFAULT FALSE
    COMMENT 'Teacher flag: parent must upload documents'
    AFTER review_notes;

ALTER TABLE parent_reviews
    ADD COLUMN document_instructions TEXT NULL
    COMMENT 'What documents to upload'
    AFTER document_required;

ALTER TABLE parent_reviews
    ADD COLUMN return_reason TEXT NULL
    COMMENT 'Reason when teacher returns submission to parent'
    AFTER document_instructions;

-- Extends status ENUM to include the new 'returned' state
ALTER TABLE parent_reviews MODIFY COLUMN status
    ENUM('link_sent','parent_submitted','returned','approved','rejected','expired')
    DEFAULT 'link_sent';

-- ── E. review_documents table (§2.8) ─────────────────────────
-- Stores references to PDF / DOCX / image files uploaded by parent
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

SET FOREIGN_KEY_CHECKS = 1;

-- ============================================================
-- END OF DELTA PATCH
-- ============================================================
