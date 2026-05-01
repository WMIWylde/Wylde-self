# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Is

Wylde Self is an identity-based transformation app — not a fitness tracker. The product is built around the principle that the user is becoming someone, and every surface reinforces that identity. Brand position: Whoop + Levels + Calm + high-end men's initiation container.

**Voice:** Grounded, direct, masculine but not aggressive, no fluff, no emojis.

## Architecture

**Hybrid app — three layers:**

1. **Web SPA** (`app.html`) — Single-file vanilla HTML/CSS/JS (~11k lines), no framework, no bundler. Deployed on Vercel at `wyldeself.com/app.html`. Contains all screens: Today, Coach, Progress, Future Self, Library, Workouts, Nutrition, Settings.

2. **Native iOS shell** (`WyldeSelf-iOS/`) — SwiftUI. Today + Exercise Library are native Swift views. Future/Coach/Progress are WKWebViews wrapping `app.html` paths (auto-updated on Vercel deploy). `AppState` is the single ObservableObject for all state.

3. **Serverless API** (`api/`) — Vercel Node.js functions. No Express, no framework — each file exports a handler. Functions reference env vars set in Vercel dashboard, not `.env` files.

**Database:** Supabase (auth via magic link, profiles, workouts, food_logs, badges, identity profiles, push subscriptions). Schema migrations in `supabase/migrations/`.

**No build step.** Static HTML files served at URL root. `vercel --prod` deploys everything. Vercel also auto-deploys on push to `main`.

## Common Commands

```bash
# Deploy
cd ~/Wylde-self
git push origin main              # triggers Vercel auto-deploy
vercel --prod                     # manual deploy

# Git — clear stale locks before commits (Xcode causes these)
rm -f .git/index.lock .git/HEAD.lock

# Open iOS project
open WyldeSelf-iOS/WyldeSelf.xcodeproj
```

There are no test, lint, or build commands. `package.json` scripts section is empty.

## Deployment

- **Vercel project:** `wyldeself` (under `wilkemitzin-8619s-projects`)
- **Domain:** `wyldeself.com` / `www.wyldeself.com`
- **Git remote:** `https://github.com/WMIWylde/Wylde-self.git`
- **Branch:** `main` (production)
- **Cron:** `/api/cron-push` runs daily at 8am UTC (push notifications)
- `vercel.json` configures function timeouts and `includeFiles` for exercise data

## Key Environment Variables (Vercel Dashboard)

```
ANTHROPIC_API_KEY          — Claude API (Coach, Identity Import)
OPENAI_API_KEY             — OpenAI (workout generation)
GEMINI_API_KEY             — Google Gemini (future-self image gen)
SUPABASE_URL               — Supabase project URL
SUPABASE_SERVICE_KEY       — Supabase service_role key
VAPID_PUBLIC_KEY           — Web push notifications
VAPID_PRIVATE_KEY          — Web push notifications
```

Supabase URL and anon key are also hardcoded in `app.html` (lines ~4433-4434) for client-side auth — this is intentional for the browser client.

## API Functions (`api/`)

| File | Purpose | External Service |
|------|---------|-----------------|
| `anthropic.js` | Claude proxy (Coach voice) | Anthropic |
| `openai.js` | GPT proxy (workout generation) | OpenAI |
| `generate-image.js` | Future-self image generation | Google Gemini |
| `exercises.js` | Exercise search/filter (local DB) | None |
| `exercise-demo.js` | Exercise detail lookup (local DB, RapidAPI fallback) | Optional RapidAPI |
| `identity-analyze.js` | Identity Import — URL fetch + Claude analysis | Anthropic + Supabase |
| `founder-count.js` | Founding member counter | Supabase |
| `cron-push.js` | Scheduled push notifications | Supabase + web-push |
| `send-push.js` | Send individual push notification | web-push |
| `predict-protocol.js` | Protocol outcome prediction | Anthropic + Supabase |
| `protocol-checklist.js` | Protocol dose logging | Supabase |
| `revenuecat-webhook.js` | iOS purchase webhook | Supabase |

## Exercise Data

`data/exercises.json` — 873 exercises with muscles, equipment, level, descriptions. Bundled in both web app (loaded by API functions) and iOS app (`WyldeSelf-iOS/WyldeSelf/exercises.json`). Keep both copies in sync.

## iOS App Structure

- `AppState.swift` — Single source of truth (ObservableObject)
- `MainTabView.swift` — Bottom tab bar (Today, Library, Future, Coach, Progress) + hamburger menu
- `TodayView.swift` — Native Today screen (the most important surface)
- `WebViewScreen.swift` — WKWebView wrapper for hybrid tabs
- `Theme.swift` — Brand colors and design tokens
- `PurchaseManager.swift` — RevenueCat wrapper (currently in stub mode, flip `useRealRevenueCat` when ready)

## Brand Palette (Strict)

```
Background:      #070707
Surface:         #111111 / #161616
Gold accent:     #C8A96E
Sage accent:     #7D9275
Text primary:    #F4F1E8
Text secondary:  #A6A29A
```

No bright colors. No gradients except subtle. No emojis in UI or copy.

## Known Issues & Gotchas

- **Git lock files:** Xcode running in background causes `.git/index.lock` conflicts. Always `rm -f .git/index.lock .git/HEAD.lock` before git operations.
- **Vercel function limit:** Pro plan (no longer Hobby). Was previously limited to 12 functions.
- **`app.html` is massive:** ~11k lines, single file. Edits require care — search for the exact function/section before modifying. Major sections are marked with `═══` comment banners.
- **Coach speaks as the user's future self** — never as "AI assistant." The prompt says "You ARE Future {firstName}."
- **RevenueCat is stub mode** on iOS — purchase UI is built but real SDK isn't wired. When ready, set `useRealRevenueCat = true` in `PurchaseManager.swift`.

## Reference Documentation

- `HANDOFF.md` — Comprehensive project state, architecture decisions, what's shipped vs. stubbed
- `STRIPE_SETUP.md` — Stripe product/webhook configuration
- `PAYWALL_SETUP.md` — iOS RevenueCat setup guide
- `TESTFLIGHT_SUBMISSION.md` — App Store Connect / TestFlight process
