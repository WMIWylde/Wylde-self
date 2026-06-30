-- ═══════════════════════════════════════════════════════════════
--  Clinic Onboarding — full registration profile
-- ═══════════════════════════════════════════════════════════════

-- Drop and recreate clinic_settings if it exists with different schema
CREATE TABLE IF NOT EXISTS clinic_settings (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  clinician_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE UNIQUE,

  -- Basic info
  clinic_name TEXT,
  clinic_type TEXT, -- medspa, functional_medicine, hrt_clinic, wellness_center, etc.
  description TEXT,
  specialties TEXT[] DEFAULT '{}',
  website TEXT,
  phone TEXT,
  email TEXT,

  -- Address
  address_line1 TEXT,
  address_line2 TEXT,
  city TEXT,
  state TEXT,
  zip TEXT,
  country TEXT DEFAULT 'US',

  -- Licensing & compliance
  medical_license_number TEXT,
  license_state TEXT,
  license_expiry DATE,
  npi_number TEXT,
  dea_number TEXT,
  liability_insurance_carrier TEXT,
  liability_insurance_policy TEXT,
  compliance_hipaa_acknowledged BOOLEAN DEFAULT false,
  compliance_terms_accepted BOOLEAN DEFAULT false,
  compliance_accepted_at TIMESTAMPTZ,

  -- Branding
  logo_url TEXT,
  brand_color_primary TEXT DEFAULT '#6E8A7C',
  brand_color_secondary TEXT DEFAULT '#C8A96E',
  tagline TEXT,
  patient_welcome_message TEXT,

  -- Platform
  stripe_account_id TEXT,
  platform_fee_percent NUMERIC DEFAULT 10,
  onboarding_complete BOOLEAN DEFAULT false,
  onboarding_step INT DEFAULT 0,
  approved BOOLEAN DEFAULT false,
  approved_at TIMESTAMPTZ,
  approved_by UUID,

  -- Notification prefs
  notification_prefs JSONB DEFAULT '{"email_new_patient": true, "email_checkin": false, "email_reorder": true}'::jsonb,

  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE clinic_settings ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Clinicians manage own settings" ON clinic_settings;
CREATE POLICY "Clinicians manage own settings" ON clinic_settings FOR ALL USING (auth.uid() = clinician_id);
-- Patients can read linked clinic's public info
DROP POLICY IF EXISTS "Patients read linked clinic" ON clinic_settings;
CREATE POLICY "Patients read linked clinic" ON clinic_settings FOR SELECT USING (
  EXISTS (
    SELECT 1 FROM care_relationships
    WHERE care_relationships.clinician_id = clinic_settings.clinician_id
      AND care_relationships.patient_id = auth.uid()
      AND care_relationships.status = 'active'
  )
);
