import FormData from 'form-data';

export default async function handler(req, res) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');

  if (req.method === 'OPTIONS') return res.status(200).end();
  if (req.method !== 'POST') return res.status(405).json({ success: false, error: 'Method not allowed' });

  try {
    const apiKey = process.env.OPENAI_API_KEY;
    if (!apiKey) throw new Error('OPENAI_API_KEY is not configured');

    const { image_base64, prompt: promptOverride, timeline } = req.body;
    if (!image_base64) throw new Error('image_base64 is required');

    // Strip data URI prefix if present
    const base64Data = image_base64.replace(/^data:image\/\w+;base64,/, '');
    const imageBuffer = Buffer.from(base64Data, 'base64');

    // Build prompt
    const timelineLabel = timeline === '6months' ? '6 months'
                        : timeline === '1year'   ? '1 year'
                        : '12 weeks';

    const prompt = promptOverride ||
      `Transform this person's physique to reflect ${timelineLabel} of consistent training toward a lean, athletic build. Keep the same face, skin tone, and identity. Photorealistic, natural lighting, confident posture.`;

    // Build multipart/form-data body
    const form = new FormData();
    form.append('image', imageBuffer, { filename: 'photo.png', contentType: 'image/png' });
    form.append('prompt', prompt);
    form.append('model', 'gpt-image-1');
    form.append('n', '1');
    form.append('size', '1024x1024');
    form.append('response_format', 'b64_json');

    const response = await fetch('https://api.openai.com/v1/images/edits', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${apiKey}`,
        ...form.getHeaders()
      },
      body: form.getBuffer()
    });

    const data = await response.json();

    if (!response.ok) {
      const message = data?.error?.message || `OpenAI error: ${response.status}`;
      throw new Error(message);
    }

    const b64 = data?.data?.[0]?.b64_json;
    if (!b64) throw new Error('No image returned from OpenAI');

    return res.status(200).json({
      success: true,
      image_base64: `data:image/png;base64,${b64}`
    });

  } catch (err) {
    console.error('openai-image error:', err.message);
    return res.status(500).json({ success: false, error: err.message });
  }
}
