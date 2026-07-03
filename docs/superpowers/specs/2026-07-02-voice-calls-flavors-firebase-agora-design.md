# Voice calls: flavors + Firebase push + Agora — design

**Date:** 2026-07-02
**Repos:** `drivio_driver`, `drivio_user` (rider), `drivio_backend`
**Live Supabase project:** `gxzyednqegqycnmbdghf`
**Firebase projects (existing):** `drivio-prod`, `drivio-staging`

## Goal

After a rider and driver match, either party can call the other from the trip
screen. A bottom sheet offers exactly two options:

1. **Regular Call** — phone icon + the counterpart's phone number; opens the
   native dialer pre-filled (never auto-dials).
2. **Free Call** — in-app Agora voice call, no cellular charges, Uber/Bolt-grade
   UX. Must ring the recipient even when their app is backgrounded or killed.

Three sub-projects, built strictly in order (each depends on the previous):
**A. Flavors + real app identity → B. Firebase + push foundation → C. Agora calling.**

## Decisions (from the user)

- Full reachability: background **and killed-state** ringing (FCM + iOS VoIP/CallKit).
- `flutter_flavorizr` for flavors; bundle IDs move off `com.example.*`.
- Requested IDs: `com.drivedrivio.drivio_driver` / `com.drivedrivio.drivio_rider`;
  staging flavor adds "beta" to names. (iOS forbids underscores → hyphen variant
  on iOS, approved.)
- Firebase projects already exist (`drivio-prod`, `drivio-staging`); register the
  apps in them via the Firebase MCP.
- Agora account exists; user supplies App ID + App Certificate.
- Regular Call shows real numbers **both directions**, active-trip only,
  server-enforced.

## Current state (verified)

- Both apps: `com.example.*` IDs, Kotlin-DSL Gradle, **no flavors**, dotenv
  config (`.env` loaded in `main.dart`), **no Firebase/push at all**.
- Chat already uses Supabase Realtime postgres-changes
  (`message_repository_impl.dart`) — the same rail carries call signaling
  when the app is open.
- Driver has a mock in-call UI (`trip/features/call/.../call_page.dart`,
  ringing/active + timer) to evolve; rider's Call button is `onCall: () {}`.
- Rider `Trip` already carries `driver_phone`; driver side has no rider phone.
- Driver app has `flutter_foreground_task` (Android FGS) + native iOS
  significant-location shim — flavorizr output must be diff-reviewed so it
  doesn't clobber these.

---

## Phase A — Flavors & app identity

Flavors: **`prod`**, **`staging`** (both apps).

| App/flavor | Android appId | iOS bundle ID | Display name |
|---|---|---|---|
| Driver prod | `com.drivedrivio.drivio_driver` | `com.drivedrivio.drivio-driver` | Drivio Driver |
| Driver staging | `com.drivedrivio.drivio_driver.beta` | `com.drivedrivio.drivio-driver.beta` | Drivio Driver Beta |
| Rider prod | `com.drivedrivio.drivio_rider` | `com.drivedrivio.drivio-rider` | Drivio |
| Rider staging | `com.drivedrivio.drivio_rider.beta` | `com.drivedrivio.drivio-rider.beta` | Drivio Beta |

- `flutter_flavorizr` config in each pubspec; it generates Android
  `productFlavors`, iOS schemes + xcconfigs, and `main_prod.dart` /
  `main_staging.dart` entrypoints.
- Entrypoints load per-flavor dotenv: `.env.prod` / `.env.staging` (falling back
  to existing keys). Same Supabase project for both flavors for now; Firebase
  differs per flavor.
- **Risk control:** flavorizr rewrites AndroidManifest/pbxproj. After running
  it, diff-review and re-apply: driver FGS service declarations, iOS location
  shim/background modes, camera permission strings, maplibre/geolocator
  settings.
- Verify: `flutter build apk --flavor prod|staging` and an iOS build per scheme;
  both apps launch with correct display name + ID.

## Phase B — Firebase + push foundation

