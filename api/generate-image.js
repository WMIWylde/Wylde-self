// Runs on Vercel's default Node.js (Fluid Compute) runtime so we get the
// 300s execution budget. Was previously Edge for the old Hobby 10s cap —
// that's gone, and Edge's 25s initial-response cap was killing the function
// before Gemini's first model could respond. maxDuration is set in vercel.json.

// Inline allowlist (kept inline from the prior Edge config).
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

function normalizeGoals(goals, userGoal, goal) {
  let goalList = [];
  if (Array.isArray(goals)) goalList = goals.filter(Boolean);
  else if (typeof goals === 'string' && goals) goalList = [goals];
  if (goalList.length === 0 && userGoal) goalList = [userGoal];
  if (goalList.length === 0 && goal) goalList = [goal];
  if (goalList.length === 0) goalList = ['Get lean & athletic'];
  return goalList;
}

/** Physique transformation prompt — gender-aware, goal-aware. */
function buildPhysiquePrompt(timeline, goalList, gender, hasImage) {
  const g = gender || 'male';
  const isFemale = g.toLowerCase() === 'female';
  const goalKey = goalList.map(s => s.toLowerCase()).join(' + ');

  // Detect goal categories
  const wantsBulk       = goalKey.match(/muscle|bulk|build|mass|size|strong/);
  const wantsCut        = goalKey.match(/burn|fat|los|weight|slim|lean|tone|defin|cut|shred/);
  const wantsEndurance  = goalKey.match(/endurance|cardio|stamina|run|marathon/);
  const wantsFlexibility = goalKey.match(/flex|mobil|yoga|stretch/);

  // Build emphasis that reflects all goals
  let emphasis;
  if (wantsBulk && wantsCut) emphasis = 'body recomposition — lean muscle with visible definition';
  else if (wantsBulk) emphasis = 'athletic muscle gain';
  else if (wantsCut) emphasis = 'lean and toned';
  else if (wantsEndurance) emphasis = 'athletic endurance physique';
  else if (wantsFlexibility) emphasis = 'flexible, toned, and balanced';
  else emphasis = 'lean athletic physique';

  // Goal-aware style note — different for male and female
  let styleNote;
  if (isFemale) {
    if (wantsBulk && !wantsCut)
      styleNote = 'Show athletic muscle — defined shoulders, sculpted arms, strong glutes and legs. Fit and powerful, not bulky.';
    else if (wantsCut && !wantsBulk)
      styleNote = 'Show a lean toned physique — visible muscle definition, flat stomach, sculpted arms and legs. Think fitness model.';
    else if (wantsEndurance)
      styleNote = 'Show a lean runner/athlete build — long toned muscles, low body fat, effortless athleticism. Think Olympic athlete.';
    else if (wantsFlexibility)
      styleNote = 'Show a lithe, toned body — lean muscle, graceful posture, dancer/yogi build. Balanced and strong.';
    else
      styleNote = 'Show a strong, toned, confident physique — visible definition in arms, shoulders, core, and legs. Healthy and athletic.';
  } else {
    if (wantsBulk && !wantsCut)
      styleNote = 'Prioritize muscle SIZE — bigger arms, wider shoulders, thicker chest. Some body fat is fine.';
    else if (wantsCut && !wantsBulk)
      styleNote = 'Prioritize being SHREDDED — very low body fat, every muscle visible, veins showing.';
    else if (wantsEndurance)
      styleNote = 'Show an endurance athlete build — lean, wiry muscle, low body fat, strong legs and core. Think triathlete or distance runner.';
    else if (wantsFlexibility)
      styleNote = 'Show a balanced, flexible physique — lean muscle, excellent posture, functional strength. Think martial artist or gymnast.';
    else
      styleNote = 'Balance muscle gain and fat loss — bigger AND leaner.';
  }

  const identity = hasImage
    ? 'Transform this person\'s body. Keep their FACE, skin tone, hair, and tattoos identical. Same person — rebuilt body.'
    : `Generate a photorealistic image of a ${g} with a dramatically transformed athletic physique.`;

  // Gender-aware timeline descriptions
  const maleTimelines = {
    '12weeks': `12-WEEK TRANSFORMATION. This person trained hard 4x/week for 3 months straight.
Show: noticeably more muscular shoulders, arms, and chest. Tighter waist, leaner face. Visible arm definition. Abs starting to show. V-taper forming. Clear muscle tone in every body part.
Think: Instagram before/after that makes people say "what program is that?" This is NOT subtle — the change is obvious at first glance.
${styleNote}`,

    '6months': `6-MONTH TRANSFORMATION. This person trained 5x/week for half a year with zero breaks.
Show: DRAMATIC muscle gain — thick arms with bicep peak, capped round shoulders, full squared chest, visible lats. Body fat 12-15%. Defined 4-6 pack abs. Veins on forearms and biceps. Sharp jawline. V-taper is dramatic.
Think: Men's Health cover. The kind of transformation people call "insane." The body looks COMPLETELY DIFFERENT.
${styleNote}`,

    '1year': `1-YEAR PEAK TRANSFORMATION. 365 days of disciplined training, strict nutrition, full dedication.
Show: ELITE natural physique. Thick vascular arms, striated cannonball shoulders, full chest with visible striations, wide lat spread, carved 6-pack with obliques, V-lines. Veins everywhere — forearms, biceps, delts. Every muscle group shows separation. This body is COMPETITION READY.
Think: natural bodybuilder or fitness model at peak condition. Magazine cover physique. Unrecognizable from the original.
${styleNote}`,
  };

  const femaleTimelines = {
    '12weeks': `12-WEEK TRANSFORMATION. This person trained hard 4x/week for 3 months straight.
Show: noticeably more toned shoulders and arms. Tighter waist, more defined legs and glutes. Visible muscle definition starting to emerge. Posture is confident and strong. Skin looks healthier, face is leaner.
Think: that friend who started working out 3 months ago and you can clearly tell. The change is real and visible.
${styleNote}`,

    '6months': `6-MONTH TRANSFORMATION. This person trained 5x/week for half a year with zero breaks.
Show: DRAMATIC body transformation — sculpted arms and shoulders, defined abs, strong toned legs, lifted round glutes. Waist is tight, body fat is low. Every outfit fits differently. Posture radiates strength.
Think: Women's Health cover. The kind of transformation that inspires everyone around her.
${styleNote}`,

    '1year': `1-YEAR PEAK TRANSFORMATION. 365 days of disciplined training, strict nutrition, full dedication.
Show: PEAK athletic physique. Sculpted shoulders with visible caps, defined arms, visible abs with oblique lines, strong back, powerful legs with quad definition, round lifted glutes. Every muscle group shows tone and separation. This body moves with power and grace.
Think: elite fitness athlete or bikini competitor at peak condition. Magazine cover physique. Unrecognizable from the original.
${styleNote}`,
  };

  const timelines = isFemale ? femaleTimelines : maleTimelines;
  const t = timelines[timeline] || timelines['12weeks'];

  return `${identity}

${t}

Goal: ${emphasis} — ${goalList.join(', ')}.

CRITICAL: Generate ONE SINGLE full-body photograph. Do NOT create a collage, mood board, vision board, grid, split image, or multiple images. One continuous photorealistic image of one person standing or posing. No text, no labels, no watermarks, no borders, no frames.

Make the transformation dramatic and motivating. This should inspire the person to keep going.`;
}

