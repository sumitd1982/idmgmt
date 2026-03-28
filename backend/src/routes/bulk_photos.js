// ============================================================
// Bulk Photo Upload — Employees & Students
// Factory: call bulkPhotosRouter('employees') or ('students')
//
// Endpoints (mounted at /:entityType/bulk-photos/):
//   GET  /naming-guide          → XLSX with entity IDs + photo status
//   POST /validate              → Upload ZIP, dry-run, return match results
//   POST /apply                 → Process matched photos, update DB
//   GET  /history               → Upload history (bulk_batches)
// ============================================================

const router   = require('express').Router;
const multer   = require('multer');
const path     = require('path');
const fs       = require('fs');
const sharp    = require('sharp');
const AdmZip   = require('adm-zip');
const xlsx     = require('xlsx');
const { v4: uuid } = require('uuid');

const { query } = require('../models/db');
const { authenticate, requireRole } = require('../middleware/auth');

// ── Constants ──────────────────────────────────────────────────────────────
const UPLOAD_DIR      = path.join(__dirname, '../../uploads');
const TEMP_EXTRACT    = path.join(UPLOAD_DIR, 'temp_photo_batches');

const IMAGE_EXTS      = new Set(['.jpg', '.jpeg', '.png', '.webp', '.gif', '.bmp', '.tiff', '.tif']);
const SKIP_NAMES      = new Set(['thumbs.db', '.ds_store', 'desktop.ini']);
const SKIP_PREFIXES   = ['__macosx'];

const DEFAULT_MAX_PHOTO_MB = 8;      // per-photo warning threshold
const CONCURRENCY_LIMIT    = 10;     // Sharp processing concurrency
const MAX_ZIP_MB           = 200;    // multer ZIP limit

const upload = multer({
  dest: path.join(UPLOAD_DIR, 'temp'),
  limits: { fileSize: MAX_ZIP_MB * 1024 * 1024 },
  fileFilter: (req, file, cb) => {
    const ext = path.extname(file.originalname).toLowerCase();
    if (ext === '.zip') return cb(null, true);
    cb(new Error('Only .zip files are accepted for bulk photo upload'));
  },
});

fs.mkdirSync(TEMP_EXTRACT, { recursive: true });

// ── Helpers ────────────────────────────────────────────────────────────────

/** Resolve school.code for storage path, fallback to school_id slug */
async function getSchoolCode(schoolId) {
  const [row] = await query('SELECT code FROM schools WHERE id = ? LIMIT 1', [schoolId]);
  return (row?.code || schoolId).replace(/[^a-zA-Z0-9_\-]/g, '_').toLowerCase();
}

/** Resolve branch.code for storage path, fallback to branch_id slug */
async function getBranchCode(branchId) {
  if (!branchId) return 'main';
  const [row] = await query('SELECT code FROM branches WHERE id = ? LIMIT 1', [branchId]);
  return (row?.code || branchId).replace(/[^a-zA-Z0-9_\-]/g, '_').toLowerCase();
}

/** YYYYMM string from today */
function yyyymm() {
  const d = new Date();
  return `${d.getFullYear()}${String(d.getMonth() + 1).padStart(2, '0')}`;
}

/** Normalise an ID for loose matching: lowercase + strip non-alphanumeric */
function normaliseId(s) {
  return String(s || '').toLowerCase().replace(/[^a-z0-9]/g, '');
}

/** True if the ZIP entry should be silently skipped */
function shouldSkip(entryName) {
  const lower = entryName.toLowerCase();
  const basename = path.basename(lower);
  if (SKIP_NAMES.has(basename)) return true;
  if (SKIP_PREFIXES.some(p => lower.startsWith(p + '/'))) return true;
  return false;
}

/** Process items with a fixed concurrency cap (no p-limit required) */
async function withConcurrency(items, fn, limit = CONCURRENCY_LIMIT) {
  const results = [];
  for (let i = 0; i < items.length; i += limit) {
    const slice = items.slice(i, i + limit);
    const batch = await Promise.all(slice.map(fn));
    results.push(...batch);
  }
  return results;
}

