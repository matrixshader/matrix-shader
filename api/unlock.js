import { Redis } from '@upstash/redis';

const redis = new Redis({
  url: process.env.KV_REST_API_URL,
  token: process.env.KV_REST_API_TOKEN,
});

export default async function handler(req, res) {
  if (req.method !== 'POST') return res.status(405).json({ error: 'POST only' });

  const secret = req.headers.authorization?.replace('Bearer ', '');
  if (!secret || secret !== process.env.DASHBOARD_PASSWORD) {
    return res.status(401).json({ error: 'Unauthorized' });
  }

  // Clear all rate limit keys
  let cleared = 0;
  let cursor = 0;
  do {
    const [nextCursor, keys] = await redis.scan(cursor, { match: 'ratelimit:*', count: 100 });
    cursor = Number(nextCursor);
    for (const key of keys) {
      await redis.del(key);
      cleared++;
    }
  } while (cursor !== 0);

  return res.status(200).json({ success: true, cleared });
}
