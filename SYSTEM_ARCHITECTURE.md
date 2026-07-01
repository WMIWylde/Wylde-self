# Wylde Self — Complete System Architecture
## As of June 20, 2026

---

## 1. PRODUCT OVERVIEW

Wylde Self is a health transformation platform with three interfaces:

1. **iOS App** (SwiftUI, native) — consumer-facing: daily rituals, workouts, nutrition, AI coaching, future self visualization
2. **Web App** (vanilla JS SPA) — consumer-facing: same features via browser at wyldeself.com/app.html
3. **Clinical Dashboard** (vanilla JS SPA) — clinician-facing: patient management, protocols, product library, adherence tracking at wyldeself.com/clinical-dashboard.html

All three share one **Supabase** project (Postgres + Auth + RLS) and one **Vercel** deployment for API routes.

---

## 2. TECHNOLOGY STACK

| Layer | Technology | Location |
|-------|-----------|----------|
| iOS App | SwiftUI, Supabase Swift SDK, AVKit | `~/Wylde-self/WyldeSelf-iOS/` |
| Web App | Vanilla JS, HTML/CSS, Supabase JS SDK | `~/Wylde-self/app.html` |
| Clinical Dashboard | Vanilla JS, Tailwind CSS, Supabase JS SDK | `~/Wylde-self/clinical-dashboard.html` |
| API Layer | Node.js (Vercel Serverless Functions) | `~/Wylde-self/api/` |
| Database | PostgreSQL via Supabase | `huclolzxzpitdpyogolu.supabase.co` |
| Auth | Supabase Auth (email/password + magic link) | Shared across all interfaces |
| AI — Image Gen | Google Gemini (3.x models) | `/api/generate-image.js` |
| AI — Coach Chat | OpenAI GPT-4o-mini | `/api/openai.js` |
| AI — Program Gen | OpenAI GPT-4o-mini | `/api/openai.js` |
| AI — Food Analysis | OpenAI GPT-4o (vision) | `/api/openai.js` |
| AI — Identity Analysis | Anthropic Claude Haiku | `/api/identity-analyze.js` |
| Hosting | Vercel (web + API) | wyldeself.com |
| Payments | RevenueCat (iOS IAP) + Stripe (web) | Partially wired |

---

## 3. iOS APP — FEATURE MAP

### 3.1 Authentication
- Email + password sign-in and sign-up
- Magic link sign-in (Supabase OTP)
- Deep link handling via `wyldeself://auth/callback` URL scheme
- Session persistence with auto-restore on launch
- Token caching for API calls

### 3.2 Onboarding (5 steps)
1. **Name & Gender** — first name, identity (Male/Female)
2. **Training Goals** — multi-select: Burn fat, Build muscle, Get lean, Build confidence, Improve endurance, Increase flexibility
3. **Training Setup** — fitness level, days/week, equipment, gym access, gym name, workout classes
4. **Body Details** — age range, height range, weight, health concerns (9 options + notes)
5. **Dietary Preferences** — 11 diet options + notes
6. **Future Self Photo** — upload photo for AI transformation rendering (optional, skippable)

### 3.3 Today Screen (main dashboard)
Cards in order from top:
- **Header** — greeting + name + streak badge
- **Hero Card** — cinematic full-bleed image, "DAY X of becoming who you said you'd be", gold "Start Today" CTA
- **Morning Ritual** (collapsible) — 4 daily practices:
  - Energy Movement (guided Qi Gong flow — 7 movements, ~5 min)
  - Meditation (guided visualization with audio + glowing silhouette animation)
  - Journaling (check off)
  - Reading (check off + book title tracker + pages/day counter)
- **Workout** — shows today's program focus + exercise count, or "Generate Program" if none exists
- **Walk** — daily 30+ min walk toggle
- **Nutrition** — protein/calorie progress bars + "Plan" button (meal planner) + "Log" button (photo macro tracker) + today's logged meals with checkboxes
- **Future You** — dark card with silhouette, links to Future tab
- **AI Coach** — "Talk to Future [Name]", opens chat
- **Health** — HealthKit steps + calories