/**
 * Resolve school_id from request for super_admin who passes it via
 * query/body, or from the employee's own context.
 */
function resolveSchool(req) {
  return req.employee?.school_id
    || req.user?.school_id
    || req.query?.school_id
    || req.body?.school_id
    || null;
}

/**
 * Build a lookup map: normalised_id → { id, entityId, firstName, lastName, photoUrl, branchId }
 * Also a secondary map: normalised_phone → same record (for employees only)
 */
async function buildLookupMaps(entityType, schoolId, branchId) {
  let rows;
  if (entityType === 'employees') {
    let sql = `SELECT e.id, e.employee_id AS entity_id,
                      e.first_name, e.last_name, e.photo_url, e.phone, e.branch_id
               FROM employees e
               WHERE e.school_id = ? AND e.is_active = TRUE`;
    const params = [schoolId];
    if (branchId) { sql += ' AND e.branch_id = ?'; params.push(branchId); }
    rows = await query(sql, params);
  } else {
    let sql = `SELECT s.id, s.student_id AS entity_id,
                      s.first_name, s.last_name, s.photo_url, NULL AS phone, s.branch_id
               FROM students s
               WHERE s.school_id = ? AND s.is_active = TRUE`;
    const params = [schoolId];
    if (branchId) { sql += ' AND s.branch_id = ?'; params.push(branchId); }
    rows = await query(sql, params);
  }

  const byId    = new Map();
  const byPhone = new Map();
  for (const r of rows) {
    byId.set(normaliseId(r.entity_id), r);
    if (r.phone) {
      const p10 = r.phone.replace(/\D/g, '').slice(-10);
      if (p10.length === 10) byPhone.set(p10, r);
    }
  }
  return { byId, byPhone };
}

