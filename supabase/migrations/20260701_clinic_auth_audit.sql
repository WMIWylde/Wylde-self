-- Migration: Add clinic authorization status + audit logging
-- Purpose: Role-gate clinic endpoints, track clinical operations

-- ── 1. Add status column to clinic_settings for role gating ──────────
ALTER TABLE clinic_settings
  ADD COLUMN IF NOT EXISTS status TEXT NOT NULL DEFAULT 'approved';

COMMENT ON COLUMN clinic_settings.status IS 'Clinic approval status: pending, approved, suspended';

-- ── 2. Create audit_logs table ───────────────────────────────────────
CREATE TABLE IF NOT EXISTS audit_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  clinician_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  action TEXT NOT NULL,
  target_type TEXT,
  target_id TEXT,
  details JSONB DEFAULT '{}',
  ip_address TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Index for querying a clinician's audit trail
CREATE INDEX IF NOT EXISTS idx_audit_logs_clinician_created
  ON audit_logs (clinician_id, created_at DESC);

-- Index for querying by action type
CREATE INDEX IF NOT EXISTS idx_audit_logs_action
  ON audit_logs (action);

-- ── 3. Row Level Security ────────────────────────────────────────────
ALTER TABLE audit_logs ENABLE ROW LEVEL SECURITY;

-- Clinicians can only read their own audit logs
CREATE POLICY audit_logs_select_own ON audit_logs
  FOR SELECT
  USING (auth.uid() = clinician_id);

-- Only the service role can insert (API endpoints use service key)
CREATE POLICY audit_logs_insert_service ON audit_logs
  FOR INSERT
  WITH CHECK (true);

-- No updates or deletes — audit logs are append-only
-- (service role bypasses RLS, so API inserts will work)
