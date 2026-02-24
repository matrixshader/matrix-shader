import { Redis } from '@upstash/redis';
import crypto from 'crypto';

const redis = new Redis({
  url: process.env.KV_REST_API_URL,
  token: process.env.KV_REST_API_TOKEN,
});

// Auth: same as dashboard.js
async function authenticate(req) {
  // Session auth
  const sessionHeader = req.headers['x-session'];
  if (sessionHeader) {
    try {
      const valid = await redis.get(`session:${sessionHeader}`);
      if (valid === 'active') return true;
    } catch { /* fall through */ }
  }
  // Password auth
  const password = process.env.DASHBOARD_PASSWORD;
  if (!password) return false;
  const auth = req.headers.authorization;
  const providedPw = auth ? auth.replace('Bearer ', '') : '';
  if (!providedPw) return false;
  const providedHash = crypto.createHash('sha256').update(providedPw).digest();
  const expectedHash = crypto.createHash('sha256').update(password).digest();
  return crypto.timingSafeEqual(providedHash, expectedHash);
}

// Send email via Resend API
async function sendEmail(to, subject, html, previewText) {
  const apiKey = process.env.RESEND_API_KEY;
  const fromAddr = process.env.EMAIL_FROM || 'Matrix Shader <noreply@matrixshader.com>';
  if (!apiKey) throw new Error('RESEND_API_KEY not configured');

  const body = { from: fromAddr, to: [to], subject };
  if (previewText) {
    // Invisible preheader trick
    body.html = `<div style="display:none;max-height:0;overflow:hidden">${previewText}</div>` + html;
  } else {
    body.html = html;
  }

  const res = await fetch('https://api.resend.com/emails', {
    method: 'POST',
    headers: { 'Authorization': `Bearer ${apiKey}`, 'Content-Type': 'application/json' },
    body: JSON.stringify(body),
  });

  if (!res.ok) {
    const err = await res.json().catch(() => ({}));
    throw new Error(err.message || `Resend API error ${res.status}`);
  }
  return await res.json();
}

export default async function handler(req, res) {
  res.setHeader('Access-Control-Allow-Origin', 'https://matrixshader.com');
  res.setHeader('Access-Control-Allow-Methods', 'POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization, X-Session');

  if (req.method === 'OPTIONS') return res.status(200).end();
  if (req.method !== 'POST') return res.status(405).json({ error: 'Method not allowed' });

  if (!(await authenticate(req))) {
    return res.status(401).json({ error: 'Unauthorized' });
  }

  const { action } = req.body || {};

  // ── Get config status ──
  if (action === 'config') {
    return res.status(200).json({
      resend_configured: !!process.env.RESEND_API_KEY,
      email_from: process.env.EMAIL_FROM || 'Not set (will use noreply@matrixshader.com)',
      lemonsqueezy_configured: !!process.env.LEMONSQUEEZY_API_KEY,
      owner_email: process.env.OWNER_EMAIL || '',
    });
  }

  // ── Delete subscriber ──
  if (action === 'delete-subscriber') {
    const { email } = req.body;
    if (!email) return res.status(400).json({ error: 'Email required' });
    const key = `sub:${email.trim().toLowerCase()}`;
    await redis.del(key);
    await redis.decr('stats:subscribe');
    return res.status(200).json({ success: true });
  }

  // ── Send test email ──
  if (action === 'send-test') {
    const { subject, body: htmlBody, preview } = req.body;
    const ownerEmail = process.env.OWNER_EMAIL;
    if (!ownerEmail) return res.status(400).json({ error: 'OWNER_EMAIL env var not set' });
    if (!subject || !htmlBody) return res.status(400).json({ error: 'Subject and body required' });

    try {
      const result = await sendEmail(ownerEmail, `[TEST] ${subject}`, htmlBody, preview);
      return res.status(200).json({ success: true, id: result.id });
    } catch (err) {
      return res.status(500).json({ error: err.message });
    }
  }

  // ── Send campaign to all subscribers ──
  if (action === 'send-campaign') {
    const { subject, body: htmlBody, preview } = req.body;
    if (!subject || !htmlBody) return res.status(400).json({ error: 'Subject and body required' });

    // Gather all subscribers
    const subscribers = [];
    let cursor = 0;
    do {
      const [nextCursor, keys] = await redis.scan(cursor, { match: 'sub:*', count: 100 });
      cursor = Number(nextCursor);
      if (keys.length > 0) {
        const values = await redis.mget(...keys);
        for (const val of values) {
          if (val) {
            const data = typeof val === 'string' ? JSON.parse(val) : val;
            if (data.email) subscribers.push(data);
          }
        }
      }
    } while (cursor !== 0);

    if (!subscribers.length) return res.status(400).json({ error: 'No subscribers to send to' });

    // Send to each subscriber
    let sent = 0;
    let failed = 0;
    const errors = [];

    for (const sub of subscribers) {
      try {
        const personalizedHtml = htmlBody.replace(/\{\{name\}\}/g, sub.name || 'Operator');
        await sendEmail(sub.email, subject, personalizedHtml, preview);
        sent++;
      } catch (err) {
        failed++;
        errors.push({ email: sub.email, error: err.message });
      }
    }

    // Save campaign record
    const campaignId = `campaign:${Date.now()}`;
    await redis.set(campaignId, JSON.stringify({
      subject,
      sentAt: new Date().toISOString(),
      total: subscribers.length,
      sent,
      failed,
      errors: errors.slice(0, 5),
    }));

    return res.status(200).json({ success: true, sent, failed, total: subscribers.length });
  }

  // ── Get campaign history ──
  if (action === 'campaigns') {
    const campaigns = [];
    let cursor = 0;
    do {
      const [nextCursor, keys] = await redis.scan(cursor, { match: 'campaign:*', count: 100 });
      cursor = Number(nextCursor);
      if (keys.length > 0) {
        const values = await redis.mget(...keys);
        for (const val of values) {
          if (val) {
            const data = typeof val === 'string' ? JSON.parse(val) : val;
            campaigns.push(data);
          }
        }
      }
    } while (cursor !== 0);

    campaigns.sort((a, b) => (b.sentAt || '').localeCompare(a.sentAt || ''));
    return res.status(200).json({ campaigns });
  }

  return res.status(400).json({ error: 'Unknown action' });
}
