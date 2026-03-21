// ============================================================
// Notifications — MSG91 Integration (SMS, WhatsApp, Email)
// ============================================================
const router = require('express').Router();
const axios  = require('axios');
const nodemailer = require('nodemailer');
const { v4: uuid } = require('uuid');
const { query } = require('../models/db');
const { authenticate } = require('../middleware/auth');
const logger = require('../utils/logger');

const MSG91_KEY     = process.env.MSG91_AUTH_KEY;
const MSG91_SENDER  = process.env.MSG91_SENDER || 'IDMGMT';

// ── Low-level SMS send ────────────────────────────────────────
const sendSMS = async (phone, message) => {
  if (!MSG91_KEY || !phone) return null;
  try {
    const resp = await axios.post('https://api.msg91.com/api/v5/flow/', {
      template_id: process.env.MSG91_TEMPLATE_ID,
      short_url: '1',
      mobiles: phone.replace(/\D/g, ''),
      VAR1: message,
    }, { headers: { authkey: MSG91_KEY, 'content-type': 'application/json' }, timeout: 8000 });
    return resp.data;
  } catch (e) {
    logger.warn(`[SMS] Failed to ${phone}: ${e.message}`);
    return null;
  }
};

// ── Low-level WhatsApp send ───────────────────────────────────
const sendWhatsApp = async (phone, message) => {
  if (!MSG91_KEY || !process.env.MSG91_WA_NUMBER || !phone) return null;
  try {
    const resp = await axios.post(
      'https://api.msg91.com/api/v5/whatsapp/whatsapp-outbound-message/bulk/',
      {
        integrated_number: process.env.MSG91_WA_NUMBER,
        content_type: 'template',
        payload: {
          messaging_product: 'whatsapp',
          type: 'template',
          template: {
            name: process.env.MSG91_WA_TEMPLATE || 'review_notification',
            language: { code: 'en' },
            components: [{
              type: 'body',
              parameters: [{ type: 'text', text: message }]
            }]
          }
        },
        to: [{ user_whatsapp_number: phone.replace(/\D/g, '') }]
      },
      { headers: { authkey: MSG91_KEY, 'content-type': 'application/json' }, timeout: 8000 }
    );
    return resp.data;
  } catch (e) {
    logger.warn(`[WA] Failed to ${phone}: ${e.message}`);
    return null;
  }
};

// ── Low-level Email send ──────────────────────────────────────
const sendEmail = async (email, subject, message) => {
  if (!email || !process.env.SMTP_HOST) return null;
  try {
    const transporter = nodemailer.createTransport({
      host: process.env.SMTP_HOST,
      port: parseInt(process.env.SMTP_PORT || '587'),
      secure: process.env.SMTP_SECURE === 'true',
      auth: {
        user: process.env.SMTP_USER,
        pass: process.env.SMTP_PASS,
      },
    });
    await transporter.sendMail({
      from: `"${process.env.SMTP_FROM_NAME || 'School ID System'}" <${process.env.SMTP_USER}>`,
      to: email,
      subject,
      text: message,
      html: `<p style="font-family:sans-serif;line-height:1.6">${message.replace(/\n/g, '<br>')}</p>`,
    });
    return { success: true };
  } catch (e) {
    logger.warn(`[EMAIL] Failed to ${email}: ${e.message}`);
    return null;
  }
};

// ── Unified multi-channel notification ───────────────────────
/**
 * sendNotification – fires SMS + WhatsApp + Email in parallel.
 * All channels are optional; missing values are silently skipped.
 * @param {object} opts
 * @param {string} [opts.phone]
 * @param {string} [opts.whatsapp]
 * @param {string} [opts.email]
 * @param {string} opts.subject
 * @param {string} opts.message
 * @param {string} [opts.school_id]
 * @param {string} [opts.recipient_id]   – DB id if logging needed
 * @param {string} [opts.recipient_type] – 'guardian' | 'employee' | 'user'
 */
const sendNotification = async (opts) => {
  const { phone, whatsapp, email, subject, message, school_id, recipient_id, recipient_type } = opts;
  const results = await Promise.allSettled([
    sendSMS(phone, message),
    sendWhatsApp(whatsapp || phone, message),
    sendEmail(email, subject, message),
  ]);

  const [smsResult, waResult, emailResult] = results;
  logger.info(`[NOTIFY] sms=${smsResult.status} wa=${waResult.status} email=${emailResult.status} → ${phone || email}`);

  // Optional DB log
  if (school_id && recipient_id) {
    const channels = [
      { channel: 'sms', r: smsResult },
      { channel: 'whatsapp', r: waResult },
      { channel: 'email', r: emailResult },
    ];
    for (const { channel, r } of channels) {
      try {
        await query(
          `INSERT INTO notifications (id,school_id,recipient_type,recipient_id,channel,subject,message,status,sent_at)
           VALUES (?,?,?,?,?,?,?,?,NOW())`,
          [uuid(), school_id, recipient_type || 'user', recipient_id, channel, subject || '', message,
           r.status === 'fulfilled' ? 'sent' : 'failed']
        );
      } catch (_) {}
    }
  }
  return results;
};

// Export helpers for use in other routes
module.exports.sendNotification = sendNotification;

// ── POST /notifications/send ──────────────────────────────────
router.post('/send', authenticate, async (req, res, next) => {
  try {
    const { recipients, channel, subject, message, school_id } = req.body;
    if (!recipients?.length) return res.status(400).json({ success: false, message: 'No recipients' });

    const results = [];
    for (const r of recipients) {
      const notifId = uuid();
      try {
        let providerRef = null;
        if (channel === 'sms' && r.phone) {
          const resp = await sendSMS(r.phone, message);
          providerRef = resp?.request_id;
        } else if (channel === 'whatsapp' && (r.whatsapp_no || r.phone)) {
          const resp = await sendWhatsApp(r.whatsapp_no || r.phone, message);
          providerRef = resp?.request_id;
        } else if (channel === 'email' && r.email) {
          await sendEmail(r.email, subject, message);
        }
        await query(
          `INSERT INTO notifications (id,school_id,recipient_type,recipient_id,channel,subject,message,status,provider_ref,sent_at)
           VALUES (?,?,?,?,?,?,?,'sent',?,NOW())`,
          [notifId, school_id, r.type || 'user', r.id, channel, subject, message, providerRef]
        );
        results.push({ id: r.id, status: 'sent' });
      } catch (e) {
        await query(
          `INSERT INTO notifications (id,school_id,recipient_type,recipient_id,channel,message,status,error_msg)
           VALUES (?,?,?,?,?,?,'failed',?)`,
          [notifId, school_id, r.type || 'user', r.id, channel, message, e.message]
        );
        results.push({ id: r.id, status: 'failed', error: e.message });
      }
    }
    res.json({ success: true, data: results });
  } catch (err) { next(err); }
});

// ── GET /notifications/log ────────────────────────────────────
router.get('/log', authenticate, async (req, res, next) => {
  try {
    const schoolId = req.query.school_id || req.employee?.school_id || req.user.school_id;
    const notifs = await query(
      `SELECT * FROM notifications WHERE school_id = ? ORDER BY created_at DESC LIMIT 100`,
      [schoolId]
    );
    res.json({ success: true, data: notifs });
  } catch (err) { next(err); }
});

module.exports = router;
module.exports.sendNotification = sendNotification;
