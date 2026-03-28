const router = require('express').Router();
const multer = require('multer');
const path   = require('path');
const sharp  = require('sharp');
const fs     = require('fs');
const { v4: uuid } = require('uuid');
const { authenticate } = require('../middleware/auth');

const UPLOAD_DIR = path.join(__dirname, '../../uploads');

// Ensure base directories exist
['photos','logos','documents','temp','images/school'].forEach(d => {
  fs.mkdirSync(path.join(UPLOAD_DIR, d), { recursive: true });
});

const ALLOWED_IMG_TYPES = ['.jpg','.jpeg','.png','.webp','.gif'];

const upload = multer({
  dest: path.join(UPLOAD_DIR, 'temp'),
  limits: { fileSize: 10 * 1024 * 1024 },
  fileFilter: (req, file, cb) => {
    const ext = path.extname(file.originalname).toLowerCase();
    if (ALLOWED_IMG_TYPES.includes(ext)) { cb(null, true); }
    else {
      const err = new Error('Only image files are allowed (jpg, jpeg, png, webp, gif)');
      err.status = 400;
      cb(err);
    }
  }
});

/** Wrap a multer middleware so fileFilter/limit errors become 400 responses. */
function uploadSingle(fieldName) {
  const middleware = upload.single(fieldName);
  return (req, res, next) => {
    middleware(req, res, (err) => {
      if (!err) return next();
      if (err instanceof multer.MulterError) {
        const msg = err.code === 'LIMIT_FILE_SIZE'
          ? 'File size exceeds the 10 MB limit'
          : err.message;
        return res.status(400).json({ success: false, message: msg });
      }
      if (err && err.status === 400) {
        return res.status(400).json({ success: false, message: err.message });
      }
      next(err);
    });
  };
}

// ── POST /uploads/photo ───────────────────────────────────────
// Optional body fields: entity (student|employee|guardian), entity_ref (ID string)
// Naming: {entity}_{entity_ref}_{uuid}.webp  e.g. student_STU001_abc123.webp
router.post('/photo', authenticate, uploadSingle('photo'), async (req, res, next) => {
  if (!req.file) return res.status(400).json({ success: false, message: 'No file uploaded' });
  try {
    const entity    = String(req.body.entity || '').replace(/[^a-zA-Z]/g, '') || 'photo';
    const entityRef = String(req.body.entity_ref || '').replace(/[^a-zA-Z0-9_\-]/g, '').slice(0, 40);
    const nameBase  = entityRef ? `${entity}_${entityRef}_${uuid()}` : `${entity}_${uuid()}`;
    const filename  = `${nameBase}.webp`;
    const outPath   = path.join(UPLOAD_DIR, 'photos', filename);

    await sharp(req.file.path)
      .resize(400, 400, { fit: 'cover', position: 'top' })
      .webp({ quality: 85 })
      .toFile(outPath);

    fs.unlinkSync(req.file.path);
    const url = `/idmgmt/api/static/photos/${filename}`;
    res.json({ success: true, data: { url, filename } });
  } catch (err) {
    if (req.file) fs.unlink(req.file.path, () => {});
    next(err);
  }
});

// ── POST /uploads/logo ────────────────────────────────────────
router.post('/logo', authenticate, uploadSingle('logo'), async (req, res, next) => {
  if (!req.file) return res.status(400).json({ success: false, message: 'No file uploaded' });
  try {
    const filename = `${uuid()}.webp`;
    const outPath  = path.join(UPLOAD_DIR, 'logos', filename);

    await sharp(req.file.path).resize(300, 300, { fit: 'contain', background: '#FFFFFF' })
      .webp({ quality: 90 }).toFile(outPath);

    fs.unlinkSync(req.file.path);
    res.json({ success: true, data: { url: `/idmgmt/api/static/logos/${filename}` } });
  } catch (err) {
    if (req.file) fs.unlink(req.file.path, () => {});
    next(err);
  }
});

// ── POST /uploads/employee-photo ─────────────────────────────
// Saves year-wise: images/employees/YYYY/photo_*.webp
router.post('/employee-photo', authenticate, uploadSingle('photo'), async (req, res, next) => {
  if (!req.file) return res.status(400).json({ success: false, message: 'No file uploaded' });
  try {
    const year = new Date().getFullYear().toString();
    const yearDir = path.join(UPLOAD_DIR, 'images/employees', year);
    fs.mkdirSync(yearDir, { recursive: true });

    const filename = `photo_${uuid()}.webp`;
    const outPath  = path.join(yearDir, filename);

    await sharp(req.file.path)
      .resize(400, 400, { fit: 'cover', position: 'top' })
      .webp({ quality: 88 })
      .toFile(outPath);

    fs.unlinkSync(req.file.path);
    res.json({ success: true, data: { url: `/idmgmt/api/static/images/employees/${year}/${filename}` } });
  } catch (err) {
    if (req.file) fs.unlink(req.file.path, () => {});
    next(err);
  }
});

// ── POST /uploads/student-photo ──────────────────────────────
// Saves year-wise: images/students/YYYY/photo_*.webp
router.post('/student-photo', authenticate, uploadSingle('photo'), async (req, res, next) => {
  if (!req.file) return res.status(400).json({ success: false, message: 'No file uploaded' });
  try {
    const year = new Date().getFullYear().toString();
    const yearDir = path.join(UPLOAD_DIR, 'images/students', year);
    fs.mkdirSync(yearDir, { recursive: true });

    const filename = `photo_${uuid()}.webp`;
    const outPath  = path.join(yearDir, filename);

    await sharp(req.file.path)
      .resize(400, 400, { fit: 'cover', position: 'top' })
      .webp({ quality: 88 })
      .toFile(outPath);

    fs.unlinkSync(req.file.path);
    res.json({ success: true, data: { url: `images/students/${year}/${filename}` } });
  } catch (err) {
    if (req.file) fs.unlink(req.file.path, () => {});
    next(err);
  }
});

// ── POST /uploads/school-logo ─────────────────────────────────
router.post('/school-logo', authenticate, uploadSingle('logo'), async (req, res, next) => {
  if (!req.file) return res.status(400).json({ success: false, message: 'No file uploaded' });
  try {
    const filename = `logo_${uuid()}.webp`;
    const outPath  = path.join(UPLOAD_DIR, 'images/school', filename);

    await sharp(req.file.path)
      .resize(300, 300, { fit: 'contain', background: '#FFFFFF' })
      .webp({ quality: 90 })
      .toFile(outPath);

    fs.unlinkSync(req.file.path);
    res.json({ success: true, data: { url: `/idmgmt/api/static/images/school/${filename}` } });
  } catch (err) {
    if (req.file) fs.unlink(req.file.path, () => {});
    next(err);
  }
});

// ── POST /uploads/school-banner ───────────────────────────────
router.post('/school-banner', authenticate, uploadSingle('banner'), async (req, res, next) => {
  if (!req.file) return res.status(400).json({ success: false, message: 'No file uploaded' });
  try {
    const filename = `banner_${uuid()}.webp`;
    const outPath  = path.join(UPLOAD_DIR, 'images/school', filename);

    await sharp(req.file.path)
      .resize(1200, 300, { fit: 'cover', position: 'center' })
      .webp({ quality: 85 })
      .toFile(outPath);

    fs.unlinkSync(req.file.path);
    res.json({ success: true, data: { url: `/idmgmt/api/static/images/school/${filename}` } });
  } catch (err) {
    if (req.file) fs.unlink(req.file.path, () => {});
    next(err);
  }
});

module.exports = router;
