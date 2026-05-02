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
Wylde Man is a **specialized program within the Wylde ecosystem** — a deeper masculine track for men who want that specific work. It is not the front door to WyldeSelf and should not influence WyldeSelf's tone, copy, or visual language. Wylde Woman, Wylde Child, and other verticals will sit alongside it under the same parent brand.

---

## Core Product: The Daily Journey Loop

The app revolves around one structured daily flow — not multiple tabs of features, not a chat interface, not a content feed.

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
- Feel like a chatbot
- Use heavy slang, hype, or motivational-poster language

### Current implementation note
The codebase uses `identity_archetype`, `coaching_style`, a visible Identity Import UI, and `WYLDE_PHASES` labels. These should function as **internal AI modulation parameters** — server-side context that shapes how the unified AI guide responds — not as user-facing selectable personas. Audit needed: confirm whether the Identity Import UI and any archetype/style labels exposed to the user align with the "one unified AI presence" principle, or whether they should be hidden / refactored to feel like a single guide that adapts intelligently rather than a system the user configures.

The earlier exploratory work around six named coach personas (Warrior, Athlete, Yogi, Architect, Mentor, Monk) is no longer part of the system. Do not reintroduce them.

---

## Design Direction

### Aesthetic
Premium, minimal, cinematic. Neutral but powerful. Nature + human performance.

### Reference brands
Equinox, Tracksmith, Function Health, Aesop, Rapha, Levels, Ten Thousand, Future, Whoop. High-end wellness and longevity register.

### Move AWAY from
- Hyper-masculine visual language
- Dark/aggressive "alpha" energy
- Heavy sacred geometry as a focal point
- Mystical or overtly spiritual cues
- Full black + gold maximalism

### Move TOWARD
- Warm neutrals, deep charcoal (not full black), considered accent colors
- Cinematic photography of real human movement
- Quiet, restrained sacred geometry as fine detail — not centerpiece
- Generous whitespace
- Subtle motion and haptics over visual ornament

### Typography
- Cormorant Garamond — keep for editorial / display moments (neutral elegant)
- Replace Bebas Neue with a softer display face (candidates: Migra, GT Sectra Display, Söhne Breit) — Bebas reads aggressive
- Body: a clean modern sans (Söhne, Inter, or similar) for legibility

### Color
The current `#C9A84C` gold can stay as one accent but should not dominate. Consider warm bronze, sand, deep charcoal, off-white as the foundational palette with gold used sparingly for moments of significance (level-ups, completions, identity anchors).

---

## Architecture

### iOS app
- Xcode / SwiftUI
- Local repo: `~/Documents/WyldeSelf` (or wherever cloned on current machine)
- Repo: `github.com/WMIWylde/[repo-name]`

### Backend
- Next.js on Vercel
- Local repo: `~/Projects/Wylde-self` (or wherever cloned)
- Repo: `github.com/WMIWylde/Wylde-self`
- Vercel Edge Runtime used to bypass Hobby plan's 10-second function timeout

### AI / Image generation
- Future Self image generation: Gemini 3.1 Flash (chosen after evaluating fal.ai, DALL-E 2, gpt-image-1)
- Conversational AI guide: Claude (or similar) — single unified voice
- All AI work happens server-side; the iOS app makes API calls

### Auth & data (planned)
- Supabase auth — deferred, on roadmap
- HealthKit integration — deferred, on roadmap

---

## Information Architecture (target state)

The app should collapse from a feature-driven layout to a journey-driven one.

```
Today          The daily loop — primary surface
Future Self    Visual evolution, identity anchor, progression tracking
Library        Programs, past sessions, reference (minimal)
Profile        Identity, settings, account
```

Tabs are minimal. The "Today" surface is the heart of the app and should be the first and most-used screen.

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

Architectural decisions should leave room for:
- **Marketplace** — white-labeled Wylde products, proprietary supplement blends (mushroom, nootropic, performance, recovery)
- **Programs** — structured transformation journeys (e.g., 12-week identity protocols, Wylde Man, Wylde Woman verticals)
- **Clinical layer** — optional integration with labs, peptides, hormone optimization
- **Content + community** — present but never the core

These are not MVP. They inform schema design, account structure, and navigation extensibility — nothing more right now.

---

## Working Style

- Direct and concise — skip preamble
- Mobile for drafting, desktop for deployment
- Move fast from idea to production
- Ship working code, polish iteratively
- Decisive over exhaustive

---

## Active Direction (as of latest session)

Strategic pivot in progress: WyldeSelf has been re-positioned from a men's-only product to a universal identity transformation platform. Code, copy, and design audit needed against this document. The six-coach persona system is out (and not in the current codebase). The current `identity_archetype` + `coaching_style` + Identity Import UI implementation needs review against the "one unified AI guide" principle. Daily journey loop is the new architectural center. Visual identity is moving from dark/masculine/sacred-geometry toward premium/minimal/cinematic.

When working in this codebase: assume the new direction is the source of truth. Flag any existing code, copy, or design that conflicts with it.
