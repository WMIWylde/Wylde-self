# Wylde Self — Founding Member Paywall Setup

This is the external setup work you need to do to flip the paywall from STUB mode (simulated purchases) to LIVE mode (real money). All the code is already built — these are the accounts, products, and config values that have to live outside the codebase.

**Estimated time: 3–4 hours of your work, spread over a few days while Apple/Stripe approvals happen.**

---

## Overview of what's wired

```
   iOS app                         Web app
       │                              │
   PaywallView                    /paywall (TBD next phase)
       │                              │
   PurchaseManager ──┐         ┌── /api/stripe/checkout (TBD)
                     │         │
                     ▼         ▼
              RevenueCat ◄─── Stripe
                     │         │
                     └────┬────┘
                          ▼
            /api/revenuecat-webhook  (already built)
                          │
                          ▼
              Supabase profiles table
              (wylde_pro_status, founding_member_number)
```

---

## Step 1 — Run the Supabase migration (5 min)

Open Supabase → your project → SQL Editor → New query.

Paste the contents of `/supabase/migrations/20260427_pro_entitlements.sql` and run it.

Verify:
```sql
SELECT * FROM founder_count;
-- Should return: total_founders=0, founder_cap=1000, spots_remaining=1000
```

---

## Step 2 — Apple Developer Program (1–2 days for approval)

If you don't have it yet:

1. Go to https://developer.apple.com/programs/
2. Enroll as an individual or organization ($99/year)
3. Wait for Apple to approve (usually 24–48 hours)

Once approved, in App Store Connect:

1. **Create a new app** at https://appstoreconnect.apple.com → My Apps → +
2. **Bundle ID:** `com.wylde.self` (or similar — must be unique). This must match what you set in Xcode → WyldeSelf target → General → Bundle Identifier
3. Fill in the basics: name (Wylde Self), primary language, SKU

---

## Step 3 — In-App Purchase products (30 min + Apple approval ~24 hr)

In App Store Connect → your app → Monetization → In-App Purchases → +

Create THREE products. Use these EXACT product IDs (they must match `WyldeProduct` enum in `PurchaseManager.swift`):

| Product ID | Type | Reference Name | Price |
|---|---|---|---|
| `com.wylde.self.lifetime.founder` | Non-Consumable | Wylde Lifetime (Founder) | $149 (Tier 149) |
| `com.wylde.self.annual.founder` | Auto-Renewable Subscription | Wylde Annual (Founder) | $79/year (Tier 79) |
| `com.wylde.self.monthly.founder` | Auto-Renewable Subscription | Wylde Monthly (Founder) | $9.99/month (Tier 10) |

For the two subscriptions:
- Create a **Subscription Group** called "Wylde Pro"
- Both subscriptions go in the same group (so users can switch between annual/monthly without double-billing)

**Localization:** Add at least English. Display name: "Wylde Lifetime / Annual / Monthly". Description: "Founding member pricing. Locked in forever."

**Review information:** Apple will reject if missing. Add screenshot of paywall + a note: "This is a founding member offer for our wellness/fitness app. Users get lifetime or recurring access to the full app."

Apple takes ~24 hours to approve each IAP product the first time.

---

## Step 4 — RevenueCat (30 min)

1. Sign up at https://app.revenuecat.com (free up to $2.5k MTR)
2. Create a new project: "Wylde Self"
3. Add an iOS app — paste your bundle ID (`com.wylde.self`)
4. Connect your App Store Connect account:
   - **App-Specific Shared Secret:** in App Store Connect → Apps → your app → App Information → App-Specific Shared Secret → Manage. Copy the value.
   - Paste into RevenueCat → Project Settings → Apple App Store → App-Specific Shared Secret
5. Create your **Entitlement**:
   - Project → Entitlements → + New Entitlement
   - Identifier: **`wylde_pro`** (must match string in `PurchaseManager.entitlementFrom()`)
6. Create your **Products** in RevenueCat (these mirror App Store Connect):
   - Project → Products → + New Product
   - Add all three: `com.wylde.self.lifetime.founder`, `com.wylde.self.annual.founder`, `com.wylde.self.monthly.founder`
   - Attach all three to the `wylde_pro` entitlement
7. Create your **Offering**:
   - Project → Offerings → + New Offering
   - Identifier: `default`
   - Add three packages:
     - `$rc_lifetime` → lifetime founder product
     - `$rc_annual` → annual founder product
     - `$rc_monthly` → monthly founder product
8. Get your **API key**:
   - Project Settings → API Keys → Public Apple SDK Key
   - Copy it

---

## Step 5 — Add RevenueCat SDK to the iOS app (10 min)

In Xcode:

1. Open `WyldeSelf.xcodeproj`
2. File → Add Package Dependencies…
3. Paste: `https://github.com/RevenueCat/purchases-ios`
4. Choose "Up to Next Major Version" (current latest is 5.x)
5. Add `RevenueCat` to the WyldeSelf target