### 3.4 Workout System
**Program Types:**
- AI-Built (OpenAI generates custom split from user profile)
- Strength Split (4-day template: Chest/Tri, Back/Bi, Legs/Core, Shoulders/Arms)
- Kettlebell HIIT (4-day full body core: Power, Core/Conditioning, Lower Body, Upper Body)

**Workout Structure (every day):**
1. Dynamic Warmup (10 min) — 5 guided movements with streaming video from wyldeself.com
2. 5-6 Strength exercises — set/rep logging with steppers
3. Cardio finisher (15-20 min) — timer

**Exercise Card Features:**
- Suggested starting weight (gender + level aware, covers 20+ exercise types)
- Personal Record badge (gold)
- Progressive overload tips after each logged set
- Bodyweight detection (push-ups, pull-ups etc — hides weight stepper, shows "BW")
- Beginner education guide (expandable: Progressive Overload, Hypertrophy, Compound vs Isolation, Rest, RPE, Form)

**Rest Timer:**
- Appears after every logged set (except last)
- 90 seconds for compound movements, 60 seconds for isolation
- Circular countdown ring with color states: Rest → Get Ready (last 10s) → Go!
- Skip option

**Dynamic Warmup Flow:**
- 5 movements: Arm Circles (30s), Leg Swings (30s), Hip Openers (35s), Bodyweight Squats (40s), Light Jog (45s)
- Streaming video backgrounds from wyldeself.com/warmup-videos/
- Per-movement accent colors + SF Symbol icons
- Timer ring, coaching cues, progress segments
- Controls: Play/Pause, +15s, Skip
- Intro → Active → "Body activated. Let's train."

### 3.5 Guided Flows
**Qi Gong / Energy Movement:**
- 7 movements (~5 min): Standing Meditation → Raising the Sky → Pushing Mountains → Turning the Waist → Gathering Energy → Shaking the Tree → Standing Stillness
- Purple accent, timer ring, coaching cues per movement

**Guided Visualization Meditation:**
- Glowing silhouette of meditating figure (expands/contracts on 4s breathing cycle)
- Dual-layer radial glow animation (teal)
- 10-minute bundled audio track plays automatically
- Rotating visualization prompts every 30s
- Pause/End controls

### 3.6 Nutrition System
**Photo Macro Tracker:**
- Camera or photo library → image sent to GPT-4o vision
- AI returns: description, calories, protein, carbs, fat, per-item breakdown
- Select meal type (Breakfast/Lunch/Dinner/Snack) → log
- Syncs totals to AppState protein/calorie counters
- Meals persist per day (auto-reset at midnight)

**Weekly Meal Planner:**
- AI-generated 7-day plan (OpenAI) based on goals, dietary prefs, macro targets
- 4 meals/day (Breakfast, Lunch, Dinner, Snack)
- Each meal: name, description, ingredients, step-by-step instructions, prep time, full macros
- Day-by-day navigation with completion badges
- Expandable recipe cards with checkboxes
- Grocery list grouped by category (Protein, Produce, Dairy, Pantry, Grains) with checkboxes
- Fallback template if AI fails

### 3.7 AI Coach
- Full-screen dark chat interface
- Speaks as user's **future self** — calm, direct, no cheerleading
- System prompt: 2-4 sentences, no hedging, no emojis, quiet certainty
- Context-aware: name, gender, goals, fitness level, streak, today's progress (workout, walk, ritual, protein)
- Quick actions: "Motivate me", "Fix my plan", "I'm off track", "Optimize everything"
- Chat history persists last 30 messages across sessions
- Uses OpenAI GPT-4o-mini via `/api/openai`
- Coach line rotation system (CoachLine.swift) for one-sentence affirmations at key moments

### 3.8 Future Vision
- **FutureTabView** — segment control: Vision / Transformation
- **Vision Creation Flow** (full-screen sheet):
  1. Select life categories (10 options, 2-column grid)
  2. Guided reflection prompts per category (2-3 questions each)
  3. AI generates one cinematic photograph per category via Gemini
  4. Preview generated VisionCards
- **VisionCard** — large 4:5 aspect ratio cinematic cards: hero image, gradient overlay, category label (gold), identity statement (serif), "why it matters"
- **Gallery** — scrollable cards + "Add a vision" button
- **10 Categories:** Health & Body, Relationships, Family, Wealth, Business, Home, Adventure, Spirituality, Impact, Lifestyle

