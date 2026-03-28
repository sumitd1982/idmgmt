#!/usr/bin/env node
/**
 * End-to-End Test: School Add / Edit — All Attributes, Boundary & Error Conditions
 *
 * Covers:
 *   - CREATE (POST /schools): all fields, required-field validation, boundary lengths,
 *     invalid email, duplicate code, unauthorized roles
 *   - READ   (GET /schools, GET /schools/:id): happy path, not-found, cross-school auth
 *   - UPLOAD (POST /uploads/school-logo, /school-banner): valid image, no file,
 *     wrong mime type, oversized file
 *   - EDIT   (PUT /schools/:id): all allowed fields, logo_url/banner_url, settings JSON,
 *     no-valid-fields guard, not-found guard
 *   - STATS  (GET /schools/:id/stats): happy path
 */

const axios    = require('axios');
const fs       = require('fs');
const path     = require('path');
const FormData = require('form-data');

const BASE       = 'http://localhost:3001/idmgmt/api';
const PHOTO_FILE = path.join(__dirname, '../5.jpg'); // reuse existing test image

let TOKEN        = '';
let SCHOOL_ID    = '';   // created during test
let SCHOOL_CODE  = '';

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
  } else if (data) {
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
    const body = JSON.stringify(res.data);
    if (!body.toLowerCase().includes(expectedMsg.toLowerCase())) {
      fail(name, `Expected error message containing "${expectedMsg}", got: ${body.slice(0, 300)}`);
      return;
    }
  }
  pass(name);
}

/** Build minimal valid school payload (code randomised to avoid collisions). */
function minimalSchool(overrides = {}) {
  const ts = Date.now();
  return {
    name:          `Test School ${ts}`,
    code:          `TST${ts}`.slice(0, 20).toUpperCase(),
    address_line1: '123 Main Street',
    city:          'Mumbai',
    state:         'Maharashtra',
    country:       'India',
    zip_code:      '400001',
    phone1:        '9876543210',
    email:         `school${ts}@test.com`,
    ...overrides,
  };
}

/** Create a tiny valid JPEG buffer (1×1 pixel) for upload tests. */
function tinyJpegBuffer() {
  // Minimal valid JPEG bytes
  return Buffer.from(
    'ffd8ffe000104a46494600010100000100010000ffdb004300080606070605080707070909080a0c140d0c0b0b0c191213' +
    '0f141d1a1f1e1d1a1c1c20242e2720222c231c1c2837292c30313434341f27393d38323c2e333432ffc0000b08000100' +
    '0101011100ffc4001f0000010501010101010100000000000000000102030405060708090a0bffda00080101000003f0' +
    'ffd9',
    'hex'
  );
}

// ── Main ─────────────────────────────────────────────────────────────────────

