import { Redis } from '@upstash/redis';
import crypto from 'crypto';

const redis = new Redis({
  url: process.env.KV_REST_API_URL,
  token: process.env.KV_REST_API_TOKEN,
});

function getLast30Days() {
  const dates = [];
  for (let i = 29; i >= 0; i--) {
    const d = new Date();
    d.setDate(d.getDate() - i);
    dates.push(d.toISOString().slice(0, 10));
  }
  return dates;
}

// TOTP verification using Node.js crypto (no external deps)
function verifyTOTP(secret, token, window = 1) {
  if (!secret || !token) return false;
  const time = Math.floor(Date.now() / 1000 / 30);
  for (let i = -window; i <= window; i++) {
    const timeStep = time + i;
    const buffer = Buffer.alloc(8);
    buffer.writeUInt32BE(0, 0);
    buffer.writeUInt32BE(timeStep, 4);
    const keyBytes = base32Decode(secret);
    const hmac = crypto.createHmac('sha1', keyBytes);
    hmac.update(buffer);
    const hash = hmac.digest();
    const offset = hash[hash.length - 1] & 0x0f;
    const code = ((hash[offset] & 0x7f) << 24 | hash[offset + 1] << 16 | hash[offset + 2] << 8 | hash[offset + 3]) % 1000000;
    const codeStr = code.toString().padStart(6, '0');
    if (crypto.timingSafeEqual(Buffer.from(codeStr), Buffer.from(token))) {
      return true;
    }
  }
  return false;
}

function base32Decode(str) {
  const alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';
  str = str.replace(/[=\s]/g, '').toUpperCase();
  let bits = '';
  for (const c of str) {
    const val = alphabet.indexOf(c);
    if (val === -1) continue;
    bits += val.toString(2).padStart(5, '0');
  }
  const bytes = [];
  for (let i = 0; i + 8 <= bits.length; i += 8) {
    bytes.push(parseInt(bits.slice(i, i + 8), 2));
  }
  return Buffer.from(bytes);
}

function base32Encode(buffer) {
  const alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';
  let bits = '';
  for (const byte of buffer) {
    bits += byte.toString(2).padStart(8, '0');
  }
  let result = '';
  for (let i = 0; i < bits.length; i += 5) {
    const chunk = bits.slice(i, i + 5).padEnd(5, '0');
    result += alphabet[parseInt(chunk, 2)];
  }
  return result;
}

// Get TOTP secret from Redis (self-service) or env var (manual)
async function getTotpSecret() {
  try {
    const fromRedis = await redis.get('totp:secret');
    if (fromRedis) return fromRedis;
  } catch { /* fall through */ }
  return process.env.TOTP_SECRET || null;
}

