# Drivio Driver — Engineering Implementation Roadmap

> **Scope:** Production-ready engineering tickets for the **Driver Application** and the supporting platform/backend work the driver app directly depends on. Passenger-app implementation is intentionally out of scope; passenger flows are referenced only where they are required to explain driver behaviour, realtime synchronisation, or shared backend contracts.
>
> **Stack:** Flutter (existing repo) · Supabase (Postgres + Auth + Storage + Realtime + Edge Functions) · PostGIS · Paystack/Flutterwave · Termii (SMS) · FCM · Sentry · PostHog.
>
> **Region (v1):** Nigeria. Currency NGN. Phone +234. KYC: BVN/NIN. Vehicle docs: FRSC driver's licence, vehicle registration, insurance certificate, road worthiness, LASRRA (Lagos) where applicable.
>
> **Differentiator:** Drivers bid their own price for every ride. The platform never sets a fare. Drivers pay a recurring subscription to receive requests; new drivers get a 90-day free trial.

---

## Conventions

| Field | Values |
|---|---|
| **Priority** | `P0` launch blocker · `P1` must-have for v1 · `P2` post-launch v1.x · `P3` later |
| **Complexity** | `XS` ≤0.5d · `S` 1–2d · `M` 3–5d · `L` 1–2w · `XL` 2w+ |
| **ID prefix** | `PLAT-` shared platform/backend · `DRV-` driver Flutter app |
| **Order** | Global implementation sequence (1 = first) |

Every ticket has the same shape so engineers can scan it identically: **Goal → User Story → Description → Acceptance Criteria → Frontend → Backend → Realtime → State → API/Data Deps → Validation → Error Handling → Security → Analytics → Edge Cases → Priority/Complexity/Order/Depends.**

Where a field is genuinely N/A for a ticket (e.g. realtime on an offline-only screen) it is written `— N/A` rather than omitted, so reviewers know it was considered.

---

## Epic Map

| # | Epic | Tickets | Priority |
|---|---|---|---|
| 0 | Platform Foundation | PLAT-001…PLAT-014 | P0 |
| 1 | Driver App Foundation | DRV-001…DRV-009 | P0 |
| 2 | Authentication & Identity | DRV-010…DRV-015 | P0 |
| 3 | KYC & Onboarding | DRV-016…DRV-021 | P0 |
| 4 | Vehicle Management | DRV-022…DRV-025 | P0 |
| 5 | Subscription & Trial | DRV-026…DRV-033 | P0 |
| 6 | Driver Availability (Online/Offline) | DRV-034…DRV-039 | P0 |
| 7 | Marketplace Discovery | DRV-040…DRV-045 | P0 |
| 8 | Bidding (Pricing Submission) | DRV-046…DRV-051 | P0 |
| 9 | Active Trip Lifecycle | DRV-052…DRV-060 | P0 |
| 10 | Realtime Comms (Chat/Call) | DRV-061…DRV-063 | P1 |
| 11 | Earnings & Wallet | DRV-064…DRV-068 | P0 |
| 12 | Pricing Strategy Tools | DRV-069…DRV-071 | P1 |
| 13 | Driver Analytics | DRV-072…DRV-075 | P1 |
| 14 | Profile · Documents · Reviews | DRV-076…DRV-079 | P0/P1 |
| 15 | Safety & Trust | DRV-080…DRV-083 | P0 |
| 16 | Support | DRV-084…DRV-086 | P1 |
| 17 | Notifications | DRV-087…DRV-088 | P0 |
| 18 | Settings & Account | DRV-089…DRV-090 | P1/P2 |
| 19 | Edge States & Failure Recovery | DRV-091…DRV-095 | P0 |
| 20 | Security & Compliance | DRV-096…DRV-098 | P0 |
| 21 | QA & Launch | DRV-099…DRV-101 | P0 |

---

# EPIC 0 — Platform Foundation

These tickets are not driver-app-specific but the driver app **cannot ship** without them. They are platform tickets that the driver-app workstream owns the unblocking of.

---

### PLAT-001 — Supabase project bootstrap & migration workflow
- **Epic:** Platform Foundation
- **Priority:** P0 · **Complexity:** S · **Order:** 1 · **Depends on:** —
- **Goal:** Stand up a reproducible Supabase environment per flavour (`stage`, `prod`) with versioned SQL migrations, seedable local dev, and CI-driven deploys.
- **User story:** As a backend engineer, I want every schema change to land via PR and apply identically in stage and prod, so that I never run ad-hoc SQL in production.
- **Description:** Create two Supabase projects (`drivio-stage`, `drivio-prod`). Adopt the `supabase` CLI for local development (`supabase start`), migrations (`supabase migration new <name>`), and deploy (`supabase db push`). Pin the CLI version in CI. All migrations live in `supabase/migrations/` in the platform repo (separate from the Flutter repo). Seed data for stage lives in `supabase/seed.sql`.
- **Acceptance criteria:** Engineer can run `supabase start` locally and reach Studio at `:54323`. Migrations applied in stage by GitHub Actions on merge to `main`. Prod deploy is manual-gated. Both projects have separate API keys stored in 1Password vault `drivio-platform`. Project IDs and anon keys recorded in the platform repo `README`.
- **Frontend (Flutter) requirements:** None directly; **DRV-001** consumes the published `SUPABASE_URL` and `SUPABASE_ANON_KEY` per flavour.
- **Backend (Supabase) requirements:** Both projects created, JWT secret rotated to a 64-char random value, default `auth.users` settings hardened (disable signup via password, enable phone provider only), email provider disabled (Nigeria-first; we use SMS only).
- **Realtime requirements:** — N/A (handled in PLAT-004).
- **State management:** — N/A.
- **API/data dependencies:** Supabase CLI ≥ 1.180, GitHub Actions, 1Password CLI for secret pulldown.
- **Validation rules:** Migration filenames `YYYYMMDDHHMMSS_<slug>.sql`. PRs that modify migrations must pass `supabase db diff --linked` with no drift.
- **Error handling:** Failed prod deploy auto-rolls back via `supabase db reset --linked` against a pre-deploy snapshot.
- **Security:** Service-role key never committed; only the anon key ships in mobile binaries. JWT secret rotated quarterly via runbook.
- **Analytics events:** `platform.migration_deployed { env, migration_id, duration_ms }` emitted from CI.
- **Edge cases:** Two engineers writing migrations simultaneously → CI rejects merges that would re-order timestamps; engineer must rebase.
- **Definition of done:** Stage and prod URLs documented; `supabase start` reproduces stage schema locally inside 60s.

---

### PLAT-002 — Core schema v1 (drivers, vehicles, documents, subscriptions, ride lifecycle)
- **Epic:** Platform Foundation
- **Priority:** P0 · **Complexity:** L · **Order:** 2 · **Depends on:** PLAT-001
- **Goal:** Define the canonical relational model the driver app reads/writes against, with sane defaults, foreign keys, and indexes.
- **User story:** As a backend engineer, I want one source of truth for the Drivio data model so that every feature ticket builds on consistent contracts.
- **Description:** Author migrations to create the following tables (this is the v1 contract; later epics extend it). Names are snake_case; surrogate keys are `uuid` defaulted to `gen_random_uuid()`; timestamps are `timestamptz`; money is `bigint` minor units (kobo) with a `currency` text column.

  **Tables (v1):**
  - `profiles` (`user_id` PK FK→`auth.users`, `full_name`, `dob`, `gender`, `phone_e164`, `email`, `avatar_url`, `referral_code`, `referred_by`, `created_at`)
  - `drivers` (`user_id` PK FK→`profiles`, `kyc_status` enum, `bvn_verified_at`, `nin_verified_at`, `liveness_passed_at`, `home_address`, `service_city`, `created_at`)
  - `vehicles` (`id` PK, `driver_id` FK→`drivers`, `make`, `model`, `year`, `colour`, `plate`, `vin`, `seats`, `category` enum `economy|comfort|xl`, `status` enum `pending|active|suspended|retired`, `created_at`)
  - `documents` (`id` PK, `owner_user_id` FK, `kind` enum `drivers_licence|vehicle_reg|insurance|road_worthiness|lasrra|inspection_report|profile_selfie`, `vehicle_id` FK NULLABLE, `file_path` text → Storage, `expires_on` date NULLABLE, `status` enum `pending|approved|rejected|expired`, `rejection_reason` text NULLABLE, `reviewed_by` uuid NULLABLE, `reviewed_at` timestamptz NULLABLE, `created_at`)
  - `subscription_plans` (`id` PK, `code` unique text, `name`, `price_minor` bigint, `currency`, `interval` enum `month|quarter|year`, `is_active` bool)
  - `subscriptions` (`id` PK, `driver_id` FK, `plan_id` FK NULLABLE, `status` enum `trialing|active|past_due|cancelled|expired`, `trial_ends_at`, `current_period_start`, `current_period_end`, `paystack_subscription_code` text NULLABLE, `created_at`)
  - `subscription_events` (`id` PK, `subscription_id` FK, `kind`, `payload` jsonb, `occurred_at`)
  - `driver_presence` (`driver_id` PK FK, `status` enum `offline|online|on_trip`, `last_seen_at`, `last_geo` `geography(Point,4326)`, `accuracy_m` int, `heading_deg` int, `speed_kph` int, `battery_pct` smallint, `vehicle_id` FK)
  - `ride_requests` (`id` PK, `passenger_id` FK→`auth.users`, `pickup` `geography(Point,4326)`, `pickup_address` text, `dropoff` `geography(Point,4326)`, `dropoff_address` text, `expected_distance_m` int, `expected_duration_s` int, `status` enum `open|matched|cancelled|expired`, `matched_bid_id` uuid NULLABLE, `created_at`, `expires_at`)
  - `ride_bids` (`id` PK, `ride_request_id` FK, `driver_id` FK, `vehicle_id` FK, `price_minor` bigint, `currency`, `eta_seconds` int, `status` enum `pending|accepted|rejected|expired|withdrawn`, `created_at`, `expires_at`, UNIQUE(`ride_request_id`,`driver_id`))
  - `trips` (`id` PK, `ride_request_id` FK unique, `bid_id` FK unique, `driver_id` FK, `vehicle_id` FK, `passenger_id` FK, `fare_minor` bigint, `currency`, `state` enum `assigned|en_route|arrived|in_progress|completed|cancelled`, `started_at`, `ended_at`, `cancellation_reason` text NULLABLE, `actual_distance_m` int NULLABLE, `actual_duration_s` int NULLABLE, `created_at`)
  - `trip_events` (`id` PK, `trip_id` FK, `kind` enum, `actor` enum `driver|passenger|system`, `payload` jsonb, `occurred_at`)
  - `trip_locations` (`trip_id` FK, `recorded_at`, `geo` `geography(Point,4326)`, `speed_kph`, `heading_deg`, PK(`trip_id`,`recorded_at`)) — partitioned monthly (PLAT-008)
  - `wallets` (`driver_id` PK FK, `balance_minor` bigint, `currency`, `updated_at`)
  - `wallet_ledger` (`id` PK, `driver_id` FK, `kind` enum `trip_credit|payout_debit|refund|adjustment|subscription_debit`, `amount_minor` bigint, `reference_id` uuid NULLABLE, `created_at`)
  - `payouts` (`id` PK, `driver_id` FK, `amount_minor`, `status` enum `requested|processing|paid|failed`, `paystack_transfer_code`, `bank_account_masked`, `created_at`, `settled_at`)
  - `messages` (`id` PK, `trip_id` FK, `sender_user_id` FK, `body` text, `kind` enum `text|quick_reply|location|system`, `created_at`)
  - `support_tickets`, `safety_events`, `notifications`, `device_tokens` (shape standard).

