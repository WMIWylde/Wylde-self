# WYLDE SELF — Project Handoff
> Last updated: April 2026 · Update this file at the end of every chat session.

---

## Project Overview

**Wylde Self** is an AI-powered identity transformation fitness app. The core thesis: identity precedes behaviour. People don't quit fitness because they lack discipline — they quit because they can't see who they're becoming. Wylde Self is built around closing that gap.

**Founder:** Wilke — background in men's coaching, yoga, somatic work, real estate, and entrepreneurship.
**Mastermind:** Mentor Collective (Chris & Lori Harder) — coaching across AI, marketing, social funnels.

---

## Live URLs

| Page | URL |
|------|-----|
| Landing page | wyldeself.com |
| App | wyldeself.com/app.html |
| Beta gate | wyldeself.com/gate.html |
| Apply form | wyldeself.com/apply.html |
| Investor deck | wyldeself.com/investors.html |

---

## Tech Stack

| Layer | Detail |
|-------|--------|
| Frontend | Single HTML file (app.html ~200KB) |
| Hosting | Vercel — auto-deploy from GitHub |
| Repo | github.com/WMIWylde/Wylde-self |
| Claude Code | Installed at ~/Wylde-self |
| AI — Coaching | Claude Haiku via /api/anthropic.js proxy |
| AI — Image gen | Google Gemini 3.1 Flash Image via /api/generate-image.js (Edge Runtime) |
| Forms | Formspree (mkoponoz), EmailJS (service: Wylde_service, template: template_5th6z59) |
| Supplements | Fullscript dispensary — Wylde Self Health |
| Env vars | ANTHROPIC_API_KEY, GEMINI_API_KEY (stored in Vercel) |

---

## File Structure

```
~/Wylde-self/
├── index.html          # Landing page — waitlist form, before/after slider
├── gate.html           # Beta access gate — NDA + access code (WYLDE2025)
├── app.html            # Main app — all 10 screens in one file
├── apply.html          # 30-day beta intake form
├── investors.html      # VC pitch deck — TO BE ADDED (file ready in chat)
├── api/
│   ├── anthropic.js    # Claude Haiku proxy
│   └── fal.js          # fal.ai image gen proxy (POST submit + GET poll)
└── HANDOFF.md          # This file
```

---

## App Screens (Nav Order)

1. **Start** — Onboarding: name, gender, age, height, weight, goal, fitness level, days/week, health concerns, dietary restrictions
2. **Overview** — (stub)
3. **Dashboard** — Profile card, stats (weight/steps/sleep/water/energy), calorie ring, macro bars, motivational quote, transformation roadmap
4. **Future Self** — Photo upload → fal.ai image-to-image → before/after reveal. Timeline: 12 weeks / 6 months / 1 year
5. **Program** — AI workout generator via Claude Haiku. Day cards with exercises. Alt program rebuild section with quick pills
6. **Coach** — Full AI chat screen wired to Claude Haiku. Context-aware, profile-personalised
7. **Progress** — Session counter, streak, week tracker, session log
8. **Nutrition** — Macro calculator (Mifflin-St Jeor), AI meal plan, recipe guide, food log with AI macro estimation, photo scan of nutrition labels
9. **Supplements** — AI supplement stack generator via Claude + Fullscript deep-links. Personalised to profile
10. **Health+** — Functional medicine consultation (Everwell USA partnership), lab upload, peptide library (BPC-157, Ipamorelin, TB-500, NAD+, Tesamorelin, Thymosin Alpha-1, SEMAX), supplement marketplace shortcut

---

## Key Features Built

### AI Features (all via /api/anthropic.js → Claude Haiku)
- Workout program generation
- Alternative workout rebuild (pills + text input)
- Meal plan generation
- Recipe guide
- Food macro estimation by text
- Food macro estimation by photo (vision)
- Peptide protocol builder
- Coach sidebar (floating gold button, slide-in panel, 4-message history, context-aware opening)
- Coach screen (full chat, real Claude API)
- Transformation roadmap (phased 12-week plan with nutrition targets per phase)
- Supplement stack generation (4-6 supplements, Fullscript links)
- Exercise form guide modals (AI-generated instructions per exercise)

### Image Generation (via /api/fal.js → fal.ai)
- Future Self transformation — uploads photo, generates physique transformation
- Endpoint: fal-ai/flux/dev/image-to-image
- Flow: POST → queued → poll GET until COMPLETED → fetch response_url for image
- Fixed: GET poll handler fetches both status URL and response URL when COMPLETED

### Access Flow
- Landing page: name + email → localStorage (persists forever)
- gate.html: pre-fills name from localStorage, NDA checkbox, access code WYLDE2025 (case insensitive)
- app.html: gate check on load, pre-fills name from localStorage
- Returning users: skip gate entirely (wylde_gate_passed in localStorage)

