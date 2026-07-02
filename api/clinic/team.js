const { applyCors, rateLimit, clientIp } = require('../../lib/security');
const { getSupabaseAdmin, requireClinicAccess } = require('../../lib/supabase-admin');
const { auditLog } = require('../../lib/audit');

module.exports = async function handler(req, res) {
  if (applyCors(req, res, { methods: 'GET, POST, PUT, DELETE, OPTIONS' })) return;

  const auth = await requireClinicAccess(req, res);
  if (!auth) return;
  const { user } = auth;

  // Rate limit: 20/min
  const rl = rateLimit({ key: 'clinic-team', ip: clientIp(req), limit: 20, windowMs: 60000 });
  if (!rl.ok) return res.status(429).json({ error: 'Rate limit exceeded' });

  const supabase = getSupabaseAdmin();

  if (req.method === 'GET') {
    const { data } = await supabase
      .from('clinic_team_members')
      .select('*')
      .eq('clinic_id', user.id)
      .order('created_at', { ascending: true });
    return res.status(200).json({ team: data || [] });
  }

  if (req.method === 'POST') {
    const { email, name, role, permissions } = req.body || {};
    if (!email) return res.status(400).json({ error: 'Email required' });

    const { data, error } = await supabase
      .from('clinic_team_members')
      .insert({
        clinic_id: user.id,
        email,
        name: name || email.split('@')[0],
        role: role || 'staff',
        permissions: permissions || undefined,
        status: 'invited',
      })
      .select()
      .single();

    if (error) return res.status(500).json({ error: error.message });

    auditLog(supabase, {
      clinician_id: user.id,
      action: 'team_member_changed',
      target_type: 'team_member',
      target_id: data.id,
      details: { operation: 'added', email, role: role || 'staff' },
    });

    return res.status(201).json({ member: data });
  }

  if (req.method === 'PUT') {
    const { id, role, permissions, status } = req.body || {};
    if (!id) return res.status(400).json({ error: 'Member ID required' });

    const updates = {};
    if (role) updates.role = role;
    if (permissions) updates.permissions = permissions;
    if (status) updates.status = status;

    const { data, error } = await supabase
      .from('clinic_team_members')
      .update(updates)
      .eq('id', id)
      .eq('clinic_id', user.id)
      .select()
      .single();

    if (error) return res.status(500).json({ error: error.message });

    auditLog(supabase, {
      clinician_id: user.id,
      action: 'team_member_changed',
      target_type: 'team_member',
      target_id: id,
      details: { operation: 'updated', updates },
    });

    return res.status(200).json({ member: data });
  }

  if (req.method === 'DELETE') {
    const { id } = req.body || {};
    if (!id) return res.status(400).json({ error: 'Member ID required' });

    await supabase
      .from('clinic_team_members')
      .delete()
      .eq('id', id)
      .eq('clinic_id', user.id);

    auditLog(supabase, {
      clinician_id: user.id,
      action: 'team_member_changed',
      target_type: 'team_member',
      target_id: id,
      details: { operation: 'removed' },
    });

    return res.status(200).json({ ok: true });
  }

  return res.status(405).json({ error: 'Method not allowed' });
};
