const { applyCors, rateLimit, clientIp } = require('../../lib/security');
const { getSupabaseAdmin, getUserFromRequest } = require('../../lib/supabase-admin');
const { auditLog } = require('../../lib/audit');

module.exports = async function handler(req, res) {
  if (applyCors(req, res, { methods: 'GET, POST, OPTIONS' })) return;

  const user = await getUserFromRequest(req);
  if (!user) return res.status(401).json({ error: 'Unauthorized' });

  // Rate limit messages: 30/min
  const rl = rateLimit({ key: 'messages', ip: clientIp(req), limit: 30, windowMs: 60000 });
  if (!rl.ok) return res.status(429).json({ error: 'Rate limit exceeded' });

  const supabase = getSupabaseAdmin();

  // Find active care relationships for this user (as patient or clinician)
  const { data: rels } = await supabase
    .from('care_relationships')
    .select('id, patient_id, clinician_id')
    .or(`patient_id.eq.${user.id},clinician_id.eq.${user.id}`)
    .eq('status', 'active');

  if (!rels || rels.length === 0) {
    return res.status(403).json({ error: 'No active care relationship' });
  }

  // Build set of relationship IDs this user is part of (for IDOR protection)
  const userRelIds = new Set(rels.map(r => r.id));

  // GET — fetch messages
  if (req.method === 'GET') {
    const relId = req.query.relationship_id || rels[0].id;

    // IDOR fix: verify the user is a member of this relationship
    if (!userRelIds.has(relId)) {
      return res.status(403).json({ error: 'Access denied to this conversation' });
    }

    const limit = parseInt(req.query.limit) || 50;

    const { data: messages } = await supabase
      .from('care_messages')
      .select('*')
      .eq('relationship_id', relId)
      .order('created_at', { ascending: true })
      .limit(limit);

    // Mark unread messages as read
    await supabase
      .from('care_messages')
      .update({ read_at: new Date().toISOString() })
      .eq('relationship_id', relId)
      .eq('recipient_id', user.id)
      .is('read_at', null);

    return res.status(200).json({
      messages: messages || [],
      relationship_id: relId,
    });
  }

  // POST — send message
  if (req.method === 'POST') {
    const { body: msgBody, relationship_id, message_type } = req.body || {};

    if (!msgBody || !msgBody.trim()) {
      return res.status(400).json({ error: 'Message body required' });
    }

    // Find the relationship and determine recipient
    const relId = relationship_id || rels[0].id;
    const rel = rels.find(r => r.id === relId);
    if (!rel) return res.status(403).json({ error: 'Invalid relationship' });

    const recipientId = rel.patient_id === user.id ? rel.clinician_id : rel.patient_id;

    const { data, error } = await supabase
      .from('care_messages')
      .insert({
        relationship_id: relId,
        sender_id: user.id,
        recipient_id: recipientId,
        body: msgBody.trim(),
        message_type: message_type || 'general',
      })
      .select()
      .single();

    if (error) return res.status(500).json({ error: error.message });

    auditLog(supabase, {
      clinician_id: rel.clinician_id,
      action: 'message_sent',
      target_type: 'care_message',
      target_id: data.id,
      details: { relationship_id: relId, sender_id: user.id },
    });

    return res.status(201).json({ message: data });
  }

  return res.status(405).json({ error: 'Method not allowed' });
};
