// POST /api/decoda/push-adherence — write a 7-day adherence summary onto the
// linked Decoda patient chart as a quick note. Callable by the signed-in user
// (e.g. after Close the Day) or for a specific user_id by a clinician.
const { applyCors, rateLimit, clientIp } = require('../../lib/security');
const { getSupabaseAdmin, getUserFromRequest } = require('../../lib/supabase-admin');
const decoda = require('../../lib/decoda');

module.exports = async function handler(req, res) {
  if (applyCors(req, res, { methods: 'POST, OPTIONS' })) return;
  if (req.method !== 'POST') return res.status(405).json({ error: 'Method not allowed' });

  const user = await getUserFromRequest(req);
  if (!user) return res.status(401).json({ error: 'Unauthorized' });

  const limit = rateLimit({ key: 'decoda-push', ip: clientIp(req), limit: 10, windowMs: 60_000 });
  if (!limit.ok) return res.status(429).json({ error: 'Rate limit exceeded' });

  const supabase = getSupabaseAdmin();

  try {
    const { data: link } = await supabase
      .from('decoda_links')
      .select('decoda_patient_id')
      .eq('user_id', user.id)
      .maybeSingle();
    if (!link) return res.status(404).json({ error: 'Not linked to Decoda' });

    const sevenAgo = new Date(Date.now() - 7 * 86400000).toISOString();

    const [{ data: checkins }, { data: adherence }, { data: score }] = await Promise.all([
      supabase.from('patient_checkins').select('*').eq('patient_id', user.id)
        .gte('created_at', sevenAgo).order('created_at', { ascending: true }),
      supabase.from('protocol_adherence_logs').select('*').eq('patient_id', user.id)
        .gte('created_at', sevenAgo),
      supabase.from('wylde_scores').select('*').eq('user_id', user.id)
        .order('created_at', { ascending: false }).limit(1).maybeSingle(),
    ]);

    const days = (checkins || []).length;
    const doses = (adherence || []).length;
    const dosesTaken = (adherence || []).filter(a => a.taken !== false).length;
    const pct = doses ? Math.round((dosesTaken / doses) * 100) : null;

    const lines = [
      '[Wylde Self — weekly adherence]',
      `Check-ins: ${days}/7 days`,
      pct !== null ? `Protocol adherence: ${pct}% (${dosesTaken}/${doses} doses)` : 'Protocol adherence: no doses scheduled',
      score ? `Wylde Score: ${score.score ?? score.value ?? 'n/a'}` : null,
      `Generated ${new Date().toISOString().split('T')[0]} · wyldeself.com`,
    ].filter(Boolean);

    const note = await decoda.createQuickNote({
      patientId: link.decoda_patient_id,
      note: lines.join('\n'),
    });

    return res.status(200).json({ pushed: true, note_id: note.id });
  } catch (err) {
    console.error('[decoda/push-adherence]', err.message);
    return res.status(500).json({ error: 'Failed to push adherence' });
  }
};
