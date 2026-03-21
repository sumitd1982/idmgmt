-- ============================================================
-- SAMPLE DATA: Delhi Public School (DPS)
-- 8-level org hierarchy, 3 branches, 100+ teachers, 2000 students
-- ============================================================
USE idmgmt;

SET FOREIGN_KEY_CHECKS = 0;

-- ============================================================
-- SUPER ADMIN USER
-- ============================================================
INSERT INTO users (id, email, full_name, role, is_active) VALUES
('usr-super-001', 'admin@idmgmt.in', 'Super Administrator', 'super_admin', TRUE),
('usr-dps-001', 'principal@dps-rkpuram.edu.in', 'Dr. Rajiv Kumar Sharma', 'principal', TRUE),
('usr-dps-002', 'principal@dps-rohini.edu.in', 'Mrs. Sunita Agarwal', 'principal', TRUE),
('usr-dps-003', 'principal@dps-dwarka.edu.in', 'Mr. Anil Bhatia', 'principal', TRUE);

-- ============================================================
-- SCHOOL: Delhi Public School Society
-- ============================================================
INSERT INTO schools (id, name, short_name, code, affiliation_no, affiliation_board, school_type,
    address_line1, address_line2, city, state, country, zip_code,
    phone1, phone2, email, website, whatsapp_no,
    academic_year, timezone, created_by) VALUES
('sch-dps-001', 'Delhi Public School Society', 'DPS', 'DPS-HQ',
 'CBSE-130001', 'CBSE', 'k12',
 'Sri Aurobindo Marg', 'New Delhi', 'New Delhi', 'Delhi', 'India', '110016',
 '+911126581700', '+911126581701', 'info@dps.in', 'https://www.dps.in', '+911126581700',
 '2025-26', 'Asia/Kolkata', 'usr-super-001');

-- ============================================================
-- BRANCHES
-- ============================================================
INSERT INTO branches (id, school_id, name, short_name, code,
    address_line1, address_line2, city, state, country, zip_code,
    phone1, email, whatsapp_no, created_by) VALUES
('brc-rkp-001', 'sch-dps-001', 'DPS R.K. Puram', 'DPS RKP', 'RKP',
 'Sector 2, R.K. Puram', 'Near AIIMS', 'New Delhi', 'Delhi', 'India', '110022',
 '+911126171002', 'rkpuram@dps.in', '+911126171002', 'usr-super-001'),

('brc-roh-001', 'sch-dps-001', 'DPS Rohini', 'DPS Rohini', 'ROH',
 'Sector 13, Rohini', 'Phase I', 'New Delhi', 'Delhi', 'India', '110085',
 '+911127554000', 'rohini@dps.in', '+911127554000', 'usr-super-001'),

('brc-dwk-001', 'sch-dps-001', 'DPS Dwarka', 'DPS Dwarka', 'DWK',
 'Sector 19, Dwarka', 'Near Metro Station', 'New Delhi', 'Delhi', 'India', '110075',
 '+911128049012', 'dwarka@dps.in', '+911128049012', 'usr-super-001');

-- ============================================================
-- ORG ROLES (8 Levels)
-- ============================================================
INSERT INTO org_roles (id, school_id, name, code, level, description, can_approve, can_upload_bulk, sort_order) VALUES
('rol-001', 'sch-dps-001', 'Principal',        'PRINCIPAL',    1, 'School Head — highest authority', TRUE, TRUE, 1),
('rol-002', 'sch-dps-001', 'Vice Principal',   'VP',           2, 'Deputy Head of School',           TRUE, TRUE, 2),
('rol-003', 'sch-dps-001', 'Head Teacher',     'HEAD_TEACHER', 3, 'Departmental Head',               TRUE, TRUE, 3),
('rol-004', 'sch-dps-001', 'Senior Teacher',   'SR_TEACHER',   4, 'Senior Faculty Member',           TRUE, FALSE, 4),
('rol-005', 'sch-dps-001', 'Class Teacher',    'CL_TEACHER',   5, 'Primary Class Instructor',        TRUE, FALSE, 5),
('rol-006', 'sch-dps-001', 'Subject Teacher',  'SUB_TEACHER',  6, 'Subject Specialist',              FALSE, FALSE, 6),
('rol-007', 'sch-dps-001', 'Backup Teacher',   'BAK_TEACHER',  7, 'Relief / Substitute Teacher',     FALSE, FALSE, 7),
('rol-008', 'sch-dps-001', 'Temp Teacher',     'TMP_TEACHER',  8, 'Temporary / Contract Teacher',    FALSE, FALSE, 8);

-- ============================================================
-- EMPLOYEES — Branch: RK Puram
-- Level 1: Principal (1)
-- Level 2: VPs (2)
-- Level 3: Head Teachers (6)
-- Level 4: Senior Teachers (12)
-- Level 5: Class Teachers (14)
-- Level 6: Subject Teachers (4)
-- Level 7: Backup Teachers (4)
-- Level 8: Temp Teachers (3)
-- TOTAL RKP: 46
-- ============================================================

-- Principal RKP
INSERT INTO employees (id, school_id, branch_id, employee_id, org_role_id, reports_to_emp_id, user_id,
    first_name, last_name, email, phone, whatsapp_no, date_of_joining, gender, is_active, assigned_classes) VALUES
('emp-rkp-001', 'sch-dps-001', 'brc-rkp-001', 'DPS-RKP-001', 'rol-001', NULL, 'usr-dps-001',
 'Rajiv Kumar', 'Sharma', 'principal@dps-rkpuram.edu.in', '+919810001001', '+919810001001',
 '2010-04-01', 'male', TRUE, '[]');

-- VPs RKP
INSERT INTO employees (id, school_id, branch_id, employee_id, org_role_id, reports_to_emp_id,
    first_name, last_name, email, phone, whatsapp_no, date_of_joining, gender, is_active, assigned_classes) VALUES
