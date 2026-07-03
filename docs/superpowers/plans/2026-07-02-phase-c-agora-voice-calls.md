# Phase C: Agora Voice Calls Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rider↔driver calling on an active trip: a call sheet with Regular Call (native dialer, real number) + Free Call (Agora voice), ringing in foreground (Realtime), background and killed state (FCM data → full-screen intent / APNs VoIP → CallKit), with a full call state machine and production edge-case handling.

**Architecture:** Supabase `calls` table is the signaling source of truth (RPCs mutate, Realtime + push fan out). Agora carries media only. `agora-token` edge fn mints RTC tokens (npm:agora-token) with secrets env-gated until the user supplies Agora creds. Client: `CallRepository` (signaling) + `CallEngine` (Agora lifecycle) + `CallController` (state machine) + three screens (sheet, in-call, incoming), duplicated per app with each app's design system.

**Tech Stack:** agora_rtc_engine ^6.5.x, flutter_callkit_incoming ^2.x, firebase_messaging (bg handler), Supabase Realtime/pg_net, npm:agora-token.

## Global Constraints

- No tests; verification = analyze + builds; real-device end-to-end needs Agora creds + two devices (user-side).
- No commits unless asked.
- Call states: `idle, outgoingRinging, incomingRinging, connecting, connected, reconnecting, ended, declined, missed, cancelled, failed`; `muted`/`speakerOn` are flags, not states.
- One live call per trip (partial unique index on status in ringing|accepted).
- Ring timeout 30s client-side; 35s server sweep → `missed` (inline sweep, no pg_cron).
- Channel name = `call_<callId>`; uid = deterministic int32 from user UUID (server-computed).
- Regular Call: `get_trip_contact` (participants of active trip only) → `tel:` URI via url_launcher — never auto-dials.
- Secrets (env-gated, function returns `agora_not_configured` until set): `AGORA_APP_ID`, `AGORA_APP_CERTIFICATE`.

### Task C1: Backend — calls schema, RPCs, realtime, notify hook
- `calls` table (id, trip_id→trips, caller_id, callee_id, channel_name, status check, created_at, answered_at, ended_at, end_reason) + partial unique `(trip_id) where status in (ringing, accepted)` + RLS (participants select) + realtime publication.
- RPCs (SECURITY DEFINER, participant-checked, idempotent): `start_call(p_trip_id)` (validates active trip, sweeps stale, inserts ringing, pg_net → call-notify with CallKit payload: type=incoming_call, call_id, trip_id, channel, caller first name+avatar), `answer_call`, `decline_call`, `cancel_call`, `end_call(p_reason)`, `_sweep_stale_calls()` (ringing >35s → missed).
- `get_trip_contact(p_trip_id)` → counterpart `first_name, avatar_url, phone_e164` while trip active.
- Apply live + mirror migration `voice_calls`.

### Task C2: Backend — agora-token edge function
- `agora-token` (verify_jwt true): input `{ callId }`; caller must be participant with status ringing|accepted; uid = int32 from md5(user uuid); `npm:agora-token` RtcTokenBuilder publisher token TTL 2h; returns `{ token, uid, channel, appId }`; `agora_not_configured` (503) until secrets set. Deploy + source in drivio_backend.

### Task C3: Driver app — call stack
- Deps: `agora_rtc_engine`, `flutter_callkit_incoming`, mic permission (RECORD_AUDIO manifest; Info.plist string exists).
- `modules/commons/types/call.dart` (Call + CallStatus + TripContact), `data/call_repository(+impl)` (RPCs, watch call row via realtime, `getTripContact`, token fetch via functions.invoke), `modules/trip/features/call/`: `call_engine.dart` (engine lifecycle: communication profile, speechStandard scenario, join/leave/mute/speaker/route + connection state stream + token renewal), `call_controller.dart` (family by tripId; state machine driven by RPC results + call-row realtime + engine events + 30s timer), UI: call sheet (Regular/Free), in-call page (evolve mock `call_page.dart`), incoming page.
- Wire trip screen call button → sheet. Ring-in: active-trip realtime watch for `ringing` calls where callee=me → incoming page (foreground path).
- Background: FCM `onBackgroundMessage` top-level handler + foreground `onMessage` — type=incoming_call → `FlutterCallkitIncoming.showCallkitIncoming`; accept/decline events → answer/decline RPC + navigate. iOS PushKit token → `PushService.saveVoipToken`.
- Analyze + staging builds.

### Task C4: Rider app — call stack
- Mirror C3 with rider palette/widgets (new in-call + incoming pages), rider deps + `url_launcher` (add; driver already has it) + manifest `tel:` query + RECORD_AUDIO + iOS mic usage string (add) + LSApplicationQueriesSchemes tel.
- Wire `onCall: () {}` stub on the trip screen → call sheet.

### Task C5: Gates + docs
- `flutter analyze` clean both apps; staging APK + iOS build both apps.
- End-to-end checklist doc for the user (two devices, Agora creds, accept/decline/timeout/cancel/kill/airplane-mode matrix).
