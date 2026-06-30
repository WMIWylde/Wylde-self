const { applyCors } = require('../../lib/security');
const { getSupabaseAdmin, getUserFromRequest } = require('../../lib/supabase-admin');

module.exports = async function handler(req, res) {
  if (applyCors(req, res, { methods: 'GET, POST, OPTIONS' })) return;

  const user = await getUserFromRequest(req);
  if (!user) return res.status(401).json({ error: 'Unauthorized' });

  const supabase = getSupabaseAdmin();

  // GET — list notes for a patient
  if (req.method === 'GET') {
    const patientId = req.query.patient_id;
    if (!patientId) return res.status(400).json({ error: 'patient_id required' });

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
    return res.status(201).json({ note: data });
  }

  return res.status(405).json({ error: 'Method not allowed' });
};