('emp-rkp-002', 'sch-dps-001', 'brc-rkp-001', 'DPS-RKP-002', 'rol-002', 'emp-rkp-001',
 'Priya', 'Mehta', 'vp1@dps-rkpuram.edu.in', '+919810001002', '+919810001002', '2012-04-01', 'female', TRUE, '[]'),
('emp-rkp-003', 'sch-dps-001', 'brc-rkp-001', 'DPS-RKP-003', 'rol-002', 'emp-rkp-001',
 'Suresh', 'Nair', 'vp2@dps-rkpuram.edu.in', '+919810001003', '+919810001003', '2013-07-15', 'male', TRUE, '[]');

-- Head Teachers RKP (6, alternating between 2 VPs)
INSERT INTO employees (id, school_id, branch_id, employee_id, org_role_id, reports_to_emp_id,
    first_name, last_name, email, phone, whatsapp_no, date_of_joining, gender, is_active, assigned_classes) VALUES
('emp-rkp-010', 'sch-dps-001', 'brc-rkp-001', 'DPS-RKP-010', 'rol-003', 'emp-rkp-002',
 'Anita', 'Gupta', 'ht.science@dps-rkpuram.edu.in', '+919810001010', '+919810001010', '2015-04-01', 'female', TRUE, '["11","12"]'),
('emp-rkp-011', 'sch-dps-001', 'brc-rkp-001', 'DPS-RKP-011', 'rol-003', 'emp-rkp-002',
 'Ramesh', 'Verma', 'ht.maths@dps-rkpuram.edu.in', '+919810001011', '+919810001011', '2014-06-01', 'male', TRUE, '["9","10"]'),
('emp-rkp-012', 'sch-dps-001', 'brc-rkp-001', 'DPS-RKP-012', 'rol-003', 'emp-rkp-002',
 'Kavita', 'Singh', 'ht.english@dps-rkpuram.edu.in', '+919810001012', '+919810001012', '2016-01-15', 'female', TRUE, '["6","7","8"]'),
('emp-rkp-013', 'sch-dps-001', 'brc-rkp-001', 'DPS-RKP-013', 'rol-003', 'emp-rkp-003',
 'Vijay', 'Pandey', 'ht.social@dps-rkpuram.edu.in', '+919810001013', '+919810001013', '2015-08-01', 'male', TRUE, '["6","7"]'),
('emp-rkp-014', 'sch-dps-001', 'brc-rkp-001', 'DPS-RKP-014', 'rol-003', 'emp-rkp-003',
 'Neha', 'Joshi', 'ht.hindi@dps-rkpuram.edu.in', '+919810001014', '+919810001014', '2017-04-01', 'female', TRUE, '["8","9","10"]'),
('emp-rkp-015', 'sch-dps-001', 'brc-rkp-001', 'DPS-RKP-015', 'rol-003', 'emp-rkp-003',
 'Ashok', 'Kumar', 'ht.arts@dps-rkpuram.edu.in', '+919810001015', '+919810001015', '2018-04-01', 'male', TRUE, '["1","2","3","4","5"]');

-- Senior Teachers RKP (12)
INSERT INTO employees (id, school_id, branch_id, employee_id, org_role_id, reports_to_emp_id,
    first_name, last_name, email, phone, whatsapp_no, date_of_joining, gender, is_active, assigned_classes) VALUES
('emp-rkp-020', 'sch-dps-001', 'brc-rkp-001', 'DPS-RKP-020', 'rol-004', 'emp-rkp-010',
 'Sunita', 'Chopra', 'sr.physics@dps-rkpuram.edu.in', '+919810001020', '+919810001020', '2016-04-01', 'female', TRUE, '["11","12"]'),
('emp-rkp-021', 'sch-dps-001', 'brc-rkp-001', 'DPS-RKP-021', 'rol-004', 'emp-rkp-010',
 'Mukesh', 'Arora', 'sr.chemistry@dps-rkpuram.edu.in', '+919810001021', '+919810001021', '2017-04-01', 'male', TRUE, '["11","12"]'),
('emp-rkp-022', 'sch-dps-001', 'brc-rkp-001', 'DPS-RKP-022', 'rol-004', 'emp-rkp-011',
 'Rekha', 'Sharma', 'sr.algebra@dps-rkpuram.edu.in', '+919810001022', '+919810001022', '2015-06-01', 'female', TRUE, '["9","10"]'),
('emp-rkp-023', 'sch-dps-001', 'brc-rkp-001', 'DPS-RKP-023', 'rol-004', 'emp-rkp-011',
 'Naveen', 'Yadav', 'sr.geometry@dps-rkpuram.edu.in', '+919810001023', '+919810001023', '2016-01-01', 'male', TRUE, '["9","10"]'),
('emp-rkp-024', 'sch-dps-001', 'brc-rkp-001', 'DPS-RKP-024', 'rol-004', 'emp-rkp-012',
 'Pooja', 'Kapoor', 'sr.english1@dps-rkpuram.edu.in', '+919810001024', '+919810001024', '2018-04-01', 'female', TRUE, '["6","7","8"]'),
('emp-rkp-025', 'sch-dps-001', 'brc-rkp-001', 'DPS-RKP-025', 'rol-004', 'emp-rkp-012',
 'Deepak', 'Bhatt', 'sr.english2@dps-rkpuram.edu.in', '+919810001025', '+919810001025', '2019-04-01', 'male', TRUE, '["6","7"]'),
('emp-rkp-026', 'sch-dps-001', 'brc-rkp-001', 'DPS-RKP-026', 'rol-004', 'emp-rkp-013',
 'Meena', 'Tiwari', 'sr.history@dps-rkpuram.edu.in', '+919810001026', '+919810001026', '2017-07-01', 'female', TRUE, '["6","7"]'),
('emp-rkp-027', 'sch-dps-001', 'brc-rkp-001', 'DPS-RKP-027', 'rol-004', 'emp-rkp-013',
 'Sanjay', 'Mishra', 'sr.geography@dps-rkpuram.edu.in', '+919810001027', '+919810001027', '2018-01-01', 'male', TRUE, '["6","7"]'),
