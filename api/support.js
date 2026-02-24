import { Redis } from '@upstash/redis';
import crypto from 'crypto';
import { initSentry, captureError } from './_sentry.js';

const redis = new Redis({
  url: process.env.KV_REST_API_URL,
  token: process.env.KV_REST_API_TOKEN,
});

async function rateLimit(ip, prefix, limit, windowSec) {
  const key = `rl:${prefix}:${ip}`;
  try {
    const count = await redis.incr(key);
    if (count === 1) await redis.expire(key, windowSec);
    return count > limit;
  } catch { return false; }
}

function validEmail(e) {
  return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(e) && e.length <= 254;
}

export default async function handler(req, res) {
  initSentry();
  res.setHeader('Access-Control-Allow-Origin', 'https://matrixshader.com');
  res.setHeader('Access-Control-Allow-Methods', 'POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');

  if (req.method === 'OPTIONS') return res.status(200).end();
  if (req.method !== 'POST') return res.status(405).json({ error: 'Method not allowed' });

  const ip = (req.headers['x-forwarded-for'] || req.socket?.remoteAddress || 'unknown').split(',')[0].trim();
  if (await rateLimit(ip, 'support', 5, 3600)) {
    return res.status(429).json({ error: 'Too many requests. Try again later.' });
  }

  const { email, type, description, system } = req.body || {};

  if (!email || !validEmail(email)) {
    return res.status(400).json({ error: 'Valid email required' });
  }
  if (!description || description.length < 10 || description.length > 2000) {
    return res.status(400).json({ error: 'Description must be 10-2000 characters' });
  }

  const allowedTypes = ['bug', 'feature', 'retain'];
  const ticketType = allowedTypes.includes(type) ? type : 'general';

  const id = crypto.randomBytes(4).toString('hex');
  const record = {
    id,
    type: ticketType,
    email: email.trim().toLowerCase(),
    description: description.trim(),
    system: (system || '').trim().slice(0, 500),
    status: 'open',
    submittedAt: new Date().toISOString(),
  };

  try {
    await redis.set(`support:${id}`, JSON.stringify(record));
    return res.status(201).json({ id, message: 'Received' });
  } catch (err) {
    console.error('Support submit error:', err);
    captureError(err, { endpoint: 'support' });
    return res.status(500).json({ error: 'Failed to save ticket' });
  }
}
