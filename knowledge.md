# Drivio Driver — Session Knowledge Base

> Written so a future session can pick up the project cold. Read this first.

---

## 1. What this project is

**Drivio Driver** — a Flutter port of a marketplace driver app whose visual
spec was handed off as an HTML/JS prototype (Claude Design output). The app
lets gig drivers go online, set their own per-trip fare, accept/decline ride
requests, run an active trip lifecycle, and manage a flat-rate subscription
("Drivio Pro") plus profile, vehicle, documents, payments, support, and edge
states.

Project root: `/Users/ebube.okocha/StudioProjects/drivio_driver`.
Bundle ID and naming: `drivio_driver`.

---

## 2. Source materials

- **HTML prototype** (the visual contract):
  `/Users/ebube.okocha/Downloads/Drivio-handoff.zip`, extracted to
  `/tmp/drivio_handoff/drivio/`. The driver app entry is
  `drivio/project/Drivio Driver App.html`. Driver-specific JSX lives under
  `drivio/project/driver-components/` and `drivio/project/driver-styles.css`.
  Shared atoms (`Icon`, `Avatar`, `Rating`, `MapTile`) live under
  `drivio/project/components/`.
- **Coding rules**: `MIGRATION.md` at the repo root. It was originally
  written for a different project ("Kalabash") but the user explicitly said
  to ignore Kalabash references and follow the file-structure and
  coding-rules verbatim. Read sections §1, §2, §3, §3.1, §6, §7, §10
  before changing structural things.
- **Design spec** (written this session):
  `docs/superpowers/specs/2026-04-25-drivio-driver-app-design.md`. Outlines
  the module layout, dependencies, phasing, and out-of-scope list.

---

## 3. Architecture

Clean Architecture per feature, exactly as MIGRATION.md §6 prescribes:

```
modules/<module>/features/<feature>/presentation/
  ├── logic/
  │   ├── controller/<feature>_controller.dart    # StateNotifier + state class
  │   ├── data/...                                 # not used — no real backend
  │   └── domain/...                               # not used
  └── ui/
      ├── <feature>_page.dart
      └── widgets/
```

Modules under `lib/modules/`:

| Module          | Features                                                                                                |
| --------------- | ------------------------------------------------------------------------------------------------------- |
| `commons`       | DI, navigation, theme, shared widgets, helpers, utils                                                   |
| `authentication`| `welcome`, `sign_in`, `sign_up`, `otp`                                                                  |
| `subscription`  | `paywall`, `manage`                                                                                     |
| `dash`          | `home`, `add_vehicle`, `earnings`, `pricing`, `profile_hub`                                             |
| `trip`          | `ride_request`, `active_trip`, `chat`, `call`, `safety`                                                 |
| `profile`       | `vehicle_details`, `insurance`, `inspection`, `documents`, `reviews`, `payment_methods`, `referral`, `notifications`, `help`, `sign_out` |
| `cards`         | `add_card`                                                                                              |
| `documents`     | `reupload`                                                                                              |
| `vehicle`       | `vehicle_change`, `pickup_distance`                                                                     |
| `support`       | `help_article`, `support_chat`                                                                          |
| `edge_states`   | `no_requests`, `offline`, `subscription_expired`, `rider_cancelled`                                     |

### Pragmatic deviations from MIGRATION.md

These were intentional shortcuts to ship the prototype without code-gen:

1. **No `freezed`.** Controllers extend `StateNotifier<...State>` where the
   state is a hand-written immutable class with an explicit `copyWith`. Same
   contract, no `build_runner` needed.
2. **No `auto_route`.** Routes are string constants in
   `lib/modules/commons/navigation/app_routes.dart`; navigation goes through
   `AppNavigation` (a static façade over a `GlobalKey<NavigatorState>`); the
   route table is a `switch` statement in
   `lib/modules/commons/navigation/app_router.dart` registered as
   `MaterialApp.onGenerateRoute`. The public façade matches MIGRATION.md
   semantics: `AppNavigation.push/replace/replaceAll/pop`.
3. **No real backend.** No `*_service.dart` / `*_service_impl.dart` /
   `data/`/`domain/` layers were written. Controllers expose seeded constant
   data. Adding a service later only requires creating the abstract+impl
   under `presentation/logic/data/...` and injecting via `get_it`.
4. **No localisation.** Copy is inline strings, taken verbatim from the JSX.

### State management

- Every controller is `StateNotifier<XxxState>` with a top-level provider:
  `final xxxControllerProvider = StateNotifierProvider<...>(...)`.
