# Wylde Self — Stripe Founding Member Checkout Setup

The Stripe wire-up is in the codebase. To go live, you need to do this once. Should take about **30 minutes**.

---

## Step 1 — Create a Stripe account (5 min)

1. Go to https://dashboard.stripe.com/register
2. Sign up + verify your email
3. Activate your account (provides bank for payouts)
   - You can use **test mode** before activating for sandbox testing
   - Activation takes a few hours after submitting business info

---

## Step 2 — Create the 3 founder products (10 min)

In Stripe Dashboard → Products → + Create product. Create THREE:

### A. Wylde Lifetime (Founder)
- **Name:** Wylde Lifetime — Founding Member
- **Description:** Lifetime access to Wylde Self. Founder pricing locked.
- **Image:** upload your app icon (1024×1024)
- **Pricing:**
  - One-time
  - $149.00 USD
- After creating, copy the **Price ID** (looks like `price_1Q5xK7...`). Save for Step 4.

### B. Wylde Annual (Founder)
- **Name:** Wylde Annual — Founding Member
- **Description:** Yearly access at founder pricing, locked forever.
- **Pricing:**
  - Recurring → Yearly
  - $79.00 USD
- Copy the **Price ID**.

### C. Wylde Monthly (Founder)
- **Name:** Wylde Monthly — Founding Member
- **Description:** Monthly access at founder pricing, locked forever.
- **Pricing:**
  - Recurring → Monthly
  - $9.99 USD
- Copy the **Price ID**.

---

## Step 3 — Get your API keys (2 min)

In Stripe Dashboard → Developers → API keys:
- Copy **Publishable key** (`pk_live_...` or `pk_test_...`) — actually NOT used by our backend, just for reference
- Copy **Secret key** (`sk_live_...` or `sk_test_...`) — this is the one we need

⚠️ Keep the secret key secret. Never commit it to git. It only goes in Vercel env vars.

---

## Step 4 — Set Vercel env vars (5 min)

Vercel Dashboard → your project → Settings → Environment Variables. Add:

| Name | Value | Environment |
|---|---|---|
| `STRIPE_SECRET_KEY` | `sk_live_...` (or `sk_test_...` for testing) | Production + Preview |
| `STRIPE_PRICE_LIFETIME_FOUNDER` | `price_...` from Step 2A | Production + Preview |
| `STRIPE_PRICE_ANNUAL_FOUNDER` | `price_...` from Step 2B | Production + Preview |
| `STRIPE_PRICE_MONTHLY_FOUNDER` | `price_...` from Step 2C | Production + Preview |

(Leave `STRIPE_WEBHOOK_SECRET` empty for now — we set it in Step 5.)

After adding, **redeploy** so the new env vars take effect.

---

## Step 5 — Configure the webhook (5 min)

Stripe Dashboard → Developers → Webhooks → + Add endpoint:

- **Endpoint URL:** `https://wyldeself.com/api/stripe-webhook`
- **Events to send:**
  - `checkout.session.completed`
  - `invoice.paid`
  - `customer.subscription.updated`
  - `customer.subscription.deleted`
- **Save**

After creating, click into the webhook → reveal **Signing secret** (`whsec_...`). Copy it.

Add to Vercel env vars:

| Name | Value |
|---|---|
| `STRIPE_WEBHOOK_SECRET` | `whsec_...` |

**Redeploy** Vercel.

---

## Step 6 — Test in sandbox (5 min)

1. Confirm you're using `sk_test_...` and `whsec_...` for the test endpoint
2. Open `https://wyldeself.com/founder.html`
3. Pick a tier → enter your email → tap "Become a Founding Member"
4. Stripe-hosted checkout opens
5. Use test card: **4242 4242 4242 4242**, any future expiry, any 3-digit CVC
6. Complete payment
7. You should land on `/founder.html?success=true&session_id=...` with the founder number displayed

Then verify on the backend:
```sql
-- In Supabase SQL editor:
SELECT id, email, wylde_pro_status, founding_member_number, pro_provider, pro_started_at
FROM profiles
WHERE email = 'your-test-email@example.com';
```
Should show: `wylde_pro_status = lifetime`, `pro_provider = stripe`, `founding_member_number = 1` (or higher).

