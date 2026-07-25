// Clinic approvals — /api/admin/clinics
// GET: list clinics (with signup email). POST { clinician_id, action: approve|suspend }
const crypto = require('crypto');
const { getSupabaseAdmin } = require('../../lib/supabase-admin');

function secretMatches(provided, expected) {
  if (!expected || typeof provided !== 'string') return false;
  const a = Buffer.from(provided);
  const b = Buffer.from(expected);
  if (a.length !== b.length) return false;
  return crypto.timingSafeEqual(a, b);
}

module.exports = async function handler(req, res) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type, X-Admin-Secret');
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  if (req.method === 'OPTIONS') return res.status(204).end();

  const secret = req.headers['x-admin-secret'];
  if (!process.env.ADMIN_SECRET || !secretMatches(secret, process.env.ADMIN_SECRET)) {
    return res.status(401).json({ error: 'Unauthorized' });
  }

  const supabase = getSupabaseAdmin();

  if (req.method === 'GET') {
    const { data: clinics } = await supabase
      .from('clinic_settings')
      .select('clinician_id, clinic_name, status, created_at')
      .order('created_at', { ascending: false })
      .limit(100);
    // Attach signup emails via auth admin
    const { data: list } = await supabase.auth.admin.listUsers({ page: 1, perPage: 1000 });
    const emailById = {};
    (list && list.users || []).forEach((u) => { emailById[u.id] = u.email; });
    const out = (clinics || []).map((c) => ({ ...c, email: emailById[c.clinician_id] || null }));
    return res.status(200).json({ clinics: out });
  }

  if (req.method === 'POST') {
    const { clinician_id, action } = req.body || {};
    if (!clinician_id || !['approve', 'suspend'].includes(action)) {
      return res.status(400).json({ error: 'clinician_id and action (approve|suspend) required' });
    }
    const status = action === 'approve' ? 'approved' : 'suspended';
    const { error } = await supabase
      .from('clinic_settings')
      .update({ status })
      .eq('clinician_id', clinician_id);
    if (error) return res.status(500).json({ error: error.message });
    return res.status(200).json({ ok: true, status });
  }

  return res.status(405).json({ error: 'Method not allowed' });
};
