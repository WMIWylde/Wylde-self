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
CREATE POLICY "Clinicians manage own insights" ON clinical_insights
  FOR ALL USING (auth.uid() = clinician_id);

CREATE INDEX IF NOT EXISTS idx_insights_clinician_patient ON clinical_insights(clinician_id, patient_id);
