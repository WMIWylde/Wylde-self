-- Migration: Restrict audit_logs INSERT policy to service_role
-- Purpose: The original policy (audit_logs_insert_service, defined in
--          20260701_clinic_auth_audit.sql) used WITH CHECK (true), which lets
--          ANY role that can reach the table insert arbitrary audit rows.
--          Audit logs must only be written by the service role.

-- Drop the permissive policy created in 20260701_clinic_auth_audit.sql
DROP POLICY IF EXISTS audit_logs_insert_service ON audit_logs;

-- Recreate it restricted to the service_role only.
CREATE POLICY audit_logs_insert_service ON audit_logs
  FOR INSERT
  TO service_role
  WITH CHECK (true);

-- SELECT / append-only semantics from the original migration are unchanged.
