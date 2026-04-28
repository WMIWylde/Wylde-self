// /api/identity-analyze
// ────────────────────────────────────────────────────────────────────
//   Identity Import — Founding Members feature.
//
//   Takes user-provided URLs + raw text, fetches public content,
//   and asks Claude to extract a structured identity profile that
//   the Coach + every other AI surface uses to personalize tone.
//
//   Privacy contract:
//     • Only public/user-provided data is processed.
//     • No social platform auth, no scraping, no posting.
//     • User can re-run or delete via the same endpoint.
// ────────────────────────────────────────────────────────────────────

const ANTHROPIC_KEY = process.env.ANTHROPIC_API_KEY || '';
const SUPABASE_URL = process.env.SUPABASE_URL || 'https://huclolzxzpitdpyogolu.supabase.co';
const SUPABASE_SERVICE_KEY = process.env.SUPABASE_SERVICE_KEY || '';
const MODEL = 'claude-haiku-4-5-20251001';

const MAX_URLS = 5;
const MAX_TEXT_LEN = 12000;       // chars of pasted content per request
const URL_FETCH_TIMEOUT_MS = 7000;
const MAX_FETCHED_LEN_PER_URL = 6000; // truncate fetched page text to keep context small

module.exports = async function handler(req, res) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization');
  if (req.method === 'OPTIONS') return res.status(200).end();
  if (req.method !== 'POST') return res.status(405).json({ error: 'Method not allowed' });

  if (!ANTHROPIC_KEY) {
    return res.status(500).json({ error: 'Server misconfigured (no ANTHROPIC_API_KEY)' });
  }

  // ─── Parse inputs ────────────────────────────────────────────────
  const body = req.body || {};
  const userId = String(body.user_id || '').trim();
  const urls = Array.isArray(body.urls) ? body.urls.slice(0, MAX_URLS).map(String) : [];
  const rawText = String(body.raw_text || '').slice(0, MAX_TEXT_LEN);

  if (!userId) return res.status(400).json({ error: 'user_id required' });
  if (urls.length === 0 && !rawText.trim()) {
    return res.status(400).json({ error: 'Provide at least one URL or paste content.' });
  }

  // ─── Server-side fetch URLs (public content only) ────────────────
  const fetched = [];
  for (const u of urls) {
    if (!isValidPublicUrl(u)) continue;
    try {
      const text = await fetchPublicTextContent(u);
      if (text && text.length > 50) {
        fetched.push({ url: u, text: text.slice(0, MAX_FETCHED_LEN_PER_URL) });
      }
    } catch (e) {
      console.warn('[identity-analyze] fetch failed', u, e.message);
    }
  }

  // ─── Build the analysis input ────────────────────────────────────
  let analysisInput = '';
  if (rawText.trim()) {
    analysisInput += '── PASTED CONTENT ──\n' + rawText.trim() + '\n\n';
  }
  fetched.forEach(f => {
    analysisInput += '── PUBLIC PROFILE: ' + f.url + ' ──\n' + f.text + '\n\n';
  });

  if (!analysisInput.trim()) {
    return res.status(400).json({
      error: 'Couldn\u2019t extract any usable text from the provided sources. Try pasting raw content instead.'
    });
  }

  // ─── Send to Claude ──────────────────────────────────────────────
  const systemPrompt =
    'You are an identity intelligence engine. You analyze a person\u2019s communication style, ' +
    'identity patterns, emotional tone, values, self-image, and behavioral tendencies from their ' +
    'public-facing content. Your output is used to personalize how a coaching app speaks to them.\n\n' +
    'You must return ONLY a single valid JSON object matching this schema:\n' +
    '{\n' +
    '  "identity_archetype": string,            // e.g. "the disciplined builder", "the seeker in motion"\n' +
    '  "confidence_level": "low" | "medium" | "high",  // confidence in this analysis\n' +
    '  "communication_tone": string,            // 1\u20132 sentences describing how they write/speak\n' +
    '  "motivation_triggers": string[],         // 3\u20135 things that fire them up\n' +
    '  "limiting_patterns": string[],           // 2\u20134 patterns that hold them back\n' +
    '  "aspirational_identity": string,         // who they\u2019re reaching toward becoming\n' +
    '  "coaching_style": "direct" | "intense" | "supportive" | "spiritual" | "tactical" | "mixed",\n' +
    '  "language_to_use": string[],             // 4\u20136 words/phrases that resonate with them\n' +
    '  "language_to_avoid": string[],           // 3\u20135 words/phrases that would feel off\n' +
    '  "emotional_drivers": string[],           // 2\u20134 core emotions that move them\n' +
    '  "discipline_level": "emerging" | "building" | "strong" | "elite"\n' +
    '}\n\n' +
    'Rules:\n' +
    '\u2022 Be specific. \"motivated by growth\" is useless; \"motivated by proving wrong people who doubted them\" is real.\n' +
    '\u2022 Pull language and tone DIRECTLY from how they actually write \u2014 mirror their cadence.\n' +
    '\u2022 If content is sparse or ambiguous, set confidence_level: \"low\" and stay generous in interpretation.\n' +
    '\u2022 Never invent details that aren\u2019t supported by the source content.\n' +
    '\u2022 Output ONLY the raw JSON object. Do NOT wrap it in ```json``` fences. Start your response with { and end with }. Nothing else.';

  const userMessage =
    'Analyze the following content and return the structured identity profile JSON.\n\n' + analysisInput;

  let analysis;
  try {
    const claudeRes = await fetch('https://api.anthropic.com/v1/messages', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'x-api-key': ANTHROPIC_KEY,
        'anthropic-version': '2023-06-01'
      },
      body: JSON.stringify({
        model: MODEL,
        max_tokens: 1200,
        system: systemPrompt,
        messages: [{ role: 'user', content: userMessage }]
      })
    });
    if (!claudeRes.ok) {
      const errText = await claudeRes.text();
      console.error('[identity-analyze] Claude error', claudeRes.status, errText);
      return res.status(502).json({ error: 'AI analysis failed' });
    }
    const claudeJson = await claudeRes.json();
    const reply = claudeJson?.content?.[0]?.text || '';
    analysis = parseStructuredResponse(reply);
    if (!analysis || typeof analysis !== 'object') {
      console.error('[identity-analyze] Unparseable response:', reply);
      return res.status(502).json({ error: 'Couldn\u2019t parse AI response' });
    }
  } catch (e) {
    console.error('[identity-analyze] Exception', e);
    return res.status(500).json({ error: e.message });
  }

  // ─── Validate + normalize the structured output ──────────────────
  const profile = normalizeProfile(analysis);

  // ─── Persist to Supabase (upsert by user_id) ─────────────────────
  if (SUPABASE_SERVICE_KEY) {
    try {
      const upsertPayload = {
        user_id: userId,
        identity_archetype: profile.identity_archetype,
        confidence_level: profile.confidence_level,
        communication_tone: profile.communication_tone,
        motivation_triggers: profile.motivation_triggers,
        limiting_patterns: profile.limiting_patterns,
        aspirational_identity: profile.aspirational_identity,
        coaching_style: profile.coaching_style,
        language_to_use: profile.language_to_use,
        language_to_avoid: profile.language_to_avoid,
        emotional_drivers: profile.emotional_drivers,
        discipline_level: profile.discipline_level,
        raw_sources: [
          ...urls.map(u => ({ type: 'url', value: u, fetched_at: new Date().toISOString() })),
          ...(rawText ? [{ type: 'text', value: rawText.slice(0, 500) + (rawText.length > 500 ? '\u2026' : ''), fetched_at: new Date().toISOString() }] : [])
        ],
        source_count: urls.length + (rawText.trim() ? 1 : 0),
        analysis_model: MODEL,
        analysis_version: 1,
        updated_at: new Date().toISOString()
      };
      const upsertRes = await fetch(SUPABASE_URL + '/rest/v1/user_identity_profile?on_conflict=user_id', {
        method: 'POST',
        headers: {
          apikey: SUPABASE_SERVICE_KEY,
          Authorization: 'Bearer ' + SUPABASE_SERVICE_KEY,
          'Content-Type': 'application/json',
          Prefer: 'resolution=merge-duplicates,return=minimal'
        },
        body: JSON.stringify(upsertPayload)
      });
      if (!upsertRes.ok) {
        const errText = await upsertRes.text();
        console.warn('[identity-analyze] Supabase upsert failed', upsertRes.status, errText);
      }
    } catch (e) {
      console.warn('[identity-analyze] Supabase write exception', e.message);
    }
  }

  return res.status(200).json({ ok: true, profile });
};

