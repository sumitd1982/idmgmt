-- ============================================================
-- PATCH 2026-03-25 v1: Preserve employee_id on attribute updates
--   Drop the simple unique key on (school_id, employee_id) which
--   forced the app to mangle employee_id on the old record to free
--   the constraint before inserting the updated record (SCD2).
--   Replace with a non-unique index so multiple historical versions
--   can share the same employee_id without corruption.
--   Uniqueness of the active record is enforced at app level.
-- ============================================================

ALTER TABLE employees DROP INDEX IF EXISTS uq_employee_id;
ALTER TABLE employees ADD INDEX IF NOT EXISTS idx_emp_id_lookup (school_id, employee_id);
