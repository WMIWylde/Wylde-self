// /api/founder-count
// ────────────────────────────────────────────────────────────────────
//   Returns the current Founding Member count + remaining spots.
//   Called by the iOS PaywallView and the web paywall to render
//   "Founding member 47 of 1,000" on the offer screen.
//
//   Cached for 60s in CDN to avoid hammering Supabase on every paywall view.
// ────────────────────────────────────────────────────────────────────

const SUPABASE_URL = process.env.SUPABASE_URL || 'https://huclolzxzpitdpyogolu.supabase.co';
const SUPABASE_SERVICE_KEY = process.env.SUPABASE_SERVICE_KEY || ''; // anon key works too for the view

module.exports = async function handler(req, res) {
  // CORS — paywall is rendered from native iOS + web
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');
  if (req.method === 'OPTIONS') return res.status(200).end();
  if (req.method !== 'GET') return res.status(405).json({ error: 'Method not allowed' });

  // 60s edge cache — counter only updates on new founder purchase
  res.setHeader('Cache-Control', 's-maxage=60, stale-while-revalidate=120');

  try {
    const url = SUPABASE_URL + '/rest/v1/founder_count?select=*';
    const r = await fetch(url, {
      headers: {
        apikey: SUPABASE_SERVICE_KEY,
        Authorization: 'Bearer ' + SUPABASE_SERVICE_KEY
      }
    });

    if (!r.ok) {
      // Soft-fail with safe defaults so the paywall still renders
      console.error('[founder-count] Supabase responded', r.status);
      return res.status(200).json({
        total_founders: 0,
        founder_cap: 1000,
        spots_remaining: 1000,
        highest_member_number: null,
        cached: false
      });
    }

    const rows = await r.json();
    const row = Array.isArray(rows) ? rows[0] : rows;

    return res.status(200).json({
      total_founders: row?.total_founders || 0,
      founder_cap: row?.founder_cap || 1000,
      spots_remaining: row?.spots_remaining || 1000,
      highest_member_number: row?.highest_member_number || null,
      cached: false
    });
  } catch (err) {
    console.error('[founder-count] Error:', err);
    return res.status(200).json({
      total_founders: 0,
      founder_cap: 1000,
      spots_remaining: 1000,
      highest_member_number: null,
      error: err.message
    });
  }
};