In `Info.plist` (right-click → Open As → Source Code), add:

```xml
<key>WyldeRevenueCatAPIKey</key>
<string>PASTE_YOUR_REVENUECAT_PUBLIC_API_KEY_HERE</string>
```

In `PurchaseManager.swift`:

1. Uncomment the `import RevenueCat` line at the top
2. Find the line `private let useRealRevenueCat = false` and change to `true`
3. Uncomment all the `// REAL:` blocks (and comment out the `// STUB:` blocks if you want)
4. Uncomment the `entitlementFrom(_ info: CustomerInfo)` function

Build the iOS app. Should compile cleanly.

---

## Step 6 — Configure the RevenueCat webhook (10 min)

1. RevenueCat → Project Settings → Integrations → Webhooks → + Add Webhook
2. Webhook URL: `https://wyldeself.com/api/revenuecat-webhook`
3. Generate an authorization header secret (any random string; save it)
4. Add ALL events (or at minimum: INITIAL_PURCHASE, RENEWAL, CANCELLATION, EXPIRATION, BILLING_ISSUE, PRODUCT_CHANGE)

In Vercel (your hosting for the Wylde Self web app):

1. Go to your project → Settings → Environment Variables
2. Add:
   - `SUPABASE_URL` = your Supabase project URL (you probably already have this)
   - `SUPABASE_SERVICE_KEY` = your Supabase **service_role** key (NOT the anon key — service_role can write to profiles). Find at Supabase → Project Settings → API → service_role
   - `REVENUECAT_WEBHOOK_SECRET` = the random string you generated above
3. Redeploy your Vercel project so the new env vars take effect

Test the webhook: in RevenueCat → Webhooks → click the … menu → "Send test event". Should see 200 in Vercel logs.

---

## Step 7 — Test in sandbox (30 min)

1. In App Store Connect → Users and Access → Sandbox Testers → + Add a sandbox test account (use a fresh email, not your real Apple ID)
2. On your test iPhone: Settings → App Store → Sandbox Account → Sign In with the sandbox tester
3. Build & run the app on the device
4. Tap "Become a Founding Member" CTA on Today
5. Tap a price tier → "Become a Founding Member" → Apple's IAP sheet appears
6. Use Touch ID / Face ID / password — sandbox transactions are free
7. Verify:
   - Thank-you sheet appears with founding member number
   - Supabase profile row updated: `wylde_pro_status = 'lifetime'`, `founding_member_number = 1`, `pro_provider = 'apple'`
   - RevenueCat dashboard shows the test transaction

---

## Step 8 — Submit for App Review (1–7 days)

When you're ready to ship:

1. Take screenshots: 6.7" iPhone, 6.5" iPhone, 5.5" iPhone, iPad if supporting
2. Write app description + keywords + categories in App Store Connect
3. Add Privacy Policy URL — required. If you don't have one, generate at https://www.privacypolicies.com/
4. Build → Archive in Xcode → Upload to App Store Connect
5. Select build in App Store Connect → Submit for Review
6. Apple reviews in 24h–7 days. They will test the IAP. Make sure sandbox tests pass before submitting.

---

## What's NOT in this phase (deferred to later)

- **Web Stripe integration** — currently the founder offer is iOS-only. Web Stripe is the next phase.
- **Hard paywall gates** — Coach 4th-message lock, Future Self generate lock, etc. Not built yet. Right now the paywall is opt-in only.
- **Trial mechanics** — no 7-day trial yet. Founders just buy.
- **Standard tier products** — only founder products exist. Standard tier ($249 / $99 / $14.99) gets added when we hit 1,000 founders.

---

## Troubleshooting

**Paywall opens but no products show prices**
→ Check that products are approved in App Store Connect (status: "Ready to Submit" or "Approved"). RevenueCat will only return products Apple has approved.

**Purchase succeeds but Supabase doesn't update**
→ Check Vercel logs for `/api/revenuecat-webhook`. Most likely cause: `SUPABASE_SERVICE_KEY` is wrong (using anon key instead of service_role).

**"No app_user_id" in webhook logs**
→ You need to log in the user when calling `Purchases.configure()`. Pass `appUserID: supabaseUserID` — currently set up in `PurchaseManager.configure(supabaseUserID:)`. Make sure WyldeSelfApp passes the actual Supabase user UUID once auth is wired.

**Founder counter shows 0 in production**
→ Check Supabase: `SELECT COUNT(*) FROM profiles WHERE founding_member_number IS NOT NULL;`. If 0 in DB but > 0 elsewhere, RPC `assign_founding_member_number` may not have been called. Webhook calls it on INITIAL_PURCHASE only.

**Apple rejects the app**
→ Most common reason: paywall doesn't have a clear "Restore Purchases" button (already built into PaywallView), or missing privacy policy link.
