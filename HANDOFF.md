# HANDOFF — Native iOS Build Phase

**Last updated:** Tuesday, May 5, 2026 (laptop session, end of day)
**Next pickup:** Mac mini

---

## TL;DR

The strategic and architectural direction for WyldeSelf iOS is now fully captured across four files:

- **`CLAUDE.md`** — North Star, positioning, architecture mandate (fully native), AI presence rules, IA target state
- **`DESIGN.md`** — Visual language: palette, type, components, motion, voice in copy
- **`PRIVACY.md`** — Apple-ready data handling, App Store privacy declarations, user rights
- **`HANDOFF.md`** (this file) — current state, migration plan, open work

The next phase of work is migrating WyldeSelf iOS from its current WebView-hybrid state to a fully native SwiftUI app, while keeping the same backend shared with the web app at wyldeself.com.

---

## Resolved decisions

### Architecture: fully native (no wrapping)
- All journey loop surfaces, AI guide interactions, Identity work, onboarding, profile, settings → SwiftUI
- WebView **only** acceptable for: future marketplace, billing portals, terms/privacy pages — none of which are MVP
- Backend (Vercel API) is shared with the web app — same endpoints, same data, different render layers
- See `CLAUDE.md` "Architecture Mandate" for full detail

### Coach feature path: Path B (chat UI inside Today, no Coach tab)
- Earlier session drafted a 6-step plan to build a dedicated CoachView as a Coach tab
- That conflicts with `CLAUDE.md` ("one unified AI guide, no chatbot, no Coach tab in target IA")
- **Resolution:** infrastructure (Steps 1-3) proceeds as drafted; Step 4 reshapes into `CoachSheet` or `CoachInline` integrated inside Today, surfacing contextually; Step 5 is dropped (the Coach tab is being collapsed entirely, not replaced)
- Detailed migration plan below

### Visual direction
- Premium, minimal, cinematic — Equinox / Tracksmith / Function Health / Levels / Whoop register
- Move away from full black + dominant gold + Bebas Neue
- Full palette and type scale in `DESIGN.md`

---

## Migration Plan: WebView-hybrid → Fully Native

### Phase 0 — Foundation (do first, blocks everything else)

**0a. Establish design components in code**
Create `Utilities/WyldeStyles.swift` and `Components/` folder with the 10 base components defined in `DESIGN.md`:
- `WyldePrimaryButton`, `WyldeSecondaryButton`
- `WyldeTextField`
- `WyldeCard`, `WyldeSectionHeader`
- `WyldeStageRow`, `WyldeTab`
- `WyldeStat`, `WyldeProgressArc`
- `WyldeImageHero`

Every screen will use these. Build them with the exact tokens from `DESIGN.md` — colors, type, spacing, motion.

**0b. Establish networking layer**
Create `Services/WyldeAPI.swift` — generic POST/GET wrapper for the shared backend. Handles JSON encode/decode, errors, auth headers.

**0c. Establish data models**
Create `Models/CoachModels.swift` and other shared data models. The `ChatMessage` decoder must round-trip with the web app's `wylde_coach_chat` UserDefaults / localStorage blob.

**0d. Port the Coach system prompt verbatim**
Create `Utilities/CoachSystemPrompt.swift` — exact verbatim port of the system prompt from `app.html:9024`, same VOICE / FORMAT / CONTEXT / COACHING RULES / QUICK ACTIONS sections.

### Phase 1 — Bug fixes + IA cleanup (do first, before any feature work)

These are quick wins that unblock everything else.

**1a. Tab navigation profile reset bug**
Bug: tapping any of the bottom tabs is resetting the user's profile state. Diagnose root cause first (state management issue — AppState reinitialization, view identity, or .onAppear handler clearing state). Fix surgically.

**1b. Hamburger menu position fix**
Existing SettingsDrawer.swift hamburger needs:
- Consistent upper-right position across all screens (24pt from right edge, safe-area top + 12pt)
- Never covers content
- Custom mark (NOT three horizontal lines — use a more refined geometric mark with bronze accent)
- Slides in from right with spring animation per DESIGN.md motion section
- 44pt minimum hit target

Decision recorded: keeping the global hamburger menu despite premium-iOS convention against it. Conscious choice. Revisit if user testing shows confusion.

**1c. Tab structure refactor**
Current: 5 tabs including Coach (WebView-wrapped)
Target: 4 tabs — Today | Future | Library | Profile (no Coach tab; AI guide surfaces contextually inside Today in a future phase)

Remove `Coach` from `AppState.Tab` enum. Update `MainTabView.swift`. Migrate `path: "#progress"` WebView into Profile (or fold into another tab — confirm with audit).

### Phase 2 — Foundation (component system + tokens)

Per DESIGN.md "Component Catalog":

**2a. Create design tokens**
`Utilities/WyldeStyles.swift` with palette, type scale, spacing scale. Adaptive colors for light/dark mode.

**2b. Update Theme.swift**
Delegate to WyldeStyles tokens. Replace gold-dominant patterns with bronze-as-default. Replace pure black/white with charcoal/paper.

**2c. Extract 10 base components from existing inline styling**
WyldePrimaryButton, WyldeSecondaryButton, WyldeTextField, WyldeCard, WyldeSectionHeader, WyldeStageRow, WyldeTab, WyldeStat, WyldeProgressArc, WyldeImageHero. Refactor existing screens to use them.

### Phase 3 — Workout Day screen redesign (Image 2 inspired)

