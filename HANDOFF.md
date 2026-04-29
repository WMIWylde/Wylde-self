# Wylde Self — Handoff

Last updated: 2026-04-28

This is the single document that gets a new collaborator (or future-you after time off) up to speed on what Wylde Self is, what's been built, what works, what doesn't, and what's next.

---

## What Wylde Self is

An identity-based transformation app. Not a fitness tracker. The product is built around the principle that the user is becoming someone — and every surface should reinforce that identity.

**Brand position:** Whoop + Levels + Calm + a high-end men's initiation container.

**Voice:** Grounded, direct, masculine but not aggressive, no fluff, no emojis.

**Core loop:**
User opens Today → feels identity shift → takes one action → loops back tomorrow.

---

## Stack

| Layer | What |
|---|---|
| **Web app** | `app.html` (single-file, ~10k lines), deployed on Vercel at wyldeself.com |
| **Public paywall** | `founder.html` (standalone page), same Vercel deploy |
| **iOS app** | `WyldeSelf-iOS/` SwiftUI shell. Today + Library are native, Future/Coach/Progress are WKWebViews wrapping app.html paths |
| **API** | Vercel serverless under `/api/` (Anthropic proxy, exercises, identity-analyze, founder-count, RevenueCat webhook, Stripe checkout, Stripe webhook) |
| **Database** | Supabase (auth via magic link, profiles, workouts, food_logs, badges, identity profiles, founder counter, daily walks) |
| **AI** | Claude Haiku 4.5 (`claude-haiku-4-5-20251001`) via `/api/anthropic` |
| **Payments** | RevenueCat → Apple StoreKit (iOS), Stripe Checkout (web) |
| **Image gen** | Gemini 2.5 Flash via `/api/generate-image` |
| **Exercise data** | 873 exercises in `data/exercises.json`, also bundled in iOS app |

### Brand palette (strict)
- Background `#070707`
- Surface `#111111` / `#161616`
- Gold accent `#C8A96E`
- Sage accent `#7D9275`
- Text primary `#F4F1E8`
- Text secondary `#A6A29A`
- No bright colors. No gradients except subtle. No emojis.

---

## Major systems shipped

### Today screen (most important surface)
Cinematic stacked journey, top to bottom:
- Header with greeting + streak badge
- Hero card: "Day X of Y" + identity statement + single primary CTA "Enter Today's Training"
- Morning Routine — 3 fixed practices (Meditation, Journaling, Reading), checkmark each
- Today's Training (workout)
- Walk reminder
- 3-ring Nutrition card (Calories / Protein / Carbs) — animated SVG rings, live-syncs with food log
- Health snapshot (HealthKit on iOS)
- Coach access ("Talk to your future self")
- Daily Closeout — "Close the Loop" gold CTA
- Founding Member CTA (only if not Pro)

Animations: staggered fade-up on first appearance, spring on toggles, 3-ring fill animation on update.

### Coach
- Speaks AS user's literal future self ("Future Wilke" not "AI coach")
- 280 max_tokens, hard format rules: 2–4 sentences, no bullets, no meta-talk, no emojis
- Occasional single-line science callout (~1 in 4)
- 4 quick actions: Motivate me / Fix my plan / I'm off track / Optimize everything
- Pulls full user context (PRs, streak, sleep, walks, vibes, identity profile, phase) into every prompt
- Identity language cue: when user has set gender, mirrors their natural phrasing

### Identity Import (Founding Members feature)
- User pastes public URLs (bio, posts, Substack, etc.) or raw text
- `/api/identity-analyze` server-side fetches URLs (SSRF-hardened) + sends to Claude
- Claude returns structured JSON: archetype, confidence, tone, motivation triggers, limiting patterns, language to use/avoid, coaching style, discipline level
- Stored in `user_identity_profile` Supabase table
- Coach + meal planner pull this profile and mirror the user's actual voice
- Tested live: model identified "The Architect" archetype, mirrored phrasing like "act like her", "the silence", "stop negotiating"

### Phase progression (replaces stripped Ember/Spark/Flame ladder)
Driven by sessions completed, not XP grind:
- Initiate (0)    — "You stepped onto the path. Now keep walking."
- Foundation (10) — "The first layer is laid. The work is becoming yours."
- Embodied (30)   — "It's no longer trying — it's who you are."
- Relentless (100)— "You don't negotiate with yourself anymore."
- Integrated (300)— "You and the practice are the same thing now."

