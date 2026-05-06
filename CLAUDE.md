# WyldeSelf

## North Star

WyldeSelf is an AI-guided identity transformation system that helps users become their future self through daily structured actions.

It is the **entry point** into the broader Wylde ecosystem — not a standalone fitness app, not a coaching platform, not a content library.

The promise to the user, every time they open the app:

> *"I am stepping into a higher version of myself."*

Clarity > complexity. Experience > features. Identity shift > information.

---

## Positioning

**WyldeSelf is universal — designed for both men and women.**

The product integrates four pillars:
- Physical fitness
- Mental clarity
- Emotional regulation
- Lifestyle optimization

Tone: grounded, powerful, clean, balanced. Masculine structure + feminine openness. Precision and presence — never dominance or softness alone.

### What WyldeSelf is NOT
- Not a men's coaching app
- Not a multi-coach platform
- Not content-heavy or guru-driven
- Not aggressive, "alpha," or bro-coded
- Not overly spiritual, mystical, or esoteric

### Where Wylde Man fits
Wylde Man is a **specialized program within the Wylde ecosystem** — a deeper masculine track for men who want that specific work. It is not the front door to WyldeSelf and should not influence WyldeSelf's tone, copy, or visual language.

---

## Architecture Mandate

**WyldeSelf iOS is FULLY NATIVE.**

Every screen that defines the brand experience is built in SwiftUI. The web app at wyldeself.com and the iOS app share a backend (Vercel API endpoints) but render their own native UI.

### What "fully native" means in practice
- ✅ All journey loop surfaces (Today, Identity Anchor, Morning Ritual, Training, Nutrition, Future Self Check-in, Close the Loop) — SwiftUI
- ✅ Identity Import, AI guide interactions, Future Self image generation — SwiftUI
- ✅ Onboarding, profile, settings — SwiftUI
- ✅ Any screen that defines how WyldeSelf *feels* — SwiftUI

### When WebView IS acceptable (deferred — not now)
- Full script marketplace (future, when it ships) — WebView OK at launch, native later
- Complex transactional flows that already work well as web (e.g., billing portal, support tickets) — WebView fine if it's a one-off and not part of the daily loop
- Long-form content that's edited frequently and shouldn't require app updates (e.g., terms of service, privacy policy disclosures) — WebView acceptable

**Rule of thumb:** if the user touches it as part of their daily journey, it's native. If they touch it once a quarter and it lives outside the journey loop, WebView is OK.

### Current state
The codebase has WebView-wrapped surfaces (e.g., `WebViewScreen(path: "#coach")` in MainTabView). These need to be replaced with native SwiftUI implementations. See HANDOFF.md for the migration plan.

### Why this matters
1. Apple App Store guidelines require apps to be more than a website wrapper. A heavily WebView-based app risks rejection or removal.
2. Performance, gesture feel, haptics, animations — all materially better native.
3. Brand fidelity — WebViews never feel as polished as native, and WyldeSelf's design bar requires polish.
4. HealthKit, push notifications, photo library, Face ID — all require native implementations.

---

## Backend Sharing

The web and iOS apps **share a backend** — Vercel-hosted Next.js API routes at `~/Projects/Wylde-self/api/*`.

### Shared endpoints
- `/api/anthropic` — AI guide conversations
- `/api/identity-analyze` — identity import / analysis
- `/api/generate-image` — Future Self image generation
- All future endpoints

### Implications
- API contracts are versioned — breaking changes affect both web and iOS simultaneously
- Authentication strategy must work for both clients (Supabase, when implemented)
- Data persistence is server-side authoritative — local state on either client is a cache
- Cross-client continuity (start a chat on web, continue on iOS) is a feature, not an accident — design for it

---

## Core Product: The Daily Journey Loop

The app revolves around one structured daily flow.

```
1. Identity Anchor       Who you are becoming today
2. Morning Ritual        Customizable practices
3. Training              Workout or movement
4. Nutrition             Simple tracking / awareness
5. Future Self Check-in  Visual + emotional reinforcement
6. Close the Loop        Completion + reward
```

The loop should feel:
- Structured but fluid
- Rewarding and slightly addictive
- Like measurable progression toward a higher version of self

Every other feature in the app is in service of this loop. If a feature doesn't strengthen the loop, it doesn't belong in the MVP.

---

## AI Presence

There is **one unified AI guide**. Not multiple coaches. Not a character with a name and personality.

The AI feels like:
- A calm, intelligent presence
- Aware of the user's goals, history, and patterns
- Evolving with the user over time
- Confident but not performative

The AI should NOT:
- Have multiple personalities or selectable personas
- Be gimmicky, chatty, or overly conversational
- Feel like a chatbot in a corner of the app
- Use heavy slang, hype, or motivational-poster language

### Implementation note
The codebase uses `identity_archetype`, `coaching_style`, and a visible Identity Import UI plus `WYLDE_PHASES` labels. These should function as **internal AI modulation parameters** — server-side context that shapes the unified AI guide — not as user-facing selectable personas. The Identity Import UI should produce a guidance moment, not a psychographic profile card.

