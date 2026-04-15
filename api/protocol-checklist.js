import { createClient } from '@supabase/supabase-js';

const supabase = createClient(
  process.env.SUPABASE_URL,
  process.env.SUPABASE_SERVICE_KEY
);

export default async function handler(req, res) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');

  if (req.method === 'OPTIONS') return res.status(200).end();

  const { method } = req;
  const { userId } = req.body || req.query;

  try {
    if (method === 'GET') {
      const { data: protocols } = await supabase
        .from('peptide_protocols')
        .select('*')
        .eq('user_id', userId)
        .eq('status', 'active')
        .order('created_at', { ascending: true });

      const today = new Date();
      today.setHours(0, 0, 0, 0);
      const tomorrow = new Date(today);
      tomorrow.setDate(tomorrow.getDate() + 1);

      const { data: todayDoses } = await supabase
        .from('protocol_doses')
        .select('*')
        .eq('user_id', userId)
        .gte('logged_at', today.toISOString())
        .lt('logged_at', tomorrow.toISOString());

      return res.status(200).json({
        protocols: protocols || [],
        todayDoses: todayDoses || []
      });
    }

    if (method === 'POST') {
      const { action, protocolId, skipped, notes } = req.body;

      if (action === 'log_dose') {
        const { data } = await supabase
          .from('protocol_doses')
          .insert({
            protocol_id: protocolId,
            user_id: userId,
            taken_at: skipped ? null : new Date(),
            skipped: skipped || false,
            notes: notes || null,
            logged_at: new Date()
          })
          .select()
          .single();

        return res.status(200).json({ dose: data });
      }

      if (action === 'start_protocol') {
        const {
          peptideName, dose, frequency,
          timing, method: doseMethod, cycleWeeks
        } = req.body;

        const startDate = new Date();
        const endDate = new Date();
        endDate.setDate(endDate.getDate() + (cycleWeeks * 7));

        const { data } = await supabase
          .from('peptide_protocols')
          .insert({
            user_id: userId,
            peptide_name: peptideName,
            dose: dose,
            frequency: frequency,
            timing: timing,
            method: doseMethod,
            cycle_weeks: cycleWeeks,
            start_date: startDate.toISOString(),
            end_date: endDate.toISOString(),
            status: 'active'
          })
          .select()
          .single();

        return res.status(200).json({ protocol: data });
      }

      if (action === 'log_weekly') {
        const {
          protocolId: pid, weekNumber,
          energyLevel, sleepQuality, recoveryScore,
          moodScore, painLevel, bodyWeight, notes: wNotes
        } = req.body;

        const { data } = await supabase
          .from('protocol_logs')
          .insert({
            user_id: userId,
            protocol_id: pid,
            week_number: weekNumber,
            energy_level: energyLevel,
            sleep_quality: sleepQuality,
            recovery_score: recoveryScore,
            mood_score: moodScore,
            pain_level: painLevel,
            body_weight: bodyWeight,
            notes: wNotes
          })
          .select()
          .single();

        return res.status(200).json({ log: data });
      }
    }

    return res.status(405).json({ error: 'Method not allowed' });

  } catch (error) {
    console.error('Checklist error:', error);
    return res.status(500).json({ error: error.message });
  }
}

export const config = { maxDuration: 15 };
