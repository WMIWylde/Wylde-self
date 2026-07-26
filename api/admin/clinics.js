// Admin: Clinic management — /api/admin/clinics
// GET  — list all clinics (with optional ?status=pending filter)
// PATCH — approve / suspend a clinic by clinician_id

const crypto = require('crypto');
const { getSupabaseAdmin } = require('../../lib/supabase-admin');

function secretMatches(provided, expected) {
  if (!expected || typeof provided !== 'string') return false;
  const a = Buffer.from(provided);
  const b = Buffer.from(expected);
  if (a.length !== b.length) return false;
  return crypto.timingSafeEqual(a, b);
}

function requireAdmin(req, res) {
  const secret = req.headers['x-admin-secret'];
  if (!process.env.ADMIN_SECRET || !secretMatches(secret, process.env.ADMIN_SECRET)) {
    res.status(401).json({ error: 'Unauthorized' });
    return false;
  }
  return true;
}

module.exports = async function handler(req, res) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type, X-Admin-Secret');
  res.setHeader('Access-Control-Allow-Methods', 'GET, PATCH, OPTIONS');
  if (req.method === 'OPTIONS') return res.status(204).end();
  if (!requireAdmin(req, res)) return;

  const supabase = getSupabaseAdmin();

  // GET — list clinics
  if (req.method === 'GET') {
    let query = supabase
      .from('clinic_settings')
      .select('clinician_id, clinic_name, clinic_type, status, email, phone, city, state, onboarding_complete, created_at, updated_at')
      .order('created_at', { ascending: false });

    const statusFilter = req.query?.status;
    if (statusFilter) {
      query = query.eq('status', statusFilter);
    }

    const { data, error } = await query;
    if (error) return res.status(500).json({ error: error.message });

    // Enrich with signup emails from Supabase Auth
    try {
      const { data: list } = await supabase.auth.admin.listUsers({ page: 1, perPage: 1000 });
      const emailById = {};
      (list && list.users || []).forEach((u) => { emailById[u.id] = u.email; });
      const enriched = (data || []).map((c) => ({
        ...c,
        signup_email: emailById[c.clinician_id] || null,
      }));
      return res.status(200).json({ clinics: enriched, count: enriched.length });
    } catch (_) {
      // Fall back without signup emails if auth admin isn't available
      return res.status(200).json({ clinics: data, count: data.length });
    }
  }

  // PATCH — update clinic status (approve / suspend)
  if (req.method === 'PATCH') {
    const { clinician_id, status } = req.body || {};

    if (!clinician_id) {
      return res.status(400).json({ error: 'clinician_id is required' });
    }
    if (!['approved', 'suspended', 'pending'].includes(status)) {
      return res.status(400).json({ error: 'status must be approved, suspended, or pending' });
    }

    const updates = { status, updated_at: new Date().toISOString() };
    if (status === 'approved') {
      updates.approved = true;
      updates.approved_at = new Date().toISOString();
    }

    const { data, error } = await supabase
      .from('clinic_settings')
      .update(updates)
      .eq('clinician_id', clinician_id)
      .select('clinician_id, clinic_name, status, approved_at')
      .single();

    if (error) return res.status(500).json({ error: error.message });
    if (!data) return res.status(404).json({ error: 'Clinic not found' });

    return res.status(200).json({ clinic: data });
  }

  return res.status(405).json({ error: 'GET or PATCH only' });
};