The earlier exploratory work around six named coach personas (Warrior, Athlete, Yogi, Architect, Mentor, Monk) is no longer part of the system.

---

## Design Direction

See `DESIGN.md` for the full visual language. Summary:

Premium, minimal, cinematic. Equinox / Tracksmith / Function Health / Levels / Whoop register. Move away from full black + dominant gold + Bebas Neue + heavy sacred geometry. Move toward warm neutrals, deep charcoal, restrained accents, generous whitespace.

**Design fidelity bar:** every screen should feel designed in Figma, not generated. If it looks like a stock SwiftUI app, it's not done.

---

## Data Handling

See `PRIVACY.md` for the full privacy approach. Summary:

- Collect only what powers the product experience
- HealthKit data stays on device unless the user explicitly opts in to sync
- Photos used for Future Self generation are processed and discarded — not retained on the backend after generation
- AI conversation history is encrypted at rest, retained for product use, deletable on user request
- App Store privacy nutrition label must be accurate and defensible

---

## Information Architecture (target state)

```
Today          The daily loop — primary surface
Future Self    Visual evolution, identity anchor, progression tracking
Library        Programs, past sessions, reference (minimal)
Profile        Identity, settings, account
```

Tabs are minimal. The "Today" surface is the heart of the app and should be the first and most-used screen.

**No Coach tab.** AI guide interactions surface contextually inside Today, not as a separate destination.

---

## Progression System

Tier names (gender-neutral, retained from earlier work):
- **Ember** — beginning
- **Forge** — building
- **Steel** — established
- **Wylde** — embodied

These represent the user's evolving identity over time, surfaced in the Future Self view. Confirm `WYLDE_PHASES` labels in the codebase align with these names and remain gender-neutral.

---

## Future Ecosystem (architectural awareness, not MVP scope)

- **Marketplace** — white-labeled Wylde products, proprietary supplement blends. WebView acceptable at launch, native later.
- **Programs** — structured transformation journeys (12-week protocols, Wylde Man, Wylde Woman verticals). Native.
- **Clinical layer** — labs, peptides, hormone optimization integrations. Mostly native, possibly WebView for partner portals.
- **Content + community** — present, never the core. Native if shipped.

These are not MVP. They inform schema design and account structure.

---

## Working Style

- Direct and concise — skip preamble
- Mobile for drafting, desktop for deployment
- Move fast from idea to production
- Ship working code, polish iteratively
- Decisive over exhaustive

---

## Active Direction

Strategic pivot in progress: WyldeSelf has been re-positioned from a men's-only product to a universal identity transformation platform. iOS architecture is moving from WebView-hybrid to fully native SwiftUI. AI guide is consolidating to a single presence (no Coach tab, no personas). Visual identity is moving from dark/masculine/sacred-geometry toward premium/minimal/cinematic.

When working in this codebase: assume the new direction is the source of truth. Flag anything that conflicts with it.
# Wylde-self (Web / API)

## North Star

This repo is the **web and API backend** for WyldeSelf — an AI-guided identity transformation system that helps users become their future self through daily structured actions.

WyldeSelf is the entry point into the broader Wylde ecosystem. This codebase serves the iOS app and (eventually) a marketing/onboarding web surface.

The promise to the user, every time they open the app:

> *"I am stepping into a higher version of myself."*

Clarity > complexity. Experience > features. Identity shift > information.

---

## What this repo is responsible for

- **API endpoints** consumed by the WyldeSelf iOS app
- **AI orchestration** — calls to Gemini, Claude, and other model providers
- **Image generation** — Future Self photo generation pipeline
- **Marketing site** (current or future) at wyldeself.com
- **Auth and user data** (planned, via Supabase)
- **Webhooks and integrations** (HealthKit relay, Stripe, etc. — future)

What lives elsewhere:
- iOS UI/UX → `WyldeSelf` repo (Xcode/SwiftUI)
- Wylde Man marketing site → separate Wylde-man repo
- Marketplace, programs, clinical layer → future repos / future scope

---

## Positioning

**WyldeSelf is universal — designed for both men and women.**

Integrating four pillars:
- Physical fitness
- Mental clarity
- Emotional regulation
- Lifestyle optimization

Tone: grounded, powerful, clean, balanced. Masculine structure + feminine openness. Precision and presence — never dominance or softness alone.

### What WyldeSelf is NOT
- Not a men's coaching app
- Not a multi-coach platform
- Not content-heavy or guru-driven
- Not aggressive, "alpha," or bro-coded
- Not overly spiritual, mystical, or esoteric

### Where Wylde Man fits
Wylde Man is a specialized program within the Wylde ecosystem — a deeper masculine track. It is not the front door and should not influence WyldeSelf's tone, copy, or visual language. Wylde Woman, Wylde Child, and other verticals will sit alongside it.

