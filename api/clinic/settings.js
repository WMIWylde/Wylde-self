const { applyCors, rateLimit, clientIp } = require('../../lib/security');
const { getSupabaseAdmin, getUserFromRequest } = require('../../lib/supabase-admin');

module.exports = async function handler(req, res) {
  if (applyCors(req, res, { methods: 'GET, PUT, OPTIONS' })) return;

  const user = await getUserFromRequest(req);
  if (!user) return res.status(401).json({ error: 'Unauthorized' });

  // Rate limit: 20/min
  const rl = rateLimit({ key: 'clinic-settings', ip: clientIp(req), limit: 20, windowMs: 60000 });
  if (!rl.ok) return res.status(429).json({ error: 'Rate limit exceeded' });

  const supabase = getSupabaseAdmin();

  // GET — fetch clinic settings (auto-creates on first access)
  if (req.method === 'GET') {
    let { data } = await supabase
      .from('clinic_settings')
      .select('*')
      .eq('clinician_id', user.id)
      .single();

    // Auto-create if doesn't exist (new clinician onboarding).
    // New clinics start 'pending' and must be approved before gaining access.
    if (!data) {
      const { data: newSettings } = await supabase
        .from('clinic_settings')
        .insert({ clinician_id: user.id, status: 'pending' })
        .select()
        .single();
      data = newSettings;
    }

    return res.status(200).json({ settings: data });
  }

  // PUT — update clinic settings (requires existing approved clinic)
  if (req.method === 'PUT') {
    // For PUT, verify they have an approved clinic
    const { data: existing } = await supabase
      .from('clinic_settings')
      .select('status')
      .eq('clinician_id', user.id)
      .single();

    if (!existing || existing.status === 'suspended') {
      return res.status(403).json({ error: 'Not an approved clinician' });
    }

    const body = req.body || {};

    // Only allow updating specific fields
    const allowed = [
      'clinic_name', 'clinic_type', 'description', 'specialties', 'website', 'phone', 'email',
      'address_line1', 'address_line2', 'city', 'state', 'zip', 'country',
      'medical_license_number', 'license_state', 'license_expiry', 'npi_number', 'dea_number',
      'liability_insurance_carrier', 'liability_insurance_policy',
      'compliance_hipaa_acknowledged', 'compliance_terms_accepted', 'compliance_accepted_at',
      'logo_url', 'brand_color_primary', 'brand_color_secondary', 'tagline', 'patient_welcome_message',
      'notification_prefs', 'onboarding_step', 'onboarding_complete',
    ];

    const updates = { updated_at: new Date().toISOString() };
    for (const key of allowed) {
      if (body[key] !== undefined) updates[key] = body[key];
    }

    const { data, error } = await supabase
      .from('clinic_settings')
      .upsert({ clinician_id: user.id, ...updates }, { onConflict: 'clinician_id' })
      .select()
      .single();

    if (error) return res.status(500).json({ error: error.message });
    return res.status(200).json({ settings: data });
  }

  return res.status(405).json({ error: 'Method not allowed' });
};
