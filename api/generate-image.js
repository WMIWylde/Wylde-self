export const config = {
  runtime: 'edge',
};

// Edge runtime: inline allowlist (can't require() CommonJS modules from Edge).
const ALLOWED_ORIGINS = (process.env.ALLOWED_ORIGINS || 'https://wyldeself.com,https://www.wyldeself.com')
  .split(',').map(s => s.trim()).filter(Boolean);

function isAllowedOrigin(origin) {
  if (!origin) return false;
  if (ALLOWED_ORIGINS.includes(origin)) return true;
  return /^https?:\/\/(localhost|127\.0\.0\.1)(:\d+)?$/.test(origin);
}

function corsHeaders(origin, allowed) {
  const h = {};
  if (origin && allowed) {
    h['Access-Control-Allow-Origin'] = origin;
    h['Vary'] = 'Origin';
    h['Access-Control-Allow-Methods'] = 'POST, OPTIONS';
    h['Access-Control-Allow-Headers'] = 'Content-Type, Authorization';
  }
  return h;
}

// Edge per-instance per-IP limiter (mirrors lib/security.js shape)
const _buckets = new Map();
function rateLimit(ip, limit, windowMs) {
  const now = Date.now();
  const arr = (_buckets.get(ip) || []).filter(t => now - t < windowMs);
  if (arr.length >= limit) {
    const retryAfter = Math.ceil((windowMs - (now - arr[0])) / 1000);
    _buckets.set(ip, arr);
    return { ok: false, retryAfter };
  }
  arr.push(now);
  _buckets.set(ip, arr);
  return { ok: true };
}

function buildPrompt(timeline, goals, gender, hasImage) {
  const g = gender || 'male';

  // Normalize goals
  let goalList = [];
  if (Array.isArray(goals)) goalList = goals;
  else if (typeof goals === 'string' && goals) goalList = [goals];
  if (goalList.length === 0) goalList = ['Get lean & athletic'];
  const goalKey = goalList.map(s => s.toLowerCase()).join(' + ');

  // Detect emphasis — but EVERY transformation always includes muscle + fat loss
  const wantsBulk   = goalKey.match(/muscle|bulk|build|mass|size|strong/);
  const wantsCut    = goalKey.match(/burn|fat|los|weight|slim|lean|tone|defin|cut|shred/);
  const emphasis = wantsBulk && wantsCut ? 'body recomposition'
    : wantsBulk ? 'maximum muscle gain'
    : wantsCut  ? 'lean and shredded'
    : 'lean athletic muscle';

  // Short, punchy style note based on goals
  const styleNote = wantsBulk && !wantsCut
    ? 'Prioritize muscle SIZE — bigger arms, wider shoulders, thicker chest. Some body fat is fine.'
    : wantsCut && !wantsBulk
    ? 'Prioritize being SHREDDED — very low body fat, every muscle visible, veins showing.'
    : 'Balance muscle gain and fat loss — bigger AND leaner.';

  const identity = hasImage
    ? 'Transform this person\'s body. Keep their FACE, skin tone, hair, and tattoos identical. Same person — rebuilt body.'
    : `Generate a photorealistic image of a ${g} with a dramatically transformed athletic physique.`;

  const timelines = {
    '12weeks': `12-WEEK TRANSFORMATION. This person trained hard 4x/week for 3 months straight.
Show: noticeably more muscular shoulders, arms, and chest. Tighter waist, leaner face. Visible arm definition. Abs starting to show. V-taper forming. Clear muscle tone in every body part.
Think: Instagram before/after that makes people say "what program is that?" This is NOT subtle — the change is obvious at first glance.
${styleNote}`,

    '6months': `6-MONTH TRANSFORMATION. This person trained 5x/week for half a year with zero breaks.
Show: DRAMATIC muscle gain — thick arms with bicep peak, capped round shoulders, full squared chest, visible lats. Body fat 12-15%. Defined 4-6 pack abs. Veins on forearms and biceps. Sharp jawline. V-taper is dramatic.
Think: Men's Health cover. The kind of transformation people call "insane." The body looks COMPLETELY DIFFERENT.
${styleNote}`,

    '1year': `1-YEAR PEAK TRANSFORMATION. 365 days of disciplined training, strict nutrition, full dedication.
Show: ELITE natural physique. Thick vascular arms, striated cannonball shoulders, full chest with visible striations, wide lat spread, carved 6-pack with obliques, V-lines. Veins everywhere — forearms, biceps, delts. Every muscle group shows separation. Quads have visible heads. This body is COMPETITION READY.
Think: natural bodybuilder or fitness model at peak condition. Magazine cover physique. Unrecognizable from the original.
${styleNote}`,
  };

  const t = timelines[timeline] || timelines['12weeks'];

  return `${identity}

${t}

Goal: ${emphasis} — ${goalList.join(', ')}.

Rules: Photorealistic. No text/watermarks. EXAGGERATE the transformation — make it dramatic and motivating. Err on the side of MORE muscle, MORE definition, LESS body fat. Do NOT be conservative.`;
}

