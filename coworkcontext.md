# Cowork Session Context — Drivio Driver Roadmap

> A complete, detailed record of the Cowork conversation that produced `driver.md` and `driver_context.md`. Captures every user prompt verbatim, every clarifying decision made, the deliverables produced, and the open items flagged at the end. Written so a future session (or a teammate) can read this single file and have full context of what happened, what was decided, and why.
>
> **Session date:** 4 May 2026
> **User:** waka-tech (`techAI@wakanow.com`)
> **Project:** Drivio Driver (Flutter ride-hailing driver app — Lagos-first)
> **Workspace:** `/Users/ebube.okocha/StudioProjects/drivio_driver`

---

## 1. Conversation arc at a glance

The session moved through four phases:

1. **Discovery.** User asked Claude to read the project's `knowledge.md` to understand what Drivio Driver is.
2. **Design-prompt review.** User shared the original Claude Design product brief that produced the visual prototype. Claude mapped the brief onto the existing build and called out gaps (subscription gating, market-hint UX, microinteractions).
3. **Engineering roadmap brief.** User issued a long, structured "Senior PM / Architect / Tech Lead" prompt asking for two production-grade documents: `driver.md` (engineering tickets for the driver app) and `driver_context.md` (architectural and product reasoning).
4. **Clarification + delivery.** Claude asked four high-leverage clarifying questions, the user answered, and Claude produced both documents, saving them to the workspace folder.

A fifth turn occurred after delivery — the present turn — in which the user asked for this conversation-context document.

---

## 2. Phase 1 — Discovery

### 2.1 User prompt (verbatim)

> "look at the knowledge.md of this project to know what it is about"

### 2.2 What Claude did

- Globbed for `knowledge.md` (file tools didn't see it because it's outside the file index initially); used a bash listing of `/sessions/eloquent-youthful-cannon/mnt/drivio_driver/` to confirm the file exists at the project root.
- Read the full 417-line `knowledge.md`.
- Summarised back to the user: Drivio Driver is a Flutter port of a marketplace driver app whose visual spec was a Claude-Design HTML prototype. Drivers go online, set their own per-trip fare, accept/decline rides, manage subscription ("Drivio Pro"), and manage profile/vehicle/documents/payments/support/edge states.

### 2.3 Key facts surfaced from `knowledge.md`

- **Tech:** Flutter, Riverpod (`StateNotifier`), `get_it` for DI, no `freezed`, no `auto_route` (string route constants + `AppNavigation` static façade).
- **Modules:** `commons`, `authentication`, `subscription`, `dash`, `trip`, `profile`, `cards`, `documents`, `vehicle`, `support`, `edge_states`.
- **State management rule:** every widget is `ConsumerWidget` / `ConsumerStatefulWidget` — no `StatelessWidget`/`StatefulWidget` (per `MIGRATION.md` §1.12).
- **Theme rule:** read colours via `context.bg`, `context.text`, `context.accent`; never raw `AppColors.*Dark`/`*Light`.
- **Map:** custom-painted (no `google_maps_flutter`) — keeps the prototype look and avoids API-key plumbing.
- **Default theme:** dark mode.
- **Font:** Inter via `google_fonts`.
- **Existing user-feedback rules absorbed during the original session:**
  1. No fake iOS chrome (status bar / home indicator widgets were deleted; do not recreate).
  2. "You keep" equals input price (no commission multiplier).
  3. The big price on the ride-request screen must be keyboard-editable.
  4. OTP cells use an invisible `TextField` overlay — don't replace with per-cell focus nodes.
