# WYLDE SELF — Cowork Handoff
> Last updated: April 2026
> Use this document at the start of every Cowork and Claude chat session.

---

## What This App Is

**Wylde Self** is an AI-powered identity transformation platform.
Tagline: "Train with the person you're becoming."
Core thesis: identity precedes behaviour. People quit fitness apps not from lack of discipline but from lack of vision of who they're becoming.

**Founder:** Wilke — men's coaching, yoga, somatic work, real estate, entrepreneurship.
**Mastermind:** Mentor Collective (Chris & Lori Harder).

---

## Live URLs

| | URL |
|---|---|
| Landing | wyldeself.com |
| App | wyldeself.com/app.html |
| Gate | wyldeself.com/gate.html |
| Apply | wyldeself.com/apply.html |
| Investors | wyldeself.com/investors.html |

---

## Repositories & Access

| | Detail |
|---|---|
| GitHub repo | github.com/WMIWylde/Wylde-self |
| Vercel | Auto-deploys from GitHub main branch |
| Deploy time | ~30 seconds after push |
| Claude Code (web) | `cd ~/Wylde-self && claude` |
| Claude Code (iOS) | `cd ~/Documents/WyldeSelf && claude` |

---

## Tech Stack

| Layer | Detail |
|---|---|
| Web frontend | Single file: app.html (~200KB) |
| Web hosting | Vercel (Hobby plan, Edge Runtime for image gen) |
| iOS | SwiftUI, Xcode, ~/Documents/WyldeSelf |
| Database | Supabase — postgres.huclolzxzpitdpyogolu.supabase.co |
| Auth | Supabase email/password (Apple Sign In pending) |
| AI coaching | Claude Haiku via /api/anthropic.js |
| AI image gen | Gemini 3.1 Flash via /api/generate-image.js |
| AI video | Grok Imagine API — api.x.ai (planned) |
| Forms | Formspree (mkoponoz) + EmailJS |
| Supplements | Fullscript dispensary — Wylde Self Health |

---

## Environment Variables (Vercel)

```
ANTHROPIC_API_KEY
GEMINI_API_KEY
SUPABASE_URL        = https://huclolzxzpitdpyogolu.supabase.co
SUPABASE_ANON_KEY   = sb_publishable_VFZ0Yd0PhqAh3AgZF1TcXQ... (wylde_self key)
SUPABASE_SERVICE_KEY = sb_secret_8YaBq... (secret key)
```

---

## File Structure

```
~/Wylde-self/                     WEB APP
├── index.html                    Landing page
├── gate.html                     Beta gate (NDA + code: WYLDE2025)
├── app.html                      Main app — ALL screens in one file
├── apply.html                    Beta intake form
├── investors.html                VC pitch deck (live)
├── api/
│   ├── anthropic.js              Claude Haiku proxy
│   └── generate-image.js        Gemini image gen (Edge Runtime)
└── HANDOFF.md

~/Documents/WyldeSelf/            iOS SwiftUI APP
├── Theme.swift                   WyldeTheme colors + level system
├── WyldeButton.swift             5-variant button component
├── WyldeCard.swift               Base card + breathing border
├── CollapsibleWyldeCard.swift    Collapsible card with header summary
├── PulseDot.swift                Alive pulse animation (6px)
├── HeartbeatLine.swift           Bottom heartbeat bar
├── LevelBadge.swift              Level badge with pulse dot
├── SupabaseService.swift         All Supabase auth + data calls
├── AuthView.swift                Sign in / create account screen
├── APIService.swift              Claude API calls
├── UserProfile.swift             ObservableObject profile
├── CoachPersona.swift            6 coach definitions
├── OnboardingView.swift
├── MainTabView.swift
├── DashboardView.swift           Draggable + collapsible card grid
├── ProgramView.swift             Workout + rest timer
├── CoachView.swift
├── NutritionView.swift
├── ProgressView.swift
├── CommunityView.swift           Feed + leaderboard + events + forums
├── WorkoutCompleteView.swift     Celebration animation
├── RestTimerView.swift           Circular rest timer
├── HealthKitService.swift        HealthKit read/write
├── ScheduleService.swift         Calendar + reminders (EKEventKit)
├── WorkoutSchedulerView.swift    Schedule workouts UI
├── FutureSelfRevealView.swift    3-image parallel gen + drag slider
└── ConsentView.swift
```

---

## Supabase Database

**Project:** huclolzxzpitdpyogolu.supabase.co
**RLS:** Enabled on all tables

### Tables (16)

