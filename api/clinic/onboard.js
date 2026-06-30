const { applyCors, rateLimit, clientIp } = require('../../lib/security');
const { getSupabaseAdmin, getUserFromRequest } = require('../../lib/supabase-admin');

module.exports = async function handler(req, res) {
  if (applyCors(req, res, { methods: 'POST, OPTIONS' })) return;
  if (req.method !== 'POST') return res.status(405).json({ error: 'Method not allowed' });

  const user = await getUserFromRequest(req);
  if (!user) return res.status(401).json({ error: 'Unauthorized' });

  const rl = rateLimit({ key: 'clinic-onboard', ip: clientIp(req), limit: 3, windowMs: 60000 });
  if (!rl.ok) return res.status(429).json({ error: 'Rate limit exceeded' });

  const supabase = getSupabaseAdmin();
  const { content, file_text } = req.body || {};
  const rawText = content || file_text || '';

  if (!rawText || rawText.length < 20) {
    return res.status(400).json({ error: 'Please provide clinic information (product lists, pricing, protocols, etc.)' });
  }

  try {
    const apiKey = process.env.OPENAI_API_KEY;
    if (!apiKey) throw new Error('OPENAI_API_KEY not configured');

    const response = await fetch('https://api.openai.com/v1/chat/completions', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${apiKey}` },
      body: JSON.stringify({
        model: 'gpt-4o',
        max_tokens: 4096,
        messages: [
          { role: 'system', content: ONBOARD_SYSTEM_PROMPT },
          { role: 'user', content: rawText.slice(0, 8000) },
        ],
      }),
    });

    const aiData = await response.json();
    const aiContent = aiData.choices?.[0]?.message?.content;
    if (!aiContent) throw new Error('No AI response');

    // Parse JSON from response
    let parsed;
    try {
      const jsonStart = aiContent.indexOf('{');
      const jsonEnd = aiContent.lastIndexOf('}');
      parsed = JSON.parse(aiContent.substring(jsonStart, jsonEnd + 1));
    } catch (e) {
      return res.status(200).json({ success: false, error: 'Could not parse AI response', raw: aiContent.substring(0, 1000) });
    }

    // Save clinic settings
    if (parsed.clinic_name) {
      await supabase.from('clinic_settings').upsert({
        clinician_id: user.id,
        clinic_name: parsed.clinic_name,
        branding: parsed.branding || {},
      }, { onConflict: 'clinician_id' });
    }

    // Save products
    let productsAdded = 0;
    if (Array.isArray(parsed.products)) {
      for (const p of parsed.products) {
        const { error } = await supabase.from('clinic_products').insert({
          clinician_id: user.id,
          name: p.name || 'Unnamed Product',
          category: mapCategory(p.category || p.type || 'supplement'),
          description: p.description || null,
          typical_dose: p.dose || p.typical_dose || null,
          frequency: p.frequency || null,
          method: p.method || p.administration || null,
          price: p.price ? parseFloat(p.price) : null,
          price_unit: p.price_unit || 'per unit',
          in_stock: true,
          is_active: true,
        });
        if (!error) productsAdded++;
      }
    }

    // Save protocols
    let protocolsAdded = 0;
    if (Array.isArray(parsed.protocols)) {
      for (const proto of parsed.protocols) {
        const { data: protocol, error } = await supabase.from('patient_protocols').insert({
          user_id: user.id,
          name: proto.name || 'Protocol',
          phase: proto.phase || 'Template',
          status: 'active',
          assigned_by: user.id,
          config: { template: true, description: proto.description, components: proto.components },
        }).select().single();

        if (!error) protocolsAdded++;
      }
    }

    return res.status(200).json({
      success: true,
      clinic_name: parsed.clinic_name || null,
      products_added: productsAdded,
      protocols_added: protocolsAdded,
      parsed_data: parsed,
    });

  } catch (err) {
    console.error('[clinic/onboard] error:', err.message);
    return res.status(500).json({ error: err.message });
  }
};

function mapCategory(raw) {
  const lower = (raw || '').toLowerCase();
  if (lower.includes('peptide')) return 'peptide';
  if (lower.includes('hormone') || lower.includes('hrt') || lower.includes('trt') || lower.includes('testosterone')) return 'medication';
  if (lower.includes('supplement') || lower.includes('vitamin') || lower.includes('mineral')) return 'supplement';
  if (lower.includes('medication') || lower.includes('rx') || lower.includes('pharma')) return 'medication';
  if (lower.includes('service') || lower.includes('iv') || lower.includes('infusion')) return 'service';
  if (lower.includes('lab') || lower.includes('test') || lower.includes('panel')) return 'lab_test';
  return 'supplement';
}

const ONBOARD_SYSTEM_PROMPT = `You are a clinical data structuring assistant for a wellness platform called Wylde Self.

A clinician is uploading their clinic's product list, pricing, protocols, or general information. Your job is to extract and structure this into a clean JSON format.

Return ONLY valid JSON in this exact format:
{
  "clinic_name": "Name of the clinic if mentioned",
  "branding": {
    "tagline": "if mentioned",
    "specialties": ["list of specialties"]
  },
  "products": [
    {
      "name": "Product name",
      "category": "peptide|hormone|medication|supplement|service|lab_test",
      "description": "Brief description",
      "dose": "typical dose if mentioned",
      "frequency": "how often",
      "method": "injection|oral|topical|iv|sublingual",
      "price": 150.00,
      "price_unit": "per unit|per month|per cycle|per session"
    }
  ],
  "protocols": [
    {
      "name": "Protocol name",
      "description": "What it's for",
      "phase": "Phase name if applicable",
      "components": ["list of products/therapies in this protocol"]
    }
  ]
}

Rules:
- Extract as many products and protocols as you can find
- If pricing is mentioned, include it. If not, set price to null
- Map categories accurately: peptides, hormones, medications, supplements, services, lab tests
- If the text mentions a clinic name, website, or branding, capture it
- If dosing is mentioned, include it as educational/reference only
- Be thorough — capture everything the clinician provided
- If you can't determine a field, set it to null rather than guessing`;
