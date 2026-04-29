// /api/stripe-checkout
// ────────────────────────────────────────────────────────────────────
//   Creates a Stripe Checkout Session for the founding member offer.
//
//   POST body:
//     { tier: 'lifetime'|'annual'|'monthly',  user_id?: string,
//       email?: string,  return_origin?: string }
//
//   Returns: { url: string } — the Stripe-hosted checkout URL.
//   Frontend redirects window.location to that URL.
//
//   After payment, Stripe redirects back to:
//     {return_origin or wyldeself.com}/founder.html?session_id={CHECKOUT_SESSION_ID}&success=true
//
//   The webhook (api/stripe-webhook.js) handles the actual entitlement
//   write to Supabase. This endpoint just creates the session.
// ────────────────────────────────────────────────────────────────────

const STRIPE_SECRET = process.env.STRIPE_SECRET_KEY || '';

// Price IDs — set these in Vercel env vars after creating products in
// Stripe dashboard. The format is `price_XXXX...`.
const PRICE_LIFETIME = process.env.STRIPE_PRICE_LIFETIME_FOUNDER || '';
const PRICE_ANNUAL   = process.env.STRIPE_PRICE_ANNUAL_FOUNDER   || '';
const PRICE_MONTHLY  = process.env.STRIPE_PRICE_MONTHLY_FOUNDER  || '';

const DEFAULT_ORIGIN = 'https://wyldeself.com';

module.exports = async function handler(req, res) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');
  if (req.method === 'OPTIONS') return res.status(200).end();
  if (req.method !== 'POST') return res.status(405).json({ error: 'Method not allowed' });

  if (!STRIPE_SECRET) {
    return res.status(500).json({
      error: 'Stripe not configured (set STRIPE_SECRET_KEY in Vercel env)'
    });
  }

  const body = req.body || {};
  const tier = String(body.tier || '').toLowerCase();
  const userId = body.user_id ? String(body.user_id) : null;
  const email  = body.email   ? String(body.email)   : null;
  const origin = String(body.return_origin || DEFAULT_ORIGIN).replace(/\/$/, '');

  // Map tier → Stripe price ID + mode (one-time vs subscription)
  const tierMap = {
    lifetime: { priceId: PRICE_LIFETIME, mode: 'payment' },
    annual:   { priceId: PRICE_ANNUAL,   mode: 'subscription' },
    monthly:  { priceId: PRICE_MONTHLY,  mode: 'subscription' }
  };
  const cfg = tierMap[tier];
  if (!cfg) {
    return res.status(400).json({ error: 'Invalid tier (use lifetime|annual|monthly)' });
  }
  if (!cfg.priceId) {
    return res.status(500).json({
      error: 'Price ID not configured for tier ' + tier + ' (set STRIPE_PRICE_' + tier.toUpperCase() + '_FOUNDER in Vercel env)'
    });
  }

  // Lazy-load Stripe so the module isn't required when Stripe isn't configured
  let stripe;
  try {
    stripe = require('stripe')(STRIPE_SECRET, { apiVersion: '2024-09-30.acacia' });
  } catch (e) {
    return res.status(500).json({ error: 'Stripe SDK not installed: ' + e.message });
  }

  // Build the session
  try {
    const session = await stripe.checkout.sessions.create({
      mode: cfg.mode,
      line_items: [{ price: cfg.priceId, quantity: 1 }],

      // Bring back to a thank-you page on our site
      success_url: origin + '/founder.html?success=true&session_id={CHECKOUT_SESSION_ID}',
      cancel_url:  origin + '/founder.html?canceled=true',

      // Apple-style branding cues
      allow_promotion_codes: true,
      automatic_tax: { enabled: false },

      // Pre-fill email if known so user doesn't have to retype
      customer_email: email || undefined,

      // Critical — these flow into Stripe's metadata and back to our webhook
      // so we can match the payment to the right Supabase user + tier.
      client_reference_id: userId || undefined,
      metadata: {
        wylde_tier: tier,
        wylde_user_id: userId || '',
        wylde_offer:  'founding_member_v1'
      },

      // For subscription tiers, also persist metadata on the subscription
      // itself so renewal events carry context too.
      subscription_data: cfg.mode === 'subscription' ? {
        metadata: {
          wylde_tier: tier,
          wylde_user_id: userId || '',
          wylde_offer:  'founding_member_v1'
        }
      } : undefined,

      // Conservative payment method types — cards + Apple Pay/Google Pay (auto)
      payment_method_types: ['card']
    });

    return res.status(200).json({
      url: session.url,
      session_id: session.id
    });
  } catch (e) {
    console.error('[stripe-checkout] Session create failed:', e);
    return res.status(500).json({ error: 'Couldn’t create checkout session', detail: e.message });
  }
};
