import { Redis } from '@upstash/redis';

if (!process.env.KV_REST_API_URL || !process.env.KV_REST_API_TOKEN) {
  console.error('FATAL: KV_REST_API_URL and KV_REST_API_TOKEN must be set');
}

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
    const lastBackup = await redis.get('backup:latest');
    const backupAge = lastBackup ? Math.floor((Date.now() - new Date(lastBackup).getTime()) / 3600000) : null;
    const backupStale = backupAge === null || backupAge > 48;
    return res.status(200).json({
      status: 'ok',
      redis: 'connected',
      latency_ms: latency,
      backup: { last: lastBackup || 'never', hours_ago: backupAge, stale: backupStale },
    });
  } catch (err) {
    const latency = Date.now() - start;
    return res.status(503).json({ status: 'error', redis: 'unreachable', latency_ms: latency, error: err.message });
  }
}
