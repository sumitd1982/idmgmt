// ============================================================
// Notifications — MSG91 Integration (SMS, WhatsApp, Email)
// ============================================================
const router = require('express').Router();
const axios  = require('axios');
const { v4: uuid } = require('uuid');
const { query } = require('../models/db');
const { authenticate } = require('../middleware/auth');
const logger = require('../utils/logger');

const MSG91_KEY     = process.env.MSG91_AUTH_KEY;
const MSG91_SENDER  = process.env.MSG91_SENDER || 'IDMGMT';

// Send SMS via MSG91
const sendSMS = async (phone, message) => {
  if (!MSG91_KEY) { logger.warn('MSG91 key not configured'); return null; }
  const resp = await axios.post('https://api.msg91.com/api/v5/flow/', {
    template_id: process.env.MSG91_TEMPLATE_ID,
    short_url: '1',
    mobiles: phone.replace('+', ''),
    VAR1: message,
  }, { headers: { authkey: MSG91_KEY, 'content-type': 'application/json' } });
  return resp.data;
};

// Send WhatsApp via MSG91
const sendWhatsApp = async (phone, templateId, params) => {
  if (!MSG91_KEY) { logger.warn('MSG91 key not configured'); return null; }
  const resp = await axios.post('https://api.msg91.com/api/v5/whatsapp/whatsapp-outbound-message/bulk/', {
    integrated_number: process.env.MSG91_WA_NUMBER,
    content_type: 'template',
    payload: {
      messaging_product: 'whatsapp',
      type: 'template',
      template: { name: templateId, language: { code: 'en' }, components: params }
    },
    to: [{ user_whatsapp_number: phone.replace('+', '') }]
  }, { headers: { authkey: MSG91_KEY, 'content-type': 'application/json' } });
  return resp.data;
};

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
        } else if (channel === 'whatsapp' && r.whatsapp_no) {
          const resp = await sendWhatsApp(r.whatsapp_no, process.env.MSG91_WA_TEMPLATE, []);
          providerRef = resp?.request_id;
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
    const schoolId = req.query.school_id || req.employee?.school_id;
    const notifs = await query(
      `SELECT * FROM notifications WHERE school_id = ? ORDER BY created_at DESC LIMIT 100`,
      [schoolId]
    );
    res.json({ success: true, data: notifs });
  } catch (err) { next(err); }
});

module.exports = router;
