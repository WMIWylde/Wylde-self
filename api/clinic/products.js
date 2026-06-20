const { applyCors } = require('../../lib/security');
const { getSupabaseAdmin, getUserFromRequest } = require('../../lib/supabase-admin');

module.exports = async function handler(req, res) {
  if (applyCors(req, res, { methods: 'GET, POST, PUT, DELETE, OPTIONS' })) return;

  const user = await getUserFromRequest(req);
  if (!user) return res.status(401).json({ error: 'Unauthorized' });

  const supabase = getSupabaseAdmin();

  // GET — list clinician's products
  if (req.method === 'GET') {
    const { data, error } = await supabase
      .from('clinic_products')
      .select('*')
      .eq('clinician_id', user.id)
      .eq('is_active', true)
      .order('sort_order', { ascending: true });

    if (error) return res.status(500).json({ error: error.message });
    return res.status(200).json({ products: data || [] });
  }

  // POST — create new product
  if (req.method === 'POST') {
    const body = req.body || {};
    const { data, error } = await supabase
      .from('clinic_products')
      .insert({
        clinician_id: user.id,
        name: body.name,
        category: body.category || 'supplement',
        description: body.description,
        mechanism: body.mechanism,
        benefits: body.benefits || [],
        contraindications: body.contraindications || [],
        typical_dose: body.typical_dose,
        cycle_length: body.cycle_length,
        frequency: body.frequency,
        method: body.method,
        price: body.price,
        price_unit: body.price_unit || 'per unit',
        in_stock: body.in_stock !== false,
        notes: body.notes,
      })
      .select()
      .single();

    if (error) return res.status(500).json({ error: error.message });
    return res.status(201).json({ product: data });
  }

  // PUT — update product
  if (req.method === 'PUT') {
    const { id, ...updates } = req.body || {};
    if (!id) return res.status(400).json({ error: 'Product ID required' });

    const { data, error } = await supabase
      .from('clinic_products')
      .update({ ...updates, updated_at: new Date().toISOString() })
      .eq('id', id)
      .eq('clinician_id', user.id)
      .select()
      .single();

    if (error) return res.status(500).json({ error: error.message });
    return res.status(200).json({ product: data });
  }

  // DELETE — soft delete
  if (req.method === 'DELETE') {
    const { id } = req.body || {};
    if (!id) return res.status(400).json({ error: 'Product ID required' });

    await supabase
      .from('clinic_products')
      .update({ is_active: false })
      .eq('id', id)
      .eq('clinician_id', user.id);

    return res.status(200).json({ ok: true });
  }

  return res.status(405).json({ error: 'Method not allowed' });
};
