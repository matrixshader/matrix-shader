import { Redis } from '@upstash/redis';
import crypto from 'crypto';
import { initSentry, captureError } from './_sentry.js';

if (!process.env.KV_REST_API_URL || !process.env.KV_REST_API_TOKEN) {
  console.error('FATAL: KV_REST_API_URL and KV_REST_API_TOKEN must be set');
}

const redis = new Redis({
  url: process.env.KV_REST_API_URL,
  token: process.env.KV_REST_API_TOKEN,
});

const CATEGORIES = ['general', 'installation', 'usage', 'licensing', 'compatibility', 'troubleshooting'];

function todayKey() {
  return new Date().toISOString().slice(0, 10);
}

function genId() {
  return crypto.randomBytes(4).toString('hex');
}

function validEmail(e) {
  return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(e);
}

async function rateLimit(ip, prefix, limit, windowSec) {
  const key = `rl:${prefix}:${ip}`;
  try {
    const count = await redis.incr(key);
    await redis.expire(key, windowSec);
    return count > limit;
  } catch { return false; }
}

async function authenticate(req) {
  // Session-based auth
  const sessionHeader = req.headers['x-session'];
  if (sessionHeader) {
    try {
      const valid = await redis.get(`session:${sessionHeader}`);
      if (valid === 'active') return true;
    } catch { /* fall through */ }
  }

  // Bearer token auth
  const auth = req.headers.authorization;
  if (!auth) return false;
  const password = process.env.DASHBOARD_PASSWORD;
  if (!password) return false;
  const provided = auth.replace('Bearer ', '');
  const providedHash = crypto.createHash('sha256').update(provided).digest();
  const expectedHash = crypto.createHash('sha256').update(password).digest();
  return crypto.timingSafeEqual(providedHash, expectedHash);
}