### Gamification (designed, partial implementation)
- Identity levels: Ember → Forge → Steel → Wylde
- Streak tracking
- Session log
- Future Self Gap concept (Current Self → Future Self progress ring)
- FORGE LEVEL badge (in mockups, partial in app)

---

## Brand

| Token | Value |
|-------|-------|
| Background | #080808 |
| Surface | #161616 |
| Gold accent | #c8a96e |
| White text | #f5f4f0 |
| Muted text | #a0a098 |
| Border | rgba(255,255,255,0.08) |
| Header font | Bebas Neue |
| Serif font | Cormorant Garamond italic |
| Body font | DM Sans |

**Tagline:** "Train with the person you're becoming."
**Logo:** SVG file (logo.svg) — Vitruvian man figure in sacred geometry circle + WYLDE SELF wordmark

---

## External Partnerships & Integrations

| Partner | Status | Detail |
|---------|--------|--------|
| Everwell USA (Newport Beach) | Active | Peptide protocols featured in Health+ |
| Fullscript | Setting up | Dispensary name: Wylde Self Health. API access applied for. Code: WYLDE2025 |
| Mentor Collective Mastermind | Active | Chris & Lori Harder — coaching, AI, marketing, sales funnels |

---

## Claude Code Workflow

```bash
cd ~/Wylde-self && claude
```

1. Describe the change in this chat
2. Claude writes the exact Claude Code prompt
3. Paste into Terminal
4. Claude Code edits files and pushes
5. Vercel deploys in ~30 seconds
6. Claude in Chrome extension used to test live at wyldeself.com

**If Claude Code asks to re-authenticate:**
```bash
claude auth
```
Follow the browser prompt.

---

## Debugging Workflow (Claude in Chrome)

```javascript
// Read source
fetch('/app.html').then(r => r.text()).then(html => {
  const idx = html.indexOf('functionName');
  console.log('LABEL:', html.substring(idx, idx + 1000));
});

// Clear console between reads
// Use pattern matching: read_console_messages({ pattern: 'LABEL' })
```

---

## Known Issues / To Fix

- [ ] Alternative workout section rendering after program generates (needs verification)
- [ ] CSS exercise animations — figure shows but limited motion accuracy
- [ ] Coach sidebar context update when screen changes (stub only)
- [ ] OVERVIEW nav tab is a stub — no screen content yet
- [ ] Apple Health integration — web only (manual entry). Full HealthKit needs React Native
- [ ] Fullscript links still placeholder — update with real dispensary URL once live

---

## Pending / Next Up

- [ ] iOS: paste PeptideView.swift Claude Code prompt
- [ ] iOS: paste SupplementView.swift Claude Code prompt
- [ ] Web + iOS: full design polish pass — make app look beautiful (Shred-level quality)
- [ ] Before/after reveal UI polish on Future Self screen
- [ ] Add "Investors" link to index.html nav
- [ ] Confirm Fullscript dispensary setup and update Shop links
- [ ] Buy wyldeself.ai domain
- [ ] Update HANDOFF.md Live URLs — investors.html is now live

---

## VC Pitch Deck Status

**File:** investors.html — fully built, self-contained HTML file
**Tool:** Built in Claude chat (not Pitch.com — HTML deck is better quality)
**Status:** Complete, needs to be added to repo at /investors.html
**Stage:** Pre-seed SAFE
**Ask:** $1M (initial close $750K)

### Deck Structure (13 slides)
1. Cover — Logo strip top, WYLDE SELF display, sacred geometry background
2. Problem — Two col, 4 bullets, 4× stat (Norcross et al.)
3. Insight — Neural head background, identity science, 66-day + 2-3× callouts (Lally/UCL, Bem)
4. Solution — 4-step flow grid (Fitness / Nutrition / Mindset / Integration)
5. Product — Two col, app screen mockup image right
6. Transformation — Full-width before/during/after photo
7. Market — Two col, 4 bar charts ($5.6T / $27B / $44B / $2.1B)
8. Business Model — 2×2 revenue grid (Subscription / Coaching / Products / Data)
9. Traction — 2×2 stats (200 waitlist / 20 beta / Live product / $0 spend)
10. Unfair Advantage — 2×2 pillars (Lived experience / Community / Philosophy+Tech / Category)
11. The Ask — $1M display, SAFE structure, 4-way fund allocation
12. Vision — Two col, 4 arrow statements, logo decorative right
13. Roadmap — 4-phase timeline (Validate / Launch / Scale / Expand)

### Science Citations Used
- **4×** habit attempt rate — Norcross et al., Journal of Clinical Psychology
- **66 days** habit formation average — Lally et al., University College London
- **2–3×** follow-through with identity anchoring — Bem Self-Perception Theory + Implementation Intentions research

### Assets Embedded in Deck
- Sacred geometry background (cover)
- Neural head image (insight slide)
- Transformation before/during/after photo
- App screen mockups
- Gold chart graphic (market slide)
- Wylde Self SVG logo (all slides, top-left; large strip on cover)

