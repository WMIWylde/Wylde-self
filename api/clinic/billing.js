// Clinic billing — /api/clinic/billing
// GET: billing state. POST { action: 'checkout' | 'portal' }.
// Subscriptions via Stripe Checkout; status synced by the webhook.
const Stripe = require('stripe');
const { applyCors, rateLimit, clientIp } = require('../../lib/security');
const { getSupabaseAdmin, requireClinicAccess } = require('../../lib/supabase-admin');

const stripe = process.env.STRIPE_SECRET_KEY ? new Stripe(process.env.STRIPE_SECRET_KEY) : null;

module.exports = async function handler(req, res) {
  if (applyCors(req, res, { methods: 'GET, POST, OPTIONS' })) return;

  const auth = await requireClinicAccess(req, res);
  if (!auth) return;
  const { clinic, clinicianId } = auth;

  const rl = rateLimit({ key: 'clinic-billing', ip: clientIp(req), limit: 10, windowMs: 60000 });
  if (!rl.ok) return res.status(429).json({ error: 'Rate limit exceeded' });

  if (req.method === 'GET') {
    return res.status(200).json({
      billing_status: clinic.billing_status || 'comped',
      period_end: clinic.billing_period_end || null,
      has_subscription: Boolean(clinic.stripe_subscription_id),
      price_configured: Boolean(process.env.STRIPE_CLINIC_PRICE_ID),
    });
  }

  if (req.method === 'POST') {
    if (!stripe) return res.status(500).json({ error: 'Billing not configured' });
    const { action } = req.body || {};
    const supabase = getSupabaseAdmin();

    try {
      if (action === 'checkout') {
        if (!process.env.STRIPE_CLINIC_PRICE_ID) {
          return res.status(500).json({ error: 'Subscription price not configured yet' });
        }
        const session = await stripe.checkout.sessions.create({
          mode: 'subscription',
          line_items: [{ price: process.env.STRIPE_CLINIC_PRICE_ID, quantity: 1 }],
          client_reference_id: clinicianId,
          metadata: { type: 'clinic_subscription', clinician_id: clinicianId },
          subscription_data: { metadata: { clinician_id: clinicianId } },
          success_url: 'https://www.wyldeself.com/clinical-dashboard?billing=success',
          cancel_url: 'https://www.wyldeself.com/clinical-dashboard?billing=cancelled',
          ...(clinic.stripe_customer_id ? { customer: clinic.stripe_customer_id } : {}),
        });
        return res.status(200).json({ url: session.url });
      }

      if (action === 'portal') {
        if (!clinic.stripe_customer_id) {
          return res.status(400).json({ error: 'No billing account yet — subscribe first' });
        }
        const portal = await stripe.billingPortal.sessions.create({
          customer: clinic.stripe_customer_id,
          return_url: 'https://www.wyldeself.com/clinical-dashboard',
        });
        return res.status(200).json({ url: portal.url });
      }

      return res.status(400).json({ error: 'action must be checkout or portal' });
    } catch (err) {
      console.error('[clinic/billing]', err.message);
      return res.status(500).json({ error: 'Billing operation failed' });
    }
  }

  return res.status(405).json({ error: 'Method not allowed' });
};
