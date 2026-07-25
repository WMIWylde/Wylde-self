// POST /api/consumer/care/join { code } — PATIENT enters a code to connect
// to a clinic. Accepts either a clinic's permanent join code or a one-time
// invite code created by a clinician. (The mirror of care/accept, which is
// the clinician entering a patient-generated code.)
const { applyCors, rateLimit, clientIp } = require('../../../lib/security');
const { getSupabaseAdmin, getUserFromRequest } = require('../../../lib/supabase-admin');

module.exports = async function handler(req, res) {
  if (applyCors(req, res, { methods: 'POST, OPTIONS' })) return;
  if (req.method !== 'POST') return res.status(405).json({ error: 'Method not allowed' });

  const user = await getUserFromRequest(req);
  if (!user) return res.status(401).json({ error: 'Unauthorized' });

  const rl = rateLimit({ key: 'care-join', ip: clientIp(req), limit: 5, windowMs: 60000 });
  if (!rl.ok) return res.status(429).json({ error: 'Rate limit exceeded' });

  const supabase = getSupabaseAdmin();
  const raw = (req.body || {}).code;
  if (!raw) return res.status(400).json({ error: 'Code is required' });
  const code = String(raw).toUpperCase().trim();

  // 1. Permanent clinic join code
  const { data: clinic } = await supabase
    .from('clinic_settings')
    .select('clinician_id, clinic_name, status, join_code')
    .eq('join_code', code)
    .maybeSingle();

  if (clinic) {
    if (clinic.status !== 'approved') {
      return res.status(403).json({ error: 'This clinic is not active yet' });
    }
    const { error: relErr } = await supabase.from('care_relationships').upsert({
      patient_id: user.id,
      clinician_id: clinic.clinician_id,
      clinic_name: clinic.clinic_name || null,
      status: 'active',
      linked_at: new Date().toISOString(),
    }, { onConflict: 'patient_id,clinician_id' });
    if (relErr) return res.status(500).json({ error: relErr.message });
    return res.status(200).json({ linked: true, clinic_name: clinic.clinic_name });
  }

  // 2. One-time code created by a clinician (care_invite_codes row whose
  // creator has a clinic) — patient redeems it.
  const { data: invite } = await supabase
    .from('care_invite_codes')
    .select('*')
    .eq('code', code)
    .eq('status', 'pending')
    .maybeSingle();

  if (!invite) return res.status(404).json({ error: 'Invalid or expired code' });
  if (new Date(invite.expires_at) < new Date()) {
    await supabase.from('care_invite_codes').update({ status: 'expired' }).eq('id', invite.id);
    return res.status(410).json({ error: 'Code has expired' });
  }

  const { data: creatorClinic } = await supabase
    .from('clinic_settings')
    .select('clinician_id, clinic_name, status')
    .eq('clinician_id', invite.user_id)
    .maybeSingle();

  if (!creatorClinic) {
    // Code was created by a patient — this endpoint is for patients joining
    // clinics; tell them which side of the flow they're on.
    return res.status(400).json({ error: 'This code should be entered by your clinician, not by you' });
  }
  if (creatorClinic.status !== 'approved') {
    return res.status(403).json({ error: 'This clinic is not active yet' });
  }

  const { error: relErr } = await supabase.from('care_relationships').upsert({
    patient_id: user.id,
    clinician_id: creatorClinic.clinician_id,
    clinic_name: creatorClinic.clinic_name || null,
    status: 'active',
    linked_at: new Date().toISOString(),
  }, { onConflict: 'patient_id,clinician_id' });
  if (relErr) return res.status(500).json({ error: relErr.message });

  await supabase.from('care_invite_codes').update({ status: 'used', used_by: user.id, used_at: new Date().toISOString() }).eq('id', invite.id);
  return res.status(200).json({ linked: true, clinic_name: creatorClinic.clinic_name });
};
