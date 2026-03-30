export default async function handler(req, res) {
  // CORS
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'POST, GET, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');

  if (req.method === 'OPTIONS') return res.status(200).end();

  try {
    const { endpoint, requestId } = req.query;

    // Poll existing request — strip variant suffixes to get base model path
    if (req.method === 'GET' && requestId) {
      const model = endpoint || 'fal-ai/flux/dev/image-to-image';
      // fal status URLs use the base model path, e.g. fal-ai/flux not fal-ai/flux/dev/image-to-image
      const basePath = model
        .replace(/\/image-to-image$/, '')
        .replace(/\/dev$/, '');
      const response = await fetch(
        `https://queue.fal.run/${basePath}/requests/${requestId}/status`,
        { headers: { 'Authorization': `Key ${process.env.FAL_API_KEY}` } }
      );
      const data = await response.json();
      return res.status(200).json(data);
    }

    // Submit new request
    if (req.method === 'POST') {
      const falEndpoint = endpoint || 'fal-ai/flux/dev/image-to-image';
      const response = await fetch(`https://queue.fal.run/${falEndpoint}`, {
        method: 'POST',
        headers: {
          'Authorization': `Key ${process.env.FAL_API_KEY}`,
          'Content-Type': 'application/json'
        },
        body: JSON.stringify(req.body)
      });
      const data = await response.json();
      return res.status(response.status).json(data);
    }

    return res.status(405).json({ error: 'Method not allowed' });
  } catch (err) {
    return res.status(500).json({ error: err.message });
  }
}
