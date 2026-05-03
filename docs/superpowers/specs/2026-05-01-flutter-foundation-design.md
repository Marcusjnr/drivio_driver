# Flutter Foundation — Implementation Spec

> **Scope:** DRV-001, DRV-002, DRV-003, DRV-008, DRV-009, DRV-010, DRV-011, DRV-012, DRV-014
> **Goal:** Take the existing 39-screen prototype from seeded data to real Supabase auth, session management, network resilience, and proper app lifecycle.
> **Source of truth:** `driver.md` (tickets), `driver_context.md` (reasoning), `knowledge.md` (existing codebase).

---

## 1. DRV-001 — Supabase Client Bootstrap

### What changes
- `commons/config/config.dart` — add `supabaseUrl` and `supabaseAnonKey` fields, sourced from `Env`.
- New `commons/config/env.dart` — `const` accessors via `String.fromEnvironment`.
- New `commons/supabase/supabase_module.dart` — typed facade exposing `db`, `auth`, `storage`, `realtime`, `functions`. No module imports `Supabase.instance.client` directly.
- `commons/di/di.dart` — call `Supabase.initialize(...)` before registering. Register `SupabaseClient` in GetIt. Register `SupabaseModule` singleton.
- `main.dart`, `main_prod.dart`, `main_stage.dart` — `await` the DI setup (it becomes async for `Supabase.initialize`).

### Facade shape
```dart
class SupabaseModule {
  SupabaseClient get client;
  SupabaseQueryBuilder Function(String table) get db; // shorthand for client.from(table)
  GoTrueClient get auth;
  SupabaseStorageClient get storage;
  RealtimeClient get realtime;
  FunctionsClient get functions;
}
```

### Rules
- Anon key and URL are placeholders (`'YOUR_SUPABASE_URL'`, `'YOUR_SUPABASE_ANON_KEY'`). User replaces before running.
- App asserts non-empty at startup; crashes with a clear message if missing.
- `autoRefreshToken: true` on auth options.

---

## 2. DRV-002 — Environment & Flavours

### What changes
- New `commons/config/env.dart`:
  ```dart
  abstract final class Env {
    static const supabaseUrl = String.fromEnvironment('SUPABASE_URL', defaultValue: 'YOUR_SUPABASE_URL');
    static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY', defaultValue: 'YOUR_SUPABASE_ANON_KEY');
    static const sentryDsn = String.fromEnvironment('SENTRY_DSN', defaultValue: '');
    static const posthogKey = String.fromEnvironment('POSTHOG_KEY', defaultValue: '');
    static const paystackPublicKey = String.fromEnvironment('PAYSTACK_PUBLIC_KEY', defaultValue: '');
  }
  ```
- `Config` updated to source from `Env` instead of hardcoded strings.
- Each `main_*.dart` can override via `--dart-define` or `--dart-define-from-file`.

---

## 3. DRV-003 — Network Resilience Layer

### What we build
A `MutationQueue` that wraps every edge-function call with:
- **Idempotency key** — UUIDv4 generated on device, persisted to SharedPreferences until acknowledged.
- **Exponential backoff** — 1s, 2s, 4s, 8s, 16s, max 60s.
- **Durable queue** — survives app restart. Drains on connectivity restore.
- **Status states** — `pending | sending | failed | completed`.

### File structure
```
commons/network/
  mutation_queue.dart          # MutationQueue StateNotifier
  mutation.dart                # Mutation<T> model (id, key, endpoint, payload, status, retryCount, createdAt)
  mutation_storage.dart        # SharedPreferences persistence for pending mutations
  network_client.dart          # Thin wrapper over SupabaseModule.functions.invoke() that routes through MutationQueue
```

### Behaviour
- 4xx responses are terminal (no retry, surface error).
- 5xx and network errors retry with backoff.
- Each mutation carries an `Idempotency-Key` header.
- `MutationQueueController` exposes `pending` and `failed` lists.
- UI can observe queue state via Riverpod provider.

---

## 4. DRV-008 — App Lifecycle Controller

### What we build
A `LifecycleController` mounted as a `WidgetsBindingObserver` in `App`.

### Behaviour
- **On `paused` (background):**
  - If no active trip: unsubscribe marketplace channels, pause location.
  - If active trip: keep trip channel + location streaming alive.
  - Record `_lastPausedAt` timestamp.
- **On `resumed` (foreground):**
  - Re-subscribe marketplace channels (if online, no active trip).
  - Replay missed events via REST fetch + merge (reconnect-then-reconcile pattern from `driver_context.md` §5.4).
  - Re-validate auth session (`auth.currentSession`). If expired, route to welcome.
  - Drain mutation queue.
- **On `detached`:**
  - Best-effort cleanup; no guarantees.

### File
```
commons/lifecycle/
  lifecycle_controller.dart
```

Registered in `App` widget's `initState` / `dispose`.

---

## 5. DRV-009 — Auth-State Router Gate (BootstrapController)

### What we build
A `BootstrapController` that computes where the user should land on app launch.

### Decision tree
```
1. No auth session → welcome
2. Auth session but no `profiles` row → sign-up (complete profile)
3. Profile exists, `drivers.kyc_status` != 'approved' → kyc flow (future)
4. KYC approved, no active vehicle → add-vehicle
5. Vehicle exists, `subscriptions.status` not in (trialing, active, past_due) → paywall
6. All gates pass → home
```

