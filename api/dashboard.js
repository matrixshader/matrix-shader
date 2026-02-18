import { Redis } from '@upstash/redis';

const redis = new Redis({
  url: process.env.KV_REST_API_URL,
  token: process.env.KV_REST_API_TOKEN,
});

function getLast30Days() {
  const dates = [];
  for (let i = 29; i >= 0; i--) {
    const d = new Date();
    d.setDate(d.getDate() - i);
    dates.push(d.toISOString().slice(0, 10));
  }
  return dates;
}

export default async function handler(req, res) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization');

  if (req.method === 'OPTIONS') {
    return res.status(200).end();
  }

  if (req.method !== 'GET') {
    return res.status(405).json({ error: 'Method not allowed' });
  }

  // Auth check
  const password = process.env.DASHBOARD_PASSWORD;
  if (!password) {
    return res.status(500).json({ error: 'Dashboard not configured' });
  }

  const auth = req.headers.authorization;
  if (!auth || auth !== `Bearer ${password}`) {
    return res.status(401).json({ error: 'Unauthorized' });
  }

  try {
    // 1. Totals
    const statKeys = [
      'stats:download', 'stats:install', 'stats:activate',
      'stats:subscribe', 'stats:purchase',
      'stats:page_view', 'stats:redpill_click', 'stats:github_click',
    ];
    const statValues = await redis.mget(...statKeys);
    const totals = {
      downloads: Number(statValues[0]) || 0,
      installs: Number(statValues[1]) || 0,
      activations: Number(statValues[2]) || 0,
      subscribers: Number(statValues[3]) || 0,
      purchases: Number(statValues[4]) || 0,
      page_views: Number(statValues[5]) || 0,
      redpill_clicks: Number(statValues[6]) || 0,
      github_clicks: Number(statValues[7]) || 0,
    };

    // 2. Time-series (last 30 days)
    const dates = getLast30Days();
    const tsEvents = ['page_view', 'download', 'install', 'activate', 'redpill_click', 'github_click', 'subscribe', 'purchase'];
    const tsKeys = [];
    for (const event of tsEvents) {
      for (const date of dates) {
        tsKeys.push(`ts:${event}:${date}`);
      }
    }

    const tsValues = tsKeys.length > 0 ? await redis.mget(...tsKeys) : [];
    const timeseries = {};
    let idx = 0;
    for (const event of tsEvents) {
      timeseries[event] = [];
      for (const date of dates) {
        timeseries[event].push({ date, count: Number(tsValues[idx]) || 0 });
        idx++;
      }
    }

    // 3. Subscribers (scan for sub:* keys)
    const subscribers = [];
    let subCursor = 0;
    do {
      const [nextCursor, keys] = await redis.scan(subCursor, { match: 'sub:*', count: 100 });
      subCursor = Number(nextCursor);
      if (keys.length > 0) {
        const values = await redis.mget(...keys);
        for (const val of values) {
          if (val) {
            const data = typeof val === 'string' ? JSON.parse(val) : val;
            subscribers.push({
              email: data.email || '',
              name: data.name || '',
              source: data.source || '',
              subscribedAt: data.subscribedAt || '',
            });
          }
        }
      }
    } while (subCursor !== 0);

    subscribers.sort((a, b) => (b.subscribedAt || '').localeCompare(a.subscribedAt || ''));

    // 4. Licenses (scan for key:* keys)
    const licenses = [];
    let keyCursor = 0;
    do {
      const [nextCursor, keys] = await redis.scan(keyCursor, { match: 'key:*', count: 100 });
      keyCursor = Number(nextCursor);
      if (keys.length > 0) {
        const values = await redis.mget(...keys);
        for (const val of values) {
          if (val) {
            const data = typeof val === 'string' ? JSON.parse(val) : val;
            licenses.push({
              orderId: data.orderId || '',
              email: data.email || '',
              buyerName: data.buyerName || '',
              createdAt: data.createdAt || '',
              activationCount: Array.isArray(data.activations) ? data.activations.length : 0,
            });
          }
        }
      }
    } while (keyCursor !== 0);

    licenses.sort((a, b) => (b.createdAt || '').localeCompare(a.createdAt || ''));

    // 5. Funnel
    const conversionRate = totals.page_views > 0
      ? ((totals.purchases / totals.page_views) * 100).toFixed(2) + '%'
      : '0%';

    const funnel = {
      page_views: totals.page_views,
      redpill_clicks: totals.redpill_clicks,
      downloads: totals.downloads,
      purchases: totals.purchases,
      conversion_rate: conversionRate,
    };

    return res.status(200).json({
      totals,
      timeseries,
      subscribers,
      licenses,
      funnel,
    });
  } catch (err) {
    console.error('Dashboard error:', err);
    return res.status(500).json({ error: 'Failed to load dashboard data' });
  }
}
