const webpush = require('web-push');
const { getUserFromRequest } = require('./../lib/supabase-admin');

const VAPID_PUBLIC = process.env.VAPID_PUBLIC_KEY;
const VAPID_PRIVATE = process.env.VAPID_PRIVATE_KEY;

webpush.setVapidDetails('mailto:wilkemitzin@gmail.com', VAPID_PUBLIC, VAPID_PRIVATE);

module.exports = async function handler(req, res) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization');
  if (req.method === 'OPTIONS') return res.status(200).end();

  if (req.method !== 'POST') {
    return res.status(405).json({ error: 'Method not allowed' });
  }

  // Auth gate: accept either the CRON_SECRET (server/cron caller, matching
  // cron-push.js) OR a valid Supabase JWT. Reject everyone else.
  const authHeader = req.headers.authorization || '';
  const isCron = !!process.env.CRON_SECRET && authHeader === `Bearer ${process.env.CRON_SECRET}`;
  if (!isCron) {
    const user = await getUserFromRequest(req);
    if (!user) return res.status(401).json({ error: 'Unauthorized' });
  }

  try {
    const { subscription, title, body, tag, url } = req.body;

    if (!subscription || !subscription.endpoint) {
      return res.status(400).json({ error: 'Missing subscription' });
    }

    const payload = JSON.stringify({
      title: title || 'Wylde Self',
      body: body || 'Time to show up.',
      tag: tag || 'wylde',
      url: url || '/'
    });

    await webpush.sendNotification(subscription, payload);
    return res.status(200).json({ success: true });
  } catch (err) {
    if (err.statusCode === 410 || err.statusCode === 404) {
      return res.status(410).json({ error: 'Subscription expired', code: err.statusCode });
    }
    console.error('Push send error:', err);
    return res.status(500).json({ error: err.message });
  }
};
