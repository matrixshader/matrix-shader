import { Redis } from '@upstash/redis';
import { initSentry, captureError } from './_sentry.js';

const redis = new Redis({
  url: process.env.KV_REST_API_URL,
  token: process.env.KV_REST_API_TOKEN,
});

function todayKey() {
  return new Date().toISOString().slice(0, 10);
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
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');

  if (req.method === 'OPTIONS') {
    return res.status(200).end();
  }

  // POST /api/track?event=download — increment a counter + daily time-series
  if (req.method === 'POST') {
    const ip = (req.headers['x-forwarded-for'] || req.socket?.remoteAddress || 'unknown').split(',')[0].trim();
    if (await rateLimit(ip, 'track', 30, 60)) {
      return res.status(429).json({ error: 'Too many requests' });
    }

    const event = req.query.event || req.body?.event;
    if (!event || typeof event !== 'string' || event.length > 32) {
      return res.status(400).json({ error: 'Missing or invalid event name' });
    }

    const allowed = ['download', 'install', 'activate', 'page_view', 'redpill_click', 'github_click'];
    if (!allowed.includes(event)) {
      return res.status(400).json({ error: `Unknown event. Allowed: ${allowed.join(', ')}` });
    }

    try {
      const [count] = await Promise.all([
        redis.incr(`stats:${event}`),
        redis.incr(`ts:${event}:${todayKey()}`),
      ]);
      return res.status(200).json({ event, count });
    } catch (err) {
      console.error('Track error:', err);
      captureError(err, { endpoint: 'track', event });
      return res.status(200).json({ event, count: -1 });
    }
  }

  // GET /api/track — return all stats (or operator count)
  if (req.method === 'GET') {
    // Read operator count for pre-checkout animation
    if (req.query.event === 'operator_count' && req.query.read === '1') {
      try {
        const count = Number(await redis.get('stats:customer_number')) || 0;
        return res.status(200).json({ count });
      } catch (err) {
        return res.status(200).json({ count: 0 });
      }
    }

    try {
      const keys = [
        'stats:download', 'stats:install', 'stats:activate',
        'stats:subscribe', 'stats:purchase',
        'stats:page_view', 'stats:redpill_click', 'stats:github_click',
      ];
      const values = await redis.mget(...keys);

      return res.status(200).json({
        downloads: Number(values[0]) || 0,
        installs: Number(values[1]) || 0,
        activations: Number(values[2]) || 0,
        subscribers: Number(values[3]) || 0,
        purchases: Number(values[4]) || 0,
        page_views: Number(values[5]) || 0,
        redpill_clicks: Number(values[6]) || 0,
        github_clicks: Number(values[7]) || 0,
      });
    } catch (err) {
      console.error('Stats error:', err);
      captureError(err, { endpoint: 'track', action: 'stats' });
      return res.status(200).json({ downloads: 0, installs: 0, activations: 0 });
    }
  }

  return res.status(405).json({ error: 'Method not allowed' });
}