### 3.9 Future Self Transformation
- Photo upload → AI generates transformed physique at 3 timelines (12 weeks, 6 months, 1 year)
- Gender-aware prompts (male bodybuilder vs female fitness athlete language)
- Goal-aware (bulk, cut, endurance, flexibility)
- Currently via embedded WebView pointing to web app's Future Self screen

### 3.10 Clinical Integration (Consumer Side)
- **CareTeamView** — generate share codes, enter clinician codes, view/revoke relationships
- **CheckinSync** — background service observing AppState daily toggles (morning ritual, workout, walk, nutrition), debounced 2.5s, POSTs to `/api/consumer/checkin`
- **ClinicalAPI** — wrapper for all consumer endpoints with JWT auth attachment
- Only syncs when active care relationship exists

### 3.11 Design System
**Adaptive Colors (WyldeStyles.swift):**
- Auto-switches between light and dark palettes using UIColor trait collections
- Dark palette matches web app: `#070707` bg, `#111111` surface, `#F4F1E8` text, `#C8A96E` gold, `#D4BE92` sage
- Light palette: `#F4F1EC` paper, `#1A1816` ink, `#7A8771` sage, `#9C7A4A` bronze

**Cinematic Effects (CinematicEffects.swift):**
- `AmbientBackground` — animated radial glow blobs (drift on 24s cycle)
- `CinematicHeroCard` — large card with gradient overlays
- `GlassCard` — glassmorphism with ultraThinMaterial
- `GoldButton` — gradient CTA (top: `#E6C886`, bottom: `#A6834A`)
- `RadialGlowOverlay` — subtle glow for sections
- `GlowingProgressBar` — progress bar with glow trail
- `BlurredTabBarBackground` — glass tab bar

**Visual Assets in Asset Catalog:**
- HeroBackground, FutureSelfMan, FutureSelfWoman, GlowMale, GlowFemale, GlowNeutral, LogoIcon, LogoMark, AppIcon, AppInHand

### 3.12 State Management
- Central `AppState` (ObservableObject) with `@Published` properties
- Persistence: UserDefaults with inline `didSet` for simple types, `saveCodable/loadCodable` for complex types
- Date-scoped keys for daily counters (auto-reset at midnight)
- Appearance mode: "dark" (default), "light", or "system"

### 3.13 Navigation Structure
4 tabs: Today, Library (exercises), Future (vision + transformation), You (profile + care team + settings)

---

## 4. WEB APP — FEATURE MAP (app.html)

### 4.1 Core Features
- Onboarding (4 steps: name/gender → goals/equipment/gym → body/health → diet)
- Today screen with daily path (workout, walk, nutrition, morning protocol)
- AI workout program generator (OpenAI)
- Exercise library (873 exercises from free-exercise-db)
- Set/rep logging with PR tracking and rest timers
- Dynamic warmup overlay (5 movements with video)
- Future Self transformation (3 timelines with Gemini image generation)
- AI Coach chat (speaks as future self, Claude Haiku)
- Nutrition tracking (food logging, macro display)
- Identity Import (social URL analysis via Claude)
- Push notifications (web push via service worker)
- Light/dark mode toggle
- Pro entitlement (RevenueCat + Stripe, founding member system)

### 4.2 Data Storage
- Supabase client-side (direct table reads/writes for profiles, workouts, food logs, etc.)
- localStorage for session state, chat history, workout logs

---

## 5. CLINICAL DASHBOARD — FEATURE MAP (clinical-dashboard.html)

### 5.1 Authentication
- Supabase email/password sign-in and sign-up
- Separate clinician accounts (same Supabase project, different users)

### 5.2 Sidebar Navigation
- Dashboard (overview)
- Patients (list + detail)
- Protocols (all active protocols across patients)
- Product Library (peptides, supplements, medications, services, lab tests)
- Billing (coming soon)
- Settings (coming soon)

### 5.3 Dashboard
- Stats: Active Patients, Avg Adherence %, Check-ins Today, Total Protocols
- Patient list with adherence scores and today's check-in status
- Recent activity feed
- Product library quick stats

