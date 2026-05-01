// Shared security helpers for /api functions.
//
// - applyCors():       allowlist-based CORS (locks down what was previously '*').
//                       Native iOS URLSession doesn't send Origin and is unaffected.
// - rateLimit():       per-instance, per-IP sliding-window limiter. Leaky across
//                       cold starts but blunts scripted abuse on a warm instance.

const DEFAULT_ALLOWED_ORIGINS = [
  'https://wyldeself.com',
  'https://www.wyldeself.com',
];

function getAllowedOrigins() {
  const fromEnv = (process.env.ALLOWED_ORIGINS || '')
    .split(',')
    .map(s => s.trim())
    .filter(Boolean);
  return fromEnv.length ? fromEnv : DEFAULT_ALLOWED_ORIGINS;
}

function isAllowedOrigin(origin) {
  if (!origin) return false;
  if (getAllowedOrigins().includes(origin)) return true;
  // Allow localhost on any port for dev
  if (/^https?:\/\/(localhost|127\.0\.0\.1)(:\d+)?$/.test(origin)) return true;
  return false;
}

/**
 * Apply CORS to a Node-style (req, res) handler.
 *   - Echoes the Origin back only if allowed
 *   - Short-circuits OPTIONS preflight with 204
 *
 * Returns true if the caller should stop (preflight handled or origin rejected
 * on a cross-origin request). Returns false to continue.
 *
 * Same-origin requests (no Origin header) and non-browser callers (native iOS,
 * server-to-server, curl) pass through — CORS only protects browsers.
 */
function applyCors(req, res, { methods = 'POST, OPTIONS' } = {}) {
  const origin = req.headers.origin || '';
  const allowed = isAllowedOrigin(origin);

  if (origin && allowed) {
    res.setHeader('Access-Control-Allow-Origin', origin);
    res.setHeader('Vary', 'Origin');
    res.setHeader('Access-Control-Allow-Methods', methods);
    res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization');
  }

  if (req.method === 'OPTIONS') {
    res.status(allowed || !origin ? 204 : 403).end();
    return true;
  }

  if (origin && !allowed) {
    res.status(403).json({ error: 'Origin not allowed' });
    return true;
  }

  return false;
}

/** Edge-runtime variant: returns { headers, preflightResponse } */
function corsHeadersEdge(req, { methods = 'POST, OPTIONS' } = {}) {
  const origin = req.headers.get('origin') || '';
  const allowed = isAllowedOrigin(origin);
  const headers = {};
  if (origin && allowed) {
    headers['Access-Control-Allow-Origin'] = origin;
    headers['Vary'] = 'Origin';
    headers['Access-Control-Allow-Methods'] = methods;
    headers['Access-Control-Allow-Headers'] = 'Content-Type, Authorization';
  }
  let preflightResponse = null;
  if (req.method === 'OPTIONS') {
    preflightResponse = new Response(null, { status: allowed || !origin ? 204 : 403, headers });
  } else if (origin && !allowed) {
    preflightResponse = new Response(JSON.stringify({ error: 'Origin not allowed' }), {
      status: 403,
      headers: { ...headers, 'Content-Type': 'application/json' },
    });
  }
  return { headers, preflightResponse, originAllowed: allowed || !origin };
}

// ── Rate limiting ──────────────────────────────────────────────────
// Per-instance Map. Vercel keeps warm instances for a while, so this
// dampens scripted abuse without external state. Distributed limiting
// would require Upstash / Vercel KV.

const _buckets = new Map();
const _BUCKET_CAP = 5000; // prevent unbounded growth on a long-lived instance

function clientIp(req) {
  const xff = req.headers['x-forwarded-for'] || req.headers.get?.('x-forwarded-for');
  if (xff) return String(xff).split(',')[0].trim();
  return req.socket?.remoteAddress || req.headers['x-real-ip'] || 'unknown';
}

/**
 * Sliding-window rate limit. Returns { ok, retryAfter } where retryAfter is
 * seconds until the oldest hit ages out.
 *   key:        logical bucket name (e.g. 'anthropic')
 *   ip:         client IP (use clientIp(req))
 *   limit:      max requests per window
 *   windowMs:   window length in ms
 */
function rateLimit({ key, ip, limit, windowMs }) {
  const now = Date.now();
  const bucketKey = `${key}:${ip}`;
  const arr = _buckets.get(bucketKey) || [];
  const fresh = arr.filter(t => now - t < windowMs);
  if (fresh.length >= limit) {
    const retryAfter = Math.ceil((windowMs - (now - fresh[0])) / 1000);
    _buckets.set(bucketKey, fresh);
    return { ok: false, retryAfter };
  }
  fresh.push(now);
  _buckets.set(bucketKey, fresh);

  // Light GC to bound memory
  if (_buckets.size > _BUCKET_CAP) {
    for (const [k, v] of _buckets) {
      if (!v.length || now - v[v.length - 1] > windowMs) _buckets.delete(k);
      if (_buckets.size <= _BUCKET_CAP * 0.8) break;
    }
  }

  return { ok: true };
}

module.exports = { applyCors, corsHeadersEdge, rateLimit, clientIp, isAllowedOrigin };
