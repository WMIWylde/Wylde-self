// Authentication: requires a valid Supabase JWT in the Authorization header.
const { applyCors, rateLimit, clientIp } = require('../lib/security');
const { getUserFromRequest } = require('../lib/supabase-admin');

const MAX_BODY_BYTES = 2 * 1024 * 1024; // 2MB for image payloads

module.exports = async function handler(req, res) {
  if (applyCors(req, res, { methods: 'POST, OPTIONS' })) return;
  if (req.method !== 'POST') return res.status(405).json({ error: 'Method not allowed' });

  // Verify Supabase JWT — reject unauthenticated requests
  const user = await getUserFromRequest(req);
  if (!user) return res.status(401).json({ error: 'Unauthorized' });

  const ip = clientIp(req);
  const limit = rateLimit({ key: 'openai', ip, limit: 30, windowMs: 60_000 });
  if (!limit.ok) {
    res.setHeader('Retry-After', String(limit.retryAfter));
    return res.status(429).json({ error: 'Rate limit exceeded' });
  }

  const bodyBytes = Buffer.byteLength(JSON.stringify(req.body || {}));
  if (bodyBytes > MAX_BODY_BYTES) {
    return res.status(413).json({ error: 'Payload too large' });
  }

  try {
    const { messages, model, max_tokens, temperature } = req.body || {};
    const start = Date.now();

    // Allow callers to request specific models. Default to gpt-4o.
    const allowedModels = ['gpt-4o', 'gpt-4o-mini', 'gpt-4.1', 'gpt-4.1-mini', 'o3-mini'];
    const requestedModel = allowedModels.includes(model) ? model : 'gpt-4o';

    const response = await fetch('https://api.openai.com/v1/chat/completions', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${process.env.OPENAI_API_KEY}`
      },
      body: JSON.stringify({
        model: requestedModel,
        max_tokens: max_tokens || 4096,
        temperature: temperature !== undefined ? temperature : 0.7,
        messages: messages || []
      })
    });

    const data = await response.json();
    const latency = Date.now() - start;
    console.log(`[openai] model=${requestedModel} status=${response.status} latency=${latency}ms tokens=${data.usage?.total_tokens || '?'}`);
    return res.status(response.status).json(data);
  } catch (err) {
    console.error(`[openai] error: ${err.message}`);
    return res.status(500).json({ error: 'Upstream request failed', message: err.message });
  }
};
