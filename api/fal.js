export default async function handler(req, res) {
  // CORS
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'POST, GET, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');

  if (req.method === 'OPTIONS') return res.status(200).end();

  try {
    const { endpoint, requestId } = req.query;

    // Poll existing request
    if (req.method === 'GET' && requestId) {
      const response = await fetch(
        `https://queue.fal.run/fal-ai/instantid/requests/${requestId}`,
        { headers: { 'Authorization': `Key ${process.env.FAL_API_KEY}` } }
      );
      const data = await response.json();
      return res.status(response.status).json(data);
    }

    // Submit new request
    if (req.method === 'POST') {
      const falEndpoint = endpoint || 'fal-ai/instantid';
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
