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

    // Acknowledge all other event types without action.
    return res.status(200).json({ received: true, ignored: event.type });
  } catch (err) {
    console.error('[stripe-webhook] Exception:', err);
    return res.status(500).json({ error: err.message });
  }
};

// Disable Vercel's automatic body parsing — signature verification needs the raw body.
module.exports.config = { api: { bodyParser: false } };