- Every widget is `ConsumerWidget` or `ConsumerStatefulWidget` —
  **no plain `StatelessWidget`/`StatefulWidget` anywhere**. This is a
  MIGRATION.md §1.12 rule and was followed throughout.

### Theme

- `lib/modules/commons/theme/app_colors.dart` — every CSS custom prop from
  `driver-styles.css`'s `:root` (dark) and `.light` blocks. Tokens are
  suffixed `Dark`/`Light` (e.g. `accentDark`, `accentLight`, `mapBgDark`).
- `lib/modules/commons/theme/context_theme.dart` — `BuildContext` extension
  with theme-aware getters: `context.bg`, `context.surface`, `context.text`,
  `context.accent`, etc. **Always** use these inside widgets, not the raw
  `AppColors.*` constants. The extension reads `Theme.of(context).brightness`
  to pick light vs dark.
- `app_text_styles.dart`, `app_dimensions.dart`, `app_radius.dart`,
  `app_shadows.dart`, `app_gradients.dart`, `app_durations.dart`,
  `app_theme.dart` — the standard token kit.
- Font is **Inter** via `google_fonts` (applied in `app.dart`'s
  `_withInter` helper). The HTML used SF Pro / system fonts; Inter is the
  closest sans-serif drop-in.
- `themeModeProvider` in `theme/logic/theme_mode_controller.dart` exposes a
  `StateNotifier<ThemeMode>` that defaults to `ThemeMode.dark` (the HTML's
  default). Watched in `app.dart` and passed to `MaterialApp.themeMode`.

### Navigation surface

- `AppRoutes` — string constants for every route.
- `AppNavigation` — static façade. Methods: `push(name)`, `replace(name)`,
  `replaceAll(name)`, `pop()`, `canPop()`. Always go through this; never
  call `Navigator.of(context)` directly (MIGRATION.md §1.7).
- `AppRouter.onGenerateRoute` — `switch` mapping name → builder.
- `App` registers `navigatorKey: AppNavigation.navigatorKey` on the
  `MaterialApp` so the static façade has a navigator to talk to.

### DI

- `lib/modules/commons/di/di.dart` — `setupServiceLocator(Flavor)` registers
  `Config` only (everything else infrastructural is intentionally absent for
  the prototype port). Called from each `main_*.dart` before `App.run()`.

### Flavors

- `Flavor.prod` and `Flavor.stage`. Entry points: `main.dart` (defaults to
  prod), `main_prod.dart`, `main_stage.dart`. `Config` carries a `title`
  and `baseUrl` switched by flavor (URLs are placeholder).

---

## 4. File inventory

92 Dart files at last count. Important ones to know:

### Commons widgets (`lib/modules/commons/widgets/`)