### 5.4 Patient Management
- Accept patient share codes (6-char alphanumeric, 7-day expiry)
- Patient list with click-to-detail
- **Patient Detail View:**
  - Profile header with avatar, name, email, linked date
  - Adherence % and total check-in count
  - Check-in history table (21 rows): date, doses, workout, nutrition, mood, weight, notes
  - Score indicators: ✓ (green), ~ (yellow), — (gray)
  - Current protocols with phase and start date
  - Active prescriptions with dose, frequency, status
  - Clinician notes (general, protocol, lab, follow-up)
  - "Assign Protocol" and "Add Note" action buttons

### 5.5 Protocol Assignment
- Modal: name protocol, select phase
- Select products from clinic's library (checkboxes)
- Creates protocol + prescriptions in Supabase
- Assigned protocols appear on patient's iOS app

### 5.6 Product Library
- Card grid with category icons (💉 peptide, 💊 supplement/medication, 🩺 service, 🧪 lab test)
- Add Product modal: name, category, description, dose, frequency, method, cycle length, price, price unit, mechanism of action
- In-stock/out-of-stock status
- Pricing per unit/month/cycle/session
- Edit and delete (soft delete)

### 5.7 Patient Notes
- Add notes per patient
- Types: General, Protocol, Lab Result, Follow-up
- Chronological list with timestamps

---

## 6. API LAYER — ENDPOINT MAP

All deployed to Vercel at `www.wyldeself.com/api/*`

### 6.1 AI Endpoints
| Endpoint | Method | Purpose | AI Model |
|----------|--------|---------|----------|
| `/api/openai` | POST | Chat completions proxy (coach, program gen, meal plan, food analysis) | GPT-4o-mini |
| `/api/anthropic` | POST | Chat completions proxy (web coach) | Claude Haiku |
| `/api/generate-image` | POST | Image generation (3 modes: physique, vision_board, future_vision) | Gemini 3.x |
| `/api/identity-analyze` | POST | Identity profile analysis from social URLs | Claude Haiku |

### 6.2 Consumer Endpoints (iOS app calls these)
| Endpoint | Method | Purpose |
|----------|--------|---------|
| `/api/consumer/me` | GET | Patient profile, active protocol, prescriptions, today's state |
| `/api/consumer/progress` | GET | 90-day timeseries, baseline vs current comparison |
| `/api/consumer/checkin` | POST | Daily adherence upsert (doses, workout, nutrition, mood, weight, sleep, HRV, RHR) |
| `/api/consumer/care/invite` | POST | Generate 6-char share code (7-day expiry) |
| `/api/consumer/care/accept` | POST | Clinician accepts patient code, creates relationship |
| `/api/consumer/care/relationships` | GET | List active relationships + pending invites |
| `/api/consumer/care/relationships` | DELETE | Revoke care access |

### 6.3 Clinic Endpoints (dashboard calls these)
| Endpoint | Method | Purpose |
|----------|--------|---------|
| `/api/clinic/products` | GET | List clinician's product catalog |
| `/api/clinic/products` | POST | Add new product |
| `/api/clinic/products` | PUT | Update product |
| `/api/clinic/products` | DELETE | Soft-delete product |
| `/api/clinic/notes` | GET | List notes for a patient |
| `/api/clinic/notes` | POST | Add note to patient |
| `/api/clinic/assign-protocol` | POST | Create protocol + prescriptions for patient |

### 6.4 Other Endpoints
| Endpoint | Method | Purpose |
|----------|--------|---------|
| `/api/exercises` | GET | Exercise library search/filter (873 exercises) |
| `/api/exercise-demo` | GET | Single exercise lookup with demo images |
| `/api/predict-protocol` | POST | AI protocol prediction (Claude) |
| `/api/protocol-checklist` | GET/POST | Peptide protocol tracking |
| `/api/founder-count` | GET | Founding member counter |
| `/api/revenuecat-webhook` | POST | RevenueCat → Supabase sync |
| `/api/send-push` | POST | Manual push notification |
| `/api/cron-push` | POST | Scheduled push notifications |

---

## 7. DATABASE SCHEMA (Supabase PostgreSQL)