('emp-rkp-028', 'sch-dps-001', 'brc-rkp-001', 'DPS-RKP-028', 'rol-004', 'emp-rkp-014',
 'Alka', 'Bose', 'sr.hindi1@dps-rkpuram.edu.in', '+919810001028', '+919810001028', '2016-04-01', 'female', TRUE, '["8","9","10"]'),
('emp-rkp-029', 'sch-dps-001', 'brc-rkp-001', 'DPS-RKP-029', 'rol-004', 'emp-rkp-014',
 'Ravi', 'Shankar', 'sr.hindi2@dps-rkpuram.edu.in', '+919810001029', '+919810001029', '2017-04-01', 'male', TRUE, '["8","9"]'),
('emp-rkp-030', 'sch-dps-001', 'brc-rkp-001', 'DPS-RKP-030', 'rol-004', 'emp-rkp-015',
 'Lalita', 'Devi', 'sr.arts@dps-rkpuram.edu.in', '+919810001030', '+919810001030', '2015-04-01', 'female', TRUE, '["1","2","3"]'),
('emp-rkp-031', 'sch-dps-001', 'brc-rkp-001', 'DPS-RKP-031', 'rol-004', 'emp-rkp-015',
 'Kishore', 'Das', 'sr.pt@dps-rkpuram.edu.in', '+919810001031', '+919810001031', '2016-07-01', 'male', TRUE, '["4","5"]');

-- Class Teachers RKP (14 — one per major class section)
INSERT INTO employees (id, school_id, branch_id, employee_id, org_role_id, reports_to_emp_id,
    first_name, last_name, email, phone, whatsapp_no, date_of_joining, gender, is_active, assigned_classes) VALUES
('emp-rkp-040', 'sch-dps-001', 'brc-rkp-001', 'DPS-RKP-040', 'rol-005', 'emp-rkp-022',
 'Saroj', 'Kumari', 'ct.10a@dps-rkpuram.edu.in', '+919810001040', '+919810001040', '2019-04-01', 'female', TRUE, '["10A"]'),
('emp-rkp-041', 'sch-dps-001', 'brc-rkp-001', 'DPS-RKP-041', 'rol-005', 'emp-rkp-022',
 'Mohit', 'Goyal', 'ct.10b@dps-rkpuram.edu.in', '+919810001041', '+919810001041', '2019-07-01', 'male', TRUE, '["10B"]'),
('emp-rkp-042', 'sch-dps-001', 'brc-rkp-001', 'DPS-RKP-042', 'rol-005', 'emp-rkp-023',
 'Geeta', 'Nanda', 'ct.9a@dps-rkpuram.edu.in', '+919810001042', '+919810001042', '2020-04-01', 'female', TRUE, '["9A"]'),
('emp-rkp-043', 'sch-dps-001', 'brc-rkp-001', 'DPS-RKP-043', 'rol-005', 'emp-rkp-023',
 'Rahul', 'Bansal', 'ct.9b@dps-rkpuram.edu.in', '+919810001043', '+919810001043', '2020-07-01', 'male', TRUE, '["9B"]'),
('emp-rkp-044', 'sch-dps-001', 'brc-rkp-001', 'DPS-RKP-044', 'rol-005', 'emp-rkp-024',
 'Usha', 'Rathi', 'ct.8a@dps-rkpuram.edu.in', '+919810001044', '+919810001044', '2018-04-01', 'female', TRUE, '["8A"]'),
('emp-rkp-045', 'sch-dps-001', 'brc-rkp-001', 'DPS-RKP-045', 'rol-005', 'emp-rkp-024',
 'Ajay', 'Saxena', 'ct.8b@dps-rkpuram.edu.in', '+919810001045', '+919810001045', '2018-07-01', 'male', TRUE, '["8B"]'),
('emp-rkp-046', 'sch-dps-001', 'brc-rkp-001', 'DPS-RKP-046', 'rol-005', 'emp-rkp-026',
 'Shobha', 'Rana', 'ct.7a@dps-rkpuram.edu.in', '+919810001046', '+919810001046', '2021-04-01', 'female', TRUE, '["7A"]'),
('emp-rkp-047', 'sch-dps-001', 'brc-rkp-001', 'DPS-RKP-047', 'rol-005', 'emp-rkp-026',
 'Manish', 'Thakur', 'ct.7b@dps-rkpuram.edu.in', '+919810001047', '+919810001047', '2021-07-01', 'male', TRUE, '["7B"]'),
('emp-rkp-048', 'sch-dps-001', 'brc-rkp-001', 'DPS-RKP-048', 'rol-005', 'emp-rkp-028',
 'Nirmala', 'Patel', 'ct.6a@dps-rkpuram.edu.in', '+919810001048', '+919810001048', '2019-04-01', 'female', TRUE, '["6A"]'),
('emp-rkp-049', 'sch-dps-001', 'brc-rkp-001', 'DPS-RKP-049', 'rol-005', 'emp-rkp-028',
 'Sushil', 'Mathur', 'ct.6b@dps-rkpuram.edu.in', '+919810001049', '+919810001049', '2019-07-01', 'male', TRUE, '["6B"]'),
('emp-rkp-050', 'sch-dps-001', 'brc-rkp-001', 'DPS-RKP-050', 'rol-005', 'emp-rkp-030',
 'Radha', 'Chauhan', 'ct.5a@dps-rkpuram.edu.in', '+919810001050', '+919810001050', '2020-04-01', 'female', TRUE, '["5A"]'),
('emp-rkp-051', 'sch-dps-001', 'brc-rkp-001', 'DPS-RKP-051', 'rol-005', 'emp-rkp-030',
 'Vinod', 'Srivastava', 'ct.5b@dps-rkpuram.edu.in', '+919810001051', '+919810001051', '2020-07-01', 'male', TRUE, '["5B"]'),
('emp-rkp-052', 'sch-dps-001', 'brc-rkp-001', 'DPS-RKP-052', 'rol-005', 'emp-rkp-031',
 'Poonam', 'Ahlawat', 'ct.4a@dps-rkpuram.edu.in', '+919810001052', '+919810001052', '2021-04-01', 'female', TRUE, '["4A"]'),
