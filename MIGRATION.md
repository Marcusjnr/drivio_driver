# Kalabash Mobile v2 — HTML → Flutter Migration Guide

> **Purpose.** This document defines the *structural contract* that every
> screen, feature, and supporting utility in `kalabash_mobile_v2` must follow
> while migrating the HTML prototype
> (`/Users/ebube.okocha/Downloads/Kalabash mobile 2/index.html`) into Flutter.
>
> The structure mirrors the production pattern used by the sibling project
> `foodie_user_mobile_app_interface` (Clean Architecture with
> `feature-first` module layout, Riverpod state, `get_it` service locator,
> `auto_route` navigation, `freezed` data classes, flavors, and a strict
> Design-System barrel).
>
> Any deviation from the rules below must be justified in a PR description.

---

## Table of Contents

1. [High-Level Principles](#1-high-level-principles)
2. [Target Folder Tree](#2-target-folder-tree)
3. [Naming Conventions](#3-naming-conventions)
   1. [Lint compliance (`analysis_options.yaml`)](#31-lint-compliance-analysis_optionsyaml)
   2. [Widget method ordering](#32-widget-method-ordering)
4. [Entry Points & Flavors](#4-entry-points--flavors)
5. [The `commons/` Package](#5-the-commons-package)
   1. [`all.dart` barrel](#51-alldart-barrel)
   2. [`config/`](#52-config)
   3. [`di/`](#53-di-service-locator)
   4. [`navigation/`](#54-navigation)
   5. [`theme/`](#55-theme-already-in-place)
      1. [Dark / Light Mode (theme switching)](#551-dark--light-mode-theme-switching)
   6. [`core/features/`](#56-corefeatures)
   7. [`domain/`, `enums/`, `extensions/`, `methods/`](#57-domain-enums-extensions-methods)
   8. [`helpers/`](#58-helpers)
   9. [`utils/`](#59-utils)
      1. [Flag rendering rule — always use `CountryCodeUtils`](#591-flag-rendering-rule--always-use-countrycodeutils)
   10. [`widgets/`](#510-widgets-shared-ui)
      1. [Input & Validation — the one textfield rule](#5101-input--validation--the-one-textfield-rule)
      2. [Escape hatch — bespoke inputs still need a validator contract](#5102-escape-hatch--bespoke-inputs-still-need-a-validator-contract)
6. [Feature Module Template](#6-feature-module-template)
7. [State Management Rules](#7-state-management-rules)
8. [Navigation Rules](#8-navigation-rules)
9. [Networking & Error Handling Rules](#9-networking--error-handling-rules)
10. [HTML → Flutter Conversion Recipe](#10-html--flutter-conversion-recipe)
11. [Module Map: HTML Screens → Feature Modules](#11-module-map-html-screens--feature-modules)
12. [Build, Codegen & Environment](#12-build-codegen--environment)
13. [Testing Conventions](#13-testing-conventions)
14. [Migration Workflow (step-by-step)](#14-migration-workflow-step-by-step)
15. [Definition of Done per Screen](#15-definition-of-done-per-screen)
16. [Color Matching Rules (every screen)](#16-color-matching-rules-every-screen)
    1. [Why a dedicated colour pass is non-negotiable](#161-why-a-dedicated-colour-pass-is-non-negotiable)
    2. [The source-of-truth hierarchy](#162-the-source-of-truth-hierarchy)
    3. [Dark-mode is state-dependent — read BEFORE you code](#163-dark-mode-is-state-dependent--read-before-you-code)
    4. [Token priority (never hard-code a colour you can name)](#164-token-priority-never-hard-code-a-colour-you-can-name)
    5. [Per-widget colour checklist](#165-per-widget-colour-checklist)
    6. [rgba(…) → Flutter ARGB conversion rules](#166-rgba--flutter-argb-conversion-rules)
    7. [Reference palette (HTML line → Flutter token)](#167-reference-palette-html-line--flutter-token)
    8. [Step-by-step colour audit protocol](#168-step-by-step-colour-audit-protocol)
    9. [Review gate (must pass before the PR merges)](#169-review-gate-must-pass-before-the-pr-merges)
17. [Font Weight Matching Rules (every screen)](#17-font-weight-matching-rules-every-screen)
    1. [Why a dedicated font-weight pass is non-negotiable](#171-why-a-dedicated-font-weight-pass-is-non-negotiable)
    2. [The source-of-truth hierarchy for weights](#172-the-source-of-truth-hierarchy-for-weights)
    3. [The "no explicit font-weight" trap](#173-the-no-explicit-font-weight-trap)
    4. [CSS weight → Flutter `FontWeight` mapping](#174-css-weight--flutter-fontweight-mapping)
    5. [DM Sans weight availability](#175-dm-sans-weight-availability)
    6. [Per-widget font-weight checklist](#176-per-widget-font-weight-checklist)
    7. [Weight semantics (pick meaning, not a number)](#177-weight-semantics-pick-meaning-not-a-number)
    8. [Step-by-step font-weight audit protocol](#178-step-by-step-font-weight-audit-protocol)
    9. [Review gate (must pass before the PR merges)](#179-review-gate-must-pass-before-the-pr-merges)
18. [Font Size Matching Rules (every screen)](#18-font-size-matching-rules-every-screen)
    1. [Why a dedicated font-size pass is non-negotiable](#181-why-a-dedicated-font-size-pass-is-non-negotiable)
    2. [The source-of-truth hierarchy for sizes](#182-the-source-of-truth-hierarchy-for-sizes)
    3. [CSS px → Flutter `fontSize` (the 1 : 1 rule)](#183-css-px--flutter-fontsize-the-1--1-rule)
    4. [The "no explicit font-size" trap](#184-the-no-explicit-font-size-trap)
    5. [Inline-style override hotspots](#185-inline-style-override-hotspots)
    6. [Per-widget font-size checklist](#186-per-widget-font-size-checklist)
    7. [Size semantics (pick a role, not a raw number)](#187-size-semantics-pick-a-role-not-a-raw-number)
    8. [Step-by-step font-size audit protocol](#188-step-by-step-font-size-audit-protocol)
    9. [Review gate (must pass before the PR merges)](#189-review-gate-must-pass-before-the-pr-merges)
19. [No Comments Rule (every migration)](#19-no-comments-rule-every-migration)
20. [Feature-Scoped Domain Layout (every migration)](#20-feature-scoped-domain-layout-every-migration)
21. [Cards Module Migration Notes](#21-cards-module-migration-notes)
22. [Toasts & Alerts — `KalabashAppNotification` is the only path](#22-toasts--alerts--kalabashappnotification-is-the-only-path)
23. [Freezed Rule — controller state and model classes](#23-freezed-rule--controller-state-and-model-classes)

---

## 1. High-Level Principles

1. **Feature-first, not layer-first.** Every screen belongs to a *feature*,
   every feature belongs to a *module*. Shared scaffolding lives under
   `commons/`.
2. **Clean Architecture inside each feature** — `data/` → `domain/` → `presentation/`
   (with `logic/` inside `presentation/` by convention, see §6).
3. **Design-system first.** No raw hex, no magic numbers, no ad-hoc
   `TextStyle`. Always use the tokens in
   `lib/modules/commons/theme/` (already generated 1:1 from
   `kalabash-design-system_Ebube.html`).
4. **One screen per file.** Widgets larger than ~60 lines that are reused
   twice or more get their own `widgets/…dart` file inside the feature.
5. **One controller per feature.** Stateful screens delegate logic to a
   Riverpod `StateNotifier` (or `AsyncNotifier`) whose state class is a
   `@freezed` class. Controller state is ALWAYS freezed — see §23.
6. **Global singletons via `get_it`.** Riverpod is used *only* for UI state;
   infrastructure (API client, logger, nav key, remote config) is resolved
   from `locator`.
7. **Routing via `auto_route`.** Never call `Navigator.of(context)` directly.
   Use `AppNavigation.push(...)` / the `RouterPort` abstraction.
8. **Type safety.** Every data-carrying class (entities, requests, responses,
   outcomes, view-models, controller state) is a `@freezed` class — no
   hand-rolled data classes, ever. DTOs that cross the wire add
   `json_serializable`. Enums are Dart enums or `@freezed sealed class`
   unions, never strings. See §23 for the full contract.
9. **Null-safety and explicit returns.** No implicit dynamic, no
   `late` without cause, return types always present.
10. **Testability.** Every use-case and every service has an interface
    (`abstract class`) so that it can be mocked with `mockito`.
11. **Lint-clean by construction.** Every file written for this migration
    must pass `flutter analyze` with zero warnings against the project's
    `analysis_options.yaml`. The full rule set and the idioms it enforces
    are documented in §3.1 "Lint compliance (`analysis_options.yaml`)" —
    read it once before writing code, and re-run `flutter analyze` before
    every PR.
12. **Every widget is a Riverpod `Consumer*` widget.** Do **not** extend
    `StatelessWidget` or `StatefulWidget` anywhere in this project — not
    even for "dumb" private helpers or decorative widgets. Always use
    `ConsumerWidget` (stateless) or `ConsumerStatefulWidget` +
    `ConsumerState<T>` (stateful). This guarantees that any future state
    or provider watch can be wired in without rewriting the widget type.
    The rationale and the canonical snippets live in §7 "State Management
    Rules".
13. **Theme-aware surfaces by default.** The HTML prototype ships a
    `.dark-mode` class that the settings screen toggles at runtime,
    flipping every surface that carries a light-mode hex. Every Flutter
    screen **must** resolve those surfaces through `Theme.of(context)`
    (or the theme-aware helpers described in §5.5.1), **not** through
    raw `AppColors.*` constants. Raw brand tokens remain appropriate
    only for elements that intentionally stay constant in both modes
    (splash gradient, primary-button fill, badge foregrounds, the
    Kalabash logo). The mode itself is exposed by
    `themeModeProvider` — see §5.5.1 "Dark / Light Mode (theme
    switching)" for the provider, the full CSS-to-Flutter surface
    mapping, and the enforcement workflow.
14. **Comment sparingly — let code speak.** Do **not** add a dartdoc
    block to every function, method, field, or private widget. Good
    Dart/Flutter code is self-documenting; names, types, and widget
    structure already convey intent. Comments are allowed **only** when
    they add information the reader cannot get from the code itself:
    (a) public API entry points on a feature boundary (the top-level
    page class, the controller class, a shared widget in
    `commons/widgets/`), (b) non-obvious business rules or
    workarounds (e.g. "backend returns `null` when the user has no
    saved cards — treat as empty"), (c) references back to the HTML
    prototype when the Flutter layout deviates from a one-to-one port.
    Do **not** comment: parameter lists, obvious getters, private
    helper widgets, straightforward `build` methods, enum values,
    state fields, or single-call wrappers. If a reviewer could delete
    the comment without losing information, it shouldn't have been
    written. ASCII-art diagrams, parroting the widget tree, and
    restating what a well-named method already says are all forbidden.
15. **Icons follow the HTML source.** The HTML prototype loads
    [Phosphor Icons](https://phosphoricons.com) via
    `<script src="https://unpkg.com/@phosphor-icons/web"></script>`
    and renders each icon as `<i class="ph ph-<name>">` (regular weight)
    or `<i class="ph-fill ph-<name>">` / `ph-bold` / `ph-light` /
    `ph-thin` / `ph-duotone` (other weights). The Flutter port uses the
    [`phosphor_flutter`](https://pub.dev/packages/phosphor_flutter)
    package (already pinned in `pubspec.yaml`) as the 1:1 replacement.
    Rules:
    * **If the HTML uses a Phosphor icon, the Flutter port MUST use
      `PhosphorIcons.<camelCaseName>(<style>)` — never a `Icons.xxx`
      Material equivalent, never a hand-drawn SVG.**
    * **If the HTML uses an inline `<svg>` or a Unicode glyph
      (`←`, `✓`, custom caret path), do NOT invent a Phosphor icon for
      it.** Port the SVG as-is via an `SvgPicture.asset(...)` /
      `CustomPaint`, or use the closest `Icons.*` primitive when the
      glyph is trivially Material (e.g. `←` → `Icons.arrow_back_rounded`).
      The phone, OTP, and country-select screens are examples — the HTML
      there is 100% inline SVG, so the Flutter port correctly uses
      Material icons.
    * **Weight mapping.**
      `ph ph-foo` → `PhosphorIcons.foo()` (regular is the default),
      `ph-fill ph-foo` → `PhosphorIcons.foo(PhosphorIconsStyle.fill)`,
      `ph-bold ph-foo` → `PhosphorIcons.foo(PhosphorIconsStyle.bold)`,
      likewise for `light`, `thin`, and `duotone`.
    * **Naming.** Convert the kebab-case class suffix to camelCase for
      the method name: `ph-airplane-tilt` → `airplaneTilt`,
      `ph-caret-right` → `caretRight`, `ph-shield-check` →
      `shieldCheck`, `ph-house-simple` → `houseSimple`.
    * **Canonical usage.**
      ```dart
      import 'package:phosphor_flutter/phosphor_flutter.dart';

      Icon(
        PhosphorIcons.airplaneTilt(),                     // ph ph-airplane-tilt
        size: 22.r,
        color: AppColors.textPrimary,
      )
      Icon(
        PhosphorIcons.check(PhosphorIconsStyle.fill),     // ph-fill ph-check
        size: 14.r,
        color: AppColors.green,
      )
      ```
    * **Never** mix icon systems on the same screen. If one icon on the
      screen is a Phosphor icon per the HTML, any other icon on that
      same screen that *also* has a Phosphor equivalent in the HTML
      must also be ported via `phosphor_flutter` — don't pick-and-mix
      with Material icons.

---

## 2. Target Folder Tree

```
kalabash_mobile_v2/
├── .env                              # copy of .env.example, local secrets
├── .env.example
├── lib/
│   ├── app.dart                      # App ConsumerStatefulWidget (root)
│   ├── firebase_options_prod.dart    # generated by flutterfire
│   ├── firebase_options_stage.dart
│   ├── main_prod.dart                # prod flavor entry
│   ├── main_stage.dart               # stage flavor entry
│   ├── gen/                          # flutter_gen output (assets.gen.dart)
│   ├── l10n/                         # ARB files + AppLocalizations
│   │   ├── app_en.arb
│   │   └── l10n.dart
│   └── modules/
│       ├── commons/
│       │   ├── all.dart              # barrel — re-exports everything common
│       │   ├── config/
│       │   │   ├── config.dart
│       │   │   └── flavor.dart
│       │   ├── core/
│       │   │   ├── features/
│       │   │   │   └── remote_config/
│       │   │   │       ├── data/
│       │   │   │       │   ├── enums/
│       │   │   │       │   │   └── remote_config_key.dart
│       │   │   │       │   └── remote_config_helper.dart
│       │   │   │       ├── domain/
│       │   │   │       └── presentation/
│       │   │   │           ├── logic/
│       │   │   │           │   ├── remote_config_controller.dart
│       │   │   │           │   └── remote_config_controller.freezed.dart
│       │   │   │           └── ui/
│       │   │   │               └── remote_config_observer.dart
│       │   │   └── presentation/      # cross-feature generic pages (e.g. verify_otp_page)
│       │   ├── di/
│       │   │   └── di.dart
│       │   ├── domain/
│       │   │   └── entities/
│       │   │       └── user/
│       │   │           ├── user.dart
│       │   │           ├── user.freezed.dart
│       │   │           └── user.g.dart
│       │   ├── enums/
│       │   │   └── overlay_enums.dart
│       │   ├── extensions/
│       │   │   ├── context.dart
│       │   │   ├── list.dart
│       │   │   └── string.dart
│       │   ├── helpers/
│       │   │   ├── api_helper.dart
│       │   │   ├── app_gesture_detector.dart
│       │   │   ├── foodie_app_notification.dart  # rename → kalabash_app_notification.dart
│       │   │   ├── haptic_feedback_helper.dart
│       │   │   └── http_helper.dart
│       │   ├── methods/
│       │   │   └── methods.dart
│       │   ├── navigation/
│       │   │   ├── app_navigation.dart
│       │   │   ├── app_router.dart
│       │   │   ├── app_router.gr.dart           # generated
│       │   │   ├── app_router_adapter.dart
│       │   │   ├── router_port.dart
│       │   │   ├── guards/
│       │   │   │   ├── onboarding_guard.dart
│       │   │   │   └── auth_guard.dart
│       │   │   └── services/
│       │   │       └── navigation_service.dart
│       │   ├── theme/                            # ALREADY EXISTS — do not re-generate
│       │   │   ├── app_colors.dart
│       │   │   ├── app_dimensions.dart
│       │   │   ├── app_durations.dart
│       │   │   ├── app_gradients.dart
│       │   │   ├── app_radius.dart
│       │   │   ├── app_shadows.dart
│       │   │   ├── app_text_styles.dart
│       │   │   ├── app_theme.dart
│       │   │   └── theme.dart                    # barrel
│       │   ├── utils/
│       │   │   ├── api_call_status.dart
│       │   │   ├── app_logger.dart
│       │   │   ├── utils.dart                    # getDeviceWidth/Height helpers
│       │   │   └── interceptors/
│       │   │       └── backend_client.dart
│       │   └── widgets/                          # cross-feature widgets
│       │       ├── app_overlay.dart
│       │       ├── flavor_banner.dart
│       │       ├── kalabash_alert.dart
│       │       ├── kalabash_safe_area.dart
│       │       ├── buttons/
│       │       │   ├── button.dart               # Button + Button.fullWidth/secondary
│       │       │   └── nav_button.dart
│       │       ├── inputs/
│       │       │   ├── input.dart
│       │       │   ├── phone_number_input.dart
│       │       │   └── pin_input.dart
│       │       └── bordered_container.dart
│       ├── authentication/                # MODULE
│       │   ├── authentication.dart        # optional per-module barrel
│       │   └── features/
│       │       ├── splash/                # FEATURE  → screen-splash
│       │       ├── onboarding/            # FEATURE  → screen-onboarding
│       │       ├── sign_up/               # FEATURE  → screen-phone, screen-otp, screen-account-setup, screen-email-otp
│       │       ├── login/                 # FEATURE  → screen-signin
│       │       ├── forgot_password/       # FEATURE  → screen-forgot-otp, screen-new-password
│       │       └── wallet_pin/            # FEATURE  → screen-create-pin, screen-confirm-pin, screen-wallet-intro
│       ├── kyc/                           # MODULE
│       │   └── features/
│       │       ├── kyc_welcome/           # screen-kyc-welcome
│       │       ├── bvn/                   # screen-bvn
│       │       ├── address/               # screen-address
│       │       ├── nin/                   # screen-nin
│       │       ├── proof_of_address/      # screen-proof-address, screen-camera, screen-photo-review
│       │       └── liveness/              # screen-liveliness, screen-liveness-cam
│       ├── dash/                          # MODULE — bottom-tab shell + tabs
│       │   └── features/
│       │       ├── home/                  # screen-home, screen-home-funded, screen-guest-home
│       │       ├── cards/                 # screen-cards, card-* screens
│       │       ├── travel/                # screen-flight*, screen-stays*, screen-things*
│       │       ├── rewards/               # screen-rewards, screen-redeem-*
│       │       ├── more/                  # screen-more, screen-settings, screen-ai-agent
│       │       └── notifications/         # screen-notifications, screen-all-transactions
│       ├── savings/                       # MODULE (Save-to-Travel)
│       │   └── features/
│       │       ├── explore/               # screen-stt-explore
│       │       ├── plans/                 # screen-stt-plans, screen-stt-plans-empty
│       │       ├── flexible/              # screen-flex-intro, screen-flex-step1/2/3, screen-flex-detail
│       │       ├── locked/                # screen-locked-intro, screen-locked-detail
│       │       ├── curated/               # screen-curated-detail, screen-curated-deposit
│       │       └── transactions/          # screen-deposit, screen-withdraw, screen-history-*
│       ├── wallet/                        # MODULE
│       │   └── features/
│       │       ├── fund/                  # screen-fund-card, screen-fund-card-pin
│       │       ├── idtp/                  # screen-idtp-*
│       │       └── pin/                   # shared wallet-pin modal (screen-card-wallet-pin)
│       ├── bills/                         # MODULE
│       │   └── features/
│       │       ├── airtime/               # screen-bills-airtime
│       │       ├── data/                  # screen-bills-data, screen-travel-data
│       │       ├── electricity/           # screen-bills-electricity
│       │       ├── pss/                   # screen-pss*, screen-pss-phone-otp
│       │       └── success/               # screen-bills-success, screen-pss-pay-success
│       └── cards/                         # MODULE
│           └── features/
│               ├── physical/              # screen-card-physical-detail, pickup, delivery
│               ├── virtual/               # screen-card-virtual-detail, virtual-order
│               ├── delivery/              # screen-card-delivery-method, screen-card-home-delivery
│               ├── dashboard/             # screen-card-dashboard, screen-card-transactions
│               ├── transactions/          # screen-card-txn-detail, screen-card-txn-netflix
│               └── deals/                 # screen-card-deals
├── test/
├── packages/
│   └── openapi/                           # local package — generated Dio client
├── pubspec.yaml                           # already present, do not break
└── MIGRATION.md                           # this file
```

> **Note on module naming.** A *module* is a top-level folder under
> `lib/modules/`, a *feature* is a folder under `<module>/features/`. A
> feature owns 1 — N related screens. Never create a single-screen
> top-level module unless the domain clearly warrants it.

---

## 3. Naming Conventions

| Item                            | Convention                                                                                  | Example                                         |
| ------------------------------- | ------------------------------------------------------------------------------------------- | ----------------------------------------------- |
| File & folder names             | `snake_case`                                                                                | `create_your_account_page.dart`                 |
| Classes                         | `PascalCase`, suffix indicates role                                                         | `SignUpController`, `SignUpPage`                |
| Screen widget class             | ends with `Page`                                                                            | `HomeDashPage`                                  |
| Widget file paired with class   | file name = snake_case of class                                                             | `sign_up_page.dart` → `SignUpPage`              |
| Controller                      | ends with `Controller`, provider suffix `Provider`                                          | `signUpControllerProvider`                      |
| Controller state                | `<Feature>ControllerState`, a `@freezed` class                                              | `SignUpControllerState`                         |
| Service interface               | ends with `Service`, `abstract class`                                                       | `SignUpService`                                 |
| Service implementation          | ends with `ServiceImpl`                                                                     | `SignUpServiceImpl`                             |
| Use case                        | ends with `UseCase`, has a single `call(...)` method                                        | `CreateUserUseCase`                             |
| Entity / value object           | `PascalCase`, `@freezed` + `.freezed.dart`/`.g.dart` parts                                  | `CreateUserRequest`                             |
| Enum                            | `PascalCase`                                                                                | `VerificationType`, `Flavor`                    |
| Sealed result type              | `<Concept>Result`, with factories for each variant                                          | `VerificationResult.success()`                  |
| Auto-route generated route      | `<Page>Route` (because `replaceInRouteName: 'Page,Route'`)                                  | `SignUpPage` → `SignUpRoute`                    |
| Design-system token classes     | `App<Kind>`                                                                                 | `AppColors`, `AppTextStyles`, `AppDimensions`   |
| Keys for tests/a11y             | prefix `const Key('snake_case_identifier')`                                                 | `Key('get_started_cta')`                        |
| Asset gen class                 | `Assets.images.png.<file>`                                                                  | `Assets.images.png.kalabashLogo`                |

### Widget keys

Every interactive element **and every screen root** gets a `Key('...')` so
widget tests and analytics can target them deterministically. This is a
convention carried over from `foodie_user_mobile_app_interface` — see
`sign_up_page.dart` for reference.

### 3.1 Lint compliance (`analysis_options.yaml`)

The project's `analysis_options.yaml` is the **source of truth for code
style**. It extends `package:flutter_lints/flutter.yaml` and then enables
a strict extra rule set plus `strict-casts` and `strict-raw-types`.
Every file you write for this migration must pass `flutter analyze`
with **zero** warnings against it.

**Read the file once before writing code.** The rules are not exotic —
they're the "best-practice" Dart lints — but a few have specific
formatting consequences that differ from how a lot of sample code
online is written. The most commonly-hit ones, with the code shape they
force, are:

| Rule (from `analysis_options.yaml`)          | What it means in practice                                                                                                                    |
| -------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------- |
| `always_use_package_imports`                 | Never use relative imports (`../../foo.dart`). Always `import 'package:kalabash_mobile_v2/...';`.                                           |
| `directives_ordering`                        | Imports are grouped `dart:` → `package:` → relative, each group sorted alphabetically, with a blank line between groups.                     |
| `prefer_single_quotes`                       | Use `'text'` everywhere. `"text"` is only for strings that already contain a literal `'`.                                                    |
| `require_trailing_commas`                    | Every multi-line parameter / argument list ends with a trailing comma (`,`). `dart format` will do it for you — run it.                      |
| `always_put_control_body_on_new_line`        | No one-liners like `if (x) return;`. Always `if (x) {\n  return;\n}` — even for a single statement.                                          |
| `sort_child_properties_last`                 | In widget constructors, `child:` and `children:` must be the **last** named argument.                                                        |
| `use_key_in_widget_constructors`             | Every public `Widget` subclass takes `{super.key, ...}`.                                                                                     |
| `always_declare_return_types`                | Every function & method declares its return type. Do not rely on inference for named functions.                                              |
| `prefer_final_locals` / `prefer_final_fields`| Locals and fields that are never reassigned must be `final`.                                                                                 |
| `unawaited_futures`                          | Any `Future` you intentionally don't `await` must be wrapped in `unawaited(...)` (from `dart:async`). Applies to things like haptics/analytics. |
| `file_names` / `package_names`               | Files, folders, and the pubspec `name` are all `snake_case`.                                                                                 |
| `eol_at_end_of_file`                         | Every file ends with a single trailing newline.                                                                                              |
| `unnecessary_const` / `unnecessary_new`      | Don't re-assert `const` inside a context that already infers it, and never write `new`.                                                      |
| `strict-casts` / `strict-raw-types`          | No implicit `dynamic` casts and no raw generic types — write `List<String>`, never `List`.                                                   |
| `no_default_cases` / `exhaustive_cases`      | `switch` on an enum must cover every case explicitly; no `default` clause.                                                                   |

**Enforcement workflow.** Before opening a PR, run:

```bash
dart format .
flutter analyze
```

Both must exit cleanly. CI runs the same two commands; a non-zero exit
blocks merge. If a rule is genuinely in the way of a specific line,
prefer an inline `// ignore: lint_name` with a comment explaining why,
over disabling the rule globally in `analysis_options.yaml` — changes
to the shared lint config need design review.

**Scope exceptions.** The `analyzer.exclude` block in
`analysis_options.yaml` already excludes generated code:
`lib/gen/**`, `lib/**/*.g.dart`, `lib/**/*.gr.dart`,
`test/**/*.mocks.dart`, and `lib/generated_plugin_registrant.dart`. You
do not need to format or lint-fix those files — `build_runner` and
`flutter_gen` own them.

### 3.2 Widget method ordering

Inside every widget class (`ConsumerWidget`, `ConsumerStatefulWidget`,
`ConsumerState<T>`), the `build()` method is the **first method body**
in the class. Any helper method on the widget — event handlers
(`_onTap`, `_onSubmit`), internal builders (`_buildHeader`,
`_buildFooter`), computed getters, and private utilities — is written
**below** `build()`.

Order within the class body:

1. `static` members (route names, `show(...)` helpers, constants).
2. Instance fields (controllers, `late final` handles, flags).
3. Constructor.
4. `initState()` and `dispose()` (in that order) — `ConsumerState` only.
5. `didChangeDependencies()` / `didUpdateWidget()` if used.
6. **`build()`.**
7. All private helper methods, getters, and callbacks, in the order
   they appear inside `build()`.
8. Nested private widget classes (`class _Foo extends ConsumerWidget`)
   live **below** the outer class, never interleaved with its methods.

**Why.** Readers open a widget file to answer one question first:
"what does this screen render?" Surfacing `build()` at the top of the
class makes that question answerable in a scroll, and keeps helpers
in the order they're *called from* `build()` rather than the order a
writer happened to author them. It also matches the canonical page
shown in §6 and every production widget in `foodie_user_mobile_app_interface`.

**Shape:**

```dart
class _FooPageState extends ConsumerState<FooPage> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // ...
    return Scaffold(
      body: Column(
        children: [
          _buildHeader(),
          TextField(controller: _controller, onChanged: _onChanged),
          ElevatedButton(onPressed: _onSubmit, child: const Text('Go')),
        ],
      ),
    );
  }

  Widget _buildHeader() { /* ... */ }

  void _onChanged(String value) { /* ... */ }

  Future<void> _onSubmit() async { /* ... */ }
}
```

`dart format` does not enforce this, so it is a **review-time rule**:
any PR that lands a helper method above `build()` in a widget class
gets sent back for a reorder.

---

## 4. Entry Points & Flavors

Two flavors: `prod` and `stage`, modelled by
`lib/modules/commons/config/flavor.dart`:

```dart
enum Flavor { prod, stage }

extension FlavorName on Flavor {
  String get name => toString().split('.').last;
}
```

Each flavor has its own `main_*.dart`:

```dart
// lib/main_prod.dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load();                         // flutter_dotenv (add it back to pubspec when needed)
  await setupServiceLocator(Flavor.prod);
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  App.run();
}
```

`App.run()` wraps `App` in a `ProviderScope`:

```dart
class App extends ConsumerStatefulWidget {
  static void run() => runApp(const ProviderScope(child: App()));
}
```

Inside `AppState.initState()` (see §8):
1. Construct `AppRouter` with `onboardingGuardProvider` + `GlobalKey<NavigatorState>` from `locator`.
2. Register the router and its `RouterPort` adapter in `locator`.
3. Kick off `RemoteConfigHelper.init()`.

`build()` tree is (top → bottom):

```
ScreenUtilInit(designSize: Size(390, 844), minTextAdapt, ensureScreenSize)
  └── AppTheme(child: …)                         // from kalabash theme barrel
      └── DevicePreview(enabled: kDebugMode)
          └── RemoteConfigObserver
              └── AppOverLay
                  └── MaterialApp.router(
                        theme: AppTheme.light,
                        darkTheme: AppTheme.dark,
                        themeMode: ThemeMode.system,
                        localizationsDelegates: AppLocalizations.localizationsDelegates,
                        supportedLocales: AppLocalizations.supportedLocales,
                        routerDelegate: _appRouter.delegate(),
                        routeInformationParser: _appRouter.defaultRouteParser(),
                        title: locator.get<Config>().title,
                      )
```

**Design size = 390 × 844** (iPhone 14 baseline), matching the HTML
prototype's `.phone-shell` dimensions. Text uses `.spMin` from
`flutter_screenutil` (already the convention in `app_text_styles.dart`).

---

## 5. The `commons/` Package

### 5.1 `all.dart` barrel

```dart
// lib/modules/commons/all.dart
export 'config/config.dart';
export 'config/flavor.dart';
export 'di/di.dart';
export 'methods/methods.dart';
export 'navigation/app_navigation.dart';
export 'navigation/app_router.dart';
export 'navigation/app_router_adapter.dart';
export 'navigation/guards/onboarding_guard.dart';
export 'navigation/router_port.dart';
export 'theme/theme.dart';                  // re-export design-system
export 'utils/utils.dart';
export 'widgets/buttons/button.dart';
export 'widgets/flavor_banner.dart';
export 'widgets/kalabash_safe_area.dart';
```

Any file that needs commons writes a single import:

```dart
import 'package:kalabash_mobile_v2/modules/commons/all.dart';
```

### 5.2 `config/`

```dart
// lib/modules/commons/config/config.dart
class Config {
  final Flavor flavor;
  Config(this.flavor);
  String get name => flavor.name;
  String get title => switch (flavor) {
        Flavor.prod  => 'Kalabash',
        Flavor.stage => 'Kalabash Stage',
      };
  String get baseUrl => switch (flavor) {
        Flavor.prod  => dotenv.env['PROD_BASE_URL']!,
        Flavor.stage => dotenv.env['STAGE_BASE_URL']!,
      };
  String get defaultLang => 'en';
}
```

### 5.3 `di/` (service locator)

Single function `setupServiceLocator(Flavor)` registers *everything*
infrastructural, ordered from least-to-most dependent. Template pulled
directly from foodie's `di.dart`:

```dart
final locator = GetIt.instance;

Future<void> setupServiceLocator(Flavor flavor) async {
  // 1. Config & global keys
  locator.registerSingleton<Config>(Config(flavor));
  locator.registerSingleton(GlobalKey<ScaffoldMessengerState>());
  locator.registerSingleton(GlobalKey<NavigatorState>());
  locator.registerSingleton(NavigationService(locator.get<GlobalKey<NavigatorState>>()));

  // 2. Infra
  locator.registerSingleton(Logger());
  locator.registerSingleton(KalabashAlert(locator.get<NavigationService>()));
  locator.registerSingleton(HapticFeedBackHelper());
  locator.registerSingleton(HttpHelper(locator.get<Logger>()));
  locator.registerSingleton(KalabashAppNotification(locator.get<KalabashAlert>()));
  locator.registerSingleton(ApiHelper(locator.get<KalabashAppNotification>()));

  // 3. Backend client (wraps dio from openapi package)
  locator.registerSingleton(BackendClient(basePathOverride: locator.get<Config>().baseUrl));

  // 4. Remote config (lazy)
  locator.registerLazySingleton<RemoteConfigHelper>(
    () => RemoteConfigHelper(FirebaseRemoteConfig.instance, locator.get<Logger>()),
  );

  // 5. Generated API classes
  locator.registerSingleton<AuthenticationApi>(
    AuthenticationApi(locator.get<BackendClient>().dio, locator.get<BackendClient>().serializers),
  );

  // 6. Feature services + use cases — one block per feature
  _registerSignUp();
  _registerLogin();
  // …
}
```

> **Rule.** New use cases and services go behind private `_registerXxx()`
> helpers in the same file, keeping `setupServiceLocator` readable.

### 5.4 `navigation/`

Four files that must exist from day one:

| File                         | Role                                                                        |
| ---------------------------- | --------------------------------------------------------------------------- |
| `app_router.dart`            | `@AutoRouterConfig(replaceInRouteName: 'Page,Route')` + routes              |
| `app_router.gr.dart`         | `part 'app_router.gr.dart';` — generated; never edit by hand                |
| `router_port.dart`           | Abstract interface (`push/replace/popAndPush/replaceAll/maybePop/popUntil`) |
| `app_router_adapter.dart`    | Concrete `AppRouterAdapter` implementing `RouterPort` against `AppRouter`   |
| `app_navigation.dart`        | Static façade used by screens: `AppNavigation.push(SomeRoute())`            |
| `guards/onboarding_guard.dart` | `AutoRouteGuard` + `onboardingGuardProvider` (Riverpod)                    |
| `services/navigation_service.dart` | Wraps `GlobalKey<NavigatorState>` to expose `getCurrentContext()`     |

Skeleton of `app_router.dart`:

```dart
@AutoRouterConfig(replaceInRouteName: 'Page,Route')
class AppRouter extends RootStackRouter {
  AppRouter(this.onboardingSeenGuard, [GlobalKey<NavigatorState>? navigatorKey])
      : super(navigatorKey: navigatorKey);

  final OnboardingGuard onboardingSeenGuard;

  @override
  RouteType get defaultRouteType =>
      RouteType.custom(customRouteBuilder: _customRouteBuilder);

  @override
  late final List<AutoRoute> routes = [
    AutoRoute(page: SplashRoute.page, initial: true),
    AutoRoute(page: OnboardingRoute.page, guards: [onboardingSeenGuard]),
    AutoRoute(page: PhoneRoute.page),
    // … all Kalabash screens
    AutoRoute(
      page: DashRoute.page,                 // bottom-tab shell
      children: [
        AutoRoute(page: HomeDashRoute.page, initial: true),
        AutoRoute(page: CardsDashRoute.page),
        AutoRoute(page: TravelDashRoute.page),
        AutoRoute(page: RewardsDashRoute.page),
        AutoRoute(page: MoreDashRoute.page),
      ],
    ),
  ];
}

Route<T> _customRouteBuilder<T>(
  BuildContext context,
  Widget child,
  AutoRoutePage<T> page,
) =>
    PageRouteBuilder(
      fullscreenDialog: page.fullscreenDialog,
      settings: page,
      transitionsBuilder: TransitionsBuilders.slideLeftWithFade,
      pageBuilder: (context, __, ___) => FlavorBanner(
        show: kDebugMode || kProfileMode,
        child: child,
      ),
    );
```

`AppNavigation` façade (identical shape to foodie):

```dart
class AppNavigation {
  AppNavigation._();
  static Future<void> push(PageRouteInfo r)       => locator.get<RouterPort>().push(r);
  static Future<void> pop()                       => locator.get<RouterPort>().maybePop();
  static void popUntil(String name)               => locator.get<RouterPort>().popUntilRouteWithName(name);
  static Future<void> replace(PageRouteInfo r)    => locator.get<RouterPort>().replace(r);
  static Future<void> replaceAll(List<PageRouteInfo> rs) => locator.get<RouterPort>().replaceAll(rs);
  static Future<void> popAndPush(PageRouteInfo r) => locator.get<RouterPort>().popAndPush(r);
}
```

### 5.5 `theme/` (already in place)

The following tokens are already generated 1:1 from
`kalabash-design-system_Ebube.html` and must be treated as the **only**
source of truth for styling:

* `AppColors` — 67 static `Color` fields.
* `AppTextStyles` — 73 static `TextStyle` fields (fontFamily = `'DM Sans'`).
* `AppDimensions` — 121 spacing / size / radius fields.
* `AppRadius` — `BorderRadius` presets.
* `AppShadows` — `List<BoxShadow>` presets.
* `AppGradients` — `LinearGradient` / `RadialGradient` presets.
* `AppDurations` — `Duration` + `Curve` motion tokens.
* `AppTheme` — `light` / `dark` `ThemeData` + `SystemUiOverlayStyle` wrapper;
  also exports `kPillShape`, `kScreenPadding`, `kCardPadding`.

> **DM Sans.** `app_text_styles.dart` uses the string `'DM Sans'` for
> `fontFamily`. Before the first screen is rendered, add DM Sans either as
> a bundled font under `pubspec.yaml → flutter.fonts` **or** swap the
> `fontFamily` to `google_fonts`. Do *not* hardcode `Roboto`.

#### 5.5.1 Dark / Light Mode (theme switching)

The HTML prototype applies its entire dark palette via a single
`.dark-mode` class on `<body>`. Toggling that class from the settings
screen is what powers the app's theme switch. Flutter's equivalent is
`MaterialApp.themeMode` — which `app.dart` now watches through the
Riverpod provider `themeModeProvider`.

**Architectural pieces**

| File                                                                         | Role                                                                                   |
| ---------------------------------------------------------------------------- | -------------------------------------------------------------------------------------- |
| `modules/commons/theme/logic/theme_mode_controller.dart`                     | `StateNotifier<ThemeMode>` + `themeModeProvider`; persists to `SharedPreferences`.     |
| `modules/commons/di/di.dart`                                                 | Registers `SharedPreferences` as a `get_it` singleton before any controller needs it.  |
| `app.dart`                                                                   | Watches `themeModeProvider` and passes `theme: AppTheme.light`, `darkTheme: AppTheme.dark`, `themeMode: <watched>` into `MaterialApp.router`. |
| `modules/commons/theme/app_theme.dart`                                       | Already exposes `light` and `dark` `ThemeData` factories; do **not** duplicate them.   |

**Reading and writing the mode**

```dart
// Read (UI that reacts to the mode):
final mode = ref.watch(themeModeProvider);

// Write (settings screen):
ref.read(themeModeProvider.notifier).setMode(ThemeMode.dark);

// Toggle (dark-mode switch in settings):
ref.read(themeModeProvider.notifier).toggle(
  osBrightness: MediaQuery.platformBrightnessOf(context),
);

// Reset to follow the OS:
ref.read(themeModeProvider.notifier).followSystem();
```

**Authoring rule — which tokens flip, which don't**

When migrating a screen, classify every colour in the HTML into one of
two buckets:

1. **Surface-like** — things the `.dark-mode` CSS overrides. These
   **must** resolve via `Theme.of(context)` so the widget flips
   automatically when the provider changes.
2. **Brand-constant** — things the `.dark-mode` CSS does **not** touch
   (brand blues, primary-button fill, badge foregrounds, splash
   gradient, logo tints). These stay as raw `AppColors.*` constants.

Reference mapping for the recurring surface-like tokens (derived from
the `.dark-mode .screen …` override block starting at line 2205 of the
HTML):

| HTML light                | HTML dark                     | Flutter (theme-aware)                                 |
| ------------------------- | ----------------------------- | ----------------------------------------------------- |
| `background:#fff`         | `background:#010E1F`          | `Theme.of(context).scaffoldBackgroundColor`           |
| `background:#F5F6FA`      | `background:#0A1929`          | `Theme.of(context).colorScheme.surface` (card bg)     |
| `background:#F3F4F6`      | `background:#0D2140`          | `isDark ? AppColors.dmInputBg : AppColors.inputBg`    |
| `color:#0D1B2A`           | `color:#fff`                  | `Theme.of(context).colorScheme.onSurface`             |
| `color:#6B7280`/`#9CA3AF` | `color:rgba(255,255,255,.45)` | `isDark ? AppColors.dmTextSecondary : AppColors.textSecondary` |
| `border:… #E5E7EB`        | `border:… #1A3050`            | `Theme.of(context).dividerColor`                      |
| status-bar `.dark`        | status-bar `.light`           | `SystemUiOverlayStyle` chosen from `Theme.of(context).brightness` |

`isDark` is shorthand for
`Theme.of(context).brightness == Brightness.dark` — read it **once** at
the top of a `build` method and reuse.

**Brand-constant tokens — still fine as `AppColors.*`**

`AppColors.primary`, `AppColors.accent`, `AppColors.yellow`,
`AppColors.red`, `AppColors.green`, `AppColors.purple`,
`AppColors.purpleLight`, `AppColors.bgDark` (always-dark surfaces like
wallet cards), `AppColors.white` (on coloured gradients), every badge
foreground, every promo-overlay colour, `AppColors.splashRadialEnd` and
the `AppGradients.*` presets.

**Per-screen `SystemUiOverlayStyle`**

For screens whose background flips with the theme, the status-bar
chrome must flip too. Use `AnnotatedRegion` and pick the overlay from
brightness:

```dart
return AnnotatedRegion<SystemUiOverlayStyle>(
  value: Theme.of(context).brightness == Brightness.dark
      ? AppTheme.darkSystemOverlay
      : AppTheme.lightSystemOverlay,
  child: Scaffold(
    // Omit `backgroundColor:` — defaults to `scaffoldBackgroundColor`.
    body: ...,
  ),
);
```

For screens whose background is constant (splash, onboarding
illustration area, any gradient hero), pick the overlay once and
document *why* it's constant with a comment, as
`splash_page.dart` does.

**Migration checklist (add to §15 "Definition of Done")**

Before marking a screen done, confirm:

- [ ] `Scaffold.backgroundColor` is omitted **or** resolves via
  `Theme.of(context).scaffoldBackgroundColor`.
- [ ] Every primary-text `Text` uses
  `Theme.of(context).colorScheme.onSurface` (or a `TextStyle` resolved
  through `Theme.of(context).textTheme`).
- [ ] Every secondary-text `Text` uses the
  `isDark ? AppColors.dmTextSecondary : AppColors.textSecondary` pair.
- [ ] Every `BorderSide` / `Divider` / inactive-indicator resolves via
  `Theme.of(context).dividerColor`.
- [ ] Every card / bottom-sheet surface uses
  `Theme.of(context).colorScheme.surface` (or an explicit
  `isDark ? dmCardBg : cardBg` pair if finer control is required).
- [ ] `SystemUiOverlayStyle` is chosen via `AnnotatedRegion` per
  brightness — unless the screen's background is constant, in which
  case add a comment explaining why.
- [ ] The screen was manually tested with the settings toggle flipped
  both ways and with the OS in both dark and light mode (system
  default).

**Anti-patterns — do not do this**

- `Scaffold(backgroundColor: AppColors.bgLight, …)` — hard-codes light
  mode. Omit the property.
- `Text(style: TextStyle(color: AppColors.textPrimary))` — hard-codes
  light-mode copy. Use `colorScheme.onSurface`.
- `Border.all(color: AppColors.borderDefault)` — hard-codes light-mode
  border. Use `theme.dividerColor`.
- Reading the theme with `Theme.of(context).brightness` **before**
  wrapping the screen in `AnnotatedRegion` (the overlay still reflects
  the previous brightness in that case; always compute it inside the
  builder).

### 5.6 `core/features/`

`core/` is a tiny module for app-wide cross-feature functionality (i.e.
features that do not belong to authentication, dash, savings, etc.). Today
it contains exactly one: **remote_config**.

```
commons/core/features/remote_config/
├── data/
│   ├── enums/
│   │   └── remote_config_key.dart            // enum of all keys used in FirebaseRemoteConfig
│   └── remote_config_helper.dart             // wraps FirebaseRemoteConfig
├── domain/                                   // (currently empty — add only if required)
└── presentation/
    ├── logic/
    │   ├── remote_config_controller.dart     // StateNotifier exposing flags
    │   └── remote_config_controller.freezed.dart
    └── ui/
        └── remote_config_observer.dart       // ConsumerWidget that hot-reloads config
```

Follow the same shape for any future cross-feature (e.g. `analytics`,
`feature_flags`, `offline_banner`).

### 5.7 `domain/`, `enums/`, `extensions/`, `methods/`

* `commons/domain/entities/user/user.dart` — shared `User` freezed model
  (id, name, email, phone, phoneVerified, emailVerified, userType).
* `commons/enums/overlay_enums.dart` — app-wide overlay enums.
* `commons/extensions/` — `context.dart` (l10n, mediaQuery), `list.dart`
  (null-safe `firstOrNull`), `string.dart` (trim/mask/obfuscate helpers).
* `commons/methods/methods.dart` — small pure-function helpers that don't
  warrant their own file.

### 5.8 `helpers/`

These are **singletons registered in DI** (never constructed directly in
widgets):

| Helper                       | Responsibility                                                   |
| ---------------------------- | ---------------------------------------------------------------- |
| `HttpHelper`                 | `handleApiCall<T,R>({apiCall, mapper, defaultErrorMessage})` → `(T?, String?)`; `handleBoolApiCall<R>({apiCall})` → `bool` |
| `ApiHelper`                  | `handleResponse(success, errorMessage, onSuccess, [onError])` — triggers app-notification on failure |
| `HapticFeedBackHelper`       | `lightImpact()`, `heavyImpact()` — called from `Button._handlePressed` |
| `KalabashAlert`              | Shows bottom-sheet dialogs via navigator-key context              |
| `KalabashAppNotification`    | Wraps `KalabashAlert` for `error()`, `success()`, `info()` toasts |
| `AppGestureDetector`         | Custom GestureDetector that pairs with HapticFeedBackHelper       |

### 5.9 `utils/`

* `api_call_status.dart` — sealed class `ApiCallStatus` with `Success<T>` and `Error` variants.
* `app_logger.dart` — `appLogger(message, {longMessage=false})` using `dart:developer`.
* `country_code_utils.dart` — `CountryCodeUtils.countryCodeToEmoji(String isoCode)`; converts an ISO-3166 alpha-2 code to its flag emoji via Unicode regional-indicator offsets.
* `utils.dart` — MediaQuery shortcuts.
* `interceptors/backend_client.dart` — extends `KalabashBackend` (from local `packages/openapi`) with `basePathOverride`.

#### 5.9.1 Flag rendering rule — always use `CountryCodeUtils`

Every country flag rendered anywhere in the app **must** come from
`CountryCodeUtils.countryCodeToEmoji(isoCode)` (or the `CountryFlag`
widget at
`lib/modules/authentication/features/sign_up/presentation/ui/widgets/country_flag.dart`,
which wraps it). Flags are emoji glyphs — not network images, not asset
PNGs, not SVGs. This keeps rendering offline-safe, theme-agnostic, and
pixel-consistent with the HTML prototype's native emoji flags.

**Do:**

```dart
Text(
  CountryCodeUtils.countryCodeToEmoji('NG'), // → 🇳🇬
  style: TextStyle(fontSize: 22.spMin),
);
```

Or, when you already have a `SignUpCountry` enum value:

```dart
CountryFlag(country: SignUpCountry.nigeria, size: 20);
```

**Don't:**

* `Image.network('https://flagcdn.com/w40/ng.png')` — no third-party CDNs.
* `Image.asset('assets/flags/ng.png')` — no PNG/SVG sprite sheets.
* Hand-rolled emoji lookup maps in feature folders.

**Input contract.** `countryCodeToEmoji` expects an **uppercase** ISO-3166
alpha-2 code (`'NG'`, `'GB'`, `'US'`). If your sample data or API returns
lowercase codes, uppercase them at the call site:

```dart
CountryCodeUtils.countryCodeToEmoji(
  (destination.countryCode ?? 'UN').toUpperCase(),
);
```

**When migrating a new screen.** If the HTML uses
`<img src="https://flagcdn.com/...">`, a native emoji (🇳🇬), or a CSS
`background-image` for a flag, translate it to
`CountryCodeUtils.countryCodeToEmoji(...)`. This applies to every
module — authentication country pickers, stays destination pickers,
travel-data destination pickers, phone-prefix sheets, anywhere a flag
renders.

### 5.10 `widgets/` (shared UI)

Widgets that appear on ≥ 2 features live here, not in a feature folder.
At minimum, seed the folder with:

| Widget                      | Equivalent HTML primitive                  |
| --------------------------- | ------------------------------------------ |
| `KalabashSafeArea`          | `.phone-shell` padding                     |
| `AppOverLay`                | Loading & modal scrim                      |
| `FlavorBanner`              | Debug flag banner                          |
| `KalabashAlert`             | `.toast`, `.center-dialog`                 |
| `buttons/button.dart`       | `.btn-primary`, `.btn-secondary`, `.btn-ghost` (factories: `.fullWidth`, `.shortWidth`, `.secondary`, `.ghost`, `.icon`) |
| `buttons/nav_button.dart`   | Bottom-tab item                            |
| `inputs/kalabash_input.dart`     | `.input-field` (single-line, multi-line, password — `KalabashInput` + `KalabashInput.withValidation` factory). The one-and-only textfield used across the app. |
| `inputs/kalabash_dropdown.dart`  | `.select-field` (matches the v2 HTML chip + chevron). |
| `inputs/phone_number_input.dart` | `.phone-input` + country prefix. **Keep as-is** — phone-number entry has bespoke formatting that doesn't fit the `KalabashInput` surface. |
| `inputs/pin_input.dart`     | 4/5/6-digit OTP & wallet-pin boxes         |
| `bordered_container.dart`   | `.social-btn`, `.bordered-box`             |
| `section_heading.dart`      | `.section-heading`                         |
| `display_chip.dart`         | `.chip`, `.filter-pill`                    |
| `shadowed_card.dart`        | `.card` + `AppShadows.centerDialog`        |

**Button contract** (from foodie, verbatim):

```dart
Button({
  required String text,
  required Future<void> Function()? onPressed,
  Color buttonColor = AppColors.primary,
  Color textColor = AppColors.white,
  Color? borderColor,
  double borderRadius = 37,
  bool disabled = false,
  bool showLoadingIndicator = true,
  bool stopLoadingAfterOnPressed = true,
  double horizontalPadding = 16,
  double height = 48,
  IconData? icon,
  bool loading = false,
  double? width,
});

factory Button.fullWidth(...)    // width = double.infinity
factory Button.shortWidth(...)   // default width = 100
factory Button.secondary(...)    // white bg, primary border
```

The widget itself (a) dispatches `HapticFeedBackHelper.heavyImpact()`,
(b) shows an inline `CircularProgressIndicator` for async `onPressed`,
and (c) toggles loading on `mounted` guard. Copy semantics precisely.

### 5.10.1 Input & Validation — the one textfield rule

Every textfield in v2 is a `KalabashInput`
(`lib/modules/commons/widgets/inputs/kalabash_input.dart`). Do not build a
bespoke textfield inside a feature folder; do not revive the old
`LabeledTextField` / `LabeledDropdownField` pair. The only exception is the
phone-number entry, which keeps its bespoke `PhoneNumberInput` because the
country-prefix + formatter surface doesn't fit the generic input.

`KalabashInput` has two call-sites, mirroring the v1 `Kalabash_Mobile_App`
`Input` / foodie `Input` pattern:

| Constructor                    | Use for                                                  |
| ------------------------------ | -------------------------------------------------------- |
| `KalabashInput(...)`           | Optional fields (e.g. referral code) and inputs that live outside a `Form`. No validator is wired. |
| `KalabashInput.withValidation(...)` | **Every non-optional field.** Requires a `validator`. Fires with `AutovalidateMode.onUserInteraction` so the inline red-border + error message appear the moment the user blurs or mutates the field. |

Validators live in `UserValidatorMixin`
(`lib/modules/authentication/controllers/mixins/user_validator_mixin.dart`),
ported verbatim from the v1 `Kalabash_Mobile_App`:

| Method                                               | Backing predicate (on `String`)              |
| ---------------------------------------------------- | -------------------------------------------- |
| `validateEmail(String?)`                             | `String.isValidEmail()`                      |
| `validateFullName(String?)`                          | `String.isValidFullName()`                   |
| `validatePassword(String?)`                          | `String.isValidPassword()`                   |
| `validateConfirmPassword(String?, String)`           | `String.isValidConfirmPassword(String)`      |
| `validatePhoneNumber(String?, SignUpCountry)`        | `String.isValidPhoneNumberFor(SignUpCountry)` |

Each returns `null` when valid, or a `LocalizedError` that resolves to the
correct l10n string. The regex/predicates live alongside the extensions in
`lib/modules/commons/extensions/string.dart`.

**The rule — always validate when validation is needed:**

1. Any non-optional textfield **must** be wired through
   `KalabashInput.withValidation(validator: ...)`. Never silently accept
   user input into a field that the app later relies on.
2. The validator passed to the widget **must** be the same pure function
   the controller uses when deriving `isValid` — so the inline error and
   the submit-gate cannot disagree. The canonical source is a method on a
   class mixing in `UserValidatorMixin`, or a `String` extension in
   `commons/extensions/string.dart`.
3. The **submit button beneath the form must stay disabled** (`disabled:
   !state.continueEnabled`) until every non-optional field's validator
   returns `null`. The screen does not need to call `Form.of(context).validate()`;
   gating the button from the controller's `isValid` is both necessary and
   sufficient.
4. Optional fields use the plain `KalabashInput` and are excluded from the
   `isValid` derivation.
5. `AutovalidateMode.onUserInteraction` is the v2 default and must not be
   overridden to `AutovalidateMode.disabled` — the prototype shows error
   state as soon as the user has touched the field, and the Flutter app
   must match.

**Canonical wiring** (see `account_setup_page.dart` for the live copy):

```dart
// Controller (mixes in UserValidatorMixin).
String? emailValidator(String? value, AppLocalizations l) =>
    validateEmail(value)?.getMessage(l);

// State (validity derived from the same string-extension predicate).
bool get emailValid => email.isValidEmail();
bool get continueEnabled => emailValid && passwordValid && !isSubmitting;

// Page.
KalabashInput.withValidation(
  label: l10n.accountSetupEmailLabel,
  controller: _emailController,
  hintText: l10n.accountSetupEmailHint,
  keyboardType: TextInputType.emailAddress,
  onChanged: controller.onEmailChanged,
  validator: (value) => controller.emailValidator(value, l10n),
);

Button.fullWidth(
  label: l10n.accountSetupContinueCta,
  onPressed: state.isSubmitting ? null : _onContinue,
  disabled: !state.continueEnabled,
);
```

---

### 5.10.2 Escape hatch — bespoke inputs still need a validator contract

`KalabashInput.withValidation` is the default. When a field is so heavily
customised that it cannot reasonably be expressed as a `KalabashInput`
(prefix-chip + dial-code + brand dot for the bills phone field, ₦ symbol
+ currency formatter for the bills amount field, meter input with a
right-edge verify badge whose border colour also tracks an async lookup
state, save-as-beneficiary card with an embedded checkbox that conditionally
reveals the input, etc.), you may build a bespoke widget. **You may not
silently drop the validator contract when you do.**

Every bespoke input that is part of a form gating a submit button must:

1. Expose `FormFieldValidator<String>? validator` and
   `AutovalidateMode autovalidateMode = AutovalidateMode.onUserInteraction`
   on its constructor — same names, same defaults as `KalabashInput`.
2. Render the underlying `TextFormField` with `validator: ...` wired
   through. Cache the resolved error string in `setState` via
   `WidgetsBinding.instance.addPostFrameCallback`, then return `null` from
   the framework validator so Flutter does **not** paint its own
   `MaterialBanner`-style error. Render the cached message yourself as a
   small red `Text` directly beneath the field's container, and flip the
   container border to `AppColors.red` while the error is non-null.
3. Listen to the controller in `initState` so the cached error refreshes
   live as the user types, even when the field has not been blurred.
4. The page that owns the form **must** call the same validator function
   from its `_canContinue` getter (or controller `isValid` derivation) so
   the inline message and the submit-button gate cannot drift apart.
   Pattern: define `_validateX(String? value, AppLocalizations l10n)` on
   the page state, pass `(v) => _validateX(v, l10n)` into the widget, and
   read `_validateX(_xCtrl.text, l10n) == null` from `_canContinue`.
5. Page state listens to every controller in `initState` (`addListener`)
   and `setState`s on change, so the Continue button re-evaluates
   `_canContinue` as the user types.
6. All error copy lives in `app_en.arb` under `<module>Error...` keys —
   never hard-code the message inside the widget.

**Reference implementations (bills module):**

| Bespoke widget                                                  | Why a `KalabashInput` doesn't fit                          |
| --------------------------------------------------------------- | ---------------------------------------------------------- |
| `bills/commons/widgets/bills_phone_input.dart`                  | Dial-code chip + brand-coloured network dot in the prefix |
| `bills/commons/widgets/bills_save_bene_card.dart`               | Checkbox toggles whether the inner field exists at all     |
| `bills/features/airtime/.../bills_airtime_page.dart#_AmountInput` | Custom `₦` glyph + `CurrencyInputFormatter` prefix        |
| `bills/features/electricity/.../bills_electricity_page.dart#_MeterInput` | Trailing verify badge + status-tracked border (idle/loading/ok) that must compose with the red error state |

Each of those is a `StatefulWidget` that mirrors the `KalabashInput`
validator-contract above. Copy that pattern; do not invent a new one.

---

## 6. Feature Module Template

Each feature inside a module follows this *exact* tree — derived from
`foodie_user_mobile_app_interface/lib/modules/authentication/features/sign_up/`:

```
<module>/features/<feature>/
└── presentation/
    ├── logic/
    │   ├── controller/
    │   │   ├── <feature>_controller.dart
    │   │   └── <feature>_controller.freezed.dart
    │   ├── data/
    │   │   ├── datasources/
    │   │   │   └── remote_data_source/
    │   │   │       └── <feature>_service.dart            // abstract
    │   │   ├── models/                                   // DTO / response shapes
    │   │   │   ├── <model>.dart
    │   │   │   ├── <model>.freezed.dart
    │   │   │   └── <model>.g.dart
    │   │   └── repositories/
    │   │       └── <feature>_service_impl.dart           // implements *_service.dart
    │   ├── domain/
    │   │   ├── entities/
    │   │   │   └── <entity>/
    │   │   │       ├── <entity>.dart
    │   │   │       ├── <entity>.freezed.dart
    │   │   │       └── <entity>.g.dart
    │   │   └── use_cases/
    │   │       └── <action>_use_case.dart                // single-action use case
    │   └── enums/
    │       ├── <feature>_result.dart                     // sealed result
    │       └── <feature>_step.dart
    └── ui/
        ├── <feature>_page.dart                           // @RoutePage() root screen
        ├── <other_feature_page>.dart                     // additional pages belong to the same feature
        └── widgets/
            ├── <header_or_block>.dart
            └── <component>.dart
```

**Why `presentation/logic/data/` instead of top-level `data/`?** This is
the foodie convention — `data/` and `domain/` are *nested inside*
`presentation/logic/` because a feature's business logic is driven by its
presentation layer. Keep this identical so we can reuse the mental model.

### Canonical controller (excerpt from foodie sign-up, adapt per feature)

```dart
final signUpControllerProvider =
    StateNotifierProvider<SignUpController, SignUpControllerState>(
  (ref) => SignUpController(
    locator.get<CreateUserUseCase>(),
    locator.get<AuthEmailUseCase>(),
    locator.get<ApiHelper>(),
  ),
);

class SignUpController extends StateNotifier<SignUpControllerState> {
  SignUpController(this._createUser, this._authEmail, this._apiHelper,
      {SignUpControllerState? state})
      : super(state ?? SignUpControllerState.withDefaults());

  final CreateUserUseCase _createUser;
  final AuthEmailUseCase  _authEmail;
  final ApiHelper         _apiHelper;

  // State mutators
  void updateSignUpButtonDisabled(bool disabled) =>
      state = state.copyWith(signUpButtonDisabled: disabled);

  // Feature logic
  Future<CreateAccountFlowResult> handleCreateAccount({...}) async { … }
}

@freezed
abstract class SignUpControllerState with _$SignUpControllerState {
  factory SignUpControllerState({
    @Default(true) bool signUpButtonDisabled,
    @Default(true) bool verifyButtonDisabled,
  }) = _SignUpControllerState;

  SignUpControllerState._();
  factory SignUpControllerState.withDefaults() => SignUpControllerState();
}
```

### Canonical use case

```dart
class CreateUserUseCase {
  final SignUpService _service;
  const CreateUserUseCase(this._service);

  Future<(User?, String?)> call({required CreateUserRequest createUserRequest}) =>
      _service.createUser(createUserRequest: createUserRequest);
}
```

### Canonical service + impl

```dart
abstract class SignUpService {
  Future<(User?, String?)> createUser({required CreateUserRequest createUserRequest});
  Future<bool> sendPhoneOtp({required String phone});
  // …
}

class SignUpServiceImpl implements SignUpService {
  SignUpServiceImpl(this._api, this._http, this._logger);
  final AuthenticationApi _api;
  final HttpHelper        _http;
  final Logger            _logger;

  @override
  Future<(User?, String?)> createUser({required CreateUserRequest req}) {
    _logger.i('POST /api/v1/auth/create → $req');
    return _http.handleApiCall(
      apiCall: () => _api.apiV1AuthCreatePost(
        request: DataCreateUserRequest((b) => b
          ..email    = req.email
          ..firstName= req.firstName
          ..lastName = req.lastName
          ..password = req.password
          ..phone    = req.phone
          ..userType = 'kalabash'),
        authorization: 'Bearer ${req.accountCreationToken}',
      ),
      mapper: (r) => User(
        id: r.data?.user?.id ?? '',
        name: r.data?.user?.name ?? '',
        email: r.data?.user?.email ?? '',
        phone: r.data?.user?.phone ?? '',
      ),
    );
  }
}
```

### Canonical page

```dart
@RoutePage()
class SignUpPage extends ConsumerStatefulWidget {
  const SignUpPage({super.key});
  @override
  ConsumerState<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends ConsumerState<SignUpPage> {
  late final SignUpController controller;
  late final TextEditingController phone;

  @override
  void initState() {
    super.initState();
    controller = ref.read(signUpControllerProvider.notifier);
    phone = TextEditingController();
  }

  @override
  void dispose() { phone.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Scaffold(
      backgroundColor: AppColors.bgLight,
      body: KalabashSafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              Text(l.whats_your_number, style: AppTextStyles.screenTitle),
              AppDimensions.spaceCompact.verticalSpace,
              Text(l.welcome_to_kalabash,
                  style: AppTextStyles.bodyRegular.copyWith(color: AppColors.textSecondary)),
              AppDimensions.gap.verticalSpace,
              PhoneNumberInput(textEditingController: phone, key: const Key('phone_input')),
              AppDimensions.gap.verticalSpace,
              Consumer(builder: (_, ref, __) {
                final disabled = ref.watch(signUpControllerProvider).signUpButtonDisabled;
                return Button.fullWidth(
                  key: const Key('continue_cta'),
                  text: l.continue_,
                  disabled: disabled,
                  onPressed: _continue,
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _continue() async {
    final result = await controller.handlePhoneAuth(phone: phone.text);
    switch (result.type) {
      case PhoneVerificationResultType.existingUser:
        await AppNavigation.push(const SignInRoute());
      case PhoneVerificationResultType.newUser:
        await AppNavigation.push(const OtpRoute(fromCreateAccount: true));
      case PhoneVerificationResultType.failureCreatingUser:
        break;
    }
  }
}
```

---

## 7. State Management Rules

1. **Every widget in this project is a Riverpod `Consumer*` widget.**
   Do **not** extend `StatelessWidget` or `StatefulWidget` anywhere — not
   even for private helpers, decorative widgets, or "obviously dumb"
   layout wrappers. The base classes for new widgets are:
   * Stateless → `ConsumerWidget`. Build signature is
     `Widget build(BuildContext context, WidgetRef ref)`.
   * Stateful  → `ConsumerStatefulWidget` paired with
     `ConsumerState<MyWidget>`. Inside the `State` class, `ref` is
     available as a property — the `build` signature stays
     `Widget build(BuildContext context)`.

   Rationale: any widget may gain a provider dependency later (theming
   toggles, feature flags, analytics). Starting from `ConsumerWidget`
   means adding `ref.watch(...)` is a one-line change instead of a type
   refactor that propagates up through every parent.

   Canonical stateless widget:

   ```dart
   import 'package:flutter/material.dart';
   import 'package:flutter_riverpod/flutter_riverpod.dart';

   class MyCard extends ConsumerWidget {
     const MyCard({super.key, required this.title});

     final String title;

     @override
     Widget build(BuildContext context, WidgetRef ref) {
       // ref.watch(...) / ref.read(...) available here.
       return Text(title);
     }
   }
   ```

   Canonical stateful widget:

   ```dart
   import 'package:flutter/material.dart';
   import 'package:flutter_riverpod/flutter_riverpod.dart';

   class MyForm extends ConsumerStatefulWidget {
     const MyForm({super.key});

     @override
     ConsumerState<MyForm> createState() => _MyFormState();
   }

   class _MyFormState extends ConsumerState<MyForm> {
     final _controller = TextEditingController();

     @override
     void dispose() {
       _controller.dispose();
       super.dispose();
     }

     @override
     Widget build(BuildContext context) {
       // `ref` is a property on ConsumerState — no extra argument.
       final flag = ref.watch(someFeatureFlagProvider);
       return TextField(controller: _controller, enabled: flag);
     }
   }
   ```

2. Controllers are always `StateNotifier<SomeState>` where `SomeState` is
   a `@freezed` class with a `withDefaults()` factory.
3. The controller's dependencies are **injected via the
   `locator.get<T>()` calls inside the Riverpod provider** — *not* via
   `ref.read` of another provider. This keeps infrastructure out of the
   Riverpod graph, which is reserved for UI state.
4. Local, transient UI state (a toggle inside a form) uses `setState`
   inside the widget's `ConsumerState`. Anything crossing screens must
   go through a controller.
5. Never call `ref.watch` inside `initState`; use `ref.read` there and
   `ref.watch` inside `build`.
6. Expose *read-only* fields on the controller for non-state data
   (e.g., `verificationType`, `createUserRequest` are instance fields on
   the controller in foodie). State (`@freezed`) is only for things the
   UI rebuilds on.

---

## 8. Navigation Rules

1. All screens are annotated with `@RoutePage()`; they're registered in
   `AppRouter.routes`.
2. Pages call **only** `AppNavigation.push/replace/popAndPush/pop()`.
   Never `context.router.push(...)` directly.
3. Bottom tab navigation = one parent route (`DashRoute`) with `children:`
   (see the foodie `HomeMainRoute` pattern).
4. Modal sheets & dialogs that cover the entire screen (e.g.
   `screen-card-wallet-pin`) may be implemented as full-screen routes with
   `fullscreenDialog: true` OR as `showModalBottomSheet` from a parent
   page — pick per Figma/HTML intent, and be consistent within a feature.
5. Route guards live under `commons/navigation/guards/`. Each guard is a
   `Provider<Guard>` so the root `App` can `ref.read` it when constructing
   `AppRouter`.

---

## 9. Networking & Error Handling Rules

1. `BackendClient` (`commons/utils/interceptors/backend_client.dart`)
   extends the generated OpenAPI client (local `packages/openapi`) and is
   the **single** Dio owner. Everything else reuses its `dio` and
   `serializers`.
2. API groups (e.g. `AuthenticationApi`) are registered as singletons in
   `setupServiceLocator`.
3. Services call the API via `HttpHelper`:
   ```dart
   return _http.handleApiCall(
     apiCall: () => _api.apiV1AuthCreatePost(request: ...),
     mapper:  (r) => User(...),
   );
   ```
4. The service returns `(T?, String?)` — payload or error message — and
   **never throws**. Controllers pipe that through `ApiHelper.handleResponse`
   to show a toast on failure.
5. Boolean-only calls use `_http.handleBoolApiCall`.
5a. **All in-app alerts (success, error, info) go through `KalabashAppNotification`.** Never call `ScaffoldMessenger.of(context).showSnackBar(...)`, `showDialog` with a `SnackBar`, or any hand-rolled toast overlay from migration code. Resolve the notifier from the locator — `locator.get<KalabashAppNotification>().success(message: '…')` / `.error(message: '…')` — and call it from controllers or page callbacks. See §22 for the full rule.
6. Interceptors (auth token injection, refresh, logging) live under
   `commons/utils/interceptors/`. Add them via
   `BackendClient().dio.interceptors.add(...)` inside the DI registration.
7. DTOs are `@freezed` — never hand-roll `toJson` / `fromJson` unless a
   field requires a custom converter.

---

## 10. HTML → Flutter Conversion Recipe

For each `<div class="screen" id="screen-XYZ">…</div>` in
`index.html`, follow these steps **in order**:

1. **Identify module & feature** via the mapping table in §11.
2. **Create folders** if this is the first screen in the feature:
   ```
   lib/modules/<module>/features/<feature>/presentation/ui/
   lib/modules/<module>/features/<feature>/presentation/ui/widgets/
   lib/modules/<module>/features/<feature>/presentation/logic/controller/
   lib/modules/<module>/features/<feature>/presentation/logic/enums/
   ```
   (Add `data/`, `domain/` subtrees only when the screen actually needs
   a backend call.)
3. **Create the page file** `<screen>_page.dart`:
   * Start from the canonical page in §6.
   * Class name = camelcased id minus `screen-` plus `Page`. E.g.
     `screen-create-pin` → `CreatePinPage`.
4. **Layout translation.** Walk the HTML depth-first:
   | HTML                                             | Flutter equivalent                                     |
   | ------------------------------------------------ | ------------------------------------------------------ |
   | `<div class="phone-shell">`                      | `Scaffold` with `KalabashSafeArea` child               |
   | `display:flex; flex-direction:column;`           | `Column`                                               |
   | `display:flex; flex-direction:row;`              | `Row`                                                  |
   | `background: #F5F6FA`                            | `backgroundColor: AppColors.bgLight`                   |
   | `.screen-title`                                  | `Text(…, style: AppTextStyles.screenTitle)`            |
   | `.screen-subtitle`                               | `Text(…, style: AppTextStyles.bodyRegular.copyWith(color: AppColors.textSecondary))` |
   | `.btn-primary`                                   | `Button.fullWidth(...)` (primary)                      |
   | `.btn-ghost` / `.btn-secondary`                  | `Button.secondary(...)`                                |
   | `.input-field`                                   | `Input(...)` from `commons/widgets/inputs/`            |
   | `.card` / rounded box                            | `ShadowedCard(...)` or `Container(decoration: BoxDecoration(borderRadius: AppRadius.card, boxShadow: AppShadows.centerDialog))` |
   | `.gradient-navy`                                 | `Container(decoration: BoxDecoration(gradient: AppGradients.navy))` |
   | Hard-coded px/margin/padding                     | Closest token in `AppDimensions`; **never invent**     |
   | `linear-gradient(135deg, ...)`                   | `AppGradients.navy` / `.purple` / `.bluePurple`        |
   | `@keyframes slideIn`                             | `AnimationController(duration: AppDurations.screenTransition)` + `CurvedAnimation(curve: AppDurations.screenTransitionCurve)` |
   | Toast / snackbar                                 | `locator.get<KalabashAppNotification>().success('…')`  |
   | `<i class="ph ph-foo-bar">`                      | `Icon(PhosphorIcons.fooBar(), size: …, color: …)` (see §1 rule 15) |
   | `<i class="ph-fill ph-foo-bar">`                 | `Icon(PhosphorIcons.fooBar(PhosphorIconsStyle.fill), ...)` |
   | `<i class="ph-bold ph-foo-bar">`                 | `Icon(PhosphorIcons.fooBar(PhosphorIconsStyle.bold), ...)` |
   | Inline `<svg>` / Unicode glyph                   | `SvgPicture.asset(...)` / `Icons.*` primitive — **never** sub in a Phosphor icon |
5. **State.** If the screen has any interactive element:
   * Create a `<feature>_controller.dart` with a freezed state.
   * Read it via `ref.watch(<feature>ControllerProvider)`.
6. **Strings.** Every user-facing string goes into `lib/l10n/app_en.arb`
   with a snake_case key. Screens read via `context.l10n.<key>`.
7. **Assets.** Place PNGs/SVGs under `assets/images/png/`, `assets/images/svg/`
   and reference them via generated `Assets.images.png.xxx` / `.svgGenImage`.
8. **Register the route.** Add `AutoRoute(page: XxxRoute.page)` to
   `app_router.dart`, then run
   `flutter pub run build_runner build --delete-conflicting-outputs`.
9. **Smoke test.** Navigate to the screen via `AppNavigation.push`.
10. **Lint + format.** `dart format .` and `flutter analyze`.

### Do / Don't

| ✅ Do                                                                    | 🚫 Don't                                         |
| ----------------------------------------------------------------------- | ------------------------------------------------ |
| Reuse `Button`, `Input`, `PinInput`, `KalabashSafeArea`                 | Build bespoke buttons per screen                 |
| Use `.verticalSpace` / `.horizontalSpace` on `AppDimensions` int values | Use `SizedBox(height: 12)` ad-hoc                |
| Use `AppColors.primary`, `AppColors.accent`                             | Paste `Color(0xFF1B3F7F)` anywhere               |
| Use `AppTextStyles.screenTitle.copyWith(color: …)`                      | `TextStyle(fontSize: 24, fontWeight: w700)` raw  |
| Use `context.l10n.foo`                                                  | Hard-code UI strings                             |
| Route via `AppNavigation.push(XxxRoute())`                              | `Navigator.push(MaterialPageRoute(...))`         |
| Inject services via `locator.get<T>()` inside Riverpod provider         | Construct `Dio()` or `FirebaseRemoteConfig.instance` inside a widget |

---

## 11. Module Map: HTML Screens → Feature Modules

All 123 screens from `/Users/ebube.okocha/Downloads/Kalabash mobile 2/index.html`
map as follows.

### authentication

| HTML screen id        | Feature folder                    | Flutter page class             |
| --------------------- | --------------------------------- | ------------------------------ |
| `screen-splash`       | `authentication/splash`           | `SplashPage`                   |
| `screen-onboarding`   | `authentication/onboarding`       | `OnboardingPage`               |
| `screen-phone`        | `authentication/sign_up`          | `PhonePage`                    |
| `screen-otp`          | `authentication/sign_up`          | `OtpPage`                      |
| `screen-account-setup`| `authentication/sign_up`          | `AccountSetupPage`             |
| `screen-email-otp`    | `authentication/sign_up`          | `EmailOtpPage`                 |
| `screen-signin`       | `authentication/login`            | `SignInPage`                   |
| `screen-forgot-otp`   | `authentication/forgot_password`  | `ForgotOtpPage`                |
| `screen-new-password` | `authentication/forgot_password`  | `NewPasswordPage`              |
| `screen-create-pin`   | `authentication/wallet_pin`       | `CreatePinPage`                |
| `screen-confirm-pin`  | `authentication/wallet_pin`       | `ConfirmPinPage`               |
| `screen-wallet-intro` | `authentication/wallet_pin`       | `WalletIntroPage`              |

### kyc

| `screen-bvn`           | `kyc/bvn`                         | `BvnPage`                      |
| `screen-kyc-welcome`   | `kyc/kyc_welcome`                 | `KycWelcomePage`               |
| `screen-address`       | `kyc/address`                     | `AddressPage`                  |
| `screen-nin`           | `kyc/nin`                         | `NinPage`                      |
| `screen-proof-address` | `kyc/proof_of_address`            | `ProofOfAddressPage`           |
| `screen-camera`        | `kyc/proof_of_address`            | `CameraPage`                   |
| `screen-photo-review`  | `kyc/proof_of_address`            | `PhotoReviewPage`              |
| `screen-liveliness`    | `kyc/liveness`                    | `LivenessPage`                 |
| `screen-liveness-cam`  | `kyc/liveness`                    | `LivenessCamPage`              |

### dash

| `screen-home`           | `dash/home`                      | `HomeDashPage` (empty state)    |
| `screen-home-funded`    | `dash/home`                      | `HomeFundedDashPage`            |
| `screen-guest-home`     | `dash/home`                      | `GuestHomePage`                 |
| `screen-notifications`  | `dash/notifications`             | `NotificationsPage`             |
| `screen-all-transactions` | `dash/notifications`           | `AllTransactionsPage`           |
| `screen-more`           | `dash/more`                      | `MorePage`                      |
| `screen-settings`       | `dash/more`                      | `SettingsPage`                  |
| `screen-ai-agent`       | `dash/more`                      | `AiAgentPage`                   |

### savings (Save-to-Travel)

| `screen-stt-explore`      | `savings/explore`                   | `SttExplorePage`             |
| `screen-stt-plans-empty`  | `savings/plans`                     | `SttPlansEmptyPage`          |
| `screen-stt-plans`        | `savings/plans`                     | `SttPlansPage`               |
| `screen-flex-intro`       | `savings/flexible`                  | `FlexIntroPage`              |
| `screen-flex-step1`       | `savings/flexible`                  | `FlexStep1Page`              |
| `screen-flex-step2`       | `savings/flexible`                  | `FlexStep2Page`              |
| `screen-flex-step3`       | `savings/flexible`                  | `FlexStep3Page`              |
| `screen-flex-detail`      | `savings/flexible`                  | `FlexDetailPage`             |
| `screen-locked-intro`     | `savings/locked`                    | `LockedIntroPage`             |
| `screen-locked-detail`    | `savings/locked`                    | `LockedDetailPage`            |
| `screen-curated-detail`   | `savings/curated`                   | `CuratedDetailPage`           |
| `screen-curated-deposit`  | `savings/curated`                   | `CuratedDepositPage`          |
| `screen-deposit`          | `savings/transactions`              | `DepositPage`                 |
| `screen-withdraw`         | `savings/transactions`              | `WithdrawPage`                |
| `screen-history-empty`    | `savings/transactions`              | `HistoryEmptyPage`            |
| `screen-history-data`     | `savings/transactions`              | `HistoryDataPage`             |

### cards

| `screen-cards`                   | `cards/dashboard`              | `CardsPage`                  |
| `screen-card-dashboard`          | `cards/dashboard`              | `CardDashboardPage`          |
| `screen-card-transactions`       | `cards/transactions`           | `CardTransactionsPage`       |
| `screen-card-txn-detail`         | `cards/transactions`           | `CardTxnDetailPage`          |
| `screen-card-txn-netflix`        | `cards/transactions`           | `CardTxnNetflixPage`         |
| `screen-card-physical-detail`    | `cards/physical`               | `CardPhysicalDetailPage`     |
| `screen-card-pickup-select`      | `cards/delivery`               | `CardPickupSelectPage`       |
| `screen-card-pickup-delivery`    | `cards/delivery`               | `CardPickupDeliveryPage`     |
| `screen-card-home-delivery`      | `cards/delivery`               | `CardHomeDeliveryPage`       |
| `screen-card-delivery-method`    | `cards/delivery`               | `CardDeliveryMethodPage`     |
| `screen-card-virtual-detail`     | `cards/virtual`                | `CardVirtualDetailPage`      |
| `screen-card-virtual-order`      | `cards/virtual`                | `CardVirtualOrderPage`       |
| `screen-card-wallet-pin`         | `wallet/pin`                   | `CardWalletPinSheet`         |
| `screen-card-request-success`    | `cards/delivery`               | `CardRequestSuccessPage`     |
| `screen-card-deals`              | `cards/deals`                  | `CardDealsPage`              |
| `screen-fund-card`               | `wallet/fund`                  | `FundCardPage`               |
| `screen-fund-card-pin`           | `wallet/fund`                  | `FundCardPinPage`            |
| `screen-idtp-info`               | `wallet/idtp`                  | `IdtpInfoPage`               |
| `screen-idtp-choose-card`        | `wallet/idtp`                  | `IdtpChooseCardPage`         |
| `screen-idtp-tnc`                | `wallet/idtp`                  | `IdtpTncPage`                |
| `screen-idtp-payment`            | `wallet/idtp`                  | `IdtpPaymentPage`             |
| `screen-idtp-success`            | `wallet/idtp`                  | `IdtpSuccessPage`            |
| `screen-idtp-manage`             | `wallet/idtp`                  | `IdtpManagePage`             |

### dash/travel (Flights / Stays / Things-to-do)

| `screen-flight`                 | `dash/travel/flight`         | `FlightPage`                  |
| `screen-flight-results`         | `dash/travel/flight`         | `FlightResultsPage`           |
| `screen-flight-passenger`       | `dash/travel/flight`         | `FlightPassengerPage`         |
| `screen-flight-pss`             | `dash/travel/flight`         | `FlightPssPage`               |
| `screen-flight-pss-pin`         | `dash/travel/flight`         | `FlightPssPinPage`            |
| `screen-flight-full-pin`        | `dash/travel/flight`         | `FlightFullPinPage`           |
| `screen-flight-success`         | `dash/travel/flight`         | `FlightSuccessPage`           |
| `screen-stays`                  | `dash/travel/stays`          | `StaysPage`                   |
| `screen-stays-results`          | `dash/travel/stays`          | `StaysResultsPage`            |
| `screen-stays-detail`           | `dash/travel/stays`          | `StaysDetailPage`             |
| `screen-stays-info`             | `dash/travel/stays`          | `StaysInfoPage`               |
| `screen-stays-pss`              | `dash/travel/stays`          | `StaysPssPage`                |
| `screen-stays-full-pin`         | `dash/travel/stays`          | `StaysFullPinPage`            |
| `screen-stays-pss-pin`          | `dash/travel/stays`          | `StaysPssPinPage`             |
| `screen-stays-success`          | `dash/travel/stays`          | `StaysSuccessPage`            |
| `screen-things`                 | `dash/travel/things_to_do`   | `ThingsPage`                  |
| `screen-things-detail`          | `dash/travel/things_to_do`   | `ThingsDetailPage`            |
| `screen-things-booking`         | `dash/travel/things_to_do`   | `ThingsBookingPage`           |
| `screen-things-pin`             | `dash/travel/things_to_do`   | `ThingsPinPage`               |

### bills

| `screen-bills`            | `bills/`                              | `BillsPage` (landing)          |
| `screen-bills-airtime`    | `bills/airtime`                       | `BillsAirtimePage`             |
| `screen-bills-data`       | `bills/data`                          | `BillsDataPage`                |
| `screen-travel-data`      | `bills/data`                          | `TravelDataPage`               |
| `screen-travel-data-pin`  | `bills/data`                          | `TravelDataPinPage`            |
| `screen-bills-electricity`| `bills/electricity`                   | `BillsElectricityPage`         |
| `screen-bills-success`    | `bills/success`                       | `BillsSuccessPage`             |
| `screen-pss`              | `bills/pss`                           | `PssPage`                      |
| `screen-pss-detail`       | `bills/pss`                           | `PssDetailPage`                |
| `screen-pss-pay-pin`      | `bills/pss`                           | `PssPayPinPage`                |
| `screen-pss-pay-success`  | `bills/pss`                           | `PssPaySuccessPage`            |
| `screen-pss-add-phone`    | `bills/pss`                           | `PssAddPhonePage`              |
| `screen-pss-phone-otp`    | `bills/pss`                           | `PssPhoneOtpPage`              |

### rewards

| `screen-rewards`          | `dash/rewards`                       | `RewardsPage`                 |
| `screen-redeem-points`    | `dash/rewards`                       | `RedeemPointsPage`            |
| `screen-redeem-pin`       | `dash/rewards`                       | `RedeemPinPage`               |

### transfer

| `transferModal` (step 1)   | `transfer/commons/widgets`          | `TransferSheet` (details)    |
| `transferModal` (step 2)   | `transfer/commons/widgets`          | `TransferSheet` (PIN)        |
| `transferModal` (step 3)   | `transfer/commons/widgets`          | `TransferSheet` (success)    |

HTML reference — `Kalabash mobile 2/index.html` lines 11647-11783.
The HTML `transferModal` is a single `modal-overlay` with three internal
step `<div>`s (`#transfer-step-1`, `-2`, `-3`) toggled via inline
`style.display`. The Flutter port therefore uses a **single stateful
bottom sheet** with an internal `_TransferStep { details, pin, success }`
state machine rather than three separate pages + routes — there is no
back-stack to preserve between steps in the HTML (the prototype mutates
shared `transferState` fields in place). Opened via
`TransferSheet.show(context)` from the Transfer quick-action tile on
`HomeDashPage` (kycLater / verified only; guest still falls through to
`GuestGateSheet`).

Files created under `lib/modules/transfer/`:

* `commons/domain/entities/kalabash_user.dart` — `KalabashUser { walletNum, name }`.
* `commons/sample_data/transfer_sample_data.dart` — `kalabashUsersSample`, `lookupKalabashUser`, `transferMockWalletBalance` (₦100,000 — matches HTML `walletBalance` default).
* `commons/state/transfer_draft.dart` — immutable `TransferDraft { walletNum, userName, amount, narration }` snapshot handed to the PIN and success steps.
* `commons/widgets/transfer_sheet.dart` — the 3-step sheet itself plus its private sub-widgets (`_DetailsStep`, `_PinStep`, `_SuccessStep`, `_NumPad`, `_PinDot`, `_TransferTextField`, `_ResolvedNamePill`, `_NotFoundPill`).

Validation contract per §5.10.2 — the details step validates inline
without `TextFormField`:

* **Wallet number** — `FilteringTextInputFormatter.digitsOnly` +
  `LengthLimitingTextInputFormatter(11)`; at exactly 11 digits calls
  `lookupKalabashUser` and toggles the green resolved-name pill or the
  red "No Kalabash user found" pill. HTML lines 15470-15499.
* **Amount** — `CurrencyInputFormatter` reused from `bills/commons/utils`;
  error text rendered below the field + 1.5px red border on the input
  container when the amount exceeds balance or is below ₦50. Continue
  CTA stays at `opacity 0.4` until validation passes. HTML lines
  15501-15526.
* **Narration** — optional, `LengthLimitingTextInputFormatter(50)` per
  HTML `maxlength="50"` on line 11711.
* **PIN** — any 4 digits accepted (HTML comment line 15580: "Prototype:
  any 4-digit PIN works"); auto-advances to the success step after
  `400ms` (HTML line 15562 `setTimeout(processTransfer, 400)`) via a
  `Timer` stored on state.

No routes registered — the sheet is the entire UI for the feature.
Closing at the success step pops the sheet and returns the user to
`HomeDashPage`. No flutter analyze blockers: the tile callback captures
the `HomeDashPage`'s `BuildContext` via the `_QuickActionsGrid.build`
scope (see `home_dash_page.dart` lines 1076-1085).

> **Totals.** 103 unique HTML screens + 1 modal → ~15 features across
> 8 modules (`authentication`, `kyc`, `dash`, `savings`, `cards`,
> `wallet`, `bills`, `transfer`).

---

## 12. Build, Codegen & Environment

### Codegen one-liner

```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

Run this every time you:
* add/edit a `@freezed` / `@JsonSerializable` class,
* add/remove an `AutoRoute`,
* add an asset and want the `Assets.images.*` entry.

### Flavors

Use `flutter_flavorizr` (already in dev deps) to wire prod/stage for
Android/iOS:

```bash
flutter pub run flutter_flavorizr
```

Then:

```bash
flutter run --flavor prod  -t lib/main_prod.dart
flutter run --flavor stage -t lib/main_stage.dart
```

### Required `.env` keys

```
PROD_BASE_URL=https://api.kalabash.example
STAGE_BASE_URL=https://api.stage.kalabash.example
```

Add `flutter_dotenv` to `pubspec.yaml` before the first
`Config.baseUrl` call.

### Firebase

1. `flutterfire configure --project=<prod-project> --out=lib/firebase_options_prod.dart`
2. `flutterfire configure --project=<stage-project> --out=lib/firebase_options_stage.dart`
3. Ensure each `main_*.dart` imports the matching generated file.

---

## 13. Testing Conventions

```
test/
├── widget_test.dart                        # smoke test for App
├── modules/
│   ├── commons/
│   │   ├── helpers/
│   │   │   └── http_helper_test.dart
│   │   └── navigation/
│   │       └── app_router_adapter_test.dart
│   └── authentication/
│       └── features/
│           └── sign_up/
│               ├── logic/
│               │   └── sign_up_controller_test.dart
│               └── ui/
│                   └── sign_up_page_test.dart
```

* Use `mockito` to mock `abstract class` services and `RouterPort`.
* Every controller gets a unit test covering: initial state,
  each state-mutator, each happy-path use-case call, each error branch.
* Every page gets a widget test that finds each `Key` and verifies
  controller interaction through a mocked provider:
  ```dart
  testWidgets('tap continue triggers handlePhoneAuth', (tester) async {
    final mockController = MockSignUpController();
    await tester.pumpWidget(ProviderScope(
      overrides: [
        signUpControllerProvider.overrideWith((ref) => mockController),
      ],
      child: MaterialApp(home: SignUpPage()),
    ));
    await tester.tap(find.byKey(const Key('continue_cta')));
    verify(mockController.handlePhoneAuth(phone: any)).called(1);
  });
  ```

---

## 14. Migration Workflow (step-by-step)

A disciplined order of operations that minimises churn and keeps the
graph importable at every commit.

1. **Bootstrap** (once, before any feature work):
   1. `lib/modules/commons/config/flavor.dart` + `config.dart`.
   2. `lib/modules/commons/utils/utils.dart`, `app_logger.dart`,
      `api_call_status.dart`.
   3. `lib/modules/commons/helpers/*` (`HttpHelper`, `HapticFeedBackHelper`,
      `KalabashAlert`, `KalabashAppNotification`, `ApiHelper`).
   4. `lib/modules/commons/widgets/kalabash_safe_area.dart`,
      `flavor_banner.dart`, `app_overlay.dart`, `buttons/button.dart`,
      `inputs/input.dart`, `inputs/pin_input.dart`,
      `inputs/phone_number_input.dart`, `bordered_container.dart`.
   5. `lib/modules/commons/navigation/*` (all five files as described in
      §5.4).
   6. `lib/modules/commons/core/features/remote_config/**` skeleton.
   7. `lib/modules/commons/domain/entities/user/user.dart`.
   8. `lib/modules/commons/di/di.dart` (`setupServiceLocator` with only
      the infra singletons).
   9. `lib/app.dart` + `lib/main_prod.dart` + `lib/main_stage.dart`.
   10. Assets + `flutter_gen` run → `gen/assets.gen.dart`.
   11. `lib/l10n/app_en.arb` with the first handful of strings.
   12. `flutter pub run build_runner build --delete-conflicting-outputs`.
   13. `flutter analyze` should be clean at this point.

2. **Per-feature loop** (repeat for each row in §11):
   1. Create the feature folder tree (§6).
   2. Add `data/models/*.dart` for any DTOs used by the screen
      (`freezed` + `.g.dart`).
   3. Add `data/datasources/remote_data_source/<feature>_service.dart`
      (abstract) and its `repositories/<feature>_service_impl.dart`.
   4. Add `domain/entities/<entity>/*.dart` if the feature has a pure
      entity (vs. a DTO).
   5. Add `domain/use_cases/<action>_use_case.dart` — one per backend
      operation the controller calls.
   6. Add `logic/controller/<feature>_controller.dart` with a `@freezed`
      state. Register the provider.
   7. Register the service + impl + use cases in
      `setupServiceLocator` under a private `_register<Feature>()` helper.
   8. Create `ui/<screen>_page.dart` for each screen. Use the canonical
      page (§6). Extract repeating blocks into `ui/widgets/*.dart`.
   9. Add `AutoRoute(page: <Screen>Route.page)` entries in
      `app_router.dart`.
   10. Run build_runner.
   11. Wire navigation (`AppNavigation.push(<Screen>Route(...))`) from
       the entry point (previous screen or bottom-tab).
   12. Add ARB strings.
   13. Run the feature in `--flavor stage` and tick the Definition of
       Done (§15).

3. **Integration / regression** (after each module):
   1. Run `flutter analyze`.
   2. Run `flutter test`.
   3. Run the app on iPhone 14 and Pixel 6 emulators.
   4. Diff the screen against the HTML prototype rendered in a desktop
      browser at 390×844.

---

## 15. Definition of Done per Screen

A screen is merged when **every** box is ticked:

* [ ] Page class is under the correct `lib/modules/<module>/features/<feature>/presentation/ui/`.
* [ ] Route is wired in `app_router.dart` and reachable via
      `AppNavigation.push`.
* [ ] Only design-system tokens are used (no raw `Color`, `TextStyle`,
      or magic number — verified by visual grep).
* [ ] Every interactive element has a `Key('...')`.
* [ ] Every user-facing string is in `app_en.arb`.
* [ ] State (if any) is in a `StateNotifier` with a `@freezed` state;
      provider is declared above the class.
* [ ] Backend calls (if any) go through a `UseCase` → `Service` →
      `HttpHelper` → generated API.
* [ ] Errors surface via `KalabashAppNotification` — never `print`,
      never a raw `SnackBar`.
* [ ] Assets resolve via `Assets.images…` (not literal paths).
* [ ] `flutter analyze` + `dart format` are clean.
* [ ] A widget test covers every `Key` on the page.
* [ ] A unit test covers each branch of the controller's public
      methods.
* [ ] Visually matches the HTML prototype at 390×844 within design tolerance.

---

## 16. Color Matching Rules (every screen)

Colour is not a place to improvise. For **every** screen migrated from
the HTML prototype, the engineer must do a dedicated colour pass in
which every pixel's fill, text, border, icon, shadow, and gradient is
read out of the HTML and re-expressed in Flutter with zero drift. This
section defines how to do that pass. It applies to every screen — home,
settings, onboarding, wallet, KYC, send, receive, swap, statement,
profile, and every future screen the team ships.

Skipping this pass is not acceptable. Visual mismatch is a regression
even if the feature works. If you don't have time for the colour pass,
you don't have time to ship the screen.

### 16.1 Why a dedicated colour pass is non-negotiable

* The HTML prototype is the design contract. If Flutter disagrees with
  it, Flutter is wrong.
* Flutter's default Material colours (`Colors.grey`, `Colors.blue`,
  `Theme.of(context).cardColor`) are **never** correct. They almost
  match — which is worse than being obviously different, because it
  survives code review.
* Dark mode is the single biggest source of colour drift. A widget can
  look correct in light mode but use the wrong dark-mode variant, and
  the bug will only surface for users who enable dark mode on their
  device.
* The HTML uses a mix of CSS custom properties (`var(--primary)`),
  rgba literals, hex literals, and inline `style="…"` overrides.
  Reading one of these without the others will give the wrong answer.

### 16.2 The source-of-truth hierarchy

When you need to determine the correct colour for any element, consult
sources in this exact order and stop at the first one that applies:

1. **Inline `style="…"` on the specific element** inside the screen's
   `#screen-<id>` block in `Kalabash mobile 2/index.html`. Inline styles
   win over every stylesheet rule. Hex and rgba literals here are
   literal — copy them byte-for-byte.
2. **`.dark-mode #screen-<id> …` overrides** in the stylesheet (search
   for `.dark-mode.*#screen-<id>` or the screen-specific dark block).
   These replace the light-mode value **only** when dark mode is
   active.
3. **Screen-conditional body class overrides** — e.g. `.dark-home`,
   `.dark-guest` — which are attached by the JavaScript in the
   prototype only when a particular screen is active **and** the
   system is in dark mode. Search for `classList.add` in the JS block
   near the bottom of the HTML to find the trigger conditions.
4. **Component-scope rules** — `.settings-card`, `.tx-icon.credit`,
   `.quick-action`, `.pill`, `.badge`, etc. — which set defaults that
   the above sources can override.
5. **Design-system `:root` variables** (top of the `<style>` block).
   These resolve `var(--primary)` etc. to concrete hex values and are
   mirrored 1:1 in `lib/modules/commons/theme/app_colors.dart`.

If two rules of equal specificity both apply, the later-declared one
wins, same as normal CSS.

### 16.3 Dark-mode is state-dependent — read BEFORE you code

Dark mode in the HTML is **not** a single uniform theme. It is a
composition of:

* A base `.dark-mode` class on `<body>` that swaps the screen
  background and all generic component colours.
* Zero or more **screen-conditional** classes (e.g. `.dark-home`,
  `.dark-guest`) that are attached by the prototype JS **only** when a
  specific screen is active. Inspect the JS at the bottom of
  `index.html` — look for `classList.add('dark-xxx')` inside event
  handlers — to enumerate which screens carry which class.
* Inline `style="…"` dark overrides that some elements define via a
  sibling `<style>` injected near their declaration.

**Practical implications for Flutter:**

* If a widget's colour depends on which *screen state* is active
  (e.g. home has `guest` / `kycLater` / `verified` / `funded` states
  and they can share a widget but require different colours), the
  widget must accept that state as a constructor param and branch on
  it. Do **not** read a provider deep in the widget tree to decide a
  colour — pass it down from the page.
* Always verify the dark value in context: open the HTML in Chrome,
  toggle `document.body.classList.add('dark-mode')` from DevTools
  (and any screen-conditional class), then inspect the computed style
  of the element. Copy that computed RGB/RGBA value. Never guess from
  the rule alone — specificity can surprise you.
* Some components have **no** dark override and simply inherit the
  base variable. Don't invent one. If the HTML renders the element the
  same in both modes, Flutter does too.

### 16.4 Token priority (never hard-code a colour you can name)

When choosing how to express a colour in Dart, walk this ladder from
top to bottom and use the first rung that fits:

1. **Named token in `app_colors.dart`** (`AppColors.primary`,
   `AppColors.dmInputBg`, etc.). Always prefer this. If the colour
   exists as a `:root` variable in the HTML, it exists as a token here.
2. **Semantic alias in `app_text_styles.dart` / `app_theme.dart`**
   (e.g. `theme.colorScheme.surface`, a heading `TextStyle` with the
   colour baked in). Use when the element's colour is pulled entirely
   from the theme and no branching is needed.
3. **A new token added to `app_colors.dart`** if the HTML uses a
   value repeatedly (three or more widgets) and no existing token
   matches. Add it with a doc comment citing the HTML line number.
4. **An inline `Color(0x…)`** only for genuinely one-off values
   (a single widget, a single state). Every such literal MUST carry a
   trailing `// HTML line <n>` comment so a future reader can verify
   it.

Never write `Colors.grey[400]`, `Colors.black54`, or any value sampled
from a screenshot. Every colour in Flutter must be traceable to a
specific line in `index.html`.

### 16.5 Per-widget colour checklist

For every widget you migrate, enumerate and resolve each of the
following surfaces in **both** light and dark mode. A widget is not
done until every row that applies has a source-cited value:

* Container `background-color` (or `background` gradient)
* Container `border-color` (or `box-shadow`, if it stands in for a
  border)
* Container `box-shadow` colour(s) and alpha
* Text `color` for **every** `<span>` / `<div>` with distinct copy
  (title, subtitle, meta, caption — each is typically its own colour)
* Text `color` in hover / pressed / disabled states, if the prototype
  has those
* Icon `color` (fill or stroke — note that some HTML icons are
  `currentColor` and inherit from the enclosing text, while others are
  SVGs with their own fills)
* Icon-wrap / badge `background-color` and text `color`
* Divider / hairline `border-bottom` colour
* Scrim / overlay `background-color` (usually rgba with alpha)
* Input field `background`, `border`, `color`, `::placeholder` colour
* Toggle / switch track and thumb colours for both on and off states
* Chart / sparkline stroke and fill colours
* Image / avatar gradients and ring colours

If the widget appears in more than one screen state (guest / verified
/ funded / etc.) repeat the entire checklist for each state.

### 16.6 rgba(…) → Flutter ARGB conversion rules

Flutter's `Color` constructor takes `0xAARRGGBB`. The HTML uses
`rgba(R, G, B, A)` where `A` is a 0.0-1.0 decimal. Convert:

* `alpha_byte = round(A * 255)` → express as two hex digits.
* `R`, `G`, `B` are already 0-255 integers → each becomes two hex
  digits.
* Concatenate: `Color(0x<alpha><RR><GG><BB>)`.

Common alpha stops are worth memorising:

| CSS alpha | Hex byte | Example (white) |
| --- | --- | --- |
| 1.00 | `FF` | `0xFFFFFFFF` |
| 0.95 | `F2` | `0xF2FFFFFF` |
| 0.92 | `EB` | `0xEB……` |
| 0.90 | `E6` | `0xE6FFFFFF` |
| 0.88 | `E0` | `0xE0FFFFFF` |
| 0.80 | `CC` | `0xCCFFFFFF` |
| 0.75 | `BF` | `0xBFFFFFFF` |
| 0.70 | `B3` | `0xB3FFFFFF` |
| 0.60 | `99` | `0x99FFFFFF` |
| 0.50 | `80` | `0x80000000` |
| 0.45 | `73` | `0x73FFFFFF` |
| 0.35 | `59` | `0x59FFFFFF` |
| 0.30 | `4D` | `0x4DFFFFFF` |
| 0.20 | `33` | `0x33FFFFFF` |
| 0.15 | `26` | `0x26……` |
| 0.12 | `1F` | `0x1F……` |
| 0.06 | `0F` | `0x0FFFFFFF` |

Prefer these byte values over re-deriving them by hand; they match the
alpha stops the designer actually used. Do **not** use Flutter's
`color.withOpacity(0.5)` / `color.withValues(alpha: 0.5)` when
migrating from the HTML — bake the alpha into the literal so the
literal itself is greppable against the HTML source.

### 16.7 Reference palette (HTML line → Flutter token)

The token values below are declared in
`lib/modules/commons/theme/app_colors.dart`. They are listed here so
that engineers doing a colour pass on **any** screen can map an HTML
variable directly to a Flutter token without re-reading the theme
file. When the HTML references a `var(--name)` variable, resolve it
via this table first before falling back to an inline literal.

**Brand & semantic**

| HTML | Hex | AppColors token |
| --- | --- | --- |
| `--primary` | `#1B3F7F` | `AppColors.primary` |
| `--accent` | `#1E56A8` | `AppColors.accent` |
| `--purple` | `#7C3AED` | `AppColors.purple` |
| `--purple-light` | `#8B5CF6` | `AppColors.purpleLight` |
| `--yellow` | `#F5C518` | `AppColors.yellow` |
| `--green` | `#10B981` | `AppColors.green` |
| `--red` | `#EF4444` | `AppColors.red` |

**Light neutral / surface**

| HTML | Hex | AppColors token |
| --- | --- | --- |
| `--bg-dark` | `#000000` | `AppColors.bgDark` |
| `--bg-light` | `#FFFFFF` | `AppColors.bgLight` |
| `--card-bg` | `#F5F6FA` | `AppColors.cardBg` |
| `--input-bg` | `#F3F4F6` | `AppColors.inputBg` |
| `--text-primary` | `#0D1B2A` | `AppColors.textPrimary` |
| `--text-secondary` | `#6B7280` | `AppColors.textSecondary` |
| Border default | `#E5E7EB` | `AppColors.borderDefault` |
| Border strong | `#D1D5DB` | `AppColors.borderStrong` |
| Muted meta / subtitle | `#9CA3AF` | `AppColors.keypadSubLabel` |
| Hairline divider | `#F3F4F6` / `#F5F5F5` | `AppColors.divider` / inline `Color(0xFFF5F5F5)` |

**Dark-mode overrides**

| HTML | Hex | AppColors token |
| --- | --- | --- |
| `dm-screen-bg` | `#010E1F` | `AppColors.dmScreenBg` |
| `dm-card-bg` | `#0A1929` | `AppColors.dmCardBg` |
| `dm-input-bg` | `#0D2140` | `AppColors.dmInputBg` |
| `dm-border` | `#1A3050` | `AppColors.dmBorder` |
| `dm-accent` | `#5BCBDF` | `AppColors.dmAccent` |
| `text-secondary` (dark) | `rgba(255,255,255,0.45)` | `AppColors.dmTextSecondary` |

**Badges / pills** (HTML name ↔ token pair)

| HTML variant | Bg | Fg | Tokens |
| --- | --- | --- | --- |
| Purple badge | `#EDE9FE` | `#7C3AED` | `badgePurpleBg` / `badgePurpleFg` |
| Navy badge | `#DBEAFE` | `#1B3F7F` | `badgeNavyBg` / `badgeNavyFg` |
| Teal badge | `#CCFBF1` | `#0D9488` | `badgeTealBg` / `badgeTealFg` |
| Green badge | `#D1FAE5` | `#059669` / `#10B981` | `badgeGreenBg` / `badgeGreenFg` or `AppColors.green` |
| Red badge | `#FEE2E2` | `#DC2626` | `badgeRedBg` / `badgeRedFg` |
| Yellow badge | `#FEF3C7` | `#D97706` | `badgeYellowBg` / `badgeYellowFg` |
| Yellow solid | `#F5C518` | `#1A1A1A` | `badgeYellowSolidBg` / `badgeYellowSolidFg` |

**Common rgba stops you'll see in the HTML**

| rgba literal | Flutter ARGB | Typical use |
| --- | --- | --- |
| `rgba(255,255,255,0.95)` | `Color(0xF2FFFFFF)` | Wallet account box fill |
| `rgba(255,255,255,0.90)` | `Color(0xE6FFFFFF)` | Dark-mode profile name |
| `rgba(255,255,255,0.88)` | `Color(0xE0FFFFFF)` | Dark-mode row label |
| `rgba(255,255,255,0.80)` | `Color(0xCCFFFFFF)` | Dark-mode kyc-later icon |
| `rgba(255,255,255,0.75)` | `Color(0xBFFFFFFF)` | Dark-mode card subtitle |
| `rgba(255,255,255,0.70)` | `Color(0xB3FFFFFF)` | "On gradient" muted copy (`AppColors.onGradientMuted`) |
| `rgba(255,255,255,0.60)` | `Color(0x99FFFFFF)` | Dark-mode tile subtitle |
| `rgba(255,255,255,0.45)` | `Color(0x73FFFFFF)` | `AppColors.dmTextSecondary` |
| `rgba(255,255,255,0.35)` | `Color(0x59FFFFFF)` | Dark-mode row subtitle |
| `rgba(255,255,255,0.30)` | `Color(0x4DFFFFFF)` | Dark-mode section label / version |
| `rgba(255,255,255,0.15)` | `Color(0x26FFFFFF)` | Icon button emphasis fill |
| `rgba(255,255,255,0.12)` | `Color(0x1FFFFFFF)` | Icon button default fill |
| `rgba(255,255,255,0.06)` | `Color(0x0FFFFFFF)` | Wallet decorative circle |
| `rgba(91,203,223,0.12)` | `Color(0x1F5BCBDF)` | Dark icon-wrap bg |
| `rgba(16,185,129,0.15)` | `Color(0x2610B981)` | Dark "verified" pill bg |
| `rgba(0,0,0,0.5)` | `Color(0x80000000)` | Modal scrim |
| `rgba(13,27,42,0.92)` | `Color(0xEB0D1B2A)` | Toast background |

If the value you need is not in any of the tables above, resolve it
from the HTML by hand using the rules in §16.6 and drop it into the
literal with a `// HTML line <n>` comment.

### 16.8 Step-by-step colour audit protocol

Run this procedure as part of migrating any new screen, and again as a
standalone pass whenever a designer flags visual drift:

1. **Locate the screen block.** Open
   `Kalabash mobile 2/index.html` and find
   `<section id="screen-<id>">…</section>`. Note the line range.
2. **Enumerate dark overrides.** Grep
   `.dark-mode.*#screen-<id>` and `.dark-<screen-short-name>` inside
   the stylesheet to find every rule that targets this screen in dark
   mode. Also grep `classList.add('dark-` in the JS block to find any
   screen-conditional classes this screen carries.
3. **Inventory widgets.** Walk the Flutter page top-to-bottom and
   list every widget (private class, `Container`, `Text`, `Icon`,
   `Divider`, `Gradient`, `BoxShadow`). Number them.
4. **Resolve each widget.** For each widget on the list, fill in
   the §16.5 checklist using §16.2's hierarchy. Cite the HTML line
   for every value. If a value is state-dependent, note the state
   variable that drives it.
5. **Map to tokens.** For each resolved value, pick an AppColors
   token per §16.4. If a new token is justified (reused ≥ 3 times),
   add it to `app_colors.dart` with a `/// HTML line <n>` doc comment
   in the same commit.
6. **Write the code.** Apply the values. Every inline `Color(0x…)`
   must have a trailing `// HTML line <n>` comment. Every
   state-dependent branch must be driven by a widget param, not a
   deep provider read.
7. **Visual diff.** Render the HTML in Chrome at 390×844. Render the
   Flutter screen in both iPhone 14 and Pixel 6 simulators at the
   matching window size. Compare side-by-side in both light and dark
   mode. Pay particular attention to card backgrounds, icon-wrap
   fills, subtitle greys, and divider lines — these are the four most
   common sources of drift.
8. **Screenshot-diff (optional but recommended).** Capture PNGs of
   both, overlay with an opacity of 50%, and look for any colour
   offset. Any offset is a bug.
9. **Record findings.** In the PR description, list the HTML
   selectors you cross-referenced and any new `AppColors` tokens
   added. Reviewers use this list to spot-check.

### 16.9 Review gate (must pass before the PR merges)

Every screen-migration PR must satisfy the following before it can
merge. This is an extension of the Definition of Done in §15 — the
colour pass is its own gate because visual bugs slip through code
review more easily than functional ones:

* [ ] Every `Color(…)` literal in the changed files is either an
      `AppColors.*` token **or** carries a trailing
      `// HTML line <n>` comment that points to the specific line in
      `index.html`.
* [ ] `grep` across the changed files for `Colors\.` (Material's
      built-in palette) returns zero hits.
* [ ] `grep` for `withOpacity\(` and `withValues\(alpha:` returns
      zero hits on colours sourced from the HTML — the alpha is
      baked into the literal.
* [ ] For every widget that renders differently per screen state,
      the state is passed in as a constructor param; the widget does
      not call `ref.watch` to decide a colour.
* [ ] Both light-mode and dark-mode screenshots are attached to the
      PR and have been diffed against the HTML.
* [ ] The PR description lists the HTML selectors consulted and any
      new `AppColors` tokens added.

A PR that fails any of these gates is rejected, regardless of how
polished the logic is.

---

## 17. Font Weight Matching Rules (every screen)

Font weight is the second pass that must run on **every** screen
migration, right after the colour pass in §16. It is equally strict
and equally non-negotiable: a Text widget whose weight drifts from the
HTML is a visual bug even if the colour, size, and copy are perfect.
Weight carries hierarchy — when Flutter over-weights a caption or
under-weights a title, the whole layout stops reading correctly.

This section is the generic playbook for matching font weights on
any screen. It applies to home, settings, onboarding, wallet, KYC,
send, receive, swap, cards, statement, profile, and every future
screen the team migrates.

### 17.1 Why a dedicated font-weight pass is non-negotiable

* The prototype is the contract. A weight mismatch is a typography
  regression and must be caught in review, not after release.
* Flutter's default for `TextStyle` is `FontWeight.w400` (regular).
  Any Text that needs to render at a different weight must say so
  explicitly — no relying on a theme default to "be close enough".
* Engineers tend to **over-weight** captions and sub-labels by
  muscle memory (`w500` / `w600` feels safe). The HTML is usually
  lighter than that. The correction is always downwards in practice.
* A single inline `style="…font-weight:600…"` in the HTML overrides
  the CSS class rule above it. If you skim the class and skip the
  inline style, your Flutter weight will be wrong even though the
  class rule "looked right".

### 17.2 The source-of-truth hierarchy for weights

For every text element you migrate, resolve the `font-weight` using
this exact order and stop at the first source that applies:

1. **Inline `style="…font-weight:<n>…"`** on the specific element
   inside the screen's `#screen-<id>` block. Inline styles win over
   every stylesheet rule, so this is always checked first.
2. **Element-specific CSS rule** that targets the element's id or a
   fully-qualified selector (e.g. `#screen-settings .settings-card
   .settings-row-label`). These beat generic class rules.
3. **Class-scope CSS rule** — e.g. `.tx-title { font-weight: 600 }`,
   `.settings-row-label { font-weight: 500 }`. Search for the class
   name at the top of the `<style>` block.
4. **Parent / body default** — if no rule sets a weight, the element
   inherits from its parent. The `@font-face` + `body { font-family:
   'DM Sans'; }` definition does **not** set a default weight, so the
   effective fallback is the CSS initial value, which is `400`.

**Do not skip step 1.** The single most common mistake in this
codebase is migrating from a class rule (e.g. `.wallet-balance
{ font-weight: 700 }`) while the actual element on the rendered
screen has an inline `font-weight: 800` that overrides it.

### 17.3 The "no explicit font-weight" trap

When an element has no `font-weight` declaration anywhere — neither
inline, nor element-scoped, nor class-scoped — its effective weight
is **400** (normal). This is the single most misapplied rule in the
Flutter migration.

Concrete patterns to watch for:

* `<div style="font-size:13px;color:#6B7280;">…</div>` → **w400**,
  not w500.
* `.tx-sub { font-size:12px; color:var(--text-secondary); }` →
  **w400**, not w500.
* Settings row subtitles rendered from
  `<div style="font-size:11px;color:#9CA3AF;">…</div>` → **w400**,
  not w500.

If you find yourself writing `FontWeight.w500` for a muted subtitle
or meta row, stop and grep the HTML — nine times out of ten that
element has no explicit weight and the correct Flutter value is
`FontWeight.w400`.

### 17.4 CSS weight → Flutter `FontWeight` mapping

CSS font-weight uses either a numeric scale (100-900 in steps of
100), the keyword `normal` (= 400), or the keyword `bold` (= 700).
Flutter `FontWeight` maps 1:1 to the numeric scale:

| CSS weight | Flutter constant | Common semantic use |
| --- | --- | --- |
| `100` | `FontWeight.w100` | Not used in this prototype |
| `200` | `FontWeight.w200` | Not used in this prototype |
| `300` | `FontWeight.w300` | Not used in this prototype |
| `400` / `normal` | `FontWeight.w400` | Body, subtitles, muted meta, captions, hints |
| `500` | `FontWeight.w500` | Secondary labels, soft emphasis, small caps |
| `600` | `FontWeight.w600` | Buttons, pill labels, trailing values, "see all" |
| `700` / `bold` | `FontWeight.w700` | Headings, titles, banner callouts, CTAs |
| `800` | `FontWeight.w800` | Wallet balance amounts, price amounts, hero numbers |
| `900` | `FontWeight.w900` | Not used in this prototype |

Do **not** shortcut this by using `FontWeight.normal` or
`FontWeight.bold` — always express the weight numerically so that a
grep for `FontWeight.w` finds every declaration.

### 17.5 DM Sans weight availability

Our typography stack is DM Sans via `google_fonts` (`GoogleFonts.dmSans`).
The DM Sans family on Google Fonts ships the following weight masters:

* **100** Thin
* **200** Extra Light
* **300** Light
* **400** Regular (italic available)
* **500** Medium (italic available)
* **600** SemiBold
* **700** Bold
* **800** ExtraBold
* **900** Black

Every weight the HTML prototype uses — 400 / 500 / 600 / 700 / 800 —
is a first-class master, not a synthesised interpolation. This means
Flutter can honour any HTML weight value byte-for-byte without
fallback. There is **never** a reason to round to a nearby weight.

If a weight cannot be fetched at runtime (e.g. the device is offline
and the cache is cold), `google_fonts` will substitute the system
sans and Flutter may synthesise weight. That is a runtime concern,
not a migration concern — the authored weight must still match the
HTML.

### 17.6 Per-widget font-weight checklist

For every widget you migrate, enumerate and resolve the weight of
**each** distinct Text child. A widget is not done until every row
below that applies has a weight cited against an HTML line:

* Primary title / heading
* Secondary subtitle directly below the title
* Meta row (timestamp, location, category, handle)
* Leading label / eyebrow text (often uppercase with letter-spacing)
* Trailing value (amount, status, language)
* Body paragraph(s) inside cards
* Button / pill / chip label
* "See all", "See more", and other navigation affordances
* Badge text (inside pill-shaped tags)
* Form field label and placeholder
* Form field value (after the user types)
* Input helper text / error message
* List-item primary text and list-item secondary text
* Toggle / switch "on" and "off" labels (if the element carries copy)
* Empty-state title and body
* Tooltip / toast / snackbar text
* Status line / version footer / copyright

Don't consolidate. Two Text widgets that look similar may have
different HTML weights.

### 17.7 Weight semantics (pick meaning, not a number)

When naming a new reusable `TextStyle` in `app_text_styles.dart` (or
choosing which existing style to apply), pick the style whose
semantic role matches the HTML element. Don't name a style by its
weight — name it by its usage. Roles that recur across screens:

* **Display** (hero balance, wallet amount) — w800, 28-36 sp.
* **Heading** (page title, section heading) — w700, 15-18 sp.
* **Title** (card title, row label with emphasis) — w700, 13-15 sp.
* **Label** (pill label, button label, trailing value) — w600,
  11-13 sp.
* **Soft label** (quick-action caption, subtitle with emphasis) —
  w500, 11-13 sp.
* **Body / Subtitle** (muted meta, body paragraph, hint) — w400,
  11-13 sp.
* **Eyebrow / Caption** (uppercase tag above a number, letter-
  spacing > 0) — varies; read the HTML.

If a style is reused three or more times across screens, add it as a
named getter on `AppTextStyles` with a doc comment citing the HTML
class it mirrors. One-offs stay inline with an `// HTML line <n>`
comment.

### 17.8 Step-by-step font-weight audit protocol

Run this procedure for every new screen migration, and as a
standalone pass whenever a designer flags typography drift:

1. **Locate the screen block** — `<div class="screen" id="screen-
   <id>">…</div>` in `index.html`. Note the line range.
2. **Grep distinct weights in scope** —
   `grep -n "font-weight" index.html` and filter to the screen's
   line range. This surfaces every weight declaration that applies
   to this screen.
3. **Inventory text widgets** — walk the Flutter page top-to-bottom
   and list every `Text` widget, numbering them. Include rich-text
   runs (`TextSpan` inside `Text.rich`).
4. **Resolve each widget's weight** — for each numbered item, walk
   the hierarchy in §17.2:
   * Find the HTML element.
   * Check inline `style="…"` first.
   * Fall back to element-scoped rules.
   * Fall back to class rules.
   * Fall back to the w400 default.
   Cite the HTML line for the value you pick.
5. **Translate to Flutter** — map each CSS value to a
   `FontWeight.wXYZ` using §17.4. Every literal must carry a
   trailing `// HTML line <n>` comment so a reviewer can verify it.
6. **Grep for weight drift anti-patterns** — after applying the
   values, run:
   * `grep -n "FontWeight\.normal\|FontWeight\.bold" <file>` →
     should return **zero hits**.
   * `grep -n "FontWeight\.w400" <file>` → every match should
     correspond to an HTML element with no explicit font-weight (or
     inline w400). If you have a `w400` match against an element
     that the HTML sets to w500+, that's a bug.
7. **Visual diff** — render the HTML in Chrome at 390×844 and the
   Flutter screen on both iPhone 14 and Pixel 6 simulators. Compare
   the hierarchy of emphasis side-by-side. Pay particular attention
   to:
   * Row labels vs row values (the label is usually lighter).
   * Transaction title vs transaction time (title is w600, time is
     w400 — this is a frequent drift).
   * Banner title vs banner subtitle (title w700, subtitle w400).
   * Empty-state title vs body (title w700, body w400).
8. **Record findings** — in the PR description, list the HTML
   selectors you cross-referenced and any new text styles added to
   `app_text_styles.dart`.

### 17.9 Review gate (must pass before the PR merges)

Every screen-migration PR must satisfy the following gates before it
can merge. This extends the §15 Definition of Done and the §16.9
colour gate — font-weight is its own gate because weight bugs slip
through code review more easily than functional ones:

* [ ] Every `FontWeight.wXYZ` literal in the changed files is
      either declared on an `AppTextStyles` named style **or**
      carries a trailing `// HTML line <n>` comment pointing to the
      specific line in `index.html`.
* [ ] `grep` for `FontWeight\.normal` and `FontWeight\.bold` in the
      changed files returns **zero hits**.
* [ ] Every muted / meta / subtitle Text has been cross-checked
      against the HTML — if the HTML element has no explicit
      `font-weight`, Flutter must use `FontWeight.w400`, not w500.
* [ ] Every amount / balance / price has been verified against the
      inline HTML style (not just the `.wallet-balance` / `.curated-
      price-main` class), because inline weights routinely override
      the class.
* [ ] Both light-mode and dark-mode screenshots show the same
      typographic hierarchy as the HTML rendered in Chrome at
      390×844.
* [ ] The PR description lists the HTML selectors consulted and
      any new `AppTextStyles` entries added.

A PR that fails any of these gates is rejected, regardless of how
polished the logic is.

---

## 18. Font Size Matching Rules (every screen)

**Applies to every screen migration, not just the screens listed in
§11.** Colour (§16) fixes *what* a pixel is, weight (§17) fixes *how
heavy* the stroke is, and size fixes *how tall the glyph is* — the
single most perceptible property of any text. A label that is 1 px
off reads as "slightly wrong" even to engineers who can't name why,
and a screen with three or four such slips never feels right no
matter how correct the palette and weight are. Treat this pass as
mandatory, and keep the protocol below pinned in the PR description.

### 18.1 Why a dedicated font-size pass is non-negotiable

* **Perceptual accuracy.** Font size sets the vertical rhythm of a
  screen. A 13-px subtitle next to a 14-px one is immediately
  legible as a hierarchy; a 13 next to a 13 flattens it. The HTML
  prototype was authored with these differences in mind — honour
  them.
* **Review blindness.** Humans reviewing a diff will happily approve
  a `14.spMin` vs a `13.spMin` without noticing, because diffs do
  not render. The only guard is an explicit HTML-line citation on
  every literal.
* **Class-vs-inline confusion.** As with weight (see §17.2 and
  §18.5), inline `style="font-size:…"` regularly overrides the
  class rule that a naive audit would consult. Every size needs to
  be traced to the *effective* rule, not the first rule grep
  returns.
* **Test drift.** `flutter_screenutil`'s `.spMin` scales with the
  shortest device dimension. A wrong base number multiplies across
  every form factor, so what looks "close enough" on the reviewer's
  390×844 emulator can read 2-3 px off on a real device.

### 18.2 The source-of-truth hierarchy for sizes

CSS specificity is identical to the colour / weight hierarchy. To
determine the effective `font-size` of any HTML element, walk this
ladder **from top to bottom** and stop at the first rule that
applies:

1. **Inline `style="font-size: Npx;"`** on the element itself.
   This wins against everything else.
2. **ID selector** — `#screen-home .some-id { font-size: … }`.
3. **Element-plus-class selector** — `.tx-row .tx-title
   { font-size: 14px }`. More specific than a bare class.
4. **Bare class selector** — `.tx-title { font-size: 14px }`.
5. **Element selector** — `h1 { font-size: 24px }`,
   `.screen h2 { font-size: 20px }`, etc.
6. **Inherited body / root default — 16 px.** CSS resets in this
   prototype do not override the UA default for font-size.

Never guess. The only acceptable answer is "I traced this Flutter
literal to HTML line N, which resolves to Mpx per the hierarchy
above." If you cannot answer that for a given `fontSize:` literal,
do not ship it.

### 18.3 CSS px → Flutter `fontSize` (the 1 : 1 rule)

The Flutter app uses `flutter_screenutil` with a design size
matching the HTML prototype (390×844). `.spMin` therefore maps
**1 : 1** to CSS pixels. There is no conversion factor, no `* 0.875`,
no "Flutter looks bigger so subtract one":

| HTML               | Flutter                           |
| ------------------ | --------------------------------- |
| `font-size: 10px`  | `fontSize: 10.spMin`              |
| `font-size: 11px`  | `fontSize: 11.spMin`              |
| `font-size: 12px`  | `fontSize: 12.spMin`              |
| `font-size: 13px`  | `fontSize: 13.spMin`              |
| `font-size: 14px`  | `fontSize: 14.spMin`              |
| `font-size: 15px`  | `fontSize: 15.spMin`              |
| `font-size: 16px`  | `fontSize: 16.spMin` *(body)*     |
| `font-size: 17px`  | `fontSize: 17.spMin`              |
| `font-size: 18px`  | `fontSize: 18.spMin`              |
| `font-size: 20px`  | `fontSize: 20.spMin`              |
| `font-size: 22px`  | `fontSize: 22.spMin`              |
| `font-size: 24px`  | `fontSize: 24.spMin`              |
| `font-size: 28px`  | `fontSize: 28.spMin`              |
| `font-size: 30px`  | `fontSize: 30.spMin`              |
| `font-size: 34px`  | `fontSize: 34.spMin`              |
| `font-size: 36px`  | `fontSize: 36.spMin`              |

Do not use `.sp` in place of `.spMin` — the difference matters on
very wide form factors and is not what the prototype was authored
against.

Use `.spMin`, not raw `double`, for every text literal. Raw numbers
skip device-scaling and will appear undersized on large phones.

### 18.4 The "no explicit font-size" trap

If an HTML element has **no** `font-size` declared by any rule,
inline or class, its effective size is the **body default — 16 px**
— not 14, not 15. This is the direct analogue of the weight-400
trap documented in §17.3. A common failure mode is to render such
an element at `14.spMin` in Flutter because "everything looks 14".
When in doubt, paste the HTML fragment into a standalone page and
inspect the computed style in DevTools.

Conversely, many elements that *appear* to have no explicit size
actually inherit one from a nested-class rule (e.g. `.screen h2`,
`.card h3`, `.kyc-card .title`). Walk the selector chain before
concluding "there's no rule".

### 18.5 Inline-style override hotspots

These are the places in the prototype where an inline
`style="font-size:…"` routinely overrides the class rule. Always
inspect the element's own `style` attribute first on anything in
these areas:

* **Wallet balance** — the `.wallet-balance` class is 36 px, but
  verified/locked variants carry inline 34/30 overrides.
* **Account number** — `.account-num` class is 17 px; some
  promotional cards inline-override to 18.
* **Transaction amount meta-row** — rows in the savings and locked
  screens add a `<div style="font-size:11px;color:…">Deposit</div>`
  that is *not* covered by `.tx-amount`.
* **Mini-cards (airtime / data / bills)** — frequently use inline
  `font-size:9px` eyebrows and `font-size:18px` value numerals that
  are not on the generic `.mini-card-*` class.
* **Curated card price** — `.curated-price-main` is a base size
  but individual cards inline-override for long prices.
* **Settings profile block** — `.profile-name` is 16 px via class,
  but phone / phone-verified variants carry inline 13 px.
* **Header titles across sheets** — many sheets declare their own
  `style="font-size:18px"` on the `<h2>` rather than extending a
  shared class.

If your widget renders content from one of these areas and you
based the size on the class rule alone, you are probably wrong.

### 18.6 Per-widget font-size checklist

For every `Text` / `RichText` / `TextSpan` / `InputDecoration`
`hintStyle` / `Tab` label that ships, verify:

1. The text content matches a specific HTML element — search the
   HTML for the same literal string or its l10n source.
2. That element's effective `font-size` has been resolved per
   §18.2 (inline → ID → element-class → class → element → body).
3. The Flutter literal equals the resolved value (§18.3 table).
4. The literal is either declared on a named `AppTextStyles` entry
   or carries a trailing `// HTML line <n> — font-size:<Npx>.`
   comment citing the source.
5. The element is not in one of the §18.5 hotspot areas without
   an explicit inline-style check.
6. The value is in `.spMin`, not `.sp` and not a raw `double`.
7. If you had to use a size that isn't in the §18.3 table, stop —
   the HTML almost certainly doesn't use it either and you've read
   the wrong rule.

### 18.7 Size semantics (pick a role, not a raw number)

To keep `app_text_styles.dart` coherent across screens, think in
roles first and pick the px second. These are the sizes the
prototype actually uses; new screens should stay within this set:

| Role                         | px | Example surfaces                                 |
| ---------------------------- | -- | ------------------------------------------------ |
| Display                      | 34 | Wallet balance (guest / KYC-later)               |
| Display-secondary            | 30 | Wallet balance (verified)                        |
| Hero title                   | 28 | KYC hero, empty-state hero                       |
| Screen title                 | 24 | `.screen-title`, modal headers                   |
| Section heading (sheet)      | 22 | Settings profile initial, sheet H2s              |
| Sub-hero / balance-small     | 20 | Wallet balance decimal, secondary numerals       |
| Card title                   | 18 | Small card titles, nav-section titles, icons-as-text |
| Field / subtitle prominent   | 17 | Account number, field labels                     |
| Body                         | 16 | Default paragraph, profile name, section label   |
| Input / button label         | 15 | Sign-in buttons, field values, quick-action H3   |
| Secondary body               | 14 | `.tx-title`, `.tx-amount`, settings row label    |
| Body-small / meta            | 13 | Screen subtitle, row subtitles, curated caption  |
| Caption / sub-meta           | 12 | `.tx-sub`, version label, mini-card labels       |
| Eyebrow / tag                | 11 | Section labels (uppercase), chip text            |
| Micro-meta                   | 10 | Trailing meta (date/time on mini-cards)          |
| Ultra-micro / badge          | 9  | Promo eyebrows, status micro-tags                |

Do not invent new sizes. If the design-team asks for one, route it
through `AppTextStyles` and this table simultaneously.

### 18.8 Step-by-step font-size audit protocol

Run this before opening the PR for any screen. It mirrors §16.8 /
§17.8 so engineers can cycle through the three passes without
reloading context.

1. **Grep the Flutter file for every size literal:**
   `grep -n "fontSize:" <file>`. Record every line.
2. **For each line, locate the HTML element.** Search the prototype
   for the text content the Flutter widget renders (or the l10n
   source string). Note the HTML line number.
3. **Resolve the effective size** per §18.2 — inspect the element's
   own `style="…"` attribute first, then walk the selector chain.
4. **Compare** with the §18.3 table. Any delta is a defect.
5. **Check §18.5 hotspots** — if the widget sits in one of those
   areas and you derived the size from a class rule, go back and
   inspect the live inline style.
6. **Fix mismatches** by editing the literal and adding a trailing
   comment of the form `// HTML line <n> — font-size:<Npx>.` so
   the next reviewer can verify without re-greping.
7. **Check for the default-16 trap (§18.4)** — for every "muted
   body" Text with no class-level size, verify the HTML really
   declares one; if it doesn't, Flutter must use `16.spMin`.
8. **Re-grep for bare doubles:**
   `grep -n "fontSize: [0-9]" <file>` — anything not followed by
   `.spMin` is a bug.
9. **Record findings** in the PR description — list the HTML line
   numbers consulted and any new `AppTextStyles` entries added.

### 18.9 Review gate (must pass before the PR merges)

Every screen-migration PR must satisfy the following gates before
it can merge. This extends the §15 Definition of Done and the
§16.9 / §17.9 gates — font-size is its own gate because size bugs
are the most visually obvious of the three passes:

* [ ] Every `fontSize:` literal in the changed files is either
      declared on an `AppTextStyles` named style **or** carries a
      trailing `// HTML line <n> — font-size:<Npx>.` comment.
* [ ] Every literal ends in `.spMin` (no `.sp`, no raw `double`).
* [ ] `grep -n "fontSize: [0-9]" <file>` returns zero hits that
      aren't followed by `.spMin`.
* [ ] Every amount / balance / price / mini-card numeral has been
      verified against the *inline* HTML style, not just its class
      rule (§18.5 hotspots).
* [ ] Every muted / meta text without a class-level `font-size` is
      using `16.spMin`, not a guessed 14.
* [ ] Every size used is in the §18.7 role table — no one-off
      magic numbers outside that set.
* [ ] Both light-mode and dark-mode screenshots show the same
      vertical rhythm as the HTML rendered in Chrome at 390×844.
* [ ] The PR description lists the HTML line numbers consulted and
      any new `AppTextStyles` entries added.

A PR that fails any of these gates is rejected, regardless of how
polished the logic is.

---

## 19. No Comments Rule (every migration)

**Hard rule — no comments of any kind in migration code. Zero. None.**

This applies to every file produced or modified as part of an HTML → Flutter migration:

- No `//` single-line comments.
- No `/* … */` block comments.
- No `///` doc-comments on classes, methods, fields, parameters, or files.
- No HTML-line-number anchors (e.g. `// HTML line 13480`).
- No TODO / FIXME / NOTE / XXX markers.
- No explanatory headers like `// ── Header ──` separating sections.
- No "why" commentary, no "mirrors JS function X" commentary, no migration breadcrumbs.
- No ARB `@key` description strings beyond what `flutter_localizations` requires to parse — if a description is optional, omit it.

Code must stand on its own. Use precise naming, small widgets, and clear structure instead of prose. If something needs explanation, the name, the type, or the structure is wrong — fix that, don't paper over it with a comment.

Applies to: `.dart` files, generated code overrides, widget trees, helper classes, extension methods, enums, test files, and any new file created during migration. Pre-existing comments in already-migrated files may remain until that file is next touched, at which point they must be removed as part of the edit.

Reviewers reject any PR that adds a comment. No exceptions, no "this one is important", no "just this once".

---

## 20. Feature-Scoped Domain Layout (every migration)

**Hard rule — domain, enums, data, and logic live INSIDE each feature, never at the module root. `domain/` contains only `entities/` and `use_cases/`.**

Follow the foodie clean-architecture pattern exactly (see `foodie_user_mobile_app_interface/lib/modules/authentication/features/sign_up/presentation/logic/` for the reference layout):

```
modules/<module>/features/<feature>/presentation/
├── logic/
│   ├── controller/
│   ├── data/
│   │   ├── datasources/
│   │   ├── models/
│   │   └── repositories/
│   ├── domain/
│   │   ├── entities/<entity>/<entity>.dart  (+ .freezed.dart, .g.dart)
│   │   └── use_cases/<use_case>.dart
│   ├── enums/<enum>.dart
│   ├── methods/<fn>.dart
│   └── sample_data/<file>.dart
└── ui/
    └── widgets/
```

Rules:

- Entities live at `features/<feature>/presentation/logic/domain/entities/<entity>/<entity>.dart`. One entity per file, each in its own folder alongside its generated `.freezed.dart` / `.g.dart` parts. Multiple data classes NEVER share a file.
- Entities are freezed data classes only. No methods, no helper functions, no computed getters beyond what freezed generates, no static factories for sample/mock data, no formatters, no computation helpers.
- Use cases live at `features/<feature>/presentation/logic/domain/use_cases/<use_case>.dart`. One per file.
- Enums live at `features/<feature>/presentation/logic/enums/<enum>.dart` — sibling of `domain/`, NOT inside it.
- Pure functions / computations live at `features/<feature>/presentation/logic/methods/<fn>.dart`.
- Mock / sample data lives at `features/<feature>/presentation/logic/sample_data/<file>.dart`.
- Repositories / data sources / models live at `features/<feature>/presentation/logic/data/`.
- Controllers (Riverpod notifiers, etc.) live at `features/<feature>/presentation/logic/controller/`.
- **Nothing** domain-related lives at `modules/<module>/` root outside of `commons/` and `features/` (no `modules/<module>/domain/`, `modules/<module>/entities/`, `modules/<module>/enums/`, `modules/<module>/methods/`, or `modules/<module>/sample_data/` at the module root).
- Before placing an entity / enum / method / sample_data / util, grep all consumers. Pick the scope that matches:
  - **One feature only** → nest it under that feature's `presentation/logic/` (e.g. `features/<feature>/presentation/logic/domain/entities/<entity>/<entity>.dart`).
  - **Multiple features in the same module** → it is MODULE-SHARED and lives in `modules/<module>/commons/`.
  - **Multiple modules** → it is APP-SHARED and lives in `modules/commons/` (the top-level commons).
- Module-level and app-level commons use the SAME internal layout — just different scope:
  - `commons/domain/entities/<entity>/<entity>.dart`
  - `commons/enums/<enum>.dart`
  - `commons/methods/<fn>.dart`
  - `commons/sample_data/<file>.dart`
  - `commons/utils/<util>.dart`
- Move up, never down: when a module-scoped commons file starts being imported by a second module, PROMOTE it to `modules/commons/` and update all imports at once. Never duplicate.
- Top-level `modules/commons/` should contain nothing module-specific — audit it during any PSS / auth / settings / etc. migration.

Anything that is not an entity or a use case MUST NOT be inside `domain/`. If a module has grown helpers, enums, sample data, or format functions at the module root, move them into the owning feature's `presentation/logic/` tree before adding new code.

---

*Source anchors (for quick cross-reference while porting):*

* Foodie pattern root: `/Users/ebube.okocha/StudioProjects/foodie_user_mobile_app_interface/lib/`
* HTML prototype: `/Users/ebube.okocha/Downloads/Kalabash mobile 2/index.html`
* Design-system HTML: `kalabash-design-system_Ebube.html`
* Existing tokens: `/Users/ebube.okocha/StudioProjects/kalabash_mobile_v2/lib/modules/commons/theme/`

---

## 21. Cards Module Migration Notes

The `cards` module mirrors the HTML card prototype (`index.html` screens `#screen-card-*`, `#screen-fund-card*`). It follows the feature-scoped layout rule (§20) — every feature ships its own `presentation/logic/` tree.

**Module-shared state** — `modules/cards/commons/`

- `enums/card_tier.dart`: `CardTier { eliteDollar, naira, leisureDollar, deluxeDollar, virtualDollar, virtualNaira }`.
- `enums/card_hub_tab.dart`: `CardHubTab { ngn, usd, ngnVirtual, usdVirtual }` — drives the 4-tab hub on `CardDashboardPage` and is the state the home mini-cards set before pushing the dashboard.
- `enums/card_kind.dart`: `CardKind { physical, virtual }` — used by catalogue tiles + delivery flow.
- `state/card_hub_controller.dart`: `StateNotifier<CardHubTab>` exposed as `cardHubProvider`. Always switch the hub tab via `ref.read(cardHubProvider.notifier).setTab(...)` BEFORE pushing `CardDashboardRoute`; never mutate the state after the route is on top.
- `widgets/card_link_sheet.dart`: static `CardLinkSheet.show(context)` bottom sheet opened from the "Link an existing card" promo on `CardsDashPage`.

**Feature pages (all under `modules/cards/features/<feature>/presentation/`):**

| Feature folder | Page | HTML ref |
|---|---|---|
| `card_dashboard` | `CardDashboardPage` | `#screen-card-dashboard` |
| `physical_card_detail` | `PhysicalCardDetailPage({required CardTier tier})` | `#screen-card-physical-detail` |
| `virtual_card_detail` | `VirtualCardDetailPage({required CardTier tier})` | `#screen-card-virtual-detail` |
| `virtual_card_customise` | `VirtualCardCustomisePage({required CardTier tier})` | `#screen-card-virtual-order` |
| `virtual_card_success` | `VirtualCardSuccessPage` | `#screen-card-virtual-success` |
| `card_pickup_select` | `CardPickupSelectPage` | `#screen-card-pickup-select` |
| `card_pickup_delivery` | `CardPickupDeliveryPage` | `#screen-card-pickup-delivery` |
| `card_home_delivery` | `CardHomeDeliveryPage` | `#screen-card-home-delivery` |
| `card_order_success` | `CardOrderSuccessPage` | `#screen-card-request-success` |
| `card_transactions` | `CardTransactionsPage` | `#screen-card-transactions` |
| `card_txn_detail` | `CardTxnDetailPage({required CardTransaction txn})` | `#screen-card-txn-detail` / `#screen-card-txn-netflix` (unified by `TxnDirection`) |
| `fund_card` | `FundCardPage` | `#screen-fund-card` |

**Home → Cards hand-off pattern** (`modules/dash/features/home/presentation/ui/home_dash_page.dart`)

- Mini physical card tile (`_MiniCardPhysical`, `ConsumerWidget`) — on tap:
  ```dart
  ref.read(cardHubProvider.notifier).setTab(CardHubTab.usd);
  unawaited(AppNavigation.push(const CardDashboardRoute()));
  ```
- Mini virtual card tile (`_MiniCardVirtual`, `ConsumerWidget`) — same pattern but with `CardHubTab.usdVirtual`.
- "Get a new card" promo (`_MiniCardNew`, `StatelessWidget`) — switches the bottom-nav to Cards (no route push):
  ```dart
  onTap: () => AutoTabsRouter.of(context).setActiveIndex(1);
  ```
  Index 1 corresponds to `CardsDashRoute` in the `DashRoute` children list (`[HomeDashRoute, CardsDashRoute, RewardsDashRoute, TravelDashRoute]`).
- "See All" tile pushes `CardDashboardRoute` directly.

**Catalogue tile pattern** (`modules/dash/features/cards/presentation/ui/cards_dash_page.dart`)

- `_CardTileData` carries `required final CardTier tier` so the tile knows which detail screen to open.
- Every `_CardTile` wraps its body in an `InkWell(onTap: onTap, borderRadius: ..., child: Container(...))` — the `InkWell` provides the ripple, the `Container` holds the existing gradient/background. Do NOT wrap the whole tile in a `GestureDetector` — it kills the ripple.
- Physical tiles push `PhysicalCardDetailRoute(tier: t.tier)`.
- Virtual tiles push `VirtualCardDetailRoute(tier: t.tier)`.
- "Link an existing card" promo wraps its row in the same InkWell and calls `unawaited(CardLinkSheet.show(context))`.

**Routing rules**

- Routes are registered in `lib/modules/commons/navigation/app_router.dart` (human-edited) — every `AutoRoute(page: ...)` entry must have a matching `PageRouteInfo` class in `app_router.gr.dart` with a `static PageInfo page`.
- `app_router.gr.dart` is normally generated by `fvm dart run build_runner build --delete-conflicting-outputs`. **If you hand-edit it** (e.g. the tool-chain is unavailable), match the existing alphabetical-by-code-point ordering. Uppercase code points sort before lowercase, so `CardsDashRoute` comes after every `Card*Route` with a non-`s` third character.
- Routes that carry arguments (`PhysicalCardDetailRoute`, `VirtualCardDetailRoute`, `VirtualCardCustomiseRoute`, `CardTxnDetailRoute`) have a sibling `*RouteArgs` class with `key`, the required args, `toString`, `==`, `hashCode` — mirror the generated shape exactly.
- Whenever you add a new page, re-run build_runner before merging. Hand-edits are a stop-gap, not a style.

**Bottom-nav highlight** — `DashPage` uses `AutoTabsRouter` + `setActiveIndex(int)`. Any tile that wants to put "Cards" on top of the screen *without* stacking a route does `AutoTabsRouter.of(context).setActiveIndex(1)`. Do not push `CardsDashRoute` from within the dash shell — that creates a duplicated tab widget.

**l10n** — every string in `cards/*` reads from `context.l10n`. Keys are namespaced (`cardTxnDetail*`, `cardDashboard*`, `fundCard*`, etc.) and live in `lib/l10n/arb/app_en.arb` + `lib/l10n/l10n.dart` abstract.

---

## 22. Toasts & Alerts — `KalabashAppNotification` is the only path

**Hard rule — every user-facing alert, toast, snack, confirmation-banner, or transient success/error message in migrated code MUST be raised through `KalabashAppNotification`. No exceptions.**

This replaces every form of ad-hoc notification UI. If a screen needs to tell the user that something happened, it calls the app notification helper — not Flutter's `ScaffoldMessenger`, not a bespoke overlay, not a custom `AnimatedPositioned` banner.

**Banned APIs in migration code:**

- `ScaffoldMessenger.of(context).showSnackBar(...)`
- `ScaffoldMessenger.of(context).showMaterialBanner(...)`
- `showDialog(... SnackBar ...)` style inline popups
- Any hand-rolled `OverlayEntry` that displays a toast-like widget
- `print` / `debugPrint` used as a "temporary" toast substitute

**Correct pattern — service resolution:**

`KalabashAppNotification` is registered as a singleton in `lib/modules/commons/di/di.dart`. Fetch it from the locator where you need it:

```dart
import 'package:kalabash_mobile_v2/modules/commons/di/di.dart';
import 'package:kalabash_mobile_v2/modules/commons/helpers/kalabash_app_notification.dart';

locator.get<KalabashAppNotification>().success(message: 'All notifications marked as read');
locator.get<KalabashAppNotification>().error(message: 'We could not reach the server.');
```

**Where the call belongs:**

- Prefer **controllers** — controllers already sit on top of the service layer and can route success/error branches through `ApiHelper.handleResponse`, which calls `KalabashAppNotification` automatically on failure (see §9).
- Page-level callbacks (`onTap`, `onSubmitted`, `onPressed`) may call `KalabashAppNotification` directly for UI-only confirmations (e.g. "copied to clipboard", "all notifications marked as read") where there is no service call.
- Never call it from `build` methods, `initState`, or inside `Provider` construction — all three are either called before the first frame or re-run on rebuild and will flash duplicate toasts.

**Public surface (`lib/modules/commons/helpers/kalabash_app_notification.dart`):**

- `.success({required String message})` — green success toast, hard-codes title `'Success'`.
- `.error({required String message})` — red error toast, title is internal to `KalabashAlert`.

If a screen needs a neutral / info variant, extend `KalabashAppNotification` — do not open-code a new overlay on the screen itself.

**Messages:**

- Wire messages through `context.l10n` when the screen is part of a localised module. Hard-coded English strings are only acceptable for migrations where the surrounding screen is also still hard-coded (will be swept in a single l10n pass).
- Keep messages short (≤ 60 chars, sentence case, no trailing period in success toasts — align with existing usage in `ApiHelper.handleResponse`).

**Review gate:**

- `grep -R "ScaffoldMessenger" lib/modules/` must return **zero** hits in migration code. Only the commons helpers themselves are allowed to mention it (and today, none of them do).
- Any PR that introduces a new `SnackBar(...)` in a migrated feature is rejected.

---

## 23. Freezed Rule — controller state and model classes

**Hard rule — every controller state class and every model class MUST be a `@freezed` class. No hand-rolled data classes. No constructor-list initializer patterns. No exceptions.**

This consolidates the scattered mentions in §1.5, §1.8, §6, and §20 into a single enforceable rule. If a class carries data, it is `@freezed`.

### 23.1 What must be `@freezed`

**Controller state classes — MUST be `@freezed`.**

Every `StateNotifier`'s `<Feature>ControllerState` (or `<Screen>ControllerState`, `<Widget>ControllerState`) is a `@freezed` class. It ships alongside `<feature>_controller.freezed.dart` generated by `build_runner`.

- The file lives at `features/<feature>/presentation/logic/controller/<feature>_controller.dart` and declares `part '<feature>_controller.freezed.dart';`.
- The state class is the ONLY data-carrying class in that file.
- The controller itself (`StateNotifier<_>`) is NOT freezed — only its state is.

**Model classes — MUST be `@freezed`.**

This covers every project-owned data-carrying class:

- **Entities** (`domain/entities/<entity>/<entity>.dart`) — request shapes, response shapes, outcomes, value objects, view-models.
- **DTOs** at `data/models/<model>.dart` when the API does not already hand us a typed response (see §23.6).
- **Commons domain entities** (`commons/domain/entities/<entity>/<entity>.dart`) — e.g. `User`.
- **Sealed/union results** — e.g. `PhoneVerificationResult`, `OtpVerificationResult`, `OnboardingStepOutcome`, `PhoneCheckOutcome`, `TokenRefreshResult`. These MUST be `@freezed` sealed unions with named factories (`.success(...)`, `.failure(...)`), NOT hand-rolled classes with private named constructors and initializer lists.
- **Any other class whose sole purpose is carrying immutable fields.** If you find yourself writing `const MyClass(this.a, this.b);` followed by `final A a; final B b; @override bool operator ==(...);` — stop. Use `@freezed`.

### 23.2 What is NOT freezed

Not everything is a data class. These stay hand-written:

- **Controllers themselves** (`StateNotifier<State>` subclasses) — they hold methods, not data.
- **Services / service impls / use cases** — behavior, not data.
- **Widgets** (`ConsumerWidget`, `ConsumerStatefulWidget`) — they are not data classes even though they have `final` fields.
- **Enums** — plain Dart enums, not freezed. (If you need a discriminant inside a freezed union, use a `@freezed` sealed class, not an enum.)
- **Helpers / utilities / formatters / extensions** — behavior.
- **Generated backend types** from `kalabash_backend/` — they are already value-typed; do not re-freeze them.

### 23.3 Canonical shape

**Controller state:**

```dart
import 'package:freezed_annotation/freezed_annotation.dart';

part '<feature>_controller.freezed.dart';

@freezed
abstract class <Feature>ControllerState with _$<Feature>ControllerState {
  factory <Feature>ControllerState({
    @Default('') String email,
    @Default(false) bool isSubmitting,
    String? errorMessage,
  }) = _<Feature>ControllerState;

  <Feature>ControllerState._();

  factory <Feature>ControllerState.withDefaults() => <Feature>ControllerState();

  bool get isValid => email.isNotEmpty;
}
```

**Entity / request / response:**

```dart
import 'package:freezed_annotation/freezed_annotation.dart';

part '<entity>.freezed.dart';
part '<entity>.g.dart';

@freezed
abstract class <Entity> with _$<Entity> {
  const factory <Entity>({
    required String id,
    required String name,
  }) = _<Entity>;

  factory <Entity>.fromJson(Map<String, dynamic> json) =>
      _$<Entity>FromJson(json);
}
```

**Sealed result / outcome union (replaces hand-rolled `_(this.status)` patterns):**

```dart
import 'package:freezed_annotation/freezed_annotation.dart';

part 'onboarding_step_outcome.freezed.dart';

@freezed
sealed class OnboardingStepOutcome with _$OnboardingStepOutcome {
  const factory OnboardingStepOutcome.success({
    String? sessionToken,
    OnboardingNextStep? nextStep,
  }) = OnboardingStepOutcomeSuccess;

  const factory OnboardingStepOutcome.failure({String? errorMessage}) =
      OnboardingStepOutcomeFailure;
}
```

Callers pattern-match with `switch` or `result.when(...)` / `result.map(...)`. Add a `bool get succeeded => this is OnboardingStepOutcomeSuccess;` extension in the same file if read-sites need a boolean shortcut.

### 23.4 Banned patterns

These patterns appear in the current codebase and MUST be converted to `@freezed` the next time the file is touched:

- Hand-rolled private named constructor with one positional and multiple initializer-list variants:
  ```dart
  class TokenRefreshResult {
    const TokenRefreshResult._(this.status);
    const TokenRefreshResult.success(User user)
        : status = TokenRefreshStatus.success,
          user = user,
          errorMessage = null;
    // …
  }
  ```
  This is the exact shape that regressed during the API-integration branch (a stray edit to `TokenRefreshResult._(this.status)` silently dropped the `{this.user, this.errorMessage}` optional params and broke compilation). Freezed generates the equivalent code and makes that regression impossible.

- Hand-rolled `copyWith`, `==`, `hashCode`, or `toString` on a data class. If you need them, the class is data — use `@freezed`.

- Using a bare Dart enum where variants carry data (e.g. "OTP result" with a message). Use a `@freezed sealed class` union instead.

- Mutable state fields on a controller that aren't in its `@freezed` state (e.g. `String? temporaryPhone;` on the class body). If a field affects UI or outcomes, move it INTO the freezed state; if it's genuinely private orchestration memory, that's tolerated but flagged in review.

### 23.5 Entity hygiene (reinforces §20)

- **One class per file.** Never share a file between two `@freezed` classes, even tiny ones. Each entity gets its own folder: `entities/<entity>/<entity>.dart` + `<entity>.freezed.dart` + `<entity>.g.dart` (the last only if the entity needs JSON).
- **No methods on entities.** Pure data only. No computed getters beyond what freezed generates, no static `.sample` factories, no formatters. If you need a derived value, put it on a `methods/` function or an extension in the same file.
- **No cycles.** Entity A must not import entity B that imports A. Break with a shared enum or a smaller value type.

### 23.6 When `data/models/` may be absent

§6 shows `data/models/` for DTO / response shapes. When the service impl types its `handleApiCall` against a generated `kalabash_backend` response (e.g. `ResultOfOnboardingV2CheckPhoneResponse`), there is no project-owned DTO to create — the generated type IS the model layer. In that case `data/models/` may be absent. As soon as ANY hand-rolled mapping class appears (e.g. to flatten or re-key a response), it MUST be a `@freezed` class at `data/models/<model>.dart`.

### 23.7 Build & codegen requirements

- `pubspec.yaml` must include `freezed_annotation` under `dependencies` and `freezed` + `build_runner` under `dev_dependencies`. For JSON-serialized entities add `json_serializable` and `json_annotation`.
- Every freezed file MUST declare its `part` directives:
  ```dart
  part '<file>.freezed.dart';
  part '<file>.g.dart'; // only if .fromJson/.toJson is needed
  ```
- After adding or changing a freezed class, run:
  ```
  fvm dart run build_runner build --delete-conflicting-outputs
  ```
  Commit the generated `.freezed.dart` / `.g.dart` files alongside the source — they are checked in, not gitignored.
- CI must include a `flutter analyze` step that fails the build on any `_$<Class>` symbol referenced without the corresponding generated file.

### 23.8 Review gate (must pass before the PR merges)

Every PR must satisfy every gate below in the files it touches:

- [ ] Every controller state class is `@freezed`. `grep -rn "class .*ControllerState {" lib/modules/` returns only matches inside generated files — zero hand-rolled hits.
- [ ] Every entity under `domain/entities/` is `@freezed`. `grep -rnL "^@freezed" lib/modules/**/domain/entities/**/*.dart` (excluding generated files) returns zero matches.
- [ ] Every result / outcome / response union is a `@freezed sealed class` (or `@freezed abstract class` for non-discriminated shapes) — no hand-rolled private-ctor + initializer-list classes remain.
- [ ] Every freezed file declares the correct `part` directives and its generated partner files are committed.
- [ ] `fvm dart run build_runner build --delete-conflicting-outputs` succeeds with no conflicts after the change.
- [ ] `fvm flutter analyze` reports zero errors AND zero warnings on the changed files.

A PR that fails any of these gates is rejected, regardless of how polished the UI or logic is.

