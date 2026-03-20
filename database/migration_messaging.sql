-- Migration to add Parent-Teacher Messaging module support
-- Run this on the idmgmt database

SET FOREIGN_KEY_CHECKS = 0;

-- 1. Add settings JSON column to schools to toggle Messaging on/off
ALTER TABLE schools 
ADD COLUMN settings JSON NULL COMMENT '{"is_messaging_enabled": true}';

-- 2. Create conversations table (the thread)
CREATE TABLE IF NOT EXISTS conversations (
    id            VARCHAR(36) NOT NULL DEFAULT (UUID()) PRIMARY KEY,
    school_id     VARCHAR(36) NOT NULL,
    student_id    VARCHAR(36) NOT NULL,
    employee_id   VARCHAR(36) NOT NULL,
    parent_id     VARCHAR(36) NOT NULL,
    subject       VARCHAR(255) NOT NULL,
    status        ENUM('open', 'resolved', 'closed') DEFAULT 'open',
    created_at    DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at    DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (school_id) REFERENCES schools(id) ON DELETE CASCADE,
    FOREIGN KEY (student_id) REFERENCES students(id) ON DELETE CASCADE,
    FOREIGN KEY (employee_id) REFERENCES employees(id) ON DELETE CASCADE,
    FOREIGN KEY (parent_id) REFERENCES users(id) ON DELETE CASCADE,
    INDEX idx_conv_school (school_id),
    INDEX idx_conv_parent (parent_id),
    INDEX idx_conv_employee (employee_id),
    INDEX idx_conv_status (status)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- 3. Create messages table (the individual chat bubbles)
CREATE TABLE IF NOT EXISTS messages (
    id                VARCHAR(36) NOT NULL DEFAULT (UUID()) PRIMARY KEY,
    conversation_id   VARCHAR(36) NOT NULL,
    sender_id         VARCHAR(36) NOT NULL,
    sender_type       ENUM('parent', 'employee') NOT NULL,
    body              TEXT NOT NULL,
    read_at           DATETIME NULL,
    created_at        DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (conversation_id) REFERENCES conversations(id) ON DELETE CASCADE,
    INDEX idx_msg_conv (conversation_id),
    INDEX idx_msg_sender (sender_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

SET FOREIGN_KEY_CHECKS = 1;
