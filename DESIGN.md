# WyldeSelf — Design Language

This document is the source of truth for visual decisions in the iOS app. Reference it any time a new screen or component is built.

**Design fidelity bar:** every screen should feel designed in Figma, not generated. If a screen looks like a stock SwiftUI app, it isn't done.

---

## Reference Brands

WyldeSelf lives in the same visual register as:

- **Equinox** — premium fitness, restraint, photographic
- **Tracksmith** — editorial sport, warmth, considered typography
- **Function Health** — clinical-meets-aspirational, clean
- **Levels** — data presented as story, calm
- **Whoop** — quiet confidence, minimal chrome
- **Aesop** — premium, cinematic, mature
- **Rapha** — sport as craft, photography forward
- **Ten Thousand** — performance with depth, restrained

What we are NOT:
- ❌ Calm / Headspace (too soft, too consumer-friendly)
- ❌ MyFitnessPal / typical fitness apps (too cluttered, data-dense)
- ❌ Bumble / typical consumer apps (too playful)
- ❌ Hims / male-coded wellness (too clinical-bro)

---

## Color Palette

Move AWAY from full black + dominant gold. Move TOWARD warm neutrals with restrained accent.

### Foundation
- **Off-white / paper:** `#F4F1EC` (warm, not blue-white)
- **Bone:** `#E8E2D6`
- **Sand:** `#D4C9B5`
- **Stone:** `#9A9286`
- **Charcoal:** `#2C2A26` (warm dark, NOT pure black)
- **Ink:** `#1A1816` (only for highest contrast moments)

### Accent (restrained — used for moments of significance, not as primary)
- **Bronze:** `#9C7A4A` (primary accent, warmer and more mature than gold)
- **Gold:** `#C9A84C` (existing brand gold — kept for completion / reward / celebration moments only, not as a default accent)
- **Sage:** `#7A8771` (secondary accent — calm, organic)
- **Clay:** `#A06B4F` (occasional accent for warmth)

### Semantic
- **Success:** Sage `#7A8771`
- **Warning:** Clay `#A06B4F`
- **Error:** `#8B3A2F` (muted brick, never bright red)

### Usage rules
- **Backgrounds default to off-white or charcoal**, depending on screen mood
- **Bronze is the default accent**, not gold
- **Gold is reserved** for: level-ups, completion states, identity anchors at peak emotional moments, celebration confetti — never default UI elements
- **No pure white (`#FFFFFF`)** anywhere — always warm
- **No pure black (`#000000`)** anywhere — always warm charcoal

---

## Typography

### Font families (loaded as custom fonts in the app bundle)
- **Display / editorial:** Cormorant Garamond — serif, elegant, used for moments that feel literary (Identity Anchor, Future Self affirmations, hero quotes)
- **Display / strong:** Replace Bebas Neue. Candidates in priority order: Migra, GT Sectra Display, Söhne Breit. Pick one, commit to it.
- **Body / UI:** Söhne or Inter — clean modern sans, high legibility
- **Numerals / data:** Söhne Mono or JetBrains Mono — used for stats, timestamps, anything quantitative

### Type scale (iOS)
| Token | Size | Weight | Use |
|---|---|---|---|
| `display.hero` | 48pt | Cormorant 400 | Identity Anchor, Future Self affirmations |
| `display.large` | 36pt | Display font 500 | Section headers in journey loop |
| `display.medium` | 28pt | Display font 500 | Card headers |
| `body.large` | 18pt | Söhne 400 | Primary body |
| `body.medium` | 16pt | Söhne 400 | Default body |
| `body.small` | 14pt | Söhne 400 | Captions, metadata |
| `label.large` | 14pt | Söhne 600, +0.05 tracking | Stage labels, tab labels |
| `label.small` | 11pt | Söhne 600, +0.1 tracking, uppercase | Eyebrow tags |
| `numeric.large` | 32pt | Söhne Mono 400 | Big stats |
| `numeric.medium` | 18pt | Söhne Mono 400 | Inline stats |

