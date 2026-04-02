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

    const base64Data = image_base64.replace(/^data:image\/\w+;base64,/, '');
    const imageBuffer = Buffer.from(base64Data, 'base64');

    const timelineLabel = timeline === '6months' ? '6 months' : timeline === '1year' ? '1 year' : '12 weeks';
    const prompt = promptOverride || `Athletic physique transformation after ${timelineLabel} of consistent training. Lean, muscular, confident. Same face and identity. Photorealistic.`;

    const form = new FormData();
    form.append('image', imageBuffer, { filename: 'photo.png', contentType: 'image/png' });
    form.append('prompt', prompt);
    form.append('model', 'dall-e-2');
    form.append('n', '1');
    form.append('size', '512x512');

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
      throw new Error(data?.error?.message || `OpenAI error: ${response.status}`);
    }

    const imageUrl = data?.data?.[0]?.url;
    if (!imageUrl) throw new Error('No image URL returned from OpenAI');

    // Fetch the image and convert to base64 to return to client
    const imgResponse = await fetch(imageUrl);
    const imgBuffer = Buffer.from(await imgResponse.arrayBuffer());
    const imgBase64 = imgBuffer.toString('base64');

    return res.status(200).json({
      success: true,
      image_base64: `data:image/png;base64,${imgBase64}`
    });

  } catch (err) {
    console.error('openai-image error:', err.message);
    return res.status(500).json({ success: false, error: err.message });
  }
}