Redesign the workout day surface using the architecture from the reference design (horizontal day picker, block tabs for Warmup/Strength/Accessories/Finisher, hero image per exercise with play button overlay, icon-row metadata, Last Weight + PR as separate framed boxes, sticky Start Workout button) — but rendered in WyldeSelf's actual design language (warm-neutral palette, Cormorant Garamond for editorial moments, varied cinematic photography, bronze as primary accent not sage).

**Includes:**
- PR card layout fix (Last Weight + Personal Record as separate framed boxes)
- Light + dark mode support (full implementation per DESIGN.md "Light & Dark Mode" section)

### Phase 4 — Dynamic Warmup flow

Build the timed guided warmup that gates the strength workout. Spec:

- Tap "Start Warmup" on the workout day screen → enters dedicated warmup flow
- Sequence: foam roll 1 min → arm circles 1 min → leg swings 1 min → hip openers 1 min → light jog/jump rope 1 min (default sequence; programmable per workout)
- Auto-progresses from one exercise to the next as each timer completes
- Visual countdown timer + exercise name + brief form cue
- Optional cardio swap: instead of dynamic stretches, user can opt for 10 minutes of cardio (stair master, elliptical, rowing machine, incline walk) — selectable from the warmup screen
- On warmup complete → automatically transitions to strength block start
- Cannot skip warmup unless explicitly opted out (encourages adherence; respects user autonomy)

### Phase 5 — Replace remaining WebViews

Per migration plan: native FutureSelfView (replace `path: "#future"`), native CoachSheet integrated inside Today (replace `path: "#coach"` AND collapse the Coach tab simultaneously).

### Phase 6 — Privacy alignment + App Store readiness

Info.plist permission strings, HealthKit read-only default, user data export and deletion flows. Per PRIVACY.md.

### Phase 7 — Polish, TestFlight, App Store

Final design pass against DESIGN.md ref brands. Privacy nutrition label. Submission.

---

## Pending bugs (separate from native migration, fix when convenient)