Also check Stripe Dashboard → Events to confirm the webhook fired (200 response).

---

## Step 7 — Go live (when ready)

1. In Stripe Dashboard, switch from **Test mode** → **Live mode** (toggle in left sidebar)
2. Re-create the 3 products in live mode (test products don't carry over)
3. Get the **live** Secret key (`sk_live_...`) and webhook secret (`whsec_...`)
4. Update Vercel env vars with live values
5. Update the webhook endpoint to point at your prod domain (already set if using wyldeself.com)
6. Redeploy

That's it. Real money flows now.

---

## Sending the founder offer to your contacts

Direct link: `https://wyldeself.com/founder.html`

Pre-selected tier links (skip user picking):
- Lifetime: `https://wyldeself.com/founder.html?tier=lifetime`
- Annual: `https://wyldeself.com/founder.html?tier=annual`
- Monthly: `https://wyldeself.com/founder.html?tier=monthly`

Suggested outreach (steal/edit):

> Building a thing called Wylde Self — the version of you that follows through.
> Active beta now, full launch in a few weeks. First 1,000 people who fund the work get lifetime access at founder pricing.
>
> [Lock in Founder Lifetime ($149)](https://wyldeself.com/founder.html?tier=lifetime) — never pay again.
>
> Or just install the iOS beta when it's live and decide later.

---

## Money math

Per founder sale via Stripe:

| Tier | Price | Stripe fee (2.9% + $0.30) | You receive |
|---|---|---|---|
| Lifetime | $149 | $4.62 | **$144.38** |
| Annual | $79 | $2.59 | **$76.41** |
| Monthly | $9.99 | $0.59 | **$9.40/mo** |

vs Apple iOS (15% Small Business cut after qualifying):

| Tier | iOS Price | Apple cut | You receive |
|---|---|---|---|
| Annual | $99 | $14.85 | $84.15 |
| Monthly | $12.99 | $1.95 | $11.04/mo |

So web wins margin AND user-pays-less for every sale. Just can't promote it inside iOS app (Apple anti-steering rules).

---

## Troubleshooting

**Webhook returns 400 "Invalid signature"**
→ `STRIPE_WEBHOOK_SECRET` doesn't match the secret in Stripe Dashboard. Re-copy + redeploy Vercel.

**Profile doesn't get updated after purchase**
→ Check Vercel logs: `Vercel → Project → Functions → /api/stripe-webhook`. Most common cause: `SUPABASE_SERVICE_KEY` is wrong (using anon key instead of service_role).

**"Price ID not configured" error**
→ One of the `STRIPE_PRICE_*_FOUNDER` env vars isn't set or has a typo. They start with `price_`, NOT `prod_`.

**Counter shows wrong number**
→ Check Supabase: `SELECT COUNT(*) FROM profiles WHERE founding_member_number IS NOT NULL;`. The webhook calls `assign_founding_member_number` RPC on first purchase. If RPC fails, check that you ran the migration `supabase/migrations/20260427_pro_entitlements.sql`.

**Test purchase succeeds but no email/access**
→ The webhook needs to find the user by email. Make sure the test email exists in `profiles` table (they need to have signed up first), or pass `user_id` from the Wylde app context when invoking checkout.

---

## Architecture reference

```
User taps "Become a Founding Member"
  ↓
/founder.html (or app.html → openFounderPaywall())
  ↓ POST /api/stripe-checkout {tier, email}
  ↓
Stripe creates Checkout Session
  ↓ returns session.url
  ↓
Browser redirects to Stripe-hosted checkout
  ↓ user enters card, pays
  ↓
Stripe redirects to /founder.html?success=true
  ↓
Stripe also fires webhook → /api/stripe-webhook
  ↓
Webhook: verify signature → upsert profiles row → assign founding number
  ↓
Supabase profiles updated:
  wylde_pro_status = 'lifetime'
  founding_member_number = N
  pro_provider = 'stripe'
  pro_stripe_id = cus_...
```

Same `wylde_pro_status` field is also used by the iOS RevenueCat webhook, so the entitlement is unified across platforms.