- Via Firebase MCP: register 8 apps (driver/rider × android/ios × prod/staging)
  — prod-flavor apps in `drivio-prod`, staging in `drivio-staging`. Pull
  `google-services.json` per Android flavor (`android/app/src/<flavor>/`) and
  `GoogleService-Info.plist` per iOS scheme (xcconfig-selected).
- Add `firebase_core`, `firebase_messaging` to both apps. Initialize per flavor.
- **`device_tokens` table:** `user_id uuid, app text (driver|rider), platform
  text (android|ios), fcm_token text, voip_token text (iOS only), updated_at`.
  Upsert on app start/login/token refresh; delete on sign-out. RLS: owner only.
- **Android killed-state ringing:** high-priority FCM **data** message →
  `flutter_callkit_incoming` full-screen incoming-call UI (needs
  `USE_FULL_SCREEN_INTENT` + channel setup).
- **iOS killed-state ringing:** APNs **VoIP push** + CallKit via
  `flutter_callkit_incoming`. FCM cannot deliver VoIP pushes — the backend
  speaks APNs HTTP/2 directly (JWT-signed with an APNs auth key, `.voip`
  topic). VoIP pushes MUST report a CallKit call immediately (Apple rule).
- **`call-notify` edge function:** given a callee user id + call payload, fans
  out FCM v1 (Android tokens) and APNs VoIP (iOS voip tokens). Secrets in
  Vault: Firebase service-account JSON, APNs key (key id, team id, p8).
- **User-side setup (documented, blocking iOS):** Apple Developer — enable Push
  Notifications + VoIP background mode on both iOS app IDs, create an APNs
  auth key, hand over key id/team id/p8. Android needs nothing beyond the
  google-services files.
- Verify: test push rings a real killed-state device on both platforms.

## Phase C — Agora voice calling

### Signaling (Supabase is the source of truth)

- **`calls` table:** `id uuid pk, trip_id uuid, caller_id uuid, callee_id uuid,
  channel_name text, status text check in (ringing, accepted, declined,
  missed, cancelled, ended, failed), created_at, answered_at, ended_at,
  end_reason text`.
- RPCs (SECURITY DEFINER, participants-of-active-trip only):
  - `start_call(p_trip_id)` → validates active trip + no live call on the trip
    (one live call per trip, enforced by partial unique index on
    `trip_id where status in (ringing, accepted)`), inserts `ringing` row,
    returns call id + channel name. Triggers `call-notify` (pg_net → edge fn).
  - `answer_call(p_call_id)` → ringing→accepted, stamps `answered_at`.
  - `decline_call(p_call_id)` → ringing→declined.
  - `cancel_call(p_call_id)` → caller-only, ringing→cancelled.
  - `end_call(p_call_id, p_reason)` → accepted→ended.
  - `expire_stale_calls()` → ringing older than 35s → missed (pg_cron sweep;
    clients also enforce a 30s local timeout).
- Recipient learns of the call **two ways**: Realtime postgres-changes on
  `calls` (instant, app open) and push via `call-notify` (background/killed →
  CallKit UI). Both converge on the same incoming-call state; duplicates are
  idempotent (keyed by call id).
- `get_trip_contact(p_trip_id)` RPC → counterpart's first name + phone_e164,
  only while trip state ∈ assigned…in_progress (serves the Regular Call sheet
  and both directions of number exchange).

### Agora integration

- `agora_rtc_engine` (latest 6.x) in both apps.
- **`agora-token` edge function:** RtcTokenBuilder (App ID + App Certificate
  from Vault). Input: call id; validates the caller is a participant of that
  call; channel = `call_<callId>`; uid = deterministic 32-bit int from the
  user's UUID (hash, stable per user); role publisher; TTL 2h; returns token +
  uid + channel. Token renewal: `onTokenPrivilegeWillExpire` → re-fetch →
  `renewToken`.
