// POST /api/decoda/link-patient — link the signed-in Wylde user to a Decoda patient.
// Creates the patient in Decoda (external_id = Wylde user id) and stores the
// mapping in decoda_links. Idempotent: re-linking returns the existing link.
const { applyCors, rateLimit, clientIp } = require('../../lib/security');
const { getSupabaseAdmin, getUserFromRequest } = require('../../lib/supabase-admin');
const decoda = require('../../lib/decoda');

module.exports = async function handler(req, res) {
  if (applyCors(req, res, { methods: 'POST, OPTIONS' })) return;
  if (req.method !== 'POST') return res.status(405).json({ error: 'Method not allowed' });

  const user = await getUserFromRequest(req);
  if (!user) return res.status(401).json({ error: 'Unauthorized' });

  const limit = rateLimit({ key: 'decoda-link', ip: clientIp(req), limit: 5, windowMs: 60_000 });
  if (!limit.ok) return res.status(429).json({ error: 'Rate limit exceeded' });

  const supabase = getSupabaseAdmin();

  try {
    // Already linked?
    const { data: existing } = await supabase
      .from('decoda_links')
      .select('decoda_patient_id, linked_at')
      .eq('user_id', user.id)
      .maybeSingle();
    if (existing) {
      return res.status(200).json({ linked: true, decoda_patient_id: existing.decoda_patient_id, existing: true });
    }

    const { data: profile } = await supabase
      .from('profiles')
      .select('first_name, last_name, email, phone')
      .eq('id', user.id)
      .single();

    const email = (profile && profile.email) || user.email;
    if (!email) return res.status(400).json({ error: 'No email on profile' });

    const patient = await decoda.createPatient({
      firstName: (profile && profile.first_name) || 'Wylde',
      lastName: (profile && profile.last_name) || 'Member',
      email,
      phoneNumber: profile && profile.phone,
      externalId: user.id,
    });

    const { error: insertErr } = await supabase.from('decoda_links').insert({
      user_id: user.id,
      decoda_patient_id: patient.id,
      linked_at: new Date().toISOString(),
      source: 'app',
    });
    if (insertErr) throw insertErr;

    return res.status(200).json({ linked: true, decoda_patient_id: patient.id });
  } catch (err) {
    // 409 = patient already exists in Decoda for this email — surface cleanly
    if (err.status === 409) {
      return res.status(409).json({ error: 'Patient already exists in Decoda. Link via webhook or ask clinic to resolve.' });
    }
    console.error('[decoda/link-patient]', err.message);
    return res.status(500).json({ error: 'Failed to link patient' });
  }
};