For now (before KYC epic is built), steps 3-4 are checked but gracefully skip if the tables/data don't exist yet.

### File structure
```
commons/bootstrap/
  bootstrap_controller.dart     # StateNotifier<BootstrapState>
  bootstrap_destination.dart    # enum: welcome, signUp, kyc, addVehicle, paywall, home
```

### Integration
- `App.build()` watches `bootstrapControllerProvider` to set `initialRoute`.
- `sessionProvider = StreamProvider<AuthState>` wraps `auth.onAuthStateChange`.
- On `signedOut` or `tokenRefreshFailed` events → navigate to welcome.

---

## 6. DRV-010 — Phone OTP Sign-In

### What changes
- Wire existing `SignInController` to call `auth.signInWithOtp(phone: normalizedPhone)`.
- Wire existing `OtpController.verify()` to call `auth.verifyOTP(token: code, phone: phone, type: OtpType.sms)`.
- Add states: `isRequestingOtp`, `isVerifying`, `error`.
- On successful verify → `BootstrapController` computes next destination.

### Phone normalisation
- Strip leading `0`, prepend `+234`.
- Validate: exactly 10 digits after country code for Nigerian numbers.
- The existing `PhoneNumberInput` already shows `+234` prefix; extract the national number.

### Error handling
- Network error → "Couldn't request code, tap to retry"
- Wrong code → shake cells, clear input
- Expired OTP → "Code expired, tap resend"
- Rate limited → "Too many attempts, try again in N min"

---

## 7. DRV-011 — Sign-Up (New Driver Creation)

### What changes
- Wire existing `SignUpController` to call Supabase after OTP verification.
- On first sign-in (no `profiles` row), route to sign-up form.
- On submit: insert into `profiles` and `drivers` tables via Supabase client.
- On success → route to home (KYC gating comes in Epic 3).

### Data flow
```
SignUpController.submit() →
  supabase.from('profiles').insert({
    user_id: auth.currentUser!.id,
    full_name: state.fullName,
    phone_e164: normalizedPhone,
    email: state.email,  // optional
    referral_code: generateReferralCode(),
    referred_by: state.referralCode,  // if entered, validate exists
  }) →
  supabase.from('drivers').insert({
    user_id: auth.currentUser!.id,
    kyc_status: 'not_started',
  }) →
  navigate to BootstrapController's next destination
```

---

## 8. DRV-012 — Session Refresh & Secure Token Storage

### What changes
- Add `flutter_secure_storage` to pubspec.yaml.
- Supabase Flutter already uses SharedPreferences for session by default; `flutter_secure_storage` can be configured via custom `LocalStorage`.
- A `SessionGuard` that listens to `auth.onAuthStateChange`:
  - On `tokenRefreshFailed` → navigate to welcome, show toast "Session expired"
  - On `signedOut` → navigate to welcome
  - On `passwordRecovery`, `userUpdated` → no-op for driver app

### File
```
commons/auth/
  session_guard.dart
```

Initialised in `App` and disposed on teardown.

---

## 9. DRV-014 — Logout

### What changes
- Wire existing `SignOutPage` to:
  1. Check if driver is online or on-trip → if so, disable logout, show explanation sheet.
  2. Call `auth.signOut()`.
  3. Clear any local state (SharedPreferences mutation queue, etc.).
  4. Navigate to welcome via `AppNavigation.replaceAll(AppRoutes.welcome)`.

---

## Files touched (summary)

### New files
- `commons/config/env.dart`
- `commons/supabase/supabase_module.dart`
- `commons/network/mutation_queue.dart`
- `commons/network/mutation.dart`
- `commons/network/mutation_storage.dart`
- `commons/network/network_client.dart`
- `commons/lifecycle/lifecycle_controller.dart`
- `commons/bootstrap/bootstrap_controller.dart`
- `commons/bootstrap/bootstrap_destination.dart`
- `commons/auth/session_guard.dart`

### Modified files
- `commons/config/config.dart` — add Supabase fields
- `commons/di/di.dart` — async init, register new singletons
- `commons/all.dart` — export new modules
- `main.dart`, `main_prod.dart`, `main_stage.dart` — async main
- `app.dart` — mount LifecycleController, SessionGuard, BootstrapController
- `authentication/sign_in/logic/controller/sign_in_controller.dart` — wire to Supabase auth
- `authentication/otp/logic/controller/otp_controller.dart` — wire to Supabase verify
- `authentication/sign_up/logic/controller/sign_up_controller.dart` — wire to Supabase insert
- `authentication/sign_in/ui/sign_in_page.dart` — handle loading/error states
- `authentication/otp/ui/otp_page.dart` — handle loading/error states
- `authentication/sign_up/ui/sign_up_page.dart` — handle loading/error states
- `profile/sign_out/ui/sign_out_page.dart` — wire to auth.signOut
- `pubspec.yaml` — add flutter_secure_storage, uuid

### Packages to add
- `flutter_secure_storage` — secure token persistence
- `uuid` — idempotency key generation

---

## What this does NOT include
- Sentry (DRV-004), PostHog (DRV-005), FCM (DRV-006), force-update (DRV-007) — next batch
- Biometric unlock (DRV-013) — P1
- KYC screens (Epic 3) — separate batch
- Realtime marketplace channels — comes with Epic 6/7
- Tests — per user instruction
