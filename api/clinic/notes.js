const { applyCors, rateLimit, clientIp } = require('../../lib/security');
const { getSupabaseAdmin, requireClinicAccess } = require('../../lib/supabase-admin');
const { auditLog } = require('../../lib/audit');

module.exports = async function handler(req, res) {
  if (applyCors(req, res, { methods: 'GET, POST, OPTIONS' })) return;

  const auth = await requireClinicAccess(req, res);
  if (!auth) return;
  const { user } = auth;

  // Rate limit: 30/min
  const rl = rateLimit({ key: 'clinic-notes', ip: clientIp(req), limit: 30, windowMs: 60000 });
  if (!rl.ok) return res.status(429).json({ error: 'Rate limit exceeded' });

  const supabase = getSupabaseAdmin();

  // GET — list notes for a patient
  if (req.method === 'GET') {
    const patientId = req.query.patient_id;
    if (!patientId) return res.status(400).json({ error: 'patient_id required' });

    // Verify care relationship exists
    const { data: rel } = await supabase
      .from('care_relationships')
      .select('id')
      .eq('clinician_id', user.id)
      .eq('patient_id', patientId)
      .eq('status', 'active')
      .single();

    if (!rel) return res.status(403).json({ error: 'No active care relationship with this patient' });

    const { data, error } = await supabase
      .from('patient_notes')
      .select('*')
      .eq('clinician_id', user.id)
      .eq('patient_id', patientId)
      .order('created_at', { ascending: false })
      .limit(50);

    if (error) return res.status(500).json({ error: error.message });
    return res.status(200).json({ notes: data || [] });
  }

  // POST — add a note
  if (req.method === 'POST') {
    const { patient_id, content, note_type } = req.body || {};
    if (!patient_id || !content) return res.status(400).json({ error: 'patient_id and content required' });

    // Verify care relationship exists
    const { data: rel } = await supabase
      .from('care_relationships')
      .select('id')
      .eq('clinician_id', user.id)
      .eq('patient_id', patient_id)
      .eq('status', 'active')
      .single();

    if (!rel) return res.status(403).json({ error: 'No active care relationship with this patient' });

    const { data, error } = await supabase
      .from('patient_notes')
      .insert({
        clinician_id: user.id,
        patient_id,
        content,
        note_type: note_type || 'general',
      })
      .select()
      .single();

    if (error) return res.status(500).json({ error: error.message });

    auditLog(supabase, {
      clinician_id: user.id,
      action: 'note_created',
      target_type: 'patient_note',
      target_id: data.id,
      details: { patient_id, note_type: note_type || 'general' },
    });

    return res.status(201).json({ note: data });
  }

  return res.status(405).json({ error: 'Method not allowed' });
};