('emp-rkp-053', 'sch-dps-001', 'brc-rkp-001', 'DPS-RKP-053', 'rol-005', 'emp-rkp-031',
 'Praveen', 'Dubey', 'ct.4b@dps-rkpuram.edu.in', '+919810001053', '+919810001053', '2021-07-01', 'male', TRUE, '["4B"]');

-- Backup & Temp Teachers RKP
INSERT INTO employees (id, school_id, branch_id, employee_id, org_role_id, reports_to_emp_id,
    first_name, last_name, email, phone, whatsapp_no, date_of_joining, gender, is_active, assigned_classes, is_temp) VALUES
('emp-rkp-060', 'sch-dps-001', 'brc-rkp-001', 'DPS-RKP-060', 'rol-007', 'emp-rkp-040',
 'Savita', 'Singh', 'bak1@dps-rkpuram.edu.in', '+919810001060', '+919810001060', '2022-04-01', 'female', TRUE, '["10A","10B"]', FALSE),
('emp-rkp-061', 'sch-dps-001', 'brc-rkp-001', 'DPS-RKP-061', 'rol-007', 'emp-rkp-044',
 'Suraj', 'Pal', 'bak2@dps-rkpuram.edu.in', '+919810001061', '+919810001061', '2022-07-01', 'male', TRUE, '["8A","8B"]', FALSE),
('emp-rkp-062', 'sch-dps-001', 'brc-rkp-001', 'DPS-RKP-062', 'rol-007', 'emp-rkp-046',
 'Meera', 'Rawat', 'bak3@dps-rkpuram.edu.in', '+919810001062', '+919810001062', '2023-04-01', 'female', TRUE, '["7A","7B"]', FALSE),
('emp-rkp-063', 'sch-dps-001', 'brc-rkp-001', 'DPS-RKP-063', 'rol-007', 'emp-rkp-050',
 'Tarun', 'Rawat', 'bak4@dps-rkpuram.edu.in', '+919810001063', '+919810001063', '2023-07-01', 'male', TRUE, '["5A","5B"]', FALSE),
('emp-rkp-064', 'sch-dps-001', 'brc-rkp-001', 'DPS-RKP-064', 'rol-008', 'emp-rkp-042',
 'Rinki', 'Sharma', 'tmp1@dps-rkpuram.edu.in', '+919810001064', '+919810001064', '2024-01-01', 'female', TRUE, '["9A","9B"]', TRUE),
('emp-rkp-065', 'sch-dps-001', 'brc-rkp-001', 'DPS-RKP-065', 'rol-008', 'emp-rkp-048',
 'Amit', 'Jain', 'tmp2@dps-rkpuram.edu.in', '+919810001065', '+919810001065', '2024-01-01', 'male', TRUE, '["6A","6B"]', TRUE),
('emp-rkp-066', 'sch-dps-001', 'brc-rkp-001', 'DPS-RKP-066', 'rol-008', 'emp-rkp-052',
 'Seema', 'Dhar', 'tmp3@dps-rkpuram.edu.in', '+919810001066', '+919810001066', '2024-04-01', 'female', TRUE, '["4A","4B"]', TRUE);

-- ============================================================
-- EMPLOYEES — Rohini Branch (similar structure, different names, ~32 staff)
-- ============================================================
INSERT INTO employees (id, school_id, branch_id, employee_id, org_role_id, reports_to_emp_id,
    first_name, last_name, email, phone, whatsapp_no, date_of_joining, gender, is_active, assigned_classes) VALUES
-- Principal
('emp-roh-001', 'sch-dps-001', 'brc-roh-001', 'DPS-ROH-001', 'rol-001', NULL,
 'Sunita', 'Agarwal', 'principal@dps-rohini.edu.in', '+919811001001', '+919811001001', '2011-04-01', 'female', TRUE, '[]'),
-- VPs
('emp-roh-002', 'sch-dps-001', 'brc-roh-001', 'DPS-ROH-002', 'rol-002', 'emp-roh-001',
 'Harish', 'Malhotra', 'vp1@dps-rohini.edu.in', '+919811001002', '+919811001002', '2013-04-01', 'male', TRUE, '[]'),
('emp-roh-003', 'sch-dps-001', 'brc-roh-001', 'DPS-ROH-003', 'rol-002', 'emp-roh-001',
 'Sarita', 'Tandon', 'vp2@dps-rohini.edu.in', '+919811001003', '+919811001003', '2014-07-01', 'female', TRUE, '[]'),
-- Head Teachers
('emp-roh-010', 'sch-dps-001', 'brc-roh-001', 'DPS-ROH-010', 'rol-003', 'emp-roh-002',
 'Dhruv', 'Khanna', 'ht.science@dps-rohini.edu.in', '+919811001010', '+919811001010', '2015-04-01', 'male', TRUE, '["11","12"]'),
('emp-roh-011', 'sch-dps-001', 'brc-roh-001', 'DPS-ROH-011', 'rol-003', 'emp-roh-002',
 'Manjula', 'Sethi', 'ht.maths@dps-rohini.edu.in', '+919811001011', '+919811001011', '2015-06-01', 'female', TRUE, '["9","10"]'),
('emp-roh-012', 'sch-dps-001', 'brc-roh-001', 'DPS-ROH-012', 'rol-003', 'emp-roh-002',
 'Girish', 'Soni', 'ht.english@dps-rohini.edu.in', '+919811001012', '+919811001012', '2016-01-01', 'male', TRUE, '["6","7","8"]'),
('emp-roh-013', 'sch-dps-001', 'brc-roh-001', 'DPS-ROH-013', 'rol-003', 'emp-roh-003',
 'Vandana', 'Batra', 'ht.social@dps-rohini.edu.in', '+919811001013', '+919811001013', '2016-08-01', 'female', TRUE, '["6","7"]'),
