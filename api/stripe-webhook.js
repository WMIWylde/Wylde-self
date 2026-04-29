// /api/stripe-webhook
// ────────────────────────────────────────────────────────────────────
//   Receives Stripe webhook events. Verifies the signature with
//   STRIPE_WEBHOOK_SECRET, then writes the entitlement to Supabase
//   profiles and assigns a founding_member_number atomically.
//
//   Events handled:
//     checkout.session.completed   — first purchase landed
//     invoice.paid                  — recurring renewal
//     customer.subscription.deleted — cancellation
//     customer.subscription.updated — plan changes
//
//   All other events are acked with 200 (Stripe needs a fast 200 or
//   it'll retry, which floods our logs).
//
//   IMPORTANT: Stripe webhooks need the raw request body to verify
//   signatures. Vercel Node functions get JSON-parsed by default, so
//   we have to disable body-parser via the export config below.
// ────────────────────────────────────────────────────────────────────

const STRIPE_SECRET = process.env.STRIPE_SECRET_KEY || '';
const STRIPE_WEBHOOK_SECRET = process.env.STRIPE_WEBHOOK_SECRET || '';
const SUPABASE_URL = process.env.SUPABASE_URL || 'https://huclolzxzpitdpyogolu.supabase.co';
const SUPABASE_SERVICE_KEY = process.env.SUPABASE_SERVICE_KEY || '';

// Disable Vercel's automatic body parser so we get the raw bytes for
// signature verification. Stripe's library expects the unparsed body.
module.exports.config = {
  api: { bodyParser: false }
};

module.exports = async function handler(req, res) {
  if (req.method !== 'POST') return res.status(405).json({ error: 'Method not allowed' });

  if (!STRIPE_SECRET || !STRIPE_WEBHOOK_SECRET) {
    console.error('[stripe-webhook] Missing STRIPE_SECRET_KEY or STRIPE_WEBHOOK_SECRET');
    return res.status(500).json({ error: 'Stripe not configured' });
  }

  let stripe;
  try {
    stripe = require('stripe')(STRIPE_SECRET, { apiVersion: '2024-09-30.acacia' });
  } catch (e) {
    return res.status(500).json({ error: 'Stripe SDK not installed' });
  }

  // ─── Read raw body for signature verification ───────────────────
  const rawBody = await readRawBody(req);
  const sig = req.headers['stripe-signature'] || '';

  let event;
  try {
    event = stripe.webhooks.constructEvent(rawBody, sig, STRIPE_WEBHOOK_SECRET);
  } catch (err) {
    console.error('[stripe-webhook] Signature verification failed:', err.message);
    return res.status(400).json({ error: 'Invalid signature' });
  }

  console.log('[stripe-webhook] Received', event.type);

  try {
    switch (event.type) {

      // ─── First purchase ─────────────────────────────────────────
      case 'checkout.session.completed': {
        const session = event.data.object;
        const userId = session.client_reference_id || session.metadata?.wylde_user_id || null;
        const tier = session.metadata?.wylde_tier || inferTierFromSession(session);
        const email = session.customer_details?.email || session.customer_email || null;

        if (!userId && !email) {
          console.warn('[stripe-webhook] Session has neither user_id nor email — cannot match user');
          return res.status(200).json({ ok: true, ignored: 'no_user_match' });
        }

        await upsertProEntitlement({
          userId, email, tier,
          stripeCustomerId: session.customer || null,
          stripeSubscriptionId: session.subscription || null,
          stripeSessionId: session.id,
          isInitial: true
        });
        break;
      }

      // ─── Recurring renewal ──────────────────────────────────────
      case 'invoice.paid': {
        const invoice = event.data.object;
        const subscription = invoice.subscription
          ? await stripe.subscriptions.retrieve(invoice.subscription)
          : null;
        const userId = subscription?.metadata?.wylde_user_id || null;
        const tier = subscription?.metadata?.wylde_tier || inferTierFromSubscription(subscription);
        const email = invoice.customer_email || null;

        if (!userId && !email) {
          return res.status(200).json({ ok: true, ignored: 'no_user_match' });
        }

        await upsertProEntitlement({
          userId, email, tier,
          stripeCustomerId: invoice.customer,
          stripeSubscriptionId: subscription?.id || null,
          renewalAt: subscription?.current_period_end ? new Date(subscription.current_period_end * 1000).toISOString() : null,
          isInitial: false
        });
        break;
      }

      // ─── Plan change (annual ↔ monthly) ─────────────────────────
      case 'customer.subscription.updated': {
        const sub = event.data.object;
        const userId = sub.metadata?.wylde_user_id || null;
        const tier = sub.metadata?.wylde_tier || inferTierFromSubscription(sub);
        if (!userId) return res.status(200).json({ ok: true, ignored: 'no_user_id' });

        await upsertProEntitlement({
          userId, tier,
          stripeCustomerId: sub.customer,
          stripeSubscriptionId: sub.id,
          renewalAt: sub.current_period_end ? new Date(sub.current_period_end * 1000).toISOString() : null,
          isInitial: false
        });
        break;
      }

      // ─── Cancellation / expiration ──────────────────────────────
      case 'customer.subscription.deleted': {
        const sub = event.data.object;
        const userId = sub.metadata?.wylde_user_id || null;
        if (!userId) return res.status(200).json({ ok: true, ignored: 'no_user_id' });

        await updateProStatus(userId, 'expired');
        break;
      }

      default:
        // Ack everything else so Stripe doesn't retry
        console.log('[stripe-webhook] Unhandled event', event.type);
    }

    return res.status(200).json({ ok: true });
  } catch (e) {
    console.error('[stripe-webhook] Handler exception:', e);
    return res.status(500).json({ error: e.message });
  }
};

