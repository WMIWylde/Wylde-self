const { applyCors } = require('../../lib/security');
const { getSupabaseAdmin, getUserFromRequest } = require('../../lib/supabase-admin');

module.exports = async function handler(req, res) {
  if (applyCors(req, res, { methods: 'GET, OPTIONS' })) return;

  const user = await getUserFromRequest(req);
  if (!user) return res.status(401).json({ error: 'Unauthorized' });

  const supabase = getSupabaseAdmin();

  if (req.method !== 'GET') {
    return res.status(405).json({ error: 'Method not allowed' });
  }

  try {
    // 1. Fetch clinic settings
    const { data: clinicSettings } = await supabase
      .from('clinic_settings')
      .select('*')
      .eq('clinician_id', user.id)
      .single();

    // 2. Fetch all active care relationships with patient profiles
    const { data: relationships } = await supabase
      .from('care_relationships')
      .select('id, patient_id, clinician_id, clinic_name, linked_at')
      .eq('clinician_id', user.id)
      .eq('status', 'active');

    const rels = relationships || [];
    const patientIds = rels.map(r => r.patient_id);

    if (patientIds.length === 0) {
      return res.status(200).json({
        clinic_settings: clinicSettings,
        patients: [],
      });
    }

    // 3. Batch fetch all patient data in parallel
    const today = new Date().toISOString().split('T')[0];
    const fourteenAgo = new Date(Date.now() - 14 * 86400000).toISOString();

    const [
      profilesResult,
      checkinsResult,
      protocolsResult,
      prescriptionsResult,
      unreadResult,
      scoresResult,
      adherenceLogsResult,
    ] = await Promise.all([
      // Profiles
      supabase
        .from('profiles')
        .select('id, email, profile_data')
        .in('id', patientIds),

      // Recent check-ins (last 30 per patient, get more and slice client-side)
      supabase
        .from('patient_checkins')
        .select('*')
        .in('user_id', patientIds)
        .order('date', { ascending: false })
        .limit(patientIds.length * 30),

      // Active protocols
      supabase
        .from('patient_protocols')
        .select('*')
        .in('user_id', patientIds)
        .eq('status', 'active'),

      // Active prescriptions
      supabase
        .from('patient_prescriptions')
        .select('*')
        .in('user_id', patientIds)
        .eq('status', 'active'),

      // Unread messages for this clinician, grouped by relationship
      supabase
        .from('care_messages')
        .select('id, relationship_id')
        .eq('recipient_id', user.id)
        .is('read_at', null),

      // Today's wylde scores
      supabase
        .from('wylde_scores')
        .select('*')
        .in('user_id', patientIds)
        .eq('date', today),

      // Adherence logs (last 14 days)
      supabase
        .from('protocol_adherence_logs')
        .select('*')
        .in('user_id', patientIds)
        .gte('created_at', fourteenAgo)
        .order('created_at', { ascending: false }),
    ]);

    // Index data by patient_id for efficient lookup
    const profilesMap = {};
    for (const p of (profilesResult.data || [])) {
      profilesMap[p.id] = p;
    }

    const checkinsMap = {};
    for (const c of (checkinsResult.data || [])) {
      if (!checkinsMap[c.user_id]) checkinsMap[c.user_id] = [];
      if (checkinsMap[c.user_id].length < 30) {
        checkinsMap[c.user_id].push(c);
      }
    }

    const protocolsMap = {};
    for (const p of (protocolsResult.data || [])) {
      if (!protocolsMap[p.user_id]) protocolsMap[p.user_id] = [];
      protocolsMap[p.user_id].push(p);
    }

    const prescriptionsMap = {};
    for (const rx of (prescriptionsResult.data || [])) {
      if (!prescriptionsMap[rx.user_id]) prescriptionsMap[rx.user_id] = [];
      prescriptionsMap[rx.user_id].push(rx);
    }

    // Count unread per relationship_id
    const unreadByRelId = {};
    for (const msg of (unreadResult.data || [])) {
      unreadByRelId[msg.relationship_id] = (unreadByRelId[msg.relationship_id] || 0) + 1;
    }

    const scoresMap = {};
    for (const s of (scoresResult.data || [])) {
      scoresMap[s.user_id] = s;
    }

    const adherenceMap = {};
    for (const l of (adherenceLogsResult.data || [])) {
      if (!adherenceMap[l.user_id]) adherenceMap[l.user_id] = [];
      adherenceMap[l.user_id].push(l);
    }

    // 4. Assemble patient objects
    const patients = rels.map(rel => {
      const profile = profilesMap[rel.patient_id];
      const pd = profile?.profile_data || {};
      const checkins = checkinsMap[rel.patient_id] || [];
      const protocols = protocolsMap[rel.patient_id] || [];
      const prescriptions = prescriptionsMap[rel.patient_id] || [];
      const wyldeScore = scoresMap[rel.patient_id] || null;
      const adherenceLogs = adherenceMap[rel.patient_id] || [];
      const unreadMessages = unreadByRelId[rel.id] || 0;

      const last7 = checkins.slice(0, 7);
      const adherence = last7.length > 0
        ? Math.round(last7.reduce((s, c) => s + (c.doses > 0 ? 1 : 0), 0) / last7.length * 100)
        : null;

      return {
        id: rel.patient_id,
        relationshipId: rel.id,
        name: pd.name || profile?.email?.split('@')[0] || 'Patient',
        email: profile?.email || '',
        linkedAt: rel.linked_at,
        adherence,
        todayCheckin: checkins.find(c => c.date === today) || null,
        checkins,
        protocols,
        prescriptions,
        wyldeScore,
        adherenceLogs,
        unreadMessages,
      };
    });

    return res.status(200).json({
      clinic_settings: clinicSettings,
      patients,
    });
  } catch (err) {
    console.error('Dashboard API error:', err);
    return res.status(500).json({ error: 'Internal server error' });
  }
};
