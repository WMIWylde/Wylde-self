// Server-side Supabase client using the service role key.
// Used by /api/consumer/* endpoints to read/write clinical data.

const { createClient } = require('@supabase/supabase-js');

let _client = null;

function getSupabaseAdmin() {
  if (_client) return _client;
  const url = process.env.SUPABASE_URL || process.env.NEXT_PUBLIC_SUPABASE_URL;
  const key = process.env.SUPABASE_SERVICE_KEY || process.env.SUPABASE_SERVICE_ROLE_KEY;
  if (!url || !key) throw new Error('SUPABASE_URL and SUPABASE_SERVICE_KEY must be set');
  _client = createClient(url, key, { auth: { persistSession: false } });
  return _client;
}

// Extract user ID from the Authorization: Bearer <jwt> header.
// Uses Supabase's auth.getUser() to verify the token server-side.
async function getUserFromRequest(req) {
  const auth = req.headers.authorization || req.headers.Authorization || '';
  const token = auth.replace(/^Bearer\s+/i, '');
  if (!token) return null;

  const url = process.env.SUPABASE_URL || process.env.NEXT_PUBLIC_SUPABASE_URL;
  const anonKey = process.env.SUPABASE_ANON_KEY || process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY;
  if (!url || !anonKey) return null;

  const userClient = createClient(url, anonKey, {
    auth: { persistSession: false },
    global: { headers: { Authorization: `Bearer ${token}` } },
  });

  const { data: { user }, error } = await userClient.auth.getUser();
  if (error || !user) return null;
  return user;
}

// Verify the authenticated user is an approved clinician.
// Returns { user, clinic } on success, or sends an error response and returns null.
async function requireClinicAccess(req, res) {
  const user = await getUserFromRequest(req);
  if (!user) {
    res.status(401).json({ error: 'Unauthorized' });
    return null;
  }

  const supabase = getSupabaseAdmin();
  let { data: clinic } = await supabase
    .from('clinic_settings')
    .select('*')
    .eq('clinician_id', user.id)
    .maybeSingle();

  // Team members: no clinic of their own, but an active/invited membership
  // in someone else's — they operate within the owner's clinic.
  if (!clinic && user.email) {
    const { data: membership } = await supabase
      .from('clinic_team_members')
      .select('clinician_id, status')
      .ilike('email', user.email)
      .in('status', ['invited', 'active'])
      .maybeSingle();
    if (membership) {
      const { data: ownerClinic } = await supabase
        .from('clinic_settings')
        .select('*')
        .eq('clinician_id', membership.clinician_id)
        .maybeSingle();
      clinic = ownerClinic;
      // First authenticated visit activates the membership
      if (membership.status === 'invited') {
        await supabase.from('clinic_team_members')
          .update({ status: 'active', member_user_id: user.id })
          .ilike('email', user.email);
      }
    }
  }

  // Require an explicitly approved clinic — pending/suspended/missing are denied.
  if (!clinic || clinic.status !== 'approved') {
    res.status(403).json({ error: 'Not an approved clinician' });
    return null;
  }

  // Billing gate — only enforced when BILLING_ENFORCED=true. 'comped'
  // (the default) always passes, so flipping enforcement on never locks
  // out clinics you haven't deliberately moved to paid.
  if (process.env.BILLING_ENFORCED === 'true') {
    const ok = ['comped', 'active', 'trialing'].includes(clinic.billing_status || 'comped');
    if (!ok) {
      res.status(402).json({ error: 'Subscription required', billing_status: clinic.billing_status });
      return null;
    }
  }

  // clinicianId = the clinic OWNER's id — all clinic data is scoped to it,
  // so team members read/write the same clinic the owner does.
  return { user, clinic, clinicianId: clinic.clinician_id };
}

module.exports = { getSupabaseAdmin, getUserFromRequest, requireClinicAccess };
