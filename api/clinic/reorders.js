const { applyCors } = require('../../lib/security');
const { getSupabaseAdmin, getUserFromRequest } = require('../../lib/supabase-admin');

module.exports = async function handler(req, res) {
  if (applyCors(req, res, { methods: 'GET, PUT, OPTIONS' })) return;

  const user = await getUserFromRequest(req);
  if (!user) return res.status(401).json({ error: 'Unauthorized' });

  const supabase = getSupabaseAdmin();

  // GET — list reorder requests for this clinician
  if (req.method === 'GET') {
    const { data } = await supabase
      .from('reorder_requests')
      .select('*, clinic_products(name, category, price, price_unit)')
      .eq('clinician_id', user.id)
      .order('created_at', { ascending: false })
      .limit(50);

    // Enrich with patient names
    const orders = [];
    for (const order of (data || [])) {
      const { data: profile } = await supabase
        .from('profiles')
        .select('profile_data, email')
        .eq('id', order.patient_id)
        .single();
      const pd = profile?.profile_data || {};
      orders.push({
        ...order,
        patient_name: pd.name || profile?.email?.split('@')[0] || 'Patient',
        patient_email: profile?.email || '',
      });
    }

    return res.status(200).json({ orders });
  }

  // PUT — update reorder status (approve, reject, fulfill, cancel)
  if (req.method === 'PUT') {
    const { id, status, clinician_note } = req.body || {};

    if (!id || !status) return res.status(400).json({ error: 'id and status required' });
    if (!['approved', 'rejected', 'fulfilled', 'cancelled'].includes(status)) {
      return res.status(400).json({ error: 'Invalid status' });
    }

    const updates = { status, updated_at: new Date().toISOString() };
    if (clinician_note) updates.clinician_note = clinician_note;

    const { data, error } = await supabase
      .from('reorder_requests')
      .update(updates)
      .eq('id', id)
      .eq('clinician_id', user.id)
      .select()
      .single();

    if (error) return res.status(500).json({ error: error.message });
    return res.status(200).json({ order: data });
  }

  return res.status(405).json({ error: 'Method not allowed' });
};
