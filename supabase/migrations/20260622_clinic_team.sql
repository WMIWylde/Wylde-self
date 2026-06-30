-- ═══════════════════════════════════════════════════════════════
--  Clinic Team & Permissions + Message Templates
-- ═══════════════════════════════════════════════════════════════

-- Clinic team members
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
CREATE POLICY "Clinic owners manage team" ON clinic_team_members FOR ALL USING (auth.uid() = clinic_id);

-- Patient experience feature toggles
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
CREATE POLICY "Clinicians manage own toggles" ON clinic_feature_toggles FOR ALL USING (auth.uid() = clinic_id);

-- Message templates
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
CREATE POLICY "Clinicians manage own templates" ON clinic_message_templates FOR ALL USING (auth.uid() = clinic_id);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_team_clinic ON clinic_team_members(clinic_id);
CREATE INDEX IF NOT EXISTS idx_templates_clinic ON clinic_message_templates(clinic_id);