/**
 * Vision board: one editorial collage — health, vitality, intentional wealth/ease,
 * mindset, and life in motion — not physique-only.
 */
function buildVisionBoardPrompt(timeline, goalList, gender, hasImage, ctx) {
  const g = (gender || 'male').toLowerCase();
  const futureVisionText = (ctx && ctx.futureVisionText) ? String(ctx.futureVisionText).trim().slice(0, 400) : '';
  const obstacle = (ctx && ctx.obstacle) ? String(ctx.obstacle).trim().slice(0, 200) : '';
  const motivations = Array.isArray(ctx && ctx.motivations) ? ctx.motivations.filter(Boolean).slice(0, 8) : [];

  const identity = hasImage
    ? 'The person in the reference photo MUST appear as the recognizable hero in the largest panel (same face, skin tone, hair, age). Do not replace them with a model.'
    : `Feature one recognizable photorealistic ${g === 'female' ? 'woman' : g === 'non-binary' ? 'person' : 'man'} as the hero across the board.`;

  const horizons = {
    '12weeks': `12-WEEK HORIZON — early momentum: disciplined routines forming, visible vitality returning, life feeling more intentional. Energy is rising; results are starting to show.`,
    '6months': `6-MONTH HORIZON — clear transformation: strong body, calmer mind, lifestyle upgrades that feel earned. Confidence is obvious.`,
    '1year': `1-YEAR HORIZON — embodied future self: peak health, financial ease, composed presence, a life that matches who they decided to become.`,
  };
  const horizon = horizons[timeline] || horizons['12weeks'];

  const wealthNote = goalList.some(g => /confidence|health|energy|lifestyle/i.test(g))
    ? 'Wealth shown as ease and quality of life — not excess.'
    : 'Wealth shown as intentional abundance: calm premium spaces, purposeful work, freedom of time — never gaudy.';

  const lines = [
    'Create ONE single high-end editorial VISION BOARD image — a cohesive photorealistic collage (soft grid or cinematic mosaic).',
    'This is NOT a before/after body shot alone. It is a life visualization: healthy, wealthy-in-spirit, composed, capable.',
    '',
    identity,
    '',
    horizon,
    '',
    'In ONE image, include 5–6 vignettes that read as one aspirational life:',
    '1. BODY & VITALITY — athletic health, energy, strength (same person if reference provided)',
    '2. WEALTH & EASE — ' + wealthNote + ' NO cash piles, lottery, lamborghinis, or cliché "rich" tropes.',
    '3. MIND & RITUAL — morning light, focus, stillness, journaling or meditation atmosphere',
    '4. PURPOSE & WORK — meaningful craft, creation, or leadership energy (subtle, not corporate stock)',
    '5. LIFE IN MOTION — training, nature, travel, or movement aligned with their goals',
    '6. CONNECTION (optional) — warmth, partnership, or community suggested tastefully — no cheesy romance stock',
    '',
    'Training goals: ' + goalList.join(', ') + '.',
  ];

  if (motivations.length) lines.push('Core motivations: ' + motivations.join(', ') + '.');
  if (futureVisionText) lines.push('In their words: "' + futureVisionText + '" — reflect this visually.');
  if (obstacle) lines.push('They named friction: "' + obstacle + '" — the board should imply they overcome it through consistency, not fantasy shortcuts.');

  lines.push(
    '',
    'Aesthetic: Equinox / Whoop / Aesop — warm neutrals, sage green and soft gold accents, cinematic natural light, magazine-quality. Premium, grounded, believable.',
    '',
    'Rules: Photorealistic photography only. CRITICAL — absolutely no text, typography, letters, numbers, words, captions, labels, logos, or watermarks anywhere in the image. NO cartoon or illustration. Single output image. Avoid cluttered Pinterest scrapbook chaos — elegant editorial layout.',
  );

  return lines.join('\n');
}

