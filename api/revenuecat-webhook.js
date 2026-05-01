// /api/revenuecat-webhook
// ────────────────────────────────────────────────────────────────────
//   Receives webhook events from RevenueCat and syncs the user's Pro
//   entitlement state to Supabase. Source of truth across iOS, web,
//   and any future Android client.
//
//   RevenueCat event types we care about:
//     INITIAL_PURCHASE   — new founder! assign founding_member_number
//     RENEWAL            — keep the existing entitlement valid
//     CANCELLATION       — user requested cancel; keeps access until expires_date
//     UNCANCELLATION     — user changed their mind
//     EXPIRATION         — entitlement expired; downgrade to 'expired'
//     BILLING_ISSUE      — payment failed; flag but keep access during grace
//     PRODUCT_CHANGE     — switched plan (annual ↔ monthly)
//     TRANSFER           — entitlement moved to a different anonymous ID
//     SUBSCRIPTION_PAUSED / RESUBSCRIBE / etc. — handled as no-ops or status updates
//
//   Auth: RevenueCat signs requests with a secret that's set in the
//   RevenueCat dashboard (Project → Webhooks → Authorization header).
//   We verify it against REVENUECAT_WEBHOOK_SECRET env var.
// ────────────────────────────────────────────────────────────────────

const SUPABASE_URL = process.env.SUPABASE_URL;
const SUPABASE_SERVICE_KEY = process.env.SUPABASE_SERVICE_KEY || ''; // service_role key required for writes
const REVENUECAT_WEBHOOK_SECRET = process.env.REVENUECAT_WEBHOOK_SECRET || '';

module.exports = async function handler(req, res) {
  if (req.method !== 'POST') return res.status(405).json({ error: 'Method not allowed' });

  // ─── Auth ───────────────────────────────────────────────────────
  if (!REVENUECAT_WEBHOOK_SECRET) {
    console.error('[rc-webhook] REVENUECAT_WEBHOOK_SECRET not set — refusing to run');
    return res.status(500).json({ error: 'Server misconfigured' });
  }
  const authHeader = req.headers['authorization'] || '';
  if (authHeader !== 'Bearer ' + REVENUECAT_WEBHOOK_SECRET) {
    console.warn('[rc-webhook] Bad auth header');
    return res.status(401).json({ error: 'Unauthorized' });
  }

  const event = req.body && req.body.event;
  if (!event || !event.type) {
    return res.status(400).json({ error: 'Malformed event' });
  }

  console.log('[rc-webhook] Received', event.type, 'for', event.app_user_id);

  // app_user_id should be the Supabase user UUID (set during PurchaseManager.configure)
  const userId = event.app_user_id;
  if (!userId) {
    return res.status(400).json({ error: 'Missing app_user_id' });
  }

  try {
    // ─── Determine the new pro_status from event type + product ───
    const productId = event.product_id || '';
    let proStatus = 'free';
    let proRenewalAt = null;
    let proStartedAt = null;

    switch (event.type) {
      case 'INITIAL_PURCHASE':
      case 'RENEWAL':
      case 'UNCANCELLATION':
      case 'PRODUCT_CHANGE':
      case 'RESUBSCRIBE':
        proStatus = statusFromProductId(productId);
        proRenewalAt = event.expiration_at_ms ? new Date(event.expiration_at_ms).toISOString() : null;
        proStartedAt = event.purchased_at_ms ? new Date(event.purchased_at_ms).toISOString() : null;
        break;
      case 'CANCELLATION':
        // Still has access until expiration_at_ms — keep status, just note
        proStatus = statusFromProductId(productId);
        proRenewalAt = event.expiration_at_ms ? new Date(event.expiration_at_ms).toISOString() : null;
        break;
      case 'EXPIRATION':
        proStatus = 'expired';
        break;
      case 'BILLING_ISSUE':
        // Don't downgrade during grace — RC handles grace internally
        proStatus = statusFromProductId(productId);
        break;
      case 'SUBSCRIPTION_PAUSED':
      case 'TRANSFER':
        // No-op for now
        return res.status(200).json({ ok: true, ignored: event.type });
      default:
        console.log('[rc-webhook] Unhandled event type', event.type);
        return res.status(200).json({ ok: true, unhandled: true });
    }

    // ─── Update the profile row in Supabase ───────────────────────
    const updatePayload = {
      wylde_pro_status: proStatus,
      pro_provider: 'apple',
      pro_product_id: productId,
      pro_revenuecat_id: event.original_app_user_id || userId,
      pro_renewal_at: proRenewalAt,
      pro_started_at: proStartedAt,
      updated_at: new Date().toISOString()
    };

    // Drop nulls so we don't overwrite existing values with null on partial updates
    Object.keys(updatePayload).forEach(k => updatePayload[k] === null && delete updatePayload[k]);

    const updateUrl = SUPABASE_URL + '/rest/v1/profiles?id=eq.' + encodeURIComponent(userId);
    const updateRes = await fetch(updateUrl, {
      method: 'PATCH',
      headers: {
        apikey: SUPABASE_SERVICE_KEY,
        Authorization: 'Bearer ' + SUPABASE_SERVICE_KEY,
        'Content-Type': 'application/json',
        Prefer: 'return=minimal'
      },
      body: JSON.stringify(updatePayload)
    });

    if (!updateRes.ok) {
      const errText = await updateRes.text();
      console.error('[rc-webhook] Profile update failed:', updateRes.status, errText);
      return res.status(500).json({ error: 'Profile update failed', detail: errText });
    }

    // ─── If this is a NEW purchase, assign founding_member_number ─
    // Atomic via the assign_founding_member_number RPC defined in the migration.
    if (event.type === 'INITIAL_PURCHASE' && proStatus !== 'free' && proStatus !== 'expired') {
      const rpcRes = await fetch(SUPABASE_URL + '/rest/v1/rpc/assign_founding_member_number', {
        method: 'POST',
        headers: {
          apikey: SUPABASE_SERVICE_KEY,
          Authorization: 'Bearer ' + SUPABASE_SERVICE_KEY,
          'Content-Type': 'application/json'
        },
        body: JSON.stringify({ p_user_id: userId })
      });

      if (rpcRes.ok) {
        const num = await rpcRes.json();
        console.log('[rc-webhook] Assigned founder #' + num + ' to', userId);
      } else {
        // Cap reached or other error — log but don't fail the webhook
        const errText = await rpcRes.text();
        console.warn('[rc-webhook] Founder number not assigned:', errText);
      }
    }

    return res.status(200).json({ ok: true, status: proStatus });
  } catch (err) {
    console.error('[rc-webhook] Exception:', err);
    return res.status(500).json({ error: err.message });
  }
};

function statusFromProductId(pid) {
  const p = String(pid || '').toLowerCase();
  if (p.includes('lifetime')) return 'lifetime';
  if (p.includes('annual') || p.includes('yearly')) return 'annual';
  if (p.includes('monthly') || p.includes('month'))  return 'monthly';
  return 'free';
}
