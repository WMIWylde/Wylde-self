export const config = {
  runtime: 'edge',
};

const cors = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type',
};

function buildPrompt(timeline, goal, gender, hasImage) {
  const genderLabel = gender || 'male';

  // BASE
  const base = hasImage
    ? `Transform this person's physique realistically. Keep their face, skin tone, hair, and identity identical. Same person, same lighting direction, same camera angle. Only change the body.`
    : `Generate a photorealistic fitness transformation image showing a ${genderLabel} person. Natural lighting. Athletic posture.`;

  // TIMELINE BLOCK — each level uses concrete physical markers so the model
  // produces visibly distinct results across the three timelines.
  const timelineBlocks = {
    '12weeks': `Show a realistic 12-week transformation with consistent 4-day/week training and clean eating.
Physical changes (subtle but visible):
- Body fat reduced by roughly 3-5 lbs. Waist is slightly tighter — maybe 1 inch smaller.
- Arms: a hint of muscle definition when flexed, but still soft at rest.
- Shoulders: very slightly rounder, not dramatically wider.
- Core: flatter stomach, no visible abs yet — just less softness.
- Face: marginally leaner jawline.
- Posture: stands a bit taller, chest slightly more open.
- Skin looks a touch healthier, more color.
Overall impression: "They've been working out" — noticeable to friends, not to strangers. This is the START of a transformation, not a magazine cover.`,

    '6months': `Show a realistic 6-month transformation with dedicated 4-5 day/week training and disciplined nutrition.
Physical changes (clearly visible — a real step up from 12 weeks):
- Body fat reduced by roughly 10-15 lbs from original. Waist is 2-3 inches smaller.
- Arms: visible bicep and tricep separation even at rest. Forearms have veins starting to show.
- Shoulders: noticeably broader and rounder — the shoulder-to-waist ratio has changed.
- Chest: fuller, with some upper chest definition visible.
- Core: upper abs are faintly visible. Obliques starting to show. Still not shredded — just lean.
- Legs: quads have visible sweep, calves are more defined.
- Face: noticeably leaner, jawline is sharper.
- Posture: confident and upright. Clothes would fit differently on this person.
Overall impression: friends say "you look great" unprompted. This is someone who has clearly been training hard for months — it should be obviously more transformed than the 12-week version.`,

    '1year': `Show a realistic 1-year transformation with consistent 5-day/week training and strict nutrition discipline.
Physical changes (dramatic — clearly different from the 6-month result):
- Body fat is at a fit/athletic level — roughly 12-15% for males, 20-23% for females.
- Arms: clear muscle separation between biceps, triceps, and deltoids. Visible vascularity.
- Shoulders: wide, capped, round — creating an obvious V-taper from shoulders to waist.
- Chest: full and defined with visible pec striations when flexed.
- Core: 4-pack or 6-pack visible depending on lighting. Obliques are defined. Serratus showing.
- Back: visibly wider — lats flare. Traps are developed.
- Legs: defined quads with visible muscle heads, hamstrings show when walking.
- Face: lean and angular. Looks healthy, not gaunt.
- Posture: commanding. This person carries themselves like an athlete.
Overall impression: strangers notice. This is someone who has fundamentally changed their body composition over a full year — the difference from the original AND from the 6-month version should be immediately obvious. Think "regular person who became a fitness enthusiast" — not a bodybuilder, but clearly athletic and disciplined.`,
  };

  const timelineBlock = timelineBlocks[timeline] || timelineBlocks['12weeks'];

  // GOAL BLOCK — biases the transformation toward a specific direction
  const goalLower = (goal || '').toLowerCase();
  let goalBlock = 'Balance fat loss and muscle gain equally — lean and athletic.';

  if (goalLower.includes('los') || goalLower.includes('fat') || goalLower.includes('weight')) {
    goalBlock = 'Prioritize fat loss. The body should look noticeably lighter and leaner — smaller waist, slimmer face, less bulk. Muscle tone is present but understated. Think runner or swimmer build, not powerlifter.';
  } else if (goalLower.includes('muscle') || goalLower.includes('bulk') || goalLower.includes('build')) {
    goalBlock = 'Prioritize muscle gain. The body should look noticeably bigger — thicker arms, fuller chest, wider shoulders, bigger legs. Some body fat is fine. Think someone who lifts heavy and eats to grow.';
  } else if (goalLower.includes('athlet') || goalLower.includes('perform') || goalLower.includes('sport')) {
    goalBlock = 'Show an athletic build — lean and muscular in equal measure. Think basketball player or CrossFit competitor. Functional, powerful, and agile-looking.';
  } else if (goalLower.includes('tone') || goalLower.includes('definition') || goalLower.includes('lean')) {
    goalBlock = 'Show a toned, defined physique — low body fat with moderate muscle. Muscles are visible and defined but not large. Think Pilates instructor or lean martial artist.';
  } else if (goalLower.includes('confidence') || goalLower.includes('feel')) {
    goalBlock = 'Show a healthy, balanced transformation. Better posture, healthier skin, leaner frame. The person looks like they take care of themselves — confident and vital.';
  }

  return `${base} ${timelineBlock} ${goalBlock} Photorealistic. Natural lighting. High quality. No text or watermarks.`;
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

    const { image_base64, timeline, goal, userGoal, gender } = await req.json();

    // userGoal takes precedence over legacy goal field
    const effectiveGoal = userGoal || goal || 'lean and athletic';
    const effectiveTimeline = timeline || '12weeks';

    const prompt = buildPrompt(effectiveTimeline, effectiveGoal, gender, !!image_base64);

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