### Badges (29 across 6 categories)
- Streaks (3, 7, 14, 21, 30, 100, 365 days)
- Sessions (1, 10, 50, 100, 500)
- Practice — mornings (1, 7, 30, 100), walks (1, 7, 30, 100)
- Strength — PRs (1, 10, 50)
- Nutrition — meals logged (1, 30, 100)
- Reflection — feel-prompts logged (1, 7, 30)

Each badge uses a custom SVG glyph (lucide-style, no emojis). Locked badges greyscaled at 45% opacity.

### Library (Exercise browser)
873 exercises native iOS + web. Body-part chips, search, exercise cards with image thumbnails. YouTube tutorial deep-link button on detail view.

### Set logger
- PR + Last Weight reference cards above the set rows
- +/- steppers (weight 5lb, reps 1)
- Per-set sage checkmark on log
- Workout finale feel-prompt: 1/2/3/4 with labels Brutal/Off/Solid/Dialed
- Food feel buttons inline next to logged foods: + / – / ×

### Founding Member paywall
**Pricing:** Lifetime $149 / Annual $79 / Monthly $9.99 (founder, locked forever for first 1,000)
**Standard** (post-founder cap): $249 / $99 / $14.99

- iOS: native `PaywallView` (RevenueCat in stub mode until SDK added)
- Web: `/founder.html` standalone page → Stripe Checkout
- Both webhook into same Supabase profile fields
- Atomic `founding_member_number` assignment via RPC (1-1000)
- Founder counter live-updates across both platforms
- Personalized thank-you sheet shows the founder's number

### Settings drawer
Left-slide hamburger on every screen (web + iOS). Lists Exercise Library, Nutrition, Identity Import, Edit Profile, Rebuild Program, Reset Profile, Sign Out. Founding Member CTA shown if not Pro.

### iOS brand assets bundled
9 imagesets in `Assets.xcassets/`: LogoMark, LogoIcon, HeroBackground, FutureSelfMan, FutureSelfWoman, GlowMale/Female/Neutral, AppInHand. AppIcon set with `Wyldeselflogo2.png` placeholder. AccentColor = brand gold. LaunchBackground = brand bg. Modern UILaunchScreen dict in Info.plist using LogoMark.

### Mobile web polish
- All inputs forced to 16px font-size on mobile (prevents iOS auto-zoom)
- Hamburger respects iOS safe-area-inset-top (notch)
- Bottom nav respects safe-area-inset-bottom (home indicator)
- 3-ring nutrition card responsive at 320px viewport
- Modals fill viewport edge-to-edge with bottom-safe padding
- Settings drawer 92% width on mobile
- All buttons min 44pt tap target (iOS HIG)

### Refresh-restore
URL hash + `localStorage.wylde_last_screen` survive page reload. User refreshing on Coach lands back on Coach instead of Today.

### Identity language rotation
`getIdentityPhrase(context)` returns gendered phrases mixed with neutral pool. Applied to hero, closing, morning protocol, Coach prompt cue. Female users see "the woman you're becoming", male users see "the man you're becoming", unspecified see "the version of you you're becoming". No back-to-back repeats.

### Daily walk reminder
Native iOS UNCalendarNotificationTrigger fires at 1pm. "Time for your walk — 30+ minutes outside. Phone in your pocket."

### Onboarding simplified
Gym equipment picker collapsed from 12 pills → 3 type pills (Commercial / Garage / Bodyweight). AI infers equipment from type. Tap count: 8 → 2.

### Gym location finder (web)
Type-to-search using OpenStreetMap Nominatim (free, no API key). Returns 5 matches with name + address. Saves `gymName`, `gymLat`, `gymLng`, `gymPlaceId`. Foundation for future "members at your gym" community feature.

---

## File map

