const { applyCors } = require('../../lib/security');
const { getSupabaseAdmin, getUserFromRequest } = require('../../lib/supabase-admin');

module.exports = async function handler(req, res) {
  if (applyCors(req, res, { methods: 'GET, OPTIONS' })) return;
  if (req.method !== 'GET') return res.status(405).json({ error: 'Method not allowed' });

  const user = await getUserFromRequest(req);
  if (!user) return res.status(401).json({ error: 'Unauthorized' });

  const supabase = getSupabaseAdmin();

  // Get profile
  const { data: profile } = await supabase
    .from('profiles')
    .select('profile_data')
    .eq('id', user.id)
    .single();

  // Get active protocol
  const { data: protocol } = await supabase
    .from('patient_protocols')
    .select('name, phase, started_at')
    .eq('user_id', user.id)
    .eq('status', 'active')
    .order('started_at', { ascending: false })
    .limit(1)
    .single();

  // Get last 90 days of check-ins for timeseries
  const ninetyDaysAgo = new Date(Date.now() - 90 * 86400000).toISOString().split('T')[0];
  const { data: checkins } = await supabase
    .from('patient_checkins')
    .select('date, doses, sleep_score, hrv, rhr')
    .eq('user_id', user.id)
    .gte('date', ninetyDaysAgo)
    .order('date', { ascending: true });

  const timeseries = (checkins || []).map(c => ({
    date: c.date,
    doses: c.doses,
    sleep_score: c.sleep_score,
    hrv: c.hrv,
    rhr: c.rhr,
  }));

  // Compute comparison (first week avg vs last week avg)
  const comparison = computeComparison(checkins || []);
  const dayNumber = protocol?.started_at
    ? Math.ceil((Date.now() - new Date(protocol.started_at).getTime()) / 86400000)
    : null;
  const profileData = profile?.profile_data || {};

  return res.status(200).json({
    patient: {
      first_name: profileData.name || '',
      last_name: '',
      status: 'active',
    },
    protocol: protocol ? {
      name: protocol.name,
      phase: protocol.phase,
      started_at: protocol.started_at,
      day_number: dayNumber,
    } : null,
    timeseries,
    snapshots: [],
    comparison,
  });
};

function computeComparison(checkins) {
  if (checkins.length < 7) return { adherence: null, hrv: null, sleep_score: null, rhr: null };

  const firstWeek = checkins.slice(0, 7);
  const lastWeek = checkins.slice(-7);

  const avg = (arr, key) => {
    const vals = arr.map(c => c[key]).filter(v => v != null);
    return vals.length > 0 ? vals.reduce((a, b) => a + b, 0) / vals.length : null;
  };

  const makePair = (key, unit) => {
    const baseline = avg(firstWeek, key);
    const current = avg(lastWeek, key);
    if (baseline == null || current == null) return null;
    return { baseline: Math.round(baseline * 10) / 10, current: Math.round(current * 10) / 10, unit };
  };

  return {
    adherence: makePair('doses', 'doses/day'),
    hrv: makePair('hrv', 'ms'),
    sleep_score: makePair('sleep_score', '/10'),
    rhr: makePair('rhr', 'bpm'),
  };
}