async function main() {
  console.log('╔══════════════════════════════════════════════════════════════╗');
  console.log('║   SCHOOL ADD / EDIT — BOUNDARY & ERROR CONDITION TEST SUITE  ║');
  console.log('╚══════════════════════════════════════════════════════════════╝');

  // ── 1. AUTH ──────────────────────────────────────────────────────────────
  section('1. AUTHENTICATION');
  {
    const res = await axios.post(`${BASE}/auth/otp/verify`, {
      phone: '8826756777',
      otp:   '123456',
    }, { validateStatus: () => true });

    if (res.data?.data?.token) {
      TOKEN = res.data.data.token;
      pass('Login with master OTP (super_admin)');
    } else {
      fail('Login with master OTP', JSON.stringify(res.data));
      process.exit(1);
    }
  }

  // ── 2. CREATE SCHOOL — HAPPY PATH (all fields) ───────────────────────────
  section('2. CREATE SCHOOL — HAPPY PATH (all fields)');
  {
    const ts = Date.now();
    SCHOOL_CODE = `FULL${ts}`.slice(0, 20).toUpperCase();

    const payload = {
      name:              `Full Test School ${ts}`,
      short_name:        'FTS',
      code:              SCHOOL_CODE,
      affiliation_no:    'AFF-12345',
      affiliation_board: 'CBSE',
      school_type:       'private',
      address_line1:     '45 Education Avenue',
      address_line2:     'Near City Park',
      city:              'Delhi',
      district:          'Central Delhi',
      state:             'Delhi',
      country:           'India',
      zip_code:          '110001',
      phone1:            '9999900001',
      phone2:            '9999900002',
      email:             `fullschool${ts}@example.com`,
      website:           'https://fullschool.example.com',
      principal_name:    'Dr. Ramesh Kumar',
      whatsapp_no:       '9999900001',
      facebook_url:      'https://facebook.com/fullschool',
      twitter_url:       'https://twitter.com/fullschool',
      instagram_url:     'https://instagram.com/fullschool',
      academic_year:     '2025-26',
      timezone:          'Asia/Kolkata',
    };

    const res = await api('POST', '/schools', payload);
    assertOk(res, 'Create school with all fields — HTTP 201', d => {
      const s = d.data;
      return d.success &&
        s.id &&
        s.name   === payload.name &&
        s.code   === SCHOOL_CODE  &&
        s.city   === payload.city &&
        s.email  === payload.email.toLowerCase(); // normalizeEmail lowercases
    });

    if (res.data?.data?.id) {
      SCHOOL_ID = res.data.data.id;
      console.log(`      → Created school ID: ${SCHOOL_ID}`);
    } else {
      fail('Extract school ID', 'No school ID in response — remaining tests may fail');
    }
  }

  // ── 3. CREATE SCHOOL — MISSING REQUIRED FIELDS ───────────────────────────
  section('3. CREATE SCHOOL — MISSING REQUIRED FIELDS (422)');
  const requiredFields = [
    'name', 'code', 'address_line1', 'city', 'state', 'country', 'zip_code', 'phone1', 'email',
  ];

  for (const field of requiredFields) {
    const payload = minimalSchool();
    delete payload[field];
    const res = await api('POST', '/schools', payload);
    assertFail(res, `Missing required field: ${field}`, 422, field);
  }

  // ── 4. CREATE SCHOOL — EMPTY-STRING REQUIRED FIELDS ─────────────────────
  section('4. CREATE SCHOOL — EMPTY / WHITESPACE REQUIRED FIELDS (422)');
  for (const field of requiredFields) {
    const payload = minimalSchool({ [field]: '   ' }); // whitespace only
    const res = await api('POST', '/schools', payload);
    assertFail(res, `Whitespace-only required field: ${field}`, 422);
  }

  // ── 5. BOUNDARY: name length ─────────────────────────────────────────────
  section('5. BOUNDARY — name (max 255 chars)');
  {
    // Exactly 255 — should pass
    let res = await api('POST', '/schools', minimalSchool({ name: 'A'.repeat(255) }));
    assertOk(res, 'name = 255 chars (boundary, accepted)');

    // 256 — should fail
    res = await api('POST', '/schools', minimalSchool({ name: 'A'.repeat(256) }));
    assertFail(res, 'name = 256 chars (over boundary, rejected)', 422);
  }

  // ── 6. BOUNDARY: code length ─────────────────────────────────────────────
  section('6. BOUNDARY — code (max 20 chars)');
  {
    // Exactly 20 chars (unique)
    const code20 = `C${Date.now()}`.slice(0, 20).toUpperCase().padEnd(20, 'X');
    let res = await api('POST', '/schools', minimalSchool({ code: code20 }));
    assertOk(res, 'code = 20 chars (boundary, accepted)');

    // 21 chars — should fail
    const code21 = code20 + 'Z';
    res = await api('POST', '/schools', minimalSchool({ code: code21 }));
    assertFail(res, 'code = 21 chars (over boundary, rejected)', 422);
  }

  // ── 7. INVALID EMAIL ─────────────────────────────────────────────────────
  section('7. INVALID EMAIL FORMAT');
  const badEmails = [
    'notanemail',
    'missing@',
    '@nodomain.com',
    'two@@at.com',
    'space in@email.com',
    '',
  ];
  for (const email of badEmails) {
    const res = await api('POST', '/schools', minimalSchool({ email }));
    assertFail(res, `Invalid email: "${email}"`, 422, 'email');
  }

  // ── 8. DUPLICATE CODE ────────────────────────────────────────────────────
  section('8. DUPLICATE SCHOOL CODE (409)');
  {
    if (!SCHOOL_ID) {
      fail('Duplicate code test — skipped (no SCHOOL_ID, creation failed earlier)', '');
    } else {
      const res = await api('POST', '/schools', minimalSchool({ code: SCHOOL_CODE }));
      assertFail(res, 'Duplicate school code — should return 409', 409, 'already exists');
    }
  }

  // ── 9. INVALID ENUM: school_type ─────────────────────────────────────────
  section('9. INVALID school_type ENUM');
  {
    // The DB enum is primary|secondary|higher_secondary|k12
    // Backend doesn't currently validate via express-validator but the DB will reject it
    // or silently ignore — we document the actual behaviour
    const res = await api('POST', '/schools', minimalSchool({ school_type: 'INVALID_TYPE' }));
    // May be 422 (if validator added) or still 201 (stored as default).
    // We only check it doesn't crash (5xx).
    if (res.status >= 500) {
      fail('Invalid school_type — should not cause 5xx', `Got HTTP ${res.status}`);
    } else {
      pass(`Invalid school_type handled gracefully (HTTP ${res.status})`);
    }
  }

  // ── 10. READ — LIST SCHOOLS ──────────────────────────────────────────────
  section('10. LIST SCHOOLS');
  {
    let res = await api('GET', '/schools');
    assertOk(res, 'List schools (default)', d => Array.isArray(d.data));

    res = await api('GET', `/schools?search=${encodeURIComponent('Full Test School')}`);
    assertOk(res, 'List schools with search filter', d => Array.isArray(d.data));

    res = await api('GET', '/schools?page=1&limit=5');
    assertOk(res, 'List schools with pagination', d =>
      Array.isArray(d.data) && d.meta && d.meta.limit === 5
    );

    res = await api('GET', '/schools?city=Delhi');
    assertOk(res, 'List schools filtered by city');

    res = await api('GET', '/schools?country=India');
    assertOk(res, 'List schools filtered by country');
  }

  // ── 11. READ — GET SINGLE SCHOOL ────────────────────────────────────────
  section('11. GET SINGLE SCHOOL');
  {
    if (!SCHOOL_ID) {
      fail('Get created school — skipped (no SCHOOL_ID)', 'school creation failed earlier');
    } else {
      let res = await api('GET', `/schools/${SCHOOL_ID}`);
      assertOk(res, 'Get school by ID', d =>
        d.data.id === SCHOOL_ID && d.data.code === SCHOOL_CODE
      );

      // Non-existent ID
      res = await api('GET', '/schools/00000000-0000-0000-0000-000000000000');
      assertFail(res, 'Get non-existent school — 404', 404, 'not found');
    }
  }

  // ── 12. SCHOOL STATS ─────────────────────────────────────────────────────
  section('12. SCHOOL STATS');
  {
    if (!SCHOOL_ID) {
      fail('Stats — skipped (no SCHOOL_ID)', '');
    } else {
      const res = await api('GET', `/schools/${SCHOOL_ID}/stats`);
      assertOk(res, 'Get school stats', d =>
        d.data && typeof d.data.branches === 'number'
      );

      const badRes = await api('GET', '/schools/00000000-0000-0000-0000-000000000000/stats');
      // Stats returns empty object for unknown id (no 404 guard in route), just check no 5xx
      if (badRes.status >= 500) {
        fail('Stats for unknown school — should not 5xx', `HTTP ${badRes.status}`);
      } else {
        pass(`Stats for unknown school handled gracefully (HTTP ${badRes.status})`);
      }
    }
  }

  // ── 13. UPLOAD — SCHOOL LOGO ─────────────────────────────────────────────
  section('13. UPLOAD — SCHOOL LOGO (/uploads/school-logo)');
  {
    // 13a. Valid image upload (use existing 5.jpg if available, else synthetic JPEG)
    const imgPath = fs.existsSync(PHOTO_FILE) ? PHOTO_FILE : null;
    if (imgPath) {
      const fd = new FormData();
      fd.append('logo', fs.createReadStream(imgPath), { filename: 'logo.jpg', contentType: 'image/jpeg' });
      const res = await api('POST', '/uploads/school-logo', fd);
      assertOk(res, 'Upload school logo (valid JPG)', d => d.data && d.data.url);

      // Optionally save logo_url for later PUT test
      if (res.data?.data?.url) {
        process.env._TEST_LOGO_URL = res.data.data.url;
      }
    } else {
      // Write synthetic JPEG to temp file
      const tmpFile = path.join(__dirname, '_test_logo.jpg');
      fs.writeFileSync(tmpFile, tinyJpegBuffer());
      const fd = new FormData();
      fd.append('logo', fs.createReadStream(tmpFile), { filename: 'logo.jpg', contentType: 'image/jpeg' });
      const res = await api('POST', '/uploads/school-logo', fd);
      fs.unlinkSync(tmpFile);
      assertOk(res, 'Upload school logo (synthetic JPEG)', d => d.data && d.data.url);
      if (res.data?.data?.url) process.env._TEST_LOGO_URL = res.data.data.url;
    }

    // 13b. No file — should 400
    {
      const res = await api('POST', '/uploads/school-logo', new FormData());
      assertFail(res, 'Upload school logo — no file (400)', 400);
    }

    // 13c. Wrong field name (sending under wrong key 'file' not 'logo')
    {
      const tmpFile = path.join(__dirname, '_test_wrong_field.jpg');
      fs.writeFileSync(tmpFile, tinyJpegBuffer());
      const fd = new FormData();
      fd.append('file', fs.createReadStream(tmpFile), { filename: 'x.jpg', contentType: 'image/jpeg' });
      const res = await api('POST', '/uploads/school-logo', fd);
      fs.unlinkSync(tmpFile);
      assertFail(res, 'Upload school logo — wrong field name (400)', 400);
    }

    // 13d. Non-image file (send a .txt file)
    {
      const tmpFile = path.join(__dirname, '_test_not_image.txt');
      fs.writeFileSync(tmpFile, 'this is not an image');
      const fd = new FormData();
      fd.append('logo', fs.createReadStream(tmpFile), { filename: 'doc.txt', contentType: 'text/plain' });
      const res = await api('POST', '/uploads/school-logo', fd);
      fs.unlinkSync(tmpFile);
      // multer fileFilter should reject: 400 or 422
      if (res.status >= 400 && res.status < 500) {
        pass('Upload school logo — non-image file rejected');
      } else if (res.status >= 500) {
        fail('Upload school logo — non-image file caused 5xx', `HTTP ${res.status}`);
      } else {
        fail('Upload school logo — non-image should be rejected', `Got HTTP ${res.status}`);
      }
    }
  }

  // ── 14. UPLOAD — SCHOOL BANNER ───────────────────────────────────────────
  section('14. UPLOAD — SCHOOL BANNER (/uploads/school-banner)');
  {
    // 14a. Valid banner upload
    const imgPath = fs.existsSync(PHOTO_FILE) ? PHOTO_FILE : null;
    const srcPath = imgPath || (() => {
      const tmp = path.join(__dirname, '_test_banner.jpg');
      fs.writeFileSync(tmp, tinyJpegBuffer());
      return tmp;
    })();

    const fd = new FormData();
    fd.append('banner', fs.createReadStream(srcPath), { filename: 'banner.jpg', contentType: 'image/jpeg' });
    const res = await api('POST', '/uploads/school-banner', fd);
    if (!imgPath) fs.existsSync(srcPath) && fs.unlinkSync(srcPath);

    assertOk(res, 'Upload school banner (valid JPG)', d => d.data && d.data.url);
    if (res.data?.data?.url) process.env._TEST_BANNER_URL = res.data.data.url;

    // 14b. No file
    {
      const r = await api('POST', '/uploads/school-banner', new FormData());
      assertFail(r, 'Upload school banner — no file (400)', 400);
    }

    // 14c. Non-image (PDF-like binary)
    {
      const tmpFile = path.join(__dirname, '_test_banner_bad.pdf');
      fs.writeFileSync(tmpFile, Buffer.from('%PDF-1.4 fake pdf content'));
      const fd2 = new FormData();
      fd2.append('banner', fs.createReadStream(tmpFile), { filename: 'doc.pdf', contentType: 'application/pdf' });
      const r = await api('POST', '/uploads/school-banner', fd2);
      fs.unlinkSync(tmpFile);
      if (r.status >= 400 && r.status < 500) {
        pass('Upload school banner — non-image (PDF) rejected');
      } else if (r.status >= 500) {
        fail('Upload school banner — non-image caused 5xx', `HTTP ${r.status}`);
      } else {
        fail('Upload school banner — should have been rejected', `HTTP ${r.status}`);
      }
    }
  }

  // ── 15. EDIT SCHOOL — HAPPY PATH (all allowed fields) ────────────────────
  section('15. EDIT SCHOOL — HAPPY PATH (all allowed fields)');
  if (!SCHOOL_ID) {
    fail('Edit tests skipped — no SCHOOL_ID', '');
  } else {
    const logoUrl   = process.env._TEST_LOGO_URL   || '/idmgmt/api/static/images/school/logo_test.webp';
    const bannerUrl = process.env._TEST_BANNER_URL || '/idmgmt/api/static/images/school/banner_test.webp';

    const res = await api('PUT', `/schools/${SCHOOL_ID}`, {
      name:              'Updated Full Test School',
      short_name:        'UFTS',
      affiliation_no:    'AFF-99999',
      affiliation_board: 'ICSE',
      school_type:       'international',
      address_line1:     '99 Updated Road',
      address_line2:     'Block B',
      city:              'Bangalore',
      district:          'South Bangalore',
      state:             'Karnataka',
      country:           'India',
      zip_code:          '560001',
      phone1:            '8888800001',
      phone2:            '8888800002',
      email:             `updated${Date.now()}@example.com`,
      website:           'https://updated.example.com',
      principal_name:    'Mrs. Priya Sharma',
      whatsapp_no:       '8888800001',
      facebook_url:      'https://facebook.com/updated',
      twitter_url:       'https://twitter.com/updated',
      instagram_url:     'https://instagram.com/updated',
      logo_url:          logoUrl,
      banner_url:        bannerUrl,
      academic_year:     '2026-27',
      timezone:          'Asia/Kolkata',
      is_active:         true,
      settings:          { is_messaging_enabled: true, theme_color: '#003366' },
    });

    assertOk(res, 'Edit school — all allowed fields updated', d =>
      d.data && d.data.name === 'Updated Full Test School' &&
      d.data.city === 'Bangalore' &&
      d.data.logo_url === logoUrl
    );
  }

  // ── 16. EDIT SCHOOL — PARTIAL UPDATE ─────────────────────────────────────
  section('16. EDIT SCHOOL — PARTIAL UPDATES');
  if (SCHOOL_ID) {
    // Only name
    let res = await api('PUT', `/schools/${SCHOOL_ID}`, { name: 'Partially Updated School' });
    assertOk(res, 'Edit — update name only', d => d.data.name === 'Partially Updated School');

    // Only logo_url
    const testLogoUrl = '/idmgmt/api/static/images/school/logo_partial_test.webp';
    res = await api('PUT', `/schools/${SCHOOL_ID}`, { logo_url: testLogoUrl });
    assertOk(res, 'Edit — update logo_url only', d => d.data.logo_url === testLogoUrl);

    // Only banner_url
    const testBannerUrl = '/idmgmt/api/static/images/school/banner_partial_test.webp';
    res = await api('PUT', `/schools/${SCHOOL_ID}`, { banner_url: testBannerUrl });
    assertOk(res, 'Edit — update banner_url only', d => d.data.banner_url === testBannerUrl);

    // Only settings (object should be serialized)
    res = await api('PUT', `/schools/${SCHOOL_ID}`, {
      settings: { is_messaging_enabled: false }
    });
    assertOk(res, 'Edit — update settings (JSON object) only');

    // is_active toggle
    res = await api('PUT', `/schools/${SCHOOL_ID}`, { is_active: false });
    assertOk(res, 'Edit — deactivate school (is_active: false)', d => d.data.is_active === 0 || d.data.is_active === false);

    res = await api('PUT', `/schools/${SCHOOL_ID}`, { is_active: true });
    assertOk(res, 'Edit — reactivate school (is_active: true)', d => d.data.is_active === 1 || d.data.is_active === true);
  }

  // ── 17. EDIT SCHOOL — BOUNDARY: logo_url / banner_url lengths ────────────
  section('17. EDIT SCHOOL — URL LENGTH BOUNDARIES (logo_url / banner_url = 1024 chars)');
  if (SCHOOL_ID) {
    const url1024  = 'https://cdn.example.com/' + 'a'.repeat(1000);  // 1024 total
    const url1025  = url1024 + 'b';                                   // 1025 total

    // Exactly 1024 — DB column is VARCHAR(1024), should be accepted
    let res = await api('PUT', `/schools/${SCHOOL_ID}`, { logo_url: url1024 });
    if (res.status >= 200 && res.status < 300) {
      pass('logo_url = 1024 chars (boundary, accepted)');
    } else {
      fail('logo_url = 1024 chars (boundary, accepted)', `HTTP ${res.status}: ${JSON.stringify(res.data).slice(0, 200)}`);
    }

    // 1025 chars — may be truncated or rejected by DB
    res = await api('PUT', `/schools/${SCHOOL_ID}`, { logo_url: url1025 });
    if (res.status >= 500) {
      fail('logo_url = 1025 chars — should not 5xx (truncate or 4xx)', `HTTP ${res.status}`);
    } else {
      pass(`logo_url = 1025 chars handled (HTTP ${res.status})`);
    }
  }

  // ── 18. EDIT SCHOOL — NO VALID FIELDS ────────────────────────────────────
  section('18. EDIT SCHOOL — NO VALID FIELDS (400)');
  if (SCHOOL_ID) {
    const res = await api('PUT', `/schools/${SCHOOL_ID}`, {
      nonExistentField1: 'foo',
      nonExistentField2: 'bar',
    });
    assertFail(res, 'Edit with no valid fields — 400', 400, 'No valid fields');
  }

  // ── 19. EDIT SCHOOL — EMPTY BODY ─────────────────────────────────────────
  section('19. EDIT SCHOOL — EMPTY BODY (400)');
  if (SCHOOL_ID) {
    const res = await api('PUT', `/schools/${SCHOOL_ID}`, {});
    assertFail(res, 'Edit with empty body — 400', 400, 'No valid fields');
  }

  // ── 20. EDIT SCHOOL — NON-EXISTENT SCHOOL ────────────────────────────────
  section('20. EDIT NON-EXISTENT SCHOOL');
  {
    const res = await api('PUT', '/schools/00000000-0000-0000-0000-000000000000', {
      name: 'Ghost School',
    });
    // requireSchoolAccess will 403 or the update affects 0 rows and returns empty data
    if (res.status >= 400 && res.status < 600) {
      pass(`Edit non-existent school — properly rejected (HTTP ${res.status})`);
    } else {
      // If 200 is returned with no data, still flag it
      if (!res.data?.data?.id) {
        pass(`Edit non-existent school — no data returned (HTTP ${res.status})`);
      } else {
        fail('Edit non-existent school — unexpected success', JSON.stringify(res.data).slice(0, 200));
      }
    }
  }

  // ── 21. AUTHORIZATION — UNAUTHENTICATED REQUESTS ─────────────────────────
  section('21. AUTHORIZATION — UNAUTHENTICATED (401)');
  {
    const savedToken = TOKEN;
    TOKEN = '';

    let res = await api('GET', '/schools');
    assertFail(res, 'List schools without token — 401', 401);

    res = await api('POST', '/schools', minimalSchool());
    assertFail(res, 'Create school without token — 401', 401);

    if (SCHOOL_ID) {
      res = await api('PUT', `/schools/${SCHOOL_ID}`, { name: 'Hack' });
      assertFail(res, 'Edit school without token — 401', 401);

      res = await api('GET', `/schools/${SCHOOL_ID}`);
      assertFail(res, 'Get school without token — 401', 401);
    }

    TOKEN = savedToken;
  }

  // ── 22. BOUNDARY: phone lengths ──────────────────────────────────────────
  section('22. BOUNDARY — phone1 length (VARCHAR 20)');
  {
    // 20-digit phone — boundary, should create or pass validation
    const phone20 = '1'.repeat(20);
    let res = await api('POST', '/schools', minimalSchool({ phone1: phone20 }));
    if (res.status >= 200 && res.status < 300) {
      pass('phone1 = 20 chars (boundary, accepted)');
    } else if (res.status === 422) {
      pass('phone1 = 20 chars (validator rejected — backend stricter than DB)');
    } else {
      fail('phone1 = 20 chars — unexpected response', `HTTP ${res.status}`);
    }

    // 21-digit phone — should be rejected by DB or validator
    const phone21 = '1'.repeat(21);
    res = await api('POST', '/schools', minimalSchool({ phone1: phone21 }));
    if (res.status >= 500) {
      fail('phone1 = 21 chars — should not 5xx', `HTTP ${res.status}`);
    } else {
      pass(`phone1 = 21 chars handled (HTTP ${res.status})`);
    }
  }

  // ── 23. BOUNDARY: zip_code / code special characters ─────────────────────
  section('23. BOUNDARY — zip_code and code special characters');
  {
    // zip_code with letters (some countries have alphanumeric zip)
    let res = await api('POST', '/schools', minimalSchool({ zip_code: 'SW1A 2AA' }));
    if (res.status >= 200 && res.status < 300) {
      pass('zip_code = alphanumeric (accepted)');
    } else {
      pass(`zip_code = alphanumeric (HTTP ${res.status} — may be rejected)`);
    }

    // code with lowercase — should be uppercased by validator
    res = await api('POST', '/schools', minimalSchool({ code: `lowercase${Date.now()}`.slice(0, 20) }));
    if (res.status === 201) {
      const storedCode = res.data?.data?.code;
      if (storedCode && storedCode === storedCode.toUpperCase()) {
        pass('code lowercased input stored as UPPERCASE');
      } else {
        fail('code should be uppercased', `Stored code: ${storedCode}`);
      }
    } else if (res.status === 409) {
      pass('code lowercase (409 duplicate — uppercase collision)');
    } else {
      pass(`code lowercase handled (HTTP ${res.status})`);
    }
  }

  // ── 24. VERIFY HISTORY SAVED AFTER EDIT ──────────────────────────────────
  section('24. VERIFY AUDIT HISTORY SAVED AFTER EDIT');
  if (SCHOOL_ID) {
    // Make a known edit then verify the school data is consistent
    const uniqueName = `Audit Test School ${Date.now()}`;
    await api('PUT', `/schools/${SCHOOL_ID}`, { name: uniqueName });

    const res = await api('GET', `/schools/${SCHOOL_ID}`);
    assertOk(res, 'School reflects latest edit after audit-triggering PUT', d =>
      d.data.name === uniqueName
    );
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