---

## Core Product: The Daily Journey Loop

The iOS app revolves around one structured daily flow. This backend exists to power that loop and persist its state.

```
1. Identity Anchor       Who you are becoming today
2. Morning Ritual        Customizable practices
3. Training              Workout or movement
4. Nutrition             Simple tracking / awareness
5. Future Self Check-in  Visual + emotional reinforcement
6. Close the Loop        Completion + reward
```

API design and data models should reflect this loop. Endpoints, schemas, and AI prompts should be organized around journey state — not feature silos.

---

## AI Architecture

There is **one unified AI guide** from the user's perspective. Not multiple coaches. Not selectable personas.

Internally, the AI shifts between context modes (Warrior, Athlete, Yogi, Architect, Mentor, Monk) based on what the user is doing — but these are server-side prompt strategies, never exposed in API responses or UI. The iOS client should never receive or surface persona names.

### AI guide voice
- Calm, intelligent, evolving
- Aware of the user's goals, history, and patterns
- Confident but not performative
- Never gimmicky, chatty, or hype-heavy

### Image generation
- **Provider:** Google Gemini, native multi-modal image generation (Nano Banana family)
- **Primary model:** `gemini-3.1-flash-image-preview` ("Nano Banana 2"). Falls back through `gemini-3-pro-image-preview`, `gemini-2.5-flash-image` (GA), and `gemini-2.0-flash-exp`. All entries hit the `:generateContent` endpoint with `responseModalities: ['TEXT', 'IMAGE']`.
- **Why:** Chosen after evaluating fal.ai, DALL-E 2, and gpt-image-1. Gemini's native image generation gave the best identity preservation + aesthetic match for the Future Self use case.
- **Endpoint:** runs on Vercel Edge Runtime to bypass the Hobby plan's 10-second function timeout

---

## Stack

- **Framework:** Next.js
- **Hosting:** Vercel (Hobby plan currently — Edge Runtime used for long-running AI calls)
- **Domain:** wyldeself.com
- **Auth:** Supabase (planned, deferred)
- **Database:** Supabase Postgres (planned)
- **AI providers:** Gemini (image), Claude / others (conversation) — abstracted behind a service layer so providers can be swapped
- **Repo:** github.com/WMIWylde/Wylde-self

---

## Repo conventions

- `.env.local` holds secrets — never commit
- API routes live under `app/api/` (or `pages/api/` depending on Next.js version in use)
- AI provider clients are wrapped in their own modules so model swaps don't ripple through the codebase
- Edge Runtime is used for any endpoint that calls a generative model — note the `export const runtime = 'edge'` at the top of the route

---

## Design Direction (for any web-facing surface)

If/when this repo serves a marketing or onboarding web surface, the visual language must align with the iOS app:

### Aesthetic
Premium, minimal, cinematic. Neutral but powerful. Nature + human performance.

### Reference brands
Equinox, Tracksmith, Function Health, Aesop, Rapha, Levels, Ten Thousand, Future, Whoop.

### Move AWAY from
- Hyper-masculine visual language
- Dark/aggressive "alpha" energy
- Heavy sacred geometry as a focal point
- Mystical or overtly spiritual cues
- Full black + gold maximalism

### Move TOWARD
- Warm neutrals, deep charcoal (not full black), considered accent colors
- Cinematic photography of real human movement
- Quiet, restrained sacred geometry as fine detail
- Generous whitespace
- Subtle motion over visual ornament

### Typography
- Cormorant Garamond — keep for editorial / display
- Replace Bebas Neue with a softer display face (Migra, GT Sectra Display, Söhne Breit are candidates)
- Body: clean modern sans (Söhne, Inter)

### Color
`#C9A84C` gold can stay as one accent but should not dominate. Build around warm bronze, sand, deep charcoal, off-white. Gold reserved for moments of significance.

---

## Future Ecosystem (architectural awareness, not MVP scope)

Schema and account design should leave room for:
- **Marketplace** — white-labeled Wylde products, proprietary supplement blends
- **Programs** — structured transformation journeys (12-week protocols, Wylde Man, Wylde Woman verticals)
- **Clinical layer** — labs, peptides, hormone optimization integrations
- **Content + community** — present, never core

Not MVP. Inform data model extensibility — nothing more right now.

---

## Working Style

- Direct and concise — skip preamble
- Mobile for drafting, desktop for deployment
- Move fast from idea to production
- Ship working code, polish iteratively
- Decisive over exhaustive

---

## Active Direction (as of latest session)

Strategic pivot in progress: WyldeSelf has been re-positioned from a men's-only product to a universal identity transformation platform. Backend code, API responses, copy, and any web surfaces need an audit against this document. Persona-based logic stays internal — never exposed in API responses or UI. Daily journey loop is the new architectural center.

When working in this codebase: assume the new direction is the source of truth. Flag any existing code, copy, schema, or design that conflicts with it.
