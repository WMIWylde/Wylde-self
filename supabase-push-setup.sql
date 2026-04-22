-- ═══ PUSH NOTIFICATIONS TABLE ═══
-- Run this in your Supabase SQL Editor (https://supabase.com/dashboard → SQL Editor)

-- Push subscriptions (web + iOS)
CREATE TABLE IF NOT EXISTS push_subscriptions (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  platform TEXT NOT NULL CHECK (platform IN ('web', 'ios')),
  endpoint TEXT NOT NULL,
  keys_p256dh TEXT,          -- Web Push only
  keys_auth TEXT,            -- Web Push only
  notification_prefs JSONB DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(user_id, platform)
);

-- Enable RLS
ALTER TABLE push_subscriptions ENABLE ROW LEVEL SECURITY;

-- Users can read/write their own subscriptions
CREATE POLICY "Users manage own push subscriptions"
  ON push_subscriptions
  FOR ALL
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- Index for querying by user
CREATE INDEX IF NOT EXISTS idx_push_subs_user ON push_subscriptions(user_id);

-- Add notification_prefs column to profiles if not exists
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'profiles' AND column_name = 'notification_prefs'
  ) THEN
    ALTER TABLE profiles ADD COLUMN notification_prefs JSONB DEFAULT '{}'::jsonb;
  END IF;
END $$;
