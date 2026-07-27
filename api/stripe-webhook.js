// /api/stripe-webhook
// ────────────────────────────────────────────────────────────────────
//   Receives Stripe webhook events and syncs reorder payment state to
//   Supabase. On checkout.session.completed we flip the matching
//   reorder_requests row from 'requested' to 'paid'.
//
//   Auth: Stripe signs each request. We verify the signature against
//   STRIPE_WEBHOOK_SECRET using stripe.webhooks.constructEvent, which
//   requires the RAW (unparsed) request body — so Vercel's body parser
//   is disabled below and we buffer the stream ourselves.
// ────────────────────────────────────────────────────────────────────

const { getSupabaseAdmin } = require('../lib/supabase-admin');
const Stripe = require('stripe');

const stripe = process.env.STRIPE_SECRET_KEY ? new Stripe(process.env.STRIPE_SECRET_KEY) : null;
const WEBHOOK_SECRET = process.env.STRIPE_WEBHOOK_SECRET || '';

function readRawBody(req) {
  return new Promise((resolve, reject) => {
    const chunks = [];
    req.on('data', (chunk) => chunks.push(Buffer.isBuffer(chunk) ? chunk : Buffer.from(chunk)));
    req.on('end', () => resolve(Buffer.concat(chunks)));
    req.on('error', reject);
  });
}

module.exports = async function handler(req, res) {
  if (req.method !== 'POST') return res.status(405).json({ error: 'Method not allowed' });

  if (!stripe) {
    console.error('[stripe-webhook] STRIPE_SECRET_KEY not set — refusing to run');
    return res.status(500).json({ error: 'Server misconfigured' });
  }
  if (!WEBHOOK_SECRET) {
    console.error('[stripe-webhook] STRIPE_WEBHOOK_SECRET not set — refusing to run');
    return res.status(500).json({ error: 'Server misconfigured' });
  }

  let event;
  try {
    const rawBody = await readRawBody(req);
    const sig = req.headers['stripe-signature'];
    event = stripe.webhooks.constructEvent(rawBody, sig, WEBHOOK_SECRET);
  } catch (err) {
    console.warn('[stripe-webhook] Signature verification failed:', err.message);
    return res.status(400).json({ error: `Webhook signature verification failed` });
  }

  try {
    if (event.type === 'checkout.session.completed') {
      const session = event.data.object;
      const supabase = getSupabaseAdmin();

      // Match the reorder by the Checkout Session id stored at creation time
      // (see api/consumer/reorder.js: stripe_checkout_session_id).
      const { data, error } = await supabase
        .from('reorder_requests')
        .update({ status: 'paid' })
        .eq('stripe_checkout_session_id', session.id)
        .eq('status', 'requested')
        .select('id');

      if (error) {
        console.error('[stripe-webhook] Supabase update failed:', error.message);
        return res.status(500).json({ error: 'DB update failed' });
      }

      console.log('[stripe-webhook] checkout.session.completed marked paid for session', session.id, 'rows', data?.length || 0);
      return res.status(200).json({ received: true, updated: data?.length || 0 });
    }

    // ── Clinic subscription lifecycle ──
    if (event.type === 'checkout.session.completed' ||
        event.type === 'customer.subscription.created' ||
        event.type === 'customer.subscription.updated' ||
        event.type === 'customer.subscription.deleted') {
      const obj = event.data.object;
      const clinicianId = (obj.metadata && obj.metadata.clinician_id) ||
                          (obj.subscription_details && obj.subscription_details.metadata && obj.subscription_details.metadata.clinician_id) ||
                          obj.client_reference_id;
      if (clinicianId) {
        const supabase = getSupabaseAdmin();
        const update = {};
        if (event.type === 'checkout.session.completed') {
          update.stripe_customer_id = obj.customer;
          if (obj.subscription) update.stripe_subscription_id = obj.subscription;
          update.billing_status = 'active';
        } else {
          update.stripe_subscription_id = obj.id;
          update.stripe_customer_id = obj.customer;
          update.billing_status = event.type === 'customer.subscription.deleted' ? 'cancelled'
            : (obj.status === 'active' || obj.status === 'trialing') ? obj.status
            : obj.status; // past_due, unpaid, etc. flow through verbatim
          if (obj.current_period_end) update.billing_period_end = new Date(obj.current_period_end * 1000).toISOString();
        }
        const { error: bErr } = await supabase.from('clinic_settings').update(update).eq('clinician_id', clinicianId);
        if (bErr) console.error('[stripe-webhook] clinic billing update failed:', bErr.message);
        else console.log('[stripe-webhook] clinic billing:', event.type, '->', update.billing_status, 'for', clinicianId);
        return res.status(200).json({ received: true, billing: update.billing_status });
      }
    }

    // Acknowledge all other event types without action.
    return res.status(200).json({ received: true, ignored: event.type });
  } catch (err) {
    console.error('[stripe-webhook] Exception:', err);
    return res.status(500).json({ error: err.message });
  }
};

// Disable Vercel's automatic body parsing — signature verification needs the raw body.
module.exports.config = { api: { bodyParser: false } };
