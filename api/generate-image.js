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

  // TIMELINE BLOCK
  const timelineBlocks = {
    '12weeks': `Show 12 weeks of consistent training and clean eating. Visibly reduced body fat (approximately 4-6% reduction). Shoulders slightly broader. Waist noticeably tighter. Arms show early muscle definition. Core has some visible tone but not dramatic. Overall look: leaner and more athletic. Skin looks healthier. Posture slightly improved. Subtle but clear physical change.`,

    '6months': `Show 6 months of dedicated training. Significant body recomposition — substantially less body fat (8-12% reduction from starting point), noticeably more muscle mass. Shoulders are clearly broader and rounder. Arms show defined biceps and triceps. Core is visibly toned with some abdominal definition. Chest is fuller. Legs look more athletic. Overall look: strong, athletic, confident. Posture is upright and commanding. This is a body that has clearly been through months of consistent work. More dramatic change than 12 weeks — this should look like a different fitness level, not just a minor adjustment.`,

    '1year': `Show a full year of elite training and nutrition discipline. This is a major physical transformation. Body fat is very low (athletic/performance level). Muscle is clearly developed across all major groups — shoulders are wide and defined, arms have strong visible muscle separation, chest is full, back is visibly wider creating a V-taper, core is lean with clear abdominal definition, legs are athletic and strong. Overall look: this person has completely changed their body composition. They look like a fitness athlete or high-performance individual. Skin is radiant. Posture is excellent. The difference from the original photo should be dramatic and immediately obvious — this is what a full year of dedicated transformation looks like.`,
  };

  const timelineBlock = timelineBlocks[timeline] || timelineBlocks['12weeks'];

  // GOAL BLOCK
  const goalLower = (goal || '').toLowerCase();
  let goalBlock = 'Show a balanced transformation — leaner and more muscular equally.';

  if (goalLower.includes('los') || goalLower.includes('fat') || goalLower.includes('weight')) {
    goalBlock = 'Emphasize fat loss over muscle gain. The transformation shows a much leaner, lighter physique. Focus on reduced waist, face, and limbs.';
  } else if (goalLower.includes('muscle') || goalLower.includes('bulk') || goalLower.includes('build')) {
    goalBlock = 'Emphasize muscle gain. The transformation shows clear hypertrophy — bigger arms, chest, shoulders, and legs. Athletic and powerful look.';
  } else if (goalLower.includes('athlet') || goalLower.includes('perform') || goalLower.includes('sport')) {
    goalBlock = 'Emphasize athletic body composition — lean and muscular equally. Looks like a high-performance athlete. Functional and strong.';
  } else if (goalLower.includes('tone') || goalLower.includes('definition') || goalLower.includes('lean')) {
    goalBlock = 'Emphasize definition over size. Lean, toned, and fit. Muscles are defined but not large. Healthy and energetic look.';
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

    const response = await fetch(
      `https://generativelanguage.googleapis.com/v1beta/models/gemini-3.1-flash-image-preview:generateContent?key=${apiKey}`,
      {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          contents,
          generationConfig: {
            responseModalities: ['TEXT', 'IMAGE']
          }
        })
      }
    );

    const data = await response.json();

    if (!response.ok) {
      throw new Error(data?.error?.message || `Gemini error ${response.status}`);
    }

    const parts = data?.candidates?.[0]?.content?.parts || [];
    const imagePart = parts.find(p => p.inlineData);

    if (!imagePart) {
      throw new Error('No image in response: ' + JSON.stringify(data).substring(0, 200));
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
