-- Patch: Add per-employee can_approve / can_upload_bulk override columns
-- NULL means "inherit from org_role"; TRUE/FALSE overrides the role default

ALTER TABLE employees
  ADD COLUMN IF NOT EXISTS can_approve     BOOLEAN DEFAULT NULL COMMENT 'NULL = inherit from org_role',
  ADD COLUMN IF NOT EXISTS can_upload_bulk BOOLEAN DEFAULT NULL COMMENT 'NULL = inherit from org_role';
