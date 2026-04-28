-- ════════════════════════════════════════════════════════════════════
--  Wylde Self — Pro Entitlements migration
--  Run this in the Supabase SQL editor (Project → SQL Editor → New query).
--  Safe to run multiple times — each statement uses IF NOT EXISTS guards.
-- ════════════════════════════════════════════════════════════════════

-- 1. Add Pro entitlement columns to profiles ------------------------------
ALTER TABLE profiles
  ADD COLUMN IF NOT EXISTS wylde_pro_status      text  DEFAULT 'free',
  ADD COLUMN IF NOT EXISTS founding_member_number int,
  ADD COLUMN IF NOT EXISTS founder_at            timestamptz,
  ADD COLUMN IF NOT EXISTS pro_provider          text,            -- 'apple' | 'stripe' | 'google'
  ADD COLUMN IF NOT EXISTS pro_product_id        text,            -- e.g. 'wylde_lifetime_founder'
  ADD COLUMN IF NOT EXISTS pro_renewal_at        timestamptz,
  ADD COLUMN IF NOT EXISTS pro_started_at        timestamptz,
  ADD COLUMN IF NOT EXISTS pro_revenuecat_id     text,
  ADD COLUMN IF NOT EXISTS pro_stripe_id         text;

-- 2. Constrain wylde_pro_status to known values ---------------------------
DO $$ BEGIN
  ALTER TABLE profiles
    ADD CONSTRAINT profiles_wylde_pro_status_check
    CHECK (wylde_pro_status IN ('free','lifetime','annual','monthly','expired','refunded'));
EXCEPTION WHEN duplicate_object THEN null;
END $$;

-- 3. Unique founding_member_number — only one #N per integer --------------
CREATE UNIQUE INDEX IF NOT EXISTS profiles_founding_member_number_unique
  ON profiles (founding_member_number)
  WHERE founding_member_number IS NOT NULL;

-- 4. Fast lookups when checking pro status by user ------------------------
CREATE INDEX IF NOT EXISTS profiles_pro_status_idx
  ON profiles (wylde_pro_status)
  WHERE wylde_pro_status != 'free';

-- 5. Founder count view — used by /api/founder-count for the paywall counter
CREATE OR REPLACE VIEW founder_count AS
SELECT
  COUNT(*) FILTER (WHERE founding_member_number IS NOT NULL) AS total_founders,
  1000 AS founder_cap,
  GREATEST(0, 1000 - COUNT(*) FILTER (WHERE founding_member_number IS NOT NULL)) AS spots_remaining,
  MAX(founding_member_number) AS highest_member_number
FROM profiles;

-- 6. Atomic founder-number assignment function ----------------------------
-- Called by the RevenueCat webhook + Stripe webhook. Guarantees no two
-- users get the same number even under race conditions.
CREATE OR REPLACE FUNCTION assign_founding_member_number(p_user_id uuid)
RETURNS int
LANGUAGE plpgsql
AS $$
DECLARE
  next_num int;
BEGIN
  -- Already a founder? Return existing number, idempotent.
  SELECT founding_member_number INTO next_num
  FROM profiles
  WHERE id = p_user_id AND founding_member_number IS NOT NULL;

  IF next_num IS NOT NULL THEN
    RETURN next_num;
  END IF;

  -- Lock the count, get next number
  SELECT COALESCE(MAX(founding_member_number), 0) + 1 INTO next_num
  FROM profiles
  FOR UPDATE;

  -- Refuse if cap reached
  IF next_num > 1000 THEN
    RAISE EXCEPTION 'Founder cap of 1000 reached (would-be number: %)', next_num;
  END IF;

  UPDATE profiles
  SET founding_member_number = next_num,
      founder_at = NOW()
  WHERE id = p_user_id;

  RETURN next_num;
END;
$$;

-- 7. RLS policy — users can read their own pro_status (already covered if
--    profiles RLS is on by user_id, but adding column-explicit policy
--    here for safety) ----------------------------------------------------
DO $$ BEGIN
  CREATE POLICY profiles_self_read_pro ON profiles
    FOR SELECT USING (auth.uid() = id);
EXCEPTION WHEN duplicate_object THEN null;
END $$;

-- 8. Done — verify with: SELECT * FROM founder_count;
