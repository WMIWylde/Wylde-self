const { applyCors } = require('../../lib/security');
const { getSupabaseAdmin, getUserFromRequest } = require('../../lib/supabase-admin');

module.exports = async function handler(req, res) {
  if (applyCors(req, res, { methods: 'POST, OPTIONS' })) return;
  if (req.method !== 'POST') return res.status(405).json({ error: 'Method not allowed' });

  const user = await getUserFromRequest(req);
  if (!user) return res.status(401).json({ error: 'Unauthorized' });

  const supabase = getSupabaseAdmin();
  const { patient_id, protocol_name, phase, prescriptions } = req.body || {};

  if (!patient_id || !protocol_name) {
    return res.status(400).json({ error: 'patient_id and protocol_name required' });
  }

  // Verify care relationship exists
  const { data: rel } = await supabase
    .from('care_relationships')
    .select('id')
    .eq('clinician_id', user.id)
    .eq('patient_id', patient_id)
    .eq('status', 'active')
    .single();

  if (!rel) return res.status(403).json({ error: 'No active care relationship with this patient' });

  // Create the protocol
  const { data: protocol, error: protErr } = await supabase
    .from('patient_protocols')
    .insert({
      user_id: patient_id,
      name: protocol_name,
      phase: phase || 'Active',
      status: 'active',
      assigned_by: user.id,
    })
    .select()
    .single();

  if (protErr) return res.status(500).json({ error: protErr.message });

  // Add prescriptions if provided
  if (Array.isArray(prescriptions) && prescriptions.length > 0) {
    const rxRows = prescriptions.map(rx => ({
      protocol_id: protocol.id,
      user_id: patient_id,
      drug: rx.drug || rx.name,
      dose: rx.dose || rx.typical_dose || '',
      frequency: rx.frequency || 'daily',
      timing: rx.timing || null,
      method: rx.method || null,
      status: 'active',
    }));

    const { error: rxErr } = await supabase
      .from('patient_prescriptions')
      .insert(rxRows);

    if (rxErr) console.error('[assign-protocol] rx insert error:', rxErr.message);
  }

  return res.status(201).json({
    ok: true,
    protocol: {
      id: protocol.id,
      name: protocol.name,
      phase: protocol.phase,
      prescriptions_count: prescriptions?.length || 0,
    },
  });
};
