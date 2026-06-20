const { applyCors } = require('../../lib/security');
const { getSupabaseAdmin, getUserFromRequest } = require('../../lib/supabase-admin');

module.exports = async function handler(req, res) {
  if (applyCors(req, res, { methods: 'GET, POST, OPTIONS' })) return;

  const user = await getUserFromRequest(req);
  if (!user) return res.status(401).json({ error: 'Unauthorized' });

  const supabase = getSupabaseAdmin();
  const today = new Date().toISOString().split('T')[0];

  // GET — fetch score(s)
  if (req.method === 'GET') {
    const date = req.query.date || today;
    const range = req.query.range; // "7" or "30" for history

    if (range) {
      const daysAgo = new Date(Date.now() - parseInt(range) * 86400000).toISOString().split('T')[0];
      const { data } = await supabase
        .from('wylde_scores')
        .select('*')
        .eq('user_id', user.id)
        .gte('date', daysAgo)
        .order('date', { ascending: true });
      return res.status(200).json({ scores: data || [] });
    }

    const { data } = await supabase
      .from('wylde_scores')
      .select('*')
      .eq('user_id', user.id)
      .eq('date', date)
      .single();

    return res.status(200).json({ score: data || null });
  }

  // POST — calculate and upsert today's score
  if (req.method === 'POST') {
    const body = req.body || {};

    // Score components (each normalized to their max)
    // ritual: 20pts — morning protocol completion
    // movement: 20pts — workout + walk
    // nutrition: 20pts — protein/calorie adherence
    // protocol: 25pts — prescription adherence
    // recovery: 10pts — sleep/rest indicators
    // mindset: 5pts — journaling/meditation/coach engagement

    const ritual = Math.min(20, Math.round((body.ritual_completion || 0) * 20));
    const movement = Math.min(20, Math.round((body.movement_completion || 0) * 20));
    const nutrition = Math.min(20, Math.round((body.nutrition_completion || 0) * 20));
    const protocol = Math.min(25, Math.round((body.protocol_completion || 0) * 25));
    const recovery = Math.min(10, Math.round((body.recovery_completion || 0) * 10));
    const mindset = Math.min(5, Math.round((body.mindset_completion || 0) * 5));
    const total = ritual + movement + nutrition + protocol + recovery + mindset;

    const { data, error } = await supabase
      .from('wylde_scores')
      .upsert({
        user_id: user.id,
        date: body.date || today,
        total_score: total,
        ritual_score: ritual,
        movement_score: movement,
        nutrition_score: nutrition,
        protocol_score: protocol,
        recovery_score: recovery,
        mindset_score: mindset,
        updated_at: new Date().toISOString(),
      }, { onConflict: 'user_id,date' })
      .select()
      .single();

    if (error) return res.status(500).json({ error: error.message });
    return res.status(200).json({ score: data });
  }

  return res.status(405).json({ error: 'Method not allowed' });
};
