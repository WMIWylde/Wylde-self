export default async function handler(req, res) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');
  if (req.method === 'OPTIONS') return res.status(200).end();
  if (req.method !== 'POST') return res.status(405).json({ success: false, error: 'Method not allowed' });

  try {
    const apiKey = process.env.GEMINI_API_KEY;
    if (!apiKey) throw new Error('GEMINI_API_KEY not configured');

    const { image_base64, timeline, goal, gender } = req.body;

    const timelineLabel = timeline === '6months' ? '6 months' : timeline === '1year' ? '1 year' : '12 weeks';
    const goalLabel = goal || 'lean and athletic';
    const genderLabel = gender || 'male';

    // Build prompt and contents array
    const prompt = `Generate a photorealistic fitness transformation image showing a ${genderLabel} person after ${timelineLabel} of consistent training toward a ${goalLabel} physique. Athletic, lean, confident posture. Natural lighting. No text or watermarks.`;

    let contents;

    if (image_base64) {
      // Image editing mode — user uploaded a photo
      const base64Data = image_base64.replace(/^data:image\/\w+;base64,/, '');
      const mimeType = image_base64.match(/^data:(image\/\w+);base64,/)?.[1] || 'image/jpeg';
      contents = [
        {
          role: 'user',
          parts: [
            {
              inlineData: {
                mimeType,
                data: base64Data
              }
            },
            {
              text: `Transform this person's physique to show ${timelineLabel} of consistent ${goalLabel} training. Keep the same face and identity. Athletic, lean, confident. Photorealistic.`
            }
          ]
        }
      ];
    } else {
      // Text-to-image mode — no photo uploaded
      contents = [
        {
          role: 'user',
          parts: [{ text: prompt }]
        }
      ];
    }

    const response = await fetch(
      `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash-preview-04-17:generateContent?key=${apiKey}`,
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

    // Extract image from response
    const parts = data?.candidates?.[0]?.content?.parts || [];
    const imagePart = parts.find(p => p.inlineData);

    if (!imagePart) {
      throw new Error('No image in response: ' + JSON.stringify(data).substring(0, 200));
    }

    const { mimeType, data: imgData } = imagePart.inlineData;
    return res.status(200).json({
      success: true,
      image_base64: `data:${mimeType};base64,${imgData}`
    });

  } catch (err) {
    console.error('generate-image error:', err.message);
    return res.status(500).json({ success: false, error: err.message });
  }
}
