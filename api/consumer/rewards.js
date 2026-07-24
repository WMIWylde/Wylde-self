// GET /api/consumer/rewards — balance, lifetime points, catalog, redemption history
const { applyCors } = require('../../lib/security');
const { getSupabaseAdmin, getUserFromRequest } = require('../../lib/supabase-admin');

module.exports = async function handler(req, res) {
  if (applyCors(req, res, { methods: 'GET, OPTIONS' })) return;
  if (req.method !== 'GET') return res.status(405).json({ error: 'Method not allowed' });
  const user = await getUserFromRequest(req);
  if (!user) return res.status(401).json({ error: 'Unauthorized' });

  const supabase = getSupabaseAdmin();
  try {
    const [{ data: ledger }, { data: rewards }, { data: redemptions }] = await Promise.all([
      supabase.from('points_ledger').select('delta').eq('user_id', user.id),
      supabase.from('rewards').select('*').eq('active', true).order('sort'),
      supabase.from('reward_redemptions').select('id, reward_id, cost, code, status, created_at')
        .eq('user_id', user.id).order('created_at', { ascending: false }).limit(20),
    ]);
    const rows = ledger || [];
    const balance = rows.reduce((a, r) => a + r.delta, 0);
    const lifetime = rows.filter(r => r.delta > 0).reduce((a, r) => a + r.delta, 0);
    return res.status(200).json({ balance, lifetime, rewards: rewards || [], redemptions: redemptions || [] });
  } catch (err) {
    console.error('[rewards]', err.message);
    return res.status(500).json({ error: 'Failed to load rewards' });
  }
};
