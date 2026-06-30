const { applyCors } = require('../../lib/security');
const { getSupabaseAdmin } = require('../../lib/supabase-admin');

module.exports = async function handler(req, res) {
  if (applyCors(req, res, { methods: 'GET, OPTIONS' })) return;
  if (req.method !== 'GET') return res.status(405).json({ error: 'Method not allowed' });

  const supabase = getSupabaseAdmin();
  const { slug } = req.query;

  if (slug) {
    const { data: protocol } = await supabase
      .from('therapy_protocols')
      .select('*')
      .eq('slug', slug)
      .eq('is_public', true)
      .single();

    if (!protocol) return res.status(404).json({ error: 'Protocol not found' });

    const { data: components } = await supabase
      .from('protocol_components')
      .select('*, therapies(slug, name, therapy_type, short_description, evidence_rating)')
      .eq('protocol_id', protocol.id)
      .order('display_order');

    return res.status(200).json({ protocol, components: components || [] });
  }

  const { data } = await supabase
    .from('therapy_protocols')
    .select('id, slug, name, category, goal, consumer_description, typical_duration, evidence_rating')
    .eq('is_public', true)
    .order('name');

  return res.status(200).json({ protocols: data || [] });
};
