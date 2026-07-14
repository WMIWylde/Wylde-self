-- Migration: Default clinic_settings.status to 'pending'
-- Purpose: New clinics must be explicitly approved before gaining clinician
--          access. Previously the column defaulted to 'approved', which auto-
--          granted access to any authenticated user on first settings access.

-- ── 1. Change the column default to 'pending' ───────────────────────
ALTER TABLE clinic_settings
  ALTER COLUMN status SET DEFAULT 'pending';

COMMENT ON COLUMN clinic_settings.status IS 'Clinic approval status: pending, approved, suspended (new rows default to pending)';

-- ── 2. Existing rows are intentionally left untouched ───────────────
-- This migration does NOT modify existing data. Any clinic_settings rows
-- created under the old 'approved' default remain 'approved'.
--
-- OPERATOR ACTION REQUIRED: manually review existing rows and downgrade any
-- that were never legitimately approved, e.g.:
--
--   SELECT clinician_id, clinic_name, status, created_at
--     FROM clinic_settings
--    WHERE status = 'approved'
--    ORDER BY created_at;
--
-- Then, for rows that should not have auto-approved access:
--
--   UPDATE clinic_settings SET status = 'pending' WHERE clinician_id = '<uuid>';
--
-- No automatic UPDATE is performed here to avoid revoking access from
-- legitimately approved clinicians.
