# Drivio Driver — Context Handoff

This file is the running state of the **Drivio Driver** app for handing off to a fresh Claude session. Read it top to bottom before touching code; it captures the things that aren't obvious from the source tree alone — the why behind decisions, the schema gotchas, the current backlog position, and the conventions that hold the codebase together.

Last updated: 2026-05-04.

---

## 1. Project basics

- **App**: Drivio Driver — Flutter ride-hailing driver app for the Nigerian market (Lagos primarily, WAT timezone, Naira currency).
- **Flutter package name**: `drivio_driver` (in `pubspec.yaml`). Every internal import is `package:drivio_driver/...`.
- **Backend**: Supabase. Two projects exist:
  - `Drivio Driver` (display label was changed to "Drivio") — id **`gxzyednqegqycnmbdghf`** — the only one this app talks to.
  - `Drivio User` — id `zimiopszteiznopqeyfh` — passenger app, separate.
- **Authoritative spec**: `driver.md` at repo root (1355 lines, ~101 tickets DRV-001..DRV-101). Every ticket has Epic / Priority / Complexity / Order / Depends-on metadata.
- **Other repo docs**: `knowledge.md`, `driver_context.md`, `MIGRATION.md`, `README.md`.
- **User preference**: No tests — focus on app code only. Skip writing test files even when tempted.
- **Auto mode**: Often active. The user expects autonomous execution with reasonable assumptions. They explicitly told me to **ask questions when unclear**, which I should still respect even in auto mode.

---

## 2. Architecture conventions

- **State**: Riverpod `StateNotifier` + manual `copyWith`. **No freezed.** Each feature has `presentation/logic/controller/<name>_controller.dart` with a `<Name>State` class plus `<Name>Controller extends StateNotifier<...>` plus a `<name>ControllerProvider`.
- **DI**: `get_it` via `lib/modules/commons/di/di.dart`. Every repository registered as `registerLazySingleton<Interface>(() => SupabaseImpl(locator<SupabaseModule>()))`.
- **File layout**: feature-based clean arch — `lib/modules/<area>/features/<feature>/presentation/{logic/controller,logic/data,ui}/...`. Repositories live in `lib/modules/commons/data/<thing>_repository.dart` (interface) + `<thing>_repository_impl.dart`. Types in `lib/modules/commons/types/`.
- **Theme**: dark-first, brand accent green `#5EE4A8`. Accessed via `context.accent`, `context.text`, `context.surface` (etc.) extension getters. Text styles in `AppTextStyles` (Inter family). Defined in `lib/modules/commons/theme/`.
- **Money**: stored as `bigint` minor units (kobo). Display via `NairaFormatter.format(naira)` — convert with `~/ 100` before passing in.
- **`.autoDispose.family<…, String>`** providers keyed by tripId/requestId for per-entity controllers. **Always guard async state writes with `if (!mounted) return;`** because autoDispose can fire mid-await.
- **Single shared root map** (Uber-style) — `DriveShellPage` orchestrates `idle | bidding | trip | tripCompleted | tripCancelled` modes via `DriveShellController`. Bottom sheets transition state, not separate routes. `LiveMap` widget supports markers, polylines, polygons.
- **All RPC calls go through `loggedRpc(_supabase, 'fn_name', params: {...})`** when added recently — emits structured logs (request, response shape, errors with PostgrestException details). See "Logger" section below.

---

## 3. Database state — tables and RPCs

