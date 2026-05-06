# WyldeSelf — Privacy & Data Handling

This document is the source of truth for what data WyldeSelf collects, where it lives, how it's protected, and what users can do about it. Reference it when building any feature that touches user data.

**Operating principle:** collect only what's needed to deliver the product experience. Default to local. Be honest in the App Store privacy nutrition label. Be deletable on request.

---

## Why this matters

1. **Apple App Store:** Apps must declare exactly what data they collect, how it's used, and whether it's linked to the user. Inaccurate declarations are grounds for rejection or removal.
2. **GDPR / CCPA:** Users have legal rights to access, export, and delete their data. WyldeSelf must support this.
3. **Brand:** WyldeSelf is a premium identity transformation product. Trust is foundational. A privacy breach or sloppy handling damages the entire brand, including Wylde Man and the future ecosystem.
4. **HealthKit (when implemented):** Apple has additional restrictions on health data. Misuse can result in App Store removal.

---

## What We Collect

### Core profile data
- Name (provided in onboarding)
- Date of birth or age range (for AI personalization, optional)
- Gender identity (optional, never required, used only when relevant for AI tone)
- Goals selected during onboarding
- Identity Anchor / Identity Import responses
- Current progression phase (Ember / Forge / Steel / Wylde)

### Activity data
- Daily journey loop completion state
- Workout / training session logs (sets, reps, time, notes)
- Nutrition tracking (meals, macros, optional)
- Morning ritual completions
- Photos uploaded for Future Self generation (see "Photos" below)

### AI conversation history
- Messages between user and the AI guide
- Model context (recent state, identity profile) sent with each request
- Stored to preserve continuity across sessions and across web ↔ iOS

### Device & technical data
- Device type, OS version (for crash reporting and compatibility)
- App version
- Anonymized analytics (screen views, feature usage) — opt-in only
- Crash reports — opt-in only