('emp-roh-014', 'sch-dps-001', 'brc-roh-001', 'DPS-ROH-014', 'rol-003', 'emp-roh-003',
 'Santosh', 'Pillai', 'ht.hindi@dps-rohini.edu.in', '+919811001014', '+919811001014', '2017-04-01', 'male', TRUE, '["8","9","10"]'),
('emp-roh-015', 'sch-dps-001', 'brc-roh-001', 'DPS-ROH-015', 'rol-003', 'emp-roh-003',
 'Renu', 'Dixit', 'ht.arts@dps-rohini.edu.in', '+919811001015', '+919811001015', '2018-04-01', 'female', TRUE, '["1","2","3","4","5"]');

-- Rohini Senior + Class Teachers (abbreviated — 23 more)
INSERT INTO employees (id, school_id, branch_id, employee_id, org_role_id, reports_to_emp_id,
    first_name, last_name, email, phone, whatsapp_no, date_of_joining, gender, is_active, assigned_classes) VALUES
('emp-roh-020', 'sch-dps-001', 'brc-roh-001', 'DPS-ROH-020', 'rol-004', 'emp-roh-010',
 'Nitin', 'Chandra', 'sr.physics@dps-rohini.edu.in', '+919811001020', '+919811001020', '2016-04-01', 'male', TRUE, '["11","12"]'),
('emp-roh-021', 'sch-dps-001', 'brc-roh-001', 'DPS-ROH-021', 'rol-004', 'emp-roh-010',
 'Deepa', 'Menon', 'sr.bio@dps-rohini.edu.in', '+919811001021', '+919811001021', '2017-04-01', 'female', TRUE, '["11","12"]'),
('emp-roh-022', 'sch-dps-001', 'brc-roh-001', 'DPS-ROH-022', 'rol-004', 'emp-roh-011',
 'Rakesh', 'Dube', 'sr.maths@dps-rohini.edu.in', '+919811001022', '+919811001022', '2015-04-01', 'male', TRUE, '["9","10"]'),
('emp-roh-023', 'sch-dps-001', 'brc-roh-001', 'DPS-ROH-023', 'rol-004', 'emp-roh-012',
 'Seema', 'Narang', 'sr.english@dps-rohini.edu.in', '+919811001023', '+919811001023', '2017-04-01', 'female', TRUE, '["6","7","8"]'),
('emp-roh-030', 'sch-dps-001', 'brc-roh-001', 'DPS-ROH-030', 'rol-005', 'emp-roh-022',
 'Harpreet', 'Kaur', 'ct.10a@dps-rohini.edu.in', '+919811001030', '+919811001030', '2019-04-01', 'female', TRUE, '["10A"]'),
('emp-roh-031', 'sch-dps-001', 'brc-roh-001', 'DPS-ROH-031', 'rol-005', 'emp-roh-022',
 'Aakash', 'Mehrotra', 'ct.10b@dps-rohini.edu.in', '+919811001031', '+919811001031', '2019-07-01', 'male', TRUE, '["10B"]'),
('emp-roh-032', 'sch-dps-001', 'brc-roh-001', 'DPS-ROH-032', 'rol-005', 'emp-roh-022',
 'Trishna', 'Roy', 'ct.9a@dps-rohini.edu.in', '+919811001032', '+919811001032', '2020-04-01', 'female', TRUE, '["9A"]'),
('emp-roh-033', 'sch-dps-001', 'brc-roh-001', 'DPS-ROH-033', 'rol-005', 'emp-roh-023',
 'Satya', 'Prakash', 'ct.8a@dps-rohini.edu.in', '+919811001033', '+919811001033', '2020-07-01', 'male', TRUE, '["8A"]'),
('emp-roh-034', 'sch-dps-001', 'brc-roh-001', 'DPS-ROH-034', 'rol-005', 'emp-roh-023',
 'Shilpa', 'Negi', 'ct.7a@dps-rohini.edu.in', '+919811001034', '+919811001034', '2021-04-01', 'female', TRUE, '["7A"]'),
('emp-roh-035', 'sch-dps-001', 'brc-roh-001', 'DPS-ROH-035', 'rol-005', 'emp-roh-013',
 'Vikas', 'Luthra', 'ct.6a@dps-rohini.edu.in', '+919811001035', '+919811001035', '2021-07-01', 'male', TRUE, '["6A"]'),
('emp-roh-036', 'sch-dps-001', 'brc-roh-001', 'DPS-ROH-036', 'rol-005', 'emp-roh-015',
 'Anjali', 'Garg', 'ct.5a@dps-rohini.edu.in', '+919811001036', '+919811001036', '2022-04-01', 'female', TRUE, '["5A"]'),
('emp-roh-037', 'sch-dps-001', 'brc-roh-001', 'DPS-ROH-037', 'rol-007', 'emp-roh-030',
 'Kuldeep', 'Rana', 'bak1@dps-rohini.edu.in', '+919811001037', '+919811001037', '2022-07-01', 'male', TRUE, '["10A","9A"]'),
('emp-roh-038', 'sch-dps-001', 'brc-roh-001', 'DPS-ROH-038', 'rol-007', 'emp-roh-033',
 'Shweta', 'Choudhary', 'bak2@dps-rohini.edu.in', '+919811001038', '+919811001038', '2023-04-01', 'female', TRUE, '["8A","7A"]'),
('emp-roh-039', 'sch-dps-001', 'brc-roh-001', 'DPS-ROH-039', 'rol-008', 'emp-roh-035',
 'Pranav', 'Misra', 'tmp1@dps-rohini.edu.in', '+919811001039', '+919811001039', '2024-01-01', 'male', TRUE, '["6A","5A"]');

-- ============================================================
-- EMPLOYEES — Dwarka Branch (~30 staff)
-- ============================================================
INSERT INTO employees (id, school_id, branch_id, employee_id, org_role_id, reports_to_emp_id,
    first_name, last_name, email, phone, whatsapp_no, date_of_joining, gender, is_active, assigned_classes) VALUES
('emp-dwk-001', 'sch-dps-001', 'brc-dwk-001', 'DPS-DWK-001', 'rol-001', NULL,
 'Anil', 'Bhatia', 'principal@dps-dwarka.edu.in', '+919812001001', '+919812001001', '2012-04-01', 'male', TRUE, '[]'),