// ─── Helpers ───────────────────────────────────────────────────────

function isValidPublicUrl(u) {
  try {
    const parsed = new URL(u);
    if (!['http:', 'https:'].includes(parsed.protocol)) return false;
    // Block localhost / private IPs / cloud metadata to prevent SSRF
    const host = parsed.hostname.toLowerCase();
    if (host === 'localhost' || host === '127.0.0.1' || host === '0.0.0.0') return false;
    if (host.endsWith('.local') || host.endsWith('.internal')) return false;
    // IPv4 private ranges
    if (/^10\./.test(host)) return false;
    if (/^192\.168\./.test(host)) return false;
    if (/^172\.(1[6-9]|2\d|3[01])\./.test(host)) return false;
    // AWS / GCP / Azure metadata endpoints
    if (host === '169.254.169.254' || /^169\.254\./.test(host)) return false;
    if (host === 'metadata.google.internal') return false;
    // IPv6 loopback / link-local
    if (host === '::1' || host === '[::1]' || host === '[::]') return false;
    if (/^\[?fe80:/i.test(host) || /^\[?fc00:/i.test(host) || /^\[?fd00:/i.test(host)) return false;
    return true;
  } catch (e) { return false; }
}

async function fetchPublicTextContent(url) {
  const controller = new AbortController();
  const t = setTimeout(() => controller.abort(), URL_FETCH_TIMEOUT_MS);
  try {
    const r = await fetch(url, {
      redirect: 'follow',
      signal: controller.signal,
      headers: {
        // Public bot UA, identifies itself honestly
        'User-Agent': 'WyldeSelf-IdentityImporter/1.0 (+https://wyldeself.com)',
        'Accept': 'text/html,application/xhtml+xml,*/*;q=0.8'
      }
    });
    clearTimeout(t);
    if (!r.ok) return '';
    const ct = r.headers.get('content-type') || '';
    if (!ct.includes('text/html') && !ct.includes('text/plain') && !ct.includes('application/json')) return '';
    const html = await r.text();
    return extractReadableText(html);
  } finally {
    clearTimeout(t);
  }
}

/**
 * Extract readable text from HTML — intentionally simple. Pulls visible body
 * text, meta description, og:description, og:title. Not trying to be a full
 * readability parser; just enough signal for the AI to pick up on style.
 */
function extractReadableText(html) {
  if (!html || typeof html !== 'string') return '';

  // Pull og + meta description (common on profile pages)
  const meta = [];
  const ogTitleMatch = /<meta[^>]+property=["']og:title["'][^>]+content=["']([^"']+)["']/i.exec(html);
  if (ogTitleMatch) meta.push('Title: ' + ogTitleMatch[1]);
  const ogDescMatch = /<meta[^>]+property=["']og:description["'][^>]+content=["']([^"']+)["']/i.exec(html);
  if (ogDescMatch) meta.push('Description: ' + ogDescMatch[1]);
  const descMatch = /<meta[^>]+name=["']description["'][^>]+content=["']([^"']+)["']/i.exec(html);
  if (descMatch && !ogDescMatch) meta.push('Description: ' + descMatch[1]);

  // Strip script/style/nav/footer/header blocks
  let body = html
    .replace(/<script[\s\S]*?<\/script>/gi, ' ')
    .replace(/<style[\s\S]*?<\/style>/gi, ' ')
    .replace(/<nav[\s\S]*?<\/nav>/gi, ' ')
    .replace(/<footer[\s\S]*?<\/footer>/gi, ' ')
    .replace(/<header[\s\S]*?<\/header>/gi, ' ')
    .replace(/<noscript[\s\S]*?<\/noscript>/gi, ' ');

  // Strip remaining tags, decode common entities
  body = body
    .replace(/<[^>]+>/g, ' ')
    .replace(/&nbsp;/g, ' ')
    .replace(/&amp;/g, '&')
    .replace(/&lt;/g, '<')
    .replace(/&gt;/g, '>')
    .replace(/&quot;/g, '"')
    .replace(/&#39;/g, "'")
    .replace(/\s+/g, ' ')
    .trim();

  return [meta.join('\n'), body].filter(Boolean).join('\n\n');
}

/**
 * Parse Claude's response — usually clean JSON, but handle markdown fence
 * wrappers + leading explanation text defensively.
 */
function parseStructuredResponse(text) {
  if (!text) return null;
  // Strip markdown code fences if present
  let t = text.trim();
  if (t.startsWith('```')) {
    t = t.replace(/^```(?:json)?\s*/i, '').replace(/```\s*$/i, '').trim();
  }
  // Find first { and last } if there's extra text
  const start = t.indexOf('{');
  const end = t.lastIndexOf('}');
  if (start === -1 || end === -1) return null;
  const jsonStr = t.slice(start, end + 1);
  try { return JSON.parse(jsonStr); } catch (e) { return null; }
}

/**
 * Normalize the AI output — coerce arrays, clamp enums, default missing fields.
 */
function normalizeProfile(p) {
  const enums = {
    confidence_level: ['low', 'medium', 'high'],
    coaching_style: ['direct', 'intense', 'supportive', 'spiritual', 'tactical', 'mixed'],
    discipline_level: ['emerging', 'building', 'strong', 'elite']
  };
  const arr = (v) => Array.isArray(v) ? v.filter(x => typeof x === 'string' && x.trim()) : [];
  const str = (v, def) => (typeof v === 'string' && v.trim()) ? v.trim() : def;
  const enumOf = (v, choices, def) => choices.includes(v) ? v : def;
  return {
    identity_archetype:    str(p.identity_archetype, 'someone in motion'),
    confidence_level:      enumOf(p.confidence_level, enums.confidence_level, 'low'),
    communication_tone:    str(p.communication_tone, 'unclear from the content provided'),
    motivation_triggers:   arr(p.motivation_triggers).slice(0, 5),
    limiting_patterns:     arr(p.limiting_patterns).slice(0, 4),
    aspirational_identity: str(p.aspirational_identity, ''),
    coaching_style:        enumOf(p.coaching_style, enums.coaching_style, 'mixed'),
    language_to_use:       arr(p.language_to_use).slice(0, 6),
    language_to_avoid:     arr(p.language_to_avoid).slice(0, 5),
    emotional_drivers:     arr(p.emotional_drivers).slice(0, 4),
    discipline_level:      enumOf(p.discipline_level, enums.discipline_level, 'building')
  };
}