```
/Wylde-self/
├── app.html                                   ← single-file web app
├── founder.html                               ← public paywall page
├── package.json                               ← dependencies (stripe, supabase, etc.)
├── data/exercises.json                        ← 873 exercises
├── api/
│   ├── anthropic.js                           ← Claude proxy
│   ├── exercises.js                           ← Exercise DB
│   ├── identity-analyze.js                    ← Identity Import
│   ├── founder-count.js                       ← Counter for paywall
│   ├── revenuecat-webhook.js                  ← iOS IAP entitlement sync
│   ├── stripe-checkout.js                     ← Web Checkout Session creator
│   └── stripe-webhook.js                      ← Web Stripe entitlement sync
├── supabase/migrations/
│   ├── 20260427_pro_entitlements.sql          ← Pro fields + founder RPC
│   └── 20260428_identity_profile.sql          ← Identity Import schema
├── WyldeSelf-iOS/
│   └── WyldeSelf/
│       ├── WyldeSelfApp.swift                 ← Main app entry
│       ├── ContentView.swift                  ← Tab routing
│       ├── Info.plist                         ← UILaunchScreen + permissions
│       ├── Assets.xcassets/                   ← AppIcon + brand images
│       ├── Models/
│       │   ├── AppState.swift                 ← Single source of truth
│       │   ├── Exercise.swift
│       │   └── IdentityProfile.swift
│       ├── Services/
│       │   ├── PurchaseManager.swift          ← RevenueCat wrapper (stub mode)
│       │   ├── IdentityAnalysisService.swift
│       │   ├── HealthKitManager.swift
│       │   ├── HapticManager.swift
│       │   ├── NotificationManager.swift
│       │   └── CameraManager.swift
│       ├── Utilities/Theme.swift              ← Brand colors
│       └── Views/
│           ├── MainTabView.swift              ← Bottom tabs + hamburger overlay
│           ├── TodayView.swift                ← Native Today screen
│           ├── ExercisesView.swift            ← Native exercise library
│           ├── WebViewScreen.swift            ← WKWebView wrapper for hybrid tabs
│           ├── PaywallView.swift              ← Native Founding Member paywall
│           ├── SettingsDrawer.swift           ← Native left-slide drawer
│           └── IdentityImportView.swift       ← Native Identity Import
├── HANDOFF.md                                 ← This file
├── PAYWALL_SETUP.md                           ← iOS RevenueCat setup guide
├── STRIPE_SETUP.md                            ← Web Stripe setup guide
└── TESTFLIGHT_SUBMISSION.md                   ← iOS submission guide
```

---

## Pricing decided

| Plan | Founder (first 1,000) | Standard (after) |
|---|---|---|
| Lifetime (web only) | **$149** | $249 |
| Annual web / iOS | **$79 / $99** | $99 / $129.99 |
| Monthly web / iOS | **$9.99 / $12.99** | $14.99 / $19.99 |

**Per founder sale:**
- Web Stripe lifetime $149 → you receive **$144.38** (after 2.9% + $0.30 fee)
- iOS Apple lifetime n/a (subscription only)
- iOS annual $99 → you receive **$84.15** (15% Apple Small Business Program cut)

Web wins margin AND user pays less. Apple anti-steering rules prevent promoting web pricing inside the iOS app — only mention via direct outreach (email/SMS/social).

---

## What's working end-to-end (live verified)

- ✓ Coach API live with future-self voice + user context
- ✓ Identity Import returns valid structured profile
- ✓ 873 exercises returning from `/api/exercises`
- ✓ Web app renders correctly on dark theme
- ✓ Mobile web polish (no iOS input zoom, safe-area aware, responsive cards)
- ✓ Refresh-restore (URL hash + localStorage)
- ✓ Founder counter API
- ✓ All Supabase RPCs work (assign_founding_member_number, etc.)

## What's stub mode (waiting on external setup)

- iOS PaywallView — RevenueCat SDK not added yet, simulates purchases
- Stripe checkout — endpoint exists, needs real Stripe products + env vars
- iOS gym location finder — natural next when native onboarding is built

---

## External setup user must do

### Required for Founder launch
1. **Run Supabase migrations** — paste both `.sql` files in Supabase SQL editor
2. **Stripe** — see `STRIPE_SETUP.md`. Create account, 3 products, get price IDs, set Vercel env vars, configure webhook endpoint
3. **Vercel env vars:**
   - `SUPABASE_URL`, `SUPABASE_SERVICE_KEY` (already set, used by all webhooks)
   - `ANTHROPIC_API_KEY` (already set)
   - `STRIPE_SECRET_KEY`
   - `STRIPE_PRICE_LIFETIME_FOUNDER`
   - `STRIPE_PRICE_ANNUAL_FOUNDER`
   - `STRIPE_PRICE_MONTHLY_FOUNDER`
   - `STRIPE_WEBHOOK_SECRET`
   - `REVENUECAT_WEBHOOK_SECRET` (when iOS goes live)