| File | Purpose |
| ---- | ------- |
| `screen_scaffold.dart` | The standard page wrapper. `Scaffold` with theme-aware bg, `SafeArea(bottom: false)`, optional `bottomBar`. **No fake status bar** (the user explicitly removed it; the deleted `status_bar.dart` and `home_indicator.dart` are gone — don't recreate them). |
| `detail_scaffold.dart` | The detail-page wrapper used by every profile sub-screen and most extras. Has a header row (back-button + title + optional badge), scrollable body, and optional sticky `footer`. `DetailGroup` is the grouped-card primitive used inside it. |
| `back_button_box.dart` | The 32×32 rounded back button. Defaults to `AppNavigation.pop()`. |
| `buttons/button.dart` | `DrivioButton` with variants `accent`/`primary`/`ghost`/`danger`. Fills width by default; pass `disabled: true` to dim it; `onPressed: null` also dims. |
| `inputs/drivio_input.dart` | Standard labelled text field. `compact: true` for the tighter form fields used in sign-up/add-vehicle. |
| `inputs/phone_number_input.dart` | The 🇳🇬 +234 prefix + national-number input. |
| `inputs/pin_input.dart` | The OTP cells. **It really is editable** — has an invisible `TextField` overlaid on the row that captures keyboard input. The visible cells reflect the controller value and animate the active cell with `\|` cursor. Notifies parent via `onChanged(value)`. See "Bug fixes" below for context. |
| `pill.dart` | Small status pill. Tones: `neutral/accent/blue/amber/red`. |
| `avatar.dart` | Initial-based gradient avatar. `variant` (0–5) picks one of 6 gradients from `AppGradients.avatars`. |
| `rating.dart` | Star + numeric rating to 2dp. |
| `live_dot.dart` | Animated breathing dot. `ConsumerStatefulWidget` with a `SingleTickerProviderStateMixin`. |
| `map/drivio_map.dart` | A stylised SVG-style map painter (`CustomPaint`). Renders bg/water/park/roads, optional demand heatmap, optional pickup/dropoff pins, optional driver position, optional route polyline. **No `google_maps_flutter`** — keeps the prototype look and avoids API-key plumbing. |
| `online_toggle.dart`, `icon_circle_button.dart`, `progress_steps.dart`, `section_label.dart`, `field_row.dart`, `divider_dot.dart`, `sheet.dart`, `brand_mark.dart` | Self-explanatory primitives. |
| `icons/drivio_icons.dart` | The icon library (Material icons aliased by their HTML-prototype names). |

The `commons/all.dart` barrel re-exports everything above. Page files
typically just `import 'package:drivio_driver/modules/commons/all.dart';`
plus the page's own controller.

### Authentication module

- `welcome` — splash-style hero with map backdrop; CTAs route to sign-up
  and sign-in.
- `sign_in` — phone + password + Face-ID stub. Always-enabled "Sign in"
  routes to `home`. Has a `SignInController` but it's mostly cosmetic.
- `sign_up` — 4-step setup form (name, email, phone, password +
  referral card). `SignUpController` collects values; "Continue" routes to
  OTP.
- `otp` — 6-digit verify with resend countdown (24s default in state).
  `OtpController` exposes `setValue(String)` and `resend()`. The page wires
  `PinInput.onChanged` → `OtpController.setValue`. "Verify & continue" stays
  disabled until `state.isComplete` (all 6 digits filled), then routes to
  `paywall`.

### Subscription module

- `paywall` — onboarding paywall with plan card and 4 benefits. CTA
  routes to `home`. **Not a gate** — see §6 ("Known limitations").
- `manage` — subscription status, payment method, billing history.

### Dash module

- `home` — the marketplace screen. Map + online toggle + (when online)
  demand banner + (when no vehicle) add-vehicle banner + price bubble +
  bottom sheet with today's earnings. Has a `VehicleGateSheet` modal that
  pops over the screen if the user tries to go online without a vehicle.
  `HomeController` owns `status` (`offline/online/onTrip`) and `hasVehicle`.
- `add_vehicle` — make/model/year/colour/plate form + 2 doc upload tiles.
  On save, calls `homeControllerProvider.setHasVehicle(true)` and routes
  back to `home`.
- `earnings` — weekly chart + 4 metric cards (`Avg fare`, `Trips`,
  `Accept rate`, `Cancel rate`) + 3 coach-tip cards.
  **`childAspectRatio: 1.7`** on the metric `GridView.count` — see "Bug
  fixes" for why this matters.
- `pricing` — base fare + per-km steppers, peak-hour toggle + multiplier
  slider, night-shift toggle, trip-preference rows. Each row routes to
  `pickup-distance` for the prototype.
- `profile_hub` — the "Profile" tab. Hero (avatar + rating + verified
  badge), 3-stat strip, Vehicle / Documents / Reviews / Account / Settings
  groups. Every row routes to a sub-screen.

The `dash` features all use a shared `DriverTabBar` (4 tabs:
Drive/Earnings/Pricing/Profile) at the bottom; the "active" tab is passed
explicitly per page.

### Trip module

- `ride_request` — the hero. Top half is a stylised map with a 15-second
  countdown urgency timer (auto-decrements via `Timer.periodic`); bottom
  half is a route summary + the editable fare card + accept/decline.
  `RideRequestController` owns `price`, `suggested`, distance, duration,
  pricing variant (`type`/`slider`/`chips`), `secondsLeft`. The fare card
  has 3 variants:
  - **type**: `_PriceField` is a TextField the user can tap to edit
    directly with the keyboard; `_TypeKeys` row of `+500/+100/−100/−500`
    quick-adjusters works alongside.
  - **slider**: range slider from 60% to 160% of suggested.
  - **chips**: 4 chips at −15% / suggested / +15% / +30%.
  "You keep" displays the same value as the price (the prototype's `* 0.96`
  was a mistake the user corrected — see "User feedback").
- `active_trip` — 4-state lifecycle (`enRoute`/`arrived`/`inProgress`/
  `completed`). `ActiveTripController.advance()` cycles through them.
  Tapping the bottom-sheet action button advances. Completed state shows a
  "you earned" summary with tip breakdown.
- `chat` — rider chat with quick-reply chips, scrollable bubble list,
  composer.
- `call` — `_CallState.ringing` → `_CallState.active` (incrementing
  `_seconds` every second). Big red end button + (in active mode)
  mute/speaker/keypad placeholders.
- `safety` — the SOS hero, quick-action rows, trusted contacts.

### Profile sub-screens

All wrap `DetailScaffold`. `DocumentPage` is parameterised — used 3 times
from the route map for licence / registration / background check, with
different `policyNo`/`expiry`/`verifiedOn` strings.

`NotificationsPage` and `PricingPage` both use Material `Switch.adaptive`
with `activeTrackColor: context.accent` (NOT `activeColor`, which is
deprecated in current Flutter — see "Bug fixes").

### Edge cases

`no_requests`, `offline`, `subscription_expired`, `rider_cancelled`.
Each is a one-off scene with bespoke layout. They are reachable via direct
route names but not yet wired to any real-world trigger.

---

## 5. User feedback collected this session

These are corrections/preferences the user voiced. Treat them as durable
project rules:

1. **No fake iOS chrome.** Don't render time/wifi/battery overlays. The
   real device chrome handles that. The deleted files were
   `commons/widgets/status_bar.dart` and `commons/widgets/home_indicator.dart`
   — do not reintroduce them. `ScreenScaffold` no longer has `showStatusBar`
   or `showHomeIndicator` params.
2. **"You keep" equals the input price.** Drivio is flat-subscription,
   not commission-based, so there's no per-trip cut. `RideRequestState.netToYou`
   returns `price` directly. Don't re-add a fee multiplier.
3. **The big price in the request screen must be keyboard-editable.**
   When the variant is `type`, tapping the hero number focuses a real
   `TextField` so the OS keyboard pops up.
4. **OTP cells must accept input.** PinInput uses an invisible TextField
   overlay; tapping anywhere on the row focuses it. Don't replace this with
   a per-cell focus-node-array pattern — it caused the original "can't
   click" bug.

---

## 6. Known limitations / explicit non-features

- **No subscription gating.** `PaywallPage` and `EdgeSubscriptionExpiredPage`
  exist as screens but nothing forces the user through them. There is no
  `SubscriptionState` controller and no route guard. The user asked about
  this; the offered fix (a `SubscriptionController` + `SubscriptionGate`
  wrapper, or a per-action check) was not yet built — they didn't pick an
  approach. If you wire one up, the natural integration points are:
  - `HomePage`'s online-toggle (`HomeController.toggleOnline`)
  - `RideRequestPage` accept handler
  - The route generator (return the expired page for gated routes)
- **No persistence.** Theme mode, sign-in state, vehicle-on-file, none of
  it survives a process restart. Wire `SharedPreferences` (already in
  `pubspec.yaml`) into `ThemeModeController` and any new state notifiers
  that need to persist.
- **No real auth / API.** Sign-in/sign-up CTAs always succeed and route
  forward.
- **No analytics, Firebase, remote config.** Skipped per design doc.
- **No tests** beyond a placeholder `test/widget_test.dart`.
- **No iOS/Android platform tweaks.** Default templates only.
- **No localisation.** Copy is inline.

---

## 7. Bugs fixed this session

Useful to know in case similar mistakes appear again:

| Symptom | Root cause | Fix |
| ------- | ---------- | --- |
| `Config` ambiguous import in `app.dart` | `google_fonts` exports a `Config` too | Aliased: `import '...config.dart' as cfg;`, used `cfg.Config`. |
| `FontWeight.w650` undefined | Made-up weight — Flutter only has 100/200/.../900 | Replaced with `FontWeight.w700` in `h2` and `button`. |
| Test failed to build referencing `MyApp` | Default template's smoke test still pointed at the deleted demo widget | Replaced `test/widget_test.dart` with a placeholder. |
| `Switch.activeColor` deprecation warnings | Flutter 3.31+ deprecation | Switched to `activeTrackColor` in `pricing_page.dart` and `notifications_page.dart`. |
| OTP page crashed on open: "Incorrect use of ParentDataWidget. Expanded widgets must be placed inside Flex widgets." | In `PinInput`, an `Expanded` was wrapped in a `Padding` before being placed in the `Row` — so the `Row` saw `Padding`, not `Expanded`. | Reordered to `Expanded(child: Padding(child: AspectRatio(...)))`. |
| Earnings page: RenderFlex overflowed by 27 px on the bottom (in `_MetricCard`'s Column) | The metric `GridView.count` had `childAspectRatio: 2.5`, forcing each card to ~66 px tall while content needed ~85 px (eyebrow + value + delta + 28 px padding) | Lowered to `childAspectRatio: 1.7`. |
| OTP cells weren't tappable | `PinInput` was display-only — the cells were static `Container`s. There was no `TextField` to receive input. | Added an invisible full-row `TextField` overlay (`Opacity(0)` over `Positioned.fill`) that captures input; visible cells reflect its value reactively. The OTP page wires `onChanged` to `OtpController.setValue`. |

---

## 8. How to run

```bash
flutter pub get
flutter run            # uses lib/main.dart (prod flavor)
flutter run -t lib/main_stage.dart
flutter analyze        # currently 9 info-level lints, 0 warnings, 0 errors
```

Dependencies: `flutter_riverpod`, `get_it`, `flutter_screenutil`,
`google_fonts`, `intl`, `shared_preferences`, plus
`cupertino_icons` and `flutter_lints` (dev).

---

## 9. Conventions to follow when extending

These are absorbed from MIGRATION.md and the existing codebase. **Match
them when adding code:**

- **Always** use `ConsumerWidget` / `ConsumerStatefulWidget`. Never
  `StatelessWidget` / `StatefulWidget`.
- **Always** route via `AppNavigation.push/replace/...` with an
  `AppRoutes.xxx` constant. Never call `Navigator.of(context)` directly.
- **Always** read colours via `context.bg`, `context.text`,
  `context.accent`, etc. — not raw `AppColors.*Dark`/`*Light`. The
  extension picks the right token for the active brightness.
- **Always** declare return types and parameter types. The lint config
  enforces `strict-casts` / `strict-raw-types`.
- **Always** use single quotes (`'foo'`) and trailing commas on multi-line
  arg lists. `dart format .` will sort it out.
- File and folder names are `snake_case`; classes are `PascalCase`; page
  classes end in `Page`; controller classes end in `Controller`; state
  classes end in `State`; providers end in `Provider`.
- Do not write doc comments unless they explain a non-obvious business
  rule. Self-documenting code is the default (MIGRATION.md §1.14).
- New module? Follow the same `features/<feature>/presentation/{logic,ui}/`
  structure. Add a route constant to `AppRoutes`, a `case` to
  `AppRouter._builderFor`, and an export to `commons/all.dart` only if you
  added a new shared widget.

---

## 10. Where to look first when something breaks

- **Compile errors after editing**: `flutter analyze` (fast, ~2s).
- **A widget doesn't show up**: check `commons/all.dart` exports it, or
  that the page imports it directly.
- **A route doesn't exist**: `lib/modules/commons/navigation/app_router.dart`.
  The default fallback is `WelcomePage`, so unknown route names silently
  send you home.
- **Theme isn't reacting**: did you use `context.<token>`? If you used a
  raw `AppColors.xxxDark`, it won't flip in light mode.
- **Layout overflow in a `GridView.count`**: the `childAspectRatio` is
  almost certainly too tall. Drop it (smaller number = shorter cells).
- **`Expanded` errors**: it must be a *direct* child of `Row`/`Column`/
  `Flex`. Wrapping it in `Padding`/`Center`/etc. breaks it.

---

## 11. The git/spec trail

- Initial commit on this branch: just the design spec
  (`docs/superpowers/specs/2026-04-25-drivio-driver-app-design.md`).
- Everything since (the 92 Dart files, theme, routing, all 39 screens, the
  `knowledge.md` you're reading) is **uncommitted** in the working tree.
  The user has not yet asked to commit. Ask before committing — they
  haven't authorised it.

---

## 12. The 39 screens (canonical list)

Sourced from `Drivio Driver App.html`'s `FLOW`, `PROFILE_SUBS`, `EXTRAS`,
and `EDGE` arrays. Numbers match the prototype's labels.

**Core flow (12)**: 01 Welcome · 02 Sign in · 03 Sign up · 04 Verify OTP ·
05 Subscription paywall · 06 Home dashboard · 06a Add vehicle · 07 Ride
request (3 pricing variants) · 08 Active trip (4 stages) · 09 Earnings &
insights · 10 Pricing strategy · 11 Subscription mgmt · 12 Profile.

**Profile sub (12)**: vehicle-details · insurance · inspection ·
doc-licence · doc-registration · doc-background · reviews ·
payment-methods · referral · notifications · help · sign-out.

**Flow extras (11)**: chat · call · safety · add-card · reupload-licence ·
reupload-registration · reupload-background · vehicle-change ·
pickup-distance · help-article · support-chat. (The 3 reupload screens all
route to the same `ReuploadDocPage` — parameterisation by title is a
simple follow-up if needed.)

**Edge (4)**: no-requests · offline · subscription-expired ·
rider-cancelled.