('emp-dwk-002', 'sch-dps-001', 'brc-dwk-001', 'DPS-DWK-002', 'rol-002', 'emp-dwk-001',
 'Kavitha', 'Nair', 'vp1@dps-dwarka.edu.in', '+919812001002', '+919812001002', '2014-04-01', 'female', TRUE, '[]'),
('emp-dwk-003', 'sch-dps-001', 'brc-dwk-001', 'DPS-DWK-003', 'rol-002', 'emp-dwk-001',
 'Ramakant', 'Tripathi', 'vp2@dps-dwarka.edu.in', '+919812001003', '+919812001003', '2015-07-01', 'male', TRUE, '[]'),
('emp-dwk-010', 'sch-dps-001', 'brc-dwk-001', 'DPS-DWK-010', 'rol-003', 'emp-dwk-002',
 'Shalini', 'Oberoi', 'ht.science@dps-dwarka.edu.in', '+919812001010', '+919812001010', '2016-04-01', 'female', TRUE, '["11","12"]'),
('emp-dwk-011', 'sch-dps-001', 'brc-dwk-001', 'DPS-DWK-011', 'rol-003', 'emp-dwk-002',
 'Narendra', 'Kulkarni', 'ht.maths@dps-dwarka.edu.in', '+919812001011', '+919812001011', '2016-06-01', 'male', TRUE, '["9","10"]'),
('emp-dwk-012', 'sch-dps-001', 'brc-dwk-001', 'DPS-DWK-012', 'rol-003', 'emp-dwk-002',
 'Bhavna', 'Desai', 'ht.english@dps-dwarka.edu.in', '+919812001012', '+919812001012', '2017-01-01', 'female', TRUE, '["6","7","8"]'),
('emp-dwk-013', 'sch-dps-001', 'brc-dwk-001', 'DPS-DWK-013', 'rol-003', 'emp-dwk-003',
 'Manoj', 'Tripathi', 'ht.social@dps-dwarka.edu.in', '+919812001013', '+919812001013', '2016-08-01', 'male', TRUE, '["6","7"]'),
('emp-dwk-014', 'sch-dps-001', 'brc-dwk-001', 'DPS-DWK-014', 'rol-003', 'emp-dwk-003',
 'Rakhee', 'Aggarwal', 'ht.hindi@dps-dwarka.edu.in', '+919812001014', '+919812001014', '2017-04-01', 'female', TRUE, '["8","9","10"]'),
('emp-dwk-020', 'sch-dps-001', 'brc-dwk-001', 'DPS-DWK-020', 'rol-004', 'emp-dwk-010',
 'Subhash', 'Goel', 'sr.physics@dps-dwarka.edu.in', '+919812001020', '+919812001020', '2017-04-01', 'male', TRUE, '["11","12"]'),
('emp-dwk-021', 'sch-dps-001', 'brc-dwk-001', 'DPS-DWK-021', 'rol-004', 'emp-dwk-011',
 'Archana', 'Choudhuri', 'sr.maths@dps-dwarka.edu.in', '+919812001021', '+919812001021', '2018-04-01', 'female', TRUE, '["9","10"]'),
('emp-dwk-022', 'sch-dps-001', 'brc-dwk-001', 'DPS-DWK-022', 'rol-004', 'emp-dwk-012',
 'Hemant', 'Joshi', 'sr.english@dps-dwarka.edu.in', '+919812001022', '+919812001022', '2018-07-01', 'male', TRUE, '["6","7","8"]'),
('emp-dwk-030', 'sch-dps-001', 'brc-dwk-001', 'DPS-DWK-030', 'rol-005', 'emp-dwk-021',
 'Kiran', 'Kapila', 'ct.10a@dps-dwarka.edu.in', '+919812001030', '+919812001030', '2019-04-01', 'female', TRUE, '["10A"]'),
('emp-dwk-031', 'sch-dps-001', 'brc-dwk-001', 'DPS-DWK-031', 'rol-005', 'emp-dwk-021',
 'Yogesh', 'Walia', 'ct.9a@dps-dwarka.edu.in', '+919812001031', '+919812001031', '2019-07-01', 'male', TRUE, '["9A"]'),
('emp-dwk-032', 'sch-dps-001', 'brc-dwk-001', 'DPS-DWK-032', 'rol-005', 'emp-dwk-022',
 'Preeti', 'Khatri', 'ct.8a@dps-dwarka.edu.in', '+919812001032', '+919812001032', '2020-04-01', 'female', TRUE, '["8A"]'),
('emp-dwk-033', 'sch-dps-001', 'brc-dwk-001', 'DPS-DWK-033', 'rol-005', 'emp-dwk-013',
 'Arun', 'Bhatnagar', 'ct.7a@dps-dwarka.edu.in', '+919812001033', '+919812001033', '2020-07-01', 'male', TRUE, '["7A"]'),
('emp-dwk-034', 'sch-dps-001', 'brc-dwk-001', 'DPS-DWK-034', 'rol-005', 'emp-dwk-014',
 'Shashi', 'Kaur', 'ct.6a@dps-dwarka.edu.in', '+919812001034', '+919812001034', '2021-04-01', 'female', TRUE, '["6A"]'),
('emp-dwk-035', 'sch-dps-001', 'brc-dwk-001', 'DPS-DWK-035', 'rol-007', 'emp-dwk-030',
 'Rohit', 'Sehgal', 'bak1@dps-dwarka.edu.in', '+919812001035', '+919812001035', '2022-04-01', 'male', TRUE, '["10A","9A"]'),
('emp-dwk-036', 'sch-dps-001', 'brc-dwk-001', 'DPS-DWK-036', 'rol-008', 'emp-dwk-032',
 'Prity', 'Thakral', 'tmp1@dps-dwarka.edu.in', '+919812001036', '+919812001036', '2024-01-01', 'female', TRUE, '["8A","7A"]');

