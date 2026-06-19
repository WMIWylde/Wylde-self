const { applyCors } = require('../../../lib/security');
const { getSupabaseAdmin, getUserFromRequest } = require('../../../lib/supabase-admin');

module.exports = async function handler(req, res) {
  if (applyCors(req, res, { methods: 'GET, DELETE, OPTIONS' })) return;

  const user = await getUserFromRequest(req);
  if (!user) return res.status(401).json({ error: 'Unauthorized' });

  const supabase = getSupabaseAdmin();

  // DELETE — revoke access
  if (req.method === 'DELETE') {
    await supabase
      .from('care_relationships')
      .update({ status: 'revoked', revoked_at: new Date().toISOString() })
      .eq('patient_id', user.id)
      .eq('status', 'active');

    return res.status(200).json({ ok: true });
  }

  // GET — list relationships and pending invites
  if (req.method !== 'GET') return res.status(405).json({ error: 'Method not allowed' });

  // Active relationship (as patient)
  const { data: relationship } = await supabase
    .from('care_relationships')
    .select('patient_id, clinician_id, clinic_name, linked_at')
    .eq('patient_id', user.id)
    .eq('status', 'active')
    .order('linked_at', { ascending: false })
    .limit(1)
    .single();

  // Also check if user is a clinician with patients
  const { data: clinicianRels } = await supabase
    .from('care_relationships')
    .select('patient_id, clinic_name, linked_at')
    .eq('clinician_id', user.id)
    .eq('status', 'active');

  // Pending invites
  const { data: invites } = await supabase
    .from('care_invite_codes')
    .select('code, status, message, access_level, expires_at, created_at')
    .eq('user_id', user.id)
    .in('status', ['pending'])
    .order('created_at', { ascending: false })
    .limit(5);

  return res.status(200).json({
    active_relationship: relationship ? {
      patient_id: relationship.patient_id,
      linked_at: relationship.linked_at,
      clinic: relationship.clinic_name ? { name: relationship.clinic_name } : null,
    } : null,
    clinician_patients: (clinicianRels || []).map(r => ({
      patient_id: r.patient_id,
      linked_at: r.linked_at,
    })),
    pending_invites: (invites || []).map(i => ({
      code: i.code,
      status: i.status,
      message: i.message,
      access_level: i.access_level,
      expires_at: i.expires_at,
      created_at: i.created_at,
    })),
  });
};