export default async function handler(req, res) {
  res.setHeader('Access-Control-Allow-Origin', 'https://matrixshader.com');
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, PATCH, DELETE, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization, X-Session');

  initSentry();

  if (req.method === 'OPTIONS') {
    return res.status(200).end();
  }

  // ── POST: Submit a question (public, rate-limited) ──
  if (req.method === 'POST') {
    const ip = (req.headers['x-forwarded-for'] || req.socket?.remoteAddress || 'unknown').split(',')[0].trim();
    if (await rateLimit(ip, 'faq', 5, 3600)) {
      return res.status(429).json({ error: 'Too many questions. Try again later.' });
    }

    const { email, question, category } = req.body || {};

    if (!email || !validEmail(email)) {
      return res.status(400).json({ error: 'Valid email required' });
    }
    if (!question || question.length < 10 || question.length > 500) {
      return res.status(400).json({ error: 'Question must be 10-500 characters' });
    }
    const cat = category && CATEGORIES.includes(category) ? category : 'general';

    const id = genId();
    const record = {
      id,
      question: question.trim(),
      email: email.trim().toLowerCase(),
      category: cat,
      tags: [],
      status: 'pending',
      answer: null,
      answeredBy: null,
      submittedAt: new Date().toISOString(),
      publishedAt: null,
      dismissedAt: null,
      updatedAt: null,
    };

    try {
      await redis.set(`faq:q:${id}`, JSON.stringify(record), { ex: 31536000 });
      await Promise.all([
        redis.incr('stats:faq_submit'),
        redis.incr(`ts:faq_submit:${todayKey()}`),
      ]);

      // Notify owner about new FAQ question (best-effort)
      const ownerEmail = process.env.OWNER_EMAIL;
      const resendKey = process.env.RESEND_API_KEY;
      const fromAddr = process.env.EMAIL_FROM || 'Matrix Shader <noreply@matrixshader.com>';
      if (ownerEmail && resendKey) {
        const notifHtml = `<div style="background:#0a0a0a;color:#ccc;font-family:monospace;padding:2rem">
<h2 style="color:#00ff41">New FAQ Question</h2>
<p><strong>From:</strong> ${record.email}</p>
<p><strong>Category:</strong> ${cat}</p>
<hr style="border-color:#333">
<p style="white-space:pre-wrap">${question.trim().slice(0, 500).replace(/</g, '&lt;')}</p>
<hr style="border-color:#333">
<p style="color:#888;font-size:0.8rem">Answer it from the admin dashboard.</p>
</div>`;
        fetch('https://api.resend.com/emails', {
          method: 'POST',
          headers: { 'Authorization': `Bearer ${resendKey}`, 'Content-Type': 'application/json' },
          body: JSON.stringify({ from: fromAddr, to: [ownerEmail], subject: `[FAQ] New question: ${cat}`, html: notifHtml }),
        }).catch(err => console.error('FAQ notification failed:', err.message));
      }

      return res.status(201).json({ id, message: 'Question received' });
    } catch (err) {
      console.error('FAQ submit error:', err);
      captureError(err, { endpoint: 'faq', action: 'submit' });
      return res.status(500).json({ error: 'Failed to save question' });
    }
  }

  // ── GET: List questions ──
  if (req.method === 'GET') {
    const authed = await authenticate(req);
    const status = req.query.status || '';

    try {
      // Scan all faq:q:* keys
      const questions = [];
      let cursor = 0;
      do {
        const [nextCursor, keys] = await redis.scan(cursor, { match: 'faq:q:*', count: 100 });
        cursor = Number(nextCursor);
        if (keys.length > 0) {
          const values = await redis.mget(...keys);
          for (const val of values) {
            if (val) {
              const data = typeof val === 'string' ? JSON.parse(val) : val;
              questions.push(data);
            }
          }
        }
      } while (cursor !== 0);

      // Count by status
      const counts = { pending: 0, published: 0, dismissed: 0, total: questions.length };
      for (const q of questions) {
        if (counts[q.status] !== undefined) counts[q.status]++;
      }

      // Filter based on auth
      let filtered;
      if (authed) {
        if (status === 'pending') filtered = questions.filter(q => q.status === 'pending');
        else if (status === 'published') filtered = questions.filter(q => q.status === 'published');
        else if (status === 'dismissed') filtered = questions.filter(q => q.status === 'dismissed');
        else filtered = questions; // status=all or no filter
      } else {
        // Public: only published
        filtered = questions.filter(q => q.status === 'published');
        // Strip email from public responses
        filtered = filtered.map(({ email, ...rest }) => rest);
      }

      // Sort: published by publishedAt desc, pending by submittedAt desc
      filtered.sort((a, b) => {
        const dateA = a.publishedAt || a.submittedAt || '';
        const dateB = b.publishedAt || b.submittedAt || '';
        return dateB.localeCompare(dateA);
      });

      // Cache header for public requests
      if (!authed) {
        res.setHeader('Cache-Control', 'public, s-maxage=300, stale-while-revalidate=86400');
      }

      return res.status(200).json({ questions: filtered, counts });
    } catch (err) {
      console.error('FAQ list error:', err);
      captureError(err, { endpoint: 'faq', action: 'list' });
      return res.status(500).json({ error: 'Failed to load questions' });
    }
  }

  // ── PATCH: Update a question (auth required) ──
  if (req.method === 'PATCH') {
    const authed = await authenticate(req);
    if (!authed) return res.status(401).json({ error: 'Unauthorized' });

    const { id, action, answer, category, tags } = req.body || {};
    if (!id || !action) {
      return res.status(400).json({ error: 'id and action required' });
    }

    try {
      const raw = await redis.get(`faq:q:${id}`);
      if (!raw) return res.status(404).json({ error: 'Question not found' });
      const record = typeof raw === 'string' ? JSON.parse(raw) : raw;
      const now = new Date().toISOString();

      switch (action) {
        case 'publish':
          if (!answer && !record.answer) {
            return res.status(400).json({ error: 'Answer required to publish' });
          }
          if (answer) record.answer = answer.trim();
          record.status = 'published';
          record.publishedAt = now;
          record.answeredBy = record.answeredBy || 'human';
          record.dismissedAt = null;
          record.updatedAt = now;
          break;

        case 'dismiss':
          record.status = 'dismissed';
          record.dismissedAt = now;
          record.updatedAt = now;
          break;

        case 'reopen':
          record.status = 'pending';
          record.dismissedAt = null;
          record.updatedAt = now;
          break;

        case 'update':
          if (answer !== undefined) record.answer = answer.trim();
          if (category && CATEGORIES.includes(category)) record.category = category;
          if (Array.isArray(tags)) record.tags = tags;
          record.updatedAt = now;
          break;

        default:
          return res.status(400).json({ error: `Unknown action: ${action}` });
      }

      await redis.set(`faq:q:${id}`, JSON.stringify(record), { ex: 31536000 });
      return res.status(200).json(record);
    } catch (err) {
      console.error('FAQ update error:', err);
      captureError(err, { endpoint: 'faq', action: 'update' });
      return res.status(500).json({ error: 'Failed to update question' });
    }
  }

  // ── DELETE: Permanently delete (auth required) ──
  if (req.method === 'DELETE') {
    const authed = await authenticate(req);
    if (!authed) return res.status(401).json({ error: 'Unauthorized' });

    const id = req.query.id;
    if (!id) return res.status(400).json({ error: 'id required' });

    try {
      const existed = await redis.del(`faq:q:${id}`);
      if (!existed) return res.status(404).json({ error: 'Question not found' });
      return res.status(200).json({ deleted: true, id });
    } catch (err) {
      console.error('FAQ delete error:', err);
      captureError(err, { endpoint: 'faq', action: 'delete' });
      return res.status(500).json({ error: 'Failed to delete question' });
    }
  }

  return res.status(405).json({ error: 'Method not allowed' });
}
