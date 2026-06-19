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
    .select('id, email, profile_data')
    .eq('id', user.id)
    .single();

  // Get active protocol
  const { data: protocol } = await supabase
    .from('patient_protocols')
    .select('id, name, phase, status, started_at')
    .eq('user_id', user.id)
    .eq('status', 'active')
    .order('started_at', { ascending: false })
    .limit(1)
    .single();

  // Get prescriptions
  const { data: prescriptions } = await supabase
    .from('patient_prescriptions')
    .select('drug, dose, frequency, status, last_filled_at')
    .eq('user_id', user.id)
    .eq('status', 'active');

  // Check if already logged today
  const today = new Date().toISOString().split('T')[0];
  const { data: todayCheckin } = await supabase
    .from('patient_checkins')
    .select('id')
    .eq('user_id', user.id)
    .eq('date', today)
    .single();

  const profileData = profile?.profile_data || {};
  const dayNumber = protocol?.started_at
    ? Math.ceil((Date.now() - new Date(protocol.started_at).getTime()) / 86400000)
    : null;

  return res.status(200).json({
    patient: {
      id: user.id,
      first_name: profileData.name || user.email?.split('@')[0] || '',
      last_name: '',
      status: 'active',
    },
    protocol: protocol ? {
      id: protocol.id,
      name: protocol.name,
      phase: protocol.phase,
      started_at: protocol.started_at,
      day_number: dayNumber,
    } : null,
    prescriptions: (prescriptions || []).map(p => ({
      drug: p.drug,
      dose: p.dose,
      frequency: p.frequency,
      status: p.status,
      last_filled_at: p.last_filled_at,
    })),
    today: {
      adherence_required: (prescriptions || []).map(p => p.drug),
      already_logged_today: !!todayCheckin,
    },
  });
};
