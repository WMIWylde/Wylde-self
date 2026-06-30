-- ═══════════════════════════════════════════════════════════════
--  Drop 1: Wylde Score + Protocol Adherence + Care Messages
-- ═══════════════════════════════════════════════════════════════

-- Wylde Score — daily composite health score
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
CREATE POLICY "Users see own scores" ON wylde_scores
  FOR ALL USING (auth.uid() = user_id);
CREATE POLICY "Clinicians read patient scores" ON wylde_scores
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM care_relationships
      WHERE care_relationships.patient_id = wylde_scores.user_id
        AND care_relationships.clinician_id = auth.uid()
        AND care_relationships.status = 'active'
    )
  );

-- Protocol adherence logs — individual dose tracking
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
CREATE POLICY "Users manage own adherence" ON protocol_adherence_logs
  FOR ALL USING (auth.uid() = user_id);
CREATE POLICY "Clinicians read patient adherence" ON protocol_adherence_logs
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM care_relationships
      WHERE care_relationships.patient_id = protocol_adherence_logs.user_id
        AND care_relationships.clinician_id = auth.uid()
        AND care_relationships.status = 'active'
    )
  );

-- Care messages — clinician <> patient messaging
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
CREATE POLICY "Participants see own messages" ON care_messages
  FOR ALL USING (auth.uid() = sender_id OR auth.uid() = recipient_id);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_wylde_scores_user_date ON wylde_scores(user_id, date);
CREATE INDEX IF NOT EXISTS idx_adherence_user ON protocol_adherence_logs(user_id);
CREATE INDEX IF NOT EXISTS idx_adherence_prescription ON protocol_adherence_logs(prescription_id);
CREATE INDEX IF NOT EXISTS idx_messages_relationship ON care_messages(relationship_id, created_at);
CREATE INDEX IF NOT EXISTS idx_messages_recipient ON care_messages(recipient_id, read_at);
