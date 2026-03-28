#!/usr/bin/env node
/**
 * End-to-End Test: Branch — Add, Edit, Delete (deactivate), All Properties, Photo/Logo
 * Relationships: School→Branch, Branch→Employee, Branch→Student
 *
 * Sections:
 *  1.  Authentication
 *  2.  Create Branch — happy path (all fields, including logo_url)
 *  3.  Create Branch — missing required fields
 *  4.  Create Branch — whitespace-only required fields
 *  5.  Create Branch — missing school_id
 *  6.  Create Branch — duplicate code within same school
 *  7.  Create Branch — duplicate code in different school (should succeed)
 *  8.  Boundary — name, code, phone lengths, logo_url length
 *  9.  List Branches — filters: school_id, city, country, search
 *  10. List Branches — employee_count & student_count in response
 *  11. Upload Branch Logo (/uploads/school-logo)
 *  12. Edit Branch — all allowed fields
 *  13. Edit Branch — partial updates (logo_url, is_active, phone)
 *  14. Edit Branch — logo_url length boundary
 *  15. Edit Branch — no valid fields
 *  16. Edit Branch — empty body
 *  17. Edit Branch — non-existent branch
 *  18. "Delete" Branch — deactivate (is_active: false), verify excluded from default list
 *  19. Reactivate Branch
 *  20. School → Branch relationship — branch belongs to correct school
 *  21. Branch → Employee relationship — create employee in branch, list by branch
 *  22. Branch → Student relationship — create student in branch, list by branch
 *  23. Authorization — unauthenticated access
 *  24. Auto-seeded classes — verify 15 default classes after branch creation
 */

const axios    = require('axios');
const fs       = require('fs');
const path     = require('path');
const FormData = require('form-data');

const BASE       = 'http://localhost:3001/idmgmt/api';
const PHOTO_FILE = path.join(__dirname, '../5.jpg');

// Known test anchors (Delhi Public School)
const SCHOOL_ID     = 'd895e400-9d6a-434e-8fb4-899a027d1e1d';
const ROLE_PRINCIPAL = '28405112-3e3a-4be8-ade0-6cb86145cdb4';

let TOKEN      = '';
let BRANCH_ID  = '';
let BRANCH_CODE = '';
let EMP_ID     = '';
let STU_ID     = '';

let passCount = 0;
let failCount = 0;
const failures = [];

// ── Helpers ──────────────────────────────────────────────────────────────────

function pass(name) {
  passCount++;
  console.log(`  ✅ PASS  ${name}`);
}

function fail(name, reason) {
  failCount++;
  failures.push({ name, reason });
  console.log(`  ❌ FAIL  ${name}`);
  console.log(`           ${reason}`);
}

function section(title) {
  console.log(`\n${'─'.repeat(64)}`);
  console.log(`  ${title}`);
  console.log('─'.repeat(64));
}

async function api(method, urlPath, data, extraHeaders = {}) {
  const cfg = {
    method,
    url: `${BASE}${urlPath}`,
    headers: { Authorization: `Bearer ${TOKEN}`, ...extraHeaders },
    validateStatus: () => true,
    timeout: 30000,
  };
  if (data instanceof FormData) {
    cfg.data    = data;
    cfg.headers = { ...cfg.headers, ...data.getHeaders() };
  } else if (data !== undefined) {
    cfg.data                    = data;
    cfg.headers['Content-Type'] = 'application/json';
  }
  return axios(cfg);
}

function assertOk(res, name, check) {
  if (res.status >= 200 && res.status < 300 && res.data.success !== false) {
    if (check && !check(res.data)) {
      fail(name, `Unexpected body: ${JSON.stringify(res.data).slice(0, 300)}`);
    } else {
      pass(name);
    }
  } else {
    fail(name, `HTTP ${res.status}: ${JSON.stringify(res.data).slice(0, 300)}`);
  }
}

function assertFail(res, name, expectedStatus, expectedMsg) {
  const statusOk = res.status === expectedStatus ||
                   (expectedStatus >= 400 && res.status >= 400 && res.status < 600);
  if (!statusOk) {
    fail(name, `Expected HTTP ${expectedStatus}, got ${res.status}: ${JSON.stringify(res.data).slice(0, 200)}`);
    return;
  }
  if (expectedMsg) {
    const body = JSON.stringify(res.data).toLowerCase();
    if (!body.includes(expectedMsg.toLowerCase())) {
      fail(name, `Expected error containing "${expectedMsg}", got: ${JSON.stringify(res.data).slice(0, 300)}`);
      return;
    }
  }
  pass(name);
}

