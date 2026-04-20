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
    ? `Transform this person's physique to show what they will realistically look like after following through on their training protocol. Keep their face, skin tone, hair, and identity identical. Same person, same lighting direction, same camera angle. Only change the body composition and musculature.`
    : `Generate a photorealistic fitness transformation image showing a ${genderLabel} person. Natural lighting. Athletic posture. This is what they will look like after following their protocol.`;

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

  // --- TIMELINE BLOCKS — goal-aware physical markers ---
  const timelineBlocks = {
    '12weeks': `Show what this person will realistically look like after 12 weeks of consistent 4-day/week training and clean eating. This is week 12 — they followed through on the protocol.
Physical changes (subtle but real — the early wins):
${has.fat ? '- Waist is 1-2 inches smaller. Face is noticeably leaner. Clothes fit looser around the midsection.' : '- Body fat slightly reduced. Waist is a bit tighter.'}
${has.muscle ? '- Arms show a hint of new muscle when flexed — slightly fuller biceps, emerging tricep shape. Shoulders are marginally rounder.' : '- Muscle tone is starting to show — arms have slightly more definition.'}
${has.lean ? '- First signs of definition appearing — faint lines on arms, slightly more visible collarbone and shoulder caps.' : ''}
${has.athletic ? '- Posture is noticeably better. Stands taller, moves more confidently. Legs look slightly more toned.' : '- Posture is slightly improved. Stands a bit taller.'}
- Skin looks healthier — better color, more vibrant.
- Face is marginally leaner, jawline slightly more defined.
Overall impression: "They've been working out" — friends notice, strangers don't yet. This is the START of a real transformation. Visible enough to be motivating, but clearly just the beginning. DO NOT over-transform — this must look like an honest 12 weeks of work.`,

    '6months': `Show what this person will realistically look like after 6 months of dedicated 4-5 day/week training and disciplined nutrition. They followed through on the protocol for half a year.
Physical changes (clearly visible — a dramatic step up from 12 weeks):
${has.fat ? '- Body fat reduced by 15-25 lbs from original. Waist is 3-4 inches smaller. Face is noticeably lean — sharp jawline, defined cheekbones. Love handles gone or nearly gone. Clothes hang differently — everything is looser around the middle.' : '- Body fat is lower. Waist is 2-3 inches smaller. Face is leaner.'}
${has.muscle ? '- Arms are visibly bigger — clear bicep peak, tricep horseshoe forming. Shoulders are noticeably wider and rounder. Chest is fuller with visible upper chest. Back is wider. The body looks like it carries more mass than before.' : '- Arms show visible definition. Shoulders are slightly broader.'}
${has.lean ? '- Muscle definition is clear — visible arm veins, shoulder striations, upper abs emerging. The body has clean lines. Obliques are starting to show.' : '- Upper abs are faintly visible. Arms show separation between muscle groups.'}
${has.athletic ? '- Body moves and looks athletic — visible quad sweep, developed calves, strong-looking core. Proportioned like someone who trains for performance.' : '- Legs are more defined. Quads have visible shape.'}
- Posture is confident and upright. This person carries themselves differently.
- The transformation from the 12-week version should be OBVIOUSLY more advanced — this is not a subtle difference.
Overall impression: friends say "you look amazing" unprompted. People ask what you've been doing. This person has clearly been training hard for months — the dedication shows in every part of their body.`,

    '1year': `Show what this person will realistically look like after a full year of consistent 5-day/week training and strict nutrition discipline. They followed the protocol for an entire year without quitting.
Physical changes (dramatic — a completely different-looking person from the start):
${has.fat ? '- Body fat is at lean/athletic levels — 10-14% for males, 18-22% for females. Waist is 4-6 inches smaller than the start. Face is angular and lean. NO visible excess body fat. The transformation from the original is striking.' : '- Body fat is at a fit athletic level — 12-15% for males, 20-23% for females.'}
${has.muscle ? '- Significant muscle mass gained. Arms are thick with clear separation — biceps, triceps, and deltoids all distinctly visible. Shoulders are wide, capped, and round — creating an obvious V-taper. Chest is full and developed. Back is wide with visible lat spread. Traps are developed. Legs are powerful — visible quad sweep and hamstring development.' : '- Clear muscle definition throughout. Arms show separation between all muscle groups.'}
${has.lean ? '- Razor sharp definition — visible abs (4-6 pack depending on genetics), defined obliques, serratus visible. Arm veins are prominent. Shoulder striations visible. Every muscle group has clean, visible separation. This person looks CARVED.' : '- 4-pack or 6-pack visible. Obliques defined. Overall lean and defined.'}
${has.athletic ? '- Athletic proportions — powerful legs, strong core, balanced upper and lower body. Looks like someone who can perform: explosive, agile, and strong. Think elite amateur athlete.' : '- Athletic posture. Commanding presence.'}
- Face is lean and angular. Looks healthy and vital, not gaunt.
- Posture is commanding. This person walks into a room and people notice.
- The difference from BOTH the original AND the 6-month version should be immediately, dramatically obvious.
Overall impression: strangers notice. People assume this person is an athlete or personal trainer. They have fundamentally transformed their body over a full year — this is what complete follow-through looks like. NOT a professional bodybuilder — but someone who has clearly made fitness a core part of their identity.`,
  };

  const timelineBlock = timelineBlocks[timeline] || timelineBlocks['12weeks'];

  return `${base}\n\n${timelineBlock}\n\nGoal direction: ${goalBlock}\n\nCRITICAL RULES: Photorealistic only. Natural lighting. High quality. No text, watermarks, or graphics. The person must look like a REAL human being, not AI-generated. Maintain the same person's identity throughout — same face, same skin tone, same distinguishing features. This image represents what they WILL look like after following through.`;
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
