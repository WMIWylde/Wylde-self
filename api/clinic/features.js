const { applyCors } = require('../../lib/security');
const { getSupabaseAdmin, getUserFromRequest } = require('../../lib/supabase-admin');

module.exports = async function handler(req, res) {
  if (applyCors(req, res, { methods: 'GET, PUT, OPTIONS' })) return;

  const user = await getUserFromRequest(req);
  if (!user) return res.status(401).json({ error: 'Unauthorized' });

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