// ─── Helpers ───────────────────────────────────────────────────────

function readRawBody(req) {
  return new Promise((resolve, reject) => {
    const chunks = [];
    req.on('data', (c) => chunks.push(Buffer.from(c)));
    req.on('end', () => resolve(Buffer.concat(chunks)));
    req.on('error', reject);
  });
}

function inferTierFromSession(session) {
  // For Checkout sessions before subscription is created
  if (session.mode === 'payment') return 'lifetime';
  if (session.mode === 'subscription') {
    // We don't have the price interval here, default to monthly
    // (subscription_data.metadata.wylde_tier should already be set, this is fallback)
    return 'monthly';
  }
  return 'lifetime';
}

function inferTierFromSubscription(sub) {
  const interval = sub?.items?.data?.[0]?.plan?.interval;
  if (interval === 'year') return 'annual';
  if (interval === 'month') return 'monthly';
  return 'monthly';
}

/**
 * Upserts the user's Pro entitlement in Supabase. Matches by user_id if
 * provided, otherwise by email. Atomically assigns founding_member_number
 * on first purchase via the RPC defined in the migration.
 */
async function upsertProEntitlement(opts) {
  const { userId, email, tier, stripeCustomerId, stripeSubscriptionId,
          stripeSessionId, renewalAt, isInitial } = opts;

  // Resolve the user — prefer user_id, fall back to email lookup
  let resolvedId = userId;
  if (!resolvedId && email) {
    const lookup = await fetch(SUPABASE_URL + '/rest/v1/profiles?select=id&email=eq.' + encodeURIComponent(email), {
      headers: {
        apikey: SUPABASE_SERVICE_KEY,
        Authorization: 'Bearer ' + SUPABASE_SERVICE_KEY
      }
    });
    if (lookup.ok) {
      const rows = await lookup.json();
      if (rows[0]?.id) resolvedId = rows[0].id;
    }
  }

  if (!resolvedId) {
    console.warn('[stripe-webhook] Could not resolve user for tier=' + tier + ' email=' + email);
    return;
  }

  const status = tier; // 'lifetime' | 'annual' | 'monthly'
  const update = {
    wylde_pro_status: status,
    pro_provider:     'stripe',
    pro_product_id:   tier === 'lifetime' ? 'founder_lifetime' : ('founder_' + tier),
    pro_stripe_id:    stripeCustomerId || stripeSubscriptionId || stripeSessionId || null,
    pro_renewal_at:   renewalAt || null,
    pro_started_at:   isInitial ? new Date().toISOString() : undefined,
    updated_at:       new Date().toISOString()
  };
  // Strip undefined so we don't blank out existing values
  Object.keys(update).forEach(k => update[k] === undefined && delete update[k]);

  const patchRes = await fetch(SUPABASE_URL + '/rest/v1/profiles?id=eq.' + encodeURIComponent(resolvedId), {
    method: 'PATCH',
    headers: {
      apikey: SUPABASE_SERVICE_KEY,
      Authorization: 'Bearer ' + SUPABASE_SERVICE_KEY,
      'Content-Type': 'application/json',
      Prefer: 'return=minimal'
    },
    body: JSON.stringify(update)
  });
  if (!patchRes.ok) {
    const err = await patchRes.text();
    console.error('[stripe-webhook] Profile PATCH failed:', patchRes.status, err);
  }

  // First purchase → assign founder number atomically
  if (isInitial && status !== 'expired' && status !== 'free') {
    const rpcRes = await fetch(SUPABASE_URL + '/rest/v1/rpc/assign_founding_member_number', {
      method: 'POST',
      headers: {
        apikey: SUPABASE_SERVICE_KEY,
        Authorization: 'Bearer ' + SUPABASE_SERVICE_KEY,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({ p_user_id: resolvedId })
    });
    if (rpcRes.ok) {
      const num = await rpcRes.json();
      console.log('[stripe-webhook] Founder #' + num + ' assigned to', resolvedId);
    } else {
      const err = await rpcRes.text();
      // Cap reached or other error — log but don't fail the webhook
      console.warn('[stripe-webhook] Founder number not assigned:', err);
    }
  }
}

async function updateProStatus(userId, status) {
  const r = await fetch(SUPABASE_URL + '/rest/v1/profiles?id=eq.' + encodeURIComponent(userId), {
    method: 'PATCH',
    headers: {
      apikey: SUPABASE_SERVICE_KEY,
      Authorization: 'Bearer ' + SUPABASE_SERVICE_KEY,
      'Content-Type': 'application/json',
      Prefer: 'return=minimal'
    },
    body: JSON.stringify({ wylde_pro_status: status, updated_at: new Date().toISOString() })
  });
  if (!r.ok) console.error('[stripe-webhook] Status update failed:', r.status);
}
