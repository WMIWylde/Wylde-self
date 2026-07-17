// GET /api/decoda/status — is the Decoda integration configured + reachable?
// Auth: any signed-in user (clinician dashboard calls this). Never exposes keys.
const { applyCors } = require('../../lib/security');
const { getUserFromRequest } = require('../../lib/supabase-admin');
const decoda = require('../../lib/decoda');

module.exports = async function handler(req, res) {
  if (applyCors(req, res, { methods: 'GET, OPTIONS' })) return;
  if (req.method !== 'GET') return res.status(405).json({ error: 'Method not allowed' });

  const user = await getUserFromRequest(req);
  if (!user) return res.status(401).json({ error: 'Unauthorized' });

  if (!decoda.isConfigured()) {
    return res.status(200).json({ configured: false, connected: false });
  }

  try {
    const tenant = await decoda.getTenantPublic();
    return res.status(200).json({
      configured: true,
      connected: true,
      tenant: { name: tenant && (tenant.name || tenant.tenantName || null) },
    });
  } catch (err) {
    console.error('[decoda/status]', err.message);
    return res.status(200).json({ configured: true, connected: false, error: 'Decoda unreachable' });
  }
};
