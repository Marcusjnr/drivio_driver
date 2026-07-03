# Phase B: Firebase + Push Foundation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Both apps registered in Firebase per flavor, initialized with per-flavor options, FCM tokens stored server-side, and the killed-state ringing plumbing (CallKit/full-screen intent + `call-notify` edge function) in place — so Phase C only has to *use* it.

**Architecture:** Firebase apps registered via the Firebase MCP (prod flavors → `drivio-prod`, staging → `drivio-staging`). Firebase initializes **dart-side** from per-flavor `firebase_options_{prod,stage}.dart` (no google-services gradle plugin — it was removed in Phase A and isn't needed with explicit options). Tokens land in a `device_tokens` table via a repository called on app start/login. `call-notify` edge function fans out FCM v1 (Android) and APNs VoIP (iOS, env-gated until the user supplies the APNs key).

**Tech Stack:** Firebase MCP, firebase_core, firebase_messaging, flutter_callkit_incoming, Supabase (device_tokens + edge fn), APNs HTTP/2 JWT.

## Global Constraints

- No tests; verification = analyze + builds + a real staging FCM push.
- No commits unless asked.
- Firebase projects: `drivio-staging` (both `.beta` IDs), `drivio-prod` (both prod IDs).
- Android IDs: `com.drivedrivio.drivio_driver[.beta]`, `com.drivedrivio.drivio_rider[.beta]`; iOS: hyphen variants.
- Existing legacy apps (`com.example.*` in drivio-staging) are left untouched.
- Dart flavor enum: `Flavor { prod, staging }`; per-flavor options files named `firebase_options_prod.dart` / `firebase_options_stage.dart`.

### Task 1: Register 8 Firebase apps + collect SDK configs
- [ ] In `drivio-staging`: create Android `com.drivedrivio.drivio_driver.beta`, iOS `com.drivedrivio.drivio-driver.beta`, Android `com.drivedrivio.drivio_rider.beta`, iOS `com.drivedrivio.drivio-rider.beta` (display names "Drivio Driver Beta"/"Drivio Beta").
- [ ] In `drivio-prod`: same four without `.beta` ("Drivio Driver"/"Drivio").
- [ ] `firebase_get_sdk_config` for each app; record apiKey/appId/messagingSenderId/projectId/storageBucket (+ iOS bundleId).

### Task 2: Driver app — per-flavor Firebase options + messaging
- [ ] Rewrite `lib/firebase_options_stage.dart` with the NEW staging app values; create `lib/firebase_options_prod.dart` with prod values (same class name `DefaultFirebaseOptions`, different library).
- [ ] `main.dart` `bootstrap()`: pick options by flavor (`Flavor.prod` → prod options, else stage).
- [ ] Add `firebase_messaging` to pubspec; create `lib/modules/commons/push/push_service.dart`: requests permission (iOS), gets FCM token, upserts via `upsert_device_token` RPC, listens to `onTokenRefresh`; called after sign-in and on app start when signed in; delete token row on sign-out.
- [ ] Analyze + staging/prod APK builds.

### Task 3: Rider app — same as Task 2
- [ ] Add `firebase_core` + `firebase_messaging`; create `lib/firebase_options_stage.dart` + `lib/firebase_options_prod.dart` (new rider app values); wire `Firebase.initializeApp` into `bootstrap()` (rider had none); same `push_service.dart` + wiring.
- [ ] Analyze + builds.

### Task 4: Backend — device_tokens
- [ ] Migration `device_tokens`: `user_id uuid not null, app text check (driver|rider), platform text check (android|ios), fcm_token text not null, voip_token text, updated_at timestamptz default now(), primary key (user_id, app, platform)`. RLS owner-only. RPC `upsert_device_token(p_app,p_platform,p_fcm_token,p_voip_token)` SECURITY DEFINER + `delete_my_device_token(p_app,p_platform)`.
- [ ] Apply live + mirror into drivio_backend migrations.

### Task 5: call-notify edge function (scaffold now, consumed in Phase C)
- [ ] `supabase/functions/call-notify/index.ts`: input `{ calleeUserId, payload }`; reads `device_tokens`; Android → FCM HTTP v1 data message (service-account JSON from Vault secret `get_firebase_service_account`); iOS → APNs VoIP HTTP/2 JWT (key from Vault `get_apns_key`; returns `apns_not_configured` until the user provides it). verify_jwt on; service-role internal call from DB via pg_net in Phase C.
- [ ] Deploy skeleton; source mirrored to drivio_backend.

### Task 6: CallKit plumbing (client)
- [ ] Add `flutter_callkit_incoming` to both apps; Android: `USE_FULL_SCREEN_INTENT` + `FOREGROUND_SERVICE` notification channel bits per package docs; iOS: `UIBackgroundModes` `voip` + PushKit wiring in AppDelegate (guarded — inert until APNs key + entitlements exist).
- [ ] Background FCM handler displays the CallKit incoming UI from a `call` data message.
- [ ] Builds green both apps. (Actual ring test happens in Phase C end-to-end.)

**User-blocking items (needed before iOS ringing works):** Apple Developer — Push Notifications capability + VoIP background mode on both new bundle IDs, APNs auth key (.p8 + key id + team id); also Agora App ID/Certificate for Phase C.
