export const config = {
  runtime: 'edge',
};

const cors = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type',
};

function buildPrompt(timeline, goals, gender, hasImage) {
  const genderLabel = gender || 'male';

  // Normalize goals — accept string or array
  let goalList = [];
  if (Array.isArray(goals)) {
    goalList = goals;
  } else if (typeof goals === 'string' && goals) {
    goalList = [goals];
  }
  if (goalList.length === 0) goalList = ['Get lean & athletic'];
  const goalKey = goalList.map(g => g.toLowerCase()).join(' + ');

  // BASE
  const base = hasImage
    ? `Transform this person's physique SIGNIFICANTLY to show their body after dedicated training with an AI coach, strict nutrition, and zero missed sessions. Keep their face, skin tone, hair, tattoos, and identity identical. Same person, same lighting, same camera angle. ONLY change the body — reduce body fat, add muscle mass, improve definition. The transformation must be CLEARLY VISIBLE and dramatic — not subtle. This is a real transformation, not a minor tweak.`
    : `Generate a photorealistic fitness transformation image showing a ${genderLabel} person with a clearly athletic, transformed physique. Natural lighting. Athletic posture. The body should show obvious signs of dedicated training — visible muscle definition, low body fat, athletic build.`;

  // --- GOAL CLASSIFICATION ---
  // Detect which goal categories are active
  const has = {
    fat:        goalKey.match(/burn|fat|los|weight|slim/),
    muscle:     goalKey.match(/muscle|bulk|build|mass|size|strong/),
    lean:       goalKey.match(/lean|tone|defin|cut|shred/),
    athletic:   goalKey.match(/athlet|perform|sport|agil|function|endur/),
    confidence: goalKey.match(/confiden|feel|health|well|energy/),
  };

  // Count active goal types for combo detection
  const activeGoals = Object.values(has).filter(Boolean).length;

  // --- COMPOSITE GOAL BLOCK ---
  // Build a goal description that handles single goals AND combinations
  let goalBlock = '';

  if (has.fat && has.muscle) {
    // Body recomposition — the most common combo
    goalBlock = `This person's goal is body recomposition — simultaneously losing fat and building muscle. The result should show a dramatically different body composition: significantly less body fat (visible muscle definition, leaner face and waist) combined with noticeably more muscle mass (fuller shoulders, thicker arms, developed chest). They should look like they've been eating in a slight surplus with high protein while training heavy — not skinny, not bulky, but recomposed. Think classic body recomp: the scale might not change much, but the mirror tells a completely different story.`;
  } else if (has.fat && has.lean) {
    // Lean and cut
    goalBlock = `This person's goal is getting lean and defined — maximum fat loss with visible muscle definition. The result should show very low body fat with clean muscle lines visible everywhere: defined arms, visible abs, sharp jawline, minimal love handles. Think fitness model physique — not big, but every muscle is visible and defined. The emphasis is on looking CUT, not bulky.`;
  } else if (has.muscle && has.lean) {
    // Muscular and defined
    goalBlock = `This person's goal is building defined muscle — gaining significant size while staying lean. The result should show a muscular physique with clear definition: big shoulders, full chest, thick arms, developed back — but with visible abs and muscle separation. Think Men's Physique competitor or athletic model. Size AND definition, not one at the expense of the other.`;
  } else if (has.fat && has.athletic) {
    // Athletic fat loss
    goalBlock = `This person's goal is becoming lean and athletic — shedding body fat while building functional, athletic muscle. The result should show a lean, powerful physique: reduced body fat, visible muscle tone, but with an emphasis on looking capable and athletic rather than just skinny. Think UFC fighter or soccer player — lean, fast, powerful.`;
  } else if (has.muscle && has.athletic) {
    // Athletic muscle
    goalBlock = `This person's goal is building athletic muscle — getting bigger and stronger while maintaining athleticism. The result should show a powerful, muscular physique that still looks agile: broad shoulders, thick legs, developed arms, but with the proportions of an athlete, not a bodybuilder. Think NFL receiver or rugby player — big, but built to move.`;
  } else if (has.fat) {
    goalBlock = `This person's goal is fat loss. The body should look noticeably lighter and leaner — significantly smaller waist, slimmer face, less bulk everywhere. Muscle tone is present but understated. The transformation should emphasize how much lighter and more comfortable in their body they look. Think runner or swimmer build — lean, efficient, healthy.`;
  } else if (has.muscle) {
    goalBlock = `This person's goal is building muscle. The body should look noticeably bigger and more muscular — thicker arms, fuller chest, wider shoulders, bigger legs, developed back. This person has been lifting heavy and eating to grow. Some body fat is acceptable — the emphasis is on SIZE and strength. Think powerlifter who also cares about aesthetics.`;
  } else if (has.lean) {
    goalBlock = `This person's goal is getting toned and defined. Show a lean physique with visible muscle definition — low body fat, clean lines, defined abs, visible arm and shoulder definition. Not big, but every muscle is visible. Think fitness influencer or lean martial artist — disciplined, precise, aesthetic.`;
  } else if (has.athletic) {
    goalBlock = `This person's goal is athletic performance. Show a functional, powerful build — lean and muscular in equal measure. Well-developed legs, strong core, balanced proportions. Think decathlete or CrossFit competitor — built to perform, not just to look good. Agile, powerful, and capable.`;
  } else if (has.confidence) {
    goalBlock = `This person's goal is feeling confident and healthy. Show a balanced transformation — better posture, healthier skin, leaner frame, more muscle tone. The person looks like they genuinely take care of themselves. Not extreme in any direction — just visibly healthier, more energetic, and confident. The kind of transformation where people say "you look amazing, what changed?"`;
  } else {
    goalBlock = `Balance fat loss and muscle gain equally — lean, athletic, and healthy. Show a well-rounded transformation that makes this person look like they follow a disciplined training protocol.`;
  }

  // If 3+ goals selected, add emphasis on balanced transformation
  if (activeGoals >= 3) {
    goalBlock += ` This person has multiple transformation goals, so the result should show a well-rounded, complete physical transformation — not biased toward any single goal, but showing clear progress in ALL areas: less fat, more muscle, better definition, improved posture, and overall athleticism.`;
  }

  // --- TIMELINE BLOCKS — aggressive, real results for dedicated training ---
  const timelineBlocks = {
    '12weeks': `Show a SIGNIFICANT 12-week body transformation. This person trained 4x/week with an AI coach, strict nutrition, and did not miss sessions. 12 weeks of real dedication produces REAL visible results — do NOT make this subtle.
REQUIRED physical changes at 12 weeks:
${has.fat ? '- Body fat dropped significantly — waist is 2-3 inches smaller. Love handles visibly reduced. Face is noticeably leaner with sharper jawline. Midsection is tighter and flatter.' : '- Noticeable body fat reduction. Waist visibly smaller. Face leaner.'}
${has.muscle ? '- Arms are visibly more muscular — biceps have clear shape, triceps showing. Shoulders are rounder and wider. Chest is fuller. The body carries noticeably more muscle mass than the original.' : ''}
- Abs are starting to show — at minimum a visible 2-pack or flat defined stomach. Core is tight.
- Shoulders and arms have clear muscle definition even at rest — not just when flexing.
- The V-taper from shoulders to waist is beginning to form.
- Posture is upright, chest open, confident stance.
- Skin looks healthy and vibrant.
This should look like a legitimate before/after transformation photo you'd see on a fitness coach's Instagram — the kind that makes people say "what program are you on?" The change from the original should be OBVIOUS and motivating. Think: body recomposition — less fat, more muscle, tighter everywhere.`,

    '6months': `Show a DRAMATICALLY DIFFERENT body at 6 months. This person has been training 5x/week with an AI coach, progressive overload, caloric surplus/deficit cycling, and has not deviated from the protocol for 6 months. The body should look like a COMPLETELY DIFFERENT PERSON from the 12-week version.
MANDATORY physical changes — the image MUST show ALL of these:
${has.fat ? '- Body fat is 12-14% for males, 19-22% for females. The midsection is TIGHT — clearly visible abs, defined obliques. Waist is 4-5 inches smaller than original. Face is lean with sharp angular jawline and cheekbones. ZERO love handles.' : '- Body fat clearly very low. Midsection is tight and lean.'}
${has.muscle ? '- SUBSTANTIAL muscle mass increase. Arms are noticeably thick — bicep peak is prominent, tricep horseshoe is clearly defined even unflexed. Shoulders are wide, round, capped, and striated — the kind that fill out a t-shirt. The V-taper from shoulders to waist is DRAMATIC. Chest is full and squared with visible upper chest separation. Back is noticeably wider — lats flare. Traps are visible from the front.' : ''}
- VISIBLE 4-6 pack abs depending on lighting. This is NON-NEGOTIABLE at 6 months.
- Forearm and bicep veins clearly visible. Muscle separation between deltoid heads is clear.
- Legs show visible quad sweep — the teardrop shape above the knee. Calves have definition.
- The entire body looks like it has been RECOMPOSED — dramatically less fat, dramatically more muscle.
- Posture is powerful and confident — chest up, shoulders back, commanding stance.
IMPORTANT: This must look like a Men's Health or Women's Health cover model transformation. The kind where people see the before/after and say "that can't be the same person." This is NOT a subtle improvement from 12 weeks — it is a QUANTUM LEAP. If the 12-week version makes friends notice, the 6-month version makes STRANGERS stop and stare. Think Chris Hemsworth preparing for Thor, or someone who could compete in a physique show.`,

    '1year': `Show the ABSOLUTE PEAK natural physique transformation at 1 year. This person trained 5-6x/week for 365 days straight — periodized programming, strict nutrition, supplements, sleep optimization, and total dedication. This body represents the pinnacle of what this person can achieve naturally.
MANDATORY physical changes — EVERY SINGLE ONE of these must be visible:
${has.fat ? '- Body fat is at COMPETITION levels — 8-12% for males, 16-20% for females. There is NO excess body fat ANYWHERE on the body. The face is CHISELED — razor sharp jawline, defined cheekbones, lean angular features. Skin sits tight against muscle everywhere.' : '- Body fat is extremely low — every muscle is visible through the skin.'}
${has.muscle ? '- MAXIMUM natural muscle development. Arms are THICK and VASCULAR — every head of the bicep and tricep is distinctly visible. Shoulders are WIDE, STRIATED, and have visible muscle fibers — they look like cannonballs. The V-taper is EXTREME. Chest is FULL with visible striations when the light hits. Back has a wide dramatic lat spread. Traps create a visible slope from neck to shoulder. Forearms are thick with road-map vascularity.' : ''}
- FULL 6-PACK ABS with deep separations between each block. Obliques are CARVED. Serratus anterior fans are visible along the ribs. Lower abs show — the V-lines (Adonis belt) are clearly defined.
- VASCULARITY is prominent — veins visible across forearms, biceps, deltoids, and possibly across the lower abs.
- Every single muscle group shows clear separation and definition — deltoid heads, quad heads, hamstrings, calves.
- Legs are POWERFUL — quadriceps show 3-4 distinct heads, hamstrings visible from behind, calves are diamond-shaped.
- The body has the dry, full, polished look of someone who has been training for a full year without stopping.
- Posture is COMMANDING — this person walks into a room and everyone notices. They radiate physical discipline and power.
CRITICAL: This should look like a FITNESS MODEL, NATURAL BODYBUILDER, or ELITE ATHLETE at their absolute peak. Think: magazine cover, fitness competition stage, or movie star physique. The difference from the 6-month version must STILL be clearly visible — more size, more definition, more vascularity, more visual impact. The transformation from the ORIGINAL photo should be UNRECOGNIZABLE — the same face on a completely rebuilt body. This is what a full year of ZERO COMPROMISE looks like.`,
  };

  const timelineBlock = timelineBlocks[timeline] || timelineBlocks['12weeks'];

  return `${base}\n\n${timelineBlock}\n\nGoal direction: ${goalBlock}\n\nCRITICAL RULES:\n- Photorealistic only. Natural lighting. High quality.\n- No text, watermarks, or graphics anywhere in the image.\n- The person must look like a REAL human being — not AI-generated or CGI.\n- Keep the same face, skin tone, hair, tattoos, and distinguishing features.\n- DO NOT be conservative with the body transformation — show REAL results that reflect dedicated training.\n- The body change should be the FIRST thing anyone notices when comparing before and after.\n- Err on the side of MORE transformation, not less. Users want to see what's possible when they follow through.`;
}

