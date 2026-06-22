# Wylde Self iOS · Photography spec

The app uses a curated set of bundled photos. `Utilities/ImageLibrary.swift` maps named scenes to image-set names in `Assets.xcassets`. Missing assets render a tinted gradient placeholder during development — drop the matching photo into the catalog to light it up.

## Visual register

Reference brands (CLAUDE.md): Equinox, Tracksmith, Function Health, Aesop, Rapha, Levels, Ten Thousand, Future, Whoop. The treatment we want sits between **Tracksmith's quiet running portraits** and **Function Health's clinical-natural blend**.

— Cinematic photography of real human movement, never illustrated graphics
— Warm tones — bone, sand, bronze, charcoal. No saturated colors
— Natural light. Soft contrast. Slight grain acceptable
— Composition leaves whitespace; subject often off-center or backlit
— No faces in close-up unless it's the user's own future-self render
— Avoid stock-photo clichés (no lifted dumbbells, no smiling business attire)

Where to source: Stocksy / Unsplash+ / Getty Reportage for the bundled set. Treat each asset before bundling — apply a unified grade so they read as one library.

## Asset list

Each image set needs `@1x`, `@2x`, `@3x` variants. PNG is fine; JPEG smaller.

### Today (rotates by hour-of-day)

| Asset name        | When it shows         | Subject / mood                              |
|-------------------|-----------------------|---------------------------------------------|
| `today-morning`   | 5am–11am              | Dawn light through a window, single object, ritual energy. Coffee, journal, plant. |
| `today-midday`    | 11am–5pm              | Movement: a single runner at distance, climber in sun, walker on a path. |
| `today-evening`   | 5pm–9pm               | Wind-down: lamp light interior, table set, slow stretch. |
| `today-night`     | 9pm–5am               | Quiet close: candle, dim room, book closed on a table. Mostly charcoal. |

### Future Self

| Asset name           | Use                                                        |
|----------------------|------------------------------------------------------------|
| `future-hero`        | Hero behind the Future tab title. Distant figure, horizon, generous sky. |
| `future-placeholder` | Renders while the user's personal future-self image is loading. Soft warm gradient with a quiet silhouette. |

### Library (exercise categories)

| Asset name              | Subject                                              |
|-------------------------|------------------------------------------------------|
| `library-strength`      | Lifting platform from above, racked plates, hand on bar. Charcoal + bone. |
| `library-mobility`      | Single yoga or mobility pose, side-light, no face.   |
| `library-conditioning`  | Sprint shadow, sled track, breath visible in cold air. |
| `library-recovery`      | Sauna door, cold-plunge water surface, hot tea.      |

### You

| Asset name        | Subject                                                       |
|-------------------|---------------------------------------------------------------|
| `you-hero`        | Calm landscape — coast at dawn, hills with mist, monk-style portrait. Used in YouView hero. |
| `identity-anchor` | A single hand writing, candle, deliberate object. Used in the Identity Anchor card. |
| `care-team-hero`  | Clinician's hands on a desk, soft light. Used in CareTeamView when relationships exist. |

### Onboarding / sign-in

| Asset name         | Subject                                              |
|--------------------|------------------------------------------------------|
| `sign-in-hero`     | Full-bleed cinematic — figure walking up to a doorway, horizon at dawn. |
| `onboarding-hero`  | Same library, slightly more aspirational. Used during onboarding screens. |

### Empty states

| Asset name         | Subject                                              |
|--------------------|------------------------------------------------------|
| `empty-state-calm` | Soft warm gradient or paper texture — used when a screen has no content. |

## Sizes

| Use                       | Recommended dimension (@3x)        | Notes                                  |
|---------------------------|------------------------------------|----------------------------------------|
| Today hero                | 1200 × 800                         | Hero strip with rounded 18pt corners   |
| Future hero               | 1500 × 1500                        | Full-bleed behind title                |
| Library category header   | 1200 × 600                         | 2:1                                    |
| You hero                  | 1200 × 600                         | Cropped 2:1 with bottom-left gradient  |
| Care team / identity card | 800 × 600                          | Smaller card hero                      |
| Sign-in / onboarding hero | 1500 × 2000                        | Portrait full-bleed                    |
| Empty states              | 800 × 600                          | Soft, low-detail                       |

Provide @1x at one-third the @3x dimension, @2x at two-thirds.

## How to add a photo

1. Open `Assets.xcassets` in Xcode
2. Right-click → New Image Set
3. Name it exactly as listed above (e.g. `today-morning`)
4. Drag @1x / @2x / @3x JPEGs/PNGs into the three slots
5. Confirm Render As is `Default` (we apply our own overlays in code)
6. Build & run — the gradient placeholder is replaced automatically

## Future work

- A small `Gemini` helper that swaps in user-specific generated images for the Future tab (already in plan — see HANDOFF.md)
- HealthKit-driven imagery: if the user just completed a workout, swap the Today hero for the conditioning library photo for the next hour
- Seasonal rotation: the Today hero hour-band logic can extend to date-band variants (winter dawn vs. summer dawn)