export default async function handler(req, res) {
  res.setHeader('Access-Control-Allow-Origin', 'https://matrixshader.com');
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization, X-TOTP, X-Session');

  if (req.method === 'OPTIONS') {
    return res.status(200).end();
  }

  if (req.method !== 'GET' && req.method !== 'POST') {
    return res.status(405).json({ error: 'Method not allowed' });
  }

  // IP from Vercel headers (x-forwarded-for) or fallback
  const ip = (req.headers['x-forwarded-for'] || req.socket?.remoteAddress || 'unknown').split(',')[0].trim();

  // Auth: session token first, then full password+TOTP
  let authenticated = false;
  let newSessionToken = null;
  const totpSecret = await getTotpSecret();

  // Session-based auth (auto-refresh) — not rate limited
  const sessionHeader = req.headers['x-session'];
  if (sessionHeader) {
    try {
      const valid = await redis.get(`session:${sessionHeader}`);
      if (valid === 'active') authenticated = true;
    } catch { /* fall through to full auth */ }
  }

  if (!authenticated) {
    // IP rate limit: 5 failed attempts → locked for 15 minutes
    const rlKey = `ratelimit:${ip}`;
    try {
      const failures = Number(await redis.get(rlKey)) || 0;
      if (failures >= 5) {
        return res.status(429).json({ error: 'Too many failed attempts. Try again in 15 minutes.' });
      }
    } catch { /* allow through if Redis fails */ }

    const password = process.env.DASHBOARD_PASSWORD;
    if (!password) {
      return res.status(500).json({ error: 'Dashboard not configured' });
    }

    const auth = req.headers.authorization;
    const providedPw = auth ? auth.replace('Bearer ', '') : '';
    // Hash both before comparing to prevent password-length timing leak
    const providedHash = providedPw ? crypto.createHash('sha256').update(providedPw).digest() : Buffer.alloc(32);
    const expectedHash = crypto.createHash('sha256').update(password).digest();
    if (!providedPw || !crypto.timingSafeEqual(providedHash, expectedHash)) {
      try { await redis.incr(rlKey); await redis.expire(rlKey, 900); } catch { /* best effort */ }
      return res.status(401).json({ error: 'Unauthorized' });
    }

    if (totpSecret) {
      const totpCode = req.headers['x-totp'] || '';
      if (!totpCode) {
        // No TOTP provided — tell client to show TOTP field (don't count as failure)
        return res.status(401).json({ error: 'Enter 2FA code', requires_totp: true });
      }
      if (!verifyTOTP(totpSecret, totpCode)) {
        // Wrong TOTP code — count as failure + log breach attempt (password was correct!)
        try {
          await redis.incr(rlKey);
          await redis.expire(rlKey, 900);
          await redis.lpush('alert:totp_breach', JSON.stringify({
            ip, timestamp: new Date().toISOString(), type: 'totp_fail',
          }));
          await redis.ltrim('alert:totp_breach', 0, 49); // keep last 50
        } catch { /* best effort */ }
        return res.status(401).json({ error: 'Invalid 2FA code', requires_totp: true });
      }
    }

    // Successful auth — clear rate limit for this IP
    try { await redis.del(rlKey); } catch { /* best effort */ }

    newSessionToken = crypto.randomBytes(32).toString('hex');
    await redis.set(`session:${newSessionToken}`, 'active', { ex: 14400 });
  }

  // ── POST: TOTP management ──
  if (req.method === 'POST') {
    const { action, secret, code } = req.body || {};

    if (action === 'totp-setup') {
      // Generate a new 20-byte secret
      const secretBytes = crypto.randomBytes(20);
      const secretB32 = base32Encode(secretBytes);
      const uri = `otpauth://totp/MatrixShader:admin?secret=${secretB32}&issuer=MatrixShader&algorithm=SHA1&digits=6&period=30`;
      const response = { secret: secretB32, uri };
      if (newSessionToken) response.session_token = newSessionToken;
      return res.status(200).json(response);
    }

    if (action === 'totp-verify') {
      if (!secret || !code) {
        return res.status(400).json({ error: 'Secret and code required' });
      }
      if (!verifyTOTP(secret, code)) {
        return res.status(400).json({ error: 'Invalid code. Check your app and try again.' });
      }
      // Save to Redis (permanent — no TTL)
      await redis.set('totp:secret', secret);
      const response = { success: true };
      if (newSessionToken) response.session_token = newSessionToken;
      return res.status(200).json(response);
    }

    if (action === 'totp-disable') {
      if (!code) {
        return res.status(400).json({ error: 'Enter your current 2FA code to disable' });
      }
      if (!totpSecret || !verifyTOTP(totpSecret, code)) {
        return res.status(400).json({ error: 'Invalid code' });
      }
      await redis.del('totp:secret');
      const response = { success: true };
      if (newSessionToken) response.session_token = newSessionToken;
      return res.status(200).json(response);
    }

    return res.status(400).json({ error: 'Unknown action' });
  }

  // ── GET: Dashboard data ──
  try {
    // 1. Totals
    const statKeys = [
      'stats:download', 'stats:install', 'stats:activate',
      'stats:subscribe', 'stats:purchase',
      'stats:page_view', 'stats:redpill_click', 'stats:github_click',
    ];
    const statValues = await redis.mget(...statKeys);
    const totals = {
      downloads: Number(statValues[0]) || 0,
      installs: Number(statValues[1]) || 0,
      activations: Number(statValues[2]) || 0,
      subscribers: Number(statValues[3]) || 0,
      purchases: Number(statValues[4]) || 0,
      page_views: Number(statValues[5]) || 0,
      redpill_clicks: Number(statValues[6]) || 0,
      github_clicks: Number(statValues[7]) || 0,
    };

    // 2. Time-series (last 30 days)
    const dates = getLast30Days();
    const tsEvents = ['page_view', 'download', 'install', 'activate', 'redpill_click', 'github_click', 'subscribe', 'purchase'];
    const tsKeys = [];
    for (const event of tsEvents) {
      for (const date of dates) {
        tsKeys.push(`ts:${event}:${date}`);
      }
    }

    const tsValues = tsKeys.length > 0 ? await redis.mget(...tsKeys) : [];
    const timeseries = {};
    let idx = 0;
    for (const event of tsEvents) {
      timeseries[event] = [];
      for (const date of dates) {
        timeseries[event].push({ date, count: Number(tsValues[idx]) || 0 });
        idx++;
      }
    }

    // 3. Subscribers (scan for sub:* keys)
    const subscribers = [];
    let subCursor = 0;
    do {
      const [nextCursor, keys] = await redis.scan(subCursor, { match: 'sub:*', count: 100 });
      subCursor = Number(nextCursor);
      if (keys.length > 0) {
        const values = await redis.mget(...keys);
        for (const val of values) {
          if (val) {
            const data = typeof val === 'string' ? JSON.parse(val) : val;
            subscribers.push({
              email: data.email || '',
              name: data.name || '',
              source: data.source || '',
              subscribedAt: data.subscribedAt || '',
            });
          }
        }
      }
    } while (subCursor !== 0);

    subscribers.sort((a, b) => (b.subscribedAt || '').localeCompare(a.subscribedAt || ''));

    // 4. Licenses (scan for key:* keys)
    const licenses = [];
    let keyCursor = 0;
    do {
      const [nextCursor, keys] = await redis.scan(keyCursor, { match: 'key:*', count: 100 });
      keyCursor = Number(nextCursor);
      if (keys.length > 0) {
        const values = await redis.mget(...keys);
        for (const val of values) {
          if (val) {
            const data = typeof val === 'string' ? JSON.parse(val) : val;
            licenses.push({
              orderId: data.orderId || '',
              email: data.email || '',
              buyerName: data.buyerName || '',
              createdAt: data.createdAt || '',
              activationCount: Array.isArray(data.activations) ? data.activations.length : 0,
            });
          }
        }
      }
    } while (keyCursor !== 0);

    licenses.sort((a, b) => (b.createdAt || '').localeCompare(a.createdAt || ''));

    // 5. Funnel
    const conversionRate = totals.page_views > 0
      ? ((totals.purchases / totals.page_views) * 100).toFixed(2) + '%'
      : '0%';

    const funnel = {
      page_views: totals.page_views,
      redpill_clicks: totals.redpill_clicks,
      downloads: totals.downloads,
      purchases: totals.purchases,
      conversion_rate: conversionRate,
    };

    // 6. Security alerts (TOTP breach attempts)
    let security_alerts = [];
    try {
      const raw = await redis.lrange('alert:totp_breach', 0, 9); // last 10
      security_alerts = raw.map(r => typeof r === 'string' ? JSON.parse(r) : r);
    } catch { /* best effort */ }

    const response = { totals, timeseries, subscribers, licenses, funnel, totp_enabled: !!totpSecret, security_alerts };
    if (newSessionToken) response.session_token = newSessionToken;
    return res.status(200).json(response);
  } catch (err) {
    console.error('Dashboard error:', err);
    return res.status(500).json({ error: 'Failed to load dashboard data' });
  }
}
