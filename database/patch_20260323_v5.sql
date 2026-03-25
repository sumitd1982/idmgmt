-- ============================================================
-- Patch: 2026-03-23 v5
-- Add photo_url column to student_staging (was missing from
-- original CREATE TABLE but present in bulk-upload INSERT)
-- ============================================================

SET @col := (SELECT COUNT(*) FROM information_schema.COLUMNS
  WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='student_staging' AND COLUMN_NAME='photo_url');
SET @sql = IF(@col=0,
  'ALTER TABLE student_staging ADD COLUMN photo_url VARCHAR(500) NULL AFTER aadhaar_no',
  'SELECT 1');
PREPARE s FROM @sql; EXECUTE s; DEALLOCATE PREPARE s;
