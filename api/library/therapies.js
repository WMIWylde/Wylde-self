const { applyCors } = require('../../lib/security');
const { getSupabaseAdmin, getUserFromRequest } = require('../../lib/supabase-admin');

module.exports = async function handler(req, res) {
  if (applyCors(req, res, { methods: 'GET, OPTIONS' })) return;
  if (req.method !== 'GET') return res.status(405).json({ error: 'Method not allowed' });

  const supabase = getSupabaseAdmin();
  const { type, category, search, slug } = req.query;

  // Single therapy by slug
  if (slug) {
    const { data } = await supabase
      .from('therapies')
      .select('*, therapy_references(*)')
      .eq('slug', slug)
      .eq('is_public', true)
      .single();

    if (!data) return res.status(404).json({ error: 'Therapy not found' });

    // Get related protocols
    const { data: components } = await supabase
      .from('protocol_components')
      .select('protocol_id, role_in_protocol, therapy_protocols(slug, name, category)')
      .eq('therapy_id', data.id);

    return res.status(200).json({ therapy: data, related_protocols: components || [] });
  }

  // List with filters
  let query = supabase.from('therapies').select('id, slug, name, therapy_type, category, short_description, evidence_rating, prescription_required, requires_provider_review, administration_routes, common_uses').eq('is_public', true).eq('review_status', 'approved');

  if (type) query = query.eq('therapy_type', type);
  if (category) query = query.eq('category', category);
  if (search) query = query.ilike('name', `%${search}%`);

  query = query.order('name');
  const { data, error } = await query;

  if (error) return res.status(500).json({ error: error.message });
  return res.status(200).json({ therapies: data || [] });
};
