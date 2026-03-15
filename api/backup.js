import { Redis } from '@upstash/redis';
import crypto from 'crypto';
import { initSentry, captureError } from './_sentry.js';

if (!process.env.KV_REST_API_URL || !process.env.KV_REST_API_TOKEN) {
  console.error('FATAL: KV_REST_API_URL and KV_REST_API_TOKEN must be set');
}

const redis = new Redis({
  url: process.env.KV_REST_API_URL,
  token: process.env.KV_REST_API_TOKEN,
});

async function authenticate(req) {
  // Session-based auth
  const sessionHeader = req.headers['x-session'];
  if (sessionHeader) {
    try {
      const valid = await redis.get(`session:${sessionHeader}`);
      if (valid === 'active') return true;
    } catch { /* fall through */ }
  }

  // Bearer token auth
  const auth = req.headers.authorization;
  if (!auth) return false;
  const password = process.env.DASHBOARD_PASSWORD;
  if (!password) return false;
  const provided = auth.replace('Bearer ', '');
  const providedHash = crypto.createHash('sha256').update(provided).digest();
  const expectedHash = crypto.createHash('sha256').update(password).digest();
  return crypto.timingSafeEqual(providedHash, expectedHash);
}

async function exportAllKeys() {
  const data = {};
  let cursor = 0;
  do {
    const [nextCursor, keys] = await redis.scan(cursor, { count: 100 });
    cursor = Number(nextCursor);
    // Filter out backup keys to prevent recursive backup-of-backups growth
    const filtered = keys.filter(k =>
      !k.startsWith('backup:') &&
      !k.startsWith('rl:') &&
      !k.startsWith('ratelimit:') &&
      !k.startsWith('session:')
    );
    if (filtered.length > 0) {
      const values = await redis.mget(...filtered);
      for (let i = 0; i < filtered.length; i++) {
        const key = filtered[i];
        let value = values[i];
        // Try to parse JSON strings
        if (typeof value === 'string') {
          try { value = JSON.parse(value); } catch { /* keep as string */ }
        }
        let ttl = -1;
        try { ttl = await redis.ttl(key); } catch { /* best effort */ }
        data[key] = { value, ttl };
      }
    }
  } while (cursor !== 0);
  return data;
}

export default async function handler(req, res) {
  initSentry();
  res.setHeader('Access-Control-Allow-Origin', 'https://matrixshader.com');
  res.setHeader('Access-Control-Allow-Methods', 'GET, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization, X-Session');

  if (req.method === 'OPTIONS') {
    return res.status(200).end();
  }

  if (req.method !== 'GET') {
    return res.status(405).json({ error: 'Method not allowed' });
  }

  const isAuto = req.query.auto === '1';

  // Auth: manual = Bearer/session, auto = CRON_SECRET header
  if (isAuto) {
    const cronSecret = process.env.CRON_SECRET;
    const provided = req.headers.authorization;
    if (!cronSecret || provided !== `Bearer ${cronSecret}`) {
      return res.status(401).json({ error: 'Unauthorized' });
    }
  } else {
    const authed = await authenticate(req);
    if (!authed) {
      return res.status(401).json({ error: 'Unauthorized' });
    }
  }

  try {
    const data = await exportAllKeys();
    const keyCount = Object.keys(data).length;
    const exportedAt = new Date().toISOString();
    const backup = { exportedAt, keyCount, data };

    if (isAuto) {
      const dateKey = exportedAt.slice(0, 10);

      // Store backup in Redis with 7-day TTL (safety net if email fails).
      // exportAllKeys() filters out backup:* keys to prevent recursive growth.
      await redis.set(`backup:${dateKey}`, JSON.stringify(backup), { ex: 604800 });
      await redis.set('backup:latest', exportedAt);

      // Also email backup offsite so it survives Redis data loss
      const resendKey = process.env.RESEND_API_KEY;
      const ownerEmail = process.env.OWNER_EMAIL;
      const fromAddr = process.env.EMAIL_FROM || 'Matrix Shader <noreply@matrixshader.com>';
      if (resendKey && ownerEmail) {
        try {
          const jsonStr = JSON.stringify(backup, null, 2);
          const emailRes = await fetch('https://api.resend.com/emails', {
            method: 'POST',
            headers: { 'Authorization': `Bearer ${resendKey}`, 'Content-Type': 'application/json' },
            body: JSON.stringify({
              from: fromAddr,
              to: [ownerEmail],
              subject: `MatrixShader backup ${dateKey} — ${keyCount} keys`,
              html: `<pre style="background:#000;color:#00ff41;padding:1rem;font-size:12px;max-height:600px;overflow:auto">${jsonStr.length > 50000 ? jsonStr.slice(0, 50000) + '\n... truncated ...' : jsonStr}</pre>`,
              attachments: [{
                filename: `matrixshader-backup-${dateKey}.json`,
                content: Buffer.from(jsonStr).toString('base64'),
              }],
            }),
          });
          if (!emailRes.ok) {
            const errBody = await emailRes.text().catch(() => '');
            console.error(`Backup email failed (${emailRes.status}): ${errBody}`);
            captureError(new Error(`Backup email ${emailRes.status}`), { endpoint: 'backup' });
          }
        } catch (emailErr) {
          console.error('Backup email failed:', emailErr);
          captureError(emailErr, { endpoint: 'backup', action: 'email' });
        }
      }

      return res.status(200).json({ success: true, exportedAt, keyCount });
    }

    // Manual download
    const dateStr = exportedAt.slice(0, 10);
    res.setHeader('Content-Type', 'application/json');
    res.setHeader('Content-Disposition', `attachment; filename=matrixshader-backup-${dateStr}.json`);
    return res.status(200).json(backup);
  } catch (err) {
    console.error('Backup error:', err);
    captureError(err, { endpoint: 'backup' });
    return res.status(500).json({ error: 'Backup failed' });
  }
}
