-- Reorder requests — patient orders from clinic product catalog
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
CREATE POLICY "Patients see own orders" ON reorder_requests
  FOR ALL USING (auth.uid() = patient_id);
CREATE POLICY "Clinicians manage patient orders" ON reorder_requests
  FOR ALL USING (auth.uid() = clinician_id);

CREATE INDEX IF NOT EXISTS idx_reorders_patient ON reorder_requests(patient_id);
CREATE INDEX IF NOT EXISTS idx_reorders_clinician ON reorder_requests(clinician_id);
