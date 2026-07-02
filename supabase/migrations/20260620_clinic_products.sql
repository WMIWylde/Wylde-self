-- ═══════════════════════════════════════════════════════════════
--  Clinic Products & Marketplace
--  Peptides, supplements, medications — clinician-managed catalog
-- ═══════════════════════════════════════════════════════════════

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
  method TEXT,  -- injection, oral, topical, sublingual, etc.
  price DECIMAL(10,2),
  price_unit TEXT DEFAULT 'per unit',  -- per unit, per month, per cycle, per session
  is_in_stock BOOLEAN DEFAULT true,
  image_url TEXT,
  notes TEXT,
  sort_order INT DEFAULT 0,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE clinic_products ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Clinicians manage own products" ON clinic_products
  FOR ALL USING (auth.uid() = clinician_id);
-- Patients can view products from their linked clinician
CREATE POLICY "Patients view clinician products" ON clinic_products
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM care_relationships
      WHERE care_relationships.clinician_id = clinic_products.clinician_id
        AND care_relationships.patient_id = auth.uid()
        AND care_relationships.status = 'active'
    )
  );

-- Patient notes — clinician notes per patient
CREATE TABLE IF NOT EXISTS patient_notes (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  clinician_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  patient_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  content TEXT NOT NULL,
  note_type TEXT DEFAULT 'general' CHECK (note_type IN ('general', 'protocol', 'lab', 'follow_up')),
  created_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE patient_notes ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Clinicians manage own notes" ON patient_notes
  FOR ALL USING (auth.uid() = clinician_id);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_clinic_products_clinician ON clinic_products(clinician_id);
CREATE INDEX IF NOT EXISTS idx_patient_notes_patient ON patient_notes(patient_id, clinician_id);