### Tables in `public`
- `profiles` — `user_id, full_name, phone_e164, email, dob, gender, avatar_url, referral_code, referred_by, created_at`
- `drivers` — `user_id, kyc_status, bvn_verified_at, nin_verified_at, liveness_passed_at, home_address, service_city, has_used_trial, deleted_at, created_at`
- `vehicles` — `id, driver_id, make, model, year, colour, plate, vin, seats, category, status, deleted_at`
- `documents` — `id, owner_user_id, kind, vehicle_id, file_path, expires_on, status, rejection_reason, reviewed_by, reviewed_at`
- `subscriptions` — `id, driver_id, plan_id, status, trial_ends_at, current_period_start, current_period_end, paystack_subscription_code`
- `subscription_plans` — `id, code, name, price_minor, currency, interval`
- `wallets` — `driver_id, balance_minor, currency, updated_at`
- `wallet_ledger` — `id, driver_id, kind, amount_minor, currency, reference_id, description, created_at` (kinds: `trip_credit, payout_debit, refund, adjustment, subscription_debit`)
- `payouts` — `id, driver_id, amount_minor, currency, status, paystack_transfer_code, bank_account_masked, failure_reason, settled_at`
- `trips` — `id, ride_request_id, bid_id, driver_id, vehicle_id, passenger_id, fare_minor, currency, state, started_at, ended_at, cancellation_reason, actual_distance_m, actual_duration_s` (states: `assigned, en_route, arrived, in_progress, completed, cancelled`)
- `trip_events`, `trip_locations`
- `ride_requests`, `ride_bids`
- `driver_presence` — current state only, no history
- `passenger_ratings` — driver→passenger (driver_id is rater)
- **`driver_ratings`** — passenger→driver (NEW — DRV-078). RLS lets driver read their own + passenger see what they wrote
- **`driver_pricing_profile`** — `driver_id PK, base_minor, per_km_minor, peak_multiplier, peak_enabled, night_multiplier, night_enabled, preferences jsonb` (preferences holds `max_pickup_km`, `trip_length`)
- **`trusted_contacts`** — `id, user_id, name, phone_e164, is_primary, created_at` (cap 3 per user, partial-unique index for one primary)
- **`driver_payout_accounts`** — `driver_id PK, bank_name, account_number_last4, account_name, paystack_recipient_code, created_at, updated_at` — **bank_code column was dropped** (Q2 of profile wiring); Paystack resolves bank from account number alone
- `notifications` (with inbox), `messages`, `safety_events`

### Custom enums (`pg_type` in `public`)
- `document_kind_t`: `drivers_licence, vehicle_reg, insurance, road_worthiness, lasrra, inspection_report, profile_selfie`
  - **Note**: there is no `background_check` value. The profile UI's "Background check" row is mapped to `road_worthiness` per Q1.
- `document_status_t`: `pending, approved, rejected, expired`
- `kyc_status_t`: `not_started, in_progress, pending_review, approved, rejected`
- `subscription_status_t`: `trialing, active, past_due, cancelled, expired`
- `trip_state_t`, `vehicle_status_t`, `ledger_kind_t`, etc.

