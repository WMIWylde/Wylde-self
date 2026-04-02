export default async function handler(req, res) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');
  if (req.method === 'OPTIONS') return res.status(200).end();
  if (req.method !== 'POST') return res.status(405).json({ success: false, error: 'Method not allowed' });

  try {
    const apiKey = process.env.OPENAI_API_KEY;
    if (!apiKey) throw new Error('OPENAI_API_KEY not configured');

    const { image_base64, timeline } = req.body;
    if (!image_base64) throw new Error('image_base64 required');

    const timelineLabel = timeline === '6months' ? '6 months' : timeline === '1year' ? '1 year' : '12 weeks';
    const prompt = `Athletic physique transformation after ${timelineLabel} of consistent training. Lean, strong, confident posture. Same face and identity. Photorealistic, natural lighting.`;

    // Strip data URI prefix
    const base64Data = image_base64.replace(/^data:image\/\w+;base64,/, '');
    const imageBuffer = Buffer.from(base64Data, 'base64');

    // Fallback: use the form-data package
    const FormDataPkg = (await import('form-data')).default;
    const form = new FormDataPkg();
    form.append('image', imageBuffer, { filename: 'image.png', contentType: 'image/png' });
    form.append('prompt', prompt);
    form.append('model', 'gpt-image-1');
    form.append('n', '1');
    form.append('size', '1024x1024');
    form.append('quality', 'medium');

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
      throw new Error(data?.error?.message || `OpenAI error ${response.status}`);
    }

    // gpt-image-1 returns b64_json
    const b64 = data?.data?.[0]?.b64_json;
    const url = data?.data?.[0]?.url;

    if (b64) {
      return res.status(200).json({ success: true, image_base64: `data:image/png;base64,${b64}` });
    } else if (url) {
      // fetch and convert URL to base64
      const imgRes = await fetch(url);
      const buf = Buffer.from(await imgRes.arrayBuffer());
      return res.status(200).json({ success: true, image_base64: `data:image/png;base64,${buf.toString('base64')}` });
    } else {
      throw new Error('No image in response: ' + JSON.stringify(data));
    }

  } catch (err) {
    console.error('openai-image error:', err.message);
    return res.status(500).json({ success: false, error: err.message });
  }
}