// ── Router factory ─────────────────────────────────────────────────────────
module.exports = function bulkPhotosRouter(entityType) {
  const r = router();

  // ── GET /naming-guide ──────────────────────────────────────────────────
  // Returns XLSX: entity_id | full_name | photo_status | rename_to
  // Query: school_id, branch_id, missing_only (default false)
  r.get('/naming-guide', authenticate, async (req, res, next) => {
    try {
      const schoolId   = resolveSchool(req);
      if (!schoolId) return res.status(422).json({ success: false, message: 'school_id required' });

      const branchId   = req.query.branch_id || null;
      const missingOnly = req.query.missing_only === 'true';

      let rows;
      if (entityType === 'employees') {
        let sql = `SELECT e.employee_id AS entity_id,
                          CONCAT(e.first_name, ' ', e.last_name) AS full_name,
                          e.photo_url
                   FROM employees e
                   WHERE e.school_id = ? AND e.is_active = TRUE`;
        const p = [schoolId];
        if (branchId) { sql += ' AND e.branch_id = ?'; p.push(branchId); }
        if (missingOnly) sql += ' AND (e.photo_url IS NULL OR e.photo_url = \'\')';
        sql += ' ORDER BY e.first_name, e.last_name';
        rows = await query(sql, p);
      } else {
        let sql = `SELECT s.student_id AS entity_id,
                          CONCAT(s.first_name, ' ', s.last_name) AS full_name,
                          s.photo_url
                   FROM students s
                   WHERE s.school_id = ? AND s.is_active = TRUE`;
        const p = [schoolId];
        if (branchId) { sql += ' AND s.branch_id = ?'; p.push(branchId); }
        if (missingOnly) sql += ' AND (s.photo_url IS NULL OR s.photo_url = \'\')';
        sql += ' ORDER BY s.first_name, s.last_name';
        rows = await query(sql, p);
      }

      const entityLabel = entityType === 'employees' ? 'Employee' : 'Student';

      // Build XLSX
      const wb = xlsx.utils.book_new();

      // Instructions sheet
      const instrData = [
        [`BULK PHOTO UPLOAD — ${entityLabel.toUpperCase()} NAMING GUIDE`],
        [''],
        ['HOW TO USE THIS GUIDE:'],
        [`1. Download this file to see all ${entityType} and their current photo status.`],
        ['2. Collect photos for each person.'],
        [`3. Rename each photo file to the exact "${entityLabel} ID" shown below.`],
        ['   e.g.  EMP-001.jpg   or   STU-002.png'],
        ['4. Put all renamed photos into one folder and compress it to a ZIP file.'],
        ['5. Upload the ZIP file in the Bulk Photo Upload screen.'],
        [''],
        ['ACCEPTED PHOTO FORMATS:  jpg, jpeg, png, webp, gif'],
        ['MAXIMUM ZIP SIZE:  200 MB'],
        [`MAXIMUM PHOTO SIZE:  ${DEFAULT_MAX_PHOTO_MB} MB (larger files will be warned but still processed)`],
        [''],
        ['MATCHING RULES:'],
        ['  • Exact match first:  EMP-001.jpg  →  EMP-001'],
        ['  • Loose match second: EMP001.jpg   →  EMP-001  (hyphens/spaces stripped)'],
        ['  • Phone match (employees): 9876543210.jpg  →  employee with that phone'],
        ['  • Case-insensitive: emp-001.JPG  ===  EMP-001'],
        [''],
        ['TIP: Use the "missing_only=true" filter to see only people without a photo.'],
      ];
      xlsx.utils.book_append_sheet(wb, xlsx.utils.aoa_to_sheet(instrData), 'Instructions');

      // Data sheet
      const headers = [`${entityLabel} ID`, 'Full Name', 'Has Photo?', 'Rename Your File To'];
      const dataRows = [headers];
      for (const row of rows) {
        const hasPhoto = row.photo_url ? '✓ Yes' : '✗ No';
        dataRows.push([row.entity_id, row.full_name, hasPhoto, `${row.entity_id}.jpg`]);
      }
      const ws = xlsx.utils.aoa_to_sheet(dataRows);
      // Column widths
      ws['!cols'] = [{ wch: 18 }, { wch: 30 }, { wch: 12 }, { wch: 22 }];
      xlsx.utils.book_append_sheet(wb, ws, `${entityLabel}s`);

      const buf = xlsx.write(wb, { type: 'buffer', bookType: 'xlsx' });
      const filename = `${entityType}_photo_naming_guide.xlsx`;
      res.setHeader('Content-Type', 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
      res.setHeader('Content-Disposition', `attachment; filename="${filename}"`);
      res.send(buf);
    } catch (err) { next(err); }
  });

  // ── POST /validate ─────────────────────────────────────────────────────
  // Upload ZIP, dry-run match against DB, return results + batch_id
  r.post('/validate', authenticate, upload.single('file'), async (req, res, next) => {
    const tempZipPath = req.file?.path;
    let extractDir = null;

    try {
      if (!req.file) return res.status(400).json({ success: false, message: 'No ZIP file uploaded' });

      const schoolId = resolveSchool(req);
      if (!schoolId) {
        fs.unlink(tempZipPath, () => {});
        return res.status(422).json({ success: false, message: 'school_id required' });
      }

      const branchId      = req.body.branch_id || req.query.branch_id || null;
      const maxPhotoMb    = parseFloat(req.body.max_photo_mb || DEFAULT_MAX_PHOTO_MB);

      // Extract ZIP
      const batchId  = uuid();
      extractDir     = path.join(TEMP_EXTRACT, batchId);
      fs.mkdirSync(extractDir, { recursive: true });

      let zip;
      try {
        zip = new AdmZip(tempZipPath);
      } catch (zipErr) {
        fs.unlink(tempZipPath, () => {});
        return res.status(400).json({ success: false, message: 'Invalid or corrupt ZIP file' });
      }

      const entries    = zip.getEntries();
      const imageFiles = [];
      const xlsxFiles  = [];
      const skipped    = [];

      for (const entry of entries) {
        if (entry.isDirectory) continue;
        const entryName = entry.entryName;
        if (shouldSkip(entryName)) continue;

        const ext      = path.extname(entryName).toLowerCase();
        const basename = path.basename(entryName);

        if (['.xlsx', '.xls', '.csv'].includes(ext)) {
          xlsxFiles.push(basename);
          continue;
        }

        if (!IMAGE_EXTS.has(ext)) {
          skipped.push({ file: basename, reason: `Unsupported file type (${ext || 'no extension'})` });
          continue;
        }

        // Write to extract dir
        const outPath = path.join(extractDir, `${uuid()}${ext}`);
        try {
          fs.writeFileSync(outPath, entry.getData());
          const statSize = fs.statSync(outPath).size;
          imageFiles.push({
            entryName,
            basename,
            ext,
            outPath,
            sizeMb: statSize / (1024 * 1024),
            entityId: path.basename(basename, ext),  // filename without extension
          });
        } catch (writeErr) {
          skipped.push({ file: basename, reason: 'Could not extract from ZIP' });
        }
      }

      // Remove temp ZIP (extracted to dir)
      fs.unlink(tempZipPath, () => {});

      // Build lookup maps
      const { byId, byPhone } = await buildLookupMaps(entityType, schoolId, branchId);

      // Match each image file
      const seenEntityIds  = new Map();  // normalised_id → first filename
      const results        = [];
      let matchedCount     = 0;
      let unmatchedCount   = 0;
      let warningCount     = 0;

      for (const img of imageFiles) {
        const warnings = [];
        const errors   = [];

        // Large photo warning
        if (img.sizeMb > maxPhotoMb) {
          warnings.push(`Large file (${img.sizeMb.toFixed(1)} MB > ${maxPhotoMb} MB limit) — will still be processed`);
        }

        // Duplicate filename check
        const normId = normaliseId(img.entityId);
        if (seenEntityIds.has(normId)) {
          warnings.push(`Duplicate: "${seenEntityIds.get(normId)}" also maps to the same ID — first file wins`);
          results.push({
            file:    img.basename,
            entityId: img.entityId,
            status:  'skipped',
            reason:  'Duplicate entity ID in ZIP',
            warnings,
            errors,
          });
          // Clean up this file
          fs.unlink(img.outPath, () => {});
          unmatchedCount++;
          continue;
        }
        seenEntityIds.set(normId, img.basename);

        // Match: exact → loose → phone (employees only)
        let matchedRecord = byId.get(normId) || null;
        let matchMethod   = 'exact';

        if (!matchedRecord) {
          // Loose match: strip all non-alphanumeric from both sides
          for (const [key, val] of byId) {
            if (key === normId) { matchedRecord = val; break; }
          }
          matchMethod = 'loose';
        }

        if (!matchedRecord && entityType === 'employees') {
          // Phone match fallback
          const phone10 = img.entityId.replace(/\D/g, '').slice(-10);
          if (phone10.length === 10) {
            matchedRecord = byPhone.get(phone10) || null;
            matchMethod   = 'phone';
          }
        }

        if (!matchedRecord) {
          results.push({
            file:    img.basename,
            entityId: img.entityId,
            status:  'unmatched',
            reason:  `No active ${entityType === 'employees' ? 'employee' : 'student'} found with ID "${img.entityId}"`,
            warnings,
            errors,
            extractedPath: img.outPath,
          });
          unmatchedCount++;
          continue;
        }

        // Matched
        if (matchedRecord.photo_url) {
          warnings.push('Will replace existing photo');
        }
        if (matchMethod === 'loose') {
          warnings.push(`Matched by loose ID (stripped non-alphanumeric characters)`);
        } else if (matchMethod === 'phone') {
          warnings.push(`Matched by phone number`);
        }

        if (warnings.length) warningCount++;
        matchedCount++;

        results.push({
          file:         img.basename,
          entityId:     img.entityId,
          entityDbId:   matchedRecord.id,
          fullName:     `${matchedRecord.first_name} ${matchedRecord.last_name}`,
          status:       'matched',
          matchMethod,
          hasExistingPhoto: !!matchedRecord.photo_url,
          warnings,
          errors,
          extractedPath: img.outPath,
        });
      }

      // Warnings about XLSX files in ZIP
      if (xlsxFiles.length > 0) {
        // These are not blocking, just informational
      }

      // Save batch record
      const batchType = entityType === 'employees' ? 'employee_photos' : 'student_photos';
      await query(
        `INSERT INTO bulk_batches
           (id, school_id, branch_id, type, filename, file_url, total_rows, status, uploaded_by)
         VALUES (?, ?, ?, ?, ?, ?, ?, 'validated', ?)`,
        [batchId, schoolId, branchId, batchType,
         req.file.originalname, extractDir,
         imageFiles.length, req.user.id]
      );

      // Store match results in validation_report for apply step
      await query(
        'UPDATE bulk_batches SET validation_report = ? WHERE id = ?',
        [JSON.stringify({ results, xlsxWarnings: xlsxFiles, skipped }), batchId]
      );

      const canApplyAll     = matchedCount > 0;
      const canApplyPartial = matchedCount > 0 && unmatchedCount > 0;

      res.json({
        success: true,
        data: {
          batchId,
          totalFiles:    imageFiles.length,
          matched:       matchedCount,
          unmatched:     unmatchedCount,
          warnings:      warningCount,
          skippedFiles:  skipped,
          xlsxFiles,
          canApplyAll,
          canApplyPartial,
          results,
        },
      });
    } catch (err) {
      // Cleanup on unexpected error
      if (tempZipPath) fs.unlink(tempZipPath, () => {});
      if (extractDir)  fs.rm(extractDir, { recursive: true, force: true }, () => {});
      next(err);
    }
  });

  // ── POST /apply ────────────────────────────────────────────────────────
  // Process matched photos from a validated batch
  // Body: { batch_id, mode: 'full'|'partial' }
  //   full    = apply only if ALL files matched (abort if any unmatched)
  //   partial = apply matched files, skip unmatched (default)
  r.post('/apply',
    authenticate,
    requireRole('super_admin', 'school_owner', 'principal', 'vp', 'head_teacher'),
    async (req, res, next) => {
      try {
        const { batch_id, mode = 'partial' } = req.body;
        if (!batch_id) return res.status(400).json({ success: false, message: 'batch_id required' });

        const [batch] = await query('SELECT * FROM bulk_batches WHERE id = ?', [batch_id]);
        if (!batch) return res.status(404).json({ success: false, message: 'Batch not found' });
        if (batch.status === 'completed') return res.status(409).json({ success: false, message: 'Batch already applied' });
        if (batch.status !== 'validated') return res.status(409).json({ success: false, message: `Batch is in '${batch.status}' state, expected 'validated'` });

        const report = batch.validation_report;
        if (!report?.results) return res.status(422).json({ success: false, message: 'Batch has no validation report — re-upload ZIP' });

        const matchedItems = report.results.filter(r => r.status === 'matched');
        const unmatchedCount = report.results.filter(r => r.status === 'unmatched').length;

        if (mode === 'full' && unmatchedCount > 0) {
          return res.status(422).json({
            success: false,
            message: `Full upload rejected: ${unmatchedCount} file(s) are unmatched. Use mode='partial' to apply only matched photos.`,
          });
        }

        if (matchedItems.length === 0) {
          return res.status(422).json({ success: false, message: 'No matched photos to apply' });
        }

        await query("UPDATE bulk_batches SET status = 'processing' WHERE id = ?", [batch_id]);

        // Resolve storage path from school/branch
        const schoolCode = await getSchoolCode(batch.school_id);
        const branchCode = await getBranchCode(batch.branch_id);
        const ym         = yyyymm();
        const subPath    = `${schoolCode}/${branchCode}/${ym}/${entityType}/bulk-photos`;
        const photoDir   = path.join(UPLOAD_DIR, subPath);
        fs.mkdirSync(photoDir, { recursive: true });

        const processedItems = [];
        let processedCount = 0;
        let failedCount    = 0;

        await withConcurrency(matchedItems, async (item) => {
          const resultEntry = { file: item.file, entityId: item.entityId, fullName: item.fullName };

          // Verify extracted file still exists
          if (!item.extractedPath || !fs.existsSync(item.extractedPath)) {
            resultEntry.status  = 'error';
            resultEntry.reason  = 'Extracted file no longer found (batch may have expired)';
            processedItems.push(resultEntry);
            failedCount++;
            return;
          }

          // Check image dimensions and integrity
          try {
            const meta = await sharp(item.extractedPath).metadata();
            if (!meta.width || !meta.height) throw new Error('Cannot read image dimensions');
            if (meta.width < 100 || meta.height < 100) {
              resultEntry.warning = `Low resolution (${meta.width}×${meta.height}px) — processed anyway`;
            }
          } catch (metaErr) {
            resultEntry.status = 'error';
            resultEntry.reason = `Invalid or corrupt image: ${metaErr.message}`;
            fs.unlink(item.extractedPath, () => {});
            processedItems.push(resultEntry);
            failedCount++;
            return;
          }

          // Process with Sharp
          const outFilename = `photo_${uuid()}.webp`;
          const outPath     = path.join(photoDir, outFilename);

          try {
            await sharp(item.extractedPath)
              .resize(400, 400, { fit: 'cover', position: 'top' })
              .webp({ quality: 88 })
              .toFile(outPath);
          } catch (sharpErr) {
            resultEntry.status = 'error';
            resultEntry.reason = `Image processing failed: ${sharpErr.message}`;
            fs.unlink(item.extractedPath, () => {});
            processedItems.push(resultEntry);
            failedCount++;
            return;
          }

          // Build URL (relative to static serve root)
          const photoUrl = `/idmgmt/api/static/${subPath}/${outFilename}`;

          // Update entity record
          const table     = entityType === 'employees' ? 'employees'  : 'students';
          const idField   = entityType === 'employees' ? 'employee_id': 'student_id';
          await query(
            `UPDATE ${table} SET photo_url = ?, updated_at = NOW() WHERE id = ?`,
            [photoUrl, item.entityDbId]
          );

          // Cleanup extracted file
          fs.unlink(item.extractedPath, () => {});

          resultEntry.status   = 'ok';
          resultEntry.photoUrl = photoUrl;
          processedItems.push(resultEntry);
          processedCount++;
        });

        // Finalise batch
        await query(
          `UPDATE bulk_batches SET status = 'completed', success_rows = ?, failed_rows = ?,
           confirmed_at = NOW(), confirmed_by = ?, validation_report = ? WHERE id = ?`,
          [processedCount, failedCount, req.user.id, JSON.stringify({ results: processedItems }), batch_id]
        );

        // Cleanup extract dir (all extracted files should be gone or error-skipped)
        fs.rm(batch.file_url, { recursive: true, force: true }, () => {});

        res.json({
          success: true,
          data: {
            batchId:   batch_id,
            processed: processedCount,
            failed:    failedCount,
            skipped:   unmatchedCount,
            total:     matchedItems.length + unmatchedCount,
            results:   processedItems,
          },
        });
      } catch (err) { next(err); }
    }
  );

  // ── GET /history ───────────────────────────────────────────────────────
  r.get('/history', authenticate, async (req, res, next) => {
    try {
      const schoolId = resolveSchool(req);
      if (!schoolId) return res.json({ success: true, data: [] });

      const batchType = entityType === 'employees' ? 'employee_photos' : 'student_photos';
      const batches = await query(
        `SELECT bb.id, bb.filename, bb.total_rows, bb.success_rows, bb.failed_rows,
                bb.status, bb.created_at, bb.confirmed_at,
                u.full_name AS uploaded_by_name
         FROM bulk_batches bb
         JOIN users u ON u.id = bb.uploaded_by
         WHERE bb.school_id = ? AND bb.type = ?
         ORDER BY bb.created_at DESC
         LIMIT 100`,
        [schoolId, batchType]
      );
      res.json({ success: true, data: batches });
    } catch (err) { next(err); }
  });

  return r;
};