### RPCs (functions) added or modified recently
- **`get_or_create_my_pricing_profile()`** — DRV-069. Lazy-creates row on first call.
- **`get_my_dashboard_today()`** — today's earnings/trips/online-seconds/rating tile data. WAT-anchored "today". **Two SQL bug fixes already applied here**: (1) `kyc_status` ambiguity → use table aliases; (2) `online_seconds` was always 0 because `actual_duration_s` is null on trips → falls back to `EXTRACT(EPOCH FROM (ended_at - started_at))`.
- **`get_my_profile_summary()`** — joined_at/kyc_status/has_active_vehicle/active_vehicle_model/lifetime_trips/lifetime_earnings_minor/rating_avg/rating_count. Same `kyc_status` ambiguity bug appeared here too — fixed by aliasing every CTE table (`drivers d`, `vehicles v`, `trips t`, `driver_ratings r`).
- **`get_my_referral_summary()`** — my_code + total/active/pending counts of referred drivers.
- **`get_my_driver_rating_summary()`** — DRV-078. Lifetime + 30-day average, per-star distribution.
- **`list_my_recent_driver_ratings(p_limit)`** — DRV-078. Joins to `profiles.full_name` for passenger names.
- **`get_my_coach_tips(p_limit)`** — DRV-074. Hand-curated 7-rule set (Friday peak, peak-off, low-win-rate, high-cancel, rating-drop, strong-day, slow-week). Returns `code, severity, emoji, title, body, cta_label, cta_route`.
- **`get_demand_heatmap(p_minutes, p_max_cells)`** — DRV-075. Aggregates `ride_requests.pickup_geohash6` over trailing window, returns `cell_id, center_lat, center_lng, cell_lat_span, cell_lng_span, request_count`. Uses PostGIS `ST_PointFromGeoHash` / `ST_GeomFromGeoHash`.
- **`get_my_monthly_earnings(p_months)`** — DRV-072. Year-tab buckets.
- **`get_my_earnings_summary(p_window_days)`**, **`get_my_daily_earnings(p_days)`**, **`get_my_acceptance_metrics(p_days)`** — already existed for earnings page.
- **`is_driver_active(driver_id)`** — DRV-032. SECURITY DEFINER bool. Returns true for `trialing/active/past_due` (3-day Paystack grace).
- **`submit_bid(...)`** — DRV-032 hardened. Now calls `is_driver_active(auth.uid())` and raises `subscription_required` if false. Also still validates trip-not-in-progress, request-still-open, etc.
- **`request_account_deletion()`** — DRV-090. Refuses if active trip exists, otherwise stamps `drivers.deleted_at`.
- **`set_primary_trusted_contact(p_id)`** — DRV-081. Atomically demote the existing primary then promote the target so the partial-unique index never trips mid-update.
- **`trigger_sos`** — pre-existing SOS RPC. Updated to include `trusted_contacts` array in the `safety_events.payload` jsonb.
- **`accept_my_latest_pending_bid()`**, **`accept_test_bid`** — dev shortcuts for simulating passenger acceptance.

### Recurring SQL gotcha
**Column ambiguity (Postgres error `42702`)** — when a `RETURNS TABLE(...)` function declares an OUT param with the same name as a real column you query, Postgres can't disambiguate. **Always use table aliases** in CTEs and reference columns as `t.col_name`. Hit twice already (`kyc_status` shadow on both `get_my_dashboard_today` and `get_my_profile_summary`). Default to aliasing every table from the start.

---

## 4. Implemented features (by ticket)

### Foundational (already done before this session)
- Auth (DRV-010..015), KYC (DRV-016..021), vehicle add (DRV-022..025), subscription/Paystack (DRV-026..033, mostly), online toggle (DRV-034..039), marketplace + bidding (DRV-040..051), active trip lifecycle (DRV-052..060) including the geofence-arrived guard removal (TODO(DRV-055)), realtime chat/call (DRV-061..063), earnings + wallet (DRV-064..068), safety SOS hold-to-activate (DRV-080), notifications inbox (DRV-088), profile editor (DRV-076), single shared root map (DriveShellPage).

### Tier C — Pricing strategy + trusted contacts + account deletion
- **DRV-069 + DRV-070** — pricing strategy:
  - `PricingProfile` model w/ `baseMinor, perKmMinor, peakMultiplier, peakEnabled, nightMultiplier, nightEnabled, maxPickupKm, tripLength` (jsonb-backed).
  - `PricingController` with **500ms debounced save** that collapses rapid edits.
  - **Peak/night surcharge wired** into `RideRequestController._suggestedForRequest(req)` via `PricingProfile.suggestFor(distanceM, requestedAt)` → applies multiplier when `(peak/night)Enabled && hour in window`. Windows: peak 06–08:59 + 17–19:59, night 22–04:59 (all WAT/local).
  - Bid composer (`bidding_body.dart`) shows `PEAK · 1.5×` (amber) or `NIGHT · 1.2×` (blue) pill next to "Suggested ₦X" when active.
  - **`PricingProfile.roundToNearestNaira100`** static helper is the single rounding-to-₦100 helper used by both the controller's suggested fare AND the pricing-page preview, so they can never drift.
  - Pricing page preview shows real values + applies same rounding. Caption: `₦600 base + ₦200/km × 8 km = ₦2,200` (with `→ ₦X` tail when rounding diverges). Surcharge lines (`PEAK · 1.5× → ₦3,300`, `NIGHT · 1.2× → ₦2,640`) appear when toggles are on.
  - "Avoid zones" row removed.
  - **Max pickup distance + Preferred trip length** wired via `preferences` jsonb. Both filters honoured by **`visibleRequestsProvider`** (a derived Provider combining `marketplaceControllerProvider` + `pricingControllerProvider.profile`). Used by request feed, home page map markers, drive shell idle-mode markers — keeps map and feed in lockstep.
  - `PickupDistancePage` and `PreferredTripLengthPage` both rewritten to use the controller (live data, debounced save, no separate "Save" button).
