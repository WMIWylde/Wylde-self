// Audit logging for clinical operations.
// Writes to the audit_logs table for compliance and security tracing.

async function auditLog(supabase, { clinician_id, action, target_type, target_id, details }) {
  try {
    await supabase.from('audit_logs').insert({
      clinician_id,
      action,
      target_type,
      target_id: target_id ? String(target_id) : null,
      details: details || {},
      created_at: new Date().toISOString(),
    });
  } catch (err) {
    // Audit failures should never break the main operation
    console.error('[audit] log failed:', err.message);
  }
}

module.exports = { auditLog };
