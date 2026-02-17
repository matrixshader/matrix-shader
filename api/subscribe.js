import { Redis } from '@upstash/redis';

const redis = new Redis({
  url: process.env.KV_REST_API_URL,
  token: process.env.KV_REST_API_TOKEN,
});

function isValidEmail(email) {
  return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email) && email.length <= 254;
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

  const { email, source, name } = req.body || {};

  if (!email || !isValidEmail(email)) {
    return res.status(400).json({ error: 'Valid email required' });
  }

  const normalizedEmail = email.trim().toLowerCase();
  const emailKey = `sub:${normalizedEmail}`;

  try {
    const existing = await redis.get(emailKey);
    if (existing) {
      return res.status(200).json({ subscribed: true, message: 'Already subscribed' });
    }

    await Promise.all([
      redis.set(emailKey, JSON.stringify({
        email: normalizedEmail,
        name: name || '',
        source: source || 'website',
        subscribedAt: new Date().toISOString(),
      })),
      redis.incr('stats:subscribe'),
    ]);

    return res.status(200).json({ subscribed: true, message: 'Welcome to the Matrix' });
  } catch (err) {
    console.error('Subscribe error:', err);
    return res.status(500).json({ error: 'Server error' });
  }
}
