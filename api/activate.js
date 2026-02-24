import crypto from 'crypto';
import { Redis } from '@upstash/redis';
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

const CHARS = '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ';

function toBase36(bytes, offset, length) {
  let result = '';
  for (let i = 0; i < length; i++) {
    const idx = (offset + i < bytes.length) ? bytes[offset + i] % 36 : 0;
    result += CHARS[idx];
  }
  return result;
}

function generateKey(seed, secret) {
  // SHA256 hash the seed to get 3 groups
  const hash = crypto.createHash('sha256').update(seed).digest();
  const g1 = toBase36(hash, 0, 4);
  const g2 = toBase36(hash, 4, 4);
  const g3 = toBase36(hash, 8, 4);

  const payload = `REDPILL-${g1}-${g2}-${g3}`;

  // HMAC-SHA256 signature (truncated to 4 base36 chars)
  const hmac = crypto.createHmac('sha256', secret).update(payload).digest();
  const sig = toBase36(hmac, 0, 4);

  return `${payload}-${sig}`;
}

async function validateOrder(orderId, apiKey) {
  const res = await fetch(`https://api.lemonsqueezy.com/v1/orders/${orderId}`, {
    headers: {
      'Authorization': `Bearer ${apiKey}`,
      'Accept': 'application/vnd.api+json',
    },
  });

  if (!res.ok) return null;

  const data = await res.json();
  const order = data?.data;

  if (!order) return null;

  // Verify order is paid
  const status = order.attributes?.status;
  if (status !== 'paid' && status !== 'refunded') return null;

  return {
    id: order.id,
    status,
    email: order.attributes?.user_email,
    created: order.attributes?.created_at,
  };
}

export default async function handler(req, res) {
  initSentry();
  // CORS headers for the thank-you page
  res.setHeader('Access-Control-Allow-Origin', 'https://matrixshader.com');
  res.setHeader('Access-Control-Allow-Methods', 'GET, OPTIONS');

  if (req.method === 'OPTIONS') {
    return res.status(200).end();
  }

  if (req.method !== 'GET') {
    return res.status(405).json({ error: 'Method not allowed' });
  }

  const ip = (req.headers['x-forwarded-for'] || req.socket?.remoteAddress || 'unknown').split(',')[0].trim();
  if (await rateLimit(ip, 'activate', 10, 60)) {
    return res.status(429).json({ error: 'Too many requests. Try again later.' });
  }

  const orderId = req.query.order_id;
  if (!orderId) {
    return res.status(400).json({ error: 'Missing order_id parameter' });
  }

  const secret = process.env.LICENSE_SECRET;
  const apiKey = process.env.LEMONSQUEEZY_API_KEY;

  if (!secret || !apiKey) {
    console.error('Missing LICENSE_SECRET or LEMONSQUEEZY_API_KEY env vars');
    return res.status(500).json({ error: 'Server configuration error' });
  }

  // Validate the order with LemonSqueezy
  const order = await validateOrder(orderId, apiKey);
  if (!order) {
    return res.status(404).json({ error: 'Order not found or not paid' });
  }

  if (order.status === 'refunded') {
    return res.status(403).json({ error: 'Order has been refunded' });
  }

  // Generate deterministic key from order ID
  // Prefix with LS- so MS Store orders (MS-xxx) get different keys
  const seed = `LS-${orderId}`;
  const key = generateKey(seed, secret);

  // Store key metadata in KV for activation tracking
  const keyHash = crypto.createHash('sha256').update(key).digest('hex').slice(0, 32);
  let customerNumber = null;
  try {
    const existing = await redis.get(`key:${keyHash}`);
    if (!existing) {
      customerNumber = await redis.incr('stats:customer_number');
      await redis.set(`key:${keyHash}`, JSON.stringify({
        orderId: `LS-${orderId}`,
        customerNumber,
        createdAt: new Date().toISOString(),
        activations: [],
      }));
    } else {
      const data = typeof existing === 'string' ? JSON.parse(existing) : existing;
      customerNumber = data.customerNumber || null;
    }
  } catch (err) {
    // KV failure should not block key generation
    console.error('KV store error:', err);
    captureError(err, { endpoint: 'activate', orderId });
  }

  const response = {
    key,
    order_id: orderId,
    message: 'Run: redpill --activate ' + key,
  };
  if (customerNumber) response.customer_number = customerNumber;
  return res.status(200).json(response);
}