### Rules
- Cormorant for *meaning*, sans for *information*. Don't mix.
- Tracking on uppercase labels = +0.05 to +0.1, never tighter
- Line height: 1.4 for body, 1.15 for display
- Never bold body text for emphasis — use color or position instead
- Italic only in Cormorant, never in sans

---

## Spacing & Layout

### Spacing scale (use these, no in-between values)
- `xs` = 4pt
- `sm` = 8pt
- `md` = 16pt
- `lg` = 24pt
- `xl` = 40pt
- `2xl` = 64pt
- `3xl` = 96pt

### Layout principles
- **Generous whitespace.** When in doubt, more space, not less.
- **Single primary action per screen.** Multiple equal-weight buttons is a design failure.
- **Vertical rhythm.** Use `xl` (40pt) between major sections, `md` (16pt) between elements within a section.
- **Edge insets:** screen padding = `lg` (24pt) horizontal on iPhone. Don't reduce this for "more content."
- **Cards rare.** Avoid card-on-card. Sections separated by whitespace and subtle dividers, not nested containers.

### Grid
- Single-column on iPhone for journey loop content
- Two-column only for stats grids or comparison views
- Don't try to be clever with layout — simplicity wins

---

## Components

### Buttons
- **Primary:** filled bronze background, paper text, `lg` corner radius (16pt), `md` vertical padding, body.large weight 500
- **Secondary:** outlined charcoal border, charcoal text, transparent background
- **Tertiary / text:** charcoal text, no chrome, used inline
- **Destructive:** error semantic color, used sparingly
- **Disabled:** stone color, no opacity tricks
- **One primary per screen.** Always.

### Cards
- Use sparingly. Default is no card — just whitespace separation.
- When used: paper background, subtle bone border (1pt), `lg` corner radius, `lg` internal padding
- Never nest cards
- No drop shadows. If lift is needed, use a subtle warm tint.

### Input fields
- No box. Just a label above, the value below in body.large, and a 1pt bone underline that becomes bronze on focus
- Placeholder in stone color, never italic
- No "search" magnifying glass icons unless absolutely needed for clarity

### Bottom navigation
- 3-4 tabs maximum (Today, Future Self, Library, Profile)
- Custom tab bar — never default UITabBar appearance
- Active state: charcoal label + bronze indicator dot below
- Inactive: stone label, no icon below
- Icons only if they add meaning; otherwise text labels alone

---

## Photography & Imagery

### Style
- Cinematic, warm, real bodies in real light
- Gradient overlays welcome (warm neutrals, never blue or magenta)
- Documentary register — not stock-photo "people working out and laughing"
- Aspect ratios: 4:5 for portrait, 16:9 for hero, 1:1 only when geometric grid is required
- Black-and-white acceptable for editorial moments

### What to avoid
- ❌ Stock photography
- ❌ AI-generated images that don't look real (the Future Self generation needs to feel real or it breaks the spell)
- ❌ Hyper-saturated colors
- ❌ Group shots (the journey is personal)
- ❌ Equipment-focused shots (focus on bodies and movement, not gear)

### Future Self generation specifically
- See HANDOFF.md for the prompt overhaul backlog item
- Reference aesthetic: Equinox cover, NOT Men's Health cover
- Refined, embodied, established — never bodybuilding-cut

---

## Sacred Geometry

Restrained. Quiet. Not the focal point.

- ✅ Acceptable: subtle line geometry as background watermark at 5-10% opacity, used in Identity Anchor moments
- ✅ Acceptable: as fine detail inside completion / level-up animations
- ❌ Not acceptable: sacred geometry as primary screen ornament, large background panels, dominant on the canvas

If you can see the geometry without looking, it's too loud.

---

## Motion

### Principles
- Motion should feel earned, not decorative
- Default to spring animations (`response: 0.4, dampingFraction: 0.85`)
- Avoid bouncy "fun" motion — this isn't Duolingo
- Cross-screen transitions: gentle fade + slight upward translate, never aggressive horizontal slides

