const { applyCors } = require('../../lib/security');
const { getSupabaseAdmin, getUserFromRequest } = require('../../lib/supabase-admin');

module.exports = async function handler(req, res) {
  if (applyCors(req, res, { methods: 'GET, POST, OPTIONS' })) return;

  const user = await getUserFromRequest(req);
  if (!user) return res.status(401).json({ error: 'Unauthorized' });

  const supabase = getSupabaseAdmin();

  // GET — active protocols, prescriptions, and adherence history
  if (req.method === 'GET') {
    const { data: protocols } = await supabase
      .from('patient_protocols')
      .select('*')
      .eq('user_id', user.id)
      .eq('status', 'active')
      .order('started_at', { ascending: false });

    const { data: prescriptions } = await supabase
      .from('patient_prescriptions')
      .select('*')
      .eq('user_id', user.id)
      .eq('status', 'active');

    // Last 14 days of adherence logs
    const fourteenDaysAgo = new Date(Date.now() - 14 * 86400000).toISOString();
    const { data: adherenceLogs } = await supabase
      .from('protocol_adherence_logs')
      .select('*')
      .eq('user_id', user.id)
      .gte('created_at', fourteenDaysAgo)
      .order('created_at', { ascending: false });

    // Compute adherence rate
    const taken = (adherenceLogs || []).filter(l => l.status === 'taken').length;
    const total = (adherenceLogs || []).filter(l => l.status !== 'scheduled').length;
    const adherenceRate = total > 0 ? Math.round(taken / total * 100) : null;

    return res.status(200).json({
      protocols: protocols || [],
      prescriptions: prescriptions || [],
      adherence_logs: adherenceLogs || [],
      adherence_rate: adherenceRate,
    });
  }

  // POST — log a dose
  if (req.method === 'POST') {
    const { prescription_id, protocol_id, status, dose, notes, side_effects } = req.body || {};

    if (!prescription_id || !status) {
      return res.status(400).json({ error: 'prescription_id and status required' });
    }

    const logData = {
      user_id: user.id,
      prescription_id,
      protocol_id: protocol_id || null,
      status, // 'taken', 'skipped'
      dose: dose || null,
      notes: notes || null,
      side_effects: side_effects || null,
      taken_at: status === 'taken' ? new Date().toISOString() : null,
      scheduled_for: new Date().toISOString(),
    };

    const { data, error } = await supabase
      .from('protocol_adherence_logs')
      .insert(logData)
      .select()
      .single();

    if (error) return res.status(500).json({ error: error.message });
    return res.status(201).json({ log: data });
  }

  return res.status(405).json({ error: 'Method not allowed' });
};
