-- ════════════════════════════════════════════════════════════════════
--  Wylde Self — Identity Import (Founding Members feature)
--  Stores the AI-analyzed identity profile derived from user's
--  external content (bios, captions, public profile pages, etc.)
--  Used to dynamically tune the Coach voice + daily messages + every
--  AI-driven surface to match how the user actually communicates.
--
--  One row per user. Idempotent — safe to re-run.
-- ════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS user_identity_profile (
  user_id              uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,

  -- Core archetype + confidence
  identity_archetype   text,                              -- e.g. "the disciplined builder"
  confidence_level     text CHECK (confidence_level IN ('low','medium','high')),

  -- Communication
  communication_tone   text,                              -- e.g. "direct, visual, occasionally vulnerable"
  language_to_use      jsonb DEFAULT '[]'::jsonb,         -- array of phrases / cadence cues
  language_to_avoid    jsonb DEFAULT '[]'::jsonb,         -- array of phrases / patterns to skip

  -- Identity dynamics
  motivation_triggers  jsonb DEFAULT '[]'::jsonb,         -- what fires them up
  limiting_patterns    jsonb DEFAULT '[]'::jsonb,         -- what holds them back
  emotional_drivers    jsonb DEFAULT '[]'::jsonb,         -- core feelings that move them
  aspirational_identity text,                             -- who they're becoming
  discipline_level     text CHECK (discipline_level IN ('emerging','building','strong','elite')),

  -- Coaching style preference
  coaching_style       text CHECK (coaching_style IN ('direct','intense','supportive','spiritual','tactical','mixed')),

  -- Raw inputs (for re-analysis later if AI improves) + privacy/audit
  raw_sources          jsonb DEFAULT '[]'::jsonb,         -- {type:'url'|'text', value:string, fetched_at:ts}
  source_count         int DEFAULT 0,

  -- Timestamps
  created_at           timestamptz DEFAULT NOW(),
  updated_at           timestamptz DEFAULT NOW(),

  -- AI model used + prompt version (so we can re-analyze if we change either)
  analysis_model       text DEFAULT 'claude-haiku-4-5-20251001',
  analysis_version     int  DEFAULT 1
);

-- Index for the "join in getUserContext" lookup
CREATE INDEX IF NOT EXISTS user_identity_profile_user_id_idx
  ON user_identity_profile (user_id);

-- RLS — users can only read/write their own profile
ALTER TABLE user_identity_profile ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  CREATE POLICY user_identity_profile_self_read
    ON user_identity_profile FOR SELECT
    USING (auth.uid() = user_id);
EXCEPTION WHEN duplicate_object THEN null;
END $$;

DO $$ BEGIN
  CREATE POLICY user_identity_profile_self_write
    ON user_identity_profile FOR INSERT
    WITH CHECK (auth.uid() = user_id);
EXCEPTION WHEN duplicate_object THEN null;
END $$;

DO $$ BEGIN
  CREATE POLICY user_identity_profile_self_update
    ON user_identity_profile FOR UPDATE
    USING (auth.uid() = user_id);
EXCEPTION WHEN duplicate_object THEN null;
END $$;

DO $$ BEGIN
  CREATE POLICY user_identity_profile_self_delete
    ON user_identity_profile FOR DELETE
    USING (auth.uid() = user_id);
EXCEPTION WHEN duplicate_object THEN null;
END $$;

-- updated_at auto-bump on update
CREATE OR REPLACE FUNCTION touch_user_identity_profile_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS user_identity_profile_touch ON user_identity_profile;
CREATE TRIGGER user_identity_profile_touch
  BEFORE UPDATE ON user_identity_profile
  FOR EACH ROW
  EXECUTE FUNCTION touch_user_identity_profile_updated_at();

-- Verify with: SELECT * FROM user_identity_profile LIMIT 1;
