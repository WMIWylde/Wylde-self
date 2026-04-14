import { createClient } from '@supabase/supabase-js';

const supabase = createClient(
  process.env.SUPABASE_URL,
  process.env.SUPABASE_SERVICE_KEY
);

export default async function handler(req, res) {
  if (req.method !== 'POST') {
    return res.status(405).json({ error: 'Method not allowed' });
  }

  const { protocol, userProfile, userId } = req.body;

  try {
    const { data: knowledge } = await supabase
      .from('peptide_knowledge')
      .select('*')
      .eq('peptide_name', protocol)
      .single();

    const { data: activeProtocol } = await supabase
      .from('peptide_protocols')
      .select('*, protocol_logs(*)')
      .eq('user_id', userId)
      .eq('peptide_name', protocol)
      .eq('status', 'active')
      .maybeSingle();

    const cycleWeeks = knowledge?.cycle_length
      ? parseInt(knowledge.cycle_length) : 12;

    let currentWeek = 0;
    let weeksRemaining = cycleWeeks;
    if (activeProtocol?.start_date) {
      currentWeek = Math.floor(
        (new Date() - new Date(activeProtocol.start_date))
        / (7 * 24 * 60 * 60 * 1000)
      );
      weeksRemaining = Math.max(0, cycleWeeks - currentWeek);
    }

    const profileText = `
Age: ${userProfile?.age || 'unknown'}
Gender: ${userProfile?.gender || 'unknown'}
Weight: ${userProfile?.weight_kg || 'unknown'}kg
Goal: ${userProfile?.goal || 'general wellness'}
Fitness level: ${userProfile?.fitness_level || 'moderate'}
Health concerns: ${userProfile?.health_concerns || 'none noted'}
Days per week training: ${userProfile?.days_per_week || 3}`;

    const knowledgeText = knowledge ? `
Peptide: ${knowledge.peptide_name}
Category: ${knowledge.category}
Mechanism: ${knowledge.mechanism}
Primary benefits: ${JSON.stringify(knowledge.benefits?.primary)}
Secondary benefits: ${JSON.stringify(knowledge.benefits?.secondary)}
Typical dose: ${knowledge.typical_dose}
Cycle length: ${knowledge.cycle_length} weeks
Contraindications: ${knowledge.contraindications?.join(', ')}
Stacking notes: ${knowledge.stacking_notes}
Research summary: ${knowledge.research_summary}` : '';

    const response = await fetch(
      'https://api.anthropic.com/v1/messages',
      {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'x-api-key': process.env.ANTHROPIC_API_KEY,
          'anthropic-version': '2023-06-01'
        },
        body: JSON.stringify({
          model: 'claude-haiku-4-5-20251001',
          max_tokens: 1500,
          system: `You are a clinical AI assistant for Wylde Self,
working alongside Everwell USA clinicians.
Provide evidence-based peptide protocol outcome projections.
Always frame results as "clinical research shows" or
"users with similar profiles report" — never as guaranteed outcomes.
Always recommend clinician supervision.
Respond in valid JSON only — no markdown, no explanation outside JSON.`,
          messages: [{
            role: 'user',
            content: `Generate a personalized protocol prediction.

USER PROFILE:
${profileText}

PROTOCOL: ${protocol}

CLINICAL RESEARCH DATA:
${knowledgeText}

Return this exact JSON structure:
{
  "headline": "one compelling sentence about this protocol for this profile",
  "confidence": "High|Medium|Low",
  "profile_match": "brief note on how well this protocol suits this profile",
  "week2": {
    "focus": "what changes first",
    "metric": "specific measurable outcome"
  },
  "week4": {
    "summary": "what to expect",
    "metrics": { "energy": "+X%", "sleep": "+X pts", "recovery": "+X%" }
  },
  "week8": {
    "summary": "what to expect",
    "metrics": { "energy": "+X%", "sleep": "+X pts", "recovery": "+X%" }
  },
  "week12": {
    "summary": "peak protocol benefit",
    "metrics": { "energy": "+X%", "sleep": "+X pts", "recovery": "+X%" }
  },
  "body_composition": {
    "fat_loss": "X-Xlbs expected range",
    "lean_gain": "X-Xlbs expected range",
    "timeframe": "${cycleWeeks} weeks"
  },
  "best_for": ["3 profile types this works best for"],
  "watch_for": ["2-3 things to monitor"],
  "next_protocol": "recommended protocol after this cycle ends",
  "clinician_note": "one sentence to discuss with clinician",
  "image_prompt_addition": "specific body change description for Future Self image"
}`
          }]
        })
      }
    );

    const aiData = await response.json();
    const rawText = aiData.content?.[0]?.text || '{}';
    const prediction = JSON.parse(
      rawText.replace(/```json|```/g, '').trim()
    );

    return res.status(200).json({
      prediction,
      knowledge,
      cycle: {
        total_weeks: cycleWeeks,
        current_week: currentWeek,
        weeks_remaining: weeksRemaining,
        start_date: activeProtocol?.start_date || null,
        is_active: !!activeProtocol
      }
    });

  } catch (error) {
    console.error('Predict error:', error);
    return res.status(500).json({ error: error.message });
  }
}

export const config = { runtime: 'edge', maxDuration: 30 };
