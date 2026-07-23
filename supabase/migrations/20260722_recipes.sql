-- ════════════════════════════════════════════════════════════════════
--  Wylde Self — Recipes
--  Stores built-in, AI-generated, and user-created recipes.
--  Built-in recipes (source='builtin') are readable by all.
--  User recipes (source='user'/'ai') are private per user.
--
--  Idempotent — safe to re-run.
-- ════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS recipes (
  id              UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id         UUID REFERENCES auth.users(id) ON DELETE CASCADE,  -- NULL for built-in
  source          TEXT NOT NULL DEFAULT 'builtin'
                    CHECK (source IN ('builtin', 'user', 'ai')),
  meal_type       TEXT NOT NULL
                    CHECK (meal_type IN ('breakfast', 'lunch', 'dinner', 'snack')),
  name            TEXT NOT NULL,
  description     TEXT,
  ingredients     JSONB NOT NULL DEFAULT '[]'::jsonb,   -- ["3 eggs", "1 avocado", ...]
  instructions    JSONB NOT NULL DEFAULT '[]'::jsonb,   -- ["Scramble eggs", "Toast bread", ...]
  prep_time       INT,                                   -- minutes
  calories        INT,
  protein         INT,
  carbs           INT,
  fat             INT,
  fiber           INT,
  tags            TEXT[] DEFAULT ARRAY[]::TEXT[],         -- {"high-protein","quick","vegan"}
  image_url       TEXT,
  is_active       BOOLEAN DEFAULT true,
  created_at      TIMESTAMPTZ DEFAULT NOW(),
  updated_at      TIMESTAMPTZ DEFAULT NOW()
);

-- RLS
ALTER TABLE recipes ENABLE ROW LEVEL SECURITY;

-- Everyone can read built-in recipes
DO $$ BEGIN
  CREATE POLICY recipes_builtin_read
    ON recipes FOR SELECT
    USING (source = 'builtin');
EXCEPTION WHEN duplicate_object THEN null;
END $$;

-- Users can read their own recipes
DO $$ BEGIN
  CREATE POLICY recipes_own_read
    ON recipes FOR SELECT
    USING (auth.uid() = user_id);
EXCEPTION WHEN duplicate_object THEN null;
END $$;

-- Users can insert their own recipes
DO $$ BEGIN
  CREATE POLICY recipes_own_insert
    ON recipes FOR INSERT
    WITH CHECK (auth.uid() = user_id);
EXCEPTION WHEN duplicate_object THEN null;
END $$;

-- Users can update their own recipes
DO $$ BEGIN
  CREATE POLICY recipes_own_update
    ON recipes FOR UPDATE
    USING (auth.uid() = user_id);
EXCEPTION WHEN duplicate_object THEN null;
END $$;

-- Users can delete their own recipes
DO $$ BEGIN
  CREATE POLICY recipes_own_delete
    ON recipes FOR DELETE
    USING (auth.uid() = user_id);
EXCEPTION WHEN duplicate_object THEN null;
END $$;

-- ═══ User saved/favorited recipes (junction table) ═══

CREATE TABLE IF NOT EXISTS user_saved_recipes (
  user_id    UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  recipe_id  UUID NOT NULL REFERENCES recipes(id) ON DELETE CASCADE,
  saved_at   TIMESTAMPTZ DEFAULT NOW(),
  PRIMARY KEY (user_id, recipe_id)
);

ALTER TABLE user_saved_recipes ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  CREATE POLICY saved_recipes_self_read
    ON user_saved_recipes FOR SELECT
    USING (auth.uid() = user_id);
EXCEPTION WHEN duplicate_object THEN null;
END $$;

DO $$ BEGIN
  CREATE POLICY saved_recipes_self_insert
    ON user_saved_recipes FOR INSERT
    WITH CHECK (auth.uid() = user_id);
EXCEPTION WHEN duplicate_object THEN null;
END $$;

DO $$ BEGIN
  CREATE POLICY saved_recipes_self_delete
    ON user_saved_recipes FOR DELETE
    USING (auth.uid() = user_id);
EXCEPTION WHEN duplicate_object THEN null;
END $$;

-- ═══ Indexes ═══

CREATE INDEX IF NOT EXISTS idx_recipes_meal_type
  ON recipes(meal_type) WHERE is_active = true;

CREATE INDEX IF NOT EXISTS idx_recipes_source
  ON recipes(source) WHERE is_active = true;

CREATE INDEX IF NOT EXISTS idx_recipes_user
  ON recipes(user_id) WHERE user_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_recipes_tags
  ON recipes USING gin(tags) WHERE is_active = true;

CREATE INDEX IF NOT EXISTS idx_recipes_name_search
  ON recipes USING gin(to_tsvector('english', name));

-- ═══ Updated_at trigger ═══

CREATE OR REPLACE FUNCTION touch_recipes_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS recipes_touch ON recipes;
CREATE TRIGGER recipes_touch
  BEFORE UPDATE ON recipes
  FOR EACH ROW
  EXECUTE FUNCTION touch_recipes_updated_at();
