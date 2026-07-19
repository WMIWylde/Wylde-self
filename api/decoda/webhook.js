// POST /api/decoda/webhook — receives Decoda webhook events.
// Verifies HMAC-SHA256 signature (Decoda-Signature header) against
// DECODA_WEBHOOK_SECRET over the RAW body. Idempotent via decoda_webhook_events.
// Handles PATIENT_CREATED / PATIENT_UPDATED → auto-link to Wylde user by email.
const crypto = require('crypto');
const { getSupabaseAdmin } = require('../../lib/supabase-admin');

const WEBHOOK_SECRET = process.env.DECODA_WEBHOOK_SECRET || '';

function readRawBody(req) {
  return new Promise((resolve, reject) => {
    const chunks = [];
    req.on('data', (c) => chunks.push(Buffer.isBuffer(c) ? c : Buffer.from(c)));
    req.on('end', () => resolve(Buffer.concat(chunks)));
    req.on('error', reject);
  });
}

function verifySignature(rawBody, signature) {
  if (!signature) return false;
  // Tolerate "sha256=<hex>" scheme prefixes
  const sig = String(signature).replace(/^sha256=/i, '').trim();
  const expected = crypto.createHmac('sha256', WEBHOOK_SECRET).update(rawBody).digest('hex');
  const a = Buffer.from(sig);
  const b = Buffer.from(expected);
  return a.length === b.length && crypto.timingSafeEqual(a, b);
}

function findSignatureHeader(headers) {
  const candidates = ['decoda-signature', 'x-decoda-signature', 'x-signature', 'x-webhook-signature', 'signature'];
  for (const c of candidates) if (headers[c]) return headers[c];
  return null;
}

module.exports = async function handler(req, res) {
  if (req.method !== 'POST') return res.status(405).json({ error: 'Method not allowed' });
  if (!WEBHOOK_SECRET) {
    console.error('[decoda/webhook] DECODA_WEBHOOK_SECRET not set — refusing to run');
    return res.status(500).json({ error: 'Server misconfigured' });
  }

  const rawBody = await readRawBody(req);
  const signature = findSignatureHeader(req.headers);
  if (!verifySignature(rawBody, signature)) {
    console.error('[decoda/webhook] signature failed. sig header present:', Boolean(signature),
      'headers:', Object.keys(req.headers).join(','));
    return res.status(401).json({ error: 'Invalid signature' });
  }

  let event;
  try { event = JSON.parse(rawBody.toString('utf8')); }
  catch { return res.status(400).json({ error: 'Invalid JSON' }); }

  const supabase = getSupabaseAdmin();

  try {
    // Idempotency: insert event id; duplicate = already processed.
    const { error: dupErr } = await supabase
      .from('decoda_webhook_events')
      .insert({ event_id: event.id, event_type: event.type });
    if (dupErr && dupErr.code === '23505') {
      return res.status(200).json({ status: 'duplicate', event_id: event.id });
    }

    if (event.type === 'PATIENT_CREATED' || event.type === 'PATIENT_UPDATED') {
      const p = event.data || {};
      if (p.email) {
        const { data: profile } = await supabase
          .from('profiles')
          .select('id')
          .ilike('email', p.email)
          .maybeSingle();
        if (profile) {
          await supabase.from('decoda_links').upsert(
            {
              user_id: profile.id,
              decoda_patient_id: p.id,
              linked_at: new Date().toISOString(),
              source: 'webhook',
            },
            { onConflict: 'user_id' }
          );

          // Auto-onboard: creating the patient in Decoda IS the clinic
          // connection — no invite code needed for Decoda clinics.
          const clinicianId = process.env.DECODA_CLINICIAN_ID;
          if (clinicianId) {
            const { data: existingRel } = await supabase
              .from('care_relationships')
              .select('id')
              .eq('patient_id', profile.id)
              .eq('clinician_id', clinicianId)
              .maybeSingle();
            if (!existingRel) {
              await supabase.from('care_relationships').insert({
                patient_id: profile.id,
                clinician_id: clinicianId,
                clinic_name: process.env.DECODA_CLINIC_NAME || 'Decoda Clinic',
                status: 'active',
                linked_at: new Date().toISOString(),
              });
            }
          }
        }
      }
    }

    return res.status(200).json({ status: 'success', event_id: event.id });
  } catch (err) {
    console.error('[decoda/webhook]', err.message);
    // 200 to avoid retries for app-level errors (Decoda retries on non-2xx)
    return res.status(200).json({ status: 'error', event_id: event && event.id });
  }
};

// Signature verification needs the raw body.
module.exports.config = { api: { bodyParser: false } };