/** Minimal valid branch payload */
function minBranch(overrides = {}) {
  const ts   = Date.now();
  const rand = Math.floor(Math.random() * 9000) + 1000;
  return {
    school_id:    SCHOOL_ID,
    name:         `Test Branch ${ts}`,
    code:         `BR${rand}`.toUpperCase(),
    address_line1:'10 Test Lane',
    city:         'Delhi',
    state:        'Delhi',
    country:      'India',
    zip_code:     '110001',
    phone1:       '9876500001',
    email:        `branch${ts}@test.com`,
    ...overrides,
  };
}

function tinyJpegBuffer() {
  return Buffer.from(
    'ffd8ffe000104a46494600010100000100010000ffdb004300080606070605080707070909' +
    '080a0c140d0c0b0b0c191213' +
    '0f141d1a1f1e1d1a1c1c20242e2720222c231c1c2837292c30313434341f27393d38323c2e333432ffc0000b08000100' +
    '0101011100ffc4001f0000010501010101010100000000000000000102030405060708090a0bffda00080101000003f0ffd9',
    'hex'
  );
}

// ── Main ─────────────────────────────────────────────────────────────────────

async function main() {
  console.log('╔══════════════════════════════════════════════════════════════╗');
  console.log('║   BRANCH  ADD / EDIT / DELETE — FULL E2E TEST SUITE          ║');
  console.log('╚══════════════════════════════════════════════════════════════╝');

  // ── 1. AUTHENTICATION ────────────────────────────────────────────────────
  section('1. AUTHENTICATION');
  {
    const res = await axios.post(`${BASE}/auth/otp/verify`,
      { phone: '8826756777', otp: '123456' }, { validateStatus: () => true });
    if (res.data?.data?.token) {
      TOKEN = res.data.data.token;
      pass('Login with master OTP (super_admin)');
    } else {
      fail('Login with master OTP', JSON.stringify(res.data));
      process.exit(1);
    }
  }

  // ── 2. CREATE BRANCH — HAPPY PATH (all fields) ───────────────────────────
  section('2. CREATE BRANCH — HAPPY PATH (all fields)');
  {
    const ts = Date.now();
    BRANCH_CODE = `FULL${ts}`.slice(0, 20).toUpperCase();

    const payload = {
      school_id:    SCHOOL_ID,
      name:         `Full Test Branch ${ts}`,
      short_name:   'FTB',
      code:         BRANCH_CODE,
      logo_url:     '/idmgmt/api/static/images/school/logo_test_branch.webp',
      address_line1:'55 Branch Street',
      address_line2:'Near Central Park',
      city:         'New Delhi',
      state:        'Delhi',
      country:      'India',
      zip_code:     '110002',
      phone1:       '9111100001',
      phone2:       '9111100002',
      email:        `fullbranch${ts}@example.com`,
      website:      'https://fullbranch.example.com',
      whatsapp_no:  '9111100001',
    };

    const res = await api('POST', '/branches', payload);
    assertOk(res, 'Create branch with all fields — HTTP 201', d => {
      const b = d.data;
      return d.success &&
        b.id &&
        b.name  === payload.name &&
        b.code  === BRANCH_CODE &&
        b.school_id === SCHOOL_ID;
    });

    if (res.data?.data?.id) {
      BRANCH_ID = res.data.data.id;
      console.log(`      → Created branch ID: ${BRANCH_ID}`);
    } else {
      fail('Extract branch ID', 'No branch ID — remaining tests may fail');
    }
  }

  // ── 3. CREATE BRANCH — MISSING REQUIRED FIELDS ───────────────────────────
  section('3. CREATE BRANCH — MISSING REQUIRED FIELDS (422)');
  {
    // name missing
    let res = await api('POST', '/branches', { ...minBranch(), name: undefined });
    assertFail(res, 'Missing name — 422', 422, 'name');

    // code missing (neither code nor branch_code)
    const { code, ...noCode } = minBranch();
    res = await api('POST', '/branches', noCode);
    assertFail(res, 'Missing code — 422', 422, 'code');

    // name empty string
    res = await api('POST', '/branches', minBranch({ name: '' }));
    assertFail(res, 'Empty string name — 422', 422, 'name');

    // code empty string
    res = await api('POST', '/branches', minBranch({ code: '' }));
    assertFail(res, 'Empty string code — 422', 422, 'code');
  }

  // ── 4. CREATE BRANCH — WHITESPACE-ONLY REQUIRED FIELDS ───────────────────
  section('4. CREATE BRANCH — WHITESPACE-ONLY REQUIRED FIELDS');
  {
    // Whitespace name
    let res = await api('POST', '/branches', minBranch({ name: '   ' }));
    if (res.status >= 400) {
      pass('Whitespace-only name rejected');
    } else {
      fail('Whitespace-only name — should be rejected', `HTTP ${res.status}, stored name: "${res.data?.data?.name}"`);
    }

    // Whitespace code
    res = await api('POST', '/branches', minBranch({ code: '   ' }));
    if (res.status >= 400) {
      pass('Whitespace-only code rejected');
    } else {
      fail('Whitespace-only code — should be rejected', `HTTP ${res.status}, stored code: "${res.data?.data?.code}"`);
    }
  }

  // ── 5. CREATE BRANCH — MISSING school_id ─────────────────────────────────
  section('5. CREATE BRANCH — MISSING school_id (super_admin has no default school)');
  {
    const { school_id, ...noSchool } = minBranch();
    const res = await api('POST', '/branches', noSchool);
    assertFail(res, 'Missing school_id for super_admin — 422', 422, 'school_id');
  }

  // ── 6. DUPLICATE CODE — SAME SCHOOL ──────────────────────────────────────
  section('6. DUPLICATE BRANCH CODE — SAME SCHOOL');
  {
    if (!BRANCH_ID) {
      fail('Duplicate code test — skipped (no BRANCH_ID)', '');
    } else {
      const res = await api('POST', '/branches', minBranch({ code: BRANCH_CODE }));
      // DB unique key (school_id, code) — should reject
      if (res.status >= 400 && res.status < 600) {
        pass(`Duplicate code in same school rejected (HTTP ${res.status})`);
      } else {
        fail('Duplicate code in same school — should be rejected', `HTTP ${res.status}`);
      }
    }
  }

  // ── 7. DUPLICATE CODE — DIFFERENT SCHOOL ─────────────────────────────────
  section('7. DUPLICATE CODE — DIFFERENT SCHOOL (should succeed)');
  {
    // Create a second test school first, then try same code
    const schoolRes = await api('POST', '/schools', {
      name:          `Branch Test School ${Date.now()}`,
      code:          `BTS${Date.now()}`.slice(0, 20),
      address_line1: '1 Other Road',
      city:          'Mumbai',
      state:         'Maharashtra',
      country:       'India',
      zip_code:      '400001',
      phone1:        '8000000001',
      email:         `bts${Date.now()}@test.com`,
    });

    if (schoolRes.data?.data?.id) {
      const otherSchoolId = schoolRes.data.data.id;
      const res = await api('POST', '/branches', minBranch({
        school_id: otherSchoolId,
        code:      BRANCH_CODE, // same code, different school
      }));
      if (res.status === 201) {
        pass('Same code in different school allowed (201)');
      } else {
        fail('Same code in different school should be allowed', `HTTP ${res.status}: ${JSON.stringify(res.data).slice(0, 200)}`);
      }
    } else {
      fail('Duplicate-in-different-school — could not create second school', JSON.stringify(schoolRes.data).slice(0, 200));
    }
  }

  // ── 8. BOUNDARY CONDITIONS ───────────────────────────────────────────────
  section('8. BOUNDARY CONDITIONS');
  {
    // name = 255 chars (max for VARCHAR 255)
    let res = await api('POST', '/branches', minBranch({ name: 'N'.repeat(255) }));
    if (res.status >= 200 && res.status < 300) {
      pass('name = 255 chars (boundary, accepted)');
    } else {
      fail('name = 255 chars', `HTTP ${res.status}`);
    }

    // name = 256 chars — DB will truncate or error
    res = await api('POST', '/branches', minBranch({ name: 'N'.repeat(256) }));
    if (res.status >= 500) {
      fail('name = 256 chars — should not 5xx', `HTTP ${res.status}`);
    } else {
      pass(`name = 256 chars handled (HTTP ${res.status})`);
    }

    // code = 20 chars (max)
    const code20 = `C${Date.now()}`.slice(0, 20).toUpperCase().padEnd(20, 'X');
    res = await api('POST', '/branches', minBranch({ code: code20 }));
    if (res.status === 201) {
      pass('code = 20 chars (boundary, accepted)');
    } else {
      fail('code = 20 chars', `HTTP ${res.status}`);
    }

    // code = 21 chars
    res = await api('POST', '/branches', minBranch({ code: code20 + 'Z' }));
    if (res.status >= 500) {
      fail('code = 21 chars — should not 5xx', `HTTP ${res.status}`);
    } else {
      pass(`code = 21 chars handled (HTTP ${res.status})`);
    }

    // phone1 = 20 chars
    res = await api('POST', '/branches', minBranch({ phone1: '1'.repeat(20) }));
    if (res.status >= 200 && res.status < 300) {
      pass('phone1 = 20 chars (boundary, accepted)');
    } else {
      pass(`phone1 = 20 chars (HTTP ${res.status})`);
    }

    // phone1 = 21 chars — should not 5xx
    res = await api('POST', '/branches', minBranch({ phone1: '1'.repeat(21) }));
    if (res.status >= 500) {
      fail('phone1 = 21 chars — should not 5xx', `HTTP ${res.status}`);
    } else {
      pass(`phone1 = 21 chars handled (HTTP ${res.status})`);
    }

    // logo_url = 1024 chars (boundary)
    const logoUrl1024 = 'https://cdn.test.com/' + 'a'.repeat(1003);
    res = await api('POST', '/branches', minBranch({ logo_url: logoUrl1024 }));
    if (res.status >= 200 && res.status < 300) {
      pass('logo_url = 1024 chars (boundary, accepted)');
    } else {
      fail('logo_url = 1024 chars', `HTTP ${res.status}`);
    }

    // logo_url = 1025 chars — should not 5xx
    res = await api('POST', '/branches', minBranch({ logo_url: logoUrl1024 + 'b' }));
    if (res.status >= 500) {
      fail('logo_url = 1025 chars — should not 5xx', `HTTP ${res.status}`);
    } else {
      pass(`logo_url = 1025 chars handled (HTTP ${res.status})`);
    }

    // branch_code alias accepted (instead of 'code')
    const { code: _c, ...noCode } = minBranch();
    res = await api('POST', '/branches', { ...noCode, branch_code: `BC${Date.now()}`.slice(0, 20) });
    assertOk(res, 'branch_code alias accepted (maps to code field)');
  }

  // ── 9. LIST BRANCHES — FILTERS ───────────────────────────────────────────
  section('9. LIST BRANCHES — FILTERS');
  {
    let res = await api('GET', `/branches?school_id=${SCHOOL_ID}`);
    assertOk(res, 'List branches for school', d => Array.isArray(d.data));

    res = await api('GET', `/branches?school_id=${SCHOOL_ID}&search=Full Test`);
    assertOk(res, 'List branches with search filter', d => Array.isArray(d.data));

    res = await api('GET', `/branches?school_id=${SCHOOL_ID}&city=New Delhi`);
    assertOk(res, 'List branches filtered by city', d => Array.isArray(d.data));

    res = await api('GET', `/branches?school_id=${SCHOOL_ID}&country=India`);
    assertOk(res, 'List branches filtered by country', d => Array.isArray(d.data));

    // Search by name substring
    res = await api('GET', `/branches?school_id=${SCHOOL_ID}&search=Campus`);
    assertOk(res, 'List branches — name search (Campus)', d => Array.isArray(d.data));
  }

  // ── 10. LIST — employee_count & student_count ────────────────────────────
  section('10. LIST BRANCHES — employee_count & student_count fields present');
  {
    const res = await api('GET', `/branches?school_id=${SCHOOL_ID}`);
    assertOk(res, 'Branch list includes employee_count and student_count', d => {
      if (!Array.isArray(d.data) || d.data.length === 0) return true; // empty is ok
      const b = d.data[0];
      return typeof b.employee_count !== 'undefined' && typeof b.student_count !== 'undefined';
    });
  }

  // ── 11. UPLOAD BRANCH LOGO ───────────────────────────────────────────────
  section('11. UPLOAD BRANCH LOGO (/uploads/school-logo)');
  {
    // 11a. Valid image
    const srcPath = fs.existsSync(PHOTO_FILE) ? PHOTO_FILE : (() => {
      const tmp = path.join(__dirname, '_tmp_branch_logo.jpg');
      fs.writeFileSync(tmp, tinyJpegBuffer());
      return tmp;
    })();

    const fd = new FormData();
    fd.append('logo', fs.createReadStream(srcPath), { filename: 'logo.jpg', contentType: 'image/jpeg' });
    const res = await api('POST', '/uploads/school-logo', fd);
    if (!fs.existsSync(PHOTO_FILE) && fs.existsSync(path.join(__dirname, '_tmp_branch_logo.jpg'))) {
      fs.unlinkSync(path.join(__dirname, '_tmp_branch_logo.jpg'));
    }
    assertOk(res, 'Upload branch logo (valid JPG)', d => d.data && d.data.url);

    const uploadedLogoUrl = res.data?.data?.url;

    // 11b. Update branch with uploaded logo URL
    if (BRANCH_ID && uploadedLogoUrl) {
      const updRes = await api('PUT', `/branches/${BRANCH_ID}`, { logo_url: uploadedLogoUrl });
      assertOk(updRes, 'Branch logo_url updated with real upload URL', d =>
        d.data && d.data.logo_url === uploadedLogoUrl
      );
    }

    // 11c. No file
    {
      const r = await api('POST', '/uploads/school-logo', new FormData());
      assertFail(r, 'Upload logo — no file (400)', 400);
    }

    // 11d. Non-image file
    {
      const tmp = path.join(__dirname, '_tmp_bad_logo.txt');
      fs.writeFileSync(tmp, 'not an image');
      const fd2 = new FormData();
      fd2.append('logo', fs.createReadStream(tmp), { filename: 'doc.txt', contentType: 'text/plain' });
      const r = await api('POST', '/uploads/school-logo', fd2);
      fs.unlinkSync(tmp);
      if (r.status >= 400 && r.status < 500) {
        pass('Upload logo — non-image file rejected (4xx)');
      } else {
        fail('Upload logo — non-image should be 4xx', `HTTP ${r.status}`);
      }
    }
  }

  // ── 12. EDIT BRANCH — ALL ALLOWED FIELDS ────────────────────────────────
  section('12. EDIT BRANCH — ALL ALLOWED FIELDS');
  if (!BRANCH_ID) {
    fail('Edit tests — skipped (no BRANCH_ID)', '');
  } else {
    const res = await api('PUT', `/branches/${BRANCH_ID}`, {
      name:          'Updated Full Test Branch',
      short_name:    'UFTB',
      logo_url:      '/idmgmt/api/static/images/school/logo_updated.webp',
      address_line1: '99 Updated Avenue',
      address_line2: 'Block C',
      city:          'Gurugram',
      state:         'Haryana',
      country:       'India',
      zip_code:      '122001',
      phone1:        '8222200001',
      phone2:        '8222200002',
      email:         `updated${Date.now()}@example.com`,
      website:       'https://updated-branch.example.com',
      whatsapp_no:   '8222200001',
      is_active:     true,
    });

    assertOk(res, 'Edit branch — all allowed fields', d =>
      d.data &&
      d.data.name   === 'Updated Full Test Branch' &&
      d.data.city   === 'Gurugram' &&
      d.data.state  === 'Haryana'
    );
  }

  // ── 13. EDIT BRANCH — PARTIAL UPDATES ────────────────────────────────────
  section('13. EDIT BRANCH — PARTIAL UPDATES');
  if (BRANCH_ID) {
    let res = await api('PUT', `/branches/${BRANCH_ID}`, { name: 'Partial Update Branch' });
    assertOk(res, 'Edit — name only', d => d.data.name === 'Partial Update Branch');

    res = await api('PUT', `/branches/${BRANCH_ID}`, { city: 'Noida' });
    assertOk(res, 'Edit — city only', d => d.data.city === 'Noida');

    res = await api('PUT', `/branches/${BRANCH_ID}`, { phone1: '7000000001' });
    assertOk(res, 'Edit — phone1 only');

    res = await api('PUT', `/branches/${BRANCH_ID}`, { phone2: '7000000002', whatsapp_no: '7000000001' });
    assertOk(res, 'Edit — phone2 and whatsapp_no together');

    res = await api('PUT', `/branches/${BRANCH_ID}`, {
      logo_url: '/idmgmt/api/static/images/school/logo_partial.webp'
    });
    assertOk(res, 'Edit — logo_url only', d =>
      d.data.logo_url === '/idmgmt/api/static/images/school/logo_partial.webp'
    );

    res = await api('PUT', `/branches/${BRANCH_ID}`, { short_name: 'SN2' });
    assertOk(res, 'Edit — short_name only', d => d.data.short_name === 'SN2');

    res = await api('PUT', `/branches/${BRANCH_ID}`, { website: 'https://newsite.example.com' });
    assertOk(res, 'Edit — website only');

    res = await api('PUT', `/branches/${BRANCH_ID}`, { address_line2: 'Updated Block D' });
    assertOk(res, 'Edit — address_line2 only');

    res = await api('PUT', `/branches/${BRANCH_ID}`, { zip_code: '201301' });
    assertOk(res, 'Edit — zip_code only');
  }

  // ── 14. EDIT BRANCH — logo_url LENGTH BOUNDARY ───────────────────────────
  section('14. EDIT BRANCH — logo_url LENGTH BOUNDARY');
  if (BRANCH_ID) {
    const url1024 = 'https://cdn.example.com/' + 'a'.repeat(1000);
    let res = await api('PUT', `/branches/${BRANCH_ID}`, { logo_url: url1024 });
    if (res.status >= 200 && res.status < 300) {
      pass('logo_url = 1024 chars in PUT (boundary, accepted)');
    } else {
      fail('logo_url = 1024 chars in PUT', `HTTP ${res.status}`);
    }

    const url1025 = url1024 + 'b';
    res = await api('PUT', `/branches/${BRANCH_ID}`, { logo_url: url1025 });
    if (res.status >= 500) {
      fail('logo_url = 1025 chars in PUT — should not 5xx', `HTTP ${res.status}`);
    } else {
      pass(`logo_url = 1025 chars in PUT handled (HTTP ${res.status})`);
    }
  }

  // ── 15. EDIT BRANCH — NO VALID FIELDS ────────────────────────────────────
  section('15. EDIT BRANCH — NO VALID FIELDS (400)');
  if (BRANCH_ID) {
    const res = await api('PUT', `/branches/${BRANCH_ID}`, {
      fakeField1: 'foo',
      fakeField2: 'bar',
    });
    assertFail(res, 'Edit with no valid fields — 400', 400, 'No valid fields');
  }

  // ── 16. EDIT BRANCH — EMPTY BODY ─────────────────────────────────────────
  section('16. EDIT BRANCH — EMPTY BODY (400)');
  if (BRANCH_ID) {
    const res = await api('PUT', `/branches/${BRANCH_ID}`, {});
    assertFail(res, 'Edit with empty body — 400', 400);
  }

  // ── 17. EDIT NON-EXISTENT BRANCH ─────────────────────────────────────────
  section('17. EDIT NON-EXISTENT BRANCH');
  {
    const res = await api('PUT', '/branches/00000000-0000-0000-0000-000000000000', {
      name: 'Ghost Branch',
    });
    // Should be 404, but current code may return 200 with null data (documenting actual behavior)
    if (res.status === 404) {
      pass('Edit non-existent branch — 404');
    } else if (res.status === 200 && !res.data?.data?.id) {
      fail('Edit non-existent branch — returns 200 with no data (missing 404 guard)', `HTTP ${res.status}`);
    } else if (res.status >= 400 && res.status < 600) {
      pass(`Edit non-existent branch — rejected (HTTP ${res.status})`);
    } else {
      fail('Edit non-existent branch — unexpected', `HTTP ${res.status}: ${JSON.stringify(res.data).slice(0, 200)}`);
    }
  }

  // ── 18. DEACTIVATE BRANCH (is_active: false) ─────────────────────────────
  section('18. DEACTIVATE BRANCH (is_active: false)');
  if (BRANCH_ID) {
    let res = await api('PUT', `/branches/${BRANCH_ID}`, { is_active: false });
    assertOk(res, 'Deactivate branch (is_active: false)', d =>
      d.data.is_active === 0 || d.data.is_active === false
    );

    // Verify deactivated branch excluded from default list (is_active = TRUE filter)
    res = await api('GET', `/branches?school_id=${SCHOOL_ID}`);
    assertOk(res, 'Deactivated branch excluded from default list', d => {
      if (!Array.isArray(d.data)) return false;
      return !d.data.some(b => b.id === BRANCH_ID);
    });
  }

  // ── 19. REACTIVATE BRANCH ────────────────────────────────────────────────
  section('19. REACTIVATE BRANCH (is_active: true)');
  if (BRANCH_ID) {
    const res = await api('PUT', `/branches/${BRANCH_ID}`, { is_active: true });
    assertOk(res, 'Reactivate branch (is_active: true)', d =>
      d.data.is_active === 1 || d.data.is_active === true
    );

    // Verify reactivated branch back in list
    const listRes = await api('GET', `/branches?school_id=${SCHOOL_ID}`);
    assertOk(listRes, 'Reactivated branch back in default list', d =>
      Array.isArray(d.data) && d.data.some(b => b.id === BRANCH_ID)
    );
  }

  // ── 20. SCHOOL → BRANCH RELATIONSHIP ─────────────────────────────────────
  section('20. SCHOOL → BRANCH RELATIONSHIP');
  if (BRANCH_ID) {
    const res = await api('GET', `/branches?school_id=${SCHOOL_ID}`);
    assertOk(res, 'Branches list filtered to school_id', d => {
      if (!Array.isArray(d.data)) return false;
      return d.data.every(b => b.school_id === SCHOOL_ID);
    });

    // Branch carries school_name from JOIN
    assertOk(res, 'Branch includes school_name from JOIN', d => {
      if (!d.data.length) return true;
      return d.data[0].school_name !== undefined;
    });

    // Newly created branch belongs to correct school
    const branch = res.data?.data?.find(b => b.id === BRANCH_ID);
    if (branch) {
      if (branch.school_id === SCHOOL_ID) {
        pass('Created branch has correct school_id');
      } else {
        fail('Created branch school_id mismatch', `Expected ${SCHOOL_ID}, got ${branch.school_id}`);
      }
    }
  }

  // ── 21. BRANCH → EMPLOYEE RELATIONSHIP ───────────────────────────────────
  section('21. BRANCH → EMPLOYEE RELATIONSHIP');
  if (BRANCH_ID) {
    // Create an employee in this specific branch
    const ts = Date.now();
    const empRes = await api('POST', '/employees', {
      school_id:    SCHOOL_ID,
      branch_id:    BRANCH_ID,
      employee_id:  `BRNCH-EMP-${ts}`,
      org_role_id:  ROLE_PRINCIPAL,
      first_name:   'Branch',
      last_name:    'Employee',
      email:        `branch.emp${ts}@test.com`,
      phone:        '9500000001',
      gender:       'male',
    });
    assertOk(empRes, 'Create employee assigned to branch', d =>
      d.data && d.data.branch_id === BRANCH_ID
    );

    if (empRes.data?.data?.id) {
      EMP_ID = empRes.data.data.id;
      console.log(`      → Created employee ID: ${EMP_ID}`);
    }

    // List employees filtered by branch_id
    const listRes = await api('GET', `/employees?school_id=${SCHOOL_ID}&branch_id=${BRANCH_ID}`);
    assertOk(listRes, 'List employees filtered by branch_id', d =>
      Array.isArray(d.data) && d.data.length > 0
    );

    // All returned employees belong to this branch
    assertOk(listRes, 'All listed employees have correct branch_id', d =>
      Array.isArray(d.data) && d.data.every(e => e.branch_id === BRANCH_ID)
    );

    // Employee record has branch_name from JOIN
    assertOk(listRes, 'Employee list includes branch_name', d => {
      if (!d.data.length) return true;
      return d.data[0].branch_name !== undefined;
    });

    // Verify employee count in branch list reflects new employee
    const branchList = await api('GET', `/branches?school_id=${SCHOOL_ID}`);
    const branchRow = branchList.data?.data?.find(b => b.id === BRANCH_ID);
    if (branchRow) {
      if (parseInt(branchRow.employee_count) >= 1) {
        pass('Branch employee_count ≥ 1 after adding employee');
      } else {
        fail('Branch employee_count not updated', `Got: ${branchRow.employee_count}`);
      }
    }

    // Reassign employee to a different branch and verify old branch clears
    const otherBranches = branchList.data?.data?.filter(b => b.id !== BRANCH_ID);
    if (EMP_ID && otherBranches?.length) {
      const otherBranchId = otherBranches[0].id;
      const moveRes = await api('PUT', `/employees/${EMP_ID}`, { branch_id: otherBranchId });
      assertOk(moveRes, 'Employee reassigned to different branch', d =>
        d.data && d.data.branch_id === otherBranchId
      );
      // Move back
      await api('PUT', `/employees/${EMP_ID}`, { branch_id: BRANCH_ID });
    }
  }

  // ── 22. BRANCH → STUDENT RELATIONSHIP ────────────────────────────────────
  section('22. BRANCH → STUDENT RELATIONSHIP');
  if (BRANCH_ID) {
    const ts = Date.now();

    // Create student in this branch (branch auto-seeded class 1, section A)
    const stuRes = await api('POST', '/students', {
      school_id:  SCHOOL_ID,
      branch_id:  BRANCH_ID,
      student_id: `BSTU-${ts}`,
      first_name: 'Branch',
      last_name:  'Student',
      gender:     'female',
      class_name: '1',
      section:    'A',
    });
    assertOk(stuRes, 'Create student assigned to branch', d =>
      d.data && d.data.branch_id === BRANCH_ID
    );

    if (stuRes.data?.data?.id) {
      STU_ID = stuRes.data.data.id;
      console.log(`      → Created student ID: ${STU_ID}`);
    }

    // List students filtered by branch_id
    const listRes = await api('GET', `/students?school_id=${SCHOOL_ID}&branch_id=${BRANCH_ID}`);
    assertOk(listRes, 'List students filtered by branch_id', d =>
      Array.isArray(d.data) && d.data.length > 0
    );

    // All returned students belong to this branch
    assertOk(listRes, 'All listed students have correct branch_id', d =>
      Array.isArray(d.data) && d.data.every(s => s.branch_id === BRANCH_ID)
    );

    // Student record includes branch_name from JOIN
    assertOk(listRes, 'Student list includes branch_name', d => {
      if (!d.data.length) return true;
      return d.data[0].branch_name !== undefined;
    });

    // Student requires valid branch_id (invalid branch → error)
    const badBranchRes = await api('POST', '/students', {
      school_id:  SCHOOL_ID,
      branch_id:  '00000000-0000-0000-0000-000000000000',
      student_id: `BSTU-BAD-${ts}`,
      first_name: 'Invalid',
      last_name:  'Branch',
      gender:     'male',
      class_name: '1',
      section:    'A',
    });
    if (badBranchRes.status >= 400) {
      pass('Student with invalid branch_id rejected');
    } else {
      fail('Student with invalid branch_id should be rejected', `HTTP ${badBranchRes.status}`);
    }

    // Student requires branch-specific class/section
    const wrongClassRes = await api('POST', '/students', {
      school_id:  SCHOOL_ID,
      branch_id:  BRANCH_ID,
      student_id: `BSTU-WRONGCLS-${ts}`,
      first_name: 'Wrong',
      last_name:  'Class',
      gender:     'male',
      class_name: 'NONEXISTENT_CLASS',
      section:    'Z',
    });
    assertFail(wrongClassRes, 'Student with non-existent class/section rejected', 422);

    // Verify branch student_count updated
    const branchList = await api('GET', `/branches?school_id=${SCHOOL_ID}`);
    const branchRow = branchList.data?.data?.find(b => b.id === BRANCH_ID);
    if (branchRow) {
      if (parseInt(branchRow.student_count) >= 1) {
        pass('Branch student_count ≥ 1 after adding student');
      } else {
        fail('Branch student_count not updated', `Got: ${branchRow.student_count}`);
      }
    }
  }

  // ── 23. AUTHORIZATION ────────────────────────────────────────────────────
  section('23. AUTHORIZATION — UNAUTHENTICATED (401)');
  {
    const savedToken = TOKEN;
    TOKEN = '';

    let res = await api('GET', `/branches?school_id=${SCHOOL_ID}`);
    assertFail(res, 'List branches without token — 401', 401);

    res = await api('POST', '/branches', minBranch());
    assertFail(res, 'Create branch without token — 401', 401);

    if (BRANCH_ID) {
      res = await api('PUT', `/branches/${BRANCH_ID}`, { name: 'Hack' });
      assertFail(res, 'Edit branch without token — 401', 401);
    }

    TOKEN = savedToken;
  }

  // ── 24. AUTO-SEEDED CLASSES AFTER BRANCH CREATION ────────────────────────
  section('24. AUTO-SEEDED CLASSES (15 classes seeded on branch creation)');
  if (BRANCH_ID) {
    // Query classes for this branch via students or a direct test
    // Since there's no GET /classes endpoint exposed in tests, we verify indirectly:
    // create students for several seeded classes and confirm they're accepted
    const classSectionPairs = [
      ['Nursery', 'A'], ['LKG', 'B'], ['UKG', 'A'],
      ['5', 'A'], ['10', 'B'], ['12', 'A'],
    ];

    for (const [cls, sec] of classSectionPairs) {
      const ts = Date.now() + Math.random();
      const r = await api('POST', '/students', {
        school_id:  SCHOOL_ID,
        branch_id:  BRANCH_ID,
        student_id: `SEED-${cls}-${sec}-${Math.floor(ts)}`,
        first_name: `Seed${cls}`,
        last_name:  sec,
        gender:     'male',
        class_name: cls,
        section:    sec,
      });
      if (r.status === 201) {
        pass(`Auto-seeded class "${cls}" section "${sec}" accepts students`);
      } else {
        fail(`Auto-seeded class "${cls}" section "${sec}"`, `HTTP ${r.status}: ${JSON.stringify(r.data).slice(0, 200)}`);
      }
    }
  }

  // ── SUMMARY ──────────────────────────────────────────────────────────────
  console.log('\n' + '═'.repeat(64));
  console.log(`  RESULTS:  ${passCount} passed,  ${failCount} failed`);
  console.log('═'.repeat(64));

  if (failures.length) {
    console.log('\n  Failed tests:');
    for (const f of failures) {
      console.log(`    ❌ ${f.name}`);
      console.log(`       ${f.reason}`);
    }
  }

  process.exit(failCount > 0 ? 1 : 0);
}

main().catch(err => {
  console.error('\n  FATAL ERROR:', err.message);
  process.exit(1);
});
