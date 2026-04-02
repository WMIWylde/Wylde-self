export default async function handler(req, res) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');
  if (req.method === 'OPTIONS') return res.status(200).end();
  if (req.method !== 'POST') return res.status(405).json({ success: false, error: 'Method not allowed' });

  try {
    const apiKey = process.env.OPENAI_API_KEY;
    if (!apiKey) throw new Error('OPENAI_API_KEY not configured');

    const { timeline, goal, gender } = req.body;

    const timelineLabel = timeline === '6months' ? '6 months' : timeline === '1year' ? '1 year' : '12 weeks';
    const goalLabel = goal || 'lean and athletic';
    const genderLabel = gender || 'male';

    const prompt = `A fit, confident ${genderLabel} person with a ${goalLabel} physique after ${timelineLabel} of dedicated training. Athletic build, natural lighting, standing confidently. Photorealistic fitness photography. No text, no watermarks.`;

    const response = await fetch('https://api.openai.com/v1/images/generations', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${apiKey}`,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({
        model: 'dall-e-3',
        prompt,
        n: 1,
        size: '1024x1024',
        quality: 'standard',
        response_format: 'b64_json'
      })
    });

    const data = await response.json();

    if (!response.ok) {
      throw new Error(data?.error?.message || `OpenAI error ${response.status}`);
    }

    const b64 = data?.data?.[0]?.b64_json;
    if (!b64) throw new Error('No image returned');

    return res.status(200).json({ success: true, image_base64: `data:image/png;base64,${b64}` });

  } catch (err) {
    console.error('openai-image error:', err.message);
    return res.status(500).json({ success: false, error: err.message });
  }
}
