// Authentication: requires a valid Supabase JWT in the Authorization header.
const { applyCors } = require('../../lib/security');
const { getUserFromRequest } = require('../../lib/supabase-admin');

module.exports = async function handler(req, res) {
  if (applyCors(req, res, { methods: 'POST, OPTIONS' })) return;
  if (req.method !== 'POST') return res.status(405).json({ error: 'Method not allowed' });

  // Verify Supabase JWT — reject unauthenticated requests
  const user = await getUserFromRequest(req);
  if (!user) return res.status(401).json({ error: 'Unauthorized' });

  const { text } = req.body || {};
  if (!text || typeof text !== 'string' || text.trim().length < 2) {
    return res.status(400).json({ error: 'text is required (describe what you ate)' });
  }

  const apiKey = process.env.OPENAI_API_KEY;
  if (!apiKey) return res.status(500).json({ error: 'OpenAI not configured' });

  const prompt = `The user described what they ate. Parse this into individual food items with accurate nutritional estimates.

User said: "${text.trim()}"

Return ONLY valid JSON in this exact format:
{
  "meals": [
    {
      "name": "Food item name",
      "quantity": "2 large",
      "calories": 180,
      "protein": 12,
      "carbs": 2,
      "fat": 12
    }
  ],
  "total": {
    "calories": 180,
    "protein": 12,
    "carbs": 2,
    "fat": 12
  }
}

Rules:
- Be accurate with portions. "A chicken breast" = ~6oz/170g unless specified otherwise.
- Common sense portions: "some rice" = ~1 cup cooked (200cal), "a salad" = ~2 cups greens + dressing (~150cal)
- If the user says a brand name, use known nutrition data for that brand
- Round all numbers to whole integers
- Include ALL items mentioned, even drinks, sauces, and sides
- If ambiguous, estimate a typical adult portion
- "Coffee with cream" = coffee (~5cal) + 2 tbsp heavy cream (~100cal) as separate items
- Return ONLY the JSON, no explanation`;

  try {
    const response = await fetch('https://api.openai.com/v1/chat/completions', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${apiKey}`,
      },
      body: JSON.stringify({
        model: 'gpt-4o-mini',
        messages: [
          { role: 'system', content: 'You are a precise nutrition calculator. Parse food descriptions into accurate macro breakdowns. You are not a medical professional. If the described intake for a full day appears severely restrictive (under 1200 cal for women or 1500 cal for men), add a "warning" field noting that very low intake may require medical guidance. Nutrition needs change during pregnancy and breastfeeding. Return only valid JSON.' },
          { role: 'user', content: prompt },
        ],
        temperature: 0.3,
        max_tokens: 1500,
      }),
    });

    if (!response.ok) {
      const errText = await response.text();
      console.error('[nutrition/parse] OpenAI error:', response.status, errText.slice(0, 200));
      return res.status(502).json({ error: 'AI parsing failed' });
    }

    const data = await response.json();
    const content = data.choices?.[0]?.message?.content || '';

    // Extract JSON from response
    const jsonStart = content.indexOf('{');
    const jsonEnd = content.lastIndexOf('}');
    if (jsonStart === -1 || jsonEnd === -1) {
      return res.status(502).json({ error: 'Could not parse AI response' });
    }

    const parsed = JSON.parse(content.slice(jsonStart, jsonEnd + 1));
    return res.status(200).json(parsed);
  } catch (e) {
    console.error('[nutrition/parse] Error:', e.message);
    return res.status(500).json({ error: 'Failed to parse food description' });
  }
};