- **DRV-081** — trusted contacts CRUD on safety page. Cap at 3, 1 primary enforced by partial-unique index. Bottom sheet for add/edit with E.164 validation.
- **DRV-090** — Delete account in `sign_out_page.dart` "DANGER ZONE". Two-step confirm requiring user types `DELETE`. Calls `request_account_deletion` RPC then signs out.

### Subscription gate (DRV-032)
- `SubscriptionStatus.unlocksMarketplace` returns true for `trialing/active/past_due`; `isHardBlocked` returns true for `expired/cancelled`.
- `drive_shell_page.dart` auto-flips driver offline when `home.isOnline && subHardBlocked && !shell.isTripLike`. **Trip-in-progress is sacred** — the post-trip handler (`onTripCompleted`) checks the same condition and offlines then.
- Marketplace channel is also `.stop()`-ed in the same hand-off so a stray request can't slip through.
- Server-side enforcement: `submit_bid` calls `is_driver_active(auth.uid())` and raises `subscription_required` on hard-block.

### Driver ratings (DRV-078)
- `driver_ratings` table (RLS gated; insert is RPC-only).
- `DriverRating` + `DriverRatingSummary` types.
- `DriverReviewsController` for the Reviews page (loads summary + recent in parallel).
- Reviews page rewritten — real distribution bars, top-tags chips derived client-side, time-ago, empty/error states.
- `get_my_dashboard_today` populates `rating` field — home tile reads from real driver ratings now (was a placeholder).

### Earnings analytics (DRV-072 + DRV-073)
- **`EarningsPeriod`** enum (`week/month/year`) on `WalletState`. Segmented tabs are now controlled and wired to `WalletController.setPeriod()`.
- `get_my_monthly_earnings` RPC for year view (12 monthly buckets — daily would be 365 bars).
- Smart axis labels: week = day initials, month = day-of-month every 5 days, year = month initials.
- Chart fades to 40% opacity during period switches so it doesn't blink.
- DRV-073 acceptance/cancellation tiles (existed) updated to reflect active period in their delta captions.

### Coach tips (DRV-074)
- `CoachTip` type (severity: `info/warning/win`), repository, controller (auto-refresh every 5 min, session-level dismiss).
- Card surfaced in the home bottom sheet between metrics tile and request feed. Severity-themed (amber/accent/blue), dismissable with ×, tap-through CTA when the rule provides one.

### Demand heatmap (DRV-075)
- `DemandCell` type, repo, `DemandHeatmapController` (auto-refresh every 5 min while visible).
- Heatmap toggle button on idle-mode top overlay (fire icon, theme-tinted amber when active).
- Polygon overlay added to `LiveMap` — each geohash6 cell becomes a coloured rectangle with a 5-step intensity ramp (teal → amber → orange → red), opacity 0.18–0.6 by intensity.

### Today's tile dashboard
- `get_my_dashboard_today()` RPC + `DashboardSummary` type + `DashboardController`.
- Auto-refresh every 60s + on trip completion + on going-online + on auth state change.
- **Cold-start race handling**: if the first call fails (no JWT yet), backoff retry 2s/5s/15s + listens to `Supabase.auth.onAuthStateChange` for `signedIn/tokenRefreshed/initialSession`.
- **Tile UX**: distinguishes "first load pending" (`—`) from "loaded and genuinely zero" (`₦0`). Inline error banner with **TAP TO RETRY** when `!hasEverLoaded && error != null`.

