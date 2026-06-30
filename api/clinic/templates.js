const { applyCors } = require('../../lib/security');
const { getSupabaseAdmin, getUserFromRequest } = require('../../lib/supabase-admin');

module.exports = async function handler(req, res) {
  if (applyCors(req, res, { methods: 'GET, POST, PUT, DELETE, OPTIONS' })) return;

  const user = await getUserFromRequest(req);
  if (!user) return res.status(401).json({ error: 'Unauthorized' });

  const supabase = getSupabaseAdmin();

  if (req.method === 'GET') {
    const { data } = await supabase
      .from('clinic_message_templates')
      .select('*')
      .eq('clinic_id', user.id)
      .order('category', { ascending: true });
    return res.status(200).json({ templates: data || [] });
  }

  if (req.method === 'POST') {
    const { name, category, body: msgBody } = req.body || {};
    if (!name || !msgBody) return res.status(400).json({ error: 'name and body required' });

    const { data, error } = await supabase
      .from('clinic_message_templates')
      .insert({ clinic_id: user.id, name, category: category || 'general', body: msgBody })
      .select()
      .single();

    if (error) return res.status(500).json({ error: error.message });
    return res.status(201).json({ template: data });
  }

  if (req.method === 'PUT') {
    const { id, name, category, body: msgBody, is_active } = req.body || {};
    if (!id) return res.status(400).json({ error: 'Template ID required' });

    const updates = {};
    if (name !== undefined) updates.name = name;
    if (category !== undefined) updates.category = category;
    if (msgBody !== undefined) updates.body = msgBody;
    if (is_active !== undefined) updates.is_active = is_active;

    const { data, error } = await supabase
      .from('clinic_message_templates')
      .update(updates)
      .eq('id', id)
      .eq('clinic_id', user.id)
      .select()
      .single();

    if (error) return res.status(500).json({ error: error.message });
    return res.status(200).json({ template: data });
  }

  if (req.method === 'DELETE') {
    const { id } = req.body || {};
    if (!id) return res.status(400).json({ error: 'Template ID required' });
    await supabase.from('clinic_message_templates').delete().eq('id', id).eq('clinic_id', user.id);
    return res.status(200).json({ ok: true });
  }

  return res.status(405).json({ error: 'Method not allowed' });
};
