// AI Health Check — /api/admin/ai-health
// Tests all AI providers and returns status

module.exports = async function handler(req, res) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  if (req.method === 'OPTIONS') return res.status(204).end();
  if (req.method !== 'GET') return res.status(405).json({ error: 'GET only' });

  // Require admin secret to prevent public config leakage
  const secret = req.headers['x-admin-secret'] || req.query.secret;
  if (!process.env.ADMIN_SECRET || secret !== process.env.ADMIN_SECRET) {
    return res.status(401).json({ error: 'Unauthorized' });
  }

  const results = {};
  const testPrompt = [{ role: 'user', content: 'Respond with exactly: OK' }];

  // OpenAI
  try {
    const start = Date.now();
    const resp = await fetch('https://api.openai.com/v1/chat/completions', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${process.env.OPENAI_API_KEY}` },
      body: JSON.stringify({ model: 'gpt-4o', max_tokens: 10, messages: testPrompt }),
    });
    const data = await resp.json();
    results.openai = {
      status: resp.ok ? 'healthy' : 'error',
      model: 'gpt-4o',
      latency_ms: Date.now() - start,
      response: data.choices?.[0]?.message?.content?.substring(0, 50) || null,
      error: resp.ok ? null : data.error?.message,
    };
  } catch (e) { results.openai = { status: 'down', error: e.message, latency_ms: null }; }

  // Anthropic
  try {
    const start = Date.now();
    const resp = await fetch('https://api.anthropic.com/v1/messages', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', 'x-api-key': process.env.ANTHROPIC_API_KEY, 'anthropic-version': '2023-06-01' },
      body: JSON.stringify({ model: 'claude-haiku-4-5-20251001', max_tokens: 10, messages: testPrompt }),
    });
    const data = await resp.json();
    results.anthropic = {
      status: resp.ok ? 'healthy' : 'error',
      model: 'claude-haiku-4-5-20251001',
      latency_ms: Date.now() - start,
      response: data.content?.[0]?.text?.substring(0, 50) || null,
      error: resp.ok ? null : data.error?.message,
    };
  } catch (e) { results.anthropic = { status: 'down', error: e.message, latency_ms: null }; }

  // Gemini
  try {
    const start = Date.now();
    const model = 'gemini-3.1-flash-image-preview';
    const resp = await fetch(
      `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=${process.env.GEMINI_API_KEY}`,
      {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ contents: [{ role: 'user', parts: [{ text: 'Respond with exactly: OK' }] }] }),
      }
    );
    const data = await resp.json();
    results.gemini = {
      status: resp.ok ? 'healthy' : (resp.status === 404 ? 'model_unavailable' : 'error'),
      model,
      latency_ms: Date.now() - start,
      response: data.candidates?.[0]?.content?.parts?.[0]?.text?.substring(0, 50) || null,
      error: resp.ok ? null : data.error?.message,
    };
  } catch (e) { results.gemini = { status: 'down', error: e.message, latency_ms: null }; }

  // Supabase
  try {
    const start = Date.now();
    const resp = await fetch(`${process.env.SUPABASE_URL}/rest/v1/therapies?select=count&limit=0`, {
      headers: { 'apikey': process.env.SUPABASE_ANON_KEY || process.env.SUPABASE_SERVICE_KEY },
    });
    results.supabase = {
      status: resp.ok ? 'healthy' : 'error',
      latency_ms: Date.now() - start,
      error: resp.ok ? null : `HTTP ${resp.status}`,
    };
  } catch (e) { results.supabase = { status: 'down', error: e.message, latency_ms: null }; }

  // Stripe
  try {
    results.stripe = {
      status: process.env.STRIPE_SECRET_KEY ? 'configured' : 'missing',
      mode: process.env.STRIPE_SECRET_KEY?.startsWith('sk_live') ? 'live' : 'test',
    };
  } catch (e) { results.stripe = { status: 'error', error: e.message }; }

  // Summary
  const allHealthy = Object.values(results).every(r => r.status === 'healthy' || r.status === 'configured');
  const timestamp = new Date().toISOString();

  return res.status(200).json({
    overall: allHealthy ? 'healthy' : 'degraded',
    timestamp,
    environment: process.env.NODE_ENV || 'production',
    providers: results,
    env_vars: {
      OPENAI_API_KEY: !!process.env.OPENAI_API_KEY,
      ANTHROPIC_API_KEY: !!process.env.ANTHROPIC_API_KEY,
      GEMINI_API_KEY: !!process.env.GEMINI_API_KEY,
      STRIPE_SECRET_KEY: !!process.env.STRIPE_SECRET_KEY,
      SUPABASE_URL: !!process.env.SUPABASE_URL,
      SUPABASE_SERVICE_KEY: !!(process.env.SUPABASE_SERVICE_KEY || process.env.SUPABASE_SERVICE_ROLE_KEY),
    },
  });
};