- **Engine config (and why):**
  - `channelProfile: communication` — 1:1 duplex, lower latency than
    liveBroadcasting.
  - `audioProfile: speechStandard` (~18 kbps mono voice) — bandwidth-lean,
    ideal for Nigerian mobile networks; music profiles wasted here.
  - `audioScenario: default` — enables hardware/software AEC, ANS, AGC.
  - Video **never initialized**; dual-stream off; no media recording — battery,
    permissions, and review-surface minimization.
  - Engine created lazily at first call, `release()`d after call ends.
- **Network resilience:** Agora handles jitter/PLC/FEC internally for speech
  profiles; expose `onNetworkQuality` → weak-signal chip; `onConnectionStateChanged`
  (reconnecting/failed) → UI + auto-recovery; audio route change callbacks →
  route indicator.

### Call state machine (one enum both apps)

```
idle → outgoingRinging → connecting → connected ⇄ reconnecting → ended
        │                    │                                 ↘ failed
        ├→ cancelled         └→ failed
callee: incomingRinging → connecting → … (same tail)
                │→ declined  │→ missed (timeout)
```
`muted`, `speakerOn` are flags on `connected`, not states. Transitions are
driven by: local user actions, `calls` row changes (Realtime), Agora engine
events, and the 30s ring timer — whichever fires first wins; the rest are
no-ops (idempotent transitions).

### Edge cases

| Case | Handling |
|---|---|
| Caller cancels before answer | `cancel_call` → callee's ringing UI dismisses (Realtime/CallKit end event) |
| Callee declines | `decline_call` → caller sees "Declined", sheet offers Regular Call |
| Callee offline/unreachable | 30s timeout → `missed`; caller prompted to use Regular Call |
| Either side loses internet mid-call | Agora `reconnecting` ≤ 25s → auto-resume; beyond → `failed` + end row |
| App killed mid-call | On next launch: if `calls.status = accepted` on an active trip → "Return to call?" rejoin |
| Simultaneous calls | Partial unique index rejects 2nd `start_call` → caller joins the existing ringing call as callee-view |
| Token expiry | Renewal callback → `agora-token` re-fetch → `renewToken` |
| Channel join failure | Retry once, then `failed` + user-facing error |
| GSM call interrupts | Audio-focus loss → auto-mute/hold + `reconnecting` UI; resume on focus regain |
| Device route change | Agora route callback → UI chip (earpiece/speaker/BT) |
| WiFi↔cellular switch | Agora session migration handles it; surfaced as brief `reconnecting` |

### UI

- **Call sheet** (both apps, trip screen Call button): two rows —
  Regular Call (phone icon, counterpart number, subtitle "Uses your network")
  → `url_launcher` `tel:` URI; Free Call (voice icon, "Free · uses internet").
- **Outgoing screen:** evolve driver's mock `call_page.dart` — callee name +
  avatar, CALLING… / timer, mute + speaker + end. Rider gets the identical
  page (rider palette).
- **Incoming (app open):** full-screen in-app ringing page (accept/decline).
- **Incoming (background/killed):** CallKit/full-screen-intent native UI →
  accept deep-links into the call screen and `answer_call` + join.
- Mic permission requested at first Free Call (Info.plist
  `NSMicrophoneUsageDescription` + Android `RECORD_AUDIO` — both new).

### Performance/battery

- Engine lifecycle scoped to the call; no idle Agora process.
- Speech profile ≈ 18 kbps → ~8 MB/hour of talk.
- No wake-locks beyond the call; CallKit/ConnectionService handle OS-level
  call plumbing natively.

## Build order & verification gates

1. **A** → both apps build/run in both flavors, IDs + names verified.
2. **B** → killed-state test push rings a real Android + iOS device.
3. **C** → end-to-end: rider↔driver free call on real devices (accept, decline,
   timeout, cancel, mid-call kill, network flap), regular-call dialer both ways.

## Out of scope

- Video calls, call recording, voicemail, in-call chat.
- Number masking/proxy for Regular Call (real numbers by decision).
- General (non-call) push notifications — the plumbing lands, but wiring trip
  events etc. into push is a follow-up.
