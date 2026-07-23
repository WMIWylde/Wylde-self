-- ════════════════════════════════════════════════════════════════════
--  Wylde Self — Nutrition Preferences
--  Stores structured user nutrition preferences (dietary framework,
--  restrictions, goals, meal structure, lifestyle, and targets).
--  One row per user. preferences_data JSONB holds the full model;
--  dietary_framework and restrictions are denormalized for queries.
--
--  Idempotent — safe to re-run.
-- ════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS nutrition_preferences (
  user_id            UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  preferences_data   JSONB NOT NULL DEFAULT '{}'::jsonb,
  dietary_framework  TEXT,
  restrictions       TEXT[] DEFAULT ARRAY[]::TEXT[],
  source             TEXT DEFAULT 'user' CHECK (source IN ('user', 'ai', 'care-team')),
  created_at         TIMESTAMPTZ DEFAULT NOW(),
  updated_at         TIMESTAMPTZ DEFAULT NOW()
);

-- RLS — users can only access their own preferences
ALTER TABLE nutrition_preferences ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  CREATE POLICY nutrition_preferences_self_read
    ON nutrition_preferences FOR SELECT
    USING (auth.uid() = user_id);
EXCEPTION WHEN duplicate_object THEN null;
END $$;

DO $$ BEGIN
  CREATE POLICY nutrition_preferences_self_write
    ON nutrition_preferences FOR INSERT
    WITH CHECK (auth.uid() = user_id);
EXCEPTION WHEN duplicate_object THEN null;
END $$;

DO $$ BEGIN
  CREATE POLICY nutrition_preferences_self_update
    ON nutrition_preferences FOR UPDATE
    USING (auth.uid() = user_id);
EXCEPTION WHEN duplicate_object THEN null;
END $$;

DO $$ BEGIN
  CREATE POLICY nutrition_preferences_self_delete
    ON nutrition_preferences FOR DELETE
    USING (auth.uid() = user_id);
EXCEPTION WHEN duplicate_object THEN null;
END $$;

-- Updated_at auto-bump
CREATE OR REPLACE FUNCTION touch_nutrition_preferences_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS nutrition_preferences_touch ON nutrition_preferences;
CREATE TRIGGER nutrition_preferences_touch
  BEFORE UPDATE ON nutrition_preferences
  FOR EACH ROW
  EXECUTE FUNCTION touch_nutrition_preferences_updated_at();

-- Index for quick framework lookups (Phase 2 recipe filtering)
CREATE INDEX IF NOT EXISTS idx_nutrition_preferences_framework
  ON nutrition_preferences(dietary_framework)
  WHERE dietary_framework IS NOT NULL;
