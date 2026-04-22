const webpush = require('web-push');
const { createClient } = require('@supabase/supabase-js');

const VAPID_PUBLIC = process.env.VAPID_PUBLIC_KEY || 'BNGQFMUQu7IPUrks8ibBTzsrR_m22cwdI-fpPe7cz0A8GX-GaGvYFfhvQ5mOkdDV242WXPOIXVUzg531eh289m4';
const VAPID_PRIVATE = process.env.VAPID_PRIVATE_KEY || 'f7Sux0dfkRmg7-UMe__6kPriQTMmaTbDjkHbwnOopJU';
const SUPABASE_URL = process.env.SUPABASE_URL || 'https://huclolzxzpitdpyogolu.supabase.co';
const SUPABASE_SERVICE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY;

webpush.setVapidDetails('mailto:wilkemitzin@gmail.com', VAPID_PUBLIC, VAPID_PRIVATE);

const NOTIFICATIONS = {
  morning_protocol: {
    title: 'Your Protocol Awaits',
    body: 'Start your morning with intention. Show up for yourself before the noise begins.',
    tag: 'morning'
  },
  workout_reminder: {
    title: "Today's a Training Day",
    body: "Your program is ready. Time to build the version of you that doesn't quit.",
    tag: 'workout'
  },
  macro_reminder: {
    title: 'Log Your Fuel',
    body: "Stay on track — log your meals and stick to the plan.",
    tag: 'macro'
  },
  streak_protection: {
    title: "Don't Break Your Streak",
    body: "You haven't completed today yet. Show up.",
    tag: 'streak'
  },
  unfinished_day: {
    title: 'Day Incomplete',
    body: 'Your workout, protocol, or nutrition still needs attention. Finish what you started.',
    tag: 'unfinished'
  },
  weekly_recap: {
    title: 'Your Week in Review',
    body: 'Check in on your progress. Keep building.',
    tag: 'recap'
  }
};

module.exports = async function handler(req, res) {
  const authHeader = req.headers.authorization;
  if (process.env.CRON_SECRET && authHeader !== `Bearer ${process.env.CRON_SECRET}`) {
    return res.status(401).json({ error: 'Unauthorized' });
  }

  if (!SUPABASE_SERVICE_KEY) {
    return res.status(500).json({ error: 'Missing SUPABASE_SERVICE_ROLE_KEY env var' });
  }

  const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY);

  // Get current hour (Pacific Time)
  const now = new Date();
  const ptString = now.toLocaleString('en-US', { timeZone: 'America/Los_Angeles' });
  const ptDate = new Date(ptString);
  const currentHour = ptDate.getHours();
  const dayOfWeek = ptDate.getDay(); // 0 = Sunday

  let notifType = null;
  if (currentHour === 7) notifType = 'morning_protocol';
  else if (currentHour === 9) notifType = 'workout_reminder';
  else if (currentHour === 12) notifType = 'macro_reminder';
  else if (currentHour === 20) notifType = 'streak_protection';
  else if (currentHour === 21) notifType = 'unfinished_day';
  else if (currentHour === 10 && dayOfWeek === 0) notifType = 'weekly_recap';

  if (!notifType) {
    return res.status(200).json({ message: 'No notifications this hour', hour: currentHour });
  }

  const { data: subs, error } = await supabase
    .from('push_subscriptions')
    .select('*')
    .eq('platform', 'web');

  if (error) return res.status(500).json({ error: error.message });

  const notif = NOTIFICATIONS[notifType];
  let sent = 0, failed = 0, expired = [];

  for (const sub of (subs || [])) {
    const prefs = sub.notification_prefs || {};
    if (prefs[notifType] && prefs[notifType].enabled === false) continue;

    const pushSub = {
      endpoint: sub.endpoint,
      keys: { p256dh: sub.keys_p256dh, auth: sub.keys_auth }
    };
    if (!pushSub.endpoint || !pushSub.keys.p256dh) continue;

    try {
      await webpush.sendNotification(pushSub, JSON.stringify({
        title: notif.title, body: notif.body,
        tag: 'wylde-' + notif.tag, url: '/'
      }));
      sent++;
    } catch (err) {
      if (err.statusCode === 410 || err.statusCode === 404) expired.push(sub.id);
      failed++;
    }
  }

  if (expired.length > 0) {
    await supabase.from('push_subscriptions').delete().in('id', expired);
  }

  return res.status(200).json({ type: notifType, sent, failed, expired: expired.length });
};