- **Acceptance criteria:** Schema applies cleanly on a fresh stage project. ERD generated to `docs/schema.svg` from `pg_dump --schema-only`. All FKs `ON DELETE` reasoned about (cascade for child events; restrict for `auth.users` so we never silently delete trip history).
- **Frontend (Flutter) requirements:** Generate Dart model classes from `supabase gen types dart`; commit to `lib/modules/commons/types/` (note: keep manual `copyWith` per existing convention, no freezed).
- **Backend (Supabase) requirements:** All enums declared at top of migration. `created_at` defaults `now()`. `updated_at` triggers via shared `set_updated_at()` function. Postgres role permissions: `authenticated` has SELECT on read-allowed tables only; mutations go through edge functions or RLS.
- **Realtime requirements:** Set `replica identity full` on `ride_requests`, `ride_bids`, `trips`, `trip_events`, `driver_presence` (these stream over Realtime). Other tables stay default to keep WAL light.
- **State management:** — N/A.
- **API/data dependencies:** PostGIS extension `postgis` enabled (covered in PLAT-008).
- **Validation rules:** Money columns must be `bigint`, never `numeric`. Currency must be 3-letter ISO. Phone numbers in E.164. Geo columns are `geography(Point,4326)` (not `geometry`) so distance is in metres without a transform.
- **Error handling:** Migration is one transaction; failure rolls back cleanly.
- **Security:** Tables created with `OWNER` = `postgres`, `GRANT`s explicit. No `GRANT ALL ON ALL TABLES` shortcuts.
- **Analytics events:** — N/A (schema only).
- **Edge cases:** A driver with a deleted `auth.users` row (account deletion) — child rows kept for accounting; `drivers.user_id` becomes orphan-tolerant via `ON DELETE SET NULL` for soft delete or anonymisation flag.
- **Definition of done:** ERD published, type generation wired, RLS still off (PLAT-003 turns it on).

---

### PLAT-003 — Row-Level Security baseline + JWT custom claims
- **Epic:** Platform Foundation
- **Priority:** P0 · **Complexity:** M · **Order:** 3 · **Depends on:** PLAT-002
- **Goal:** Lock down every table with RLS so a driver can read/write only their own rows, and a passenger never sees another passenger's data.
- **User story:** As a security-conscious driver, I want strong assurance that my BVN, location history, and earnings cannot be read by any other user, so that I trust the platform with sensitive data.
- **Description:** Enable RLS on every table from PLAT-002. Author policies grouped by access pattern. Add a custom JWT claim `role` (`driver|passenger|admin`) populated by an `auth.on_auth_user_created` trigger that reads `raw_user_meta_data->>'role'` set at signup; admins are flipped manually via SQL.
- **Acceptance criteria:** Pen-test script (PLAT-006) confirms a driver cannot SELECT another driver's `wallet_ledger`, `documents`, or `trip_locations`. RLS audit page in Supabase Studio shows every table green.
- **Backend (Supabase) requirements (key policies):**
  - `profiles`: `select using (user_id = auth.uid())`; `update using (user_id = auth.uid()) with check (user_id = auth.uid())`.
  - `drivers`, `vehicles`, `documents`, `wallets`, `wallet_ledger`, `payouts`, `subscriptions`, `subscription_events`, `device_tokens`: all keyed by `auth.uid() = driver_id` (or `owner_user_id`).
  - `driver_presence`: `update` only via edge function with service role; drivers don't write directly (prevents location spoofing). `select` filtered to row owner OR (`auth.uid()` is the matched passenger of an active ride).
  - `ride_requests`: passengers `insert` their own; drivers `select` rows where `status='open'` AND ST_DWithin(`pickup`, current driver location, `request_radius_m`). Driver location for the predicate comes from a SECURITY DEFINER function `current_driver_location()` that reads `driver_presence`.
  - `ride_bids`: drivers `insert` own bids on open requests; drivers `select` own bids; passengers `select` bids on their own open request.
  - `trips`: read by participating driver or passenger only.
  - `trip_locations`: read by participating driver, passenger during active trip, admin always.
  - `messages`: `select` and `insert` only by participants in the trip.
- **Realtime requirements:** Realtime respects RLS by default (Supabase reads RLS for the subscribing user). Confirm with a smoke test: a driver subscribed to `ride_requests` channel must not receive another driver's already-matched request.
- **State management:** — N/A.
- **Validation rules:** Every policy includes `with check` for inserts/updates; never just `using` for write paths.
- **Error handling:** RLS violations surface as `42501 permission denied`; the Flutter network layer (DRV-003) translates to a user-friendly "session expired or unauthorised" and forces re-auth if the JWT looks stale.
- **Security:** Service role used only by edge functions, never shipped to the client. SECURITY DEFINER functions fully qualified (`set search_path = public`) to prevent search-path attacks.
- **Analytics events:** `security.rls_violation { table, op, user_id }` from a Postgres event trigger (best-effort).
- **Edge cases:** Driver and passenger are the same `auth.uid()` (an employee testing) — both policy sets fire harmlessly. Admin user with `role='admin'` claim short-circuits via `(auth.jwt() ->> 'role') = 'admin'` clause appended to every policy.
- **Definition of done:** Negative tests in `supabase/tests/rls/` pass; `supabase test db` is green in CI.

---

### PLAT-004 — Realtime channel topology
- **Epic:** Platform Foundation
- **Priority:** P0 · **Complexity:** M · **Order:** 4 · **Depends on:** PLAT-003
- **Goal:** Define every realtime channel name, payload shape, and authorisation rule the driver app subscribes to or broadcasts on, so engineers don't invent channel names ad hoc.
- **User story:** As a Flutter engineer, I want a single document I consult to know exactly which channel to subscribe to and what shape its events take, so that I never hardcode strings or guess payloads.
- **Description:** Adopt three channel families:
  - **Postgres-changes channels** (driven by `replica identity full` + `publication`): cheap, automatic, filtered server-side.
    - `public:driver_presence:driver_id=eq.<self>` — driver's own presence (rarely used).
    - `public:ride_bids:driver_id=eq.<self>` — driver's own bids' state changes (won/lost/expired).
    - `public:trips:driver_id=eq.<self>` — trip state transitions.
    - `public:trip_events:trip_id=eq.<active>` — per-trip event firehose during a trip.
    - `public:subscriptions:driver_id=eq.<self>` — subscription status flips.
    - `public:messages:trip_id=eq.<active>` — chat messages.
  - **Broadcast channels** (low-latency fan-out, no DB write):
    - `marketplace:zone:<geohash6>` — open ride requests within a 6-char geohash cell. Drivers subscribe to the cells covering their current location + neighbours (9 cells) and re-subscribe on movement.
    - `trip:<trip_id>:driver_location` — driver streams their position to the passenger (and any co-listeners) at 1 Hz during active trip; not persisted on every tick (persistence is throttled to 5 s via PLAT-008 batched insert).
  - **Presence channels** (membership semantics):
    - `presence:online_drivers:<service_city>` — for ops dashboards; drivers join/leave when toggling online. The driver app does not subscribe to this; it only tracks its own presence via the realtime presence state.
- **Acceptance criteria:** Channel registry committed to `supabase/realtime/CHANNELS.md` with payload schemas (TypeScript types + Dart model). Driver app references constants from `lib/modules/commons/realtime/channels.dart`.
- **Frontend (Flutter) requirements:** A `RealtimeRegistry` Riverpod provider that yields strongly-typed channel handles; never call `client.channel('foo')` with a literal string from a feature module.
- **Backend (Supabase) requirements:** Configure Realtime publication `supabase_realtime` to include exactly the tables listed above. Set `realtime.max_concurrent_users` and `realtime.max_events_per_second` per project tier; document chosen values.
- **Realtime requirements:** Enforce that drivers can only subscribe to `*:driver_id=eq.<self>` filters by validating in a `realtime.broadcast_authorize` hook (Supabase Realtime Authorization, available 2024+).
- **State management:** Each channel's events feed a `StateNotifier`; the controllers de-duplicate by `id` and version (newest `updated_at` wins).
- **API/data dependencies:** Geohash library for Dart (`dart_geohash`) and PostgreSQL (custom function `geohash6(geography)`).
- **Validation rules:** Driver subscribes to at most 9 marketplace zones (centre + 8 neighbours). Re-subscription threshold: when driver moves more than 50% of cell width.
- **Error handling:** On disconnect, replay missed events from `ride_requests` table (poll `WHERE created_at > last_seen_at AND status='open'`).
- **Security:** Realtime authorisation hook rejects broadcasts to `marketplace:zone:*` from non-driver roles.
- **Analytics events:** `realtime.connected`, `realtime.disconnected { reason }`, `realtime.subscribed { channel }`, `realtime.event_received { channel, kind, latency_ms }`.
- **Edge cases:** Driver crosses a geohash cell boundary mid-trip — marketplace channel re-subscribe is skipped (driver is busy and not eligible for new requests).
- **Definition of done:** Smoke test: a passenger insert into `ride_requests` lands on the right driver's `marketplace:zone:*` channel within 250 ms p95 in stage.

---

### PLAT-005 — Edge Functions scaffold (Deno)
- **Epic:** Platform Foundation
- **Priority:** P0 · **Complexity:** S · **Order:** 5 · **Depends on:** PLAT-001
- **Goal:** Establish the deployment, structure, and shared utilities for every server-side function the driver app calls.
- **User story:** As a backend engineer, I want a project layout where adding a new edge function is a 60-second job with logging, auth, and validation already wired.
- **Description:** Create `supabase/functions/_shared/` with: `auth.ts` (extract & verify JWT, return `{ userId, role }`), `db.ts` (server-role Postgres client), `logger.ts` (structured JSON logs to stdout — Supabase forwards to Logflare), `errors.ts` (typed `AppError` with HTTP mapping), `validate.ts` (zod-style schema runner). Each function is a folder `<name>/index.ts` exporting a `Deno.serve` handler that uses the shared kit. Naming: `verb-noun` (`submit-bid`, `start-trip`, `request-payout`).
- **Acceptance criteria:** A new function can be created with `pnpm new-function <name>` (project Makefile or task) and deploys via CI on merge.
- **Backend (Supabase) requirements:** Functions deployed with `--no-verify-jwt false` (default-on JWT check); functions that must accept anonymous webhooks (Paystack) are explicitly listed and use a webhook signature instead of JWT.
- **Validation rules:** Every handler validates input with the shared schema runner. Invalid input → 400 with a stable `code` field (`invalid_payload`, `unauthorized`, `not_found`, `conflict`, `rate_limited`, `internal`).
- **Error handling:** Unhandled exceptions caught by a top-level wrapper; never leak stack traces to the client.
- **Security:** Service-role key consumed only inside the function runtime, fetched from `Deno.env.get('SERVICE_ROLE_KEY')`.
- **Analytics events:** `edge.invocation { name, status_code, duration_ms, user_id }` from the wrapper.
- **Edge cases:** Cold-start latency (Edge Functions are deno-deploy-style isolates) — accept p99 ~600ms first call; warm < 80ms. Document this expectation.
- **Definition of done:** Two reference functions deployed (`health` and `whoami`); both return JSON within 100ms warm.

---

