# Drivio Driver — System & Product Context

> **Purpose:** Explain *why* the driver app, backend, and realtime systems are designed the way they are in `driver.md`. A senior engineer joining in month 9 should be able to read this and understand every load-bearing decision without asking. Where there is a credible alternative, the trade-off is explicitly stated.
>
> **Audience:** Engineers, product owners, future hires, security reviewers, investors doing technical diligence.
>
> **Companion to:** `driver.md` (the implementation tickets), `knowledge.md` (the existing Flutter app's state-of-the-tree).

---

## 1. Product philosophy & differentiation

### 1.1 The driver as a micro-entrepreneur

Uber, Bolt, and inDrive all set or constrain the price. Drivio inverts that: **the platform never sets a fare**. A passenger requests a ride; nearby drivers each propose their own price; the passenger picks. The platform's revenue is a flat monthly subscription, not a per-trip rake.

This is not just a UX choice — it is a control-and-incentives choice with three downstream effects that shape the system:

1. **Pricing is unbounded by us.** That means the bid composer must feel like an empowering tool, not a fenced-in form. The hero number on `RideRequestPage` is therefore keyboard-editable (per the existing user-feedback rule in `knowledge.md` #3) and the suggested price is a soft hint, never a hard ceiling.

2. **"You keep" equals the input price.** No commission, no platform fee subtracted from the bid. The previous `* 0.96` multiplier was removed for exactly this reason. Drivers see the literal naira amount they will receive.

3. **Drivers must be able to compete.** That means the marketplace screen must surface every relevant request within ~500 ms of creation, and every driver in range must see it. A delayed feed kills the marketplace; a feed that misses requests kills trust.

### 1.2 Subscription as the only revenue lever

Because we don't take a per-trip cut, the subscription is the entire business. Three corollaries:

- **The trial must convert.** New drivers get 90 days free (DRV-027). 90 days is long enough that even infrequent drivers complete enough trips to feel the platform's value, but short enough that we don't drown in unmonetised inventory.

- **Expiry must bite.** A driver whose subscription lapses cannot receive new requests (DRV-032). Soft warnings only would not produce a viable business; we'd be giving away the marketplace for free. The hard block is enforced server-side at every gate (toggle online, marketplace channel auth, bid submission), not just at the UI.

- **Trips in progress are sacred.** Even if the subscription expires mid-trip (e.g., a renewal failure webhook lands), the active trip completes. Stranding a passenger to enforce billing would destroy the trust that the marketplace runs on. This is encoded in `submit-bid`'s gate and in the home controller's auto-flip-offline logic.

### 1.3 Why Nigeria first

Three reasons:

1. **Distribution.** The team has the network and ground knowledge for Lagos. Cold-starting a marketplace is fundamentally a city problem, not a country problem; one city solved well beats six cities done halfway.
2. **Payments fit.** Paystack and Flutterwave handle subscriptions, transfers, and account verification in NGN cleanly. Card decline rates are well-understood. Bank account resolution against a name (a feature you need for payouts) is a built-in.
3. **Regulatory clarity.** FRSC, NIN/BVN, and LASRRA give you crisp KYC primitives. You don't need a generic ID provider's coverage matrix; you go straight to Dojah/Smile-ID/NIBSS.

Trade-off accepted: the schema and feature set have **Nigeria-shaped** decisions (E.164 with hardcoded +234, `kobo` minor units assumed, plate regex). When pan-African expansion comes, these calcify into a `service_area` table with country-aware modules. v1 keeps it simple.

---

## 2. The marketplace mechanic

### 2.1 The auction model in detail

The mechanic chosen by the user (and lined up against UI affordances already in the prototype):

> A passenger creates a ride request. Every nearby driver sees it, types in the price they want, and submits. The passenger sees all pending bids and picks one. The platform never sets a price.

**Lifecycle (per ride request):**

```
passenger app                   server                              driver app(s)
─────────────                   ──────                              ──────────────
  POST request   ──────────►  insert ride_requests   ───────────►  marketplace channel
                                  (open, expires_at +60s)          (realtime broadcast)
                                          │
                                          │                           bid composer opens
                                          │                           submit-bid POST
                                          │                                │
                                          ▼                                ▼
                                  insert ride_bids ◄────────── realtime fanout to passenger
                                  (one row per driver)
                                          │
                                          │                           (driver waits)
  pick a bid    ──────────► accept-bid (txn):
                              - lock ride_requests row
                              - mark this bid 'accepted'
                              - mark all other bids 'rejected'
                              - mark request 'matched'
                              - insert trips row
                              - emit events on:
                                · ride_bids realtime
                                · trips realtime
                                · trip_events
                                          │
                                          ▼
                              winning driver:                    losing drivers:
                                advance to active trip            remove request from feed,
                                                                  optional toast "another
                                                                  driver was chosen"
```

### 2.2 Why this shape

**Why open competitive (not sealed-bid)?** Sealed-bid auctions reduce passenger anxiety (no "wait, did I just pay 30% over the median?") but they also conceal the marketplace from passengers, removing the "you decide" signal that's core to the product story. The passenger should *see* the variance — that's the differentiation.

**Why time-limited (60s default)?** Auction theory says the optimum window is the smallest one that still gathers enough bids to be informative. In Lagos with reasonable density (5+ drivers per geohash6 cell during day), 60s gives enough drivers a chance to bid without making the passenger wait. If density is too low, surface "fewer than expected — keep waiting?" to the passenger.

**Why one bid per driver per request?** A driver re-bidding mid-window would create a noisy passenger UX and would arms-race down to whoever bids last. The UNIQUE constraint on `(ride_request_id, driver_id)` enforces this. A driver who wants to change their mind must `withdraw-bid` and submit a new one; this is intentional friction.

**Why not a counter-offer / negotiation cycle?** The original brief flagged this as optional; we've explicitly chosen NOT to build it for v1 because (a) it exponentially increases realtime channel pressure, (b) it changes the passenger UX from "pick a price" to "haggle", which is a different product, and (c) Lagos taxi culture (like most ride-hailing markets) tolerates "this price or no" but resists drawn-out negotiation in-app. v2 can revisit.

### 2.3 Race conditions and how they are resolved

Three race classes exist:

1. **Two passengers requesting near each other simultaneously.** No conflict — each request has its own ID and channel events. Drivers see both and pick which to bid on (or bid on both).

2. **Multiple drivers bidding on the same request at the same instant.** Each `submit-bid` is its own atomic insert; UNIQUE constraint guarantees one bid per (request, driver). All bids reach the passenger.

3. **Passenger accepts bid X at the moment driver Y submits a new bid (or driver X tries to withdraw).** Resolved by a serializable-isolation transaction in `accept-bid`:
   ```sql
   BEGIN;
   SELECT * FROM ride_requests WHERE id = $1 FOR UPDATE;  -- locks
   IF status != 'open' THEN ROLLBACK + 409 'already_matched';
   UPDATE ride_requests SET status = 'matched', matched_bid_id = $bid;
   UPDATE ride_bids SET status = 'accepted' WHERE id = $bid;
   UPDATE ride_bids SET status = 'rejected' WHERE ride_request_id = $1 AND id != $bid;
   INSERT INTO trips (...);
   COMMIT;
   ```
   Concurrent `withdraw-bid` calls on a bid that the passenger just accepted return 409 `bid_already_accepted`; the driver's UI catches up via the realtime trip event.

4. **Driver bid expiry vs. passenger acceptance.** `pg_cron` flips bids past `expires_at` to `expired` every 5s; if a passenger acceptance sneaks in within that window, the FOR UPDATE lock means whoever holds the row first wins, deterministically.

### 2.4 Marketplace channel topology

The single most expensive realtime decision is *how* to fan out a new request to drivers.

**Naïve approach:** broadcast to "all drivers", let clients filter. This melts at scale: every driver gets every request payload nationwide.

**Sharded approach:** broadcast to a geohash6 cell (~1.2 km × 0.6 km). Drivers subscribe to their current cell + the 8 neighbours (so the radius is roughly 1.8 km × 1.2 km, plenty for Lagos). When the driver moves > 50% of cell width, re-subscribe.

This was chosen for three reasons:

- **It scales horizontally.** Each cell is its own broadcast topic; load is distributed naturally across the city. A surge in Victoria Island doesn't impact Yaba.
- **It's cheap.** A driver maintains 9 subscriptions (each ~free in Supabase Realtime); a passenger pushes one event per request.
- **It composes with PostGIS.** The cell ID is a generated column on `ride_requests`; we don't need a separate index of "which channels does this request go to".

The trade-off is a small extra logic burden in the driver-app `MarketplaceController` to manage cell crossings. Acceptable.

**Why not Postgres-changes for the marketplace feed?** Two reasons. First, RLS evaluation on every WAL change for every connected driver is expensive at scale. Second, the broadcast channel can be authorised once at subscribe time (zone membership) rather than per-row. The cost is that we don't get free RLS — but RLS doesn't actually help here, since "you can see this request" is a geographic predicate, not a row-owner predicate.

We DO use Postgres-changes for **personal** channels (a driver's own bids, trips, subscription status) where RLS is the right tool.

---

## 3. Subscription system

### 3.1 Trial, paid, expired — the only three states drivers care about

Internally, `subscriptions.status` has more values (`trialing | active | past_due | cancelled | expired`) but the driver experience is collapsed:

- **Active** = trialing OR active. UI says "Trial — 56 days left" or "Active — renews 12 May". Marketplace works.
- **Grace** = past_due (Paystack retrying after a failed charge). Marketplace works for ≤ 3 days; banner urges payment update.
- **Blocked** = expired OR cancelled. Marketplace gate is hard.

The user's chosen policy is **hard block immediately at expiry**, with the **trial only for new drivers, never re-grantable**. A 3-day grace during `past_due` is a Paystack-native mechanism (their dunning); we surface it but don't extend it ourselves.

### 3.2 Why 90 days for the trial?

Three constraints:

- **Long enough to ride out KYC delay.** Some drivers take a week or more to get all docs approved. A 30-day trial with 7 days lost to onboarding is a 23-day usable trial — too short.
- **Long enough to feel the platform.** Most Lagos drivers don't drive 7 days a week. 90 days = ~12 weekends + ~60 weekday opportunities. They feel the marketplace velocity, the earnings pattern, the demand zones.
- **Short enough to not give away the business.** 6 months would create a population of long-tail freeloaders.

Trade-off: drivers who only drive part-time may not hit a strong enough activation curve in 90 days and churn. We mitigate via DRV-074 (insights / coach tips) that surface the cost of going inactive ("you missed ₦18,000 in potential earnings last week").

### 3.3 Server-side gate, not client-side

Every trust boundary that the subscription enforces is **server-side**. A modified client cannot:

- Toggle online (server validates `is_driver_active(user_id)` in `go-online`).
- Subscribe to a marketplace zone (Realtime auth hook checks role + active status).
- Submit a bid (`submit-bid` validates).

Client-side disable is purely UX (avoid the user tapping an action that will reject them). Never the source of truth.

### 3.4 Why Paystack subscriptions, not our own billing engine

We could implement charging with Paystack one-shot transactions and our own scheduler. Why not?

- **Dunning is a swamp.** Soft declines, retries, currency rules, partial failures, refunds — Paystack's subscription product handles this and it took them years.
- **Compliance follows.** Their PCI scope shields us; we never touch card data.
- **Webhooks are the contract.** Our system reacts to Paystack events; we don't have to be the source of truth on "is this card valid right now?".

The trade-off is a hard dependency on Paystack API availability. We mitigate with a fallback Flutterwave path for new activations only (renewals still flow through Paystack).

---

## 4. Architecture overview

### 4.1 Big picture

```
                         Drivio (Driver App)
                         ─────────────────
  Flutter app  ◄── Realtime ──┐
  (iOS, Android)              │
       │                      │
       │  REST                │
       ▼                      ▼
                ┌─────────────────────────────┐
                │  Supabase                   │
                │  ┌────────────────────────┐ │
                │  │ Postgres + PostGIS     │ │
                │  │ - core schema (PLAT-002)│ │
                │  │ - RLS (PLAT-003)        │ │
                │  │ - partitioned timeseries│ │
                │  └────────────────────────┘ │
                │  ┌────────────────────────┐ │
                │  │ Realtime               │ │
                │  │ - postgres-changes     │ │
                │  │ - broadcast (zones)    │ │
                │  │ - presence             │ │
                │  └────────────────────────┘ │
                │  ┌────────────────────────┐ │
                │  │ Edge Functions (Deno)  │ │
                │  │ - submit-bid, accept-bid│ │
                │  │ - go-online, update-presence│
                │  │ - kyc-submit-step       │ │
                │  │ - paystack webhooks     │ │
                │  └────────────────────────┘ │
                │  ┌────────────────────────┐ │
                │  │ Storage (private buckets)│
                │  └────────────────────────┘ │
                │  ┌────────────────────────┐ │
                │  │ Auth (phone OTP)       │ │
                │  └────────────────────────┘ │
                └─────────────────────────────┘
                          │
                          ▼
        ┌────────────────┬────────────┬───────────────┐
        │   Termii (SMS) │  Paystack  │  Dojah/Smile  │
        │                │  (subs +   │  (BVN/NIN +   │
        │                │  transfers)│  liveness)    │
        └────────────────┴────────────┴───────────────┘
                          │
                          ▼
                   ┌─────────────┐
                   │ FCM (push)  │
                   │ Sentry      │
                   │ PostHog     │
                   │ Logflare    │
                   └─────────────┘
```

### 4.2 Why Supabase

Three things matter for this product, and Supabase is the only off-the-shelf bundle that gives all three with low integration friction:

1. **A first-class realtime layer that respects RLS.** We need driver-specific channels and zone broadcasts; Supabase Realtime gives both with auth hooks. Building this on top of Postgres LISTEN/NOTIFY directly would consume two engineer-months for behaviour Supabase ships out of the box.

2. **Auth + RLS + Postgres in one.** Auth claims feed straight into RLS predicates (`auth.uid()`), so the security model collapses to "write the right policies once". Compare to running our own auth service against a separate DB: every query needs to pass user identity manually, and every dev forgets occasionally.

3. **Deno edge functions colocated with the DB.** Bid validation has a sub-200 ms budget; functions running in the same region as the DB hit this consistently. A separate Lambda + RDS would cross a network boundary and add 30–80 ms.

The trade-offs:

- **Supabase is a managed service.** We do not control the Realtime server's scaling. We mitigate by sharding via geohash and not over-broadcasting.
- **Edge functions are Deno.** Our backend folks may default to Node.js. The shared `_shared/` toolkit (PLAT-005) keeps the edges thin so the lift is small.
- **We're betting on a venture-funded vendor.** If Supabase changes pricing or product direction sharply, we have a Postgres + Auth + Storage substrate that is largely portable; the Realtime layer is the lock-in. Acceptable for v1.

### 4.3 Why Flutter

The repo already exists in Flutter, but the deeper reasons:

- **One team, two platforms.** Lagos drivers are heavily Android (low-end at that), but iOS coverage matters for fleet owners and ops. Two native teams is a luxury we'd rather convert to one mobile + more backend.
- **Realtime SDKs.** `supabase_flutter` is mature; the FCM and location packages are well-supported.
- **Performance is good enough.** A driver app's hot path is "render a map + a card + advance state". Flutter's render path handles this without breaking sweat at 60 fps even on 2 GB Android phones.

The corollary: where native is required (background location FGS, ProGuard tuning, iOS background modes), we accept the platform-channel cost. DRV-036 is the biggest one.

---

## 5. Realtime architecture

### 5.1 Three channel families

(Discussed in PLAT-004; the "why" follows.)

| Family | Used for | Why this family |
|---|---|---|
| `postgres-changes` (filtered) | Personal subscriptions: own bids, own trips, own subscription status, own messages on active trip | RLS is the right tool here; the data model already enforces ownership; payload reflects the canonical row |
| `broadcast` (custom topic) | Marketplace fanout (`marketplace:zone:<gh>`), live driver location during trip (`trip:<id>:driver_location`) | Authorisation is geographic or trip-membership based — easier to express as a single subscribe-time check than per-row RLS; also keeps WAL out of the hot path |
| `presence` | Ops dashboards, "who's online in city X" | Built-in semantics for membership; no DB writes for joining |

### 5.2 Why postgres-changes for trip events but not for marketplace fanout

Both are valid candidates but the calculus differs:

- **Trip events** are low-rate (~10 events per trip), per-trip-scoped (typically 2 subscribers: one driver, one passenger), and benefit from being canonical in the DB. RLS for free.
- **Marketplace requests** are higher-rate during peak (a request every few seconds in dense Lagos zones), have potentially hundreds of subscribers per zone, and benefit from broadcast (no WAL delivery; payload is exactly what we choose, not the full row). Authorisation is a one-time geographic check; wasting RLS evaluation per WAL change for every driver in the zone would be wasteful.

### 5.3 Why we *insert* presence rows but *broadcast* trip locations

`driver_presence` is a single row per driver, last-write-wins. We update that row at low frequency (every 5–30s typically) because the on-line/off-line decision needs to be persisted (cron sweepers read it; admin dashboards query it).

Trip locations stream at 1 Hz during a trip. Persisting every tick is overkill (10–20× more writes than we need). So we:

- **Broadcast** at 1 Hz for the passenger's live map.
- **Batch persist** at 5s intervals (server worker) into `trip_locations` (partitioned monthly) for replay, receipts, and disputes.

The 5s sample density gives us ~720 points for a 1-hour trip, which is plenty for fare reconstruction or geofence audit, while keeping WAL and disk use sane.

### 5.4 Reconnection and state reconciliation

Realtime is a best-effort channel; during a tunnel, an iOS background suspension, or a server hiccup, events get dropped. Every controller that consumes Realtime must reconcile on resume:

```
on resume:
  1. fetch the present state via REST (the truth)
  2. merge with any in-memory state (newest wins)
  3. resubscribe channels
  4. continue
```

For the marketplace, this means calling `list-open-requests-near` and merging. For trips, re-querying `trips` and `trip_events`. For subscriptions, re-querying `subscriptions`.

This pattern is non-negotiable; it's the single most common bug source in realtime mobile apps.

### 5.5 What the realtime layer must NOT do

- It must not be the source of truth for anything financial. Bid acceptance, fare computation, and wallet credits all happen in Postgres transactions; Realtime carries notifications, not authoritative state.
- It must not deliver to unauthorised parties. The auth hook checks happen on every channel subscribe; this is the strongest line in the security model.
- It must not assume strict ordering. Postgres-changes events arrive monotonically per row, but cross-row ordering across channels is not guaranteed. Controllers must tolerate out-of-order delivery (use `updated_at`).

---

## 6. Geo-location strategy

### 6.1 Coordinate system: `geography(Point, 4326)` everywhere

Why not `geometry`? Distance in `geometry` is in degrees (useless), in `geography` it's in metres. PostGIS handles spheroidal distance internally; we never have to think about projections. Marginal index cost is worth it.

### 6.2 Geohash6 vs H3

We chose **geohash6** for the marketplace zoning because:

- **Standard library support in Dart and Postgres.** No native bindings, no geometry conversions.
- **Cells are roughly rectangular and align reasonably with city blocks.**
- **Simple neighbour computation** (string manipulation).

We use **H3 hex** for the demand heatmap (DRV-075) because:

- **Equal-area cells** make the heatmap visually correct (squares distort).
- **Hierarchical resolution** is convenient for zoom levels.

Different tools for different jobs is fine; we're not standardising on one.

### 6.3 Driver location update cadence

Two competing demands: passenger UX wants frequent updates; battery + data want infrequent ones.

- **Off-trip, online:** 5s while stationary, 1s while moving. Updates only `driver_presence`. No realtime broadcast.
- **On-trip:** 1s, broadcast on `trip:<id>:driver_location`. Server batches 5s persistence to `trip_locations`.
- **Background, on-trip:** depends on OS power state; 1s when active, 5s when OS throttles us. iOS will suspend us if we don't have a Live Activity or significant-location-change configured.

### 6.4 Why the driver client doesn't write directly to `driver_presence`

PLAT-003's RLS denies direct UPDATE on `driver_presence`. Instead, `update-presence` edge function is the gate. Why?

- **Anti-spoof.** A modded client could spoof `driver_presence.last_geo` to claim a Yaba location while in Lekki, and claim every Yaba request. The edge function validates the location is plausible (Δ from previous fix is consistent with `speed_kph`), validates against the current cell (no teleporting), and rate-limits.
- **Rate limiting.** A flapping client could write 100 ticks/s; edge function caps at 4 Hz.
- **Side effects.** The function emits analytics, updates derived state (current_geohash6), and triggers cell re-subscription server-side.

Trade-off: marginal extra latency (10–30ms) per tick. Acceptable.

---

## 7. Database design principles

### 7.1 Money is `bigint` minor units

Never `numeric`, never `float`. ₦10,000 = `10_000_00` kobo (we store kobo as the minor unit; documented in `currency='NGN'`). Computation is integer; rounding errors are impossible.

### 7.2 Time is `timestamptz`

Never `timestamp without time zone`. The driver may be in Lagos, the server in Frankfurt, the passenger displaying in WAT — `timestamptz` settles every conversion automatically.

### 7.3 Foreign keys are not optional

Every relation is FK-enforced; orphan rows are a bug, not a tolerable mess. The one exception is `auth.users` deletion: PLAT-002 chose `ON DELETE SET NULL` (or kept rows for accounting) because hard deletion would lose trip history that matters for compliance.

### 7.4 Enums vs lookup tables

Enums for short, code-like sets (`status`, `kind`). Lookup tables for sets with metadata (e.g., `subscription_plans`). Adding a new enum value requires a migration; this is intentional friction that prevents typo-driven new states.

### 7.5 Soft delete vs hard delete

Soft delete (`deleted_at`) for drivers, vehicles, profiles — anything that has financial or audit history. Hard delete only for ephemeral noise (e.g., expired bids that no one references after 90 days).

Account deletion (DRV-090) flips `deleted_at` immediately and schedules a 30-day PII purge job (replace name/phone with hashes, drop documents).

### 7.6 Partitioning timeseries

`trip_locations` and `trip_events` will dominate the DB at scale (a single trip generates 720 location rows + 10 event rows; at 10k trips/day = 7.3M rows/day). Monthly partitioning + 90-day online retention keeps the working set bounded; cold partitions go to S3.

### 7.7 Materialised views for analytics

Driver dashboard queries (DRV-072) over months of data would scan millions of rows otherwise. A materialised view refreshed every 15 min keeps the dashboard at <50ms p95 with no harmful staleness.

---

## 8. Flutter architecture

### 8.1 Honour what already exists

`knowledge.md` documents pragmatic deviations from `MIGRATION.md`:

- No `freezed` — manual `copyWith`.
- No `auto_route` — string constants + static `AppNavigation`.
- No `*_service.dart` layer (yet) — controllers expose seeded data.

These tickets re-introduce the data layer as services backed by Supabase, but the deviations stand: keep `copyWith` manual; keep navigation through `AppNavigation`. The principle is "don't ship a new convention without a reason"; the existing conventions are fine.

### 8.2 Riverpod, not Provider

State is `StateNotifier` per controller; subscriptions to Realtime use `StreamProvider` or `StateNotifierProvider`. This is consistent with the existing project. Riverpod's compile-safe DI removes a class of bugs that plague mobile apps that grow past 50k LoC.

### 8.3 The "controller per feature" model

Each feature directory has one controller. The controller is the only thing that mutates state. Pages and widgets are read-only consumers via `ref.watch`. This rule is rigid for a reason: it makes side effects locatable. When a junior engineer sees a state mutation in a widget, they know it's wrong without thinking.

### 8.4 Repositories vs services vs controllers

The vocabulary in the existing codebase:

- **Repository** = the abstraction over a data source. `BidsRepository` exposes `submitBid(Bid)`, `streamMyBids(driverId)`. Implementation in `bids_repository_impl.dart` calls Supabase.
- **Service** = a domain operation that crosses repositories. Rare; most things are repository-direct.
- **Controller** = `StateNotifier` orchestrating repositories + state.

When in doubt, prefer repository methods over service methods.

### 8.5 The mutation queue

DRV-003's `MutationQueue` is the single most important resilience primitive. Every write that crosses a network boundary goes through it; every write generates an idempotency key on the device; every key is durable across cold starts. Without this, we'd have a leaky app on Lagos networks.

### 8.6 Theme tokens

Already done in `knowledge.md`. The rule "always read colours via `context.bg`, never `AppColors.bgDark`" stands. New widgets MUST follow it.

---

## 9. Offline-first strategy

### 9.1 What "offline-first" means here

We are not building Notion. The driver app is **online-required for revenue** — you can't bid without realtime. Offline-first means three things specifically:

1. **No data is lost on momentary disconnect.** Mutations queue (DRV-003), retry, succeed.
2. **The UI degrades gracefully.** Banners say "reconnecting"; buttons that would fail are disabled.
3. **Critical local state survives kill+relaunch.** Active trip ID, active bid IDs, queued mutations.

### 9.2 What we do NOT support offline

- **Browsing the marketplace.** Realtime is required.
- **Submitting a bid.** Server validates against an open request; this is online-only by definition.
- **Going online.** Toggling on requires a server gate check.

These are explicit non-features; the UI tells the user clearly.

### 9.3 Connectivity awareness

A central `ConnectivityController` (DRV-092) watches three signals:

- `connectivity_plus` for cellular/WiFi presence.
- A periodic `health` ping to the edge function (1 per 30s while foreground).
- Realtime channel state (CONNECTED / DISCONNECTED).

Any of the three flagging unhealthy → banner; all three healthy → no banner.

---

## 10. Failure recovery patterns

### 10.1 The "five things that can go wrong mid-trip" list

1. **Driver loses GPS.** Banner; if > 30s, auto-flip-offline (PLAT-011 cron mirrors). Active trip continues; ETA degrades; passenger app shows "driver lost GPS, last seen at...".
2. **Driver loses network.** Mutation queue holds outgoing events; on reconnect, drains. Trip state on the server doesn't change until "complete trip" lands; passenger sees stale ETA but the trip isn't lost.
3. **Driver app crashes.** Sentry captures; on relaunch, `BootstrapController` reads `trips.state` and resumes. The user re-enters the active trip page; no data loss.
4. **OS kills foreground service.** Heartbeat misses; PLAT-011 marks driver offline after 90s; passenger app shows "lost connection". Driver app on relaunch sees `trips.state = in_progress` and resumes.
5. **Driver power dies.** No graceful path; passenger app's safety flow kicks in (cancel + refund + report).

### 10.2 The "three things that can go wrong with bidding" list

1. **Bid lands after `expires_at`.** Server returns 409 `request_expired`; UI removes from feed.
2. **Bid lands after another bid is accepted.** Server returns 409 `request_no_longer_open`; UI removes from feed.
3. **Bid succeeds but the realtime ack is lost.** Mutation queue's idempotency key means the second retry returns the same bid. The `public:ride_bids:driver_id=eq.<self>` subscription updates UI on the *next* reconnect.

### 10.3 The "three things that can go wrong with subscription" list

1. **Webhook lands before client polling.** Realtime update beats poll; UI flips active. Poll exits.
2. **Webhook lands after polling timeout.** UI shows "we'll notify you when payment confirms"; FCM push lands later.
3. **Webhook never lands (Paystack outage).** PLAT-014 alerting catches webhook lag > 60s; ops manually reconciles.

---

## 11. Event-driven patterns

### 11.1 Append-only event tables

`trip_events`, `subscription_events`, `safety_events`, `audit_log`. These are insert-only; no updates, no deletes. Every meaningful state transition writes one. Three benefits:

- **Replay.** If we need to recompute analytics, we replay events.
- **Audit.** Disputes and ops investigations have a complete trail.
- **Decoupling.** Multiple consumers (analytics, push, ops dashboard) can react to the same event without coupling.

### 11.2 Inside-the-DB events are the default

We don't use a separate event bus (Kafka, NATS) for v1. Postgres + Realtime is enough. If volume forces us, we can swap in a message queue without changing the producer side (the DB is the producer).

### 11.3 Idempotency is the contract

Every edge function accepts an `Idempotency-Key` header. The server caches successful responses for 24h. Clients always pass a key for non-trivial writes. This is the single most important contract in the system after RLS.

---

## 12. Security

### 12.1 Layers

1. **Network:** HTTPS only; cert pinning for the Supabase domain (mobile; consider in v1.1 — costs velocity).
2. **Auth:** Phone OTP, secure token storage, biometric re-lock.
3. **Authorisation:** RLS on every table; SECURITY DEFINER functions explicitly enumerated.
4. **Input validation:** Edge function schemas; never trust client-shaped JSON.
5. **Audit:** Append-only `audit_log` for sensitive actions.
6. **PII:** BVN/NIN/bank stored as `bytea` encrypted via `pgcrypto`; never in logs; stripped from Sentry events.

### 12.2 Service-role key hygiene

Lives only in edge function runtime. Never on a developer machine in plaintext (1Password). Never in CI logs (masked).

### 12.3 The biggest threats

- **A modded driver client.** Mitigated by server-side gates everywhere; client is treated as adversarial.
- **Phone-number takeover.** Mitigated by BVN re-verification on phone change (DRV-015 v1 manual; v1.1 self-serve).
- **Marketplace data leakage.** Mitigated by zone authorisation hook + RLS on personal channels.
- **Webhook spoofing.** Mitigated by HMAC signature verification + IP allowlist.

### 12.4 NDPR compliance

Nigeria Data Protection Regulation:

- **Consent at sign-up** for KYC processing.
- **Right to access** — drivers can download their data via support flow.
- **Right to deletion** — DRV-090 honours within 30 days.
- **Data minimisation** — we don't collect what we don't need.

---

## 13. Performance

### 13.1 Targets

| Metric | Target | Source of truth |
|---|---|---|
| Cold start (warm OS, app cached) | < 1.5 s to first paint | Sentry performance |
| Cold start to home interactive | < 3.5 s p95 | Sentry |
| Marketplace event latency (passenger insert → driver render) | < 500 ms p95 | PostHog `marketplace.request_received.latency_ms` |
| Bid submission round-trip | < 600 ms p95 | edge.invocation duration_ms |
| Trip location p95 latency (driver tick → passenger render) | < 1.2 s | broadcast metric |
| Edge function p95 (warm) | < 200 ms | Logflare |
| RLS query p95 | < 50 ms | pg_stat_statements |
| Battery drain at typical use | < 8% / hour | Manual measurement |

### 13.2 Mobile-specific tactics

- **Image caching** via `cached_network_image`.
- **List virtualisation** — `ListView.builder` everywhere, never spread thousands of widgets.
- **Map rendering** — the existing custom-painter `DrivioMap` is intentionally lightweight; we do not switch to `google_maps_flutter` for v1.
- **Avoid rebuilds** — controllers are split per feature so a state change in one doesn't repaint the whole tree.
- **Defer non-critical I/O** — analytics flushed every 30s, not per event.

### 13.3 Database tactics

- **Indexes on every query path documented.** `EXPLAIN ANALYZE` reviewed in PR.
- **Avoid N+1 in edge functions.** One query per request handler; never loop with queries inside.
- **Materialised views for dashboards.**
- **`pg_stat_statements`** monitored weekly; the slowest queries become tickets.

---

## 14. Observability

### 14.1 What we measure

Three cuts:

1. **Business** (PostHog): bids submitted, bids won, trip completion rate, subscription conversion, churn, payout volume.
2. **System** (Logflare + Grafana): edge function p95/p99, DB CPU, Realtime connections, webhook success, push delivery.
3. **Product/UX** (PostHog + Sentry): screen load times, error rates per screen, funnel drop-offs.

### 14.2 What we alert on

- Edge function 5xx > 1% over 5 min.
- Realtime disconnect rate > 5%.
- Subscription webhook lag > 60s.
- Trip events not landing in 30s of a state transition.
- DB connection saturation > 80%.
- Crash-free rate < 99.5%.

### 14.3 The 2 AM principle

When you get paged, the runbook tells you exactly which dashboard to open and which query to run. PLAT-014 makes this explicit. If a runbook is missing, that's a P1 ticket.

---

## 15. Trade-offs explicitly considered

| Decision | Alternative | Why we chose this | Cost |
|---|---|---|---|
| Open competitive auction | Sealed-bid, system-ranked | Differentiation; passenger sees variance | Higher passenger cognitive load |
| 90-day trial | 30-day or 60-day | KYC delays + activation curve | More unmonetised inventory |
| Hard block at expiry (sub) | 7-day grace period | Revenue protection | Higher voluntary churn |
| Geohash6 broadcast | Global broadcast + client filter | Scale | Cell-crossing logic |
| Edge functions in Deno | Lambdas in Node | Colocation latency | Team learning curve |
| Single Flutter app | Native iOS + Android | Team capacity | Minor platform-specific friction |
| Custom-painter map (v1) | Google Maps SDK | API cost, brand consistency | No turn-by-turn (handed off) |
| Paystack subscriptions | Build dunning ourselves | Engineering velocity | Hard dependency |
| 9-cell zone subscription | 1-cell subscription | Coverage at boundaries | 9× channel count per driver |
| Last-write-wins for presence | Append-only history | Single-row simplicity | No history (use trip_locations for that) |
| Postgres-only event bus | Kafka/NATS | Simplicity | Throughput ceiling (acceptable for v1) |
| Inline strings | Localisation | Velocity | Pan-African expansion blocker |

---

## 16. Future-proofing

### 16.1 Things we deliberately did not over-engineer

- **No multi-tenant.** Drivio is one tenant. If we sell white-label, we'll re-architect.
- **No multi-currency.** NGN only. Pan-African is a v2 conversation.
- **No fleet accounts.** Individual drivers only. Fleet companies become an account type with sub-drivers in v2 (schema is FK-friendly to that change).
- **No driver tiers.** Every driver is "a driver". Tiers (gold/platinum) come post-launch when we have data on what differentiates good drivers.
- **No price negotiation.** Single round of bids. v2 may add counter-offer.

### 16.2 Things we did pre-engineer (cheap insurance)

- **Money in `bigint` minor units** — currency-agnostic ready.
- **Phone in E.164** — country-agnostic ready.
- **`service_areas`** as polygons — multi-city ready.
- **`subscription_plans`** table — we can launch a "starter" tier without a migration.
- **Append-only event tables** — analytics replays survive any rebuild.
- **Pluggable identity providers** — Dojah today, anyone tomorrow.
- **`category` on `vehicles`** — economy/comfort/xl tiers when we want them, no schema change.

### 16.3 Things to revisit in 6 months

- **Realtime cost.** If marketplace channel pressure dominates the Supabase bill, consider self-hosting Phoenix Channels.
- **DB scaling.** When `trip_locations` partitions cross 100M rows total, evaluate Citus or read replicas.
- **Map rendering.** When passenger expectations push us to turn-by-turn UX, evaluate Mapbox Navigation SDK.
- **ML.** Insights (DRV-074) is rule-based v1; replace with a real model when we have ≥ 6 months of trip data.

---

## 17. Open questions and risks

### 17.1 Open product questions (bubbled up during design)

1. **What is the price ceiling?** The spec says "drivers set their own price". A driver who bids ₦500,000 for a 2 km trip is technically allowed. We've imposed a server-side cap of ₦100,000 per trip in v1; this is a safety rail, not a feature. Confirm with product.

2. **Cancellation penalties.** What happens to a driver with a 30% cancellation rate? v1 just shows the metric; v2 may auto-suspend. Need a policy.

3. **Surge pricing transparency.** Drivers can multiply prices freely; the platform shows the passenger raw bids. Should we surface "today's average for this route" to passengers? That would be a passenger-app feature; it impacts driver psychology.

4. **What fraction of a trip's location trail is required for a fare receipt?** Right now we save 5s samples; gaps > 5 min would be suspicious. Need a dispute SOP.

5. **Trial reset on suspension.** A driver who completes the trial, gets suspended (e.g., bad behaviour), then comes back via support — do they get more trial? v1 says no. Confirm.

### 17.2 Technical risks (with severity)

| Risk | Severity | Mitigation |
|---|---|---|
| Supabase Realtime can't sustain 1k concurrent drivers per zone | High | Load test before launch (DRV-099); shard further if needed |
| Paystack webhook outage | Medium | Polling fallback; ops dashboard for manual reconciliation |
| iOS background suspension stops driver location during trips | High | Foreground service / Live Activity / significant-location-change combo (DRV-036) |
| BVN provider downtime | Medium | Manual review fallback for KYC |
| Driver client modding to bypass gates | Medium | All gates server-side; modded clients still can't bid without server approval |
| Concurrent bid acceptance race (passenger picks driver A; driver A withdraws same instant) | Low | Serializable transaction in `accept-bid` |
| WAL bloat from `replica identity full` on hot tables | Low | Monitor; switch to default replica identity if it dominates |
| Realtime channel sprawl as features grow | Medium | The `realtime/CHANNELS.md` registry is the discipline; keep it the only entry point |

### 17.3 Things this design assumes

- Lagos has enough density for a marketplace at launch (≥ 5 drivers per geohash6 zone during peak).
- Passengers tolerate 60s of waiting for bids during an emergency-feeling moment (rain, surge demand).
- Drivers will accept the cognitive overhead of pricing every trip rather than letting the platform price for them. (Design mitigates with sane defaults via `driver_pricing_profile`.)

If any assumption is wrong, the marketplace mechanic itself needs a rethink — which is a product call, not an engineering call.

---

## 18. Reading order for a new engineer

1. `knowledge.md` — what the Flutter app already looks like.
2. This file — why we're building it this way.
3. `driver.md` — what to build next, in order.
4. `supabase/migrations/` — the schema source of truth.
5. `supabase/functions/` — the server-side contracts the app depends on.
6. `lib/modules/commons/` — the shared Flutter primitives.

When in doubt about any decision in `driver.md`, the answer is in this file. When this file is wrong, fix it before the ticket — the document is the source of truth for *why*; the tickets are the source of truth for *what*. Keep them coherent.
