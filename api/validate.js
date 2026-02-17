import crypto from 'crypto';
import { Redis } from '@upstash/redis';

const redis = new Redis({
  url: process.env.KV_REST_API_URL,
  token: process.env.KV_REST_API_TOKEN,
});
const MAX_ACTIVATIONS = 3;

function hashKey(key) {
  return crypto.createHash('sha256').update(key.trim().toUpperCase()).digest('hex').slice(0, 32);
}

export default async function handler(req, res) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');

  if (req.method === 'OPTIONS') {
    return res.status(200).end();
  }

  if (req.method !== 'POST') {
    return res.status(405).json({ error: 'Method not allowed' });
  }

  const { key, fingerprint } = req.body || {};

  if (!key || !fingerprint) {
    return res.status(400).json({ error: 'Missing key or fingerprint' });
  }

  if (typeof fingerprint !== 'string' || fingerprint.length < 8 || fingerprint.length > 64) {
    return res.status(400).json({ error: 'Invalid fingerprint' });
  }

  const kvKey = `key:${hashKey(key)}`;

  try {
    let raw = await redis.get(kvKey);
    let record = typeof raw === 'string' ? JSON.parse(raw) : raw;

    // Key not in KV — could be a pre-existing key activated before this system.
    // Allow it through (backward compatibility).
    if (!record) {
      record = {
        orderId: 'legacy',
        createdAt: new Date().toISOString(),
        activations: [],
      };
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
    // If KV is down, allow activation (graceful degradation on server side too)
    return res.status(200).json({
      activated: true,
      message: 'Activation accepted (offline)',
      activationCount: -1,
      limit: MAX_ACTIVATIONS,
    });
  }
}
