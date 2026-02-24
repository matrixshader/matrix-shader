import crypto from 'crypto';
import { Redis } from '@upstash/redis';
import { initSentry, captureError } from './_sentry.js';

const redis = new Redis({
  url: process.env.KV_REST_API_URL,
  token: process.env.KV_REST_API_TOKEN,
});

function isValidEmail(email) {
  return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email) && email.length <= 254;
}

async function syncToLemonSqueezy(email, name) {
  const apiKey = process.env.LEMONSQUEEZY_API_KEY;
  const storeId = process.env.LEMONSQUEEZY_STORE_ID;
  if (!apiKey || !storeId) return;

  try {
    await fetch('https://api.lemonsqueezy.com/v1/customers', {
      method: 'POST',
      headers: {
        'Accept': 'application/vnd.api+json',
        'Content-Type': 'application/vnd.api+json',
        'Authorization': `Bearer ${apiKey}`,
      },
      body: JSON.stringify({
        data: {
          type: 'customers',
          attributes: {
            name: name || 'Operator',
            email: email,
          },
          relationships: {
            store: {
              data: { type: 'stores', id: storeId },
            },
          },
        },
      }),
    });
  } catch {
    // Best-effort sync — don't fail the subscription if LS is down
  }
}

async function sendConfirmationEmail(email, token) {
  const apiKey = process.env.RESEND_API_KEY;
  const fromAddr = process.env.EMAIL_FROM || 'Matrix Shader <noreply@matrixshader.com>';
  if (!apiKey) return false;

  const confirmUrl = `https://matrixshader.com/api/subscribe?confirm=${token}`;
  const html = `<div style="background:#000;color:#00ff41;font-family:'Courier New',monospace;padding:2rem;text-align:center">
<h2 style="color:#00ff41;text-shadow:0 0 10px rgba(0,255,65,0.5)">Confirm your subscription</h2>
<p style="color:#ccc;margin:1rem 0">Click below to confirm your MatrixShader subscription.</p>
<a href="${confirmUrl}" style="display:inline-block;padding:12px 24px;background:#00ff41;color:#000;text-decoration:none;font-weight:bold;border-radius:6px;margin:1rem 0">Confirm</a>
<p style="color:#555;font-size:0.8rem;margin-top:2rem">Didn't sign up? Just ignore this email.</p>
</div>`;

  try {
    const res = await fetch('https://api.resend.com/emails', {
      method: 'POST',
      headers: { 'Authorization': `Bearer ${apiKey}`, 'Content-Type': 'application/json' },
      body: JSON.stringify({ from: fromAddr, to: [email], subject: 'Confirm your MatrixShader subscription', html }),
    });
    return res.ok;
  } catch {
    return false;
  }
}

async function rateLimit(ip, prefix, limit, windowSec) {
  const key = `rl:${prefix}:${ip}`;
  try {
    const count = await redis.incr(key);
    if (count === 1) await redis.expire(key, windowSec);
    return count > limit;
  } catch { return false; }
}

