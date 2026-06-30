const { applyCors } = require('../../lib/security');
const { getSupabaseAdmin, getUserFromRequest } = require('../../lib/supabase-admin');
const Stripe = require('stripe');

const stripe = process.env.STRIPE_SECRET_KEY ? new Stripe(process.env.STRIPE_SECRET_KEY) : null;

module.exports = async function handler(req, res) {
  if (applyCors(req, res, { methods: 'GET, POST, OPTIONS' })) return;

  const user = await getUserFromRequest(req);
  if (!user) return res.status(401).json({ error: 'Unauthorized' });

  const supabase = getSupabaseAdmin();

  // GET — list patient's reorder requests
  if (req.method === 'GET') {
    const { data } = await supabase
      .from('reorder_requests')
      .select('*, clinic_products(name, category, price, price_unit)')
      .eq('patient_id', user.id)
      .order('created_at', { ascending: false })
      .limit(20);

    return res.status(200).json({ orders: data || [] });
  }

  // POST — create reorder + Stripe checkout session
  if (req.method === 'POST') {
    const { clinic_product_id, prescription_id, quantity, note } = req.body || {};

    if (!clinic_product_id) return res.status(400).json({ error: 'clinic_product_id required' });

    // Get the product
    const { data: product } = await supabase
      .from('clinic_products')
      .select('*')
      .eq('id', clinic_product_id)
      .single();

    if (!product) return res.status(404).json({ error: 'Product not found' });

    // Verify care relationship with this clinician
    const { data: rel } = await supabase
      .from('care_relationships')
      .select('id, clinician_id')
      .eq('patient_id', user.id)
      .eq('clinician_id', product.clinician_id)
      .eq('status', 'active')
      .single();

    if (!rel) return res.status(403).json({ error: 'No active care relationship with this clinic' });

    const qty = quantity || 1;
    const amountCents = Math.round((product.price || 0) * 100 * qty);

    // Create Stripe Checkout Session
    let checkoutSession = null;
    if (amountCents > 0 && stripe) {
      try {
        checkoutSession = await stripe.checkout.sessions.create({
          mode: 'payment',
          line_items: [{
            price_data: {
              currency: 'usd',
              product_data: {
                name: product.name,
                description: `${product.category} · ${product.typical_dose || ''} · ${product.frequency || ''}`.trim(),
              },
              unit_amount: Math.round((product.price || 0) * 100),
            },
            quantity: qty,
          }],
          metadata: {
            patient_id: user.id,
            clinician_id: product.clinician_id,
            product_id: product.id,
          },
          success_url: 'https://www.wyldeself.com/reorder-success?session_id={CHECKOUT_SESSION_ID}',
          cancel_url: 'https://www.wyldeself.com/reorder-cancel',
        });
      } catch (err) {
        console.error('[reorder] Stripe error:', err.message);
        return res.status(500).json({ error: 'Payment setup failed' });
      }
    }

    // Create reorder request in DB
    const { data: order, error } = await supabase
      .from('reorder_requests')
      .insert({
        patient_id: user.id,
        clinician_id: product.clinician_id,
        clinic_product_id: product.id,
        prescription_id: prescription_id || null,
        status: checkoutSession ? 'requested' : 'requested',
        quantity: qty,
        patient_note: note || null,
        stripe_checkout_session_id: checkoutSession?.id || null,
        amount_cents: amountCents,
      })
      .select()
      .single();

    if (error) return res.status(500).json({ error: error.message });

    return res.status(201).json({
      order,
      checkout_url: checkoutSession?.url || null,
    });
  }

  return res.status(405).json({ error: 'Method not allowed' });
};
