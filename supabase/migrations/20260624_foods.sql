-- Unified food database — cached from USDA + user corrections
CREATE TABLE IF NOT EXISTS foods (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  provider TEXT DEFAULT 'usda' CHECK (provider IN ('usda','nutritionix','openfoodfacts','user','ai')),
  provider_food_id TEXT,
  name TEXT NOT NULL,
  brand TEXT,
  description TEXT,
  serving_size DECIMAL(10,2) DEFAULT 100,
  serving_unit TEXT DEFAULT 'g',
  calories INT,
  protein DECIMAL(6,2),
  carbs DECIMAL(6,2),
  fat DECIMAL(6,2),
  fiber DECIMAL(6,2),
  sugar DECIMAL(6,2),
  sodium DECIMAL(6,2),
  barcode TEXT,
  image_url TEXT,
  verified BOOLEAN DEFAULT false,
  search_count INT DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(provider, provider_food_id)
);

ALTER TABLE foods ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Foods readable by all" ON foods FOR SELECT USING (true);
CREATE POLICY "Authenticated users insert" ON foods FOR INSERT WITH CHECK (auth.uid() IS NOT NULL);

CREATE INDEX IF NOT EXISTS idx_foods_name ON foods USING gin(to_tsvector('english', name));
CREATE INDEX IF NOT EXISTS idx_foods_barcode ON foods(barcode) WHERE barcode IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_foods_search_count ON foods(search_count DESC);