### Specific patterns
- **Stage completion:** subtle scale (1.0 → 0.98) + bronze glow at edges, 600ms
- **Identity Anchor reveal:** 1.5s slow fade-in with 200ms text-character stagger
- **Future Self image generation:** progressive blur reveal, never spinner-and-wait
- **Tab switching:** instant, no animation (don't make tabs feel slow)
- **Pull to refresh:** custom — bronze line that draws as you pull, then retracts on release

### What to avoid
- ❌ Bouncy entrances on routine UI elements
- ❌ Loading spinners (use skeleton states)
- ❌ Confetti unless it's a major level-up moment (and even then, restrained)
- ❌ Heavy parallax — feels gimmicky on iOS

---

## Haptics

iOS-native, used sparingly:
- Light impact on stage completion within journey loop
- Medium impact on day completion (Close the Loop stage)
- Heavy impact + success haptic on level-up (Ember → Forge, etc.)
- Selection feedback on tab switching
- Never on incidental UI like button presses (Apple's UIButton handles this implicitly)

---

## Iconography

### Approach
- SF Symbols for utilitarian icons (settings gears, chevrons, profile)
- Custom-drawn icons for journey loop stages (each stage gets a unique mark — Identity Anchor, Morning Ritual, Training, Nutrition, Future Self Check-in, Close the Loop)
- Custom marks should be 1.5pt stroke, charcoal color, geometric but warm

### Sizing
- Inline icons: 16pt
- Standalone icons: 24pt
- Hero icons: 48pt+

---

## Voice (in-app copy)

Voice for the universal Wylde Self product — distinct from Wylde Man's masculine register.

### Tone
- Grounded, direct, mature
- Calm authority
- Confident without being performative
- Warm without being soft
- Never explains too much

### Specific patterns
- **Stage labels:** noun phrases. "Identity Anchor" not "Anchor your identity"
- **Empty states:** evocative, not instructional. "Your future self is waiting" not "You haven't created a profile yet"
- **Errors:** specific and human. "We couldn't reach the server. Try again in a moment." Not "Error 500."
- **Success states:** quiet acknowledgment. "Logged" not "Great job!! 🎉"
- **Notifications:** invitation, never urgency. "Today is here" not "Don't miss your workout!!"

### Words to avoid
- ❌ "Crush," "smash," "dominate," "destroy" (generic fitness bro)
- ❌ "Hey there!" "Awesome!" "Amazing!" (over-friendly)
- ❌ "Unlock," "level up" (gamified)
- ❌ "Let's do this!" (generic motivation)
- ❌ Emojis in body copy (occasional, considered use only)

### Words that fit
- ✅ "Step into," "anchor," "embody," "integrate," "return to"
- ✅ "Today," "now," "this moment"
- ✅ "Practice," "ritual," "rhythm"

---

## Component Catalog (build these first)

When building out the app, these components form the foundation. Build them once, reuse everywhere:

1. `WyldePrimaryButton` — bronze filled, paper text, lg corner radius
2. `WyldeSecondaryButton` — outlined, charcoal
3. `WyldeTextField` — underlined, no box
4. `WyldeCard` — paper background, subtle border, generous padding
5. `WyldeSectionHeader` — display.medium type + small eyebrow label above
6. `WyldeStageRow` — used in journey loop, contains icon + label + state + chevron
7. `WyldeTab` — custom tab bar item with bronze indicator dot
8. `WyldeStat` — large numeric + small label below
9. `WyldeProgressArc` — used for stage progression, bronze fill on charcoal track
10. `WyldeImageHero` — full-bleed image with warm gradient overlay

Establish these in `Utilities/WyldeStyles.swift` and `Components/` folder. Every screen pulls from these.

---

## Decision rules when something is ambiguous

When designing or building and you don't know which way to go:
1. **More restraint, less ornament**
2. **More whitespace, less density**
3. **More photographic, less illustrative**
4. **More native iOS conventions, less custom-clever**
5. **More premium-mature, less consumer-fun**

If after applying these you're still unsure, ask: *"Would Equinox or Function Health ship this?"* If no, redesign.