### Required for App Store / TestFlight
4. **Apple Developer Program** ($99/yr, 24-48hr approval) — user has this
5. **App Store Connect entry** — bundle ID `com.wylde.self`, see `TESTFLIGHT_SUBMISSION.md`
6. **Xcode signing** — Settings & Capabilities → Team + Bundle ID
7. **App Icon** — final 1024×1024 PNG (placeholder is bundled)
8. **Privacy policy URL** — required for App Store
9. **RevenueCat** — see `PAYWALL_SETUP.md`. Create account, entitlement, offering, get API key, add SDK in Xcode, flip `useRealRevenueCat = true`
10. **Sandbox test** — full purchase flow with test card `4242 4242 4242 4242`
11. **TestFlight upload** — Xcode → Archive → Distribute → App Store Connect

### Suggested
- `billing@wyldeself.com` email for Stripe account login (Cloudflare Email Routing free, forwards to your inbox)

---

## Recurring infra issue (the git lock)

The dev sandbox can't unlink `.git/index.lock` due to virtiofs permissions. After every commit attempt by the AI agent, the user must clear it manually before pushing:

```bash
cd ~/Wylde-self
rm -f .git/index.lock .git/HEAD.lock .git/objects/*/tmp_obj_*
git push origin main
```

This is a sandbox quirk, not a bug in the code. Just the workflow.

---

## Decisions made (with reasoning)

- **iOS-first launch, web Stripe in parallel** — TestFlight is the primary milestone; Stripe lets warm contacts buy direct without waiting for App Store review
- **Hybrid app (native shell + WKWebView tabs) approved by Apple** — App provides real native value (Today, Library, Paywall, Identity Import, HealthKit, IAP, push)
- **No emojis anywhere** — initiation container brand
- **Levels stripped, replaced with Phases** — phases reflect identity formation, not video-game tier grinding
- **Morning Protocol locked to 3 fixed practices** (Meditation, Journaling, Reading) — Workout removed from morning, lives in daily routine
- **Walk added as separate daily action** — not part of training, not part of morning ritual
- **Coach speaks AS the user's future self** ("Future Wilke") — not a generic AI assistant
- **Identity Import behind Founding Members paywall** — high-leverage feature gated to drive conversion
- **OpenStreetMap Nominatim for gym search** — free, no API key, fine until 10k DAU
- **Stub-mode RevenueCat in iOS for now** — UI is fully built, swap to live with one config flag
- **Pantry/forum/peptide/advanced protocols hidden** — out of MVP scope, code preserved for later
- **Single hamburger menu on every screen** — settings live there, never in a tab
- **Mobile web is the primary marketing surface** — must be polished even if iOS is the conversion target

---

## Pending / next priorities

- ❑ User: complete Stripe setup + push live
- ❑ User: complete iOS App Store Connect entry + signing
- ❑ User: archive + upload first TestFlight build
- ❑ Coach insight card on Today screen (replaces rejected red-dot pattern from Gemini audit)
- ❑ Native iOS gym finder using MKLocalSearch
- ❑ Native iOS CoachView (replace WebView for full-quality Coach)
- ❑ Native iOS FutureSelfView (currently WebView)
- ❑ Native iOS onboarding (currently WebView)
- ❑ Apple anti-steering compliance audit before App Store submission
- ❑ "Members at your gym" community feature (foundation already in place via gymPlaceId)
- ❑ Coach proactive daily insight push notification

---

## Quick context for the AI agent in future sessions

If you're an AI agent picking this up:

1. **Read this file first.** Then `app.html` and the iOS Views/ folder.
2. **Brand voice is sacred.** Grounded, direct, masculine but not aggressive. No emojis. No fluff. No SaaS clichés. No video-game gamification.
3. **The Coach speaks as the user's future self, not as an AI.** Never break that frame.
4. **Mobile web is critical.** Test every change on a 375px viewport (iPhone SE) before committing.
5. **The git lock issue is recurring.** Don't waste cycles trying to fix it — just commit locally and tell the user to push.
6. **Always commit locally, even if you can't push.** The user will push manually.
7. **iOS WebView tabs DO get web changes automatically** — push to Vercel, WebViews see the update.
8. **Stub mode is fine for now.** Don't try to wire RevenueCat or real Stripe products without the user's API keys.
9. **`HANDOFF.md` should be kept current** as major systems ship.

---

End of handoff.