### Profile hub (full rewire)
- `get_my_profile_summary()` RPC powers header (joined date, kyc_status), stats row (Joined / Lifetime / Vehicle), VERIFIED pill (`kyc_status == 'approved' && hasActiveVehicle`).
- `ProfileHubController` loads profile + summary + active vehicle + KYC snapshot + top review in parallel; pull-to-refresh works.
- **Joined date format**: `May 2026` (not `May '26` — apostrophe-year was being misread as "May 26th"). See `_monthYear()` helper.
- **All document rows route to the existing KYC `DocumentCapturePage`** with the appropriate `DocumentKind` argument (per Q3 — re-use onboarding flow). Insurance/Inspection/per-doc rich detail pages were **deleted**: `InsurancePage`, `InspectionPage`, `DocumentPage` files gone, routes removed.
- "Background check" maps to `DocumentKind.roadWorthiness` (per Q1).
- VEHICLE row reads from active `vehicles` row; falls back to "Add a vehicle" CTA when none exists.
- REVIEWS card shows the most-recent real review.
- ACCOUNT — Subscription row uses live `subscriptionControllerProvider`; status pill colour-coded; days remaining real.
- ACCOUNT — Referral code from `profiles.referral_code`.
- Notification preferences row removed (Q4/Q7 — no server store yet).
- Card-on-file payment block removed entirely (Q2). `addCard` route deleted, `cards/` module directory deleted.
- `VehicleDetailsPage` reads from active vehicle; status badge from `vehicles.status`. Empty-state with "Add a vehicle" CTA when none.
- `ReferralPage` uses real `profiles.referral_code` + `get_my_referral_summary()` counts. "Free months earned" computed as `activeReferred * ₦15,000`. "Share code" button is currently a no-op (share-sheet integration is a follow-up ticket).
- **Loading skeleton** uses the [shimmer](https://pub.dev/packages/shimmer) package — `ProfileHubShimmer` renders 1:1 against the loaded layout (header avatar + name bars + status pill, three stat cards, five group cards). Single `Shimmer.fromColors` ancestor wraps everything (cheaper + visually consistent). `_VehicleDetailsShimmer` baked into the vehicle details page. `_ShimmerBox` helper class — placeholders MUST actually paint pixels (use a `BoxDecoration(color: Colors.white)`) for the shimmer gradient to land. Bare `Container(width:..., height:...)` won't tint.

### Manage payment / billing history
- `Manage payment` page (was Payment Methods). Cards-on-file completely removed.
- `driver_payout_accounts` table — one row per driver, RLS-gated. **`bank_code` column was dropped** — Paystack resolves bank from account number. Form fields are: Bank name, Account number (10-digit NUBAN, digits-only, length-limited), Account name.
- `PayoutAccount` model, repo, `PayoutAccountController` (also loads subscription debits from `wallet_ledger.subscription_debit` for billing history).
- Add/Edit bottom sheet, Remove with confirm sheet.
- Subscription manage page also rewired:
  - Plan name from `subscription.featuredPlan?.name` (was hardcoded `DRIVIO PRO`)
  - Price line `₦5,000/month` from `priceMinor / 100 + interval.label` (was hardcoded `₦15,000/mo`)
  - Status pill colour-coded
  - Progress bar = real fraction `(now - start) / (end - start)` clamped 0..1
  - Renew label adapts: `Trial ends X` / `Renews X` / `Was due X` / `Ended X`
  - Billing history rendered from `wallet_ledger` filtered to `subscription_debit` via new `SubscriptionManageController`
  - Card-on-file block removed; the duplicate "PAYMENT METHOD" sub-section is also gone
  - Both plan card and billing history have shimmer skeletons

### Splash page + location permission (just shipped)
- **`AppRoutes.splash = '/'`** (welcome moved to `/welcome`). All `AppRoutes.welcome` references unchanged because they use the constant.
- **`SplashPage`** is the always-first route. Owns: brand reveal animation + permission ask + waiting for bootstrap + hand-off via `pushReplacementNamed`.
- **Visual design**: dark backdrop with radial gradient. Continuous **radar pulse** behind the `DRIVIO` wordmark — three concentric green rings expanding outward on a 1.6s loop, staggered 0.4s apart. Wordmark is Inter 56pt weight 800 letter-spacing 5.5 with a vertical metallic gradient via `Paint..shader`. Below: `· BUILT TO MOVE LAGOS ·` eyebrow with two glowing accent dots. Bottom-anchored permission card slides up after the brand reveal.
- **`LocationPermissionService`** — wraps `Geolocator.checkPermission/requestPermission/isLocationServiceEnabled` into a single 4-state enum: `granted / denied / permanentlyDenied / serviceDisabled`. Has `request()`, `openAppSettings()`, `openLocationSettings()`. Registered in DI.
- **`SplashController`**: phases `brandReveal → askingPermission → proceeding`. On mount, probes permission silently in parallel with the 1100ms brand-reveal hold. If already granted → skip the card and proceed; otherwise show the card.
- **Permission card adapts** to state: `denied/unknown` → `Allow location` primary; `permanentlyDenied` → `Open settings`; `serviceDisabled` → `Open location settings`. Always has a `Not now` ghost button.
- **`LocationGateSheet`** — when the driver later taps "Go online" without a usable permission, this gate sheet pops up with the same adaptive copy/CTA. Built matching the `KycGateSheet` / `SubscriptionGateSheet` pattern.
- **`drive_shell_page.dart`** online-toggle path: replaces the old SnackBar with the gate sheet on permission failures. `_toGateReason()` static helper translates `PresencePermissionState` → `LocationPermState` so both surfaces share vocabulary.
- **`app.dart` simplified**: removed the `bootstrap.isLoading` branch + `onGenerateInitialRoutes` callback. MaterialApp always boots into `/`. The splash hands off via `pushReplacementNamed(bootstrap.initialRoute, arguments: bootstrap.initialArguments)` — `arguments` still flow through `onGenerateRoute` for the cold-start trip-resume case.

---

## 5. Logger (just shipped)

- **`logger: ^2.4.0`** package added.
- **`AppLogger`** at `lib/modules/commons/logging/app_logger.dart` — single static façade with `.d / .i / .w / .e`, structured `data:` map for key/value pairs, full stack on errors, **silenced in release builds** (debug + profile only via `_ReleaseFilter`).
- **`loggedRpc(module, fn, params: ...)`** at `lib/modules/commons/logging/supabase_logging.dart` — wrap any Supabase RPC call. Logs:
  - Outbound: `rpc → fn  ›  user=<uid> · params={...}`
  - Inbound success: `rpc ← fn  ›  ms=<duration> · shape=List(N)/Map(N keys)/null`
  - Inbound error: `rpc ✗ fn  ›  ms=<duration> · code=<code> · details=<details> · hint=<hint> · message=<message>` plus full stack
  - PostgrestException unpacked specifically — `code/details/hint/message` separately, not just toString
- Exported via `commons/all.dart`. **Use `loggedRpc` for any new RPC call** — it's how we caught the two `42702` ambiguity bugs. Existing repos haven't all been retrofitted.

---

## 6. Routing map

```
/                       splash (always first)
/welcome                welcome
/sign-in, /sign-up      auth
/otp                    OTP
/paywall                paywall
/kyc, /kyc/bvn-nin, /kyc/selfie, /kyc/document  KYC flow
/home                   DriveShellPage (the canvas)
/add-vehicle            AddVehiclePage
/earnings               earnings tab
/pricing                pricing tab
/profile                profile hub tab
/profile/vehicle        vehicle details
/profile/reviews        reviews page
/profile/payment-methods   manage payment (payout account + billing history)
/profile/referral       refer & earn
/profile/edit           profile editor (DRV-076)
/profile/help           static help topics
/profile/sign-out       sign-out + DANGER ZONE delete account
/notifications          notifications inbox
/subscription/manage    subscription manage page
/ride-request, /active-trip, /chat, /call, /safety
/vehicle/change         vehicle change
/pricing/pickup-distance       max pickup distance picker
/pricing/preferred-trip-length trip-length filter picker
/documents/reupload     re-upload document
/edge/* (no-requests, offline, sub-expired, rider-cancelled)
```

**Removed routes**: `addCard`, `insurance`, `inspection`, `docLicence`, `docRegistration`, `docBackground`, `notifications` (preferences page).

**Removed page files**: `cards/`, `profile/features/insurance`, `profile/features/inspection`, `profile/features/documents` (the per-doc detail page), `profile/features/notifications`.

---

## 7. Outstanding TODOs flagged in code

- **`TODO(DRV-055)`** — geofence guard around "I've arrived" button. User explicitly disabled this; restore later.
- **Online session tracking** — `online_seconds` in dashboard RPC is currently `SUM(actual_duration_s)` (with fallback to `ended_at - started_at`) of completed trips. Real proper tracking would need a `driver_online_session` table with start/end stamps recorded on `toggleOnline()`. Comment is in `dashboard_summary.dart`.
- **Share code** button on Referral page is a no-op pending share-sheet integration.
- Coach tip CTAs deeplink to existing routes (`/pricing`, `/profile/reviews`) only — add more as more rules ship.

---

## 8. Recommended next tickets (from prior audit)

Based on `driver.md` cross-referenced with the codebase. **Done**: DRV-032, DRV-069/070, DRV-072/073, DRV-074, DRV-075, DRV-076, DRV-078, DRV-081, DRV-088, DRV-090.

**Still unbuilt and high-value**:

### P0
- **DRV-055** — Arrived check-in via geofence. Restore the disabled guard.

### P1
- **DRV-062** — Masked voice calls (Africa's Talking or Twilio). Privacy-critical.
- **DRV-082** — Trip sharing link (public read-only URL with driver position + ETA, auto-revoked 1h after trip end).
- **DRV-083** — Incident report form (post-trip "report an issue" with categories).

### P2
- Online-session tracking table (real online hours, would replace dashboard proxy).
- Notification preferences server store (so the page can come back).
- Driver-side push notifications via FCM (DRV-006 — partial).

---

## 9. Style + UX conventions to keep

- **Inter** font, no other font families.
- Number rounding: nearest ₦100 for fare suggestions via `PricingProfile.roundToNearestNaira100`.
- Time format: full month + 4-digit year (`May 2026`), not `May '26` (gets misread).
- All times stored in UTC, displayed in WAT (`Africa/Lagos`) — RPCs anchor day boundaries to `Africa/Lagos` (no DST in Nigeria).
- Pill tones: `accent` (green good), `amber` (warning), `red` (bad), `blue` (info), `neutral` (off).
- Loading states use **shimmer** (`shimmer: ^3.0.0`) for any list/page that takes >100ms. Match the loaded layout 1:1 to avoid reflow. Placeholders need actual paint (`BoxDecoration(color: Colors.white)`) — bare `SizedBox` won't tint.
- Error UX preference: distinguishable from "loaded and empty". Use `—` for "not loaded yet", real values otherwise. Surface inline retry CTAs.
- Bottom-sheet gates (Kyc/Subscription/Location/Vehicle) all follow the same skeleton: dimmed scrim, centered icon disc, pill, h1 title, body, primary CTA, "Maybe later" text button.

---

## 10. Things to watch for

- **`42702` ambiguity** — when adding a `RETURNS TABLE(...)` RPC, alias every CTE table and reference columns by alias. The function's OUT parameters DO live in scope and shadow real columns.
- **`actual_duration_s` is null on trips** — the trip state machine doesn't populate it. Use `coalesce(actual_duration_s, EXTRACT(EPOCH FROM (ended_at - started_at)))` in any duration aggregate.
- **`vehicles.colour` is nullable** — handle the null case in any "Vehicle: <colour>" display.
- **Active vehicle look-up**: must filter `status='active' AND deleted_at IS NULL`. There may be older pending/suspended/retired rows.
- **Vehicle data oddity** in the test driver's row: `model` is spelled `Corrolla` (sic). Display reflects the data faithfully — fix at the source if needed.
- **`auth.uid()` race** — on cold start the JWT may not be restored when the first widget tries to call an RPC. Defensive pattern: check `_supabase.auth.currentUser != null` before calling, throw a clear exception otherwise. Listen to `onAuthStateChange` to retry. See `DashboardController` for the reference impl.
- **`mounted` guards** — every `await` inside a controller's method must be followed by `if (!mounted) return;` before mutating state. AutoDispose providers can dispose mid-flight.
- **`Future.wait` failure mode** — if any sub-future throws, the whole `wait` throws. The controller catches and shows an error. Be conservative about which calls to bundle.
- **Don't use `BuildContext` across `await`** — capture `ScaffoldMessenger.of(context)` BEFORE the await if you need it after.

---

## 11. Useful one-liners

- **MCP project ID**: `gxzyednqegqycnmbdghf`
- **Run analyze**: `flutter analyze` (project has 22-25 baseline info-level lints — focus on errors/warnings; the existing info hints are unfixed style nits across the codebase, don't try to fix them all in one PR)
- **User's driver_id for testing**: `6d5973d7-eb7f-4ee6-aeff-73c366173a06`
- **User's joined date**: 2026-05-02 06:50 UTC (= May 2 2026, 07:50 WAT)
- **User's active vehicle**: Toyota Corrolla 2020, plate `36566FG`, white
- **User's lifetime as of 2026-05-04**: 11 completed trips, ₦17,700 (1,770,000 minor)
- **User's subscription**: Drivio Pro Monthly @ ₦5,000/mo, status `trialing`, period 2026-05-02 → 2026-07-31

---

## 12. How the user prefers to work

- **Auto mode is on a lot**: execute autonomously, prefer action over planning, but don't take destructive actions without explicit confirmation, and don't share credentials/secrets to chat.
- **Asks targeted clarifying questions**: when the user explicitly says "ask questions if you don't understand", honour it even in auto mode.
- **No tests** — `feedback_no_tests.md` in user memory.
- **Concise commit-style explanations** — they read fast. Lead with the "what changed", follow with "why", end with "verified by X". Don't repeat what's in the diff.
- **Will tell you when something is wrong**: "the date is wrong", "the spinner keeps spinning". Take the report at face value, verify against DB, then fix.
- **Doesn't want guesses**: if the data is in the DB and the UI shows wrong, check both before assuming a bug.

---

## 13. Files most worth reading first if you're new

1. **`driver.md`** — the spec.
2. **`lib/app.dart`** — entry point + theme + routing.
3. **`lib/modules/commons/di/di.dart`** — every repository registered here.
4. **`lib/modules/commons/all.dart`** — barrel export of common widgets/utilities/types.
5. **`lib/modules/dash/features/drive_shell/presentation/ui/drive_shell_page.dart`** — the central canvas. All shell modes (idle/bidding/trip) live here. ~1000 lines.
6. **`lib/modules/commons/types/`** — domain models. Read `pricing_profile.dart`, `wallet.dart`, `dashboard_summary.dart`, `profile_summary.dart`, `subscription.dart` for the recently-touched ones.
7. **`lib/modules/commons/logging/`** — logger + supabase wrapper.
8. **`lib/modules/splash/`** — newest module.

---

End of context handoff. Update this file as work progresses — the next agent will thank you.
