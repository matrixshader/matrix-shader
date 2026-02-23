import crypto from 'crypto';
import { Redis } from '@upstash/redis';
import { initSentry, captureError } from './_sentry.js';

const redis = new Redis({
  url: process.env.KV_REST_API_URL,
  token: process.env.KV_REST_API_TOKEN,
});
const MAX_ACTIVATIONS = 3;

const CHARS = '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ';

function toBase36(bytes, offset, length) {
  let result = '';
  for (let i = 0; i < length; i++) {
    const idx = (offset + i < bytes.length) ? bytes[offset + i] % 36 : 0;
    result += CHARS[idx];
  }
  return result;
}

function verifyKey(key) {
  const secret = process.env.LICENSE_SECRET;
  if (!secret) return false;
  const trimmed = key.trim().toUpperCase();
  // Format: REDPILL-XXXX-XXXX-XXXX-XXXX
  const parts = trimmed.split('-');
  if (parts.length !== 5 || parts[0] !== 'REDPILL') return false;
  // Reconstruct payload (first 4 parts) and verify HMAC signature (5th part)
  const payload = parts.slice(0, 4).join('-');
  const providedSig = parts[4];
  const hmac = crypto.createHmac('sha256', secret).update(payload).digest();
  const expectedSig = toBase36(hmac, 0, 4);
  return providedSig === expectedSig;
}

function hashKey(key) {
  return crypto.createHash('sha256').update(key.trim().toUpperCase()).digest('hex').slice(0, 32);
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
  res.setHeader('Access-Control-Allow-Methods', 'POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');

  if (req.method === 'OPTIONS') {
    return res.status(200).end();
  }

  if (req.method !== 'POST') {
    return res.status(405).json({ error: 'Method not allowed' });
  }

  const ip = (req.headers['x-forwarded-for'] || req.socket?.remoteAddress || 'unknown').split(',')[0].trim();
  if (await rateLimit(ip, 'validate', 10, 60)) {
    return res.status(429).json({ error: 'Too many requests. Try again later.' });
  }

  const { key, fingerprint } = req.body || {};

  if (!key || !fingerprint) {
    return res.status(400).json({ error: 'Missing key or fingerprint' });
  }

  if (typeof fingerprint !== 'string' || fingerprint.length < 8 || fingerprint.length > 64) {
    return res.status(400).json({ error: 'Invalid fingerprint' });
  }

  // Verify key signature before hitting Redis
  if (!verifyKey(key)) {
    return res.status(403).json({
      activated: false,
      error: 'invalid_key',
      message: 'Invalid license key. Check your key and try again.',
    });
  }

  const kvKey = `key:${hashKey(key)}`;

  try {
    let raw = await redis.get(kvKey);
    let record = typeof raw === 'string' ? JSON.parse(raw) : raw;

    // Key has valid signature but not in Redis (webhook race condition or Redis data loss).
    // Create a record so the customer isn't blocked.
    if (!record) {
      record = {
        orderId: 'verified-offline',
        createdAt: new Date().toISOString(),
        activations: [],
      };
    }

    // Check if key has been revoked (refund)
    if (record.revoked) {
      return res.status(403).json({
        activated: false,
        error: 'key_revoked',
        message: 'This license key has been revoked. Contact support if you believe this is an error.',
      });
    }

    const activations = record.activations || [];

    // Check if this fingerprint is already activated (re-activation is OK)
    const existing = activations.find(a => a.fingerprint === fingerprint);
    if (existing) {
      return res.status(200).json({
        activated: true,
        message: 'Already activated on this machine',
        activationCount: activations.length,
        limit: MAX_ACTIVATIONS,
      });
    }

    // Check activation limit
    if (activations.length >= MAX_ACTIVATIONS) {
      return res.status(403).json({
        activated: false,
        error: 'activation_limit',
        message: `This key has been activated on ${activations.length} machines (limit: ${MAX_ACTIVATIONS}). Contact support for help.`,
        activationCount: activations.length,
        limit: MAX_ACTIVATIONS,
      });
    }

    // Add new activation
    activations.push({
      fingerprint,
      activatedAt: new Date().toISOString(),
      ip: (req.headers['x-forwarded-for'] || req.socket?.remoteAddress || 'unknown').split(',')[0].trim(),
    });

    record.activations = activations;
    await Promise.all([
      redis.set(kvKey, JSON.stringify(record)),
      redis.incr('stats:activate'),
    ]);

    return res.status(200).json({
      activated: true,
      message: 'Activation successful',
      activationCount: activations.length,
      limit: MAX_ACTIVATIONS,
    });
  } catch (err) {
    console.error('KV error in /api/validate:', err);
    captureError(err, { endpoint: 'validate' });
    return res.status(503).json({
      activated: false,
      error: 'service_unavailable',
      message: 'Activation server temporarily unavailable. Please try again in a minute.',
    });
  }
}
