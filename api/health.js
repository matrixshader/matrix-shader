import { Redis } from '@upstash/redis';

const redis = new Redis({
  url: process.env.KV_REST_API_URL,
  token: process.env.KV_REST_API_TOKEN,
});

export default async function handler(req, res) {
  if (req.method !== 'GET' && req.method !== 'HEAD') {
    return res.status(405).json({ error: 'Method not allowed' });
  }

  const start = Date.now();
  try {
    await redis.ping();
    const latency = Date.now() - start;
    return res.status(200).json({ status: 'ok', redis: 'connected', latency_ms: latency });
  } catch (err) {
    const latency = Date.now() - start;
    return res.status(503).json({ status: 'error', redis: 'unreachable', latency_ms: latency, error: err.message });
  }
}
