// Account deletion — /api/account/delete
// Deletes all user data from Supabase and the auth account.
// Requires a valid Bearer token (the user's own JWT).

const { getSupabaseAdmin, getUserFromRequest } = require('../../lib/supabase-admin');

module.exports = async function handler(req, res) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization');
  res.setHeader('Access-Control-Allow-Methods', 'POST, OPTIONS');
  if (req.method === 'OPTIONS') return res.status(204).end();
  if (req.method !== 'POST') return res.status(405).json({ error: 'POST only' });

  const user = await getUserFromRequest(req);
  if (!user) return res.status(401).json({ error: 'Unauthorized' });

  const userId = user.id;
  const supabase = getSupabaseAdmin();
  const errors = [];

  // Delete from all user-associated tables.
  // Order matters: delete dependents before parents.
  const tables = [
    // Clinical
    { table: 'patient_prescriptions', column: 'user_id' },
    { table: 'patient_protocols', column: 'user_id' },
    { table: 'patient_checkins', column: 'user_id' },
    { table: 'care_invite_codes', column: 'user_id' },
    { table: 'care_relationships', column: 'patient_id' },
    { table: 'care_relationships', column: 'clinician_id' },
    { table: 'clinic_settings', column: 'clinician_id' },
    { table: 'audit_logs', column: 'clinician_id' },
    // App data
    { table: 'workout_set_logs', column: 'user_id' },
    { table: 'points_ledger', column: 'user_id' },
    { table: 'reward_redemptions', column: 'user_id' },
    { table: 'feedback', column: 'user_id' },
    { table: 'profiles', column: 'id' },
  ];

  for (const { table, column } of tables) {
    const { error } = await supabase.from(table).delete().eq(column, userId);
    if (error && !error.message.includes('does not exist')) {
      errors.push({ table, error: error.message });
    }
  }

  // Delete the Supabase auth account
  const { error: authError } = await supabase.auth.admin.deleteUser(userId);
  if (authError) {
    errors.push({ table: 'auth.users', error: authError.message });
  }

  if (errors.length > 0 && authError) {
    return res.status(500).json({ error: 'Partial deletion', details: errors });
  }

  return res.status(200).json({ deleted: true, userId });
};
