const { applyCors } = require('../../../lib/security');
const { getSupabaseAdmin, getUserFromRequest } = require('../../../lib/supabase-admin');

module.exports = async function handler(req, res) {
  if (applyCors(req, res, { methods: 'POST, OPTIONS' })) return;
  if (req.method !== 'POST') return res.status(405).json({ error: 'Method not allowed' });

  const user = await getUserFromRequest(req);
  if (!user) return res.status(401).json({ error: 'Unauthorized' });

  const supabase = getSupabaseAdmin();
  const { message } = req.body || {};

  // Generate a 6-character alphanumeric code
  const code = generateCode();
  const expiresAt = new Date(Date.now() + 7 * 24 * 60 * 60 * 1000).toISOString(); // 7 days

  const { data, error } = await supabase
    .from('care_invite_codes')
    .insert({
      user_id: user.id,
      code,
      message: message || null,
      access_level: 'full',
      status: 'pending',
      expires_at: expiresAt,
    })
    .select('code, expires_at')
    .single();

  if (error) {
    console.error('[care/invite] error:', error.message);
    return res.status(500).json({ error: error.message });
  }

  return res.status(200).json({
    code: data.code,
    expires_at: data.expires_at,
    share_text: `Connect with me on Wylde Self. Use code: ${data.code}`,
  });
};

function generateCode() {
  const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // no ambiguous chars
  let code = '';
  for (let i = 0; i < 6; i++) {
    code += chars[Math.floor(Math.random() * chars.length)];
  }
  return code;
}
