-- ============================================================
-- PATCH 2026-03-25 v1: Preserve employee_id on attribute updates
--   Drop the simple unique key on (school_id, employee_id) which
--   forced the app to mangle employee_id on the old record to free
--   the constraint before inserting the updated record (SCD2).
--   Replace with a non-unique index so multiple historical versions
--   can share the same employee_id without corruption.
--   Uniqueness of the active record is enforced at app level.
-- ============================================================

SET @idx_exists = (SELECT COUNT(*) FROM information_schema.STATISTICS
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'employees' AND INDEX_NAME = 'uq_employee_id');
SET @sql = IF(@idx_exists > 0, 'ALTER TABLE employees DROP INDEX uq_employee_id', 'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @idx2_exists = (SELECT COUNT(*) FROM information_schema.STATISTICS
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'employees' AND INDEX_NAME = 'idx_emp_id_lookup');
SET @sql2 = IF(@idx2_exists = 0, 'ALTER TABLE employees ADD INDEX idx_emp_id_lookup (school_id, employee_id)', 'SELECT 1');
PREPARE stmt2 FROM @sql2; EXECUTE stmt2; DEALLOCATE PREPARE stmt2;