### 7.1 Core User Tables
- `profiles` — id, email, profile_data (JSONB), xp, streak, weekly_sessions, morning_protocol, program, wylde_pro_status, founding_member_number, notification_prefs
- `user_identity_profile` — identity_archetype, confidence_level, communication_tone, motivation_triggers, limiting_patterns, aspirational_identity, coaching_style, language_to_use, language_to_avoid, discipline_level

### 7.2 Fitness & Tracking
- `workout_sessions` — high-level workout events
- `workout_sets` — individual sets (exercise, weight, reps)
- `personal_bests` — PR tracking per exercise
- `weekly_check_ins` — weekly summaries
- `daily_walks` — walk tracking
- `food_logs` — daily food intake
- `food_feels` — emotional/satisfaction tags on meals

### 7.3 Clinical System
- `care_invite_codes` — user_id, code (unique), message, access_level, status (pending/accepted/expired/revoked), accepted_by, expires_at
- `care_relationships` — patient_id, clinician_id, clinic_name, status (active/paused/revoked), linked_at, revoked_at. Unique constraint on (patient_id, clinician_id)
- `patient_checkins` — user_id, date (unique per user per day), doses, daily_checkin, workout, nutrition, weight, sleep_score, hrv, rhr, mood, notes
- `patient_protocols` — user_id, name, phase, status (active/paused/completed), assigned_by, started_at, config (JSONB)
- `patient_prescriptions` — protocol_id, user_id, drug, dose, frequency, timing, method, status, last_filled_at

### 7.4 Peptide System
- `peptide_knowledge` — reference data (name, category, mechanism, benefits, dose, cycle, contraindications, stacking notes, research summary)
- `peptide_protocols` — user protocols (peptide_name, dose, frequency, timing, method, cycle_weeks, start/end dates, status)
- `protocol_doses` — individual dose logs (taken_at, skipped, notes)
- `protocol_logs` — weekly progress (energy, sleep, recovery, mood, pain, weight, notes)

### 7.5 Clinic Products
- `clinic_products` — clinician_id, name, category (peptide/supplement/medication/service/lab_test), description, mechanism, benefits, contraindications, typical_dose, cycle_length, frequency, method, price, price_unit, in_stock, image_url

### 7.6 Patient Notes
- `patient_notes` — clinician_id, patient_id, content, note_type (general/protocol/lab/follow_up)

### 7.7 Social & Engagement
- `feed_posts`, `badges`, `leaderboard`, `activity_feed`

### 7.8 Push Notifications
- `push_subscriptions` — user_id, platform (web/ios), endpoint, keys, notification_prefs

### 7.9 RLS Policy Summary
- Users see own data (all tables)
- Clinicians with active `care_relationships` can read: patient_checkins, patient_prescriptions
- Clinicians manage own: clinic_products, patient_notes
- Patients can view: clinic_products from their linked clinician
- Care participants (patient or clinician) can see: care_invite_codes, care_relationships

---

## 8. AUTH FLOW

### Consumer (iOS app)
1. User signs up with email + password (Supabase Auth)
2. Session token cached in AuthService
3. Token attached to all ClinicalAPI requests as Bearer header
4. Session auto-restored on app launch via `AuthService.restore()`
5. If session invalid, user redirected to sign-in screen

### Clinician (web dashboard)
1. Clinician signs up/in with email + password (same Supabase project)
2. Session managed by Supabase JS SDK
3. Token attached to all `/api/clinic/*` and `/api/consumer/care/*` calls

### Care Relationship Flow
1. Patient generates 6-char share code in iOS app (CareTeamView)
2. Code stored in `care_invite_codes` with 7-day expiry
3. Clinician enters code in dashboard → POST `/api/consumer/care/accept`
4. System creates `care_relationships` row (patient_id ↔ clinician_id)
5. Patient's CheckinSync detects active relationship → begins auto-syncing daily data
6. Clinician sees patient in dashboard with check-in history

---

## 9. DATA FLOW — DAILY LOOP