- **Known limitations flagged:**
  - No subscription gating logic (paywall and expired-edge screens exist but no gate).
  - No persistence (theme mode, sign-in state, vehicle-on-file don't survive a restart).
  - No real auth/API.
  - No tests beyond a placeholder.
  - No iOS/Android platform tweaks.
  - No localisation.
- **Status of repo:** 92 Dart files, 39 screens; everything beyond the design spec is uncommitted in the working tree.

---

## 3. Phase 2 — Design-prompt review

### 3.1 User prompt (verbatim, abbreviated for length — full prompt preserved below)

> "Take a look at this prompt to see what was used to make the design of the application"

(Followed by the full Claude-Design design brief: ~1,000 words covering core product concept, design principles, key screens — onboarding/subscription, home dashboard, incoming ride request with custom pricing, active trip, earnings, price management, subscription management, profile/vehicle — edge cases, microinteractions, tone, and the "key differentiator: pricing control must feel central, visible, and powerful, not hidden".)

### 3.2 Full text of the design brief (preserved)

```
Design a modern, intuitive Driver (Rider) mobile application for a ride-hailing
platform similar to Uber, Bolt, and InDrive, but with a key differentiation:

Drivers operate like independent business owners — they set their own ride
prices and manage their earnings strategy.

The design should feel professional, trustworthy, and empowering, giving
drivers a sense of ownership and control over their work.

🧠 Core Product Concept
- Drivers are not just workers — they are micro-entrepreneurs
- They:
  - Set their own pricing per trip
  - Accept/reject ride requests based on price, distance, and preference
  - Manage their business performance
- Drivers must also pay a monthly subscription to stay active on the platform

🎨 Design Principles
- Clean, minimal, and highly functional (similar to Uber Driver)
- Emphasis on real-time decision-making
- Clear hierarchy of information (pricing, distance, earnings)
- Use subtle color coding:
  - Green → Earnings / Profit
  - Red → Expiry / Urgency / Subscription issues
  - Blue → Actions / Primary CTA
- Large touch targets for in-motion usability

📱 Key Screens & UX Flows
1. Onboarding & Subscription Flow
   - Welcome screen ("Be your own boss")
   - Account setup (personal info, vehicle, documents)
   - Pricing philosophy intro
   - Subscription paywall (plan, benefits, "Activate Subscription")
   - States: Active subscription, Expired (blocking)

2. Home Screen (Driver Dashboard)
   - Online/Offline toggle
   - Status indicator
   - Map: live position + nearby ride requests (heat zones / pins)
   - Bottom panel: today's earnings, # trips, performance summary
   - Floating CTA: "Set Price Mode"

3. Incoming Ride Request (Custom Pricing Flow)
   - Pickup/dropoff, distance, ETA, rider rating, suggested price
   - Editable price input (very prominent), slider/input
   - Accept with price, Counter-offer (optional), Decline
   - Show estimated earnings; real-time too-high/too-low feedback

4. Active Trip Screen
   - States: en route to pickup, waiting, in progress, completed
   - Navigation map, rider details, call/chat, fare locked

5. Earnings & Business Insights
   - Daily/weekly/monthly earnings, graphs, avg price, accept/cancel rates
   - Insights: "raise prices peak hours", "you earn more in zone X"

6. Price Management / Strategy Screen
   - Default base fare, per km, surge multiplier (manual), time-based pricing
   - Sliders, toggles, fields

7. Subscription Management
   - Current plan, expiry (urgency), payment history, Renew CTA
   - States: Active, Expiring soon, Expired (restricted)

8. Profile & Vehicle Management
   - Profile, vehicle, documents, ratings/reviews

🔄 Edge Cases & States
- No ride requests
- Poor network
- Subscription expired (critical lock)
- Ride cancelled by rider
- Price rejected by rider (if negotiation)

⚙️ Microinteractions
- Smooth ride-request transitions
- Haptic on accept/decline
- Realtime map updates
- Price-adjust animations
- Price-locked confirmation

📊 Design Tone
- Empowering, transparent, efficient

🔥 Key Differentiator
Pricing control must feel central, visible, and powerful, not hidden.
- Price input NEVER feels secondary
- Always reinforce "You decide your fare"
```

### 3.3 What Claude did

Mapped the brief against `knowledge.md` and reported alignment + gaps:

- **Tight alignment:** core concept (drivers as micro-entrepreneurs, no commission), screen list (12-screen core flow + sub-screens + extras + edge states all present), pricing-as-hero (3 variants on ride-request screen, keyboard-editable hero number), custom-painted map matching prototype, edge states all built, color-coding via design tokens.
- **Partial / unfulfilled:**
  - **Subscription enforcement is the biggest miss** — `PaywallPage` and `EdgeSubscriptionExpiredPage` exist as screens but nothing forces the user through them; no `SubscriptionController`, no route guard.
  - "Real-time feedback if price is too high/low (market hint)" is not present in the bid composer.
  - Counter-offer was correctly skipped (brief flagged it as optional).
  - Haptics + microinteractions not yet wired up (or at least not surfaced in `knowledge.md`).
- **Confirmed correct call:** "you keep equals input price" (no commission multiplier) lines up with the brief's flat-subscription model and was already corrected during the original build session.

Claude finished by offering: do a more rigorous audit, or sketch how to close the subscription-gating gap.

---

## 4. Phase 3 — Engineering roadmap brief

### 4.1 User prompt (verbatim, in full)

The user issued a multi-page structured prompt assigning Claude the roles of "Senior Product Manager, Product Owner, Systems Architect, and Technical Delivery Lead". Key sections:

- **Stance:** Think like a founder + senior engineer + solutions architect + DevOps lead simultaneously.
- **Product context:** ride-hailing platform similar to Uber/Bolt/inDrive, but drivers set prices; passengers receive multiple driver bids and pick; drivers pay monthly subscription. Ecosystem includes Passenger app, Driver app, backend, realtime matching, subscription/payment, notifications, analytics, admin tooling.
- **Scope clarification:** must reason about the WHOLE ecosystem (passenger app, marketplace flow, backend, realtime, DB, ride lifecycle sync, subscription, cross-platform transitions), but ONLY create implementation tickets for the Driver Application. Passenger-app referenced only where needed to explain driver flows or shared backend.
- **Core responsibilities:** break the driver app into detailed, production-ready engineering tickets covering the entire driver lifecycle (auth, onboarding, KYC, vehicle, subscription, online/offline, availability, request discovery, dynamic pricing, ride-offer lifecycle, ride acceptance sync, active ride, navigation, location streaming, realtime updates, earnings, wallet, notifications, support, analytics, settings, failure recovery, network resilience, realtime sync edge cases). No shallow tasks.
- **Deliverables:**
  1. `driver.md` — feature/task breakdown, organised by epic → feature → task, in implementation order. Each ticket: title, goal, description, user story, acceptance criteria, technical notes, frontend, backend, realtime, state management, API/data deps, validation, error handling, security, analytics, edge cases, priority, complexity, suggested implementation order.
  2. `driver_context.md` — reasoning behind product decisions, UX, architecture, realtime, pricing logic, subscription, marketplace sync, geo, state mgmt, Flutter recs, DB reasoning, Supabase strategy, scalability, offline, failure recovery, event sync, security, performance, tradeoffs, future-proofing.
- **Backend expectations:** Supabase Realtime, PostgreSQL scalability, geo-query optimisation, RLS, minimising expensive realtime subs, efficient location updates, ride-offer broadcasting, race-condition handling, mobile bandwidth optimisation, websocket connection mgmt, event-driven patterns.
- **Stack named:** Flutter + Supabase + `supabase_flutter`. References: pub.dev page and Supabase Dart docs.
- **Engineering expectations:** proactively identify missing requirements, weak UX, scalability problems, sync risks, data consistency issues, security risks, perf bottlenecks, state mgmt problems, mobile perf concerns, tech debt. Challenge weak product assumptions. Provide recommendations.
- **Constraints:** understand FULL ecosystem; ONLY create driver-app tickets; no passenger tickets; do NOT assume unclear business logic; ASK clarifying questions if needed; no shallow detail; no generic ticket generation; production-first, realtime-first, scalability-first, mobile-first.

### 4.2 What Claude did before producing the docs

Recognised four load-bearing decisions that would materially shape both documents and that the brief had left underspecified. Used `AskUserQuestion` to ask all four in one batch:

1. **Auction model** — Claude offered four options (open competitive auction; sealed-bid system-ranked; driver posted-price catalog; sequential single-offer) and recommended open competitive.
2. **Region / payments** — Nigeria-Paystack/Flutterwave (recommended); pan-African; global Stripe.
3. **Subscription enforcement** — hard block with 3-day grace (recommended); hard block immediate; soft warning only; configurable.
4. **Backend state** — greenfield Supabase project (recommended); existing project to extend; defer backend detail.

### 4.3 User's clarifying answers (verbatim)

| Question | User's answer |
|---|---|
| Auction model | "when a customer requests a ride the driver sees this ride and enters the price they will take for this ride and bid the platform does not force a price on them they are in full control of the price" — interpreted as the "open competitive auction" option |
| Region / payments | "Nigeria first, Paystack/Flutterwave (Recommended)" |
| Subscription enforcement | "hard block immediately at expiry but for a new driver they do not have to pay for the first three months" — interpreted as: hard block at expiry + 90-day free trial for new drivers (one-time, never re-grantable) |
| Backend state | "The project exists on supabase but it's totally empty, not table has been created" — interpreted as greenfield |

### 4.4 Decisions that flowed from the answers

- **Marketplace mechanic:** open competitive auction. Each driver may submit at most one bid per request (`UNIQUE (ride_request_id, driver_id)`); 60s default request expiry; passenger sees all pending bids and picks one; `accept-bid` runs as a serializable transaction that locks the request, accepts the chosen bid, rejects all others, and creates the trip atomically.
- **Trial logic:** automatic 90-day `trialing` subscription created when `drivers.kyc_status` flips to `approved`; `drivers.has_used_trial` flag prevents re-grant; trial converts to `active` on first paid charge; expired drivers can subscribe but never re-trial.
- **Hard block:** server-side gates in `go-online`, marketplace channel auth, and `submit-bid` all check `is_driver_active(user_id)`. UI mirrors via `subscriptionGateProvider`. Trips already in progress when expiry fires are sacred — they complete; only future bids are blocked.
- **Backend:** greenfield, so the roadmap defines schema, RLS, realtime channels, edge functions from scratch.
- **Region-shaped specifics:** NGN + kobo (`bigint` minor units); E.164 with assumed +234; BVN/NIN KYC via Dojah-class provider; Paystack subscriptions + transfers; Termii for SMS OTP (with Sendchamp fallback).

### 4.5 Pre-flight tool work

- Loaded `AskUserQuestion`, `TaskCreate`, and `TaskUpdate` schemas via `ToolSearch`.
- Created two tasks:
  - Task #1: "Author driver.md ticket roadmap"
  - Task #2: "Author driver_context.md architecture doc"

(Mid-stream, the user noted Claude had stopped generating; on the next turn Claude resumed and produced both files.)

### 4.6 What was produced — `driver.md`

Saved to `/Users/ebube.okocha/StudioProjects/drivio_driver/driver.md`. Structure:

- **Front matter:** scope statement, stack reference, region (Nigeria), differentiator, conventions table (priority P0–P3, complexity XS–XL, ID prefixes PLAT-/DRV-, ordering).
- **Epic map:** 22 epics (numbered 0–21) with ticket-id ranges and overall priority.
- **Tickets:** every ticket carries the same field set: Goal · User Story · Description · Acceptance Criteria · Frontend (Flutter) · Backend (Supabase) · Realtime · State Management · API/Data Deps · Validation · Error Handling · Security · Analytics events · Edge Cases · Priority · Complexity · Order · Depends on. Where a field is genuinely N/A (e.g. realtime on an offline-only screen), it is written `— N/A` rather than omitted, so reviewers know it was considered.

**Epic and ticket inventory (115 tickets total):**

- **Epic 0 — Platform Foundation (PLAT-001…014):** Supabase project bootstrap & migration workflow; core schema v1 (drivers/vehicles/documents/subscriptions/ride lifecycle/trips/wallet/payouts/messages tables); RLS baseline + JWT custom claims; realtime channel topology (postgres-changes vs broadcast vs presence families); Edge Functions (Deno) scaffold; Storage buckets (`kyc-private`, `vehicle-photos`, `avatars`, `chat-attachments`); PostGIS + geohash + GIST indexes; partitioning for `trip_locations` / `trip_events`; Termii SMS OTP integration; Paystack subscriptions + transfers; cron workers (matchmaker, expiry sweeper, payout reconciliation, archiver); materialised views for analytics; rate limiting; observability stack.
- **Epic 1 — Driver App Foundation (DRV-001…009):** `supabase_flutter` bootstrap; env/flavors via `--dart-define`; mutation queue with idempotency keys; Sentry; PostHog analytics façade; FCM with notification categories; force-update version gate; app lifecycle controller (foreground/background transitions); auth-state-driven router gate (`BootstrapController`).
- **Epic 2 — Authentication & Identity (DRV-010…015):** phone OTP sign-in; sign-up; secure token storage + refresh; biometric/PIN unlock; logout (disallowed mid-trip); manual account recovery v1.
- **Epic 3 — KYC & Onboarding (DRV-016…021):** KYC orchestrator state machine; BVN/NIN verification; selfie + liveness; document upload (DL/vehicle reg/insurance/road worthiness); onboarding gate route guard; live admin-review updates.
- **Epic 4 — Vehicle Management (DRV-022…025):** add vehicle; inspection upload; approval state; edit/replace.
- **Epic 5 — Subscription & Trial (DRV-026…033):** plan catalog; **90-day new-driver free trial (DRV-027) — auto-created on KYC approval, one-time-per-driver**; Paystack activation; auto-renewal; receipts; realtime subscription state sync; **hard-block gate (DRV-032) with three integration points (online toggle, marketplace channel, bid submit) and the rule that trips already in progress are never interrupted**; pre-expiry warnings (T-7/T-3/T-1/T-0).
- **Epic 6 — Driver Availability (DRV-034…039):** online/offline toggle (gated); foreground location streaming; background location (FGS on Android, iOS background modes); heartbeat (30s); service-area geofencing; battery/data optimisation.
- **Epic 7 — Marketplace Discovery (DRV-040…045):** realtime nearby request subscription via `marketplace:zone:<geohash6>` + 8 neighbours; request card rendering & sorting; per-request countdown; distance/ETA computation; multi-request handling; reconnect & backfill on resume.
- **Epic 8 — Bidding (DRV-046…051):** bid composer UI (3 variants — type/slider/chips, all already designed); `submit-bid` edge function; bid lifecycle realtime updates; cancel/withdraw; anti-spam limits; win/lose result handling.
- **Epic 9 — Active Trip Lifecycle (DRV-052…060):** trip state machine (`assigned → en_route → arrived → in_progress → completed | cancelled`); navigation handoff to Google/Apple Maps; live location publish (1 Hz broadcast + 5s batched persist); arrived check-in (geofence); start trip; complete trip + fare credit; driver-initiated cancellation with reasons; passenger-cancelled handling; post-trip rating.
- **Epic 10 — Realtime Comms (DRV-061…063):** in-app chat scoped to active trip; masked voice call (Africa's Talking / Twilio); quick-reply templates.
- **Epic 11 — Earnings & Wallet (DRV-064…068):** trip earnings ledger; wallet balance; payout request via Paystack transfers (min ₦5k, max daily ₦500k); payout history; daily/weekly summary.
- **Epic 12 — Pricing Strategy Tools (DRV-069…071):** default base fare + per-km; peak-hour profiles; trip preferences (long/short/airport).
- **Epic 13 — Driver Analytics (DRV-072…075):** earnings chart; acceptance/cancellation metrics; insights/coach tips (rule-based v1, ML later); demand heatmap (H3).
- **Epic 14 — Profile · Documents · Reviews (DRV-076…079).**
- **Epic 15 — Safety & Trust (DRV-080…083):** SOS button + escalation; trusted contacts; trip sharing link; incident report.
- **Epic 16 — Support (DRV-084…086).**
- **Epic 17 — Notifications (DRV-087…088).**
- **Epic 18 — Settings & Account (DRV-089…090):** theme/language; NDPR-compliant delete account.
- **Epic 19 — Edge States & Failure Recovery (DRV-091…095):** offline-first mutation queue UI; reconnection orchestration; subscription-expired lock screen; network-poor mode; no-requests empty state.
- **Epic 20 — Security & Compliance (DRV-096…098):** RLS audit; PII encryption at rest; audit logs.
- **Epic 21 — QA & Launch (DRV-099…101):** test strategy (widget/integration/RLS/load); closed beta program (TestFlight + Play Internal); launch checklist.

**Suggested timeline:** ~10–12 weeks for a 4-engineer team (2 mobile, 1.5 backend, 0.5 DevOps), with PLAT-001…007 + DRV-001…009 in week 1, auth+KYC weeks 2–3, vehicle+subscription weeks 3–4, the marketplace heart (presence + discovery + bidding) weeks 4–6, active trip weeks 6–7, comms+earnings+pricing strategy week 7, analytics+profile+settings weeks 8–9, resilience+security weeks 9, QA+launch week 10.

**Where the differentiator earns its keep:** the four tickets that make Drivio "drivers as micro-entrepreneurs" rather than another Uber clone are **DRV-027** (free-trial logic that lets new drivers prove the platform), **DRV-032** (subscription gate without commission), **DRV-046** (the bid composer as the hero), and **DRV-040** (open marketplace fanout). Engineering effort should disproportionately weight quality and polish on those four.

### 4.7 What was produced — `driver_context.md`

Saved to `/Users/ebube.okocha/StudioProjects/drivio_driver/driver_context.md`. 18 sections answering *why* every load-bearing decision in `driver.md` is the way it is.

1. **Product philosophy & differentiation** — driver-as-micro-entrepreneur; subscription as the only revenue lever; why Nigeria first.
2. **The marketplace mechanic** — auction lifecycle diagram; why open competitive (not sealed-bid); why 60s window; why one bid per driver per request; why no counter-offer; race conditions and the serializable `accept-bid` transaction; channel topology (geohash6 broadcast vs postgres-changes for personal channels).
3. **Subscription system** — trial/active/expired states; why 90 days; server-side gate (not client); why Paystack subscriptions vs DIY billing.
4. **Architecture overview** — system diagram (Flutter ↔ Supabase ↔ Termii/Paystack/Dojah/FCM/Sentry/PostHog/Logflare); why Supabase; why Flutter; trade-offs explicit.
5. **Realtime architecture** — three channel families (postgres-changes / broadcast / presence) and when to use each; why postgres-changes for trips but broadcast for marketplace; why insert presence rows but broadcast trip locations; reconnection and state reconciliation; what the realtime layer must NOT do.
6. **Geo-location strategy** — `geography(Point,4326)` everywhere; geohash6 vs H3 for different jobs; driver location update cadence (5s/1s/0.5s by state); why the driver client doesn't write directly to `driver_presence`.
7. **Database design principles** — money in `bigint` minor units; time as `timestamptz`; FKs not optional; enums vs lookup tables; soft vs hard delete; partitioning timeseries; materialised views.
8. **Flutter architecture** — honour what already exists (no `freezed`, no `auto_route`); Riverpod; controller-per-feature model; repositories vs services vs controllers vocabulary; mutation queue; theme tokens.
9. **Offline-first strategy** — what offline-first means (and doesn't); explicit non-features; connectivity awareness.
10. **Failure recovery patterns** — five things that can go wrong mid-trip; three things that can go wrong with bidding; three things that can go wrong with subscription.
11. **Event-driven patterns** — append-only event tables; inside-the-DB events as default; idempotency as contract.
12. **Security** — layers (network/auth/authorisation/input/audit/PII); service-role key hygiene; biggest threats; NDPR compliance.
13. **Performance** — targets table (cold start, marketplace event latency, bid round-trip, trip location latency, edge function p95, RLS query p95, battery drain); mobile-specific tactics; database tactics.
14. **Observability** — what we measure; what we alert on; the 2 AM principle.
15. **Trade-offs explicitly considered** — table of every major decision, the alternative, why we chose this, and the cost.
16. **Future-proofing** — things deliberately not over-engineered; things pre-engineered as cheap insurance; things to revisit in 6 months.
17. **Open questions and risks** — 5 product questions to escalate; technical risk register with severity; 3 product assumptions that, if wrong, force a marketplace rethink.
18. **Reading order for a new engineer.**

### 4.8 Two open items Claude flagged at the end of the delivery

- **₦100,000 per-trip price cap** — engineering safety rail, not a product feature; needs product confirmation on whether the cap exists at all and at what value.
- **Trial-once-per-driver-forever rule (DRV-027)** — a driver who churns and returns 18 months later does not get a second trial; defensible but worth confirming.

---

## 5. Phase 4 — This document

### 5.1 User prompt (verbatim)

> "write the context of this conversation both the prompt and everything be detailed, write the file in the drivio_driver and call it coworkcontext"

### 5.2 What Claude is doing

Producing this file at `/Users/ebube.okocha/StudioProjects/drivio_driver/coworkcontext.md` to capture the entire session: discovery, design-prompt review, the engineering brief, the four clarifying questions and their answers, and full descriptions of the two deliverables produced.

---

## 6. Workspace state at end of session

Files now present in `/Users/ebube.okocha/StudioProjects/drivio_driver/` directly relevant to this session:

| File | Purpose |
|---|---|
| `knowledge.md` | Pre-existing — what the Flutter app already is. |
| `MIGRATION.md` | Pre-existing — original coding rules referenced by `knowledge.md`. |
| `driver.md` | **New, this session** — engineering ticket roadmap (PLAT-001…014 + DRV-001…101). |
| `driver_context.md` | **New, this session** — architectural/product reasoning, 18 sections. |
| `coworkcontext.md` | **This file** — conversation record. |

The Flutter source tree under `lib/modules/...` is unchanged by this session (no code edits were made; only documentation was authored).

---

## 7. Decisions captured for future sessions

Future Cowork or engineering sessions opening this project should treat the following as the durable record of decisions made during this session. They are repeated here so they are findable in one place.

### 7.1 Product decisions

1. **Marketplace mechanic:** open competitive auction. Drivers each submit one bid per request; passenger sees all bids and picks one; 60s default request expiry; no counter-offer in v1.
2. **Subscription:** flat monthly via Paystack. Hard block immediately at expiry. Active trips already in progress when expiry hits run to completion — never interrupted.
3. **New-driver free trial:** 90 days, auto-created on KYC approval, one-time-per-driver-forever, never re-grantable except by admin override (out of scope for v1 self-serve).
4. **Region:** Nigeria-first (Lagos for v1). NGN. +234 phone. BVN/NIN KYC. FRSC + LASRRA documents. Paystack + Flutterwave payments. Termii + Sendchamp SMS.
5. **No commission.** "You keep" equals input price. The platform's revenue is the subscription only.
6. **Pricing must feel central.** The bid composer's hero number is keyboard-editable; the suggested price is a soft hint, never a ceiling.

### 7.2 Architecture decisions

1. **Backend:** Supabase (Postgres + Auth + Storage + Realtime + Edge Functions in Deno). Project exists but empty; greenfield schema designed in PLAT-002.
2. **Realtime:**
   - **postgres-changes** for personal channels (own bids, own trips, own subscription, own messages on active trip).
   - **broadcast** for marketplace fanout (`marketplace:zone:<geohash6>` + 8 neighbours) and live driver location during trip (`trip:<id>:driver_location` at 1 Hz).
   - **presence** for ops dashboards.
3. **Geo:** `geography(Point, 4326)` everywhere; geohash6 for marketplace cells; H3 for demand heatmap. Driver client NEVER writes directly to `driver_presence`; goes through `update-presence` edge function for anti-spoof and rate limiting.
4. **Trip locations:** broadcast at 1 Hz, batch-persist at 5s into a monthly-partitioned `trip_locations` table; 90 days online retention, archive to S3 cold.
5. **Money:** `bigint` minor units (kobo for NGN). Never `numeric`, never `float`.
6. **Time:** `timestamptz` everywhere.
7. **Idempotency:** every edge function accepts `Idempotency-Key`; mobile mutation queue (DRV-003) generates and persists keys across cold starts.
8. **RLS:** enabled on every table; driver-app row scope is `auth.uid() = driver_id`; admin override via JWT `role` claim.
9. **Service-role key:** only inside edge function runtime; never on a developer machine in plaintext; never in git or CI logs.

### 7.3 Existing-codebase rules to honour

(From `knowledge.md`, reaffirmed for any future implementation.)

1. Always `ConsumerWidget` / `ConsumerStatefulWidget`. Never plain `StatelessWidget`/`StatefulWidget`.
2. Always route via `AppNavigation.push/replace/...` with an `AppRoutes.xxx` constant.
3. Always read colours via `context.bg`, `context.text`, `context.accent`, etc. Never raw `AppColors.*Dark/Light`.
4. Manual `copyWith` — no `freezed`.
5. String route constants — no `auto_route`.
6. Single quotes, trailing commas, `dart format .` clean.
7. File/folder `snake_case`; classes `PascalCase`; pages end in `Page`; controllers in `Controller`; states in `State`; providers in `Provider`.
8. New shared widget? Add to `commons/all.dart` barrel. New module? Same `features/<feature>/presentation/{logic,ui}/` skeleton.
9. **Do not recreate** the deleted `status_bar.dart` and `home_indicator.dart` widgets; no fake iOS chrome.
10. **"You keep" equals input price.** Never re-add a fee multiplier in `RideRequestState.netToYou`.
11. **Hero price is keyboard-editable** in the type variant of the bid composer.
12. **OTP cells use an invisible TextField overlay**, not per-cell focus nodes.

### 7.4 Open product questions to escalate

(Captured in §17.1 of `driver_context.md`; reproduced here for findability.)

1. Per-trip price ceiling — is the engineering safety rail of ₦100,000 acceptable, or do we want truly unbounded?
2. Cancellation penalties — what triggers auto-suspension (e.g. 30% cancel rate)?
3. Surge transparency to passengers — do we surface "today's average for this route"?
4. Dispute SOP for incomplete location trails (gaps > 5 min).
5. Trial reset on suspension-then-readmission — confirm "no second trial ever".

### 7.5 Technical risks tracked

(From §17.2 of `driver_context.md`.)

| Risk | Severity | Mitigation |
|---|---|---|
| Supabase Realtime can't sustain 1k concurrent drivers per zone | High | Load test before launch; shard further if needed |
| Paystack webhook outage | Medium | Polling fallback; ops dashboard for manual reconciliation |
| iOS background suspension stops driver location during trips | High | FGS / Live Activity / significant-location-change combo |
| BVN provider downtime | Medium | Manual review fallback for KYC |
| Driver client modding to bypass gates | Medium | All gates server-side |
| Concurrent bid acceptance race | Low | Serializable transaction in `accept-bid` |
| WAL bloat from `replica identity full` on hot tables | Low | Monitor; switch to default replica identity if it dominates |
| Realtime channel sprawl as features grow | Medium | The `realtime/CHANNELS.md` registry is the discipline |

### 7.6 Things deliberately not built in v1

- Multi-tenant / white-label.
- Multi-currency.
- Fleet accounts (individual drivers only; FK-friendly to add later).
- Driver tiers (gold/platinum/etc.).
- Counter-offer / price negotiation (single round of bids).
- Localisation (inline strings).
- Self-serve account recovery (manual via support in v1).
- Embedded turn-by-turn navigation (hand off to Google/Apple Maps).
- Native ML for insights (rule-based v1).

---

## 8. Tools and skills used in this session

- `Glob`, `Grep`, `Read` for the discovery phase reading `knowledge.md`.
- `mcp__workspace__bash` to confirm file presence (workspace mounts initially didn't surface `knowledge.md` to glob).
- `ToolSearch` to load deferred tool schemas: `mcp__workspace__bash`, `AskUserQuestion`, `TaskCreate`, `TaskUpdate`.
- `AskUserQuestion` to elicit the four clarifying decisions before authoring the documents.
- `TaskCreate` / `TaskUpdate` to track the two-document delivery as in-progress / completed.
- `Write` to author `driver.md`, `driver_context.md`, and (this turn) `coworkcontext.md`.

No code was edited. No git operations were performed. No Supabase project was created or modified. The Supabase MCP tools surfaced in the most recent `<system-reminder>` were not used in this session and remain available for any follow-up that wants to begin executing the roadmap.

---

## 9. Suggested next steps

Roughly in execution order, if the user wants to start building:

1. **Decide the open product questions** in §7.4 above — particularly the per-trip price cap and the trial-reset-on-readmission rule.
2. **Stand up PLAT-001** — Supabase migration workflow against the existing empty project. The Supabase MCP tools (`apply_migration`, `execute_sql`, `list_tables`, `deploy_edge_function`, etc.) make this directly executable from a future Cowork session.
3. **Apply PLAT-002 schema v1** — author and apply the core schema migration, then run `supabase gen types dart` and commit generated types under `lib/modules/commons/types/`.
4. **Add `supabase_flutter` to `pubspec.yaml`** and execute DRV-001 (client bootstrap). This is the smallest possible Flutter change that unblocks every subsequent ticket.
5. **Seed `subscription_plans`** with a stage `drivio_pro_monthly` plan so DRV-026 / DRV-027 / DRV-028 can be wired end-to-end.
6. **Build the marketplace spine first** (DRV-034 → DRV-040 → DRV-046 → DRV-052) since the three differentiator tickets (027, 032, 040, 046) all depend on it. Polish auth/KYC after.
7. **Run a closed beta with 25 Lagos drivers** per DRV-100 before any public launch.

---

## 10. How to use this file

This document is the canonical conversation record. Read it whenever:

- A new engineer joins and needs to understand how the roadmap was built.
- A decision in `driver.md` looks wrong and someone needs to know what was considered.
- A future Cowork session opens cold and needs to pick up where this one left off — the user prompts and clarifying answers are preserved verbatim.

If a decision in this file conflicts with a later decision in `driver.md` or `driver_context.md`, the later document wins; this is a snapshot of the session in which those documents were written.
