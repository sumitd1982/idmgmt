const router = require('express').Router();
const multer = require('multer');
const path   = require('path');
const sharp  = require('sharp');
const fs     = require('fs');
const { v4: uuid } = require('uuid');
const { authenticate } = require('../middleware/auth');

const UPLOAD_DIR = path.join(__dirname, '../../uploads');

// Ensure directories exist
['photos','logos','documents','temp'].forEach(d => {
  fs.mkdirSync(path.join(UPLOAD_DIR, d), { recursive: true });
});

const upload = multer({
  dest: path.join(UPLOAD_DIR, 'temp'),
  limits: { fileSize: 10 * 1024 * 1024 },
  fileFilter: (req, file, cb) => {
    const imgTypes = ['.jpg','.jpeg','.png','.webp','.gif'];
    const ext = path.extname(file.originalname).toLowerCase();
    if (imgTypes.includes(ext)) { cb(null, true); }
    else { cb(new Error('Only image files allowed for photo upload')); }
  }
});

// ── POST /uploads/photo ───────────────────────────────────────
router.post('/photo', authenticate, upload.single('photo'), async (req, res, next) => {
  if (!req.file) return res.status(400).json({ success: false, message: 'No file uploaded' });
  try {
    const filename  = `${uuid()}.webp`;
    const outPath   = path.join(UPLOAD_DIR, 'photos', filename);

    await sharp(req.file.path)
      .resize(400, 400, { fit: 'cover', position: 'face' })
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
router.post('/logo', authenticate, upload.single('logo'), async (req, res, next) => {
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

module.exports = router;
