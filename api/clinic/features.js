const { applyCors, rateLimit, clientIp } = require('../../lib/security');
const { getSupabaseAdmin, requireClinicAccess } = require('../../lib/supabase-admin');

module.exports = async function handler(req, res) {
  if (applyCors(req, res, { methods: 'GET, PUT, OPTIONS' })) return;

  const auth = await requireClinicAccess(req, res);
  if (!auth) return;
  const { user } = auth;

  // Rate limit: 20/min
  const rl = rateLimit({ key: 'clinic-features', ip: clientIp(req), limit: 20, windowMs: 60000 });
  if (!rl.ok) return res.status(429).json({ error: 'Rate limit exceeded' });

  const supabase = getSupabaseAdmin();

  if (req.method === 'GET') {
    let { data } = await supabase
      .from('clinic_feature_toggles')
      .select('*')
      .eq('clinic_id', user.id)
      .single();

    if (!data) {
      const { data: newRow } = await supabase
        .from('clinic_feature_toggles')
        .insert({ clinic_id: user.id })
        .select()
        .single();
      data = newRow;
    }
    return res.status(200).json({ features: data });
  }

  if (req.method === 'PUT') {
    const body = req.body || {};
    const allowed = ['future_self','vision_board','ai_coach','workouts','nutrition','meal_tracking','habits','journaling','meditation','messaging','protocol_tracking','wylde_score'];
    const updates = { updated_at: new Date().toISOString() };
    for (const k of allowed) { if (body[k] !== undefined) updates[k] = body[k]; }

    const { data, error } = await supabase
      .from('clinic_feature_toggles')
      .upsert({ clinic_id: user.id, ...updates }, { onConflict: 'clinic_id' })
      .select()
      .single();

    if (error) return res.status(500).json({ error: error.message });
    return res.status(200).json({ features: data });
  }

  return res.status(405).json({ error: 'Method not allowed' });
};
