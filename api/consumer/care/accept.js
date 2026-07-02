const { applyCors, rateLimit, clientIp } = require('../../../lib/security');
const { getSupabaseAdmin, requireClinicAccess } = require('../../../lib/supabase-admin');
const { auditLog } = require('../../../lib/audit');

module.exports = async function handler(req, res) {
  if (applyCors(req, res, { methods: 'POST, OPTIONS' })) return;
  if (req.method !== 'POST') return res.status(405).json({ error: 'Method not allowed' });

  // Only approved clinicians can accept patient invite codes
  const auth = await requireClinicAccess(req, res);
  if (!auth) return;
  const { user } = auth;

  // Rate limit: 5 attempts per minute (brute-force protection)
  const rl = rateLimit({ key: 'care-accept', ip: clientIp(req), limit: 5, windowMs: 60000 });
  if (!rl.ok) return res.status(429).json({ error: 'Rate limit exceeded' });

  const supabase = getSupabaseAdmin();
  const { code } = req.body || {};

  if (!code) return res.status(400).json({ error: 'Code is required' });

  // Find the invite code
  const { data: invite, error: findErr } = await supabase
    .from('care_invite_codes')
    .select('*')
    .eq('code', code.toUpperCase().trim())
    .eq('status', 'pending')
    .single();

  if (findErr || !invite) {
    return res.status(404).json({ error: 'Invalid or expired code' });
  }

  // Check expiry
  if (new Date(invite.expires_at) < new Date()) {
    await supabase.from('care_invite_codes').update({ status: 'expired' }).eq('id', invite.id);
    return res.status(410).json({ error: 'Code has expired' });
  }

  // Can't accept your own code
  if (invite.user_id === user.id) {
    return res.status(400).json({ error: 'Cannot accept your own invite code' });
  }

  // Create the care relationship
  const { error: relErr } = await supabase
    .from('care_relationships')
    .upsert({
      patient_id: invite.user_id,
      clinician_id: user.id,
      status: 'active',
      linked_at: new Date().toISOString(),
    }, { onConflict: 'patient_id,clinician_id' });

  if (relErr) {
    console.error('[care/accept] relationship error:', relErr.message);
    return res.status(500).json({ error: relErr.message });
  }

  // Mark invite as accepted
  await supabase.from('care_invite_codes').update({
    status: 'accepted',
    accepted_by: user.id,
    updated_at: new Date().toISOString(),
  }).eq('id', invite.id);

  auditLog(supabase, {
    clinician_id: user.id,
    action: 'patient_linked',
    target_type: 'care_relationship',
    target_id: invite.user_id,
    details: { patient_id: invite.user_id, invite_id: invite.id },
  });

  return res.status(200).json({
    patient_id: invite.user_id,
    linked: true,
  });
};
