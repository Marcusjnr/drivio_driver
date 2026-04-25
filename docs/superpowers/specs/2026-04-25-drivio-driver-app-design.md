# Drivio Driver App — Design

## Goal

Implement the Drivio Driver mobile app in Flutter from the HTML prototype in
`/Users/ebube.okocha/Downloads/Drivio-handoff.zip` (`drivio/project/Drivio Driver App.html`),
following the structural contract documented in `MIGRATION.md` (originally written for
Kalabash but treated here as a generic project rule set — names, references, and any
Kalabash-specific labels are replaced with Drivio equivalents).

## Source of truth

- HTML prototype: `Drivio Driver App.html` + `driver-styles.css` + JSX components under
  `driver-components/` (and shared atoms under `components/`).
- Coding rules: `MIGRATION.md` (architecture, lint, freezed, theme, navigation, widget
  rules — every section applies; just substitute "Drivio" for "Kalabash").
- Visual tokens: `driver-styles.css` `:root` and `.light` variables.

## Scope

39 screens, grouped:

**Core flow (12).**
01 Welcome · 02 Sign in · 03 Sign up · 04 Verify OTP · 05 Subscription paywall ·
06 Home/Dashboard · 06a Add vehicle · 07 Ride request (3 pricing variants:
type/slider/chips) · 08 Active trip (en-route → arrived → in-progress → completed) ·
09 Earnings & insights · 10 Pricing strategy · 11 Subscription mgmt · 12 Profile hub.

**Profile sub-screens (12).**
Vehicle details · Insurance · Inspection · Driver's licence · Vehicle registration ·
Background check · Reviews · Payment methods · Refer & earn · Notifications · Help &
support · Sign out.

**Flow extras (11).**
Chat with rider · Call rider · Safety toolkit · Add payment card · Re-upload licence /
registration / background · Vehicle change request · Max pickup distance · Help
article · Support chat.

**Edge cases (4).**
No requests · Poor connection · Subscription expired · Rider cancelled.

## Architecture

Strict Clean Architecture per feature, exactly as MIGRATION.md §6 prescribes:

```
<module>/features/<feature>/
└── presentation/
    ├── logic/
    │   ├── controller/
    │   │   ├── <feature>_controller.dart
    │   │   └── <feature>_controller.freezed.dart
    │   ├── data/
    │   │   ├── datasources/remote_data_source/<feature>_service.dart
    │   │   ├── models/
    │   │   └── repositories/<feature>_service_impl.dart
    │   ├── domain/
    │   │   ├── entities/
    │   │   └── use_cases/
    │   └── enums/
    └── ui/
        ├── <feature>_page.dart
        └── widgets/
```

### Modules under `lib/modules/`

| Module          | Features                                                                                    |
| --------------- | ------------------------------------------------------------------------------------------- |
| `commons`       | DI, navigation, theme, shared widgets, helpers, utils                                       |
| `authentication`| `welcome`, `sign_in`, `sign_up`, `otp`                                                      |
| `subscription`  | `paywall`, `manage`                                                                         |
| `dash`          | `home`, `add_vehicle`, `earnings`, `pricing`, `profile_hub`                                 |
| `trip`          | `ride_request`, `active_trip`, `chat`, `call`, `safety`                                     |
| `profile`       | `vehicle_details`, `insurance`, `inspection`, `documents`, `reviews`, `payment_methods`, `referral`, `notifications`, `help`, `sign_out` |
| `cards`         | `add_card`                                                                                  |
| `documents`     | `reupload`                                                                                  |
| `vehicle`       | `vehicle_change`, `pickup_distance`                                                         |
| `support`       | `help_article`, `support_chat`                                                              |
| `edge_states`   | `no_requests`, `offline`, `subscription_expired`, `rider_cancelled`                         |

### State management

- `StateNotifier<...ControllerState>` + `@freezed` state per feature.
- Providers exposed as `<feature>ControllerProvider`.
- Every widget is `ConsumerWidget` or `ConsumerStatefulWidget`. No bare
  `StatelessWidget` / `StatefulWidget`.

### Navigation

- `auto_route` with `@AutoRouterConfig(replaceInRouteName: 'Page,Route')`.
- `AppNavigation.push/replace/pop` static façade backed by `RouterPort` resolved via
  `get_it`.
