-- Run this entire file in Supabase SQL Editor
-- All clinic tables, RLS policies, and indexes

-- 1. Care invite codes
CREATE TABLE IF NOT EXISTS care_invite_codes (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  code TEXT NOT NULL UNIQUE,
  message TEXT,
  access_level TEXT DEFAULT 'full',
  status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'accepted', 'expired', 'revoked')),
  accepted_by UUID REFERENCES auth.users(id),
  expires_at TIMESTAMPTZ NOT NULL,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);
ALTER TABLE care_invite_codes ENABLE ROW LEVEL SECURITY;
DO $$ BEGIN
  CREATE POLICY "Users see own invites" ON care_invite_codes FOR ALL USING (auth.uid() = user_id OR auth.uid() = accepted_by);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- 2. Care relationships
CREATE TABLE IF NOT EXISTS care_relationships (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  patient_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  clinician_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  clinic_name TEXT,
  status TEXT DEFAULT 'active' CHECK (status IN ('active', 'paused', 'revoked')),
  linked_at TIMESTAMPTZ DEFAULT now(),
  revoked_at TIMESTAMPTZ,
  UNIQUE(patient_id, clinician_id)
);
ALTER TABLE care_relationships ENABLE ROW LEVEL SECURITY;
DO $$ BEGIN
  CREATE POLICY "Participants see relationship" ON care_relationships FOR ALL USING (auth.uid() = patient_id OR auth.uid() = clinician_id);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- 3. Patient checkins
CREATE TABLE IF NOT EXISTS patient_checkins (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  date DATE NOT NULL DEFAULT CURRENT_DATE,
  doses INT DEFAULT 0,
  daily_checkin INT DEFAULT 0,
  workout INT DEFAULT 0,
  nutrition INT DEFAULT 0,
  weight DOUBLE PRECISION,
  sleep_score INT,
  hrv INT,
  rhr INT,
  mood INT,
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(user_id, date)
);
ALTER TABLE patient_checkins ENABLE ROW LEVEL SECURITY;
DO $$ BEGIN
  CREATE POLICY "Users see own checkins" ON patient_checkins FOR SELECT USING (auth.uid() = user_id);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;
DO $$ BEGIN
  CREATE POLICY "Users insert own checkins" ON patient_checkins FOR INSERT WITH CHECK (auth.uid() = user_id);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;
DO $$ BEGIN
  CREATE POLICY "Users update own checkins" ON patient_checkins FOR UPDATE USING (auth.uid() = user_id);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;
DO $$ BEGIN
  CREATE POLICY "Clinicians read patient checkins" ON patient_checkins FOR SELECT USING (
    EXISTS (SELECT 1 FROM care_relationships WHERE care_relationships.patient_id = patient_checkins.user_id AND care_relationships.clinician_id = auth.uid() AND care_relationships.status = 'active')
  );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- 4. Patient protocols
CREATE TABLE IF NOT EXISTS patient_protocols (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  phase TEXT,
  status TEXT DEFAULT 'active' CHECK (status IN ('active', 'paused', 'completed')),
  assigned_by UUID REFERENCES auth.users(id),
  started_at TIMESTAMPTZ DEFAULT now(),
  ended_at TIMESTAMPTZ,
  config JSONB DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);
ALTER TABLE patient_protocols ENABLE ROW LEVEL SECURITY;
DO $$ BEGIN
  CREATE POLICY "Users see own protocols" ON patient_protocols FOR ALL USING (auth.uid() = user_id OR auth.uid() = assigned_by);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- 5. Patient prescriptions