| Table | Purpose |
|---|---|
| users | Profile, level, XP, streak, goals |
| workout_sessions | Completed workouts |
| workout_sets | Sets logged (weight × reps) |
| nutrition_logs | Daily macro totals |
| food_entries | Individual food items |
| progress_metrics | Weight, sleep, steps, HR |
| personal_bests | PR per exercise |
| xp_transactions | XP audit log |
| badges | 10 badge definitions |
| user_badges | Badges earned |
| activity_feed | Community stream (realtime) |
| feed_reactions | Emoji reactions (realtime) |
| events | Upcoming events |
| event_registrations | Event signups |
| challenges | Group challenges (realtime) |
| challenge_participants | Challenge progress |
| forum_threads | Forum posts (3 sections) |
| forum_replies | Forum replies |

### Views
- `leaderboard` — XP rank, streak rank, weekly rank

### Functions
- `award_xp(user_id, amount, reason)` — adds XP, logs transaction, auto-levels user

### Level Thresholds
- Ember: 0 XP
- Root: 1,000 XP
- Rise: 3,500 XP
- Wylde: 8,000 XP

---

## Design System

### Core Aesthetic
Pure black background (#000000). Gold (#c8a96e) as the ONLY accent color at varying opacities. No cards with heavy fills — sections separated by hairline gold lines (0.5px). Vast negative space. The human figure (logo) is center of identity.

### Brand Reference
The logo image: gold human figure inside sacred geometry circles on pure black. This IS the design language. Everything in the app derives from this.

### Color Tokens

```css
--bg:       #000000        /* pure black */
--surface:  #0d0c0a        /* barely lifted surface */
--gold:     #c8a96e        /* primary accent */
--gold-hi:  rgba(200,169,110,0.85)   /* high emphasis */
--gold-mid: rgba(200,169,110,0.55)   /* medium emphasis */
--gold-lo:  rgba(200,169,110,0.35)   /* low emphasis */
--gold-dim: rgba(200,169,110,0.15)   /* backgrounds */
--text-hi:  rgba(255,245,220,0.95)   /* primary text */
--text-mid: rgba(255,245,220,0.75)   /* secondary text */
--text-lo:  rgba(200,169,110,0.55)   /* labels (MINIMUM) */
```

**Text brightness rule:** No text element below rgba(200,169,110,0.40). Labels minimum 0.45. Secondary text minimum 0.65.

### Typography

| Role | Font | Size |
|---|---|---|
| UI / body | Inter 300–500 | 11–16px |
| Numbers / timers | Space Mono 400/700 | varies |
| Milestones / wins | Montserrat 800 | varies |
| Editorial / coach | Cormorant Garamond italic 300 | 13–18px |

### Button Style
```css
/* All buttons — outline only, no fill */
border: 0.5px solid rgba(200,169,110,0.28);
background: transparent;
color: rgba(200,169,110,0.78);
font-size: 9px;
letter-spacing: .2em;
text-transform: uppercase;
padding: 11px 16px;
border-radius: 0; /* sharp corners */

/* Primary variant */
border-color: rgba(200,169,110,0.45);
color: rgba(200,169,110,0.9);
```

### Section Anatomy
No card blocks. Sections separated by:
```css
border-top: 0.5px solid rgba(200,169,110,0.09);
padding: 16px 0 0;
margin-bottom: 16px;
```

### Alive Elements
- Pulse dot: 4px circle, gold 0.7, scale 1→1.8 over 2.5s
- Heartbeat line: 1px segments, varying widths, gold 0.1–0.36
- Progress fills: gold gradient with shimmer animation
- Momentum bar: 0.5px track, filled with gold glow

---

## Identity Level System

| Level | XP | Accent note |
|---|---|---|
| Ember | 0 | Fire energy |
| Root | 1,000 | Earth/growth |
| Rise | 3,500 | Gold/visible |
| Wylde | 8,000 | Prismatic/iridescent |

In the pure black aesthetic, level changes manifest through:
- Badge text brightness increase
- Pulse dot intensity
- Subtle glow on key elements

---

## Coach Roster

| Name | Energy | Specialty |
|---|---|---|
| Adam | Masc | Strength |
| Marcus | Masc | Performance |
| Zara | Fem | Movement |
| Nadia | Fem | Restoration |
| Sage | Neutral | Mindset |
| Ren | Neutral | Integration |

---

## XP Actions

| Action | XP |
|---|---|
| Complete workout | +50 |
| Log a set | +5 |
| Log meal | +20 |
| Hit water goal | +15 |
| Log sleep | +10 |
| Complete supplement stack | +15 |
| Generate Future Self | +25 |
| 7-day streak bonus | +200 |
| Forum post | +15 |
| Forum reply | +5 |
| Attend event | +100 |
| Refer member | +250 |

---

## App Screens (app.html)

1. **Auth** — email/password sign in + create account. Guest mode fallback.
2. **Start (Onboarding)** — name, gender, age, height, weight, goals (up to 3), fitness level, days/week, health concerns, dietary restrictions
3. **Dashboard** — draggable + collapsible sections. Momentum bar. All 9 data modules.
4. **Future Self** — photo upload → 3 parallel Gemini calls → drag-reveal slider with timeline tabs
5. **Program** — AI workout generator. Rest timer. Set logging with inline history. Finish → celebration.
6. **Coach** — 6 coaches, roster + AI chat (Claude Haiku)
7. **Progress** — streak, session log, personal bests, sleep chart
8. **Nutrition** — macros, AI meal plan, food log (text + photo), water tracker
9. **Supplements** — AI stack generator + Fullscript links
10. **Health+** — Everwell peptide protocols, lab upload, clinical records
11. **Community** — Feed | Forums (Wylde Man / Wylde Woman / Wylde Self) | Leaderboard | Events

---

## iOS App Screens

Same as above plus:
- WorkoutCompleteView (celebration fullscreen)
- RestTimerView (sheet, 90s/60s)
- WorkoutSchedulerView (calendar + reminders)
- FutureSelfRevealView (3-image parallel + drag slider)

---

## Community Forums

Three sections in the Forums tab:

| Section | Accent | Tagline |
|---|---|---|
| Wylde Man | ember #ff6030 | "Iron sharpens iron." |
| Wylde Woman | blush #e88a9a | "She remembered who she was." |
| Wylde Self | gold #f0c040 | "Become who you were always becoming." |

Supabase tables: forum_threads, forum_replies
XP: +15 for post, +5 for reply

---

## Future Self — Image Generation

**Provider:** Gemini 3.1 Flash Image via /api/generate-image.js (Edge Runtime, 30s timeout)
**Flow:** Upload photo → 3 parallel API calls → each timeline resolves independently → drag slider reveal

**Timeline prompts:**
- 12 weeks: leaner, more athletic, 4-6% fat reduction
- 6 months: significant recomposition, 8-12% fat reduction, clear muscle
- 1 year: dramatic transformation, athletic/performance physique

**Goal modifiers:** fat_loss / muscle / athletic / toning

---

## Planned Features (Not Yet Built)

### HIGH PRIORITY
1. **Design overhaul** — apply pure black / gold hairline system to ALL screens in app.html. Currently only partially applied.
2. **Workout flow fix** — make workout logging feel seamless. Quick-tap weight/reps adjusters (+5/-5 lbs, +1/-1 rep). Inline exercise video. Swap exercise button.
3. **Inline exercise history** — show last session's weight × reps on each exercise so user knows what to beat.
4. **Wylde Strength Score** — proprietary metric. Compounds volume + consistency + progression. Shows on dashboard + leaderboard.
5. **Shareable workout card** — after completing workout, generates branded card: logo, workout name, sets/time/streak/score. Share to Instagram Stories.
6. **Muscle map** — SVG body diagram, trained muscles highlight in gold. Shows in workout completion + progress screen.
7. **Text brightness fix** — all secondary/label text too dark. Minimum opacity 0.45 throughout.
8. **Opening sequence** — logo animation on first launch. Logo image already in repo. Progress line fills. Then onboarding starts.

### MEDIUM PRIORITY
9. **Exercise video player** — Grok Imagine generated videos per exercise. Cloudflare Stream hosting. Plays inline during set logging.
10. **PeptideView.swift** — iOS peptide protocol screen (prompt designed, not built)
11. **SupplementView.swift** — iOS supplement screen (prompt designed, not built)
12. **Apple Watch companion** — basic watchOS app: start workout, log set, rest timer on wrist
13. **Supabase full verification** — confirm auth screen live on wyldeself.com, verify all data flows

### LOWER PRIORITY
14. **Apple Sign In** — waiting on Apple Developer verification (48+ hrs pending, contact support)
15. **Clinical Health Records** — HealthKit, requires separate Apple review. Everwell partnership justifies it.
16. **wyldeself.ai domain** — buy (~$50-80/yr)
17. **Trademark** — file post-funding (~$350)
18. **Fullscript links** — update from placeholder to real dispensary URL

---

## Competitive Intelligence (Fitbod)

**What they do well:**
- Exercise database + video demos alongside set logging
- Clean set logging UI (quick-tap increments)
- Muscle recovery table (which muscles need rest)
- Apple Watch integration

**What we do better:**
- AI program generation (they have zero AI)
- Identity system / XP / levels
- Coach AI chat
- Future Self transformation
- Community + forums
- Nutrition integration
- Brand / emotional resonance
- Shareable cards

**Specific Fitbod features to replicate and exceed:**
- Inline video during set logging → we do this with Grok-generated videos
- Muscle map → we have SVG body diagram
- Swap exercise → one tap, our AI picks contextually better replacement
- Quick weight/rep input → +5/-5 buttons, no keyboard required

---

## Claude Code Workflow

```bash
# Web app
cd ~/Wylde-self && claude

# iOS app  
cd ~/Documents/WyldeSelf && claude
```

**Standard flow:**
1. Design / plan in Claude chat
2. Claude writes exact prompt
3. Paste into Claude Code terminal or Cowork
4. Vercel auto-deploys in ~30s
5. Verify on wyldeself.com

**If Claude Code needs re-auth:**
```bash
claude auth
```

---

## Known Issues

- [ ] app.html design system only partially applied — needs full pass
- [ ] All secondary text too dark (below 0.40 opacity)
- [ ] Workout flow feels clunky — too many taps to get to action
- [ ] Overview screen is a stub — no content
- [ ] Coach sidebar doesn't update context on screen change
- [ ] Alternative workout section rendering needs verification
- [ ] Fullscript links are placeholder URLs
- [ ] iOS: ProgramBuilderSheet has no back button
- [ ] iOS: coach portraits are initials only (pending AI-generated images)
- [ ] Apple Developer enrollment pending 48+ hrs — contact Apple support

---

## Immediate Next Actions for Cowork

Run these in order:

### 1. Design system pass — app.html
Apply pure black / gold hairline aesthetic to ALL screens. Fix text brightness. Opening sequence with logo. This is the highest priority.

### 2. Workout flow overhaul — app.html
- Dashboard "Today's session" taps directly into active workout
- Quick-tap +5/-5 weight, +1/-1 rep buttons
- Inline exercise history (last session weight × reps)
- Swap exercise button (AI picks replacement)
- Workout state persists across screen navigation
- Rest timer floats as persistent element during active workout

### 3. Wylde Score + Shareable Card — app.html
- Calculate Wylde Strength Score (volume × consistency × progression index)
- Show on dashboard + leaderboard
- Post-workout shareable card with logo, stats, score

### 4. iOS design match — WyldeSelf Xcode
After web is verified, apply same design tokens to iOS SwiftUI files.

### 5. Grok video integration
- Set up api.x.ai account + key
- Build /api/grok-video.js proxy
- Pre-generate 30 core exercises
- Upload to Cloudflare Stream
- Wire video player into Program screen

---

## Session Log

### Session 7 — April 2026 (current)
- Competitive analysis vs Fitbod — identified gaps and advantages
- Decided on pure black / gold hairline design system (derived from logo image)
- Built dashboard mockup with actual logo embedded (dashboard_preview.html)
- Identified 8 high-priority build items
- Planned muscle map, Wylde Score, shareable card, inline exercise history
- Grok Imagine researched for exercise video — API live, $0.05/sec
- Moved build operations to Claude Cowork for structured execution
- This HANDOFF.md written for Cowork transition

### Session 6 — April 2026
- Gender-neutral rebrand — Ember/Root/Rise/Wylde arc
- Balanced coach roster (2M/2F/2N)
- Living color system per identity level
- New typography system (Inter/Space Mono/Montserrat/Cormorant)
- Draggable dashboard (web + iOS)
- Collapsible cards with header summary values
- Rest timer (90s/60s, 3-phase color journey)
- Future Self: 3 parallel Gemini, drag-reveal slider, timeline tabs
- Supabase: 16 tables, leaderboard view, award_xp function, RLS
- Supabase wired to web + iOS
- Community screen: feed, leaderboard, events (web + iOS)
- Forum system: Wylde Man / Wylde Woman / Wylde Self
- XP engine + badge system
- WorkoutCompleteView celebration
- HealthKitService read/write + Clinical Health Records
- ScheduleService calendar + reminders
- FutureSelfRevealView 3-image parallel + drag slider
- Xcode errors fixed: Combine imports, MainActor, deprecations
- Supabase Swift package added to Xcode

### Session 5 — April 2026
- Switched image gen to Gemini 3.1 Flash Image
- Future Self image gen working end-to-end
- ConsentView, Future Self coach added
- PeptideView + SupplementView prompts designed

### Session 4 — April 2026
- Native iOS SwiftUI app scaffolded at ~/Documents/WyldeSelf
- All core Swift files built
- CoachPersona, CoachView, ProgramView, NutritionView
- ExerciseDatabase, WorkoutSession

### Session 3 — April 2026
- 13-slide VC pitch deck (investors.html live)
- Pre-seed SAFE $1M ask

### Session 2 — April 2026
- Image gen, coach sidebar, food log, supplement stack
- gate.html, apply.html rebuilt
- Full design pass

### Session 1 — April 2026
- Initial build — all 10 screens, Claude API, localStorage, nav
