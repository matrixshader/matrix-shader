import crypto from 'crypto';
import { Redis } from '@upstash/redis';

const redis = new Redis({
  url: process.env.KV_REST_API_URL,
  token: process.env.KV_REST_API_TOKEN,
});

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
  const hash = crypto.createHash('sha256').update(seed).digest();
  const g1 = toBase36(hash, 0, 4);
  const g2 = toBase36(hash, 4, 4);
  const g3 = toBase36(hash, 8, 4);

  const payload = `REDPILL-${g1}-${g2}-${g3}`;
  const hmac = crypto.createHmac('sha256', secret).update(payload).digest();
  const sig = toBase36(hmac, 0, 4);

  return `${payload}-${sig}`;
}

function verifySignature(rawBody, signature, secret) {
  const hmac = crypto.createHmac('sha256', secret).update(rawBody).digest('hex');
  return crypto.timingSafeEqual(Buffer.from(hmac), Buffer.from(signature));
}

export const config = {
  api: { bodyParser: false },
};

function getRawBody(req) {
  return new Promise((resolve, reject) => {
    const chunks = [];
    req.on('data', (chunk) => chunks.push(chunk));
    req.on('end', () => resolve(Buffer.concat(chunks).toString('utf8')));
    req.on('error', reject);
  });
}

export default async function handler(req, res) {
  if (req.method !== 'POST') {
    return res.status(405).json({ error: 'Method not allowed' });
  }

  const webhookSecret = process.env.LEMONSQUEEZY_WEBHOOK_SECRET;
  const licenseSecret = process.env.LICENSE_SECRET;

  if (!webhookSecret || !licenseSecret) {
    console.error('Missing LEMONSQUEEZY_WEBHOOK_SECRET or LICENSE_SECRET');
    return res.status(500).json({ error: 'Server configuration error' });
  }

  // Read raw body for signature verification
  const rawBody = await getRawBody(req);
  const signature = req.headers['x-signature'];

  if (!signature || !verifySignature(rawBody, signature, webhookSecret)) {
    return res.status(401).json({ error: 'Invalid signature' });
  }

  const event = JSON.parse(rawBody);
  const eventName = event.meta?.event_name;
  const orderId = event.data?.id;

  console.log(`Webhook: ${eventName} for order ${orderId}`);

  if (eventName === 'order_created') {
    const status = event.data?.attributes?.status;
    if (status !== 'paid') {
      return res.status(200).json({ received: true, skipped: 'not paid' });
    }

    // Generate key and store in Redis (same logic as activate.js)
    const seed = `LS-${orderId}`;
    const key = generateKey(seed, licenseSecret);
    const keyHash = crypto.createHash('sha256').update(key).digest('hex').slice(0, 32);

    try {
      const buyerEmail = event.data?.attributes?.user_email || '';
      const buyerName = event.data?.attributes?.user_name || event.data?.attributes?.first_name || '';

      const existing = await redis.get(`key:${keyHash}`);
      if (!existing) {
        // Assign sequential customer number
        const customerNumber = await redis.incr('stats:customer_number');
        await redis.set(`key:${keyHash}`, JSON.stringify({
          orderId: `LS-${orderId}`,
          email: buyerEmail,
          buyerName: buyerName,
          customerNumber,
          createdAt: new Date().toISOString(),
          activations: [],
        }));
      }
      await redis.incr('stats:purchase');
    } catch (err) {
      console.error('Redis error in webhook:', err);
    }

    return res.status(200).json({ received: true, event: eventName });
  }

  if (eventName === 'order_refunded') {
    // Log refund — key revocation could be added later
    console.log(`Refund for order ${orderId}`);
    return res.status(200).json({ received: true, event: eventName });
  }

  return res.status(200).json({ received: true, event: eventName });
}