-- ============================================================
-- CLASSES for RK Puram Branch
-- ============================================================
INSERT INTO classes (id, branch_id, name, numeric_level, sections, class_teacher_id) VALUES
('cls-rkp-12', 'brc-rkp-001', 'Class 12', 12, '["A","B"]', NULL),
('cls-rkp-11', 'brc-rkp-001', 'Class 11', 11, '["A","B"]', NULL),
('cls-rkp-10', 'brc-rkp-001', 'Class 10', 10, '["A","B"]', 'emp-rkp-040'),
('cls-rkp-09', 'brc-rkp-001', 'Class 9',   9, '["A","B"]', 'emp-rkp-042'),
('cls-rkp-08', 'brc-rkp-001', 'Class 8',   8, '["A","B"]', 'emp-rkp-044'),
('cls-rkp-07', 'brc-rkp-001', 'Class 7',   7, '["A","B"]', 'emp-rkp-046'),
('cls-rkp-06', 'brc-rkp-001', 'Class 6',   6, '["A","B"]', 'emp-rkp-048'),
('cls-rkp-05', 'brc-rkp-001', 'Class 5',   5, '["A","B"]', 'emp-rkp-050'),
('cls-rkp-04', 'brc-rkp-001', 'Class 4',   4, '["A","B"]', 'emp-rkp-052');

-- ============================================================
-- STUDENTS (2000 total — generated via stored procedure)
-- ============================================================
-- We use a procedure to generate 2000 realistic student records

DROP PROCEDURE IF EXISTS generate_students;

DELIMITER $$
CREATE PROCEDURE generate_students()
BEGIN
    DECLARE i INT DEFAULT 1;
    DECLARE branch_id VARCHAR(36);
    DECLARE class_nm VARCHAR(20);
    DECLARE section_nm VARCHAR(10);
    DECLARE gender_val ENUM('male','female');
    DECLARE first_nm VARCHAR(50);
    DECLARE last_nm VARCHAR(50);
    DECLARE blood_g VARCHAR(10);
    DECLARE status_c ENUM('red','blue','green');

    -- Name pools
    SET @male_first = '["Aarav","Vivaan","Aditya","Vihaan","Arjun","Sai","Reyansh","Ayaan","Krishna","Ishaan","Shaurya","Atharva","Advik","Pranav","Advaith","Dhruv","Kabir","Ritvik","Aarush","Darsh","Divyansh","Yuvraj","Rudra","Harshit","Arnav","Himanshu","Rishabh","Tanish","Laksh","Karan","Mohit","Nikhil","Varun","Udit","Sachin","Rohan","Gaurav","Vikram","Anand","Manav"]']';
    SET @female_first = '["Aadhya","Ananya","Pari","Aanya","Riya","Pihu","Anvi","Sara","Diya","Myra","Kiara","Avni","Isha","Neha","Priya","Shruti","Pooja","Swati","Meera","Kavya","Tanvi","Sneha","Nidhi","Ankita","Divya","Sana","Tanya","Sonal","Kritika","Rekha","Deepa","Simran","Mansi","Jyoti","Swara","Radha","Geeta","Uma","Vani","Lakshmi"]']';
    SET @last_names = '["Sharma","Verma","Gupta","Agarwal","Singh","Yadav","Mishra","Pandey","Tiwari","Joshi","Kumar","Nair","Menon","Patel","Shah","Modi","Mehta","Kapoor","Malhotra","Chopra","Saxena","Srivastava","Dubey","Shukla","Tripathi","Chandra","Rao","Reddy","Iyer","Pillai","Das","Bose","Roy","Mukherjee","Chatterjee","Dey","Saha","Ghosh","Paul","Sen"]']';
    SET @blood_groups = '["A+","A-","B+","B-","O+","O-","AB+","AB-"]';
    SET @branches = '["brc-rkp-001","brc-roh-001","brc-dwk-001"]';
    SET @classes  = '["10","9","8","7","6","5","4","3","2","1"]';
    SET @sections = '["A","B","C","D"]';
    SET @statuses = '["red","blue","green"]';

    WHILE i <= 2000 DO
        -- Distribute across branches
        SET branch_id = JSON_UNQUOTE(JSON_EXTRACT(JSON_ARRAY('brc-rkp-001','brc-roh-001','brc-dwk-001'),
                        CONCAT('$[', MOD(i-1, 3), ']')));

        -- Distribute across classes 1-12
        SET class_nm = CONCAT('Class ', (MOD(i-1, 12) + 1));

        -- 2 sections per class
        SET section_nm = ELT(MOD(i-1, 4) + 1, 'A', 'B', 'C', 'D');

        SET gender_val = IF(MOD(i, 2) = 0, 'male', 'female');

        -- Pick names
        IF gender_val = 'male' THEN
            SET first_nm = JSON_UNQUOTE(JSON_EXTRACT(JSON_ARRAY(
                'Aarav','Vivaan','Aditya','Vihaan','Arjun','Sai','Reyansh','Ayaan','Krishna','Ishaan',
                'Shaurya','Atharva','Advik','Pranav','Advaith','Dhruv','Kabir','Ritvik','Aarush','Darsh'),
                CONCAT('$[', MOD(i, 20), ']')));
        ELSE
            SET first_nm = JSON_UNQUOTE(JSON_EXTRACT(JSON_ARRAY(
                'Aadhya','Ananya','Pari','Aanya','Riya','Pihu','Anvi','Sara','Diya','Myra',
                'Kiara','Avni','Isha','Neha','Priya','Shruti','Pooja','Swati','Meera','Kavya'),
                CONCAT('$[', MOD(i, 20), ']')));
        END IF;

        SET last_nm = JSON_UNQUOTE(JSON_EXTRACT(JSON_ARRAY(
            'Sharma','Verma','Gupta','Agarwal','Singh','Yadav','Mishra','Pandey','Tiwari','Joshi',
            'Kumar','Nair','Menon','Patel','Shah','Modi','Mehta','Kapoor','Malhotra','Chopra',
            'Saxena','Srivastava','Dubey','Shukla','Tripathi','Chandra','Rao','Reddy','Iyer','Pillai'),
            CONCAT('$[', MOD(i, 30), ']')));

        SET blood_g = JSON_UNQUOTE(JSON_EXTRACT(JSON_ARRAY('A+','A-','B+','B-','O+','O-','AB+','AB-'),
                      CONCAT('$[', MOD(i, 8), ']')));

        SET status_c = JSON_UNQUOTE(JSON_EXTRACT(JSON_ARRAY('red','blue','green'),
                       CONCAT('$[', MOD(i, 3), ']')));

        INSERT INTO students (
            school_id, branch_id, student_id, roll_number,
            class_name, section, academic_year,
            first_name, last_name, date_of_birth, gender, blood_group,
            nationality, category,
            address_line1, city, state, country, zip_code,
            bus_route, bus_stop,
            is_active, review_status, status_color
        ) VALUES (
            'sch-dps-001', branch_id,
            CONCAT('DPS-STU-', LPAD(i, 5, '0')),
            CONCAT('R', LPAD(MOD(i-1, 50) + 1, 3, '0')),
            class_nm, section_nm, '2025-26',
            first_nm, last_nm,
            DATE_SUB(CURDATE(), INTERVAL (5 + MOD(i-1,12) + FLOOR(RAND()*365)) DAY),
            gender_val, blood_g,
            'Indian',
            ELT(MOD(i, 4) + 1, 'General','OBC','SC','ST'),
            CONCAT('House No. ', MOD(i, 999) + 1, ', Sector ', MOD(i, 30) + 1),
            'New Delhi', 'Delhi', 'India',
            CONCAT('11', LPAD(MOD(i-1, 100), 4, '0')),
            CONCAT('Route-', MOD(i, 15) + 1),
            CONCAT('Stop-', MOD(i, 30) + 1),
            TRUE,
            ELT(MOD(i, 3) + 1, 'pending','parent_reviewed','approved'),
            status_c
        );

        -- Insert primary guardian (mother or father alternating)
        INSERT INTO guardians (student_id, guardian_type, first_name, last_name, relation,
            phone, whatsapp_no, email, occupation, is_primary, same_as_student)
        SELECT id, 'mother',
            JSON_UNQUOTE(JSON_EXTRACT(JSON_ARRAY(
                'Sunita','Priya','Meena','Kavita','Rekha','Anita','Neha','Pooja','Seema','Radha',
                'Geeta','Uma','Lata','Kiran','Asha','Sudha','Mala','Rani','Saroj','Madhuri'),
                CONCAT('$[', MOD(i, 20), ']'))),
            last_nm, 'Mother',
            CONCAT('+9198100', LPAD(i, 5, '0')),
            CONCAT('+9198100', LPAD(i, 5, '0')),
            CONCAT('parent', i, '@gmail.com'),
            ELT(MOD(i, 6) + 1, 'Teacher','Engineer','Doctor','Homemaker','Business','Government'),
            TRUE, TRUE
        FROM students WHERE student_id = CONCAT('DPS-STU-', LPAD(i, 5, '0'))
        LIMIT 1;

        SET i = i + 1;
    END WHILE;