CREATE TABLE IF NOT EXISTS patient_prescriptions (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  protocol_id UUID NOT NULL REFERENCES patient_protocols(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  drug TEXT NOT NULL,
  dose TEXT NOT NULL,
  frequency TEXT NOT NULL,
  timing TEXT,
  method TEXT,
  status TEXT DEFAULT 'active' CHECK (status IN ('active', 'paused', 'discontinued')),
  last_filled_at TIMESTAMPTZ,
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT now()
);
ALTER TABLE patient_prescriptions ENABLE ROW LEVEL SECURITY;
DO $$ BEGIN
  CREATE POLICY "Users see own prescriptions" ON patient_prescriptions FOR ALL USING (auth.uid() = user_id);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;
DO $$ BEGIN
  CREATE POLICY "Clinicians see patient prescriptions" ON patient_prescriptions FOR SELECT USING (
    EXISTS (SELECT 1 FROM care_relationships WHERE care_relationships.patient_id = patient_prescriptions.user_id AND care_relationships.clinician_id = auth.uid() AND care_relationships.status = 'active')
  );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- 6. Clinic products
CREATE TABLE IF NOT EXISTS clinic_products (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  clinician_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  category TEXT NOT NULL CHECK (category IN ('peptide', 'supplement', 'medication', 'service', 'lab_test')),
  description TEXT,
  mechanism TEXT,
  benefits JSONB DEFAULT '[]'::jsonb,
  contraindications JSONB DEFAULT '[]'::jsonb,
  typical_dose TEXT,
  cycle_length TEXT,
  frequency TEXT,
  method TEXT,
  price DECIMAL(10,2),
  price_unit TEXT DEFAULT 'per unit',
  available BOOLEAN DEFAULT true,
  image_url TEXT,
  notes TEXT,
  sort_order INT DEFAULT 0,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);
ALTER TABLE clinic_products ENABLE ROW LEVEL SECURITY;
DO $$ BEGIN
  CREATE POLICY "Clinicians manage own products" ON clinic_products FOR ALL USING (auth.uid() = clinician_id);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;
DO $$ BEGIN
  CREATE POLICY "Patients view clinician products" ON clinic_products FOR SELECT USING (
    EXISTS (SELECT 1 FROM care_relationships WHERE care_relationships.clinician_id = clinic_products.clinician_id AND care_relationships.patient_id = auth.uid() AND care_relationships.status = 'active')
  );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- 7. Patient notes
CREATE TABLE IF NOT EXISTS patient_notes (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  clinician_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  patient_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  content TEXT NOT NULL,
  note_type TEXT DEFAULT 'general' CHECK (note_type IN ('general', 'protocol', 'lab', 'follow_up')),
  created_at TIMESTAMPTZ DEFAULT now()
);
ALTER TABLE patient_notes ENABLE ROW LEVEL SECURITY;
DO $$ BEGIN
  CREATE POLICY "Clinicians manage own notes" ON patient_notes FOR ALL USING (auth.uid() = clinician_id);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- 8. Clinical insights
CREATE TABLE IF NOT EXISTS clinical_insights (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  patient_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  clinician_id UUID NOT NULL REFERENCES auth.users(id),
  relationship_id UUID REFERENCES care_relationships(id),
  insight_type TEXT DEFAULT 'ai_generated',
  severity TEXT CHECK (severity IN ('low', 'medium', 'high')) DEFAULT 'low',
  title TEXT NOT NULL,
  summary TEXT,
  recommended_action TEXT,
  source JSONB,
  status TEXT CHECK (status IN ('new', 'reviewed', 'dismissed', 'acted_on')) DEFAULT 'new',
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);
ALTER TABLE clinical_insights ENABLE ROW LEVEL SECURITY;
DO $$ BEGIN
  CREATE POLICY "Clinicians manage own insights" ON clinical_insights FOR ALL USING (auth.uid() = clinician_id);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- 9. Reorder requests
CREATE TABLE IF NOT EXISTS reorder_requests (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  patient_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  clinician_id UUID NOT NULL REFERENCES auth.users(id),
  clinic_product_id UUID NOT NULL REFERENCES clinic_products(id),
  prescription_id UUID REFERENCES patient_prescriptions(id),
  status TEXT DEFAULT 'requested' CHECK (status IN ('requested', 'approved', 'rejected', 'fulfilled', 'cancelled')),
  quantity INT DEFAULT 1,
  patient_note TEXT,
  clinician_note TEXT,
  stripe_checkout_session_id TEXT,
  amount_cents INT,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);
ALTER TABLE reorder_requests ENABLE ROW LEVEL SECURITY;
DO $$ BEGIN
  CREATE POLICY "Patients see own orders" ON reorder_requests FOR ALL USING (auth.uid() = patient_id);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;
DO $$ BEGIN
  CREATE POLICY "Clinicians manage patient orders" ON reorder_requests FOR ALL USING (auth.uid() = clinician_id);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- 10. Wylde scores
CREATE TABLE IF NOT EXISTS wylde_scores (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  date DATE NOT NULL DEFAULT CURRENT_DATE,
  total_score INT NOT NULL DEFAULT 0,
  ritual_score INT DEFAULT 0,
  movement_score INT DEFAULT 0,
  nutrition_score INT DEFAULT 0,
  protocol_score INT DEFAULT 0,
  recovery_score INT DEFAULT 0,
  mindset_score INT DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(user_id, date)
);
ALTER TABLE wylde_scores ENABLE ROW LEVEL SECURITY;
DO $$ BEGIN
  CREATE POLICY "Users see own scores" ON wylde_scores FOR ALL USING (auth.uid() = user_id);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;
DO $$ BEGIN
  CREATE POLICY "Clinicians read patient scores" ON wylde_scores FOR SELECT USING (
    EXISTS (SELECT 1 FROM care_relationships WHERE care_relationships.patient_id = wylde_scores.user_id AND care_relationships.clinician_id = auth.uid() AND care_relationships.status = 'active')
  );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- 11. Protocol adherence logs
CREATE TABLE IF NOT EXISTS protocol_adherence_logs (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  prescription_id UUID REFERENCES patient_prescriptions(id) ON DELETE SET NULL,
  protocol_id UUID REFERENCES patient_protocols(id) ON DELETE SET NULL,
  scheduled_for TIMESTAMPTZ,
  taken_at TIMESTAMPTZ,
  status TEXT NOT NULL DEFAULT 'scheduled' CHECK (status IN ('scheduled', 'taken', 'skipped', 'missed')),
  dose TEXT,
  notes TEXT,
  side_effects JSONB,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);
ALTER TABLE protocol_adherence_logs ENABLE ROW LEVEL SECURITY;
DO $$ BEGIN
  CREATE POLICY "Users manage own adherence" ON protocol_adherence_logs FOR ALL USING (auth.uid() = user_id);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;
DO $$ BEGIN
  CREATE POLICY "Clinicians read patient adherence" ON protocol_adherence_logs FOR SELECT USING (
    EXISTS (SELECT 1 FROM care_relationships WHERE care_relationships.patient_id = protocol_adherence_logs.user_id AND care_relationships.clinician_id = auth.uid() AND care_relationships.status = 'active')
  );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- 12. Care messages
CREATE TABLE IF NOT EXISTS care_messages (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  relationship_id UUID NOT NULL REFERENCES care_relationships(id) ON DELETE CASCADE,
  sender_id UUID NOT NULL REFERENCES auth.users(id),
  recipient_id UUID NOT NULL REFERENCES auth.users(id),
  body TEXT NOT NULL,
  message_type TEXT DEFAULT 'general',
  read_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT now()
);
ALTER TABLE care_messages ENABLE ROW LEVEL SECURITY;
DO $$ BEGIN
  CREATE POLICY "Participants see own messages" ON care_messages FOR ALL USING (auth.uid() = sender_id OR auth.uid() = recipient_id);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- 13. Clinic settings
CREATE TABLE IF NOT EXISTS clinic_settings (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  clinician_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE UNIQUE,
  clinic_name TEXT,
  clinic_type TEXT,
  description TEXT,
  specialties TEXT[] DEFAULT '{}',
  website TEXT,
  phone TEXT,
  email TEXT,
  address_line1 TEXT,
  address_line2 TEXT,
  city TEXT,
  state TEXT,
  zip TEXT,
  country TEXT DEFAULT 'US',
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
  logo_url TEXT,
  brand_color_primary TEXT DEFAULT '#6E8A7C',
  brand_color_secondary TEXT DEFAULT '#C8A96E',
  tagline TEXT,
  patient_welcome_message TEXT,
  stripe_account_id TEXT,
  platform_fee_percent NUMERIC DEFAULT 10,
  onboarding_complete BOOLEAN DEFAULT false,
  onboarding_step INT DEFAULT 0,
  approved BOOLEAN DEFAULT false,
  approved_at TIMESTAMPTZ,
  approved_by UUID,
  notification_prefs JSONB DEFAULT '{"email_new_patient": true, "email_checkin": false, "email_reorder": true}'::jsonb,
  status TEXT NOT NULL DEFAULT 'approved',
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);
ALTER TABLE clinic_settings ENABLE ROW LEVEL SECURITY;
DO $$ BEGIN
  DROP POLICY IF EXISTS "Clinicians manage own settings" ON clinic_settings;
EXCEPTION WHEN undefined_object THEN NULL;
END $$;
CREATE POLICY "Clinicians manage own settings" ON clinic_settings FOR ALL USING (auth.uid() = clinician_id);
DO $$ BEGIN
  CREATE POLICY "Patients read linked clinic" ON clinic_settings FOR SELECT USING (
    EXISTS (SELECT 1 FROM care_relationships WHERE care_relationships.clinician_id = clinic_settings.clinician_id AND care_relationships.patient_id = auth.uid() AND care_relationships.status = 'active')
  );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- 14. Clinic team members
CREATE TABLE IF NOT EXISTS clinic_team_members (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  clinic_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  user_id UUID REFERENCES auth.users(id),
  email TEXT NOT NULL,
  name TEXT,
  role TEXT DEFAULT 'staff' CHECK (role IN ('owner','admin','physician','nurse_practitioner','nurse','health_coach','trainer','nutrition_coach','front_desk','billing','staff')),
  status TEXT DEFAULT 'invited' CHECK (status IN ('invited','active','disabled')),
  permissions JSONB DEFAULT '{"patients":true,"protocols":true,"products":true,"messaging":true,"billing":false,"settings":false,"ai_tools":true}'::jsonb,
  invited_at TIMESTAMPTZ DEFAULT now(),
  accepted_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT now()
);
ALTER TABLE clinic_team_members ENABLE ROW LEVEL SECURITY;
DO $$ BEGIN
  CREATE POLICY "Clinic owners manage team" ON clinic_team_members FOR ALL USING (auth.uid() = clinic_id);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- 15. Feature toggles
CREATE TABLE IF NOT EXISTS clinic_feature_toggles (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  clinic_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE UNIQUE,
  future_self BOOLEAN DEFAULT true,
  vision_board BOOLEAN DEFAULT true,
  ai_coach BOOLEAN DEFAULT true,
  workouts BOOLEAN DEFAULT true,
  nutrition BOOLEAN DEFAULT true,
  meal_tracking BOOLEAN DEFAULT true,
  habits BOOLEAN DEFAULT true,
  journaling BOOLEAN DEFAULT true,
  meditation BOOLEAN DEFAULT true,
  messaging BOOLEAN DEFAULT true,
  protocol_tracking BOOLEAN DEFAULT true,
  wylde_score BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);
ALTER TABLE clinic_feature_toggles ENABLE ROW LEVEL SECURITY;
DO $$ BEGIN
  CREATE POLICY "Clinicians manage own toggles" ON clinic_feature_toggles FOR ALL USING (auth.uid() = clinic_id);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- 16. Message templates
CREATE TABLE IF NOT EXISTS clinic_message_templates (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  clinic_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  category TEXT DEFAULT 'general' CHECK (category IN ('general','welcome','protocol','lab_results','refill','missed_checkin','follow_up')),
  body TEXT NOT NULL,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT now()
);
ALTER TABLE clinic_message_templates ENABLE ROW LEVEL SECURITY;
DO $$ BEGIN
  CREATE POLICY "Clinicians manage own templates" ON clinic_message_templates FOR ALL USING (auth.uid() = clinic_id);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- 17. Audit logs
CREATE TABLE IF NOT EXISTS audit_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  clinician_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  action TEXT NOT NULL,
  target_type TEXT,
  target_id TEXT,
  details JSONB DEFAULT '{}',
  ip_address TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
ALTER TABLE audit_logs ENABLE ROW LEVEL SECURITY;
DO $$ BEGIN
  CREATE POLICY "audit_logs_select_own" ON audit_logs FOR SELECT USING (auth.uid() = clinician_id);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;
DO $$ BEGIN
  CREATE POLICY "audit_logs_insert_service" ON audit_logs FOR INSERT WITH CHECK (true);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- 18. All indexes
CREATE INDEX IF NOT EXISTS idx_checkins_user_date ON patient_checkins(user_id, date);
CREATE INDEX IF NOT EXISTS idx_care_rel_patient ON care_relationships(patient_id);
CREATE INDEX IF NOT EXISTS idx_care_rel_clinician ON care_relationships(clinician_id);
CREATE INDEX IF NOT EXISTS idx_invite_code ON care_invite_codes(code);
CREATE INDEX IF NOT EXISTS idx_protocols_user ON patient_protocols(user_id);
CREATE INDEX IF NOT EXISTS idx_clinic_products_clinician ON clinic_products(clinician_id);
CREATE INDEX IF NOT EXISTS idx_patient_notes_patient ON patient_notes(patient_id, clinician_id);
CREATE INDEX IF NOT EXISTS idx_insights_clinician_patient ON clinical_insights(clinician_id, patient_id);
CREATE INDEX IF NOT EXISTS idx_reorders_patient ON reorder_requests(patient_id);
CREATE INDEX IF NOT EXISTS idx_reorders_clinician ON reorder_requests(clinician_id);
CREATE INDEX IF NOT EXISTS idx_wylde_scores_user_date ON wylde_scores(user_id, date);
CREATE INDEX IF NOT EXISTS idx_adherence_user ON protocol_adherence_logs(user_id);
CREATE INDEX IF NOT EXISTS idx_adherence_prescription ON protocol_adherence_logs(prescription_id);
CREATE INDEX IF NOT EXISTS idx_messages_relationship ON care_messages(relationship_id, created_at);
CREATE INDEX IF NOT EXISTS idx_messages_recipient ON care_messages(recipient_id, read_at);
CREATE INDEX IF NOT EXISTS idx_team_clinic ON clinic_team_members(clinic_id);
CREATE INDEX IF NOT EXISTS idx_templates_clinic ON clinic_message_templates(clinic_id);
CREATE INDEX IF NOT EXISTS idx_audit_logs_clinician_created ON audit_logs(clinician_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_audit_logs_action ON audit_logs(action);
