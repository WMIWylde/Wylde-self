// POST /api/consumer/redeem { reward_id } — server-side balance check,
// issues a redemption code and records the spend as a negative ledger row.
const crypto = require('crypto');
const { applyCors, rateLimit, clientIp } = require('../../lib/security');
const { getSupabaseAdmin, getUserFromRequest } = require('../../lib/supabase-admin');

module.exports = async function handler(req, res) {
  if (applyCors(req, res, { methods: 'POST, OPTIONS' })) return;
  if (req.method !== 'POST') return res.status(405).json({ error: 'Method not allowed' });
  const user = await getUserFromRequest(req);
  if (!user) return res.status(401).json({ error: 'Unauthorized' });

  const limit = rateLimit({ key: 'redeem', ip: clientIp(req), limit: 10, windowMs: 60_000 });
  if (!limit.ok) return res.status(429).json({ error: 'Rate limit exceeded' });

  const { reward_id } = req.body || {};
  if (!reward_id) return res.status(400).json({ error: 'reward_id required' });

  const supabase = getSupabaseAdmin();
  try {
    const { data: reward } = await supabase.from('rewards')
      .select('*').eq('id', reward_id).eq('active', true).single();
    if (!reward) return res.status(404).json({ error: 'Reward not found' });

    const { data: ledger } = await supabase.from('points_ledger')
      .select('delta').eq('user_id', user.id);
    const balance = (ledger || []).reduce((a, r) => a + r.delta, 0);
    if (balance < reward.cost) {
      return res.status(400).json({ error: 'Not enough points', balance, cost: reward.cost });
    }

    const code = 'WYLDE-' + crypto.randomBytes(4).toString('hex').toUpperCase();
    const { data: redemption, error: rErr } = await supabase.from('reward_redemptions')
      .insert({ user_id: user.id, reward_id, cost: reward.cost, code })
      .select().single();
    if (rErr) throw rErr;

    await supabase.from('points_ledger').insert({
      user_id: user.id, delta: -reward.cost,
      reason: `Redeemed: ${reward.title}`, source: 'redemption',
    });

    return res.status(200).json({ redeemed: true, code, balance: balance - reward.cost });
  } catch (err) {
    console.error('[redeem]', err.message);
    return res.status(500).json({ error: 'Redemption failed' });
  }
};