---

## Domain Notes
- Primary: wyldeself.com (live, Vercel)
- To buy: wyldeself.ai — decided April 2026, ~$50-80/yr, on-brand for AI product
- WHOIS privacy: low urgency, turn on when convenient
- Trademark: file after first funding close (~$350, use a lawyer)

---

## Session Log

### Session 5 — April 2026
- Switched image generation from fal.ai to OpenAI (gpt-image-1 / dall-e-2) — multiple failures due to model restrictions, billing limits, PNG format requirements
- Verified OpenAI org as Individual — unlocked gpt-image-1
- Switched to Google Gemini 3.1 Flash Image (Nano Banana) via Gemini API
- Added GEMINI_API_KEY to Vercel environment variables
- Fixed model name to gemini-3.1-flash-image-preview
- Fixed generationConfig to use responseModalities: ["TEXT", "IMAGE"] (no responseMimeType)
- Switched api/generate-image.js to Vercel Edge Runtime to get 30s timeout on Hobby plan
- Future Self image generation now WORKING — realistic output confirmed live
- Added photo preview to Future Self upload zone (shows TODAY label, X to clear)
- Added consent flow (ConsentView.swift) — fixed duplicate body declaration
- Added Future Self as special featured coach in coach roster
- Designed PeptideView.swift and SupplementView.swift prompts (ready to build next session)
- iOS: back button fix, workout tracker UI redesign prompts written
- iOS: coach portrait images added (Adam, Marcus, Kai, Cole, Sage, Ren)

### Session 4 — April 2026
- Started native iOS app in Xcode/SwiftUI at ~/Documents/WyldeSelf
- Scaffolded all core Swift files: Theme, APIService, UserProfile, OnboardingView, MainTabView, DashboardView, ProgramView, CoachView, NutritionView, ProgressView
- Fixed UserProfile ObservableObject (import SwiftUI + Combine)
- Fixed iOS simulator setup (iPhone 17 Pro Max)
- Updated OnboardingView: multi-select goals up to 3, 12 goal options, rounded corners, "Your full name" label
- Built CoachPersona.swift with 6 coaches: Adam, Marcus, Kai, Cole, Sage, Ren
- Built full CoachView with roster screen and AI chat per coach
- Built ProgramView: AI program generator, progression levels (Ember/Forge/Steel/Wylde), session logging with difficulty rating, custom program builder
- Built NutritionView: macro tracking, AI food log estimation, AI meal plan generator
- Built ExerciseDatabase.swift and WorkoutSession.swift
- Fixed API: added model field to anthropic.js proxy
- Extracted slide1_cover.jpg from investors.html, added as hero background on index.html
- Known issues: ProgramBuilderSheet has no back button, coach portraits are initials placeholders pending AI-generated images

### Session 3 — April 2026
- Built full 13-slide VC pitch deck as self-contained HTML file
- Embedded all 6 brand images (sacred geometry, neural head, transformation, app screens, gold chart, supplements)
- Integrated SVG logo across all slides (vector, no quality loss, no background artifacts)
- Added identity science callouts (Norcross 4×, Lally 66 days, Bem 2-3×)
- Iterative design fixes: layout cramping, text brightness, slide label overlaps, transformation image crop
- Decided on investors.html as separate page linked from main nav
- Decided to buy wyldeself.ai domain
- Discussed trademark timing (post-funding)
- Discussed HANDOFF.md workflow for persistent context across chat sessions
- OS reset on Wilke's machine mid-session — Chrome extension and Terminal need to be reconnected

### Session 2 — April 2026
- Fixed fal.ai image generation end-to-end (proxy GET poll, reveal race condition)
- Built coach sidebar from scratch (Claude Haiku, typing indicator, opening message)
- Fixed coach screen sendMessage() from pre-written responses to real Claude API
- Added SVG exercise animations to form modals
- Built transformation roadmap feature on Dashboard
- Built AI food log with text + photo macro estimation
- Built AI supplement stack marketplace (Health+ and Supplements tab)
- Added Supplements as dedicated nav tab
- Converted top nav to left side nav
- Added localStorage profile persistence
- Rebuilt gate.html with NDA + access code flow
- Fixed gate.html checkbox double-fire bug
- Updated all "naturopath" copy to "functional medicine practitioner"
- Built /apply.html — 30-day beta intake form (Formspree + EmailJS)
- Updated apply.html — multi-select goals, sleep quality, expanded training locations
- Moved Health+ to last nav position
- Updated disclaimer banner copy
- Completed full design pass (spacing, surface contrast, nav polish)
- Discussed VC pitch strategy, founder story, deck structure
- Generated 9 app mockup screens via ChatGPT prompts
- Discussed React Native path (solo buildable with Claude Code + Expo)
- Set up Pitch.com account for deck building
