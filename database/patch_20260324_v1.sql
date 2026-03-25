-- ============================================================
-- Patch: 2026-03-24 v1
-- Parent Dashboard enhancements:
--   1. visible_to_parents flag on attendance_modules
--   2. parent_review_messages table (parent-teacher chat)
-- ============================================================

-- 1. Add visibility controls to attendance_modules
SET @c1 := (SELECT COUNT(*) FROM information_schema.COLUMNS
  WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='attendance_modules' AND COLUMN_NAME='visible_to_parents');
SET @s1 = IF(@c1=0,
  'ALTER TABLE attendance_modules ADD COLUMN visible_to_parents BOOLEAN NOT NULL DEFAULT TRUE AFTER is_active',
  'SELECT 1');
PREPARE st FROM @s1; EXECUTE st; DEALLOCATE PREPARE st;

-- 2. Parent review messages (parent ↔ teacher chat per review)
CREATE TABLE IF NOT EXISTS parent_review_messages (
    id           VARCHAR(36)  NOT NULL DEFAULT (UUID()) PRIMARY KEY,
    review_id    VARCHAR(36)  NOT NULL,
    sender_type  ENUM('parent','teacher','admin') NOT NULL DEFAULT 'parent',
    sender_id    VARCHAR(36)  NULL COMMENT 'employee.id for teacher, guardian.id for parent',
    sender_name  VARCHAR(200) NOT NULL DEFAULT 'Unknown',
    message      TEXT         NOT NULL,
    created_at   DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (review_id) REFERENCES parent_reviews(id) ON DELETE CASCADE,
    INDEX idx_prm_review  (review_id),
    INDEX idx_prm_created (created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
