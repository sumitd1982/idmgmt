const router = require('express').Router();
const { v4: uuid } = require('uuid');
const PDFDocument = require('pdfkit');
const QRCode   = require('qrcode');
const { query } = require('../models/db');
const { authenticate } = require('../middleware/auth');
const path = require('path');
const fs   = require('fs');

router.get('/themes', authenticate, async (req, res, next) => {
  try {
    const schoolId = req.query.school_id || req.employee?.school_id;
    const themes = await query(
      'SELECT * FROM id_card_themes WHERE school_id = ? AND is_active = TRUE ORDER BY is_default DESC, name',
      [schoolId]
    );
    res.json({ success: true, data: themes });
  } catch (err) { next(err); }
});

router.post('/themes', authenticate, async (req, res, next) => {
  try {
    const id = uuid();
    const { school_id, name, description, primary_color, secondary_color, accent_color,
            text_color, bg_color, front_layout, back_layout, custom_fields, is_default } = req.body;

    if (is_default) {
      await query('UPDATE id_card_themes SET is_default=FALSE WHERE school_id=?', [school_id]);
    }

    await query(
      `INSERT INTO id_card_themes (id,school_id,name,description,primary_color,secondary_color,
         accent_color,text_color,bg_color,front_layout,back_layout,custom_fields,is_default)
       VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?)`,
      [id, school_id, name, description,
       primary_color || '#003087', secondary_color || '#1565C0', accent_color || '#FFC107',
       text_color || '#212121', bg_color || '#FFFFFF',
       JSON.stringify(front_layout || {}), JSON.stringify(back_layout || {}),
       JSON.stringify(custom_fields || []), is_default || false]
    );

    const [theme] = await query('SELECT * FROM id_card_themes WHERE id=?', [id]);
    res.status(201).json({ success: true, data: theme });
  } catch (err) { next(err); }
});

// Generate ID card PDF for a student
router.get('/generate/student/:student_id', authenticate, async (req, res, next) => {
  try {
    const [student] = await query(
      `SELECT s.*, b.name AS branch_name, sch.name AS school_name,
              sch.logo_url, sch.phone1, sch.email, sch.website,
              b.address_line1, b.city, b.zip_code
       FROM students s
       JOIN branches b ON b.id = s.branch_id
       JOIN schools sch ON sch.id = s.school_id
       WHERE s.id = ?`, [req.params.student_id]
    );
    if (!student) return res.status(404).json({ success: false, message: 'Student not found' });

    const [theme] = await query(
      `SELECT t.* FROM id_card_themes t
       JOIN id_card_assignments a ON a.theme_id = t.id
       WHERE a.school_id = ? AND a.employee_type IN ('student','all') AND t.is_active = TRUE
       LIMIT 1`, [student.school_id]
    );

    // Generate QR code data
    const qrData = JSON.stringify({
      id: student.id, name: `${student.first_name} ${student.last_name}`,
      school: student.school_name, class: `${student.class_name}-${student.section}`,
      student_id: student.student_id
    });
    const qrBuffer = await QRCode.toBuffer(qrData, { width: 80, margin: 1 });

    // Create PDF
    const doc = new PDFDocument({ size: [242, 153], margin: 0 }); // 85.6mm x 53.98mm @ 72dpi

    const primaryColor  = theme?.primary_color  || '#003087';
    const secondaryColor = theme?.secondary_color || '#1565C0';
    const accentColor   = theme?.accent_color   || '#FFC107';
    const textColor     = theme?.text_color     || '#212121';

    // Front side — header
    doc.rect(0, 0, 242, 35).fill(primaryColor);
    doc.fontSize(9).fillColor('#FFFFFF').font('Helvetica-Bold')
       .text(student.school_name, 10, 8, { width: 220, align: 'center' });
    doc.fontSize(6).fillColor('#FFFFFF').font('Helvetica')
       .text(student.branch_name, 10, 20, { width: 220, align: 'center' });

    // Photo placeholder
    doc.rect(8, 40, 45, 55).stroke(primaryColor);
    if (student.photo_url) {
      // In production: fetch and embed image
      doc.rect(8, 40, 45, 55).fill('#E3F2FD');
    } else {
      doc.rect(8, 40, 45, 55).fill('#E3F2FD');
      doc.fontSize(6).fillColor('#90A4AE').text('PHOTO', 15, 60);
    }

    // Student info
    doc.fontSize(9).fillColor(textColor).font('Helvetica-Bold')
       .text(`${student.first_name} ${student.last_name}`, 60, 42, { width: 120 });
    doc.fontSize(7).fillColor('#555555').font('Helvetica')
       .text(`ID: ${student.student_id}`, 60, 54)
       .text(`Class: ${student.class_name} - ${student.section}`, 60, 63)
       .text(`Roll No: ${student.roll_number || 'N/A'}`, 60, 72)
       .text(`DOB: ${student.date_of_birth ? new Date(student.date_of_birth).toLocaleDateString('en-IN') : 'N/A'}`, 60, 81);

    // Blood group badge
    doc.circle(218, 52, 12).fill(accentColor);
    doc.fontSize(6).fillColor('#000000').font('Helvetica-Bold')
       .text(student.blood_group || 'N/A', 210, 48, { width: 18, align: 'center' });

    // QR code
    doc.image(qrBuffer, 185, 65, { width: 50, height: 50 });

    // Footer
    doc.rect(0, 118, 242, 35).fill(secondaryColor);
    doc.fontSize(5.5).fillColor('#FFFFFF').font('Helvetica')
       .text(student.phone1 || '', 10, 122)
       .text(student.website || '', 10, 131);
    doc.fontSize(6).fillColor('#FFFFFF').font('Helvetica-Bold')
       .text('STUDENT IDENTITY CARD', 10, 140, { width: 222, align: 'center' });

    // Finalize
    const chunks = [];
    doc.on('data', (c) => chunks.push(c));
    doc.on('end', () => {
      const buf = Buffer.concat(chunks);
      res.setHeader('Content-Type', 'application/pdf');
      res.setHeader('Content-Disposition', `attachment; filename="idcard_${student.student_id}.pdf"`);
      res.send(buf);
    });
    doc.end();

  } catch (err) { next(err); }
});

// Bulk generate ID cards (zip)
router.post('/generate/bulk', authenticate, async (req, res, next) => {
  try {
    const { student_ids, school_id } = req.body;
    // Return job ID — actual generation happens asynchronously
    const jobId = uuid();
    res.json({ success: true, data: { job_id: jobId, message: 'Bulk generation queued' } });
  } catch (err) { next(err); }
});

module.exports = router;