- Initial route: `WelcomeRoute` (no auth-state persistence in this prototype port —
  match the HTML's `FLOW[0]`).

### Theme

Tokens generated from `driver-styles.css`:

- `AppColors` — every CSS custom property under `:root` (dark default) and `.light`
  override, exposed as `AppColors.bg`, `AppColors.surface`, `AppColors.surface2..4`,
  `AppColors.accent`, `AppColors.accentInk`, `AppColors.blue`, `AppColors.amber`,
  `AppColors.red`, plus the dark-mode (`dm`-prefixed) and map-specific
  (`AppColors.mapBg`, `mapRoad`, `mapWater`, `mapPark`) tokens.
- `AppTextStyles` — derived from inline styles in JSX (the prototype is consistent —
  ~12 distinct text roles: hero/title/body/caption/eyebrow/mono/price-display/etc.).
- `AppDimensions`, `AppRadius`, `AppShadows`, `AppGradients`, `AppDurations`.
- `AppTheme.light` / `AppTheme.dark` `ThemeData` factories.
- `themeModeProvider` (StateNotifier<ThemeMode>) persists with `SharedPreferences`.

Surface-like colours resolve via `Theme.of(context)`; brand-constant colours
(`AppColors.accent`, brand blues) stay as raw tokens. See MIGRATION.md §5.5.1.

### Data

No real backend in this prototype port. Each `*_service_impl.dart` returns seeded
mock data after a short `Future.delayed` so loading states are exercised. The
`*_service.dart` interface stays real so a backend can replace the impl without
touching controllers.

### Maps

The HTML prototype uses an SVG-stylised map. Port this as a `CustomPainter`-driven
`DrivioMap` widget under `commons/widgets/map/` rather than integrating
`google_maps_flutter` (matches the prototype's stylised look and avoids API-key
plumbing for the prototype).

## File-tree skeleton

```
lib/
├── app.dart
├── main_prod.dart
├── main_stage.dart
├── gen/                                  # flutter_gen output
└── modules/
    ├── commons/
    │   ├── all.dart
    │   ├── config/{config.dart, flavor.dart}
    │   ├── di/di.dart
    │   ├── enums/
    │   ├── extensions/
    │   ├── helpers/
    │   ├── methods/methods.dart
    │   ├── navigation/{app_navigation, app_router, router_port, app_router_adapter}.dart
    │   ├── theme/{app_colors, app_text_styles, app_dimensions, app_radius, app_shadows, app_gradients, app_durations, app_theme, theme}.dart
    │   ├── theme/logic/theme_mode_controller.dart
    │   ├── utils/{api_call_status, app_logger, utils, naira_formatter}.dart
    │   └── widgets/
    │       ├── drivio_safe_area.dart
    │       ├── flavor_banner.dart
    │       ├── status_bar.dart
    │       ├── home_indicator.dart
    │       ├── live_dot.dart
    │       ├── avatar.dart
    │       ├── rating.dart
    │       ├── pill.dart
    │       ├── icons/drivio_icons.dart
    │       ├── map/drivio_map.dart
    │       ├── buttons/{button.dart, nav_button.dart}
    │       └── inputs/{drivio_input.dart, phone_number_input.dart, pin_input.dart}
    ├── authentication/features/{welcome, sign_in, sign_up, otp}/...
    ├── subscription/features/{paywall, manage}/...
    ├── dash/features/{home, add_vehicle, earnings, pricing, profile_hub}/...
    ├── trip/features/{ride_request, active_trip, chat, call, safety}/...
    ├── profile/features/{vehicle_details, insurance, inspection, documents, reviews, payment_methods, referral, notifications, help, sign_out}/...
    ├── cards/features/add_card/...
    ├── documents/features/reupload/...
    ├── vehicle/features/{vehicle_change, pickup_distance}/...
    ├── support/features/{help_article, support_chat}/...
    └── edge_states/features/{no_requests, offline, subscription_expired, rider_cancelled}/...
```

## Dependencies (pubspec)

```
flutter_riverpod, get_it, auto_route, freezed_annotation, json_annotation,
flutter_screenutil, shared_preferences, google_fonts (for SF Pro / Inter
fallback), intl

dev: build_runner, freezed, json_serializable, auto_route_generator,
flutter_lints
```

## Build phasing

1. **Foundation.** pubspec, theme tokens, commons (DI stub, nav skeleton, shared
   widgets), `app.dart`, `main_prod.dart`, `main_stage.dart`.
2. **Authentication.** Welcome → SignIn → SignUp → OTP → Paywall.
3. **Dash.** Home (online toggle, demand heat), Add vehicle gate, Earnings, Pricing
   strategy, Subscription mgmt, Profile hub.
4. **Trip.** Ride request (3 variants), Active trip (4 states), Chat, Call, Safety.
5. **Profile sub-screens.** All 12.
6. **Extras.** Add card, re-upload doc, vehicle change, pickup distance, help
   article, support chat.
7. **Edge cases.** No requests, offline, subscription expired, rider cancelled.
8. **Lint pass.** `dart format .` + `flutter analyze` until clean.

## Out of scope

- Real backend integration / OpenAPI client (`packages/openapi/`).
- Firebase init, remote config, analytics.
- Localisation ARB files (text stays inline strings — matching prototype copy).
- Unit / widget tests (the prototype port is visual; tests come in a follow-up).
- Native splash, app icons, signing.
- iOS/Android platform-specific tweaks beyond defaults.

## Definition of done (per screen)

- Visually matches the HTML at the design size (390 × 844, iPhone 14 baseline).
- Uses only design tokens — no raw hex, no inline `TextStyle` constructors.
- Theme-aware surfaces via `Theme.of(context)` where the HTML's `.dark`/`.light`
  CSS overrides apply.
- Widget is a `ConsumerWidget` / `ConsumerStatefulWidget`.
- No comments except where MIGRATION.md §1.14 explicitly allows them.
- `flutter analyze` exits clean against `analysis_options.yaml`.