### Onboarding routing (web app)
- File: `~/Projects/Wylde-self/app.html`
- State: under investigation. Original premise (onboarding routes to wrong screen) is in question.
- Diagnosis from earlier session: `completeOnboard()` at `app.html:6975` correctly calls `showScreen('overview')`. The two `showScreen` definitions (line 3980 wrapper and line 6575 function) — wrapper at 3980 is dead code. Live function at 6575 runs.
- **Next step:** verify whether the bug actually reproduces on a fresh state. Start dev server (`npm run dev`), clear localStorage, run through onboarding, observe.
- If bug doesn't reproduce → close the issue
- If bug reproduces → trace `wylde_last_screen` writes (suspect #2 from earlier diagnosis)

### Future Self image generation regression
- File: `~/Projects/Wylde-self/api/generate-image.js`
- **Issue:** 12-week generated future self looks MORE developed than 1-year future self. Timeline runs backward visually.
- **Root cause:** prompt logic over-indexes on aggressive cut/Men's Health/bodybuilding language for 12-week, then softens too much for 1-year. Net effect: 1-year looks like a regression from 12-week.
- **Two issues to fix together:**
  1. Realign 12-week vs 1-year so progression actually progresses (1-year = refined, embodied, established practice — not just "more 12-week")
  2. Strip masculine-coded language ("Men's Health cover," bodybuilding tropes) per `CLAUDE.md` universal positioning. Reference aesthetic: Equinox cover, NOT Men's Health cover.
- **Bonus:** also account for user's starting fitness level — for already-fit users, future self differentiation is subtle; lean into refinement, posture, presence, lighting, not raw muscle mass

### Side findings (web — fix later)
- Dead `showScreen` wrapper at `app.html:3980` — never executes due to script ordering. The setTimeout calls inside (`ovSyncData`, `ovSyncHeroImage`, `completeDayInit`) never fire on screen change. Should be deleted; calls moved into the live `showScreen` function's `'overview'` branch.
- `identity_archetype` and `coaching_style` are user-facing today — flagged in earlier audit, need to be hidden from UI per `CLAUDE.md` direction. Refactor Identity Import result UI from psychographic-profile-card into a guidance moment.

---

## Active Direction

Phase 1c (tab refactor) partially complete. Today's progress:
- WyldeStyles.swift design tokens shipped
- Theme.swift updated to delegate to tokens
- WebView tab reset bug fixed (WebViewScreen.updateUIView is now no-op)
- AppState.swift: Coach tab removed from Tab enum
- MainTabView.swift: Coach tab entry removed
- ContentView.swift: legacy "coach" notification routing redirected to .today

## OPEN — resolve before continuing

Tab structure beyond the Coach removal is NOT yet locked. Late-session
iterations explored multiple alternatives without integration. Don't
re-litigate here — decide tomorrow with fresh eyes.

Tomorrow's first 10 minutes (BEFORE opening any code):
  1. Re-read CLAUDE.md target IA section
  2. Ask: "What does each tab uniquely represent that the others don't?"
  3. Ask: "If Nutrition lives inside Today (Stage 4), what's the right
     interaction model so a user can log a meal in one tap from Today
     without forced linear progression through earlier stages?"
  4. Ask: "What ultimately goes in Future — and is it rich enough to
     earn the tab slot or does it need to merge with something?"
  5. Whatever clean answers surface, that's the structure to commit to

Until resolved, do NOT make further changes to MainTabView, AppState,
ContentView, or StartTodayFlow beyond what's already committed.

## Future work — captured but not designed yet

### First-launch onboarding walkthrough
Brief tutorial explaining the daily journey loop and how the app works.
Surfaces the first time a user opens WyldeSelf after onboarding.
Walks through:
  - What the journey loop is (Identity Anchor → Morning Ritual → Training
    → Nutrition → Future Self Check-in → Close the Loop)
  - That stages can be tapped in any order throughout the day
  - Where Future, Library, and account live
  - How the AI guide surfaces (when in-Today CoachSheet exists)

Visual register: matches DESIGN.md (premium, minimal, cinematic).
NOT a generic feature-tour with arrows pointing at things.
Closer to: short cinematic vignettes with editorial copy that frame
the practice as identity work, not "here's how to use this app."

Reference: Function Health's first-launch flow, Whoop's onboarding tour.

Implementation phase: TBD. Not Phase 1 or 2. Probably Phase 6 or 7
(polish + App Store readiness) — by then the IA is locked, the daily
loop interaction model is final, and we have something stable to
walk users through.

### Pending separately
- StartTodayFlow.swift Step 5 ("coach" navigation) — needs diagnosis
- Hamburger polish (Phase 1b)
- Component foundation (Phase 2)

## Resume on Mac mini

```bash
cd ~/Projects/Wylde-self    # or wherever the iOS subfolder lives
git pull
cat HANDOFF.md
cat CLAUDE.md
cat DESIGN.md
cat PRIVACY.md
```

Then in Claude Code (in Cursor's terminal):

> "Read CLAUDE.md, DESIGN.md, PRIVACY.md, and HANDOFF.md fully — these together define the strategic direction, design language, data handling, and current migration plan for WyldeSelf iOS. After reading, audit the current iOS codebase against these documents and produce a prioritized refactor plan. Don't change anything yet — just give me the audit."

That gives Claude Code complete context. From then on, tactical instructions ("build the Today view per DESIGN.md") will land correctly because the spec is fully captured.

---

## Working pattern (commit to this going forward)

- **Cursor + Claude Code in terminal** = primary code workspace, both machines
- **Claude.ai** (this conversation, or successors) = strategy, planning, prompt drafting, sanity checks
- **Cowork** = files outside repos (brand assets, PDFs) — not used yet, save for later

Session pattern:
- **Start:** `git pull`, read `HANDOFF.md`
- **End:** update `HANDOFF.md`, commit, push

`CLAUDE.md`, `DESIGN.md`, `PRIVACY.md` are stable references — only update on real direction changes. `HANDOFF.md` updates every session.
# Wylde Self — Handoff

Last updated: 2026-04-30

This is the single document that gets a new collaborator (or future-you after time off) up to speed on what Wylde Self is, what's been built, what works, what doesn't, and what's next.

---

## Machine handoff (laptop → Mac mini, 2026-04-30)

**This session was on the laptop. The Mac mini will pick up here.**

To resume on the mini:

```bash
cd ~/Wylde-self
git pull origin main          # latest main with all work below
rm -f .git/index.lock .git/HEAD.lock   # if Xcode is running
open WyldeSelf-iOS/WyldeSelf.xcodeproj
```

Verify the build is green in Xcode (Cmd+B). All of this session's iOS files were committed in `9a24df5 iOS: native StartTodayFlow + tone helpers + Today reorder` and should be in the project target. If the build flags any of these as missing, drag them into the project navigator under their respective folders and re-add to the WyldeSelf target:

- `Utilities/CoachLine.swift`
- `Utilities/JourneyPhase.swift`
- `Views/StartTodayFlow.swift`

**Where we paused:** Strategic decision made to go native-first. The Mac mini's first job is **Port #1 of 5: native Coach tab**. Detailed plan is in the **Native-first transition** section near the bottom of this document. Read that section + the conversation transcript to pick up exactly where the laptop left off.

---

## What Wylde Self is

An identity-based transformation app. Not a fitness tracker. The product is built around the principle that the user is becoming someone — and every surface should reinforce that identity.

**Brand position:** Whoop + Levels + Calm + a high-end identity transformation container.

**Voice:** Grounded, direct, strong but not aggressive, no fluff, no emojis. The **core Wylde Self app is welcoming to men and women** (per the inclusivity work shipped this session). **Wylde Man** is a separate sub-program that keeps its masculine-specific voice — gendered phrasing belongs there, not in the core app.

**Core loop:**
User opens Today → feels identity shift → taps "Start Today" → moves through the 6-step guided flow → closes the loop → loops back tomorrow.

---

## Latest session — 2026-04-30 (laptop)

This session shipped a major Today-screen evolution + iOS native foundation work + a strategic pivot to native-first architecture.

### Web app (app.html → 11,470 lines, refactored)

**StartTodayFlow** — new 6-step guided daily flow (Identity Anchor → Morning Ritual → Training → Nutrition → Future Self → Close the Loop). Originally inline; later refactored out to `/css/start-today-flow.css` (228 lines) and `/js/start-today-flow.js` (455 lines). Markup now injected by the JS at script load. State persists per day via `wylde_stf_state` UserDefaults/localStorage key.

**Today screen reorder** — primary hero CTA changed from "Enter Today's Training" to **"Start Today"** which opens StartTodayFlow. Card priority reordered via CSS `order` (no markup moved): Hero → Workout → Walk → Nutrition → Future You → Morning Routine → Daily Closeout → Path → Streak.

**Inclusivity sweep** — `Eat like the man you're becoming` → `Eat for who you're becoming`. Coach prompt `Masculine but not aggressive` → `Strong but not aggressive`. `getIdentityPhrase()` rotation engine rebalanced: full neutral pool now mixed in with gendered phrases so even male users skew toward inclusive phrasing in the core app.

**Coach chat persistence** — `chatHistory` now persists to `localStorage["wylde_coach_chat"]` (capped at 30 messages, prompt context capped at last 8). Hydrates on `showScreen('coach')` via a `_chatHydrated` closure flag (the original guard was broken because the static greeting bubble was always a child of `#chatMessages`). Conversations now continue across reloads and across web ↔ iOS.

**Future You evolving copy** — `getFutureYouCopy(week)` returns a calm one-liner that evolves week-by-week (week 1: "this is the version you're beginning to build" → week 12: "this is what follow-through looks like"). Wired into the Today Future You strip via `ovUpdateHero`.

**`coachLine()` helper** — centralized one-sentence coach voice with 8 contextual pools (mealLogged / mealLowProtein / mealOnTrack / workoutDone / ritualDone / closeout / missed / generic). Auto-swaps mealLogged → mealLowProtein/mealOnTrack based on daily protein context. Wired into `appendFoodLogItem`, morning protocol completion, and `completeDay()`.

**`getJourneyPhase()`** — maps day 1..84 to the 4-phase Foundation/Build/Embody/Integrate structure. Used by StartTodayFlow Step 1 (Identity Anchor) and the Future You strip. Parallel to the existing identity-based phases (Initiate/Foundation/Embodied/Relentless/Integrated) — does not replace them.

**Nutrition "Why this works"** — meal plan cards now have an expandable section explaining why the macros work (protein → recovery + hunger; carbs → fuel; fats → hormones + satiety). Macro-aware rationale.

**Post-meal feedback** — after `appendFoodLogItem`, a single calm coach line renders below the food log via `coachLine('mealLogged', { protein, proteinGoal })`. Replaces on each subsequent log so it never piles up.

### Web app — bug fixes shipped

**Badge toast flashing on every page load** (commit `374ce9e`) — `checkBadges()` was retro-celebrating already-earned badges on every load because (a) toast fired even for retro-credit and (b) `state.badges` was never persisted after mutation. Fix: `checkBadges({ silent: true })` for the load-time call + persist `state.badges` to localStorage immediately on mutation. Live actions (e.g. hitting a PR) still celebrate normally.

**Set checkmark unicode escape** — CSS `content: '✓'` was rendering as the literal text `u2713` next to set numbers. CSS unicode escapes use `\XXXX` (no `u`), not the JavaScript `\uXXXX` form. Fixed to `content: '\2713 '` with trailing space terminator.

**Program screen defaults to today's day only** (commit `23be2f3`) — previously stacked all 5 days. Now today's day card is auto-expanded, others hidden behind a `View full program (5 days)` toggle. Today index computed via `wylde_day mod plan.length`. Re-rendering resets to today-only. Single-day plans skip the toggle.

### iOS app — three native phases shipped (commit `9a24df5`)

**Phase 1 — Helpers + tone defaults**

- `Utilities/CoachLine.swift` — Swift port of the web `coachLine()` helper. Same 8 pools, same protein-aware auto-swap, same rotation logic. Used in StartTodayFlow ritual + closeout steps.
- `Utilities/JourneyPhase.swift` — Swift port of `getJourneyPhase` and `getFutureYouCopy`. `JourneyPhase.forDay(_:)` and `FutureYouCopy.forWeek(_:)`.
- `AppState.swift` — `gender: String = "Male"` default changed to `""`. Backwards-compatible: existing users keep their saved value via `UserDefaults.string(forKey: "wylde_gender")`. New users start unspecified.

**Phase 2 — StartTodayFlow native sheet**

- `Views/StartTodayFlow.swift` (~595 lines) — full native 6-step flow. Presented as `.sheet` with `.presentationDetents([.large])`. Uses `@MainActor final class StartTodayFlowState` for step persistence to the same `wylde_stf_state` UserDefaults key the web uses, so a user moving between web and iOS during a single day resumes at the same step.
- `TodayView.swift` — new gold "Start Today" CTA inside the hero card, opens the sheet.

Step 6 (Close the Loop) writes `wylde_last_completed_day` and `wylde_last_day_key` matching web behavior, increments `appState.currentDay`, updates streak via the same yesterday-comparison logic, awards 50 XP. Web and iOS see consistent day state.

Step 3 (Training) and Step 4 (Nutrition) dismiss the flow on action — workout and nutrition are still web-only on iOS. Both are flagged for native port (see Native-first transition below).

**Phase 3 — Today reorder + Future You strip**

- `TodayView.swift` body reordered to match the web brief priority: Hero → Workout → Walk → Nutrition → Future You → Morning Protocol → Health → Founding. Animation delays restaggered cleanly (0.05 → 0.40 in 0.05 steps).
- New `futureYouCard` view between Nutrition and Morning Protocol. Shows weeks-remaining sigil, evolving copy from `FutureYouCopy.forWeek(week)`, taps through to the Future tab.

### Strategic decision

**Native-first.** The hybrid (native shell + WebView tabs) was a useful prototype. The product is the native app. Going forward, the WebView tabs (Future, Coach, Settings/Progress) will be replaced outright with native SwiftUI ports, in a deliberate order. Native polish (haptics, voice input, native camera, animations) layers on after each tab is 1:1 ported and stable.

The web `app.html` continues to exist as the desktop browser experience and as the source of truth for any features not yet native-ported — but is no longer the primary surface.

---

## Stack

| Layer | What |
|---|---|
| **Web app** | `app.html` (single-file, ~11.5k lines) + `/css/start-today-flow.css` + `/js/start-today-flow.js`, deployed on Vercel at wyldeself.com |
| **Public paywall** | `founder.html` (standalone page), same Vercel deploy |
| **iOS app** | `WyldeSelf-iOS/` SwiftUI shell. Today + Library + Identity Import + StartTodayFlow are native. Future / Coach / Progress are still WKWebView wrappers (Coach is the next port — see Native-first transition below) |
| **API** | Vercel serverless under `/api/` (Anthropic proxy, exercises, identity-analyze, founder-count, RevenueCat webhook, Stripe checkout, Stripe webhook, generate-image) |
| **Database** | Supabase (auth via magic link, profiles, workouts, food_logs, badges, identity profiles, founder counter, daily walks) |
| **AI** | Claude Haiku 4.5 (`claude-haiku-4-5-20251001`) via `/api/anthropic` |
| **Payments** | RevenueCat → Apple StoreKit (iOS, stub mode), Stripe Checkout (web) |
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
Cinematic stacked journey, top to bottom (post-2026-04-30 reorder):
- Header with greeting + streak badge
- Hero card: "Day X" + identity statement + **gold "Start Today" CTA** (opens StartTodayFlow)
- Today's Workout
- Long Walk (separate from training)
- 3-ring Nutrition card (Calories / Protein / Carbs) — animated SVG rings, live-syncs with food log
- **Future You strip** — week-evolving copy, taps to Future tab
- Morning Routine — 3 fixed practices (Meditation, Journaling, Reading), checkmark each (collapsed/hidden once complete)
- Health snapshot (HealthKit on iOS)
- Coach access ("Talk to your future self") — secondary
- Daily Closeout — "Close the Loop" gold CTA (web)
- Founding Member CTA (only if not Pro)

Animations: staggered fade-up on first appearance, spring on toggles, 3-ring fill animation on update.

### StartTodayFlow (web + iOS native)
6-step guided daily flow:
1. **Identity Anchor** — phase + day + grounding line
2. **Morning Ritual** — checkable list, reuses Morning Protocol data
3. **Training** — today's session metadata + "Start Training" CTA
4. **Nutrition** — 3 options (log meal / photo / view plan)
5. **Future Self** — calm check-in + "Talk to your future self"
6. **Close the Loop** — 4 completion checks + final state, calls existing `completeDay()`

State persists per day via `wylde_stf_state`. Closing and reopening returns to the same step. Date change resets to step 1. Both surfaces share the same key — a user mid-flow on web continues from the same step on iOS.

### Coach (still web-based on iOS — next port)
- Speaks AS user's literal future self ("Future Wilke" not "AI coach")
- 280 max_tokens, hard format rules: 2–4 sentences, no bullets, no meta-talk, no emojis
- Occasional single-line science callout (~1 in 4)
- 4 quick actions: Motivate me / Fix my plan / I'm off track / Optimize everything
- Pulls full user context (PRs, streak, sleep, walks, vibes, identity profile, phase) into every prompt
- Identity language cue: when user has set gender, mirrors their natural phrasing
- **Chat history persists** to `wylde_coach_chat` localStorage key, hydrates on screen open, capped at 30 messages

### Identity Import (Founding Members feature)
- User pastes public URLs (bio, posts, Substack, etc.) or raw text
- `/api/identity-analyze` server-side fetches URLs (SSRF-hardened) + sends to Claude
- Claude returns structured JSON: archetype, confidence, tone, motivation triggers, limiting patterns, language to use/avoid, coaching style, discipline level
- Stored in `user_identity_profile` Supabase table
- Coach + meal planner pull this profile and mirror the user's actual voice

### Phase progression (driven by sessions completed)
- Initiate (0)    — "You stepped onto the path. Now keep walking."
- Foundation (10) — "The first layer is laid. The work is becoming yours."
- Embodied (30)   — "It's no longer trying — it's who you are."
- Relentless (100)— "You don't negotiate with yourself anymore."
- Integrated (300)— "You and the practice are the same thing now."

Parallel to this, the **Journey Phase** (Foundation / Build / Embody / Integrate, day-driven) is used by the new StartTodayFlow.

### Badges (29 across 6 categories)
Streaks / Sessions / Practice / Strength / Nutrition / Reflection. Custom SVG glyphs. Locked badges greyscaled at 45%. **Toasts only fire for live achievements** (retro-credit on load is silent — fixed 2026-04-30).

### Library (Exercise browser)
873 exercises native iOS + web. Body-part chips, search, exercise cards. YouTube tutorial deep-link button.

### Set logger
PR + Last Weight reference cards, +/- steppers (5lb / 1 rep), per-set sage checkmark, Workout finale feel-prompt (Brutal/Off/Solid/Dialed), inline food feel buttons (+ / – / ×).

### Program screen
- **Default-to-today behavior** (shipped 2026-04-30): only today's day card auto-expanded; "View full program (5 days)" toggle reveals the rest.
- Today index computed via `wylde_day mod plan.length`.
- Day cards collapsible. Alt-workout swap available per day.

### Founding Member paywall
Lifetime $149 / Annual $79 / Monthly $9.99 (founder, locked forever for first 1,000). Standard pricing applies after.
- iOS: native `PaywallView` (RevenueCat in stub mode)
- Web: `/founder.html` standalone page → Stripe Checkout
- Both webhook into same Supabase profile fields

### Settings drawer
Left-slide hamburger on every screen (web + iOS). Lists Library, Nutrition, Identity Import, Edit Profile, Rebuild Program, Reset Profile, Sign Out.

### iOS brand assets bundled
9 imagesets in `Assets.xcassets/`. AppIcon set with `Wyldeselflogo2.png`. AccentColor = brand gold.

---

## File map (post-2026-04-30)

```
/Wylde-self/
├── app.html                                   ← single-file web app (~11,470 lines)
├── founder.html                               ← public paywall page
├── package.json                               ← dependencies
├── data/exercises.json                        ← 873 exercises
├── css/
│   └── start-today-flow.css                   ← extracted STF styles (228 lines)
├── js/
│   └── start-today-flow.js                    ← extracted STF controller (455 lines)
├── api/
│   ├── anthropic.js                           ← Claude proxy
│   ├── exercises.js                           ← Exercise DB
│   ├── identity-analyze.js                    ← Identity Import
│   ├── founder-count.js                       ← Counter for paywall
│   ├── revenuecat-webhook.js                  ← iOS IAP entitlement sync
│   ├── stripe-checkout.js                     ← Web Checkout Session creator
│   ├── stripe-webhook.js                      ← Web Stripe entitlement sync
│   └── generate-image.js                      ← Gemini image gen
├── supabase/migrations/
│   ├── 20260427_pro_entitlements.sql
│   └── 20260428_identity_profile.sql
├── WyldeSelf-iOS/
│   └── WyldeSelf/
│       ├── WyldeSelfApp.swift
│       ├── ContentView.swift                  ← Tab routing
│       ├── Info.plist
│       ├── Assets.xcassets/
│       ├── Models/
│       │   ├── AppState.swift                 ← Single source of truth (gender default = "" as of 2026-04-30)
│       │   ├── Exercise.swift
│       │   └── IdentityProfile.swift
│       ├── Services/
│       │   ├── PurchaseManager.swift
│       │   ├── IdentityAnalysisService.swift
│       │   ├── HealthKitManager.swift
│       │   ├── HapticManager.swift
│       │   ├── NotificationManager.swift
│       │   └── CameraManager.swift
│       ├── Utilities/
│       │   ├── Theme.swift                    ← Brand colors
│       │   ├── CoachLine.swift                ← NEW (2026-04-30) — coach voice helper
│       │   └── JourneyPhase.swift             ← NEW (2026-04-30) — 4-phase + Future You week-band
│       └── Views/
│           ├── MainTabView.swift              ← Bottom tabs + hamburger overlay
│           ├── TodayView.swift                ← Native Today (Start Today CTA + Future You + reorder, 2026-04-30)
│           ├── StartTodayFlow.swift           ← NEW (2026-04-30) — native 6-step sheet
│           ├── ExercisesView.swift            ← Native exercise library
│           ├── WebViewScreen.swift            ← WKWebView wrapper for hybrid tabs (Future / Coach / Progress)
│           ├── PaywallView.swift              ← Native Founding Member paywall
│           ├── SettingsDrawer.swift           ← Native left-slide drawer
│           └── IdentityImportView.swift       ← Native Identity Import
├── HANDOFF.md                                 ← This file
├── CLAUDE.md                                  ← AI agent project context
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

Web wins margin AND user pays less. Apple anti-steering rules prevent promoting web pricing inside the iOS app — only mention via direct outreach.

---

## What's working end-to-end (live verified)

- ✓ Coach API live with future-self voice + user context (web)
- ✓ Identity Import returns valid structured profile
- ✓ 873 exercises returning from `/api/exercises`
- ✓ Web app renders correctly on dark theme
- ✓ Mobile web polish (no iOS input zoom, safe-area aware, responsive cards)
- ✓ Refresh-restore (URL hash + localStorage)
- ✓ Founder counter API
- ✓ All Supabase RPCs work
- ✓ **StartTodayFlow on web — full 6-step flow tested via jsdom (47 assertions pass)**
- ✓ **iOS Phase 1–3 build green in Xcode (user verified 2026-04-30)**
- ✓ **Coach chat persistence across reloads + cross-surface (web ↔ web)**
- ✓ **Badge toasts only fire for live achievements (retro-credit silent)**
- ✓ **Program screen defaults to today's day**

## What's stub mode

- iOS PaywallView — RevenueCat SDK not added yet, simulates purchases
- Stripe checkout — endpoint exists, needs real Stripe products + env vars
- iOS native gym location finder — natural next when native onboarding is built

---

## Native-first transition (port plan)

**Decision (2026-04-30):** Replace WebView tabs with native SwiftUI ports, in deliberate order. No dual maintenance. Native polish (haptics / voice / camera / animation) layers on after each tab is 1:1 ported and stable.

**Port order:**
1. **Coach** — emotional and behavioral core. Highest perceived "feels native" win.
2. **Future** — reinforces the identity transformation promise.
3. **Settings / Progress** — clean lower-complexity port.
4. **Nutrition** — heavy. Photo capture, vision API, food log persistence, macro tallying.
5. **Program / Workout** — heaviest. Set logging, day cards, swap-day generation.

### Port #1 — Coach (next session, Mac mini)

**Plan summary** (full plan in conversation transcript with the laptop session, dated 2026-04-30):

**New files (5):**
- `Services/WyldeAPI.swift` (~120 lines) — generic URLSession wrapper. `post<T: Decodable>(path:body:) async throws -> T` and `get<T: Decodable>(path:) async throws -> T`. Holds `baseURL = "https://wyldeself.com"`. Throws `APIError`.
- `Models/CoachModels.swift` (~80 lines) — `ChatMessage` (Codable, with `id: UUID` + `timestamp: Date` plus a custom decoder that handles the web's leaner `{role, content}` form so cross-surface continuity works), `AnthropicRequest`, `AnthropicResponse`, `AnthropicContent`, `APIError`, `CoachUserContext`.
- `Views/CoachView.swift` (~350 lines) — native chat screen. Header with "Future {firstName}", greeting bubble (visible only when chatHistory empty), 4 quick-action chips, ScrollView+LazyVStack of message bubbles, typing indicator, error banner, sticky input row.
- `Utilities/WyldeStyles.swift` (~70 lines) — `WyldeCard` view modifier + `WyldePrimaryButton` style extracted from existing TodayView/StartTodayFlow patterns.
- `Utilities/CoachSystemPrompt.swift` (~80 lines) — verbatim port of the Coach voice rules from `app.html` line ~9024. Single function: `CoachSystemPrompt.build(name:phase:idPhrase:context:) -> String`.

**Modified files (1):**
- `Views/MainTabView.swift` — one line: `tabContent(.coach) { WebViewScreen(path: "#coach") }` → `tabContent(.coach) { CoachView() }`

**Persistence:** reuses `wylde_coach_chat` UserDefaults key (same as web `localStorage`). Cap at 30 messages. Prompt context capped at last 8 turns. `ChatMessage` decoder tolerates web's leaner JSON form (auto-fills `id` and `timestamp`).

**API flow:** `CoachView.send` → build context from `appState` + `JourneyPhase.forDay` → build system prompt via `CoachSystemPrompt.build` → `WyldeAPI.shared.post("/api/anthropic", body: AnthropicRequest)` → decode response → append assistant message → save to UserDefaults → hide typing indicator. No auth header (Vercel function holds API key server-side, same as web).

**Open questions to confirm with user before starting:**
- Streaming responses? (1:1 port = non-streaming, matches web. Streaming is its own engineering project.)
- Live Supabase fetch for `user_identity_profile`? (1:1 port = use locally-cached `appState.identityProfile`. Live Supabase requires adding the Swift package.)
- All 4 quick-action chips? (Likely yes.)
- Greeting bubble hides when chatHistory exists? (Likely yes, mirrors web.)

**Test plan (22 checks):**
1. `xcodebuild -scheme WyldeSelf clean build` returns 0
2. App launches, Coach tab opens, greeting visible
3. Quick action "Motivate me" → response renders
4. Custom typed message → response renders
5. Force-quit + relaunch → history restored
6. Web → iOS continuity (open `wyldeself.com` while logged in, send message, return to iOS, see it)
7. Empty message guard
8. Airplane mode → graceful error
9. 30+ messages → oldest pruned, no crash
10. Switch tab mid-typing → typing indicator survives
11. StartTodayFlow Step 5 "Talk to your future self" → lands on native Coach (not WebView)
12. Long response (200+ words) → renders without truncation
13. 500 error → graceful banner
14. Concurrent send while in-flight → handled
15. Hamburger overlay over Coach tab
16. `WyldeAPI.shared.post` with malformed body throws decoding error caught in CoachView
17. `WyldeCard` applied to existing TodayView heroCard renders identically (visual regression)
18. iOS 17 deployment target — no new warnings beyond existing
19. ChatMessage decoder handles web's leaner JSON form
20. ChatMessage encoder writes the iOS-rich form
21. Identity profile presence vs absence both render correctly
22. App backgrounded mid-stream → returns cleanly

### After Coach

Once Coach is shipped + audited, the foundation (`WyldeAPI`, `WyldeStyles`, models pattern) makes Ports 2–5 faster. Future is the next port (~1-2 days), then Settings (~1-2 days), then Nutrition (~1 week), then Program (~1.5-2 weeks).

---

## External setup user must do

### Required for Founder launch
1. **Run Supabase migrations** — paste both `.sql` files in Supabase SQL editor
2. **Stripe** — see `STRIPE_SETUP.md`
3. **Vercel env vars:** `SUPABASE_URL`, `SUPABASE_SERVICE_KEY`, `ANTHROPIC_API_KEY`, `STRIPE_SECRET_KEY`, `STRIPE_PRICE_*`, `STRIPE_WEBHOOK_SECRET`, `REVENUECAT_WEBHOOK_SECRET`

### Required for App Store / TestFlight
4. **Apple Developer Program** ($99/yr)
5. **App Store Connect entry** — bundle ID `com.wylde.self`, see `TESTFLIGHT_SUBMISSION.md`
6. **Xcode signing** — Settings & Capabilities → Team + Bundle ID
7. **App Icon** — final 1024×1024 PNG
8. **Privacy policy URL** — required for App Store
9. **RevenueCat** — see `PAYWALL_SETUP.md`. Create entitlement, offering, get API key, add SDK in Xcode, flip `useRealRevenueCat = true`
10. **Sandbox test** — full purchase flow with test card `4242 4242 4242 4242`
11. **TestFlight upload** — Xcode → Archive → Distribute → App Store Connect

---

## Recurring infra issues

### Git lock (sandbox)
The dev sandbox can't unlink `.git/index.lock` due to virtiofs permissions. After every commit attempt by the AI agent, manually clear before pushing:

```bash
cd ~/Wylde-self
rm -f .git/index.lock .git/HEAD.lock .git/objects/*/tmp_obj_*
git push origin main
```

### Xcode locks
Xcode running in the background also causes `.git/index.lock` conflicts. Same fix.

### Adding new Swift files to the Xcode project
Xcode does not auto-discover loose `.swift` files in directories. After an AI agent creates a new file, you must drag it into the Xcode project navigator under its folder and confirm it's added to the WyldeSelf target. The build will fail with "cannot find type X in scope" otherwise.

---

## Decisions made (with reasoning)

- **iOS-first launch, web Stripe in parallel** — TestFlight is the primary milestone; Stripe lets warm contacts buy direct without waiting for App Store review
- **Native-first transition (2026-04-30)** — hybrid was a useful prototype; native is the product. WebView tabs replaced outright as each native port lands. No dual maintenance.
- **No emojis anywhere** — initiation container brand
- **Inclusivity in core app, masculine voice in Wylde Man only (2026-04-30)** — core Wylde Self welcomes men and women; Wylde Man (separate program) keeps gendered voice
- **Levels stripped, replaced with Phases** — phases reflect identity formation, not video-game tier grinding
- **Morning Protocol locked to 3 fixed practices** (Meditation, Journaling, Reading)
- **Walk added as separate daily action**
- **Coach speaks AS the user's future self** ("Future Wilke") — not a generic AI assistant
- **Coach voice tone (2026-04-30)** — "Strong but not aggressive" replaces "Masculine but not aggressive" in the Coach system prompt
- **Identity Import behind Founding Members paywall**
- **Stub-mode RevenueCat in iOS for now** — UI fully built, swap with one config flag
- **Single hamburger menu on every screen**
- **Mobile web is the primary marketing surface**
- **StartTodayFlow exists as both native (iOS) and external (web `/css/start-today-flow.css` + `/js/start-today-flow.js`)** — both share the `wylde_stf_state` key for cross-surface continuity
- **Today screen card priority (2026-04-30)** — Hero+CTA → Workout → Walk → Nutrition → Future You → Morning Routine → Health → Founding. Reduces cognitive load by surfacing required actions before optional ones.

---

## Pending / next priorities

**Immediate (Mac mini next session):**
- ❑ **Native Coach port** (Port #1) — full plan above. Foundation work (`WyldeAPI`, models, styles, system prompt) lands as part of this PR.

**Next 4 native ports (in order):**
- ❑ Native Future tab (Port #2)
- ❑ Native Settings/Progress tab (Port #3)
- ❑ Native Nutrition logger (Port #4) — heavy: photo capture, vision API, food log
- ❑ Native Program/Workout (Port #5) — heaviest: set logging, swap-day, default-to-today

**After native MVP is stable:**
- ❑ **Protocol system** — pluggable into existing Today/adherence/check-in surfaces. NOT a separate experience. Will track adherence to specific multi-week protocols (TRT cycles, sleep optimization blocks, fasting windows). Wait until the core native app is shipped and stable.
- ❑ Native iOS gym finder using MKLocalSearch
- ❑ Apple anti-steering compliance audit before App Store submission
- ❑ "Members at your gym" community feature (foundation already in place via gymPlaceId)
- ❑ Coach proactive daily insight push notification
- ❑ Streaming responses for Coach (currently non-streaming, matches web)

**User-side actions:**
- ❑ Complete Stripe setup + push live
- ❑ Complete iOS App Store Connect entry + signing
- ❑ Archive + upload first TestFlight build

---

## Quick context for the AI agent in future sessions

If you're an AI agent picking this up:

1. **Read this file first.** Then `app.html` and the iOS Views/ folder. Read the conversation transcript for the in-flight session if there's a Mac-laptop-to-Mac-mini handoff.
2. **Brand voice is sacred.** Grounded, direct, strong but not aggressive. No emojis. No fluff. No SaaS clichés. No video-game gamification. Core app is welcoming to men and women — Wylde Man (separate program) keeps masculine-specific voice.
3. **The Coach speaks as the user's future self, not as an AI.** Never break that frame.
4. **Mobile web is critical.** Test every change on a 375pt viewport before committing.
5. **The git lock issue is recurring.** Don't waste cycles trying to fix it — just commit locally and tell the user to push.
6. **Always commit locally, even if you can't push.**
7. **iOS WebView tabs (Future / Settings) get web changes automatically** — push to Vercel, WebViews see the update. Coach tab is being replaced with native — see Native-first transition.
8. **Stub mode is fine for now.** Don't try to wire RevenueCat or real Stripe products without the user's API keys.
9. **`HANDOFF.md` should be kept current** as major systems ship.
10. **Native-first ordering matters.** Don't skip ahead to Nutrition or Program before Coach + Future + Settings are done. The foundation files (`WyldeAPI`, `WyldeStyles`, models pattern) need to land first.
11. **Shared UserDefaults / localStorage keys are sacred.** `wylde_*` keys are shared between web and iOS native — never change a key during a port. Add new ones if needed; never rename existing ones.
12. **New Swift files must be added to the Xcode project target manually.** Xcode does not auto-discover. After file creation, the user drags them into the project navigator before Cmd+B.

---

End of handoff.
