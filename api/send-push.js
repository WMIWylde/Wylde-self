const webpush = require('web-push');

const VAPID_PUBLIC = process.env.VAPID_PUBLIC_KEY || 'BNGQFMUQu7IPUrks8ibBTzsrR_m22cwdI-fpPe7cz0A8GX-GaGvYFfhvQ5mOkdDV242WXPOIXVUzg531eh289m4';
const VAPID_PRIVATE = process.env.VAPID_PRIVATE_KEY || 'f7Sux0dfkRmg7-UMe__6kPriQTMmaTbDjkHbwnOopJU';

webpush.setVapidDetails('mailto:wilkemitzin@gmail.com', VAPID_PUBLIC, VAPID_PRIVATE);

module.exports = async function handler(req, res) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');
  if (req.method === 'OPTIONS') return res.status(200).end();

  if (req.method !== 'POST') {
    return res.status(405).json({ error: 'Method not allowed' });
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