```
User wakes up
  → Opens iOS app → Today screen
  → Taps Energy Movement → Qi Gong guided flow (5 min)
  → Taps Meditation → Guided visualization with audio (10 min)
  → Checks off Journaling
  → Checks off Reading → logs pages read
  → Morning Ritual complete (4/4)

  → Taps Start Workout → Dynamic Warmup (5 guided movements with video)
  → Strength exercises → logs sets/reps/weight → rest timer between sets
  → Cardio finisher
  → Workout complete

  → Taps Log on Nutrition → photos meal → AI returns macros → logs as Lunch
  → Or opens Meal Plan → follows today's recipes → checks off meals

  → Taps 30+ min walk → toggle complete

  → Talks to AI Coach → "How am I doing?" → Coach references today's data

  → CheckinSync observes all toggles → debounces 2.5s
  → POSTs to /api/consumer/checkin with:
      doses, daily_checkin, workout, nutrition scores

  → Clinician opens dashboard
  → Sees patient's check-in for today
  → Views adherence trends, protocols, prescriptions
  → Adds a note or adjusts protocol
```

---

## 10. ENVIRONMENT VARIABLES (Vercel)

| Variable | Purpose |
|----------|---------|
| `SUPABASE_URL` | Supabase project URL |
| `SUPABASE_ANON_KEY` | Public anon key |
| `SUPABASE_SERVICE_KEY` | Service role key (server-side only) |
| `OPENAI_API_KEY` | OpenAI API (coach, program gen, food analysis) |
| `GEMINI_API_KEY` | Google Gemini (image generation) |
| `ANTHROPIC_API_KEY` | Claude API (web coach, identity analysis) |
| `REVENUECAT_WEBHOOK_SECRET` | RevenueCat webhook auth |

---

## 11. FILE STRUCTURE

