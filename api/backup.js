import { Redis } from '@upstash/redis';
import crypto from 'crypto';
import { initSentry, captureError } from './_sentry.js';

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
    if (keys.length > 0) {
      const values = await redis.mget(...keys);
      for (let i = 0; i < keys.length; i++) {
        const key = keys[i];
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
      // Store compressed backup in Redis with 7-day TTL
      const dateKey = exportedAt.slice(0, 10);
      await redis.set(`backup:${dateKey}`, JSON.stringify(backup), { ex: 604800 }); // 7 days
      await redis.set('backup:latest', exportedAt);
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
