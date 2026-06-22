-- ═══════════════════════════════════════════════════════════════
--  Therapy & Protocol Library
--  Clinical-grade research database for peptides, HRT, wellness
-- ═══════════════════════════════════════════════════════════════

-- Master therapy table
CREATE TABLE IF NOT EXISTS therapies (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  slug TEXT UNIQUE NOT NULL,
  name TEXT NOT NULL,
  therapy_type TEXT NOT NULL CHECK (therapy_type IN ('peptide','hormone','medication','supplement','lifestyle','lab_test')),
  category TEXT CHECK (category IN ('recovery','metabolic','longevity','sexual_health','inflammation','cognitive','sleep','hair','hormone_optimization','immune')),
  short_description TEXT,
  consumer_summary TEXT,
  clinical_summary TEXT,
  mechanism_plain_english TEXT,
  mechanism_clinical TEXT,
  common_uses TEXT[] DEFAULT '{}',
  potential_benefits TEXT[] DEFAULT '{}',
  potential_risks TEXT[] DEFAULT '{}',
  common_side_effects TEXT[] DEFAULT '{}',
  contraindications TEXT[] DEFAULT '{}',
  administration_routes TEXT[] DEFAULT '{}',
  typical_duration TEXT,
  typical_dosing_educational TEXT,
  fda_status TEXT,
  prescription_required BOOLEAN DEFAULT true,
  evidence_rating TEXT CHECK (evidence_rating IN ('A','B','C','D','X')),
  evidence_summary TEXT,
  safety_disclaimer TEXT DEFAULT 'This information is for education only and is not medical advice. Protocols, dosing, and suitability should be determined by a qualified medical provider.',
  is_public BOOLEAN DEFAULT true,
  requires_provider_review BOOLEAN DEFAULT true,
  review_status TEXT DEFAULT 'approved' CHECK (review_status IN ('draft','needs_review','approved','archived')),
  last_reviewed_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE therapies ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Public therapies readable by all" ON therapies FOR SELECT USING (is_public = true);

-- References / citations
CREATE TABLE IF NOT EXISTS therapy_references (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  therapy_id UUID NOT NULL REFERENCES therapies(id) ON DELETE CASCADE,
  title TEXT,
  authors TEXT,
  source_name TEXT,
  source_type TEXT CHECK (source_type IN ('clinical_trial','review','meta_analysis','fda_label','guideline','animal_study','observational','article')),
  url TEXT,
  publication_year INT,
  summary TEXT,
  relevance_notes TEXT,
  evidence_weight TEXT CHECK (evidence_weight IN ('high','medium','low')),
  created_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE therapy_references ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Public references readable" ON therapy_references FOR SELECT USING (true);

-- Protocol templates
CREATE TABLE IF NOT EXISTS therapy_protocols (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  slug TEXT UNIQUE NOT NULL,
  name TEXT NOT NULL,
  category TEXT,
  goal TEXT,
  consumer_description TEXT,
  clinical_description TEXT,
  typical_duration TEXT,
  ideal_candidate TEXT,
  not_appropriate_for TEXT,
  expected_outcomes TEXT[] DEFAULT '{}',
  lifestyle_requirements TEXT[] DEFAULT '{}',
  lab_markers_to_consider TEXT[] DEFAULT '{}',
  evidence_rating TEXT CHECK (evidence_rating IN ('A','B','C','D','X')),
  is_public BOOLEAN DEFAULT true,
  requires_provider_review BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE therapy_protocols ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Public protocols readable" ON therapy_protocols FOR SELECT USING (is_public = true);

-- Protocol components (links therapies to protocols)
CREATE TABLE IF NOT EXISTS protocol_components (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  protocol_id UUID NOT NULL REFERENCES therapy_protocols(id) ON DELETE CASCADE,
  therapy_id UUID REFERENCES therapies(id) ON DELETE SET NULL,
  component_name TEXT NOT NULL,
  role_in_protocol TEXT,
  timing_notes TEXT,
  optional BOOLEAN DEFAULT false,
  display_order INT DEFAULT 0
);

ALTER TABLE protocol_components ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Public components readable" ON protocol_components FOR SELECT USING (true);

-- Conditions / goals
CREATE TABLE IF NOT EXISTS therapy_conditions (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  slug TEXT UNIQUE NOT NULL,
  name TEXT NOT NULL,
  description TEXT,
  category TEXT
);

ALTER TABLE therapy_conditions ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Conditions readable" ON therapy_conditions FOR SELECT USING (true);

-- Therapy-condition mapping
CREATE TABLE IF NOT EXISTS therapy_condition_map (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  therapy_id UUID NOT NULL REFERENCES therapies(id) ON DELETE CASCADE,
  condition_id UUID NOT NULL REFERENCES therapy_conditions(id) ON DELETE CASCADE,
  UNIQUE(therapy_id, condition_id)
);

ALTER TABLE therapy_condition_map ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Map readable" ON therapy_condition_map FOR SELECT USING (true);

-- Clinic-specific therapy products/pricing
CREATE TABLE IF NOT EXISTS clinic_therapy_products (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  clinic_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  therapy_id UUID NOT NULL REFERENCES therapies(id) ON DELETE CASCADE,
  product_name TEXT,
  formulation TEXT,
  concentration TEXT,
  price DECIMAL(10,2),
  price_unit TEXT DEFAULT 'per unit',
  inventory_status TEXT DEFAULT 'available' CHECK (inventory_status IN ('available','limited','unavailable','coming_soon')),
  requires_consult BOOLEAN DEFAULT true,
  reorder_available BOOLEAN DEFAULT false,
  clinic_notes TEXT,
  active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE clinic_therapy_products ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Clinicians manage own" ON clinic_therapy_products FOR ALL USING (auth.uid() = clinic_id);
CREATE POLICY "Patients view linked clinic" ON clinic_therapy_products FOR SELECT USING (
  EXISTS (
    SELECT 1 FROM care_relationships
    WHERE care_relationships.clinician_id = clinic_therapy_products.clinic_id
      AND care_relationships.patient_id = auth.uid()
      AND care_relationships.status = 'active'
  )
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_therapies_type ON therapies(therapy_type);
CREATE INDEX IF NOT EXISTS idx_therapies_category ON therapies(category);
CREATE INDEX IF NOT EXISTS idx_therapies_slug ON therapies(slug);
CREATE INDEX IF NOT EXISTS idx_therapy_refs ON therapy_references(therapy_id);
CREATE INDEX IF NOT EXISTS idx_protocol_components ON protocol_components(protocol_id);
CREATE INDEX IF NOT EXISTS idx_clinic_therapy ON clinic_therapy_products(clinic_id, therapy_id);
