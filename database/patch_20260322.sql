-- ============================================================
-- PATCH 2026-03-22: Bulk Upload + Validation Messages + ID Templates
-- ============================================================
USE idmgmt;
SET FOREIGN_KEY_CHECKS = 0;

-- ── 1. Effective dates on employees ──────────────────────────
ALTER TABLE employees
  ADD COLUMN IF NOT EXISTS effective_start_date DATE NULL COMMENT 'Role effective from',
  ADD COLUMN IF NOT EXISTS effective_end_date   DATE NULL COMMENT 'Role valid until';

-- ── 2. Effective dates on students ───────────────────────────
ALTER TABLE students
  ADD COLUMN IF NOT EXISTS effective_start_date DATE NULL COMMENT 'Enrollment effective from',
  ADD COLUMN IF NOT EXISTS effective_end_date   DATE NULL COMMENT 'Enrollment valid until';

-- ── 3. Country field on schools (add if missing) ─────────────
-- Already exists, but add state if not
ALTER TABLE students
  ADD COLUMN IF NOT EXISTS state   VARCHAR(100) NULL AFTER city,
  ADD COLUMN IF NOT EXISTS country VARCHAR(100) NOT NULL DEFAULT 'India' AFTER state;

-- ── 4. Country field on employees ────────────────────────────
ALTER TABLE employees
  ADD COLUMN IF NOT EXISTS country VARCHAR(100) NOT NULL DEFAULT 'India' AFTER is_active;

