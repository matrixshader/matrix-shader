import { Redis } from '@upstash/redis';
import { initSentry, captureError } from './_sentry.js';

const redis = new Redis({
  url: process.env.KV_REST_API_URL,
  token: process.env.KV_REST_API_TOKEN,
});

function isValidEmail(email) {
  return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email) && email.length <= 254;
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

  const ip = (req.headers['x-forwarded-for'] || req.socket?.remoteAddress || 'unknown').split(',')[0].trim();
  if (await rateLimit(ip, 'unsub', 5, 3600)) {
    if (req.method === 'GET') {
      return res.status(200).send(unsubscribePage('Too many requests. Try again later.'));
    }
    return res.status(429).json({ error: 'Too many requests. Try again later.' });
  }

  // GET /api/unsubscribe?email=xxx — one-click unsubscribe from email links
  // POST /api/unsubscribe — form submission
  const email = req.method === 'GET'
    ? req.query.email
    : (req.body || {}).email;

  if (!email || !isValidEmail(email)) {
    if (req.method === 'GET') {
      return res.status(200).send(unsubscribePage('Invalid or missing email address.'));
    }
    return res.status(400).json({ error: 'Valid email required' });
  }

  const normalizedEmail = email.trim().toLowerCase();
  const emailKey = `sub:${normalizedEmail}`;

  try {
    const existed = await redis.del(emailKey);
    if (existed) await redis.decr('stats:subscribe');
    if (req.method === 'GET') {
      return res.status(200).send(unsubscribePage(
        existed ? 'You have been unsubscribed.' : 'Email not found in our list.'
      ));
    }
    return res.status(200).json({
      unsubscribed: !!existed,
      message: existed ? 'You have been unsubscribed.' : 'Email not found in our list.',
    });
  } catch (err) {
    console.error('Unsubscribe error:', err);
    captureError(err, { endpoint: 'unsubscribe' });
    if (req.method === 'GET') {
      return res.status(200).send(unsubscribePage('Something went wrong. Please try again or email matrixshader@protonmail.com.'));
    }
    return res.status(500).json({ error: 'Server error' });
  }
}

function unsubscribePage(message) {
  return `<!DOCTYPE html>
<html lang="en"><head>
<meta charset="UTF-8"><meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Unsubscribe - MatrixShader</title>
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
