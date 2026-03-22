-- ============================================================
-- PATCH 2026-03-22 v4: Employee bulk upload improvements
--   1. Drop effective_start_date / effective_end_date from employees
--   2. Add created_by (FK → users.id) to employees
-- ============================================================
USE idmgmt;
SET FOREIGN_KEY_CHECKS = 0;

-- ── 1. Remove effective date columns from employees ───────────
ALTER TABLE employees
  DROP COLUMN IF EXISTS effective_start_date,
  DROP COLUMN IF EXISTS effective_end_date;

-- ── 2. Add created_by column to track who uploaded/created ───
ALTER TABLE employees
  ADD COLUMN IF NOT EXISTS created_by VARCHAR(36) NULL
    COMMENT 'User ID who created or bulk-uploaded this record'
    AFTER bulk_upload_batch;

ALTER TABLE employees
  ADD CONSTRAINT fk_emp_created_by
    FOREIGN KEY (created_by) REFERENCES users(id) ON DELETE SET NULL;

SET FOREIGN_KEY_CHECKS = 1;
-- ============================================================