```
~/Wylde-self/
├── app.html                          # Consumer web app (SPA, ~15K lines)
├── clinical-dashboard.html           # Clinician dashboard (SPA)
├── clinical.html                     # Marketing landing page
├── command-center.html               # Legacy dashboard mockup
├── api/
│   ├── openai.js                     # OpenAI proxy
│   ├── anthropic.js                  # Anthropic proxy
│   ├── generate-image.js             # Gemini image gen (physique/vision/future_vision)
│   ├── identity-analyze.js           # Identity profile analysis
│   ├── exercises.js                  # Exercise library search
│   ├── exercise-demo.js              # Exercise demo lookup
│   ├── predict-protocol.js           # AI protocol prediction
│   ├── protocol-checklist.js         # Peptide protocol CRUD
│   ├── founder-count.js              # Founding member counter
│   ├── revenuecat-webhook.js         # Payment sync
│   ├── send-push.js                  # Push notification
│   ├── cron-push.js                  # Scheduled push
│   ├── consumer/
│   │   ├── me.js                     # Patient profile
│   │   ├── checkin.js                # Daily adherence
│   │   ├── progress.js               # Timeseries data
│   │   └── care/
│   │       ├── invite.js             # Generate share code
│   │       ├── accept.js             # Accept patient code
│   │       └── relationships.js      # Manage care links
│   └── clinic/
│       ├── products.js               # Product catalog CRUD
│       ├── notes.js                  # Patient notes
│       └── assign-protocol.js        # Protocol assignment
├── lib/
│   ├── security.js                   # CORS + rate limiting
│   └── supabase-admin.js             # Server-side Supabase client + JWT verification
├── data/
│   └── exercises.json                # 873 bundled exercises
├── supabase/
│   └── migrations/
│       ├── 20260427_pro_entitlements.sql
│       ├── 20260428_identity_profile.sql
│       ├── 20260619_clinical_system.sql
│       └── 20260620_clinic_products.sql
├── warmup-videos/                    # 5 MP4 files for dynamic warmup
├── vercel.json                       # Function config + cron
├── package.json                      # Dependencies
│
└── WyldeSelf-iOS/
    └── WyldeSelf/
        ├── WyldeSelfApp.swift
        ├── ContentView.swift
        ├── Info.plist                # SUPABASE_URL, SUPABASE_ANON_KEY, CLINICAL_API_BASE
        ├── exercises.json            # Bundled exercise library
        ├── guided-meditation.m4a     # 10-min meditation audio
        ├── Models/
        │   ├── AppState.swift        # Central state + persistence
        │   ├── Exercise.swift        # Exercise model + repository
        │   ├── WorkoutProgram.swift  # Workout/set/PR models
        │   ├── FutureVision.swift    # Vision category + vision models
        │   ├── MealPlan.swift        # Meal plan models
        │   ├── ConsumerModels.swift  # Clinical API response models
        │   └── IdentityProfile.swift # Identity analysis model
        ├── Services/
        │   ├── SupabaseClient.swift       # Singleton Supabase client
        │   ├── AuthService.swift          # Auth (sign-in, sign-up, magic link, session)
        │   ├── ClinicalAPI.swift          # Clinical endpoint wrapper
        │   ├── CheckinSync.swift          # Background adherence sync
        │   ├── WorkoutService.swift       # Program gen, set logging, PRs
        │   ├── FutureVisionService.swift  # Vision generation + persistence
        │   ├── CoachService.swift         # AI coach chat
        │   ├── MacroTrackerService.swift  # Photo food analysis
        │   └── MealPlanService.swift      # Weekly meal plan generation
        ├── Utilities/
        │   ├── WyldeStyles.swift     # Adaptive color tokens (dark/light)
        │   ├── Theme.swift           # UI aliases + UIColor helpers
        │   ├── VisionTheme.swift     # Dark tokens for Vision feature
        │   ├── CinematicEffects.swift # Ambient bg, glass cards, gold buttons
        │   ├── LiftingCoach.swift    # Starting weights, overload tips, education
        │   ├── CoachLine.swift       # One-sentence affirmation rotation
        │   └── ImageLibrary.swift    # Asset registry with gradient fallbacks
        ├── Views/
        │   ├── TodayView.swift
        │   ├── MainTabView.swift
        │   ├── SignInView.swift
        │   ├── OnboardingView.swift
        │   ├── SplashView.swift
        │   ├── ExercisesView.swift
        │   ├── YouView.swift
        │   ├── CareTeamView.swift
        │   ├── CoachChatView.swift
        │   ├── FoodScannerView.swift
        │   ├── MealPlanView.swift
        │   ├── IdentityImportView.swift
        │   ├── PaywallView.swift
        │   ├── SettingsDrawer.swift
        │   ├── WebViewScreen.swift
        │   ├── StartTodayFlow.swift
        │   ├── FutureVision/
        │   │   ├── FutureTabView.swift
        │   │   ├── FutureVisionView.swift
        │   │   ├── VisionCard.swift
        │   │   ├── VisionCreationFlow.swift
        │   │   ├── VisionCategorySelector.swift
        │   │   └── FutureReflectionFlow.swift
        │   └── Workout/
        │       ├── WorkoutContainerView.swift
        │       ├── WorkoutGeneratorView.swift
        │       ├── ProgramView.swift
        │       ├── WorkoutDayView.swift
        │       ├── ExerciseCard.swift
        │       ├── RestTimerView.swift
        │       ├── DynamicWarmupView.swift
        │       ├── QiGongFlowView.swift
        │       └── GuidedMeditationView.swift
        └── Assets.xcassets/
            ├── AppIcon, HeroBackground, FutureSelfMan, FutureSelfWoman
            ├── GlowMale, GlowFemale, GlowNeutral
            ├── LogoIcon, LogoMark, AppInHand
            ├── AccentColor, LaunchBackground
```

---

## 12. WHAT'S NOT BUILT YET

### iOS App
- Protocol tracker tab (peptides/supplements visible to patient)
- Social integration (connect Instagram, etc. for AI identity learning)
- Progressive future self rendering (upgraded images as user progresses)
- Marketplace (browse + purchase clinician products)
- Apple Watch companion
- Push notifications (local + remote)
- HealthKit write-back (workout sessions)
- Wearable data sync (Whoop, Oura, etc.)

### Clinical Dashboard
- Trends & Biomarkers chart (line chart from timeseries data)
- Lifestyle Snapshot scoring
- Insights panel (AI-generated recommendations)
- Lab Results integration
- Messaging (clinician ↔ patient)
- Calendar / scheduling
- Billing & Orders (Stripe integration for product purchases)
- Multi-clinic support
- Clinician iOS app for mobile medspas

### Web App
- Vision board as separate feature from Future Self transformation
- Recipe builder
- Social feed improvements

### Infrastructure
- SMTP setup for branded emails (Microsoft 365)
- Profile sync (iOS UserDefaults → Supabase profiles table)
- Proper error handling and offline support
- Analytics / event tracking
- CI/CD pipeline
- TestFlight distribution
