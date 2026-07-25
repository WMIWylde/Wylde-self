// Founder pulse — /api/admin/pulse — real beta numbers for the command center
const crypto = require('crypto');
const { getSupabaseAdmin } = require('../../lib/supabase-admin');

function secretMatches(provided, expected) {
  if (!expected || typeof provided !== 'string') return false;
  const a = Buffer.from(provided);
  const b = Buffer.from(expected);
  if (a.length !== b.length) return false;
  return crypto.timingSafeEqual(a, b);
}

module.exports = async function handler(req, res) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type, X-Admin-Secret');
  if (req.method === 'OPTIONS') return res.status(204).end();
  if (req.method !== 'GET') return res.status(405).json({ error: 'GET only' });

  const secret = req.headers['x-admin-secret'];
  if (!process.env.ADMIN_SECRET || !secretMatches(secret, process.env.ADMIN_SECRET)) {
    return res.status(401).json({ error: 'Unauthorized' });
  }

  const supabase = getSupabaseAdmin();
  const dayAgo = new Date(Date.now() - 86400000).toISOString();
  const weekAgo = new Date(Date.now() - 7 * 86400000).toISOString();

  try {
    const [users, sets24, setsWeek, points, feedback, redemptions] = await Promise.all([
      supabase.auth.admin.listUsers({ page: 1, perPage: 1000 }),
      supabase.from('workout_set_logs').select('user_id', { count: 'exact', head: true }).gte('logged_at', dayAgo),
      supabase.from('workout_set_logs').select('user_id', { count: 'exact', head: true }).gte('logged_at', weekAgo),
      supabase.from('points_ledger').select('delta').gte('created_at', weekAgo),
      supabase.from('feedback').select('message, platform, build, created_at, user_id').order('created_at', { ascending: false }).limit(10),
      supabase.from('reward_redemptions').select('id', { count: 'exact', head: true }),
    ]);

    const allUsers = (users.data && users.data.users) || [];
    const activeDay = allUsers.filter(u => u.last_sign_in_at && u.last_sign_in_at > dayAgo).length;
    const activeWeek = allUsers.filter(u => u.last_sign_in_at && u.last_sign_in_at > weekAgo).length;
    const emailById = {};
    allUsers.forEach(u => { emailById[u.id] = u.email; });
    const pointsWeek = (points.data || []).filter(r => r.delta > 0).reduce((a, r) => a + r.delta, 0);

    return res.status(200).json({
      users_total: allUsers.length,
      active_24h: activeDay,
      active_7d: activeWeek,
      sets_logged_24h: sets24.count || 0,
      sets_logged_7d: setsWeek.count || 0,
      points_earned_7d: pointsWeek,
      redemptions_total: redemptions.count || 0,
      feedback: (feedback.data || []).map(f => ({ ...f, email: emailById[f.user_id] || null, user_id: undefined })),
    });
  } catch (err) {
    console.error('[pulse]', err.message);
    return res.status(500).json({ error: 'Failed to load pulse' });
  }
};