export default async function handler(req) {
  if (req.method === 'OPTIONS') {
    return new Response(null, { status: 200, headers: cors });
  }
  if (req.method !== 'POST') {
    return new Response(JSON.stringify({ success: false, error: 'Method not allowed' }), {
      status: 405,
      headers: { ...cors, 'Content-Type': 'application/json' },
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

    // Try models in order — names change often, first success wins
    // Updated April 2026: old 2.0-flash-exp models retired
    const models = [
      'gemini-2.5-flash-image',
      'gemini-3.1-flash-image-preview',
      'gemini-3-pro-image-preview',
    ];

    const body = JSON.stringify({
      contents,
      generationConfig: {
        responseModalities: ['TEXT', 'IMAGE']
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
          body
        }
      );
      data = await response.json();
      usedModel = model;
      if (response.ok || response.status !== 404) break;
      console.log(`[generate-image] Model ${model} returned ${response.status}, trying next...`);
    }

    console.log(`[generate-image] Final model: ${usedModel}, status: ${response.status}`);

    if (!response.ok) {
      const errMsg = data?.error?.message || `Gemini error ${response.status}`;
      console.error(`[generate-image] API error:`, JSON.stringify(data?.error || data).substring(0, 500));
      throw new Error(errMsg);
    }

    const parts = data?.candidates?.[0]?.content?.parts || [];
    console.log(`[generate-image] Response parts: ${parts.length}, types: ${parts.map(p => p.text ? 'text' : p.inlineData ? 'image' : 'unknown').join(',')}`);
    const imagePart = parts.find(p => p.inlineData);

    if (!imagePart) {
      console.error('[generate-image] No image part found. Full response:', JSON.stringify(data).substring(0, 500));
      throw new Error('No image in response — model may not support image generation');
    }

    const { mimeType, data: imgData } = imagePart.inlineData;
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
