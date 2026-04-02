import FormData from 'form-data';
import sharp from 'sharp';

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

    if (imageBuffer.length > 4 * 1024 * 1024) {
      throw new Error('Image too large. Please use a photo under 4MB.');
    }

    const pngBuffer = await sharp(imageBuffer)
      .resize(512, 512, { fit: 'cover', position: 'centre' })
      .png()
      .toBuffer();

    const timelineLabel = timeline === '6months' ? '6 months' : timeline === '1year' ? '1 year' : '12 weeks';
    const prompt = promptOverride || `Athletic physique transformation after ${timelineLabel} of consistent training. Lean, muscular, confident. Same face and identity. Photorealistic.`;

    const form = new FormData();
    form.append('image', pngBuffer, { filename: 'photo.png', contentType: 'image/png' });
    form.append('prompt', prompt);
    form.append('model', 'gpt-image-1');
    form.append('n', '1');
    form.append('size', '1024x1024');
    form.append('response_format', 'b64_json');

    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), 55000);

    const response = await fetch('https://api.openai.com/v1/images/edits', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${apiKey}`,
        ...form.getHeaders()
      },
      body: form.getBuffer(),
      signal: controller.signal
    });
    clearTimeout(timeout);

    const data = await response.json();

    if (!response.ok) {
      throw new Error(data?.error?.message || `OpenAI error: ${response.status}`);
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
