const { applyCors } = require('../../lib/security');
const { getSupabaseAdmin, getUserFromRequest } = require('../../lib/supabase-admin');

module.exports = async function handler(req, res) {
  if (applyCors(req, res, { methods: 'POST, OPTIONS' })) return;
  if (req.method !== 'POST') return res.status(405).json({ error: 'Method not allowed' });

  const user = await getUserFromRequest(req);
  if (!user) return res.status(401).json({ error: 'Unauthorized' });

  const supabase = getSupabaseAdmin();
  const body = req.body || {};
  const today = body.date || new Date().toISOString().split('T')[0];

  const checkinData = {
    user_id: user.id,
    date: today,
    doses: body.doses ?? 0,
    daily_checkin: body.daily_checkin ?? 0,
    workout: body.workout ?? 0,
    nutrition: body.nutrition ?? 0,
    weight: body.weight ?? null,
    sleep_score: body.sleep_score ?? null,
    hrv: body.hrv ?? null,
    rhr: body.rhr ?? null,
    mood: body.mood ?? null,
    notes: body.notes ?? null,
  };

  // Upsert — one check-in per user per day
  const { data, error } = await supabase
    .from('patient_checkins')
    .upsert(checkinData, { onConflict: 'user_id,date' })
    .select('id, date')
    .single();

  if (error) {
    console.error('[consumer/checkin] error:', error.message);
    return res.status(500).json({ error: error.message });
  }

  return res.status(200).json({
    ok: true,
    checkin: { id: data.id, date: data.date },
  });
};
