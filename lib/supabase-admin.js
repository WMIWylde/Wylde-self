// Server-side Supabase client using the service role key.
// Used by /api/consumer/* endpoints to read/write clinical data.

const { createClient } = require('@supabase/supabase-js');

let _client = null;

function getSupabaseAdmin() {
  if (_client) return _client;
  const url = process.env.SUPABASE_URL || process.env.NEXT_PUBLIC_SUPABASE_URL;
  const key = process.env.SUPABASE_SERVICE_KEY || process.env.SUPABASE_SERVICE_ROLE_KEY;
  if (!url || !key) throw new Error('SUPABASE_URL and SUPABASE_SERVICE_KEY must be set');
  _client = createClient(url, key, { auth: { persistSession: false } });
  return _client;
}

// Extract user ID from the Authorization: Bearer <jwt> header.
// Uses Supabase's auth.getUser() to verify the token server-side.
async function getUserFromRequest(req) {
  const auth = req.headers.authorization || req.headers.Authorization || '';
  const token = auth.replace(/^Bearer\s+/i, '');
  if (!token) return null;

  const url = process.env.SUPABASE_URL || process.env.NEXT_PUBLIC_SUPABASE_URL;
  const anonKey = process.env.SUPABASE_ANON_KEY || process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY;
  if (!url || !anonKey) return null;

  const userClient = createClient(url, anonKey, {
    auth: { persistSession: false },
    global: { headers: { Authorization: `Bearer ${token}` } },
  });

  const { data: { user }, error } = await userClient.auth.getUser();
  if (error || !user) return null;
  return user;
}

module.exports = { getSupabaseAdmin, getUserFromRequest };