-- ── 5. Validation messages table (i18n-ready) ─────────────────
CREATE TABLE IF NOT EXISTS validation_messages (
  id          VARCHAR(36)  NOT NULL DEFAULT (UUID()) PRIMARY KEY,
  code        VARCHAR(100) NOT NULL UNIQUE COMMENT 'e.g. ERR_PHONE_FORMAT',
  level       ENUM('error','warning','info') NOT NULL DEFAULT 'error',
  field       VARCHAR(100) NULL COMMENT 'Which field this applies to',
  entity      ENUM('employee','student','school','guardian','general') DEFAULT 'general',
  message_en  TEXT         NOT NULL COMMENT 'Default English message',
  message_hi  TEXT         NULL COMMENT 'Hindi translation',
  updated_at  DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  INDEX idx_vmsg_code (code),
  INDEX idx_vmsg_entity (entity)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ── 6. Seed validation messages ───────────────────────────────
INSERT IGNORE INTO validation_messages (code, level, field, entity, message_en, message_hi) VALUES
-- Employee validations
('ERR_EMP_ID_REQUIRED',     'error',   'employee_id',   'employee', 'Employee ID is required.',                          'कर्मचारी ID आवश्यक है।'),
('ERR_EMP_ID_FORMAT',       'error',   'employee_id',   'employee', 'Employee ID must be alphanumeric (max 30 chars).',  'कर्मचारी ID अल्फान्यूमेरिक होनी चाहिए।'),
('ERR_EMP_ID_DUPLICATE',    'error',   'employee_id',   'employee', 'Employee ID already exists in branch.',             'कर्मचारी ID पहले से मौजूद है।'),
('ERR_FIRST_NAME_REQUIRED', 'error',   'first_name',    'employee', 'First name is required.',                           'पहला नाम आवश्यक है।'),
('ERR_LAST_NAME_REQUIRED',  'error',   'last_name',     'employee', 'Last name is required.',                            'अंतिम नाम आवश्यक है।'),
('ERR_EMAIL_FORMAT',        'error',   'email',         'general',  'Invalid email address format.',                     'ईमेल पता अमान्य है।'),
('ERR_PHONE_FORMAT',        'error',   'phone',         'general',  'Phone must be 10 digits starting with 6–9.',        'फोन 10 अंक का होना चाहिए।'),
('ERR_PHONE_REQUIRED',      'error',   'phone',         'employee', 'Employee phone number is required.',                'कर्मचारी का फोन नंबर आवश्यक है।'),
('ERR_ROLE_LEVEL_INVALID',  'error',   'org_role_level','employee', 'Role level must be a number between 1 and 10.',     'भूमिका स्तर 1 से 10 के बीच होना चाहिए।'),
('ERR_BRANCH_NOT_FOUND',    'error',   'branch_code',   'employee', 'Branch code not found. Check branch_code column.',  'शाखा कोड नहीं मिला।'),
('WARN_DOJ_FUTURE',         'warning', 'date_of_joining','employee','Date of joining is in the future.',                  'नियुक्ति तिथि भविष्य में है।'),
('WARN_REPORTS_TO_MISSING', 'warning', 'reports_to_emp_id','employee','reports_to_emp_id not found — will be left blank.','रिपोर्टिंग आईडी नहीं मिली।'),
-- Student validations
('ERR_STU_ID_REQUIRED',     'error',   'student_id',    'student',  'Student ID is required.',                           'छात्र ID आवश्यक है।'),
('ERR_STU_ID_DUPLICATE',    'error',   'student_id',    'student',  'Student ID already exists.',                        'छात्र ID पहले से मौजूद है।'),
('ERR_CLASS_REQUIRED',      'error',   'class_name',    'student',  'Class name is required (e.g. Class 5).',            'कक्षा का नाम आवश्यक है।'),
('ERR_SECTION_REQUIRED',    'error',   'section',       'student',  'Section is required (A/B/C/D).',                    'सेक्शन आवश्यक है।'),
('ERR_DOB_FORMAT',          'error',   'date_of_birth', 'student',  'Date of birth must be in YYYY-MM-DD format.',       'जन्म तिथि YYYY-MM-DD प्रारूप में होनी चाहिए।'),
('ERR_GUARDIAN_PHONE',      'error',   'guardian_phone','student',  'Guardian phone number is required.',                'अभिभावक का फोन नंबर आवश्यक है।'),
('ERR_GENDER_INVALID',      'error',   'gender',        'general',  'Gender must be male, female, or other.',            'लिंग male/female/other होना चाहिए।'),
('WARN_BLOOD_GROUP',        'warning', 'blood_group',   'student',  'Blood group not provided — will be set to Unknown.','रक्त समूह नहीं दिया गया।'),
('WARN_CATEGORY_DEFAULT',   'warning', 'category',      'student',  'Category not provided — defaulting to General.',   'श्रेणी नहीं दी गई, General माना जाएगा।');

-- ── 7. ID card template enhancements ─────────────────────────
ALTER TABLE id_card_themes
  ADD COLUMN IF NOT EXISTS template_type ENUM('student','employee','both') NOT NULL DEFAULT 'student'
    COMMENT 'Who this template is for',
  ADD COLUMN IF NOT EXISTS orientation   ENUM('portrait','landscape')       NOT NULL DEFAULT 'landscape'
    COMMENT 'Card orientation',
  ADD COLUMN IF NOT EXISTS terms_front   TEXT NULL COMMENT 'Free text / terms shown on front',
  ADD COLUMN IF NOT EXISTS terms_back    TEXT NULL COMMENT 'T&C / instructions on back',
  ADD COLUMN IF NOT EXISTS is_prebuilt   TINYINT(1) NOT NULL DEFAULT 0
    COMMENT '1 = system prebuilt template, 0 = school-created';

-- ── 8. Seed 10 prebuilt templates ─────────────────────────────
INSERT IGNORE INTO id_card_themes
  (id, school_id, name, description, primary_color, secondary_color, accent_color,
   text_color, bg_color, front_layout, back_layout,
   template_type, orientation, terms_back, is_prebuilt, is_default)
VALUES
-- Student - Landscape
('tpl-std-001', NULL, 'Classic Blue (Student)',    'Official indigo school ID',  '#1A237E','#3F51B5','#FFC107','#212121','#FFFFFF',
 '{"style":"classic","show_photo":true,"show_qr":true,"show_blood":true}',
 '{"show_signature":true,"show_emergency":true}',
 'student','landscape','If found, please return to the school office.',1,0),

('tpl-std-002', NULL, 'Emerald Green (Student)',   'Fresh green campus card',    '#1B5E20','#4CAF50','#FFEB3B','#212121','#FFFFFF',
 '{"style":"emerald","show_photo":true,"show_qr":true,"show_blood":true}',
 '{"show_signature":true,"show_emergency":true}',
 'student','landscape','This card is property of the school. Return if found.',1,0),

('tpl-std-003', NULL, 'Royal Purple (Student)',    'Premium purple gradient',    '#4A148C','#7B1FA2','#F9A825','#FFFFFF','#FFFFFF',
 '{"style":"royal","show_photo":true,"show_qr":true,"show_blood":false}',
 '{"show_signature":true,"show_emergency":true}',
 'student','landscape','Authorised students only. Misuse will be reported.',1,0),

('tpl-std-004', NULL, 'Ocean Teal (Student)',      'Cool teal & coral',          '#006064','#00ACC1','#FF7043','#212121','#FFFFFF',
 '{"style":"ocean","show_photo":true,"show_qr":true,"show_blood":true}',
 '{"show_signature":true,"show_emergency":true}',
 'student','landscape','Valid for academic year 2025-26 only.',1,0),

('tpl-std-005', NULL, 'Slate Modern (Student)',    'Minimal slate grey',         '#37474F','#78909C','#FFCA28','#212121','#FAFAFA',
 '{"style":"slate","show_photo":true,"show_qr":false,"show_blood":true}',
 '{"show_signature":true,"show_emergency":true}',
 'student','landscape','Not transferable. Carry this card at all times.',1,0),

-- Student - Portrait
('tpl-std-006', NULL, 'Portrait Blue (Student)',   'Vertical portrait layout',   '#1A237E','#3F51B5','#FF6F00','#212121','#FFFFFF',
 '{"style":"portrait_blue","show_photo":true,"show_qr":true,"show_blood":true}',
 '{"show_signature":true,"show_emergency":true}',
 'student','portrait','Present this card at all school events and examinations.',1,0),

-- Employee - Landscape
('tpl-emp-001', NULL, 'Professional Navy (Staff)', 'Corporate navy staff ID',    '#0D1B63','#1A237E','#FFC107','#212121','#FFFFFF',
 '{"style":"navy","show_photo":true,"show_qr":true,"show_dept":true}',
 '{"show_signature":true,"show_designation":true}',
 'employee','landscape','Official staff identification. Wear while on campus.',1,0),

('tpl-emp-002', NULL, 'Crimson Authority (Staff)', 'Red & gold faculty ID',      '#7B1FA2','#C62828','#FFC107','#FFFFFF','#FFFFFF',
 '{"style":"crimson","show_photo":true,"show_qr":true,"show_dept":true}',
 '{"show_signature":true,"show_designation":true}',
 'employee','landscape','This ID card must be returned upon separation from service.',1,0),

('tpl-emp-003', NULL, 'Forest Green (Staff)',      'Natural green authority',    '#1B5E20','#2E7D32','#FFCA28','#212121','#FFFFFF',
 '{"style":"forest","show_photo":true,"show_qr":true,"show_dept":true}',
 '{"show_signature":true,"show_designation":true}',
 'employee','landscape','Valid while employed. Report loss immediately to HR.',1,0),

-- Both
('tpl-cmn-001', NULL, 'Universal Gold',            'Works for both roles',       '#BF360C','#FF7043','#FFD54F','#212121','#FFFDE7',
 '{"style":"universal","show_photo":true,"show_qr":true,"show_role_badge":true}',
 '{"show_signature":true,"show_emergency":true,"show_t_and_c":true}',
 'both','landscape','This card is the property of the institution. Do not tamper.',1,0);

SET FOREIGN_KEY_CHECKS = 1;
-- ============================================================