### What we do NOT collect
- ❌ Precise location (no GPS unless explicitly asked for, e.g., outdoor run tracking)
- ❌ Contacts list
- ❌ Social media graph
- ❌ Browsing history outside the app
- ❌ Microphone or camera access without explicit purpose and consent
- ❌ Advertising identifiers (we don't run ads or share data with ad networks)

---

## Photos

User photos for Future Self generation are sensitive. Handle carefully.

### Capture
- Photos can be taken inside the app (with camera permission) OR selected from photo library (with photo library permission)
- Use limited photo library access (`PHPickerViewController`) — never full library access
- Require explicit purpose statement at permission request: *"WyldeSelf uses your photo to generate a visualization of your future self. Photos are processed once and not stored."*

### Processing
- Photo is sent over HTTPS (TLS 1.3) to the backend Future Self generation endpoint
- Photo is processed by the image generation model (Gemini 3.1 Flash)
- Generated future-self image is returned to the device and stored locally in the user's profile
- **The original input photo is NOT retained on the backend after generation completes** — discarded immediately after the model returns
- Generated output images ARE retained (they are part of the user's progression record)

### User control
- User can delete any generated future-self image at any time
- User can revoke camera / photo library permissions at any time (App settings)
- User can request full deletion of their account, which removes all images

---

## HealthKit (when implemented — currently deferred)

When HealthKit integration ships, follow these rules:

- Read-only by default. Don't write to HealthKit unless the user explicitly enables it for a specific data type.
- Request permission only for the data types we actually use (workouts, nutrition, body measurements, sleep — not "all health data")
- HealthKit data **stays on device** unless the user explicitly opts in to backend sync
- Never use HealthKit data for advertising, third-party analytics, or any purpose other than improving the WyldeSelf experience for that user
- Apple's HealthKit terms prohibit selling, leasing, or disclosing HealthKit data — comply absolutely

---

## Data Storage

### On device (iOS)
- Cached profile data, recent journey state, AI conversation history (recent)
- Encrypted at rest by iOS data protection (default for app data)
- Cleared on app uninstall

### On backend (Supabase, when implemented — currently deferred)
- Authoritative copy of user profile
- Full AI conversation history
- Generated images (links / references)
- Activity logs
- Encrypted at rest (Supabase Postgres default)
- Encrypted in transit (TLS 1.3)
- Row-level security policies — users can only read their own data

### Backups
- Supabase handles infrastructure backups
- No cross-region replication of user data without notice (we are a single-region app for MVP)

---

## Authentication

- Use Supabase Auth (when implemented)
- Support email + password and Sign in with Apple
- **Sign in with Apple required** for iOS — Apple guidelines mandate this for any app offering social login
- Never store passwords in app code or local state
- Sessions are managed via JWTs with reasonable expiry (e.g., 1 hour access, 30 day refresh)
- No SMS-based 2FA in MVP (overhead not justified for stage)

---

## API Keys & Secrets

### Frontend (iOS app, web client)
- **Never embed API keys for third-party services in the iOS app or web client.** Anyone can extract them.
- All third-party API calls (Anthropic, Gemini, etc.) go through our backend, where the keys are environment variables
- The iOS app and web client only have a Supabase anon key (which is safe to expose by design)

### Backend (Vercel)
- API keys stored as Vercel environment variables, scoped to functions only
- Pulled to local development via `vercel env pull .env.local`
- Never committed to git
- Rotated quarterly or immediately on suspected compromise

---

## User Rights

The app must support these capabilities — build them in from the start, don't bolt on later:

### Data export
- User can export all their data as a JSON file at any time, from Settings → Privacy → Export My Data
- Includes profile, journey logs, conversation history, generated images (as links)
- Delivered via download or emailed link

### Data deletion
- User can delete their account at any time, from Settings → Privacy → Delete Account
- Deletion confirmation requires re-authentication and a clear warning
- After confirmation: all user data is removed from the backend within 30 days
- Generated images stored on device are removed immediately on account deletion

### Data correction
- User can edit profile data at any time
- Changes propagate to backend within seconds

### Opt-outs
- Analytics: opt-in by default, can be turned off any time in Settings → Privacy
- AI conversation retention: user can clear conversation history without deleting account
- Marketing emails: clearly opt-in only, with one-click unsubscribe in every email

---

## Children

WyldeSelf is intended for adults (18+). The app does not knowingly collect data from children under 13.

- Onboarding should ask for date of birth or confirm age 18+
- If a user indicates they are under 18, gate access or provide an age-appropriate path (no MVP support for minors)
- Wylde Child, when it ships, will have its own age-appropriate handling and parental consent flow — that is a separate product, not WyldeSelf

---

## App Store Privacy Nutrition Label

When submitting to App Store Connect, declare these data types accurately:

### Data Linked to User
- **Contact Info:** Name, Email Address (if email auth used)
- **Health & Fitness:** Health (when HealthKit is enabled), Fitness
- **User Content:** Photos (for Future Self generation), Other User Content (AI conversations, journal entries)
- **Identifiers:** User ID
- **Usage Data:** Product Interaction (if analytics opt-in)
- **Diagnostics:** Crash Data (if crash reporting opt-in)

### Data Not Collected
- Location (unless GPS workouts ship — declare then)
- Search History
- Browsing History
- Contacts
- Sensitive Info (race, religion, sexual orientation, etc. — we don't ask)
- Financial Info
- Other Data Types

### Used to Track You
- **None.** WyldeSelf does not track users across apps and websites owned by other companies.

This declaration must be reviewed and updated whenever a data-touching feature ships.

---

## Required Permission Strings (Info.plist)

Be specific, brand-aligned, and honest:

- **NSCameraUsageDescription:** *"WyldeSelf uses your camera to capture photos for your Future Self visualization."*
- **NSPhotoLibraryUsageDescription:** *"Select a photo to generate your Future Self visualization. Photos are processed once and not stored."*
- **NSHealthShareUsageDescription:** *"WyldeSelf reads your workout, nutrition, and body measurement data from Apple Health to personalize your daily journey."*
- **NSHealthUpdateUsageDescription:** *"WyldeSelf can write your training sessions to Apple Health when you choose to enable this."*
- **NSUserTrackingUsageDescription:** *Not needed* — we do not request tracking permission because we do not track.

---

## Third-Party Services

Track every third-party service that touches user data:

| Service | Data Accessed | Purpose | DPA |
|---|---|---|---|
| Vercel | All API request data | Backend hosting | Yes (Vercel Pro+) |
| Supabase | Profile, conversation history, logs | Auth + database | Yes |
| Anthropic | AI conversation context | Powering AI guide | Yes (review terms) |
| Google (Gemini) | Photos for generation | Future Self image generation | Yes (review terms) |
| Apple App Store | Account purchases | App distribution | Apple's terms |

DPA = Data Processing Agreement. Required under GDPR for any vendor processing EU user data.

---

## Incident Response

If a data breach or compromise is suspected:

1. Rotate affected credentials immediately
2. Determine scope (which users, what data)
3. Notify affected users within 72 hours of confirmed breach (GDPR requirement)
4. Document the incident, root cause, and remediation
5. Update policies if needed to prevent recurrence

For MVP: this is process, not infrastructure. As the user base grows, consider services like Sentry for error tracking and incident detection.

---

## Decision Rules

When in doubt about a data question:

1. **Do we need this data to deliver the product?** If no, don't collect.
2. **Could this stay on device?** If yes, keep it on device.
3. **Would a reasonable user be surprised we collect this?** If yes, either don't, or be transparent before collecting.
4. **Could this become a liability if breached?** If yes, encrypt heavily, retain minimally, expose access narrowly.
5. **Would Apple's reviewer approve this?** If unsure, look up the relevant App Store guideline.

When unclear, default to *less data, more user control*.