### PLAT-006 — Storage buckets & signed-URL strategy
- **Epic:** Platform Foundation
- **Priority:** P0 · **Complexity:** S · **Order:** 6 · **Depends on:** PLAT-003
- **Goal:** A clean buckets-and-paths convention for KYC documents, vehicle photos, profile avatars, and chat attachments with strict RLS.
- **Description:** Buckets: `kyc-private` (private, 5 MB image limit, MIME whitelist `image/jpeg|png|heic|application/pdf`), `vehicle-photos` (private), `avatars` (public-read, 1 MB), `chat-attachments` (private). Path convention `{bucket}/{user_id}/{kind}/{uuid}.{ext}`. RLS policies on `storage.objects` mirror PLAT-003 (owner-only writes; reads via signed URL minted server-side).
- **Acceptance criteria:** Upload from the driver app via signed-URL POST works; another user cannot read the path; signed URLs expire in 60s for KYC, 1 h for chat attachments.
- **Frontend (Flutter) requirements:** A `StorageRepo` that mints upload URLs via an edge function (`mint-upload-url`) rather than letting the client choose paths.
- **Validation rules:** Server-side EXIF strip on KYC images (edge function `strip-exif` triggered on upload); MIME re-checked server-side via magic bytes (don't trust client-provided MIME).
- **Security:** No public bucket holds PII. Avatars are public-read by design.
- **Edge cases:** User retries upload after network drop → path collision avoided by UUID; orphan files swept by a daily cron (PLAT-013) for objects with no DB row pointing at them after 24 h.

---

### PLAT-007 — PostGIS, geohash, and geo-indexes
- **Epic:** Platform Foundation
- **Priority:** P0 · **Complexity:** S · **Order:** 7 · **Depends on:** PLAT-002
- **Goal:** Make spatial queries (nearby ride requests, in-zone presence, distance) fast and correct.
- **Description:** Enable extensions `postgis`, `pg_trgm`, `pgcrypto`. Create GIST indexes on `ride_requests.pickup`, `driver_presence.last_geo`, `trip_locations.geo`. Add a `geohash6(geography)` immutable function and a generated column `pickup_geohash6 text` on `ride_requests` with a btree index for fast zone fan-out. Establish a helper `find_nearby_drivers(p geography, radius_m int)` SECURITY DEFINER function used by the matchmaker.
- **Acceptance criteria:** `EXPLAIN ANALYZE` of "find nearest 20 drivers within 5 km of a point" finishes < 30 ms with 10 k presence rows.
- **Validation rules:** Always use `geography` (metre-based), never `geometry` for user-facing distance.
- **Edge cases:** Points near the antimeridian or 180° boundary — Nigeria is far from these but the helper functions should still be correct.

---

### PLAT-008 — Time-series tables: partitioning & retention
- **Epic:** Platform Foundation
- **Priority:** P0 · **Complexity:** M · **Order:** 8 · **Depends on:** PLAT-002, PLAT-007
- **Goal:** Keep `trip_locations`, `trip_events`, and `subscription_events` from bloating the main DB.
- **Description:** Convert `trip_locations` to a monthly-partitioned table via `pg_partman` (`PARTITION BY RANGE (recorded_at)`). Retain 90 days online, archive older partitions to a `cold` schema or to S3 via daily export. Same pattern for `trip_events` (12 months online, 36 months cold).
- **Acceptance criteria:** Partman cron creates next month's partition automatically; old partitions detached on schedule; insert performance flat as data grows.
- **Backend requirements:** Batched inserts from the trip stream (PLAT-013 worker) — driver app posts location to a Realtime broadcast channel at 1 Hz; a worker batches and writes every 5 s in groups of 5 with a single `COPY`.
- **Edge cases:** A trip that crosses a month boundary lands its early points in one partition and later in the next — both partitions queried via the parent table; transparent.

---

### PLAT-009 — Termii SMS provider integration (OTP)
- **Epic:** Platform Foundation
- **Priority:** P0 · **Complexity:** S · **Order:** 9 · **Depends on:** PLAT-005
- **Goal:** Drivers receive sub-15s OTP SMS to their +234 numbers via Termii (DND-route) with a fallback to a second provider on failure.
- **Description:** Configure Supabase Auth's phone provider to use Termii via the GoTrue `phone_template` and a custom HTTP hook (`send-sms` edge function) since Supabase's built-in Twilio provider isn't ideal for Nigerian DND. Hook signs requests with Termii API key, picks the `dnd` route, retries on 5xx, falls back to Sendchamp on second failure.
- **Acceptance criteria:** OTP delivered to MTN, Glo, Airtel, 9mobile lines in < 15s p95. SMS body contains 6-digit code and expiry text.
- **Validation rules:** Phone normalised to E.164 server-side. Reject obviously fake numbers (e.g., `+2340000000000`).
- **Error handling:** If both providers fail, return a 503 with `code: sms_provider_unavailable`; the app shows a retry CTA.
- **Security:** Rate-limit `send-sms` to 1 per phone per 30s, 5 per phone per hour, 50 per IP per hour (PLAT-013 limiter).
- **Analytics events:** `auth.otp_sent { provider, latency_ms }`, `auth.otp_failed { reason }`.

---

### PLAT-010 — Paystack integration (subscriptions + transfers)
- **Epic:** Platform Foundation
- **Priority:** P0 · **Complexity:** L · **Order:** 10 · **Depends on:** PLAT-005
- **Goal:** Drivers can activate a subscription, the system auto-renews, and drivers can be paid out.
- **Description:** Two surfaces:
  1. **Subscriptions** — Paystack plan `drivio_pro_monthly` (₦XX,XXX/month). Edge function `create-subscription` initiates a transaction, returns the authorisation URL the Flutter app opens via `url_launcher`. Webhook `paystack-webhook` receives `charge.success`, `subscription.create`, `invoice.payment_failed`, `subscription.disable`; updates `subscriptions` and emits `subscription_events`.
  2. **Transfers (payouts)** — `request-payout` validates wallet balance, creates a Paystack recipient if absent, creates a transfer, and writes a `payouts` row. Webhook `transfer.success/failed` reconciles.
- **Acceptance criteria:** End-to-end stage flow: trial → activation → renewal → expiry → reactivation works. Payout request → bank credit observed in Paystack test sandbox.
- **Backend requirements:** Webhook signature verified with `x-paystack-signature` HMAC-SHA512. Webhook idempotency via `paystack_event_id` unique constraint on `subscription_events.payload->>'id'`.
- **Validation rules:** Payout minimum ₦5,000; maximum per day ₦500,000 for v1.
- **Error handling:** Failed renewal → schedule retries at +1d, +3d, +7d (Paystack does this natively, but mirror state). After final failure, flip subscription to `expired`, fire push notification, and the gate (DRV-032) takes effect.
- **Security:** Plan codes and provider IDs never trusted from the client; only from webhooks. Webhook IPs allowlisted (Paystack publishes a list).
- **Analytics events:** `subscription.activated`, `subscription.renewed`, `subscription.expired`, `subscription.payment_failed`, `payout.requested`, `payout.settled`, `payout.failed`.
- **Edge cases:** Paystack double-fires a webhook → idempotency stops the second write. Network blip during checkout → user lands on a "checking your payment…" screen that polls `subscriptions.status` for 30s before falling back to support.

---

### PLAT-011 — Background workers & cron (matchmaker, expiry sweeper, payouts, archiver)
- **Epic:** Platform Foundation
- **Priority:** P0 · **Complexity:** M · **Order:** 11 · **Depends on:** PLAT-005, PLAT-008
- **Goal:** Recurring server jobs that the driver app silently relies on.
- **Description:** Workers:
  - `expire_open_requests` (every 5 s) — flips `ride_requests.status='expired'` for rows past `expires_at`. Emits realtime update; driver app removes them from feed.
  - `expire_pending_bids` (every 5 s) — same pattern for `ride_bids`.
  - `subscription_expirer` (every minute) — flips `trialing|active` to `expired` when `current_period_end < now()`.
  - `presence_stale_cleaner` (every 30 s) — sets `driver_presence.status='offline'` if `last_seen_at < now() - interval '90 seconds'`.
  - `trip_location_archiver` (hourly) — exports yesterday's partition to S3 cold.
  - `orphan_storage_sweeper` (daily) — removes Storage objects with no DB referent older than 24 h.
  - `analytics_rollup` (every 15 min) — refreshes materialised views for driver earnings/acceptance metrics (PLAT-013).
- **Acceptance criteria:** Each job has a `status` row in a `cron_jobs` table; failures emit `cron.failed { name }` to monitoring.
- **Backend requirements:** Implement on `pg_cron` for SQL-only jobs and `Supabase Scheduled Functions` for jobs that hit external APIs.

---

### PLAT-012 — Materialised views for analytics
- **Epic:** Platform Foundation
- **Priority:** P1 · **Complexity:** S · **Order:** 12 · **Depends on:** PLAT-011
- **Goal:** Make the driver dashboard's earnings, acceptance, and cancellation queries O(1).
- **Description:** Materialised views `driver_daily_metrics`, `driver_weekly_metrics`, `driver_monthly_metrics` keyed on `(driver_id, period_start)`. Refreshed by `analytics_rollup` worker.
- **Acceptance criteria:** Driver dashboard query (DRV-072) runs < 50 ms p95.

---

### PLAT-013 — Rate limiting & abuse prevention
- **Epic:** Platform Foundation
- **Priority:** P0 · **Complexity:** S · **Order:** 13 · **Depends on:** PLAT-005
- **Goal:** Stop bid spam, OTP abuse, payout-poking.
- **Description:** Centralised limiter using Postgres + a sliding-window function `rate_check(key text, window_s int, max_count int)` returning bool. Wrap critical edge functions: `send-sms` (per phone, per IP), `submit-bid` (per driver per request, per driver per minute), `request-payout` (per driver per day).
- **Validation rules:** Limits documented per route in `supabase/functions/_limits.md`.
- **Error handling:** 429 with `retry_after_seconds`.

---

### PLAT-014 — Observability stack (logs, metrics, errors)
- **Epic:** Platform Foundation
- **Priority:** P0 · **Complexity:** S · **Order:** 14 · **Depends on:** PLAT-005
- **Goal:** When something breaks at 2 AM, an on-call engineer can find the cause within 10 minutes.
- **Description:** Sentry for client + edge function exceptions. Logflare for structured logs. Grafana Cloud for Postgres metrics (Supabase exposes PG metrics endpoint). Alerts: edge function 5xx rate > 1% over 5 min; Realtime disconnect rate > 5%; subscription webhook lag > 60 s; matching latency p95 > 1.5 s.

---

# EPIC 1 — Driver App Foundation

The Flutter project already exists per `knowledge.md`; these tickets harden it for production.

---

### DRV-001 — Supabase client bootstrap
- **Epic:** Driver App Foundation
- **Priority:** P0 · **Complexity:** S · **Order:** 15 · **Depends on:** PLAT-001, PLAT-003
- **Goal:** Initialise `supabase_flutter` once at startup with the right URL/anon key per flavour, persistent auth session storage, and a single `SupabaseClient` injected via `get_it`.
- **User story:** As a Flutter engineer, I want `Supabase.instance.client` to "just work" everywhere with the right environment, so that no feature module hand-rolls auth or networking config.
- **Description:** Add `supabase_flutter: ^2.x` to `pubspec.yaml`. In `setupServiceLocator(Flavor)` (existing `commons/di/di.dart`), call `await Supabase.initialize(url: cfg.supabaseUrl, anonKey: cfg.supabaseAnonKey, storageOptions: SupabaseStorageOptions(retryAttempts: 3), authOptions: FlutterAuthClientOptions(authFlowType: AuthFlowType.pkce, autoRefreshToken: true))`. Register `Supabase.instance.client` in `get_it` as `SupabaseClient`. Wire `Config` (existing) to expose `supabaseUrl` and `supabaseAnonKey` per flavour, sourced from `--dart-define` in `main_prod.dart` / `main_stage.dart`.
- **Acceptance criteria:** App launches in stage and prod against the right project. `Supabase.instance.client.auth.currentSession` is restored on cold start. No anon key in git history.
- **Frontend requirements:** Add `lib/modules/commons/supabase/supabase_module.dart` exporting typed accessors (`db`, `auth`, `storage`, `realtime`). Page modules import these, never `Supabase.instance.client` directly (mirrors the project's existing rule of "always go through the façade", same as `AppNavigation`).
- **Backend requirements:** PLAT-001 anon keys.
- **Realtime requirements:** Realtime client auto-connects on first subscribe.
- **State management:** A `sessionProvider = StreamProvider<AuthState>` that wraps `auth.onAuthStateChange`, used by `DRV-009`.
- **API/data dependencies:** `flutter_dotenv` is **not** used; we use compile-time `--dart-define` to keep secrets out of the asset bundle.
- **Validation rules:** App refuses to launch if either env var is empty (assert in `main`).
- **Error handling:** `Supabase.initialize` failure surfaces a fatal error screen with retry; do not silently no-op.
- **Security:** Anon key only ships in the binary; no service-role key on device under any circumstance.
- **Analytics events:** `app.started { flavour, app_version }`.
- **Edge cases:** Flavor mis-set in CI → wrong URL, surfaced as a banner in non-prod builds reading `STAGE` or `PROD` against the app bar.
- **Definition of done:** Cold-start auth restoration verified manually on iOS + Android.

---

### DRV-002 — Environment, flavours, and secrets
- **Epic:** Driver App Foundation
- **Priority:** P0 · **Complexity:** XS · **Order:** 16 · **Depends on:** DRV-001
- **Goal:** Every secret/value the app needs is declared in one place per flavour and supplied via `--dart-define` (or `--dart-define-from-file` in CI).
- **Description:** Add `lib/modules/commons/config/env.dart` with a `const` accessor pattern: `const String supabaseUrl = String.fromEnvironment('SUPABASE_URL');` etc. Update `main_prod.dart` / `main_stage.dart` to read from these. Document required defines: `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `SENTRY_DSN`, `POSTHOG_KEY`, `MAPBOX_TOKEN` (if used for tiles), `PAYSTACK_PUBLIC_KEY`.
- **Acceptance criteria:** `flutter run` without defines in stage prints a clear error listing missing keys.
- **Edge cases:** A new engineer cloning the repo gets a `make stage` and `make prod` that wires the right defines from `1Password CLI`.

---

### DRV-003 — Network resilience layer (retry · queue · dedupe)
- **Epic:** Driver App Foundation
- **Priority:** P0 · **Complexity:** M · **Order:** 17 · **Depends on:** DRV-001
- **Goal:** Critical writes (`submit-bid`, `start-trip`, `complete-trip`, `update-presence`) survive flaky 3G/4G without losing data or double-charging.
- **Description:** Build a `MutationQueue` provider that wraps every edge-function call with: idempotency key (UUIDv4 generated on the device, persisted to `Hive` until ack), exponential backoff (1, 2, 4, 8, 16 s; max 60 s), max 3 retries for non-idempotent ops, infinite-with-jitter for idempotent ones. The queue is durable across app restarts. UI surfaces "saving…" / "queued (offline)" / "failed — tap to retry" states.
- **Acceptance criteria:** Airplane-mode test: submit a bid offline → reconnect → bid lands exactly once. Server-side, edge function rejects duplicate idempotency keys.
- **Frontend requirements:** A `Mutation<T>` widget primitive other features use; tied to `MutationQueue`.
- **Backend requirements:** Edge functions accept `Idempotency-Key` header; cache successful responses for 24 h in a `idempotency_keys` table.
- **State management:** `MutationQueueController extends StateNotifier` exposing `pending`, `failed`.
- **Error handling:** 4xx is terminal (no retry, surface to user); 5xx and network errors retry.
- **Security:** Idempotency keys are random UUIDs, not user-derivable.

---

### DRV-004 — Crash reporting (Sentry)
- **Epic:** Driver App Foundation
- **Priority:** P0 · **Complexity:** XS · **Order:** 18 · **Depends on:** DRV-002
- **Goal:** Every uncaught exception, ANR, and native crash lands in Sentry with breadcrumbs.
- **Description:** Add `sentry_flutter`. Initialise in `main` before `runApp`; wrap `runApp` in `SentryFlutter.init(...)`. Tag each event with `flavor`, `driver_id` (after auth), `app_version`. Add navigator observer for screen breadcrumbs. Ignore well-known noisy errors (cancelled futures from disposed widgets).
- **Acceptance criteria:** Forced crash from a debug menu lands in stage Sentry within 30s.
- **Security:** `beforeSend` strips PII (phone numbers, BVN, NIN, email, full name) from event bodies via a regex sweep.

---

### DRV-005 — Analytics (PostHog)
- **Epic:** Driver App Foundation
- **Priority:** P0 · **Complexity:** XS · **Order:** 19 · **Depends on:** DRV-002
- **Goal:** A central analytics façade so feature tickets just call `Analytics.track(name, props)`.
- **Description:** Add `posthog_flutter`. Wrap with a `lib/modules/commons/analytics/analytics.dart` façade with typed event constructors (e.g., `Analytics.bidSubmitted(price: p, requestId: id)`). Identify the user post-auth with `driver_id`. Auto-track screen views via a navigator observer.
- **Acceptance criteria:** Events appear in PostHog within 60s; user properties (subscription status, kyc status) attach.
- **Edge cases:** Driver hasn't signed in yet — events go anonymously and are aliased on identify.

---

### DRV-006 — Push notifications (FCM)
- **Epic:** Driver App Foundation
- **Priority:** P0 · **Complexity:** M · **Order:** 20 · **Depends on:** DRV-001
- **Goal:** The driver receives reliable push for: bid won, bid lost (silent), trip events, subscription warnings, support replies, safety alerts.
- **Description:** Add `firebase_core`, `firebase_messaging`, `flutter_local_notifications`. Request permissions at the right moment (after onboarding, not at first launch). On token refresh, upsert into `device_tokens(driver_id, token, platform, app_version, last_seen_at)`. Server sends push via Firebase Admin from edge functions.
- **Acceptance criteria:** Token registered after sign-in. Test push lands on locked screen on iOS and Android. Tapping the push deep-links to the right screen via `AppNavigation`.
- **Frontend requirements:** Notification categories: `marketplace` (bid won), `trip`, `subscription`, `safety`, `support`, `system`. Each with its own channel ID on Android and category on iOS, sound and importance set per category (safety = max).
- **Backend requirements:** `device_tokens` table; cleanup on `Unregistered` errors during send.
- **Security:** Stripped of trip details — push body says "You won a ride" not "You won a ₦4,500 ride from VI to Lekki" because lockscreens are visible to others.
- **Edge cases:** User denies notification permission → the in-app realtime channels still drive UI; we degrade gracefully and surface a banner on the home page asking them to enable.

---

### DRV-007 — Force-update / version gate
- **Epic:** Driver App Foundation
- **Priority:** P0 · **Complexity:** XS · **Order:** 21 · **Depends on:** DRV-001
- **Goal:** When we ship a critical fix, we can compel users below a min version to upgrade.
- **Description:** A `app_config` table `{ min_supported_version, latest_version, force_update_message }`. App reads on launch via edge function `app-config` (cached 1 h). If `currentVersion < min_supported_version`, show a blocking screen with store link.
- **Acceptance criteria:** Toggling `min_supported_version` in stage forces the test device to the upgrade screen on next launch.

---

### DRV-008 — App lifecycle controller
- **Epic:** Driver App Foundation
- **Priority:** P0 · **Complexity:** S · **Order:** 22 · **Depends on:** DRV-001
- **Goal:** Centralise foreground/background transitions: pause/resume Realtime, pause location streaming on background (unless on a trip), refresh session.
- **Description:** A `WidgetsBindingObserver` mounted in `App`. On `paused`: stop marketplace channel subscriptions; keep trip channel + location streaming if `state.tripId != null`. On `resumed`: re-subscribe; replay missed events; re-validate session.
- **Acceptance criteria:** Backgrounding for 10 minutes off-trip → marketplace channel is closed (verified via Realtime dashboard); resuming reconnects within 2s.

---

### DRV-009 — Auth-state-driven router gate
- **Epic:** Driver App Foundation
- **Priority:** P0 · **Complexity:** S · **Order:** 23 · **Depends on:** DRV-001
- **Goal:** A single source of truth that decides which screen the user lands on at launch (welcome / verify / kyc / paywall / home).
- **Description:** A `BootstrapController` that, on launch, reads: `Supabase.auth.currentUser`, `drivers.kyc_status`, `vehicles` count, `subscriptions.status`. Computes a `BootstrapDestination`: `welcome | otp | kycPending | kycRejected | addVehicle | paywall | home | maintenance`. App's home initial route reads this once. Subsequent transitions handled per-flow.
- **Acceptance criteria:** Cold start with each combination of state lands on the right screen.
- **Edge cases:** Driver previously signed in but the session expired → silently push them back to `welcome` and surface a toast.

---

# EPIC 2 — Authentication & Identity

---

### DRV-010 — Phone OTP sign-in (Supabase Auth + Termii)
- **Epic:** Authentication
- **Priority:** P0 · **Complexity:** M · **Order:** 24 · **Depends on:** DRV-001, PLAT-009
- **Goal:** Drivers sign in with their +234 phone and a 6-digit SMS OTP.
- **User story:** As a Nigerian driver, I want to sign in with my phone and a one-time code so that I never manage a password and can switch devices safely.
- **Description:** Existing welcome / sign-in / OTP screens (per `knowledge.md`) get wired to `auth.signInWithOtp(phone: '+234XXX...')` and `auth.verifyOTP(token: code, phone: ..., type: OtpType.sms)`. The 6-digit pin input (`PinInput`) already exists.
- **Acceptance criteria:** Valid Nigerian number → SMS within 15s p95 → entering the right code lands on `BootstrapController`'s next destination. Wrong code → cell shake + reset; rate-limited after 5 wrong attempts.
- **Frontend requirements:** A `SignInController extends StateNotifier<SignInState>` with `state.phone`, `state.otpRequestedAt`, `state.resendCountdownSec`, `state.isVerifying`, `state.error`. Calls `auth.signInWithOtp` then transitions state. `OtpController` already exists; wire its `verify()` to `auth.verifyOTP`.
- **Backend requirements:** Custom SMS hook from PLAT-009.
- **Realtime requirements:** — N/A.
- **State management:** Controllers exposed via `signInControllerProvider` and `otpControllerProvider`.
- **API/data dependencies:** Supabase Auth phone provider configured to use the custom hook.
- **Validation rules:** Phone normalised to E.164 client-side using `intl_phone_field` or a hand-rolled normaliser. Reject < 10 digits after country code. OTP accepted only as 6 numeric digits.
- **Error handling:** Network error → "couldn't request code, retry" (idempotent). Wrong code → cell-level error + clear. Expired OTP → "code expired, tap resend". Rate-limited → "too many attempts, try again in N min" with countdown.
- **Security:** Resend cooldown 30s client-side, 60s server-side. After 5 failed verifications within 15 min, server locks the phone for 15 min (PLAT-013).
- **Analytics events:** `auth.signin_started`, `auth.otp_requested { resend_count }`, `auth.otp_verified_success`, `auth.otp_verified_failure { reason }`.
- **Edge cases:** SIM swap suspicion (phone has a brand-new auth.users row but the BVN matches an existing driver) is handled at KYC, not auth — auth itself just trusts the phone.
- **Definition of done:** End-to-end stage flow works on a real Nigerian SIM.

---

### DRV-011 — Sign-up (new driver creation)
- **Epic:** Authentication
- **Priority:** P0 · **Complexity:** S · **Order:** 25 · **Depends on:** DRV-010
- **Goal:** Convert a verified phone into a `profiles + drivers` row pair with the metadata captured in the existing 4-step setup form.
- **Description:** After OTP verify on first sign-in (i.e., the user had no `profiles` row), route to the existing sign-up form (name, email, referral code) and submit via edge function `complete-signup` which atomically inserts `profiles` and `drivers` rows.
- **Acceptance criteria:** New driver lands on KYC start (DRV-016) after submission. Re-submitting the form is a no-op (idempotent).
- **Validation rules:** Email format (optional in NG), name required, referral code (if entered) must exist in `profiles.referral_code`.
- **Edge cases:** Duplicate phone — Supabase Auth already prevents this; signup just routes existing users back to home.

---

### DRV-012 — Session refresh & secure token storage
- **Epic:** Authentication
- **Priority:** P0 · **Complexity:** S · **Order:** 26 · **Depends on:** DRV-001
- **Goal:** Tokens persist securely across launches and refresh in the background.
- **Description:** `supabase_flutter` already uses `flutter_secure_storage` if installed; install it explicitly. Configure `autoRefreshToken: true`. Add a `SessionGuard` that, on `onAuthStateChange` events `tokenRefreshFailed` or `signedOut`, kicks the user to `welcome`.
- **Acceptance criteria:** Killing the app and reopening 24 h later still finds the user signed in; an invalidated refresh token deterministically signs them out.

---

### DRV-013 — Biometric / PIN unlock
- **Epic:** Authentication
- **Priority:** P1 · **Complexity:** S · **Order:** 27 · **Depends on:** DRV-012
- **Goal:** When the device has biometrics, the driver can require Face/Touch ID on app open.
- **Description:** `local_auth` package. A user setting `Settings → App lock`. On lock-eligible launch, gate the home screen behind `local_auth.authenticate`. PIN fallback if biometrics unavailable (4-digit PIN stored hashed in secure storage).
- **Acceptance criteria:** Toggle on → next launch demands biometric. Failed auth → re-prompt; 5 fails → require full re-OTP sign-in.

---

### DRV-014 — Logout & device deauth
- **Epic:** Authentication
- **Priority:** P0 · **Complexity:** XS · **Order:** 28 · **Depends on:** DRV-012
- **Goal:** A clean sign-out that revokes the session and clears device tokens.
- **Description:** `auth.signOut()`, then DELETE the device's `device_tokens` row, clear secure storage, navigate to `welcome`.
- **Edge cases:** Logout while online or on-trip is **disallowed** — the button is disabled and a sheet explains "go offline / finish trip first" (real safety concern: a driver shouldn't disappear mid-trip).

---

### DRV-015 — Account recovery
- **Epic:** Authentication
- **Priority:** P1 · **Complexity:** S · **Order:** 29 · **Depends on:** DRV-010
- **Goal:** A driver who lost the phone can recover their account with phone-port + BVN match (admin-assisted in v1).
- **Description:** "I lost my phone" link on welcome → opens a support ticket prompting BVN + selfie; ops admin verifies and updates `auth.users.phone` via Supabase admin SDK. Out of scope: self-serve.
- **Acceptance criteria:** Support runbook exists.

---

# EPIC 3 — KYC & Onboarding

---

### DRV-016 — KYC orchestrator state machine
- **Epic:** KYC & Onboarding
- **Priority:** P0 · **Complexity:** M · **Order:** 30 · **Depends on:** DRV-011
- **Goal:** A single controller that knows the driver's KYC status, the next step required, and what to do on each transition.
- **User story:** As a driver, I want a clear stepper that always shows me exactly which document is missing so that I never have to guess what's blocking me.
- **Description:** `KycController` exposes `state.steps: List<KycStep>` where each step has `kind`, `status` (`required|in_progress|submitted|approved|rejected`), `rejectionReason`. Steps in order: `bvn|nin`, `selfie_liveness`, `drivers_licence`, `vehicle_added` (handed off to vehicle epic), `vehicle_reg`, `insurance`, `road_worthiness`, `inspection_report`. KYC overall status is `not_started → in_progress → pending_review → approved | rejected`. Approved status unlocks the paywall (DRV-026).
- **Acceptance criteria:** Driver can resume mid-flow. Realtime updates from admin (approve/reject) update the stepper instantly.
- **Frontend requirements:** A scrollable stepper on `KycHomePage`. Each step taps to its capture screen.
- **Backend requirements:** Edge function `kyc-submit-step` that writes/updates `documents` rows and bumps `drivers.kyc_status` deterministically.
- **Realtime requirements:** Subscribe to `public:documents:owner_user_id=eq.<self>` (or `drivers:user_id=eq.<self>`) and refresh stepper on row changes.
- **State management:** `kycControllerProvider`. Re-fetch on app resume.
- **API/data dependencies:** `documents`, `drivers`, `vehicles` (cross-reads).
- **Validation rules:** Cannot skip a required step. Image min resolution 1200×800 (vehicle docs), file ≤ 5 MB.
- **Error handling:** Upload failure → retry via mutation queue. Reviewer rejection → step shows reason and a "Re-upload" CTA.
- **Security:** Documents go to private bucket; client never sees other drivers' paths.
- **Analytics events:** `kyc.step_started { kind }`, `kyc.step_submitted`, `kyc.step_approved`, `kyc.step_rejected { reason }`, `kyc.completed`.
- **Edge cases:** Document expires later (e.g., insurance) → admin sweeper sets `status='expired'` and the driver's home page shows a banner; bidding is gated until they re-upload.
- **Definition of done:** A driver completes the entire KYC end-to-end on stage and reaches paywall.

---

### DRV-017 — BVN / NIN verification
- **Epic:** KYC & Onboarding
- **Priority:** P0 · **Complexity:** M · **Order:** 31 · **Depends on:** DRV-016
- **Goal:** Verify the driver's identity against NIBSS/NIMC via a verification provider (e.g., Dojah, Smile ID, Premium Trust).
- **Description:** Edge function `verify-bvn-or-nin` accepts the 11-digit BVN or NIN, calls the provider, and on success writes `drivers.bvn_verified_at` (or `nin_verified_at`) and the canonical name returned. UI captures the number, dob, and full name; backend asserts they match (Levenshtein ≤ 2 for first/last name).
- **Acceptance criteria:** Valid stage BVN passes; invalid BVN returns a friendly error.
- **Validation rules:** Exactly 11 digits. Lockout after 5 wrong attempts in 24 h.
- **Security:** BVN/NIN never logged; provider response stored hashed.
- **Edge cases:** Provider downtime → fall back to manual review (admin queue).

---

### DRV-018 — Selfie + liveness check
- **Epic:** KYC & Onboarding
- **Priority:** P0 · **Complexity:** M · **Order:** 32 · **Depends on:** DRV-016
- **Goal:** Confirm the driver is a real human matching the BVN photo.
- **Description:** Use the same provider's liveness SDK (or a video selfie + server-side analysis). On success, write `drivers.liveness_passed_at`, attach `documents` row of kind `profile_selfie`. Fallback to manual review on low confidence.
- **Acceptance criteria:** Pass at 95%+ confidence in well-lit conditions; fail with helpful guidance ("move to better light") on bad samples.

---

### DRV-019 — Document upload (DL · vehicle reg · insurance · road worthiness)
- **Epic:** KYC & Onboarding
- **Priority:** P0 · **Complexity:** M · **Order:** 33 · **Depends on:** DRV-016, PLAT-006
- **Goal:** A reusable capture screen for any document with camera + gallery, edge detection, brightness check, and metadata fields.
- **Description:** `DocumentCapturePage(kind: DocumentKind)`. Uses `image_picker` + a lightweight cropping step. For the driver's licence, OCR optional v1 (we ask the user to type the policy/expiry). Submits to `kyc-submit-step` with kind, file path (post-upload), and metadata fields (`policy_no`, `expiry_date` as appropriate).
- **Acceptance criteria:** Each of the 4 docs uploads, shows in stepper as `submitted`, appears in admin queue.
- **Validation rules:** Expiry must be in the future. File size ≤ 5 MB. Reject if blur score above threshold (basic Laplacian variance check) — surfacing "image too blurry".
- **Edge cases:** User uploads PDF instead of image — accept; admin reviewer can read either.

---

### DRV-020 — Onboarding gate (route guard)
- **Epic:** KYC & Onboarding
- **Priority:** P0 · **Complexity:** XS · **Order:** 34 · **Depends on:** DRV-016, DRV-009
- **Goal:** Until KYC is `approved` AND a vehicle is `active`, the driver cannot reach `home` (no marketplace, no bidding).
- **Description:** In `AppRouter.onGenerateRoute`, intercept routes to `home`/`paywall` and redirect to the next pending KYC step if `BootstrapController` says we're not approved.
- **Acceptance criteria:** Half-onboarded driver always lands on the right step on cold start.

---

### DRV-021 — Document review live updates
- **Epic:** KYC & Onboarding
- **Priority:** P0 · **Complexity:** XS · **Order:** 35 · **Depends on:** DRV-016
- **Goal:** When an admin approves or rejects a doc, the driver app reflects it within 2s.
- **Description:** Realtime subscription per DRV-016. On rejection, surface a notification (`kyc.step_rejected`) and route the user to the offending step.

---

# EPIC 4 — Vehicle Management

---

### DRV-022 — Add vehicle
- **Epic:** Vehicle Management
- **Priority:** P0 · **Complexity:** S · **Order:** 36 · **Depends on:** DRV-016
- **Goal:** Driver registers a vehicle with make, model, year, colour, plate, plus 4 photos (front, back, interior, plate).
- **Description:** Existing `add_vehicle` page wires to edge function `add-vehicle` which inserts a `vehicles` row (status `pending`) and `documents` rows for the photos.
- **Acceptance criteria:** Vehicle appears in stepper; admin can approve.
- **Validation rules:** Plate must match Nigerian plate regex (e.g., `[A-Z]{3}-?\d{3}[A-Z]{2}` or special formats). Year ≥ 2008 (configurable per service area). Make/model from a curated list to keep data clean.

---

### DRV-023 — Vehicle inspection upload
- **Epic:** Vehicle Management
- **Priority:** P1 · **Complexity:** S · **Order:** 37 · **Depends on:** DRV-022
- **Goal:** Annual inspection report attached to the vehicle.
- **Description:** Document of kind `inspection_report` linked to a `vehicle_id`. Reminders 30/14/7 days before expiry.

---

### DRV-024 — Vehicle approval state
- **Epic:** Vehicle Management
- **Priority:** P0 · **Complexity:** XS · **Order:** 38 · **Depends on:** DRV-022
- **Goal:** Driver sees `pending → active|suspended` clearly and cannot go online with a non-active vehicle.
- **Description:** Online toggle (DRV-034) reads `vehicles.status` and disables itself if not active.

---

### DRV-025 — Edit / replace vehicle
- **Epic:** Vehicle Management
- **Priority:** P2 · **Complexity:** S · **Order:** 39 · **Depends on:** DRV-022
- **Goal:** Swap to a different car without re-doing KYC. New vehicle requires its own approval; old vehicle marked `retired`.
- **Edge cases:** Driver mid-trip cannot swap.

---

# EPIC 5 — Subscription & Trial

---

### DRV-026 — Subscription plan catalog
- **Epic:** Subscription
- **Priority:** P0 · **Complexity:** XS · **Order:** 40 · **Depends on:** PLAT-010
- **Goal:** App fetches active plans for the paywall and management screens.
- **Description:** `subscription_plans` is read-only on the client (RLS allows authenticated SELECT). Cache for 1 h.
- **Acceptance criteria:** Paywall shows current plan price and benefits.

---

### DRV-027 — New-driver 90-day free trial
- **Epic:** Subscription
- **Priority:** P0 · **Complexity:** S · **Order:** 41 · **Depends on:** PLAT-010, DRV-016
- **Goal:** Every newly approved driver automatically gets a 90-day trial subscription.
- **User story:** As a new driver, I want to start earning immediately without paying upfront so that I can prove the platform is worth the subscription.
- **Description:** When `drivers.kyc_status` flips to `approved`, edge function `start-trial` inserts a `subscriptions` row with `status='trialing'`, `trial_ends_at = now() + interval '90 days'`, `current_period_end = trial_ends_at`. Trial is one-time per driver (uniqueness enforced by partial index `WHERE status='trialing'` and a `drivers.has_used_trial` flag).
- **Acceptance criteria:** Approved driver sees "Trial: 89 days left" on home and paywall says "Trial active — upgrade anytime". Re-approving a previously-suspended driver does NOT grant a new trial.
- **Backend requirements:** Trigger on `drivers.kyc_status` change to `approved` invokes `start-trial`. Idempotent.
- **Realtime requirements:** Driver app gets `subscriptions` insert on its channel; UI updates without refresh.
- **Validation rules:** `has_used_trial` cannot be reset by client; only admin can.
- **Edge cases:** Driver was approved, used trial, lapsed, returned 1 year later — they go straight to paid (no second trial). Document this in support runbook.
- **Analytics events:** `subscription.trial_started`, `subscription.trial_days_remaining { days }` (daily snapshot).

---

### DRV-028 — Activate paid subscription via Paystack
- **Epic:** Subscription
- **Priority:** P0 · **Complexity:** M · **Order:** 42 · **Depends on:** PLAT-010, DRV-027
- **Goal:** A paying driver can convert from trial (or expired state) to an active monthly subscription in one flow.
- **Description:** Paywall CTA → call `create-subscription` edge function → receive `authorization_url` → open with `url_launcher` (in-app browser). Success deeplinks back to `paywall_pending` screen which polls `subscriptions.status` for 60s. Webhook lands → realtime flips status to `active`.
- **Acceptance criteria:** End-to-end works on Paystack test cards. Failure paths handled (declined, network drop, abandon).
- **Validation rules:** Active driver cannot start a second subscription (server enforces).
- **Edge cases:** User pays but webhook is delayed 5 min — polling falls back to "we'll notify you when payment confirms" and a push lands when the webhook fires.

---

### DRV-029 — Auto-renewal & charge attempts
- **Epic:** Subscription
- **Priority:** P0 · **Complexity:** S · **Order:** 43 · **Depends on:** DRV-028
- **Goal:** Paystack charges the saved card automatically; failed charges trigger retries and notifications.
- **Description:** Paystack handles the renewal natively; we just listen to webhooks. On `invoice.payment_failed`, push "Renewal failed — update your card" and surface a banner.

---

### DRV-030 — Receipts & billing history
- **Epic:** Subscription
- **Priority:** P1 · **Complexity:** S · **Order:** 44 · **Depends on:** DRV-028
- **Goal:** Driver sees every charge with date, amount, status, and a downloadable receipt.
- **Description:** `subscription_events` of kind `charge.success` rendered as list. Receipt PDF generated server-side on demand (`get-receipt-pdf` edge function) or rendered client-side from JSON.

---

### DRV-031 — Subscription state realtime sync
- **Epic:** Subscription
- **Priority:** P0 · **Complexity:** XS · **Order:** 45 · **Depends on:** DRV-028
- **Goal:** Any change to `subscriptions` (admin grant, plan change, expiry) reaches the app within 2s.
- **Description:** Realtime subscription on `public:subscriptions:driver_id=eq.<self>`.

---

### DRV-032 — Subscription gate (hard block on expiry)
- **Epic:** Subscription
- **Priority:** P0 · **Complexity:** S · **Order:** 46 · **Depends on:** DRV-031, DRV-034
- **Goal:** When `subscriptions.status` is not `trialing|active`, the driver cannot go online; if currently online, they're forced offline; if currently in a bidding marketplace view, requests stop arriving.
- **User story:** As a platform operator, I want non-paying drivers to be unable to take rides so that the subscription model has teeth, while never stranding a passenger mid-trip.
- **Description:** Three integration points:
  - **Online toggle (DRV-034):** disabled with a banner "Subscription required" → tap → paywall.
  - **Marketplace channel subscription (DRV-040):** the controller refuses to subscribe when state ≠ `trialing|active`; if already subscribed, immediately unsubscribes.
  - **Active trip:** **never interrupted.** A trip in progress when a subscription expires runs to completion; new bids are blocked, but the current trip is sacred.
- **Acceptance criteria:** Test matrix: (offline + expired) → cannot toggle on. (online + expired triggered by webhook) → user is auto-flipped offline within 2s with a non-dismissable sheet. (on-trip + expired) → trip completes; after completion, user is offline and cannot toggle on.
- **Backend requirements:** A SECURITY DEFINER function `is_driver_active(driver_id) returns bool` checked by `submit-bid` and the toggle-online flow.
- **Realtime requirements:** `subscriptions` realtime flip drives the UI transition.
- **State management:** `subscriptionGateProvider` exposes `bool canBid`, `bool canGoOnline`. Every gated UI watches it.
- **Error handling:** Edge cases (PLAT-013) where realtime is disconnected → at the next bid attempt, `submit-bid` returns 403 `subscription_required` and the UI catches up.
- **Security:** Server is the source of truth; never trust client-side `canBid`.
- **Analytics events:** `subscription.gate_blocked { action }` whenever a gated action is attempted while expired.
- **Edge cases:** Webhook flips status from `active` → `past_due` mid-marketplace browsing. App receives realtime update, immediately unsubscribes from marketplace, shows a sheet over the home page. Outstanding bids are auto-withdrawn server-side via the `submit-bid` cleaner trigger.

---

### DRV-033 — Pre-expiry warnings (T-7 / T-3 / T-1 / T-0)
- **Epic:** Subscription
- **Priority:** P1 · **Complexity:** XS · **Order:** 47 · **Depends on:** DRV-027, DRV-028, DRV-006
- **Goal:** Drivers know in advance their trial or paid period is ending.
- **Description:** Cron job `subscription_expirer` also fires reminders 7d, 3d, 1d, 0d before `current_period_end`. Push + in-app banner.

---

# EPIC 6 — Driver Availability

---

### DRV-034 — Online/offline toggle
- **Epic:** Availability
- **Priority:** P0 · **Complexity:** M · **Order:** 48 · **Depends on:** DRV-032, DRV-035
- **Goal:** The single most important control on the home screen flips the driver between offline and online, gated by KYC, vehicle, and subscription.
- **User story:** As a driver, when I tap "Go online" I expect to start receiving requests within seconds, and when I tap "Go offline" I expect requests to stop within seconds.
- **Description:** Existing UI exists. Wire to: `goOnline()` calls edge function `go-online` (validates gates, opens marketplace channel server-side, returns ok); `goOffline()` calls `go-offline` (closes marketplace listener server-side, sets `driver_presence.status='offline'`). Local state mirrors server state and reconciles via realtime.
- **Acceptance criteria:** Going online opens the marketplace channel, registers presence, and starts location streaming. Going offline closes them. State survives a brief network blip.
- **Frontend requirements:** Reuses existing `OnlineToggle` widget. Disabled with explanatory tooltip when gate fails (no vehicle, no sub).
- **Backend requirements:** `go-online` validates `is_driver_active(uid)` AND a vehicle is `active` AND no active trip exists for another vehicle.
- **Realtime requirements:** Status update propagates to ops dashboard via `presence:online_drivers:<city>`.
- **State management:** `presenceControllerProvider` owns `status`. `homeControllerProvider` (existing) consumes it.
- **Validation rules:** Cannot go online without a known location fix (request permission first).
- **Error handling:** Permission denied for location → modal explaining why, with a deep link to settings.
- **Security:** Server enforces gates; client-side disable is UX-only.
- **Analytics events:** `presence.went_online`, `presence.went_offline { reason: user|gate|crash|background_kill }`.
- **Edge cases:** App killed while online → presence stale-cleaner (PLAT-011) sets offline within 90s. On next launch, `BootstrapController` shows "you were marked offline because the app closed".

---

### DRV-035 — Foreground location streaming
- **Epic:** Availability
- **Priority:** P0 · **Complexity:** M · **Order:** 49 · **Depends on:** DRV-034
- **Goal:** While online, the driver's position publishes to `driver_presence` at a battery-aware cadence.
- **Description:** Use `geolocator` (or `flutter_background_geolocation` for richer power management). Stream position with: 5 s interval when stationary (low accuracy), 1 s when moving > 5 km/h, 0.5 s while on-trip. Smoothed via Kalman or simple low-pass to avoid jitter. Each tick is sent to edge function `update-presence` (idempotent on `(driver_id, recorded_at)`); function writes to `driver_presence` with last-write-wins semantics.
- **Acceptance criteria:** Driving around stage shows position lerping smoothly on a map; battery drain < 8%/hour at typical brightness.
- **Backend requirements:** `update-presence` writes only `last_geo`, `last_seen_at`, `accuracy_m`, `heading_deg`, `speed_kph`, `battery_pct` — no row creation per tick (single row per driver).
- **Realtime requirements:** No realtime broadcast for presence updates while idle (saves bandwidth); only changes that matter (status flip) hit Realtime. During trips, location goes via `trip:<id>:driver_location` broadcast (DRV-054).
- **Validation rules:** Reject ticks with `accuracy_m > 200` (likely Wi-Fi-only fix).
- **Security:** Driver can update only own presence row (RLS).
- **Edge cases:** GPS lost → app shows "GPS weak" banner; if lost > 30s, driver auto-flipped offline.

---

### DRV-036 — Background location (Android + iOS)
- **Epic:** Availability
- **Priority:** P0 · **Complexity:** L · **Order:** 50 · **Depends on:** DRV-035
- **Goal:** Streaming continues when the app is backgrounded *during a trip* (and only then).
- **Description:** Use `flutter_background_geolocation` or platform-channels with `iOS Location Background Mode` and Android `ForegroundService`. Show a persistent notification "Drivio — driving" while on-trip per Android FGS rules. **Off-trip backgrounding stops streaming** (privacy + battery).
- **Acceptance criteria:** Backgrounding mid-trip continues to update passenger ETA. Backgrounding off-trip stops within 5s.
- **Validation rules:** Required permissions: `ACCESS_BACKGROUND_LOCATION` (Android 10+), `Always Allow` (iOS). If denied, the trip can still proceed but ETA degrades.
- **Edge cases:** OS kills the FGS — heartbeat detection (PLAT-011) flips presence offline; passenger app shows "driver lost connection".

---

### DRV-037 — Heartbeat & presence
- **Epic:** Availability
- **Priority:** P0 · **Complexity:** XS · **Order:** 51 · **Depends on:** DRV-035
- **Goal:** Every 30s while online, regardless of movement, send a heartbeat so the stale-cleaner doesn't flag the driver.
- **Description:** Periodic timer runs alongside location stream; sends a minimal `update-presence` with the last-known location.

---

### DRV-038 — Service-area geofencing
- **Epic:** Availability
- **Priority:** P1 · **Complexity:** S · **Order:** 52 · **Depends on:** DRV-034
- **Goal:** Drivers cannot go online outside the supported service area (Lagos for v1) — surfaced as "service not available in your area" with a waitlist CTA.
- **Description:** A `service_areas` table with polygons. `go-online` checks `ST_Contains` against the driver's location.

---

### DRV-039 — Battery & data optimisation
- **Epic:** Availability
- **Priority:** P1 · **Complexity:** S · **Order:** 53 · **Depends on:** DRV-035
- **Goal:** Reduce GPS frequency under low battery; prefer cell location at < 20%.
- **Description:** Adaptive cadence: <20% → 10s interval; <10% → 30s + low-accuracy; <5% → warn user we'll auto-flip offline at 3%.

---

# EPIC 7 — Marketplace Discovery

---

### DRV-040 — Realtime nearby request subscription
- **Epic:** Marketplace
- **Priority:** P0 · **Complexity:** L · **Order:** 54 · **Depends on:** PLAT-004, PLAT-007, DRV-035
- **Goal:** While online, the driver receives every relevant open ride request within 500 ms p95.
- **User story:** As a driver, I want ride requests to appear immediately as they're created nearby, so that I can compete for them while they're fresh.
- **Description:** Subscribe to `marketplace:zone:<geohash6>` for the centre cell + 8 neighbours. Re-subscribe when the driver crosses ~50% of cell width. Each event payload is `{ request_id, pickup, dropoff, expected_distance_m, expected_duration_s, expires_at, passenger_rating }`. Controller filters out: requests where the driver has already bid, requests with vehicle category mismatches, requests outside acceptable distance.
- **Acceptance criteria:** Latency from `passenger app insert` to `driver app render` < 500 ms p95 in stage with 100 concurrent drivers.
- **Frontend requirements:** `MarketplaceController extends StateNotifier<MarketplaceState>` with `state.activeRequests: List<RideRequest>` sorted by distance ascending. Existing UI (per `knowledge.md`) surfaces them as a list under the map.
- **Backend requirements:** Passenger app inserts `ride_requests` rows; `replica identity full` ensures payload completeness; a server-side trigger computes `pickup_geohash6` and broadcasts on `marketplace:zone:<gh>`.
- **Realtime requirements:** This channel is broadcast (not postgres-changes) to keep payload lean and bypass RLS for zone-fanout. Authorisation hook ensures only `role='driver'` may subscribe.
- **State management:** Per-request expiry timer (DRV-042) decrements every second.
- **API/data dependencies:** `find_nearby_drivers` not used here; passenger broadcasts to a zone, not directly to drivers.
- **Validation rules:** Maximum 9 channel subscriptions at once. New centre cell on movement triggers diff (subscribe new, unsubscribe old).
- **Error handling:** On disconnect, on resume call `list-open-requests-near` REST endpoint as backfill; merge with realtime.
- **Security:** A driver outside the zone cannot subscribe to its channel (auth hook checks).
- **Analytics events:** `marketplace.request_received { request_id, distance_m, latency_ms }`, `marketplace.request_expired_in_feed`.
- **Edge cases:** Passenger cancels before driver bids → broadcast `request_cancelled`; controller removes it. Two passengers in the same cell within 200 ms → both arrive; UI shows them in created-at order.

---

### DRV-041 — Request card rendering & sorting
- **Epic:** Marketplace
- **Priority:** P0 · **Complexity:** S · **Order:** 55 · **Depends on:** DRV-040
- **Goal:** A glanceable card per request showing pickup/dropoff, distance to pickup, total trip distance, ETA, passenger rating, and time remaining.
- **Description:** Existing `ride_request` UI variants get fed by `MarketplaceController`. Top-of-list is a hero card; subsequent compact rows. Auto-scroll to most-recent on new arrival is **disabled** (would yank the user away from one they're considering).
- **Validation rules:** Distance computed locally with the haversine formula against driver location for instant render; backend does not need to recompute per driver.

---

### DRV-042 — Per-request countdown
- **Epic:** Marketplace
- **Priority:** P0 · **Complexity:** XS · **Order:** 56 · **Depends on:** DRV-041
- **Goal:** Visual urgency without trusting client clocks.
- **Description:** Each card runs a `Ticker` against `expires_at` from server. Sub-second drift OK; if device clock skew > 30s, app trusts server-sent `now()` from a heartbeat ping.

---

### DRV-043 — Distance & ETA computation
- **Epic:** Marketplace
- **Priority:** P0 · **Complexity:** S · **Order:** 57 · **Depends on:** DRV-040
- **Goal:** Approximate ETA to pickup without burning maps API budget per request render.
- **Description:** Use straight-line distance × city factor (1.4 for Lagos) ÷ avg speed (25 km/h Lagos peak). Refine via Mapbox Directions only at the moment the driver opens the bid composer. Server stores `expected_distance_m`/`expected_duration_s` for the trip leg from a single Mapbox call when the request is created.

---

### DRV-044 — Multi-request handling
- **Epic:** Marketplace
- **Priority:** P0 · **Complexity:** S · **Order:** 58 · **Depends on:** DRV-040
- **Goal:** Drivers handle 5–10 concurrent open requests without UI lag.
- **Description:** Controller virtualises the list (`ListView.builder`); state stored in a `Map<String, RideRequest>` for O(1) update on realtime patches.

---

### DRV-045 — Reconnect & backfill on resume
- **Epic:** Marketplace
- **Priority:** P0 · **Complexity:** S · **Order:** 59 · **Depends on:** DRV-040, DRV-008
- **Goal:** After backgrounding, the feed correctly reflects the present state of nearby requests.
- **Description:** On `resumed`, call `list-open-requests-near(geohash6, neighbours)` returning all open requests; reconcile with current state; resubscribe to channels.

---

# EPIC 8 — Bidding (Pricing Submission)

---

### DRV-046 — Bid composer UI (3 variants)
- **Epic:** Bidding
- **Priority:** P0 · **Complexity:** M · **Order:** 60 · **Depends on:** DRV-040
- **Goal:** The hero feature: drivers name their price with three input variants (typed, slider, chips) — already designed.
- **User story:** As a driver, I want the price field to be the most prominent thing on the screen so that I never feel like a passive worker accepting a fare.
- **Description:** Existing `RideRequestPage` and its three variants are already built. This ticket wires them to:
  - `RideRequestController.submit()` → `submit-bid` edge function with `{ request_id, price_minor, currency, eta_seconds, idempotency_key }`.
  - Soft validation: warn if price < 0.5× or > 2× system-suggested fair-range fare (from `expected_distance_m × per_km`); never block.
- **Acceptance criteria:** Bid submit returns within 600 ms p95 and the card transitions to "Bid submitted — waiting for passenger". No fee multiplier applied to "you keep" (per `knowledge.md` rule #2).
- **Frontend requirements:** Existing `_PriceField`, `_TypeKeys`, slider, and chips. The keyboard-editable hero number is already implemented (per `knowledge.md` user-feedback rule #3) — preserve it.
- **Backend requirements:** `submit-bid` validates: subscription active, request still `open`, driver hasn't already bid, price is positive and ≤ ₦100,000 (configurable). Inserts `ride_bids` with `expires_at = ride_requests.expires_at`.
- **Realtime requirements:** Insertion triggers a broadcast on the passenger's `ride_request:<id>:bids` channel (out of driver-app scope).
- **State management:** `bidStatusProvider(requestId)` watches `public:ride_bids:driver_id=eq.<self>` filtered to this request id.
- **Validation rules:** Whole-naira input only. Min ₦200, max ₦100,000 (configurable per service area).
- **Error handling:** 409 `request_no_longer_open` → toast "request already taken" + remove from feed. 409 `already_bid` → idempotent success. 403 `subscription_required` → DRV-032 sheet.
- **Security:** Server enforces; client-side soft-warns.
- **Analytics events:** `bid.composed_opened { request_id, variant }`, `bid.submitted { request_id, price_minor, suggested_minor, distance_m }`.
- **Edge cases:** Passenger cancels mid-composition → channel event removes the request; composer auto-closes with a toast.

---

### DRV-047 — Submit bid edge function
- **Epic:** Bidding
- **Priority:** P0 · **Complexity:** S · **Order:** 61 · **Depends on:** DRV-046, PLAT-005
- **Goal:** Server-side bid creation with all guardrails.
- **Description:** Validates gates, inserts `ride_bids` row, emits realtime broadcast to passenger, returns `{ bid_id, expires_at }`.
- **Validation rules:** UNIQUE(`request_id`, `driver_id`) prevents duplicate bids; if conflict, return existing bid (idempotent).

---

### DRV-048 — Bid lifecycle realtime updates
- **Epic:** Bidding
- **Priority:** P0 · **Complexity:** S · **Order:** 62 · **Depends on:** DRV-047
- **Goal:** Driver sees `pending → accepted | rejected | expired | withdrawn` instantly.
- **Description:** Subscription on `public:ride_bids:driver_id=eq.<self>`. On `accepted`: push haptic feedback + advance to active trip. On `rejected` (passenger picked someone else): toast "another driver was chosen". On `expired`: silent removal.

---

### DRV-049 — Cancel/withdraw bid
- **Epic:** Bidding
- **Priority:** P0 · **Complexity:** XS · **Order:** 63 · **Depends on:** DRV-047
- **Goal:** Driver can withdraw a pending bid before the passenger accepts.
- **Description:** Edge function `withdraw-bid` flips `status='withdrawn'`. UI shows a "Withdraw" button on submitted-bid card.
- **Edge cases:** Race: passenger accepts at the same instant. Server returns 409 `bid_already_accepted` and the trip flow takes over.

---

### DRV-050 — Anti-spam bid limits
- **Epic:** Bidding
- **Priority:** P0 · **Complexity:** XS · **Order:** 64 · **Depends on:** PLAT-013
- **Goal:** A driver cannot bid on more than N requests/minute or have more than M concurrent pending bids.
- **Description:** Limits enforced server-side: 10 concurrent pending bids, 30 bids/minute. Surfaced as "you've hit your bid limit, focus on a few".

---

### DRV-051 — Win/lose result handling
- **Epic:** Bidding
- **Priority:** P0 · **Complexity:** S · **Order:** 65 · **Depends on:** DRV-048
- **Goal:** Clean transition from "won a bid" to "active trip" with no UI flicker.
- **Description:** On bid `accepted` realtime event, controller hands off `bid_id`/`trip_id` to `ActiveTripController`; existing `active_trip` page mounts.

---

# EPIC 9 — Active Trip Lifecycle

---

### DRV-052 — Trip state machine
- **Epic:** Active Trip
- **Priority:** P0 · **Complexity:** M · **Order:** 66 · **Depends on:** DRV-051
- **Goal:** A deterministic FSM `assigned → en_route → arrived → in_progress → completed | cancelled` driven by client actions and server validation.
- **User story:** As a driver, I want the trip controls to advance only when the rules are satisfied (e.g., I can only mark "arrived" once I'm near the pickup), so that I cannot accidentally short-circuit the flow.
- **Description:** `ActiveTripController extends StateNotifier<ActiveTripState>`. Edge functions per transition (`start-trip-en-route`, `arrive-at-pickup`, `start-trip-in-progress`, `complete-trip`, `cancel-trip`). Each writes a `trip_events` row and updates `trips.state`.
- **Acceptance criteria:** Driver UI cannot send a transition out of order. Server returns 409 if it sees an out-of-order transition (idempotent if same state). Realtime `trip_events` updates the passenger app simultaneously.
- **Frontend requirements:** Existing 4-state UI (per `knowledge.md`). The bottom-sheet button advances the state only if the geofence and time guards pass (DRV-055).
- **Backend requirements:** Each transition function validates current `trips.state` before mutating.
- **Realtime requirements:** `public:trips:driver_id=eq.<self>` for self; `public:trip_events:trip_id=eq.<active>` for both parties.
- **State management:** Trip ID stored in `tripIdProvider`; controller hydrates from REST on resume.
- **Validation rules:** State transitions are linear; no skipping in v1.
- **Error handling:** Idempotent calls (e.g., double-tap "I've arrived") return current state without error.
- **Security:** Only the assigned driver can transition.
- **Analytics events:** `trip.transition { from, to, latency_ms }`.
- **Edge cases:** Driver completes the trip far from the dropoff coordinate (rider asked for a detour) → allow but flag for review.

---

### DRV-053 — Navigation handoff
- **Epic:** Active Trip
- **Priority:** P0 · **Complexity:** S · **Order:** 67 · **Depends on:** DRV-052
- **Goal:** A "Navigate" button opens Google Maps / Apple Maps for turn-by-turn.
- **Description:** Use `url_launcher` with `comgooglemaps://?daddr=lat,lng&directionsmode=driving` (Android), `http://maps.apple.com/?daddr=lat,lng&dirflg=d` (iOS), with web Google Maps fallback. v1 does not embed turn-by-turn.

---

### DRV-054 — Live location publish during trip
- **Epic:** Active Trip
- **Priority:** P0 · **Complexity:** M · **Order:** 68 · **Depends on:** DRV-052, DRV-035
- **Goal:** Passenger sees the driver moving in realtime; the system records a sampled trail for receipts/disputes.
- **Description:** While trip state ∈ {`en_route`, `arrived`, `in_progress`}, broadcast on `trip:<id>:driver_location` at 1 Hz. Server-side worker batches every 5 s and writes to `trip_locations` (PLAT-008).
- **Acceptance criteria:** Passenger map updates within 1.2 s p95.
- **Validation rules:** Broadcasts beyond `current_period_end + 1h` are ignored (anti-leak).

---

### DRV-055 — Arrived check-in (geofence-based)
- **Epic:** Active Trip
- **Priority:** P0 · **Complexity:** XS · **Order:** 69 · **Depends on:** DRV-052
- **Goal:** Driver cannot mark "arrived" unless within ~80 m of pickup (or a manual override after 3 minutes of being close-ish).
- **Description:** Client checks distance; server enforces ≤ 200 m as the hard ceiling.

---

### DRV-056 — Start trip
- **Epic:** Active Trip
- **Priority:** P0 · **Complexity:** XS · **Order:** 70 · **Depends on:** DRV-055
- **Goal:** Driver starts the trip after rider boards. Locks fare. Locks ETA.
- **Description:** `start-trip-in-progress`. Records `trips.started_at`. Fare is **already locked** at bid acceptance.

---

### DRV-057 — Complete trip & fare credit
- **Epic:** Active Trip
- **Priority:** P0 · **Complexity:** S · **Order:** 71 · **Depends on:** DRV-056
- **Goal:** Driver completes; wallet credited; passenger app shown receipt.
- **Description:** `complete-trip` writes `trips.ended_at`, `actual_distance_m`, `actual_duration_s` (computed from `trip_locations`), inserts `wallet_ledger` row of kind `trip_credit`, fires push to passenger.
- **Edge cases:** Tip from passenger (post-trip) → separate ledger entry, asynchronous.

---

### DRV-058 — Driver-initiated cancellation
- **Epic:** Active Trip
- **Priority:** P0 · **Complexity:** S · **Order:** 72 · **Depends on:** DRV-052
- **Goal:** Driver can cancel before pickup with a reason; cancellation rate impacts.
- **Description:** Reasons: `passenger_no_show` (after 5 min waiting + 2 calls), `unsafe_pickup`, `vehicle_issue`, `personal_emergency`. Each reason has different penalty weight. Server validates timing rules (e.g., `passenger_no_show` requires waiting timer met).

---

### DRV-059 — Passenger-cancelled handling
- **Epic:** Active Trip
- **Priority:** P0 · **Complexity:** XS · **Order:** 73 · **Depends on:** DRV-052
- **Goal:** Driver app gracefully handles `cancelled` event with reason, returns to home.
- **Description:** Realtime `trips` update to `cancelled`. Existing `EdgeRiderCancelledPage` shown.

---

### DRV-060 — Post-trip rating (driver rates passenger)
- **Epic:** Active Trip
- **Priority:** P1 · **Complexity:** XS · **Order:** 74 · **Depends on:** DRV-057
- **Goal:** Driver rates the passenger 1–5 with optional tags.
- **Description:** Inserts a row into `passenger_ratings` (covered in PLAT-002 v1.1).

---

# EPIC 10 — Realtime Comms (Chat / Call / Quick Replies)

---

### DRV-061 — In-app chat (driver ↔ rider)
- **Epic:** Comms
- **Priority:** P1 · **Complexity:** M · **Order:** 75 · **Depends on:** DRV-052
- **Goal:** Lightweight text chat scoped to the active trip.
- **Description:** Existing `chat` page wires to `messages` table inserts and `public:messages:trip_id=eq.<active>` realtime. Quick replies pre-populated from a server-side list (driver-side: "On my way", "I've arrived", "Stuck in traffic").
- **Validation rules:** Chat available only while trip is in non-terminal states.

---

### DRV-062 — Masked voice call
- **Epic:** Comms
- **Priority:** P1 · **Complexity:** M · **Order:** 76 · **Depends on:** DRV-052
- **Goal:** Driver and passenger can call without exposing personal numbers.
- **Description:** Use a phone masking provider (Africa's Talking Voice, or Twilio Programmable Voice). Edge function `start-masked-call` mints a temporary number; `tel:` link launches dialer.
- **Edge cases:** Call after trip end allowed for 30 min (lost-item recovery).

---

### DRV-063 — Quick reply templates
- **Epic:** Comms
- **Priority:** P2 · **Complexity:** XS · **Order:** 77 · **Depends on:** DRV-061

---

# EPIC 11 — Earnings & Wallet

---

### DRV-064 — Trip earnings ledger
- **Epic:** Earnings
- **Priority:** P0 · **Complexity:** S · **Order:** 78 · **Depends on:** DRV-057
- **Goal:** A reliable ledger of every credit, debit, and adjustment.
- **Description:** Reads `wallet_ledger`; renders as paginated list. Filters: today/week/month/all.

---

### DRV-065 — Wallet balance
- **Epic:** Earnings
- **Priority:** P0 · **Complexity:** XS · **Order:** 79 · **Depends on:** DRV-064
- **Goal:** Real-time available balance with pending lockups separated.
- **Description:** Uses materialised view or `wallets.balance_minor` (kept consistent by triggers on `wallet_ledger`).

---

### DRV-066 — Payout request
- **Epic:** Earnings
- **Priority:** P0 · **Complexity:** M · **Order:** 80 · **Depends on:** PLAT-010, DRV-065
- **Goal:** Driver withdraws balance to bank account.
- **Description:** Add bank account UI (account number + bank chooser → resolved via Paystack `bankResolve`). `request-payout` edge function checks balance, creates Paystack transfer, writes `payouts` and `wallet_ledger`. Real-time webhook flips `payouts.status`.
- **Validation rules:** Min ₦5,000; max daily ₦500,000. KYC level required (BVN-verified).
- **Error handling:** Failed transfer → balance refunded automatically.
- **Security:** Bank account details verified server-side via Paystack `resolveAccount` before saving.

---

### DRV-067 — Payout history
- **Epic:** Earnings
- **Priority:** P0 · **Complexity:** XS · **Order:** 81 · **Depends on:** DRV-066

---

### DRV-068 — Daily / weekly summary
- **Epic:** Earnings
- **Priority:** P1 · **Complexity:** S · **Order:** 82 · **Depends on:** PLAT-012

---

# EPIC 12 — Pricing Strategy Tools

---

### DRV-069 — Default base fare + per-km
- **Epic:** Pricing Strategy
- **Priority:** P1 · **Complexity:** S · **Order:** 83 · **Depends on:** —
- **Goal:** Driver pre-configures defaults that pre-fill the bid composer's suggested price.
- **Description:** `driver_pricing_profile(driver_id PK, base_minor, per_km_minor, peak_multiplier, peak_windows jsonb, night_multiplier, ...)`. Existing pricing UI wires to this. Bid composer reads it and computes a personalised "suggested price".

---

### DRV-070 — Peak hour profiles
- **Epic:** Pricing Strategy
- **Priority:** P1 · **Complexity:** XS · **Order:** 84 · **Depends on:** DRV-069
- **Goal:** Driver toggles peak windows; suggestions multiply.

---

### DRV-071 — Trip preferences
- **Epic:** Pricing Strategy
- **Priority:** P2 · **Complexity:** S · **Order:** 85 · **Depends on:** DRV-069
- **Goal:** Driver filters request feed by long/short/airport.
- **Description:** Filter happens client-side on the `MarketplaceController` to keep server-side fanout simple.

---

# EPIC 13 — Driver Analytics

---

### DRV-072 — Earnings chart (daily/weekly/monthly)
- **Epic:** Analytics
- **Priority:** P1 · **Complexity:** S · **Order:** 86 · **Depends on:** PLAT-012
- **Description:** Reads materialised views; renders with `fl_chart`.

---

### DRV-073 — Acceptance / cancellation metrics
- **Epic:** Analytics
- **Priority:** P1 · **Complexity:** XS · **Order:** 87 · **Depends on:** PLAT-012

---

### DRV-074 — Insights / coach tips
- **Epic:** Analytics
- **Priority:** P2 · **Complexity:** M · **Order:** 88 · **Depends on:** PLAT-012
- **Description:** Server-computed tips ("you earn 23% more on Friday evenings"). v1 = a curated rule set (no ML).

---

### DRV-075 — Demand heatmap
- **Epic:** Analytics
- **Priority:** P2 · **Complexity:** M · **Order:** 89 · **Depends on:** PLAT-007
- **Description:** Aggregate of recent `ride_requests.pickup` by H3 hex; rendered as overlay. Refreshed every 5 min.

---

# EPIC 14 — Profile · Documents · Reviews

---

### DRV-076 — Profile editor
- **Epic:** Profile
- **Priority:** P0 · **Complexity:** XS · **Order:** 90 · **Depends on:** DRV-011

---

### DRV-077 — Document expiry warnings
- **Epic:** Profile
- **Priority:** P0 · **Complexity:** XS · **Order:** 91 · **Depends on:** DRV-019
- **Description:** Banner at 30/14/7/0 days before expiry. After expiry, online toggle disabled.

---

### DRV-078 — Reviews & ratings
- **Epic:** Profile
- **Priority:** P1 · **Complexity:** S · **Order:** 92 · **Depends on:** DRV-057
- **Description:** Reads `driver_ratings` (passengers rate drivers post-trip).

---

### DRV-079 — Reupload document
- **Epic:** Profile
- **Priority:** P0 · **Complexity:** XS · **Order:** 93 · **Depends on:** DRV-019, DRV-021

---

# EPIC 15 — Safety & Trust

---

### DRV-080 — SOS button & escalation
- **Epic:** Safety
- **Priority:** P0 · **Complexity:** M · **Order:** 94 · **Depends on:** DRV-052
- **Goal:** A 3-second long-press during a trip alerts safety ops with the driver's location and trip details.
- **Description:** Inserts `safety_events` row with severity `critical`; ops dashboard pages on-call. Driver app shows "Help on the way" with a call-emergency button.
- **Validation rules:** Triple-tap is the alternate trigger to defeat duress.

---

### DRV-081 — Trusted contacts
- **Epic:** Safety
- **Priority:** P1 · **Complexity:** S · **Order:** 95 · **Depends on:** DRV-076
- **Description:** Drivers register up to 3 contacts; SOS pushes to them via SMS.

---

### DRV-082 — Trip sharing link
- **Epic:** Safety
- **Priority:** P1 · **Complexity:** S · **Order:** 96 · **Depends on:** DRV-052
- **Description:** Generates a public read-only URL of the live trip (driver position + ETA only); revoked at trip end + 1h.

---

### DRV-083 — Incident report
- **Epic:** Safety
- **Priority:** P1 · **Complexity:** S · **Order:** 97 · **Depends on:** DRV-057
- **Description:** Post-trip "report an issue" with categories (rude passenger, damage, accident, fraud).

---

# EPIC 16 — Support

---

### DRV-084 — Help articles
- **Epic:** Support
- **Priority:** P1 · **Complexity:** XS · **Order:** 98 · **Depends on:** —
- **Description:** Markdown content fetched from `help_articles` table; cached locally; linkable.

---

### DRV-085 — Support chat
- **Epic:** Support
- **Priority:** P1 · **Complexity:** M · **Order:** 99 · **Depends on:** DRV-061
- **Description:** Reuses chat infrastructure with a synthetic counterparty `support`.

---

### DRV-086 — Ticket history
- **Epic:** Support
- **Priority:** P2 · **Complexity:** XS · **Order:** 100 · **Depends on:** DRV-085

---

# EPIC 17 — Notifications

---

### DRV-087 — Push categories & preferences
- **Epic:** Notifications
- **Priority:** P0 · **Complexity:** S · **Order:** 101 · **Depends on:** DRV-006
- **Description:** Per-category toggles. Safety category cannot be disabled.

---

### DRV-088 — In-app notification center
- **Epic:** Notifications
- **Priority:** P1 · **Complexity:** S · **Order:** 102 · **Depends on:** DRV-006
- **Description:** A bell icon in the dashboard with unread count; reads `notifications` table.

---

# EPIC 18 — Settings & Account

---

### DRV-089 — Theme & language settings
- **Epic:** Settings
- **Priority:** P1 · **Complexity:** XS · **Order:** 103 · **Depends on:** —
- **Description:** Theme already exists; persist via `shared_preferences`. Language deferred to v1.1.

---

### DRV-090 — Delete account
- **Epic:** Settings
- **Priority:** P0 · **Complexity:** S · **Order:** 104 · **Depends on:** DRV-076
- **Goal:** GDPR/NDPR-compliant deletion request.
- **Description:** Soft-delete (`drivers.deleted_at`) + scheduled hard-deletion of PII after 30 days. Active trips block deletion.

---

# EPIC 19 — Edge States & Failure Recovery

---

### DRV-091 — Offline-first mutation queue
- **Epic:** Edge States
- **Priority:** P0 · **Complexity:** M · **Order:** 105 · **Depends on:** DRV-003
- **Description:** Already covered by DRV-003; this ticket adds UI surfaces for queued mutations (banner: "3 actions queued — will retry when online").

---

### DRV-092 — Reconnection orchestration
- **Epic:** Edge States
- **Priority:** P0 · **Complexity:** M · **Order:** 106 · **Depends on:** DRV-040, DRV-008
- **Description:** A central `ConnectivityController` tracks Realtime + REST + GPS health. Drives banners.

---

### DRV-093 — Subscription expired lock screen
- **Epic:** Edge States
- **Priority:** P0 · **Complexity:** XS · **Order:** 107 · **Depends on:** DRV-032
- **Description:** Existing `EdgeSubscriptionExpiredPage`; wired so that home redirects to it when status ∈ {`past_due`, `expired`}.

---

### DRV-094 — Network-poor mode
- **Epic:** Edge States
- **Priority:** P1 · **Complexity:** S · **Order:** 108 · **Depends on:** DRV-092
- **Description:** Detect 2G/EDGE; reduce realtime payload (skip avatars, lower trail sample); disable images in chat.

---

### DRV-095 — No-requests empty state
- **Epic:** Edge States
- **Priority:** P1 · **Complexity:** XS · **Order:** 109 · **Depends on:** DRV-040
- **Description:** Existing `EdgeNoRequestsPage`; tip rotation.

---

# EPIC 20 — Security & Compliance

---

### DRV-096 — RLS audit
- **Epic:** Security
- **Priority:** P0 · **Complexity:** S · **Order:** 110 · **Depends on:** PLAT-003
- **Description:** Quarterly audit; documented test cases checked into `supabase/tests/rls/`.

---

### DRV-097 — PII handling & encryption at rest
- **Epic:** Security
- **Priority:** P0 · **Complexity:** S · **Order:** 111 · **Depends on:** PLAT-002
- **Description:** Sensitive columns (`bvn`, `nin`, bank account) stored as `bytea` encrypted with `pgcrypto` symmetric key; key rotated yearly.

---

### DRV-098 — Audit logs
- **Epic:** Security
- **Priority:** P1 · **Complexity:** S · **Order:** 112 · **Depends on:** PLAT-005
- **Description:** Every admin action and sensitive operation appended to `audit_log` (immutable).

---

# EPIC 21 — QA & Launch

---

### DRV-099 — Test strategy
- **Epic:** QA
- **Priority:** P0 · **Complexity:** M · **Order:** 113 · **Depends on:** —
- **Goal:** Layered testing: widget, integration, RLS, load.
- **Description:** Widget tests for key controllers (auth, marketplace, bidding, trip). Integration tests that drive the auth → KYC → bid → trip flow against a stage Supabase. RLS tests in `supabase/tests/`. Load test marketplace channel with 1k synthetic drivers via `k6` (target: p95 < 500 ms).

---

### DRV-100 — Beta program (closed)
- **Epic:** Launch
- **Priority:** P0 · **Complexity:** S · **Order:** 114 · **Depends on:** —
- **Description:** TestFlight + Google Play Internal Testing with 25 hand-picked Lagos drivers. Daily standup with the cohort. PostHog dashboards reviewed nightly.

---

### DRV-101 — Launch checklist
- **Epic:** Launch
- **Priority:** P0 · **Complexity:** XS · **Order:** 115 · **Depends on:** all above
- **Goal:** A documented gate before flipping the public flag.
- **Description:** Includes: SLOs verified (Realtime p95, edge function p95, GPS-to-passenger latency); Sentry error rate < 0.5%; on-call rotation set; runbooks for all PLAT-* alerts; payment provider live keys verified; legal: ToS/Privacy/Driver Agreement signed by all beta drivers.

---

## Cross-cutting summary

**Order of attack for the team:**
1. PLAT-001…PLAT-007 (week 1) — backend fundamentals.
2. DRV-001…DRV-009 (week 1, parallel) — Flutter foundation.
3. DRV-010…DRV-021 (weeks 2–3) — auth + KYC.
4. DRV-022…DRV-033 (weeks 3–4) — vehicle + subscription (trial logic).
5. DRV-034…DRV-051 (weeks 4–6) — the marketplace heart: presence, discovery, bidding.
6. DRV-052…DRV-060 (weeks 6–7) — active trip.
7. DRV-061…DRV-071 (week 7) — chat/call, earnings, pricing strategy.
8. DRV-072…DRV-090 (weeks 8–9) — analytics, profile polish, settings.
9. DRV-091…DRV-098 (week 9) — resilience + security audits.
10. DRV-099…DRV-101 (week 10) — QA + launch.

Total: ~10–12 weeks for a 4-engineer team (2 mobile, 1.5 backend, 0.5 DevOps), assuming the design-existing assumption holds.

**Where the differentiator earns its keep:**
The four tickets that make Drivio "drivers as micro-entrepreneurs" rather than another Uber clone are **DRV-027** (free trial logic that lets new drivers prove the platform), **DRV-032** (subscription gate without commission), **DRV-046** (the bid composer as the hero of the home flow), and **DRV-040** (open marketplace fanout). Engineering effort should disproportionately weight quality and polish on those four.
