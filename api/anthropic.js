// Authentication: requires a valid Supabase JWT in the Authorization header.
const { applyCors, rateLimit, clientIp } = require('../lib/security');
const { getUserFromRequest } = require('../lib/supabase-admin');

const MAX_BODY_BYTES = 6 * 1024 * 1024; // 6MB — fits base64 phone-photo scans
const MAX_TOKENS_CEILING = 8192;

// Only allow known-good Claude models. This app uses Haiku per its docs.
const ALLOWED_MODELS = [
  'claude-3-5-haiku-20241022',
  'claude-haiku-4-5-20251001',
  'claude-3-5-sonnet-20241022',
];
const DEFAULT_MODEL = 'claude-3-5-haiku-20241022';

module.exports = async function handler(req, res) {
  if (applyCors(req, res, { methods: 'POST, OPTIONS' })) return;
  if (req.method !== 'POST') return res.status(405).json({ error: 'Method not allowed' });

  // Verify Supabase JWT — reject unauthenticated requests
  const user = await getUserFromRequest(req);
  if (!user) return res.status(401).json({ error: 'Unauthorized' });

  const ip = clientIp(req);
  const limit = rateLimit({ key: 'anthropic', ip, limit: 30, windowMs: 60_000 });
  if (!limit.ok) {
    res.setHeader('Retry-After', String(limit.retryAfter));
    return res.status(429).json({ error: 'Rate limit exceeded' });
  }

  const bodyBytes = Buffer.byteLength(JSON.stringify(req.body || {}));
  if (bodyBytes > MAX_BODY_BYTES) {
    return res.status(413).json({ error: 'Payload too large' });
  }

  // Validate model + clamp max_tokens before forwarding.
  const reqBody = req.body || {};
  const requestedModel = reqBody.model;
  if (requestedModel !== undefined && !ALLOWED_MODELS.includes(requestedModel)) {
    return res.status(400).json({ error: 'Unsupported model' });
  }
  const model = ALLOWED_MODELS.includes(requestedModel) ? requestedModel : DEFAULT_MODEL;
  const rawMaxTokens = Number(reqBody.max_tokens) || 1024;
  const maxTokens = Math.min(Math.max(1, rawMaxTokens), MAX_TOKENS_CEILING);

  try {
    const response = await fetch('https://api.anthropic.com/v1/messages', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'x-api-key': process.env.ANTHROPIC_API_KEY,
        'anthropic-version': '2023-06-01'
      },
      // Passthrough req.body, but force validated model + clamped max_tokens last.
      body: JSON.stringify({ ...reqBody, model, max_tokens: maxTokens })
    });

    const data = await response.json();
    return res.status(response.status).json(data);
  } catch (err) {
    console.error('[anthropic] error:', err.message);
    return res.status(500).json({ error: 'Upstream request failed' });
  }
};