export default async function handler(req) {
  const origin = req.headers.get('origin') || '';
  const allowed = isAllowedOrigin(origin);
  const cors = corsHeaders(origin, allowed);

  if (req.method === 'OPTIONS') {
    return new Response(null, { status: allowed || !origin ? 204 : 403, headers: cors });
  }
  if (origin && !allowed) {
    return new Response(JSON.stringify({ error: 'Origin not allowed' }), {
      status: 403,
      headers: { ...cors, 'Content-Type': 'application/json' },
    });
  }
  if (req.method !== 'POST') {
    return new Response(JSON.stringify({ success: false, error: 'Method not allowed' }), {
      status: 405,
      headers: { ...cors, 'Content-Type': 'application/json' },
    });
  }

  // Rate limit: image gen is expensive — 5/min per IP
  const ip = (req.headers.get('x-forwarded-for') || '').split(',')[0].trim() || 'unknown';
  const rl = rateLimit(ip, 5, 60_000);
  if (!rl.ok) {
    return new Response(JSON.stringify({ success: false, error: 'Rate limit exceeded' }), {
      status: 429,
      headers: { ...cors, 'Content-Type': 'application/json', 'Retry-After': String(rl.retryAfter) },
    });
  }

  try {
    const apiKey = process.env.GEMINI_API_KEY;
    if (!apiKey) throw new Error('GEMINI_API_KEY not configured');

    const { image_base64, timeline, goal, userGoal, goals, gender } = await req.json();

    // goals array takes precedence, then userGoal, then legacy goal field
    const effectiveGoals = (Array.isArray(goals) && goals.length > 0)
      ? goals
      : (userGoal || goal || 'lean and athletic');
    const effectiveTimeline = timeline || '12weeks';

    const prompt = buildPrompt(effectiveTimeline, effectiveGoals, gender, !!image_base64);
    console.log(`[generate-image] Timeline: ${effectiveTimeline}, Goals: ${JSON.stringify(effectiveGoals)}, Prompt length: ${prompt.length}`);

    let contents;

    if (image_base64) {
      const base64Data = image_base64.replace(/^data:image\/\w+;base64,/, '');
      const mimeType = image_base64.match(/^data:(image\/\w+);base64,/)?.[1] || 'image/jpeg';
      contents = [
        {
          role: 'user',
          parts: [
            { inlineData: { mimeType, data: base64Data } },
            { text: prompt }
          ]
        }
      ];
    } else {
      contents = [
        {
          role: 'user',
          parts: [{ text: prompt }]
        }
      ];
    }

    // Try models in order — names change often, first success wins.
    // All entries must support the :generateContent endpoint with
    // responseModalities: ['TEXT', 'IMAGE']. Imagen models use a
    // different :predict shape and are intentionally excluded.
    const models = [
      'gemini-3.1-flash-image-preview', // Nano Banana 2 — high-efficiency native image gen (preview)
      'gemini-3-pro-image-preview',     // Nano Banana Pro — pro-tier native image gen (preview)
      'gemini-2.5-flash-image',         // Nano Banana — GA fallback
      'gemini-2.0-flash-exp',           // legacy fallback
    ];

    // Helper: attempt generation with given contents
    async function tryGenerate(reqContents) {
      const reqBody = JSON.stringify({
        contents: reqContents,
        generationConfig: {
          responseModalities: ['TEXT', 'IMAGE'],
        }
      });

      let response, data, usedModel;
      for (const model of models) {
        console.log(`[generate-image] Trying model: ${model}`);
        response = await fetch(
          `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=${apiKey}`,
          {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: reqBody
          }
        );
        data = await response.json();
        usedModel = model;
        if (response.ok || response.status !== 404) break;
        console.log(`[generate-image] Model ${model} returned ${response.status}, trying next...`);
      }

      console.log(`[generate-image] Final model: ${usedModel}, status: ${response.status}`);

      // Check for safety block (candidates blocked or finishReason SAFETY)
      const candidate = data?.candidates?.[0];
      const finishReason = candidate?.finishReason || '';
      const blocked = data?.promptFeedback?.blockReason || '';
      if (blocked || finishReason === 'SAFETY' || finishReason === 'RECITATION') {
        console.warn(`[generate-image] Safety blocked: ${blocked || finishReason}`);
        return { blocked: true, reason: blocked || finishReason };
      }

      if (!response.ok) {
        const errMsg = data?.error?.message || `Gemini error ${response.status}`;
        console.error(`[generate-image] API error:`, JSON.stringify(data?.error || data).substring(0, 500));
        return { error: errMsg };
      }

      const parts = candidate?.content?.parts || [];
      console.log(`[generate-image] Response parts: ${parts.length}, types: ${parts.map(p => p.text ? 'text' : p.inlineData ? 'image' : 'unknown').join(',')}`);
      const imagePart = parts.find(p => p.inlineData);

      if (!imagePart) {
        console.error('[generate-image] No image part found. Full response:', JSON.stringify(data).substring(0, 500));
        return { error: 'No image in response' };
      }

      return { success: true, imagePart };
    }

    // Attempt 1: with user's photo (if provided)
    let result = await tryGenerate(contents);

    // If safety-blocked and we had a photo, retry WITHOUT the photo
    if ((result.blocked || result.error) && image_base64) {
      console.log('[generate-image] Retrying WITHOUT user photo (safety fallback)...');
      const textOnlyContents = [
        {
          role: 'user',
          parts: [{ text: prompt }]
        }
      ];
      result = await tryGenerate(textOnlyContents);
      if (result.success) {
        console.log('[generate-image] Text-only fallback succeeded');
      }
    }

    if (result.blocked) {
      throw new Error('Image generation was blocked by safety filters. Try a different photo or generate without one.');
    }
    if (result.error) {
      throw new Error(result.error);
    }

    const { mimeType, data: imgData } = result.imagePart.inlineData;
    return new Response(
      JSON.stringify({ success: true, image_base64: `data:${mimeType};base64,${imgData}` }),
      { status: 200, headers: { ...cors, 'Content-Type': 'application/json' } }
    );

  } catch (err) {
    console.error('generate-image error:', err.message);
    return new Response(
      JSON.stringify({ success: false, error: err.message }),
      { status: 500, headers: { ...cors, 'Content-Type': 'application/json' } }
    );
  }
}
