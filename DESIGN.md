# DESIGN.md — QuranKu "Malam Veranda" world

Recorded from the built app (replacement world, code-led, seed `81e68fde`).
PRODUCT.md owns product truth; this file owns durable visual decisions.

## World

Restrained Material 3 tonal system. Light is paper green for daylight reading;
dark is deep-veranda night for low-light reading at home/mosque — picked from
the use scene, never by category default. Tonal surfaces, hairline dividers,
18–22dp radii, zero elevation, no backdrop blur, no gradient text, no kickers.

## Palette (source: `lib/main.dart` `_buildTheme`)

- Binding accent: `#2E9D6B` (primary + onPrimary white). Primary is for
  selection, state, and progress fill ONLY — never large fills except the
  tasbih counter and player play button.
- Amber lamp: `#C98A2B` (tertiary + onTertiary white). Reserved for the single
  live state: playing indicator, next-prayer countdown. Nowhere else.
- Light surfaces: base `#F4F6F1`; containers `#FFFFFF / #FFFFFF / #ECEFE8 /
  #E2E7DD / #D8DED3` (lowest → highest).
- Dark surfaces: base `#0B1411`; containers `#080F0C / #101B16 / #14211B /
  #182720 / #1E2F26` (lowest → highest).
- Text: `onSurface` primary content; `onSurfaceVariant` ALL secondary text
  (solid token, never alpha < .72 for 12–14sp — elder readability floor).
- Errors/stops: `scheme.error` / `onError`. No raw red, no second green.

## Typography

- UI: platform workhorse sans via `Typography.englishLike2018` with full
  heights (title 1.2–1.3, body 1.5, small 1.45). Display roles are 800-weight
  with tight letterspacing (-0.2 to -0.4), not a brand face.
- Arabic: Amiri ONLY in Arabic surfaces (reader, tasbih header, surah rows
  `nameAr`). Latin/transliteration: Inter/italic system style.
- Floor: 12sp minimum for any text. 10/11sp banned (iOS 11pt floor + elders).

## Components (`lib/widgets/liquid_glass.dart` + Material)

- `LiquidGlassCard`: tonal `surfaceContainerLow`, 22dp radius, hairline
  `outlineVariant` border. One focal card per screen; never nest cards.
- `LiquidGlassSectionTitle`: 800 title + `onSurfaceVariant` subtitle, 18/8
  spacing. Section headers use this, not ad-hoc Text rows.
- `ThreadProgress`: THE signature — 4px track on `surfaceContainerHighest`,
  green fill, no knob. Khatam, read progress, audio progress all use it.
  (Mini-player keeps its own docked thread + amber live dot.)
- `BeadDot`: filled green = done, tonal ring = pending. Filled-vs-ring shape
  carries meaning without color alone (a11y).
- Surah rows: 56dp green-tint number medallion (`primary` .12 fill, .22 ring),
  800 name, `onSurfaceVariant` meta line, chevron in `onSurfaceVariant`.
- Navigation: phone `NavigationBar` 3 destinations (Home/Ibadah/Target);
  `NavigationRail` ≥840dp. System Back never trapped (`PopScope`: collapses
  full player, else OS default).
- Touch targets ≥48dp; icon buttons carry tooltip + semantic label; the tasbih
  counter is `Semantics(button)` with count value. Pulse/auto-follow motion
  is gated behind `disableAnimations`.

## Cross-surface reach

Applied: Home list + unified search, reader, mini/full player, tasbih,
settings, khatam banner/screen, prayer-times accents. Remaining screens
inherit tokens automatically via the shared theme; adopt `ThreadProgress` /
`SectionTitle` / `BeadDot` when touching a screen — do not invent local
progress bars, headers, or status dots.