export default async function handler(req, res) {
  initSentry();
  res.setHeader('Access-Control-Allow-Origin', 'https://matrixshader.com');
  res.setHeader('Access-Control-Allow-Methods', 'POST, GET, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');

  if (req.method === 'OPTIONS') {
    return res.status(200).end();
  }

  // GET /api/subscribe?confirm=TOKEN — double opt-in confirmation
  if (req.method === 'GET' && req.query.confirm) {
    const token = req.query.confirm;
    try {
      const raw = await redis.get(`pending-sub:${token}`);
      if (!raw) {
        return res.status(200).send(confirmPage('This link has expired or was already used.'));
      }
      const data = typeof raw === 'string' ? JSON.parse(raw) : raw;
      const emailKey = `sub:${data.email}`;

      // Check if already confirmed
      const existing = await redis.get(emailKey);
      if (existing) {
        await redis.del(`pending-sub:${token}`);
        return res.status(200).send(confirmPage('Already confirmed. You\'re in.'));
      }

      await Promise.all([
        redis.set(emailKey, JSON.stringify({
          email: data.email,
          name: data.name || '',
          source: data.source || 'website',
          subscribedAt: new Date().toISOString(),
          confirmed: true,
        })),
        redis.incr('stats:subscribe'),
        redis.del(`pending-sub:${token}`),
        syncToLemonSqueezy(data.email, data.name),
      ]);

      return res.status(200).send(confirmPage('Subscription confirmed. Welcome, Operator.'));
    } catch (err) {
      console.error('Confirm error:', err);
      captureError(err, { endpoint: 'subscribe', action: 'confirm' });
      return res.status(200).send(confirmPage('Something went wrong. Try again or email hello@matrixshader.com.'));
    }
  }

  if (req.method !== 'POST') {
    return res.status(405).json({ error: 'Method not allowed' });
  }

  const ip = (req.headers['x-forwarded-for'] || req.socket?.remoteAddress || 'unknown').split(',')[0].trim();
  if (await rateLimit(ip, 'sub', 5, 3600)) {
    return res.status(429).json({ error: 'Too many requests. Try again later.' });
  }

  const { email, source, name } = req.body || {};

  if (!email || !isValidEmail(email)) {
    return res.status(400).json({ error: 'Valid email required' });
  }

  const normalizedEmail = email.trim().toLowerCase();
  const emailKey = `sub:${normalizedEmail}`;

  try {
    const existing = await redis.get(emailKey);
    if (existing) {
      return res.status(200).json({ subscribed: true, message: 'Already subscribed' });
    }

    // Generate confirmation token and store pending subscription (24h TTL)
    const token = crypto.randomBytes(24).toString('hex');
    await redis.set(`pending-sub:${token}`, JSON.stringify({
      email: normalizedEmail,
      name: name || '',
      source: source || 'website',
    }), { ex: 86400 });

    // Send confirmation email — if Resend isn't configured, fall back to immediate subscribe
    const sent = await sendConfirmationEmail(normalizedEmail, token);
    if (!sent) {
      // Resend not configured — subscribe immediately (old behavior)
      await redis.del(`pending-sub:${token}`);
      await Promise.all([
        redis.set(emailKey, JSON.stringify({
          email: normalizedEmail,
          name: name || '',
          source: source || 'website',
          subscribedAt: new Date().toISOString(),
          confirmed: false,
        })),
        redis.incr('stats:subscribe'),
        syncToLemonSqueezy(normalizedEmail, name),
      ]);
    }

    // Return subscribed:true either way so the email gate opens
    return res.status(200).json({ subscribed: true, message: sent ? 'Check your email to confirm' : 'Welcome to MatrixShader' });
  } catch (err) {
    console.error('Subscribe error:', err);
    captureError(err, { endpoint: 'subscribe' });
    return res.status(500).json({ error: 'Server error' });
  }
}

function confirmPage(message) {
  return `<!DOCTYPE html>
<html lang="en"><head>
<meta charset="UTF-8"><meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Confirm - MatrixShader</title>
<style>
  body { background: #000; color: #00ff41; font-family: 'Courier New', monospace; display: flex; justify-content: center; align-items: center; min-height: 100vh; margin: 0; }
  .box { text-align: center; padding: 2rem; border: 1px solid rgba(0,255,65,0.2); border-radius: 12px; max-width: 400px; }
  h1 { font-size: 1.2rem; margin-bottom: 1rem; }
  p { color: #ccc; font-size: 0.9rem; line-height: 1.6; }
  a { color: #00ff41; }
</style>
</head><body>
<div class="box">
  <h1>MatrixShader</h1>
  <p>${message}</p>
  <p style="margin-top:1.5rem"><a href="https://matrixshader.com">Back to MatrixShader</a></p>
</div>
</body></html>`;
}
