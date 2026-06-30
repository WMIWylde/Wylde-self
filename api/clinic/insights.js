const { applyCors, rateLimit, clientIp } = require('../../lib/security');
const { getSupabaseAdmin, getUserFromRequest } = require('../../lib/supabase-admin');

module.exports = async function handler(req, res) {
  if (applyCors(req, res, { methods: 'GET, POST, OPTIONS' })) return;

  const user = await getUserFromRequest(req);
  if (!user) return res.status(401).json({ error: 'Unauthorized' });

  const supabase = getSupabaseAdmin();

  // GET — fetch insights for a patient
  if (req.method === 'GET') {
    const patientId = req.query.patient_id;
    if (!patientId) return res.status(400).json({ error: 'patient_id required' });

    const { data } = await supabase
      .from('clinical_insights')
      .select('*')
      .eq('clinician_id', user.id)
      .eq('patient_id', patientId)
      .order('created_at', { ascending: false })
      .limit(20);

    return res.status(200).json({ insights: data || [] });
  }

  // POST — generate insights for a patient
  if (req.method !== 'POST') return res.status(405).json({ error: 'Method not allowed' });

  // Rate limit: 5/min (AI calls are expensive)
  const rl = rateLimit({ key: 'insights', ip: clientIp(req), limit: 5, windowMs: 60000 });
  if (!rl.ok) return res.status(429).json({ error: 'Rate limit exceeded' });

  const { patient_id } = req.body || {};
  if (!patient_id) return res.status(400).json({ error: 'patient_id required' });

  // Verify care relationship
  const { data: rel } = await supabase
    .from('care_relationships')
    .select('id')
    .eq('clinician_id', user.id)
    .eq('patient_id', patient_id)
    .eq('status', 'active')
    .single();

  if (!rel) return res.status(403).json({ error: 'No active care relationship' });

  // Gather patient data
  const thirtyDaysAgo = new Date(Date.now() - 30 * 86400000).toISOString().split('T')[0];

  const [
    { data: checkins },
    { data: scores },
    { data: adherence },
    { data: protocols },
    { data: prescriptions },
    { data: profile },
  ] = await Promise.all([
    supabase.from('patient_checkins').select('*').eq('user_id', patient_id).gte('date', thirtyDaysAgo).order('date', { ascending: false }),
    supabase.from('wylde_scores').select('*').eq('user_id', patient_id).gte('date', thirtyDaysAgo).order('date', { ascending: false }),
    supabase.from('protocol_adherence_logs').select('*').eq('user_id', patient_id).gte('created_at', thirtyDaysAgo + 'T00:00:00').order('created_at', { ascending: false }),
    supabase.from('patient_protocols').select('*').eq('user_id', patient_id).eq('status', 'active'),
    supabase.from('patient_prescriptions').select('*').eq('user_id', patient_id).eq('status', 'active'),
    supabase.from('profiles').select('profile_data, email').eq('id', patient_id).single(),
  ]);

  const pd = profile?.profile_data || {};
  const patientName = pd.name || profile?.email?.split('@')[0] || 'Patient';

  // Build context for AI
  const context = buildInsightContext({
    patientName, checkins: checkins || [], scores: scores || [],
    adherence: adherence || [], protocols: protocols || [],
    prescriptions: prescriptions || [],
  });

  // Call OpenAI for insights
  try {
    const apiKey = process.env.OPENAI_API_KEY;
    if (!apiKey) throw new Error('OPENAI_API_KEY not configured');

    const response = await fetch('https://api.openai.com/v1/chat/completions', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${apiKey}` },
      body: JSON.stringify({
        model: 'gpt-4o',
        max_tokens: 800,
        messages: [
          { role: 'system', content: INSIGHT_SYSTEM_PROMPT },
          { role: 'user', content: context },
        ],
      }),
    });

    const aiData = await response.json();
    const content = aiData.choices?.[0]?.message?.content;
    if (!content) throw new Error('No AI response');

    // Parse insights array from response
    let insights = [];
    try {
      const jsonStart = content.indexOf('[');
      const jsonEnd = content.lastIndexOf(']');
      if (jsonStart >= 0 && jsonEnd > jsonStart) {
        insights = JSON.parse(content.substring(jsonStart, jsonEnd + 1));
      }
    } catch (e) {
      // If JSON parsing fails, create a single insight from the text
      insights = [{ severity: 'low', title: 'Analysis Complete', summary: content.substring(0, 500), recommended_action: 'Review patient data' }];
    }

    // Store insights in DB
    const insightRows = insights.map(i => ({
      patient_id,
      clinician_id: user.id,
      relationship_id: rel.id,
      insight_type: 'ai_generated',
      severity: i.severity || 'low',
      title: i.title || 'Insight',
      summary: i.summary || '',
      recommended_action: i.recommended_action || '',
      source: { date_range: thirtyDaysAgo + ' to today', checkin_count: (checkins || []).length, score_count: (scores || []).length },
      status: 'new',
    }));

    if (insightRows.length > 0) {
      await supabase.from('clinical_insights').insert(insightRows);
    }

    // Return fresh insights
    const { data: allInsights } = await supabase
      .from('clinical_insights')
      .select('*')
      .eq('clinician_id', user.id)
      .eq('patient_id', patient_id)
      .order('created_at', { ascending: false })
      .limit(20);

    return res.status(200).json({ insights: allInsights || [], generated: insightRows.length });

  } catch (err) {
    console.error('[insights] error:', err.message);
    return res.status(500).json({ error: err.message });
  }
};

const INSIGHT_SYSTEM_PROMPT = `You are a clinical data analyst for a health optimization platform. You analyze patient adherence, biometrics, and lifestyle data to surface actionable signals for clinicians.

RULES:
- Do NOT diagnose conditions
- Do NOT recommend specific medications or dose changes
- DO recommend: follow-up conversations, protocol reviews, adherence support, lifestyle adjustments, lab review
- Be specific — reference actual numbers from the data
- Each insight should be actionable, not just observational
- Severity: "high" = needs attention this week, "medium" = worth discussing next visit, "low" = positive trend or minor note

Return ONLY a JSON array of insights:
[
  {
    "severity": "high|medium|low",
    "title": "Short headline (5-8 words)",
    "summary": "2-3 sentences explaining the signal with specific data points.",
    "recommended_action": "One specific action the clinician should take."
  }
]

Generate 2-5 insights. Focus on the most important signals.`;

function buildInsightContext({ patientName, checkins, scores, adherence, protocols, prescriptions }) {
  let lines = [`Patient: ${patientName}`, `Data range: last 30 days`, ''];

  // Protocols
  if (protocols.length > 0) {
    lines.push('Active Protocols:');
    protocols.forEach(p => lines.push(`  - ${p.name} (${p.phase || 'active'}, started ${p.started_at?.split('T')[0]})`));
    lines.push('');
  }

  // Prescriptions
  if (prescriptions.length > 0) {
    lines.push('Active Prescriptions:');
    prescriptions.forEach(rx => lines.push(`  - ${rx.drug} ${rx.dose} ${rx.frequency}`));
    lines.push('');
  }

  // Adherence
  if (adherence.length > 0) {
    const taken = adherence.filter(a => a.status === 'taken').length;
    const skipped = adherence.filter(a => a.status === 'skipped').length;
    const withSideEffects = adherence.filter(a => a.side_effects).length;
    lines.push(`Protocol Adherence (30 days): ${taken} taken, ${skipped} skipped out of ${adherence.length} total`);
    if (withSideEffects > 0) lines.push(`  Side effects reported: ${withSideEffects} times`);
    lines.push('');
  }

  // Wylde Scores
  if (scores.length > 0) {
    const recent = scores.slice(0, 7);
    const avg = Math.round(recent.reduce((s, sc) => s + sc.total_score, 0) / recent.length);
    const trend = scores.length >= 14
      ? Math.round(scores.slice(0, 7).reduce((s, sc) => s + sc.total_score, 0) / 7) - Math.round(scores.slice(7, 14).reduce((s, sc) => s + sc.total_score, 0) / Math.min(7, scores.slice(7, 14).length))
      : null;
    lines.push(`Wylde Score: avg ${avg}/100 (last 7 days)${trend !== null ? `, trend ${trend > 0 ? '+' : ''}${trend}` : ''}`);

    // Component averages
    const compAvg = (key) => Math.round(recent.reduce((s, sc) => s + (sc[key] || 0), 0) / recent.length);
    lines.push(`  Ritual: ${compAvg('ritual_score')}/20, Movement: ${compAvg('movement_score')}/20, Nutrition: ${compAvg('nutrition_score')}/20`);
    lines.push(`  Protocol: ${compAvg('protocol_score')}/25, Recovery: ${compAvg('recovery_score')}/10, Mindset: ${compAvg('mindset_score')}/5`);
    lines.push('');
  }

  // Check-ins
  if (checkins.length > 0) {
    lines.push(`Check-ins: ${checkins.length} in last 30 days`);
    const workoutDays = checkins.filter(c => c.workout > 0).length;
    const avgMood = checkins.filter(c => c.mood != null);
    const moodAvg = avgMood.length > 0 ? (avgMood.reduce((s, c) => s + c.mood, 0) / avgMood.length).toFixed(1) : null;
    const weights = checkins.filter(c => c.weight).map(c => c.weight);
    lines.push(`  Workouts: ${workoutDays}/${checkins.length} days`);
    if (moodAvg) lines.push(`  Avg mood: ${moodAvg}/5`);
    if (weights.length >= 2) lines.push(`  Weight: ${weights[0]}lb (latest) vs ${weights[weights.length - 1]}lb (30 days ago)`);

    // Sleep/HRV if available
    const sleepScores = checkins.filter(c => c.sleep_score != null);
    if (sleepScores.length > 0) {
      const avgSleep = (sleepScores.reduce((s, c) => s + c.sleep_score, 0) / sleepScores.length).toFixed(1);
      lines.push(`  Avg sleep score: ${avgSleep}/10`);
    }
    lines.push('');
  }

  return lines.join('\n');
}