/**
 * Route to the right prompt builder based on mode.
 * Default is 'physique' — the Future Self transformation photo.
 * Pass mode='vision_board' explicitly for the life collage.
 */
function buildPrompt(timeline, goals, gender, hasImage, options) {
  const mode = (options && options.mode) || 'physique';
  const goalList = normalizeGoals(goals, options && options.userGoal, options && options.goal);
  if (mode === 'vision_board') {
    return buildVisionBoardPrompt(timeline, goalList, gender, hasImage, options);
  }
  return buildPhysiquePrompt(timeline, goalList, gender, hasImage);
}

module.exports = async function handler(req, res) {
  const origin = req.headers['origin'] || '';
  const allowed = isAllowedOrigin(origin);
  const cors = corsHeaders(origin, allowed);
  for (const [k, v] of Object.entries(cors)) res.setHeader(k, v);

  if (req.method === 'OPTIONS') {
    return res.status(allowed || !origin ? 204 : 403).end();
  }
  if (origin && !allowed) {
    return res.status(403).json({ error: 'Origin not allowed' });
  }
  if (req.method !== 'POST') {
    return res.status(405).json({ success: false, error: 'Method not allowed' });
  }

  const ip = (req.headers['x-forwarded-for'] || '').split(',')[0].trim() || 'unknown';
  const rl = rateLimit(ip, 5, 60_000);
  if (!rl.ok) {
    res.setHeader('Retry-After', String(rl.retryAfter));
    return res.status(429).json({ success: false, error: 'Rate limit exceeded' });
  }

  try {
    const apiKey = process.env.GEMINI_API_KEY;
    if (!apiKey) throw new Error('GEMINI_API_KEY not configured');

    const body = req.body || {};
    const {
      image_base64,
      timeline,
      goal,
      userGoal,
      goals,
      gender,
      mode,
      futureVisionText,
      motivations,
      obstacle,
    } = body;

    const effectiveGoals = normalizeGoals(goals, userGoal, goal);
    const effectiveTimeline = timeline || '12weeks';

    const prompt = buildPrompt(effectiveTimeline, effectiveGoals, gender, !!image_base64, {
      mode: mode || 'physique',
      userGoal,
      goal,
      futureVisionText,
      motivations,
      obstacle,
    });
    console.log(`[generate-image] mode=${mode || 'physique'} timeline=${effectiveTimeline} goals=${JSON.stringify(effectiveGoals)} promptLen=${prompt.length}`);

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

    const models = [
      'gemini-3.1-flash-image-preview',
      'gemini-3-pro-image-preview',
      'gemini-2.5-flash-image',
      'gemini-2.0-flash-exp',
    ];

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

    let result = await tryGenerate(contents);

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
    return res.status(200).json({
      success: true,
      image_base64: `data:${mimeType};base64,${imgData}`,
      mode: mode || 'physique',
    });

  } catch (err) {
    console.error('generate-image error:', err.message);
    return res.status(500).json({ success: false, error: err.message });
  }
}
