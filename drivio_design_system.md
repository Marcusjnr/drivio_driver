# Drivio Driver — Design System

> Single source of truth for the look, feel, and behaviour of the
> Drivio Driver Flutter app. Every token, component, and pattern in
> this document either ships in the codebase today or is the
> direction we're taking new work. Inspired by the *GoRide* UI kit's
> "modern + neobrutalist" sensibility, filtered through Drivio's
> brand: dark-first, mint-accented, editorial when it can be,
> dispatch-precise when it must be.
>
> **Audience:** Engineers writing UI in this app, product folk
> reviewing screens, designers writing specs that live alongside
> code.
>
> **Companion to:** `knowledge.md` (state of the codebase),
> `MIGRATION.md` (file-structure rules), `driver_context.md` (the
> WHY behind product decisions).

---

## Table of contents

1. [Design ethos](#1-design-ethos)
2. [Brand identity](#2-brand-identity)
3. [Colour tokens](#3-colour-tokens)
4. [Typography](#4-typography)
5. [Spacing & layout scale](#5-spacing--layout-scale)
6. [Radius scale](#6-radius-scale)
7. [Elevation & shadows](#7-elevation--shadows)
8. [Motion](#8-motion)
9. [Iconography](#9-iconography)
10. [Components](#10-components)
11. [Surface patterns](#11-surface-patterns)
12. [Map treatment](#12-map-treatment)
13. [Screen archetypes](#13-screen-archetypes)
14. [Voice & copy](#14-voice--copy)
15. [Accessibility](#15-accessibility)
16. [Anti-patterns — what we never do](#16-anti-patterns--what-we-never-do)
17. [How to add a new component](#17-how-to-add-a-new-component)

---

## 1. Design ethos

Drivio is a marketplace ride-hailing app. Drivers set their own
price; passengers pick. The interface has to feel **trustable for
money decisions**, **fast for in-motion use**, and **alive while the
auction is open**. That's the brief. Lagos is the first market —
the design system ships geography-neutral so it scales to whichever
city comes next.

We make six commitments:

1. **Dark-first.** Drivers spend most of the day in mixed lighting.
   Dark surfaces with mint accents read better through a windscreen,
   stay calm at night, and cut tropical-sun glare on cheap screens.
2. **Mint is meaning.** `#5EE4A8` is reserved for *live*, *go*,
   *money in*. We don't use it as decoration. If something is mint,
   it means something.
3. **Editorial typography over decoration.** Big, confident,
   tabular numerals for prices and timers. Mono uppercase eyebrows
   for status labels. Inter for everything else. We take typography
   seriously because rideshare is a numbers product.
4. **Square-edged authority for state.** Pills and cards have soft
   radii. But status indicators (eyebrows, marker dots, plate pills,
   countdown digits) carry a slightly neobrutalist edge — heavier
   weight, harder borders, monospace, uppercase. The tension between
   the soft and the hard is the brand.
5. **Motion that means something.** A slide-in or pulse fires when
   *real state has changed*. We don't animate because we can; we
   animate because the user needs to know.
6. **No fake chrome.** No mock status bars, no pretend home
   indicators, no decorative "100%" battery icons. The OS owns those
   pixels. We own ours.

**Reference influences:** the GoRide UI Kit (modern + neobrutalist
themes, dark/light parity, premium ride-hailing patterns), Apple's
Maps + Wallet (numerical hierarchy, monospace for codes/IDs), and
financial-trading interfaces (timers, tickers, anchored-state
panels). We're closer to a Bloomberg terminal than to a candy app.

---

## 2. Brand identity

### Wordmark

`DRIVIO` — Inter, weight 800, letter-spacing 5.5, vertical metallic
gradient via `Paint..shader`. Used at hero scale on the splash and at
xs scale (`BrandMark`) elsewhere.

### Brand mark

A minimal accent-mint disc with a chevron glyph. Sized 32 / 40 / 56
via `BrandMark(size:)`.

### Tagline

`· YOU SET THE FARE ·` — lives only on the splash. Eyebrow style
with two glowing accent dots flanking it. Three short tokens that
state the marketplace differentiator in the driver's voice — the
one promise that distinguishes Drivio from every commission-based
ride-hailing app on the market. **Geography-neutral by design** —
Drivio is not tied to one city.

### Strapline (in-app)

Used inside ride-request, active-trip, and bidding flows:
`AUCTION · OPEN`, `OFFERS · IN`, `BROADCASTING`, `LIVE · NOW`. Mono,
uppercase, letter-spacing ≥1.6. **Always uppercase**. **Never
sentence-case** (a strapline in sentence case becomes a sentence;
lose the strap). **Don't pin straplines to a specific city** —
Drivio is regional, not city-specific.

---

## 3. Colour tokens

All colour tokens live in `lib/modules/commons/theme/app_colors.dart`
with a `Dark` and `Light` variant for each. **Never read raw
`AppColors.fooDark` / `AppColors.fooLight` from a widget.** Always
read via the `context` extension in `context_theme.dart`:

```dart
Container(color: context.surface)             // ✅
Container(color: AppColors.surfaceDark)       // ❌  — won't flip in light mode
```

### Surfaces

| Token | Dark | Light | Use |
|---|---|---|---|
| `bg` | `#0A0B0D` | `#F4F5F7` | Page background. The "page is the page". |
| `surface` | `#111316` | `#FFFFFF` | Cards, sheets, the marketplace deck. |
| `surface2` | `#16191D` | `#F7F8FA` | Nested cards inside a card. Subtle. |
| `surface3` | `#1C2025` | `#ECEEF2` | Pressed states, dial track, chip background. |
| `surface4` | `#23282F` | `#E2E5EA` | Highest-elevation chips inside a sheet. |
| `appBackdrop` | `#050608` | `#ECEFF3` | Modal scrim and behind-everything backdrops. |

### Borders

| Token | Dark | Light | Use |
|---|---|---|---|
| `border` | `#FFFFFF` 7% | `#000000` 8% | The default 1-px border on a card. |
| `borderStrong` | `#FFFFFF` 12% | `#000000` 14% | Borders on grouped lists, dividers between rows. |

### Text

| Token | Dark | Light | Use |
|---|---|---|---|
| `text` | `#F4F5F7` | `#0F1115` | Default body. Headings. |
| `textDim` | `#9AA0A6` | `#515762` | Supporting text, eyebrows on neutral cards. |
| `textMuted` | `#686C73` | `#878C95` | Tertiary, disabled, meta. |

### Brand & semantic

Each pair has an **ink** companion — the colour of foreground content
that sits on top of the brand colour. Always pair, never improvise.

| Token | Dark | Light | Ink (dark / light) | Meaning |
|---|---|---|---|---|
| `accent` | `#5EE4A8` | `#18B374` | `#0A2418` / `#FFFFFF` | LIVE · GO · MONEY IN |
| `accentDim` | `#3BA87A` | `#0B7F52` | – | Halo glows, faint accent fills |
| `blue` | `#5B8CFF` | `#2A5BFF` | `#0A142E` / `#FFFFFF` | INFO · navigational · pickup |
| `amber` | `#FFB547` | `#D8820E` | `#2A1C00` / `#FFFFFF` | WARN · peak hours · attention |
| `red` | `#FF5A5F` | `#E03B3F` | `#2A0708` / `#FFFFFF` | ERROR · cancel · dropoff · destructive |

### Map palette

Dark-mode map is the canonical Drivio look — drivers spend most of
their time on it.

| Token | Dark | Light |
|---|---|---|
| `mapBg` | `#1A1D21` | `#E7EBEF` |
| `mapRoad` | `#2A2F36` | `#FFFFFF` |
| `mapRoadMajor` | `#353B45` | `#FFFFFF` |
| `mapWater` | `#152026` | `#CFE0EA` |
| `mapPark` | `#1A241D` | `#D6E7D4` |

### Notification banner palette

The `AppNotifier` banner uses paired bg / border / icon / text
colours per type. Source of truth: `app_notification_host.dart`.

| Type | Dark bg / border / icon | Light bg / border / icon |
|---|---|---|
| success | `#0E3B26` / `#064E3B` / `#A7F3D0` | `#DCFCE7` / `#BBF7D0` / `#16A34A` |
| error | `#3B0F0F` / `#4F1414` / `#FCA5A5` | `#FEE2E2` / `#FECACA` / `#EF4444` |
| warning | `#3D2F07` / `#78350F` / `#FEF08A` | `#FEF9C3` / `#FEF08A` / `#EAB308` |
| info | `#10283F` / `#143A59` / `#3BB4E6` | `#E6F1FB` / `#CCE3F7` / `#07478C` |
| neutral | `surface` / `borderStrong` / `textDim` | `surface` / `borderStrong` / `textDim` |

### Avatar gradients

Six gradients (`avatarA`–`avatarF` in `app_gradients.dart`) keyed by
the user's id hash. Used in `Avatar(variant: 0..5)`. The gradient is
chosen deterministically per driver so the same driver always shows
the same avatar colour in passenger lists.

---

## 4. Typography

Font stack: **Inter** for everything Latin (loaded via
`google_fonts`). **System monospace** (`'monospace'` family — Roboto
Mono on Android, Menlo on iOS) for codes, timers, plates, terminal
status feeds.

We **never** use Arial, Helvetica, Roboto-default, Space Grotesk, or
any other "AI-default" sans. Inter is the only sans we ship.

All styles are constants in `app_text_styles.dart`. Reference them
directly; never compose a `TextStyle()` inline in a widget.

### Scale

| Token | Size / weight / tracking | Use |
|---|---|---|
| `displayLg` | 32 / 700 / -0.6 | Splash hero — only place it appears |
| `screenTitle` | 28 / 700 / -0.6 | Top-of-screen titles ("Welcome back, driver.") |
| `screenTitleSm` | 26 / 700 / -0.5 | Detail-page titles |
| `h1` | 22 / 700 / -0.4 | Section headings inside a page |
| `h2` | 18 / 700 / -0.2 | Card titles, sheet titles |
| `h3` | 16 / 600 / -0.1 | Row primary text in lists |
| `bodyLg` | 16 / 500 / 1.4 line-height | Long-form paragraphs |
| `body` | 15 / 500 / 1.4 | Default body text |
| `bodySm` | 14 / 400 / 1.45 | Secondary body, supporting paragraphs |
| `caption` | 13 / 500 / 1.45 | Captions, meta rows |
| `captionSm` | 12 / 500 | Compact captions inside chips |
| `micro` | 11 / 600 / +0.6 | Tiny captions in tight UI |
| `eyebrow` | 11 / 600 / +0.9 | **Always uppercase.** Section labels above content |
| `mono` | 11 / 500 / +0.6 | Codes, plates, terminal feed |
| `priceHero` | 56 / 700 / -1.6 | The big bid-composer number |
| `metricVal` | 22 / 700 / -0.4 | Stat-strip values, mini-metrics |
| `button` | 16 / 700 / -0.1 | Primary button label |
| `buttonSm` | 14 / 600 | Compact button label |

### Numerical typography

Anything that's a number the user might compare (price, ETA, balance,
bid count, countdown) uses **tabular figures** so digits don't shift
horizontally as values change:

```dart
Text(
  '00:42',
  style: AppTextStyles.priceHero.copyWith(
    fontFeatures: const [FontFeature.tabularFigures()],
  ),
)
```

When numbers span a Naira amount, format via `NairaFormatter.format`,
**never** `'₦$amount'` directly — the formatter handles thousands
separators and the symbol consistently.

### Eyebrow rules

Eyebrows are tiny uppercase labels that sit above section content. They
are the single most identifiable part of Drivio's typography.

- **Always uppercase**, always `letterSpacing: 0.9` minimum, always
  the `eyebrow` style.
- Colour: `textDim` on neutral surfaces; `accent` when the section is
  about live/active state; `red` when the section is destructive
  (e.g. `DANGER ZONE` on the delete-account block).
- Use a divider dot (`·`) for compounds: `OFFERS LIVE · 03`,
  `BROADCASTING · NOW`.
- **Never** end with a period or use sentence case.

### Mono rules

Mono is used surgically. It carries a "this is a fact, not prose"
signal. Use mono for:

- Plate numbers (`36566FG` in a `_PlatePill`)
- Auction window codes (`#5e2f`)
- Live status feeds (`> broadcasting to drivers`)
- Distance / ETA chips (`4.2 KM`, `~12 MIN`)
- Currency / payment references (`REF a8b2…91c4`)

Don't use mono for paragraph text. Don't use mono for headings. It's a
detail font, not a display font.

---

## 5. Spacing & layout scale

Scale lives in `app_dimensions.dart`. Use the named constants — never
raw numbers.

| Token | Value | Typical use |
|---|---|---|
| `space2` | 2 | Hairline tweaks |
| `space4` | 4 | Inside very tight rows |
| `space6` | 6 | Avatar-to-name gap |
| `space8` | 8 | Standard small gap |
| `space10` | 10 | Icon-to-label inside chips |
| `space12` | 12 | Default vertical rhythm in cards |
| `space14` | 14 | Card padding |
| `space16` | 16 | Page horizontal margin (default) |
| `space18` | 18 | Section spacing |
| `space20` | 20 | Sheet inset |
| `space22` | 22 | Hero block separation |
| `space24` | 24 | Major page section spacing |
| `space28` | 28 | Hero-to-first-section gap |
| `space32` | 32 | Top-of-page lead-in |
| `space40` | 40 | Splash spacing |
| `space48` | 48 | Reserved for empty-state heroes |

### Page margin

**Default horizontal page padding: 16.** Some flows (auth, kyc) use
24 for more generous breathing room. Anything smaller than 14 looks
cramped on the iPhone-14 design baseline (390×844, see
`AppDimensions.designWidth/Height`).

### Sheet inset

Bottom sheets use `EdgeInsets.fromLTRB(20, 12, 20, 14)` plus a
`SafeArea(top: false)`. The 12-top includes the drag indicator's
breathing room.

---

## 6. Radius scale

Drivio's radii are intentionally varied. Use the right scale for the
job — picking a wrong radius reads wrong.

| Token | Px | Use |
|---|---|---|
| `sm` | 10 | Plate pills, small chips |
| `md` | 14 | Inputs, status tape, mini-metrics |
| `base` | 16 | Default card radius |
| `lg` | 22 | Major cards, sheets that aren't full-bleed |
| `xl` | 28 | The marketplace deck top, modal sheet tops |
| `pill` | 999 | Pills, buttons, avatar discs |

### Sheet-top radius

`AppRadius.sheetTop` always uses `xl` (28px) on top corners only. The
bottom corners are 0 because the sheet meets the screen edge.

### The neobrutalist exception

Status pills and meta chips can be **square (4px) or pill (999px)**
on purpose, never in between. This is the GoRide-kit influence: hard
geometric edges, no gentle 8-px-everywhere fuzziness.

```dart
// Plate pill — square 4 radius, mono caps, hard
Container(
  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
  decoration: BoxDecoration(
    color: context.surface2,
    borderRadius: BorderRadius.circular(4),
  ),
  child: Text('36566FG', style: AppTextStyles.mono.copyWith(letterSpacing: 1.4)),
)
```

---

## 7. Elevation & shadows

Shadows in `app_shadows.dart`. We use four:

| Token | Specs | Use |
|---|---|---|
| `card` | `rgba(0,0,0,.35)`, blur 30, y +10 | Default elevation for cards over a map |
| `sheet` | `rgba(0,0,0,.30)`, blur 40, y −20 | Bottom sheets rising over content |
| `brandMark` | `rgba(94,228,168,.30)` mint, blur 24, y +8 | Mint glow under the brand mark |
| `phoneFrame` | `rgba(0,0,0,.50)`, blur 80, y +30 | Splash phone-frame mock-up |

**Light-mode shadows** are softer: clamp the alpha down to ~0.10–0.14
or the page looks dirty. Read brightness via `context.isDark` and
swap.

---

## 8. Motion

All durations live in `app_durations.dart`. **Never invent a
duration in a widget.** If yours doesn't fit, add a constant.

| Token | ms | Use |
|---|---|---|
| `fast` | 120 | Tap feedback, ink ripple |
| `base` | 240 | Standard transitions, button-state |
| `slow` | 360 | Sheet open, banner enter |
| `breathe` | 1600 | Halo glow under hero elements (auction dial, brand mark) |
| `ping` | 1400 | Live-dot pulse, splash radar pulse |

### Motion principles

1. **Motion = state change.** A pulse fires only when the underlying
   thing is genuinely live (mint live-dot, auction halo).
2. **Enter from where the source is.** Sheets rise from below; banners
   fall from above; the marketplace deck slides up because it's "the
   floor". The direction tells the user where to look back.
3. **Curves: easeOutCubic in, easeInCubic out.** Never `elasticOut`,
   never `bounce`. We are not a candy app.
4. **One hero animation per screen.** The auction dial, the splash
   pulse, the banner — never two competing animations at once.
5. **Reduce motion respect.** Wrap heavy animations in
   `MediaQuery.of(context).disableAnimations` checks if a screen
   would visibly suffer from disabling them.

### Stagger pattern

When multiple elements animate in (splash brand reveal, gate sheet
content), stagger by `100–150ms` between siblings. Keeps the cascade
feeling intentional, not chaotic.

---

## 9. Iconography

We use **Material icons** (rounded variants where available) aliased
under our own names in `widgets/icons/drivio_icons.dart`. Examples:

```dart
DrivioIcons.notification        // notifications_rounded
DrivioIcons.car                 // directions_car_rounded
DrivioIcons.cash                // payments_rounded
DrivioIcons.bolt                // bolt_rounded — used for live indicators
```

Why Material rounded? Three reasons: (1) free, no extra dep weight;
(2) consistent across platforms (we don't ship SF Symbols on
Android); (3) the rounded variant matches our typography's curves
better than `_outlined` (cold) or `_sharp` (too neobrutalist for
general iconography — we save the hard edges for typography).

### Sizes

- **18** — inline with text, status banners
- **20** — chip and button leading icons
- **24** — primary action buttons
- **28** — empty-state heroes inside cards
- **32** — `IconCircleButton` discs

### Stroke weight

Material icons are pre-baked. Don't apply a `strokeWidth` override.
If the icon doesn't sit right next to text, it's the wrong icon —
don't fight it with stroke; pick another.

### Stand-alone icons

When an icon stands alone (no label), wrap it in `IconCircleButton`
or `BackButtonBox` so it has a clickable target ≥ 32×32. Bare
unlabeled icons are an accessibility miss.

---

## 10. Components

This section enumerates the canonical components in
`lib/modules/commons/widgets/`. Use these. Don't roll your own.

### Buttons — `DrivioButton`

```dart
DrivioButton(
  label: 'Continue',
  variant: DrivioButtonVariant.accent,   // accent | primary | ghost | danger
  onPressed: () => …,
  disabled: !canSubmit,
)
```

Height: `52` (`AppDimensions.buttonHeight`). Fills width by default.
Disabled state dims to ~40% opacity. **Always pass `onPressed: null`
to disable**, not just visual dim — keeps tap-target accessibility
right.

| Variant | Bg | Ink | Use |
|---|---|---|---|
| `accent` | `accent` (mint) | `accentInk` | Primary CTA — "Continue", "View offers" |
| `primary` | `text` | `bg` | High-contrast secondary — confirmation flows |
| `ghost` | transparent | `text` | Tertiary — "Maybe later", "Cancel" |
| `danger` | `red` | `redInk` | Destructive — "Yes, delete account" |

### Inputs — `DrivioInput`

```dart
DrivioInput(
  label: 'Full name',
  hint: 'Tunde Ogunleye',
  controller: _name,
  compact: true,           // tighter for sign-up forms
)
```

`compact: true` is the GoRide-style pattern — compressed vertical
rhythm, dense forms. Use on auth and KYC. Use the default looser
spacing on profile editing where the user has time.

### `PinInput`

The OTP cells. Holds an invisible `TextField` overlay that captures
real keyboard input. Visible cells reflect the controller value with
an animated `|` cursor on the active cell.

**Don't replace this with a per-cell focus-node-array pattern** — we
tried, and it caused the "can't tap any cell" bug.

### `PhoneNumberInput`

The 🇳🇬 +234 prefix + national-number combination. Used on sign-in
and sign-up. Strips non-digits, normalises to E.164.

### `Pill`

```dart
Pill(text: 'PEAK · 1.5×', tone: PillTone.amber)
```

Tones: `neutral`, `accent`, `blue`, `amber`, `red`. Pill radius is
`pill` (999). Always uppercase. Always letter-spaced ≥ 1.4. Never
end with a period.

### `Avatar`

Initial-based, gradient-backed. Variant 0–5 picks one of six
gradients deterministically.

```dart
Avatar(
  initial: 'E',
  variant: driverIdHash % 6,
  size: AppDimensions.avatarMd,    // 32 | 40 | 56
)
```

### `LiveDot`

Animated breathing dot. `ConsumerStatefulWidget` with a
`SingleTickerProviderStateMixin`. Use for live status indicators
(presence, auction open, "broadcasting").

### `BackButtonBox`

The 32×32 rounded back button. Always defaults to
`AppNavigation.pop()`. Live in the top-left of every detail page;
never write `IconButton(Icons.arrow_back)` directly.

### `IconCircleButton`

32×32 disc with a centered icon. Used for top-right utility actions
(notifications, safety toolkit, share).

### `ScreenScaffold`

The base wrapper for every page. `Scaffold` with theme-aware bg,
`SafeArea(bottom: false)`, optional `bottomBar`. **No fake status
bar.** No fake home indicator. Don't pass those flags — they don't
exist.

### `DetailScaffold`

The wrapper used by every profile sub-screen and most "extras". Has
a header row (back button + title + optional badge), scrollable body,
optional sticky `footer`. `DetailGroup` is the grouped-card primitive
used inside it.

### `DriverTabBar`

Bottom 4-tab nav (Drive · Earnings · Pricing · Profile). The
"active" tab is passed explicitly per page rather than inferred from
the route, so we don't get out-of-sync states during navigation.

### `OnlineToggle`

The big "go online" switch. Single source of truth: the
`HomeController.toggleOnline` action. Has internal state for press
+ pulse + `LiveDot`. Don't compose your own.

### `AppNotifier` & banner

Top-anchored slide-down banner system. Fire from anywhere — no
`BuildContext` required:

```dart
AppNotifier.error(message: "Couldn't save changes.");
AppNotifier.success(message: 'Vehicle added.');
AppNotifier.warning(message: 'Driver signal weak.');
AppNotifier.fromError(e, fallback: 'Could not load.', stackTrace: s);
```

The host is mounted once at the top of `MaterialApp.builder`. Auto-
dismisses after 4s. New calls replace any active banner (no queue).

### Gate sheets

The four gate sheets all live in
`dash/features/home/presentation/ui/widgets/`:

- `KycGateSheet` — KYC compliance
- `SubscriptionGateSheet` — subscription paywall
- `LocationGateSheet` — location permission
- `VehicleGateSheet` — no approved vehicle

All four follow the same skeleton: dimmed scrim, centered icon disc,
pill, h1 title, body, primary CTA, "Maybe later" text button. **When
you add a new gate, copy this shape exactly.**

---

## 11. Surface patterns

These are higher-order compositions — combinations of the components
above that recur across screens.

### The Marketplace Deck

The bottom panel that rises over a live route map. Used on
`/waiting`, `/ride-request`, `/active-trip`, parts of `/home`.

Shape:
- Top-corner radius `xl` (28)
- 1px hairline border on top edge — `accent` when state is "live"
  (offers in, trip in progress); `borderStrong` otherwise
- Default elevation: `card` shadow
- Drag indicator at top: 36×4 pill, `borderStrong`

### Eyebrow + content blocks

```
EYEBROW IN MONO          ← textDim, eyebrow style, uppercase
Big content              ← h2 or h1 below it
Supporting paragraph     ← bodySm in textDim
```

This is the dominant pattern across detail pages. Don't reverse it
(content on top, eyebrow below).

### Status tape

A single-line terminal-style status feed inside a surface card:

```
> broadcasting to drivers in your zone
```

Mono, with a `>` prefix in `accent` (live state) or `textDim`
(quiet). Cycles messages every 2.6s with cross-fade. See
`waiting_page.dart`'s `_StatusTape`.

### Route manifest

Pickup → dropoff vertical timeline:

```
●  PICKUP
   12 Awolowo Rd, Ikoyi
│
◇  DROPOFF
   Lekki Phase 1
[4.2 KM]  [~12 MIN]
```

Pickup uses an accent disc (10×10), dropoff uses a red rotated square
(9×9). Connector is a 2px vertical line in `borderStrong`. Distance
and ETA use mono caps in 4-radius square chips.

### The Auction Dial

The hero radial gauge for live auction time. 188×188, thin track
ring, mint drain arc, 12 marker dots around the rim that fill mint
as bids land. Centre: tabular `MM:SS` countdown. See
`waiting_page.dart`'s `_AuctionDial` for the canonical implementation.
**Don't ship a generic spinner where an auction dial belongs.**

### Mini metrics row

3-column row of stat tiles, each with a value (`metricVal`) and a
label (`micro` in `textDim`). Used on home dashboard, profile hub,
earnings.

```dart
Row(
  children: <Widget>[
    Expanded(child: _MiniMetric(value: '₦18,200', label: 'TODAY')),
    Expanded(child: _MiniMetric(value: '12', label: 'TRIPS')),
    Expanded(child: _MiniMetric(value: '4.9', label: 'RATING', showStar: true)),
  ],
)
```

Optional star icon trails the rating value, sized 14, in `amber`.

### Detail group cards

Used on profile sub-screens. A grouped-card primitive (`DetailGroup`)
that contains rows divided by hairline borders. Each row has an icon,
label, optional trailing meta, and disclosure chevron.

---

## 12. Map treatment

The driver app uses **MapLibre + OpenFreeMap** (no API key, no
quota). Style is dark-first.

### Marker palette

- **Pickup pin** — `accent` mint disc (10×10) with a `bg` 2px halo
- **Dropoff pin** — `red` rotated square (9×9) with a `bg` 1.5px halo
- **Driver position** — small mint car glyph, opacity 100% when
  fresh, 40% when stale (>15s since last fix)

### Polylines

- **Active route** — `accent` mint, 4px stroke, no dashes
- **Suggested route (pre-trip preview)** — `blue`, 3px, dashed
- **Demand heatmap cells** — geohash6 rectangles, opacity 0.18–0.6
  on a teal → amber → orange → red intensity ramp

### Empty-map background

When we render a stylised SVG-style map (e.g. on `MapTile` decorative
surfaces), use the `mapBg`, `mapRoad`, `mapWater`, `mapPark` tokens.
Never raw greys.

### Live overlays

A live driver position has:
- 2-second pulse halo behind the marker (`accentDim`, blur 12)
- Heading rotation if `heading_deg` is available (otherwise no
  rotation — never invent a heading)

---

## 13. Screen archetypes

Drivio's 39 screens fall into seven archetypes. Each has a canonical
shell. New screens should slot into the closest archetype.

### A. Auth / onboarding

`ScreenScaffold` → `BackButtonBox` (right of an eyebrow if not the
welcome) → `screenTitle` (1–2 lines) → supporting `bodySm` → form
fields → primary CTA at bottom.

Examples: welcome, sign-in, sign-up, OTP, paywall.

### B. KYC / step

Step indicator at top → eyebrow + h1 title → tall body content
(camera viewfinder, document upload tile, BVN/NIN form) → primary
CTA at bottom. Skip-able steps use ghost variant.

### C. Dashboard (home)

`ScreenScaffold` with map background → top utility row (online
toggle, notifications) → Marketplace Deck rising over the bottom
half → bottom tab bar.

### D. Active flow (ride request, active trip)

Map at top (~38%) → Marketplace Deck (~62%) with the auction dial,
route manifest, status tape, and primary action. No tab bar — full
focus.

### E. Detail / settings

`DetailScaffold` → `DetailGroup` cards. Each row navigates further
or toggles a switch. Pull-to-refresh on lists that are remote-
backed.

### F. List / inbox

`DetailScaffold` with empty state, loading shimmer, and rows. Rows
follow the `DetailGroup` row pattern.

### G. Edge state

Centered icon + h1 + bodySm + CTA. No tab bar, no header. Examples:
`no_requests`, `subscription_expired`, `rider_cancelled`, `offline`.

---

## 14. Voice & copy

### General rules

- **Sentence case in body.** "Set your pickup location first." — not
  "Set Your Pickup Location First."
- **Uppercase in eyebrows + status pills only.**
- **Active voice.** "We sent the code." > "The code has been sent."
- **Concrete > vague.** "Your wallet is too low. Top up to continue."
  > "Insufficient funds."
- **No exclamation marks** outside `success` notifications. Drivio is
  calm under pressure.
- **No emojis in primary copy.** Eyebrow tip lines and the no-
  requests rotating tips are the exceptions.

### Naira formatting

- Always: `₦5,400` (₦ symbol, no space, comma thousands)
- Never: `NGN 5400`, `5400 naira`, `N5400`
- Use `NairaFormatter.format(naira)` everywhere

### Time formatting

- Countdown timers: `MM:SS` (`00:42`)
- ETAs in cards: `~12 min` (mono caps in chips: `~12 MIN`)
- Long-form timestamps: `May 8, 11:43 PM` (no year unless > 60
  days old)
- Joined dates: `May 2026` — full month, four-digit year. **Never**
  `May '26` — gets misread as "May 26th".

### Error copy

The `humaniseError(...)` translator (in
`commons/errors/error_messages.dart`) is the single source of truth.
Every backend error code has a friendly mapping there. **Never
hand-write a fallback inline.** If your error needs new copy, add it
to the `_knownCodes` map.

---

## 15. Accessibility

### Hit targets

Minimum 32×32 for any tappable element. Buttons, list rows, icon
buttons all default to ≥48 in practice. **Bare `Icon` widgets are
not tappable** even with a `GestureDetector` parent — wrap in
`IconCircleButton` or `InkWell` with a defined size.

### Contrast

Body text on `bg` and `surface` meets WCAG AA at all sizes (verified
in design). When you put text on a custom-coloured surface (mint
button, amber pill), use the **ink** companion — that's why `accent`
has `accentInk`, etc.

### Dynamic type

The app respects system text scaling. Never set
`textScaleFactor: 1.0` — that's an accessibility regression. Layouts
are tested up to 1.3× scaling.

### Reduced motion

Heavy animations (auction dial halo, splash radar pulse) check
`MediaQuery.of(context).disableAnimations` and skip the animation
when the user has reduced motion enabled.

### Semantics

Every `IconCircleButton` and `BackButtonBox` has a `Semantics(label:
...)`. New stand-alone interactive elements must add one too. Lists
(`DetailGroup`) get `Semantics(container: true)` automatically.

---

## 16. Anti-patterns — what we never do

These are durable rules. Don't break them.

1. **No fake iOS chrome.** No mock status bar, no mock home
   indicator, no `100%` battery icon. The OS owns those pixels. The
   deleted `status_bar.dart` and `home_indicator.dart` widgets stay
   deleted.
2. **No raw `AppColors.fooDark`.** Always go through `context.foo`.
   Read your widget; if you see `Dark` or `Light` suffix, it's a
   bug.
3. **No plain `StatelessWidget` / `StatefulWidget`.** Every widget
   in this app is `ConsumerWidget` or `ConsumerStatefulWidget`.
   MIGRATION.md §1.12.
4. **No `Navigator.of(context).push(...)`.** Always go through
   `AppNavigation.push/replace/replaceAll/pop` with an `AppRoutes`
   constant.
5. **No commission shown to drivers.** Drivio takes a flat
   subscription, not a per-trip rake. The "you keep" line equals
   the bid price exactly; no `* 0.96` multiplier, ever.
6. **No `freezed`.** State classes are hand-written `@immutable`
   with manual `copyWith`. Codegen-free.
7. **No spinning circular indicators as the only loading UX.** Use
   shimmer skeletons that match the loaded layout 1:1. The
   `shimmer` package is already a dependency.
8. **No raw error messages.** Surface via `AppNotifier` with a
   message from `humaniseError(...)`. Database internals never
   reach the user.
9. **No trailing exclamation marks** outside `AppNotifier.success`.
10. **No `Inter` italic** unless the typographic intent is
    explicitly emphasis-in-prose. Italics in headings or button
    labels read like a typo.
11. **No emoji in headings.** Eyebrow tips, edge-state empty cards,
    and the "tap to ___" empty rotators are the only emoji
    surfaces.
12. **No `BuildContext` across `await` without capture.** Capture
    `ScaffoldMessenger.of(context)` BEFORE the await — or use
    `AppNotifier` which is context-free.

---

## 17. How to add a new component

1. **Check first.** Skim `commons/widgets/`. Nine times out of ten
   we already have it. If you build a duplicate, it'll get deleted
   in review.
2. **Pick the closest existing pattern.** A new card variant?
   Extend the existing card pattern, don't fork it.
3. **Use existing tokens.** No new colours, no new radii, no new
   durations unless you're adding to the token files. If your
   design needs a new value, pause and ask: should this be a token
   for the app, or am I solving a one-off?
4. **Match the import + folder convention.**
   ```
   lib/modules/commons/widgets/<thing>.dart
   ```
   And export from `commons/all.dart` if it'll be used outside
   `commons/`.
5. **`ConsumerWidget` / `ConsumerStatefulWidget`.** Even if it
   doesn't read Riverpod state today.
6. **`context.foo` colour reads.** Never raw constants.
7. **Tabular figures on numerical content.** If your widget shows
   a number, default to `FontFeature.tabularFigures()`.
8. **Add it to this doc.** Section 10 ("Components") needs the new
   entry. Future-you will thank past-you.

---

## Appendix — Token cheat-sheet

```dart
// Colours (always via context)
context.bg / surface / surface2 / surface3 / surface4
context.border / borderStrong
context.text / textDim / textMuted
context.accent / accentInk / accentDim
context.blue / blueInk
context.amber / amberInk
context.red / redInk
context.mapBg / mapRoad / mapRoadMajor / mapWater / mapPark

// Typography
AppTextStyles.displayLg | screenTitle | screenTitleSm |
              h1 | h2 | h3 |
              bodyLg | body | bodySm |
              caption | captionSm | micro |
              eyebrow | mono |
              priceHero | metricVal |
              button | buttonSm

// Spacing
AppDimensions.space2 | 4 | 6 | 8 | 10 | 12 | 14 | 16 | 18 |
              20 | 22 | 24 | 26 | 28 | 32 | 40 | 48

// Radius
AppRadius.sm (10) | md (14) | base (16) | lg (22) | xl (28) | pill (999)
AppRadius.sheetTop

// Motion
AppDurations.fast (120) | base (240) | slow (360) |
              breathe (1600) | ping (1400)

// Shadows
AppShadows.card | sheet | brandMark | phoneFrame
```

---

## Document maintenance

- This doc is **canon**. If a screen disagrees with it, fix the
  screen — don't quietly write a new pattern.
- If this doc disagrees with reality, fix the doc — but submit it as
  its own commit, not bundled with feature work.
- Last refreshed: 2026-05-08.