END$$
DELIMITER ;

CALL generate_students();
DROP PROCEDURE IF EXISTS generate_students;

-- ============================================================
-- ID CARD THEMES
-- ============================================================
INSERT INTO id_card_themes (id, school_id, name, description,
    primary_color, secondary_color, accent_color, text_color, bg_color,
    front_layout, back_layout, is_default) VALUES
('thm-001', 'sch-dps-001', 'Classic Blue', 'Traditional DPS blue theme',
 '#003087', '#1565C0', '#FFC107', '#212121', '#FFFFFF',
 '{"header":{"type":"school_header_v1","show_logo":true,"show_name":true},"body":{"type":"student_body_v1","show_photo":true,"show_qr":true},"footer":{"type":"branch_footer_v1"}}',
 '{"header":{"type":"blank"},"body":{"type":"contact_body_v1","show_address":true,"show_emergency":true},"footer":{"type":"barcode_footer"}}',
 TRUE),

('thm-002', 'sch-dps-001', 'Modern Green', 'Contemporary green and white theme',
 '#1B5E20', '#43A047', '#FF6F00', '#212121', '#F5F5F5',
 '{"header":{"type":"school_header_v2","show_logo":true,"gradient":true},"body":{"type":"student_body_v2","photo_circle":true,"show_qr":true},"footer":{"type":"gradient_footer"}}',
 '{"header":{"type":"school_mini_header"},"body":{"type":"contact_body_v2"},"footer":{"type":"barcode_footer"}}',
 FALSE),

('thm-003', 'sch-dps-001', 'Royal Purple', 'Premium purple gradient theme',
 '#4A148C', '#7B1FA2', '#F9A825', '#FFFFFF', '#FFFFFF',
 '{"header":{"type":"school_header_v3","dark_bg":true,"show_logo":true},"body":{"type":"student_body_v3","show_photo":true,"show_qr":true},"footer":{"type":"light_footer"}}',
 '{"header":{"type":"blank"},"body":{"type":"contact_body_v3"},"footer":{"type":"barcode_footer"}}',
 FALSE);

-- Assign default theme
INSERT INTO id_card_assignments (school_id, branch_id, theme_id, employee_type) VALUES
('sch-dps-001', NULL, 'thm-001', 'student'),
('sch-dps-001', NULL, 'thm-001', 'teacher');

SET FOREIGN_KEY_CHECKS = 1;

-- Verification queries
SELECT 'Schools' as entity, COUNT(*) as total FROM schools
UNION ALL SELECT 'Branches', COUNT(*) FROM branches
UNION ALL SELECT 'Org Roles', COUNT(*) FROM org_roles
UNION ALL SELECT 'Employees', COUNT(*) FROM employees
UNION ALL SELECT 'Students', COUNT(*) FROM students
UNION ALL SELECT 'Guardians', COUNT(*) FROM guardians
UNION ALL SELECT 'ID Themes', COUNT(*) FROM id_card_themes;
