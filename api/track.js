import { Redis } from '@upstash/redis';

const redis = new Redis({
  url: process.env.KV_REST_API_URL,
  token: process.env.KV_REST_API_TOKEN,
});

export default async function handler(req, res) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');

  if (req.method === 'OPTIONS') {
    return res.status(200).end();
  }

  // POST /api/track?event=download — increment a counter
  if (req.method === 'POST') {
    const event = req.query.event || req.body?.event;
    if (!event || typeof event !== 'string' || event.length > 32) {
      return res.status(400).json({ error: 'Missing or invalid event name' });
    }

    const allowed = ['download', 'install', 'activate'];
    if (!allowed.includes(event)) {
      return res.status(400).json({ error: `Unknown event. Allowed: ${allowed.join(', ')}` });
    }

    try {
      const count = await redis.incr(`stats:${event}`);
      return res.status(200).json({ event, count });
    } catch (err) {
      console.error('Track error:', err);
      return res.status(200).json({ event, count: -1 });
    }
  }

  // GET /api/track — return all stats
  if (req.method === 'GET') {
    try {
      const [downloads, installs, activations] = await Promise.all([
        redis.get('stats:download'),
        redis.get('stats:install'),
        redis.get('stats:activate'),
      ]);

      return res.status(200).json({
        downloads: Number(downloads) || 0,
        installs: Number(installs) || 0,
        activations: Number(activations) || 0,
      });
    } catch (err) {
      console.error('Stats error:', err);
      return res.status(200).json({ downloads: 0, installs: 0, activations: 0 });
    }
  }

  return res.status(405).json({ error: 'Method not allowed' });
}
