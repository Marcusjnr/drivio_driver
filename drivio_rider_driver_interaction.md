# Drivio — How the Rider and Driver Apps Interact

> Cross-app reference. Focus: everything that flows **between** the passenger
> app (`drivio-user`, package `drivio_user`) and the driver app
> (`drivio_driver`, package `drivio_driver`) — the shared backend, the ride
> lifecycle, realtime topology, live location, chat, calls, cancellations,
> ratings, and gating.
>
> Companion docs already in the repos:
> - `drivio-user/knowledge.md` — passenger app state of the world
> - `drivio_driver/knowledge.md` — driver app state of the world (older; predates
>   the real Supabase backend — treat its "no real backend" claims as stale)
> - `drivio_driver/drivio_driver_flows.md`, `*_prd.md`, `drivio_brd.md` — product specs
>
> Last written: 2026-09-09 from a full read of both `lib/` trees.

---

## 1. One backend, two clients

Both apps are Flutter (Riverpod `StateNotifier`, `get_it`, MapLibre/OpenFreeMap,
no `freezed`, no codegen) and talk to **one shared Supabase project**
(`gxzyednqegqycnmbdghf` — Postgres + PostGIS + Realtime + Edge Functions + Auth +
Storage). There is no per-app database and no app server of Drivio's own — the
"backend" is Postgres RPCs (mostly `SECURITY DEFINER`), Row-Level Security, the
Realtime fan-out, and a handful of Deno edge functions.

| Concern | Where it lives |
|---|---|
| Identity | `auth.users` + `profiles` (shared). `passengers` / `drivers` are role tables keyed by `user_id`. |
| Money | `wallets` + `wallet_ledger`, discriminated by `owner_kind` (`driver` \| `passenger`). Driver app reads through `driver_wallets` / `driver_wallet_ledger` compat views. |
| The trip | A single `trips` row. Both sides read/write it through their own RLS scope (`auth.uid() = passenger_id OR auth.uid() = driver_id`). |
| Realtime | Postgres-changes for private per-row streams; broadcast channels for high-frequency driver location. |

Because a trip is one row seen through two scopes, most "interaction" is: one side
calls an RPC that mutates a row → the other side's realtime subscription on that
row fires → its controller re-fetches / transitions.

### The differentiator — a bidding marketplace

The platform **never sets the fare**. The rider publishes a ride request; nearby
drivers each **bid their own price**; the rider picks one of the incoming offers.
There is a soft price *band* per Nigerian state (admin-configured base + per-km +
`warn_pct`) that the rider is quoted from and that the server **hard-caps driver
bids to** — but within that band the price is the driver's call and the choice is
the rider's.

---

## 2. End-to-end ride lifecycle

Actors: **R** = rider app, **D** = driver app, **PG** = Postgres/RPC, **RT** = realtime.

### 2.1 Rider publishes a request

1. **R** picks pickup (GPS reverse-geocoded) + dropoff (`places-proxy` edge fn
   autocomplete/details). `PendingRideController` holds the pair.
2. **R** resolves the pickup's Nigerian **state** via the `reverse-state` edge
   function and pulls the band via `get_state_pricing_default(p_state)`
   (`FareEstimateRepository`). This is shown to the rider as an estimate and,
   critically, the **state string is stamped on the request** so the server caps
   bids against the exact row the rider was quoted from.
3. **R** computes haversine distance + a 25 km/h ETA (no directions polyline in
   v1) and calls **`create_ride_request(pickup_lat, pickup_lng, pickup_address,
   dropoff_lat, dropoff_lng, dropoff_address, distance_m, duration_s,
   window_seconds=60, pickup_state)`**.
   - Server validates: 100 m–80 km, no other open request, no active trip;
     inserts `ride_requests` with `status='open'`, `expires_at = now() + window`,
     and a generated `pickup_geohash6`.
   - An `AFTER INSERT` trigger tops up `recent_places` (cap 20).
4. **R** routes to `/waiting`. `RideRequestController` adopts the request,
   subscribes to its own row, and starts an expiry timer.

`RideRequestController` (rider) lifecycle phases: `idle → creating → waiting →
matched | cancelled | expired | failed`. It cold-start-hydrates via
`get_my_active_ride_request()` so a backgrounded rider resumes into `/waiting`.

### 2.2 Drivers discover the request

The driver app does **not** rely on a zone-broadcast (the older
`marketplace:zone:<geohash6>` design in `knowledge.md` is not what the code
does). Instead `MarketplaceController` + `SupabaseRideRequestRepository`:

- Subscribes to **`public:ride_requests`** postgres-changes (insert/update/delete,
  **no server-side filter** — geography columns can't be filtered/decoded in the
  payload), and on **any** event re-fetches the canonical list.
- The canonical list is **`list_nearby_ride_requests(p_lat, p_lng)`** — a
  `SECURITY DEFINER` RPC that applies an **expanding-ring geo filter** (≈2 km → 8
  km in 2 km steps as the request ages, ~20 s per step), sorts by proximity to
  the driver, caps at ~50 rows, and joins rider identity
  (`passenger_first_name`, `passenger_avatar_url`, `passenger_rating`,
  `passenger_rating_count`) + `pickup_state`.
- Refetch triggers: first GPS fix, driver moved ≥250 m, any realtime event, and a
  **5 s safety-net poll** (Supabase Phoenix channels can silently stop delivering
  after idle).
- Backgrounded / offline drivers get an **FCM data push** (`type=ride_request`)
  fanned out server-side to nearby online drivers → `ride_alert_push.dart` plays a
  looping alarm-style sound + full-screen heads-up notification. Foreground gets
  the same looping sound with the feed card as the visual layer.
- Client-side the feed is further filtered by the driver's saved trip-length
  preference (`PricingProfile.acceptsDistance`) and hides declined ids +
  already-expired (0:00) cards.

Only drivers who pass **gating** ever bid successfully — see §7.

### 2.3 Driver bids

1. **D** taps a feed card → `DriveShellController.enterBidding(requestId)` (the
   whole drive screen is one persistent MapLibre canvas that morphs between
   `idle / bidding / trip / tripCompleted / tripCancelled`; it is **not** a
   separate route). The new-trip alert sound is silenced on tap.
2. `RideRequestController` (driver, `autoDispose.family` by requestId) hydrates:
   `get_ride_request(p_id)` + `listMyVehicles()` + pricing profile, in parallel.
   It computes the trip's **market fare** = `base + per_km × km` (lifted by any
   admin short-trip uplift band) from `get_state_pricing_default` keyed on the
   **request's `pickup_state`** (never the driver's GPS — that could substitute a
   different band).
3. The bid composer (`slider` 60–160 % of suggested, or `chips` −15 %/mid/+15
   %/+30 %) is **hard-clamped** to `marketFare ± warn_pct`. Free keypad entry was
   removed on purpose. A market-deviation banner shows while composing.
4. **D** calls **`submit_bid(p_request_id, p_vehicle_id, p_price_minor,
   p_eta_seconds)`** → inserts/updates a `ride_bids` row (`UNIQUE
   (ride_request_id, driver_id)` — one live bid per driver per request),
   `status='pending'`, its own `expires_at` (~60 s per offer). Server rejects
   `price_outside_band`, non-active drivers, closed requests.
5. **D** enters `BidPhase.waiting`; countdown switches from the request window to
   **this bid's** `expires_at`. It watches the bid via
   `ride_bids:<bidId>` postgres-changes **plus a 4 s poll** fallback.
   Driver can `withdraw_bid(p_bid_id)` → back to `composing`.

### 2.4 Rider sees offers

- **R** `/offers` uses `BidsController` (`autoDispose.family` by requestId):
  snapshot via **`list_bids_for_my_request(request_id)`** (joins `profiles` for
  driver name/avatar/rating/trip-count and `vehicles` for make/model/colour/plate
  + driver amenities), then merges **`public:ride_bids:ride_request_id=eq.<id>`**
  postgres-changes on top.
- Realtime payloads are the bare `ride_bids` row (no joins) — `Bid.fromBareRow` +
  `mergedWith` keep previously-known join columns; a debounced re-fetch
  (`list_bids_for_my_request`) back-fills missing joins. A 10 s poll is the
  safety net under the socket.
- `BidsState.liveBids` filters to `status == pending && expires_at` in the future,
  judged against an **estimated server clock** (`ServerClock`) — bids only live
  ~60 s so a skewed device clock would hide every offer. `bidsTickProvider`
  (1 s wall-clock stream) drives per-card "expires in M:SS" countdowns without
  per-card timers.
- Sort views: cheapest / fastest (ETA) / newest / top-rated.
- **No counter-offers.** (`offers_controller.dart` still has seeded counter-offer
  scaffolding but the live path is `BidsController`.)

### 2.5 Rider accepts a bid

**R** calls **`accept_bid(p_bid_id, p_payment_method, p_circle_id,
p_for_target_id, p_payer)`** — a serializable transaction that:

- locks the bid + request rows (`FOR UPDATE`), asserts states;
- on **wallet** trips, holds **₦100** from the rider wallet
  (`wallet_ledger { kind: 'trip_hold' }`); **cash** trips hold nothing;
- flips the request to `status='matched'`, sets `matched_bid_id`;
- sets the chosen bid `status='accepted'`, **rejects all sibling bids**
  (`status='rejected'`);
- inserts the **`trips`** row (`state='assigned'`, `payment_method`,
  `fare_minor` = bid price, `bid_id`, `driver_id`, `vehicle_id`, `passenger_id`)
  + a `trip_events` audit row.
- Idempotent on re-call; returns `{trip_id, ride_request_id, bid_id, fare_minor,
  idempotent}`.

Payment method is chosen **at acceptance** (Wallet or Cash bottom sheet). **No
card-on-file.** `p_circle_id` / `p_for_target_id` / `p_payer` support "book a ride
for someone else" (see §9).

### 2.6 Both sides converge on the trip

- **R**: `BidsController.acceptBid` succeeds → `TripController.hydrateActive()`
  (`get_my_active_trip()` — joined driver/vehicle/addresses/ETA) → route
  `/confirm`. `TripController` attaches `trips:<id>` postgres-changes on
  `state`. `/confirm` auto-routes to `/trip` on `en_route+`; `/trip` auto-routes
  to `/complete` on `completed` (or `/edge/driver-cancelled` on `cancelled`).
- **D**: `RideRequestController._handleBidUpdate` sees `accepted` (via realtime or
  the 4 s poll) → `findTripIdForBid(bidId)` → `BidPhase.won` →
  `DriveShellController.enterTrip(tripId)`. Losers get `rejected`/`expired` →
  `BidPhase.lost` → toast + back to idle.
- **D** also has `_reconcileActiveTrip()` on mount/resume: `get_my_active_trip`
  → if a live trip exists but the shell isn't in trip mode (missed "bid won"
  event, hot restart), force it into trip mode.

### 2.7 Active trip state machine

Canonical states (`trip_state_t`): `assigned → en_route → arrived → in_progress →
completed`, plus terminal `cancelled`.

**Only the driver advances the trip.** `ActiveTripController` (driver) calls
**`transition_trip(p_trip_id, p_to_state, p_reason)`**:

| From | Driver button | To |
|---|---|---|
| `assigned` | "I'm on my way" | `en_route` |
| `en_route` | "I've arrived" | `arrived` (server enforces **≤200 m from pickup**, else `too_far_from_pickup_<n>m`) |
| `arrived` | "Start trip" | `in_progress` |
| `in_progress` | "Complete trip" | `completed` |

The rider app is **read-only** on trip state — `TripController` just watches
`trips:<id>` and re-renders / auto-routes. Each side has a 5 s poll fallback
under the realtime sub.

### 2.8 Completion & settlement

- Driver's completion path (server side, `complete-trip` / the `completed`
  transition) releases the ₦100 hold and **debits the full fare** on wallet
  trips (`wallet_ledger { kind: 'trip_debit' }` for the rider,
  `trip_credit` for the driver). Cash trips: nothing moves on-ledger in v1
  (`PLAT-017 cash_settlements` still pending).
- **R** wallet realtime sub (`wallets:user_id=eq.<self>`, filtered
  `owner_kind == 'passenger'`) picks up the balance change; `/complete` shows the
  fare summary + payment-method-aware copy.
- **D** shell shows the "you earned" terminal body until "Back online".

### 2.9 Ratings (both directions)

- **R → D**: `submit_driver_rating(p_trip_id, p_rating, p_tags, p_comment)`;
  `report_amenity_mismatch(p_trip_id, p_codes)` if promised amenities were
  missing; `get_my_driver_rating_for_trip` to show what was already submitted.
- **D → R**: `passenger_rating` tables + `PassengerRatingController` /
  `passenger_rating_repository`. The rider's average + count is what surfaces on
  future ride requests to drivers (`passenger_rating`, `passenger_rating_count`;
  null → "New").
- Driver's own average feeds `list_bids_for_my_request` (`driver_rating`,
  `driver_trips`) so the rider sees it on each offer card.

---

## 3. Realtime channel topology

| Channel | Type | Publisher | Subscriber | Purpose |
|---|---|---|---|---|
| `public:ride_requests` | postgres-changes (no filter) | rider `create_ride_request` | **driver** `MarketplaceController` | New/updated/removed open requests → triggers `list_nearby_ride_requests` refetch |
| `public:ride_bids:ride_request_id=eq.<id>` | postgres-changes | driver `submit_bid` | **rider** `BidsController` | Bids landing on the rider's open request |
| `ride_bids:<bidId>` (`id=eq`) | postgres-changes | rider `accept_bid` (accept/reject) | **driver** `RideRequestController` | Driver's own bid outcome |
| `trips:<tripId>` (`id=eq`) | postgres-changes | driver `transition_trip`, rider `cancel_my_active_trip` | **both** `TripController` / `ActiveTripController` | Trip state transitions |
| `trip:<tripId>:driver_location` | **broadcast**, event `driver_location` | **driver** `TripLocationRecorder` (every 5 s) | **rider** `DriverLocationController` | Live car position `{lat, lng, speed_kph, heading_deg, at}` |
| `calls:<callId>` (`id=eq`) | postgres-changes | either party via call RPCs | **both** `ActiveCallController` | Masked-call signaling (ring/answer/decline/end) |
| `calls:incoming:<userId>` (`callee_id=eq`) | postgres-changes insert | caller `start_call` | **callee** | Foreground incoming-ring detection |
| `messages` (trip-scoped, RLS) | postgres-changes | either party `send` | **both** `ChatController` | In-trip chat |
| `wallets:user_id=eq.<self>` / `wallet_ledger:user_id=eq.<self>` | postgres-changes | settlement RPCs | owner | Balance / ledger updates (client filters `owner_kind`) |

Rule in both codebases: **every** realtime subscription's `StreamController.onCancel`
calls `removeChannel`. Realtime is **notification, not source of truth** — every
balance/state/acceptance mutation is a Postgres transaction; clients re-fetch the
canonical row.

---

## 4. Shared schema (interaction-relevant)

- **`ride_requests`** — `id, passenger_id, pickup/dropoff geography + *_address,
  expected_distance_m, expected_duration_s, status ride_request_status_t
  (open|matched|cancelled|expired), matched_bid_id, pickup_geohash6 (generated),
  pickup_state, created_at, expires_at`.
- **`ride_bids`** — `id, ride_request_id, driver_id, vehicle_id, price_minor,
  currency, eta_seconds, status ride_bid_status_t
  (pending|accepted|rejected|expired|withdrawn), created_at, expires_at`.
  `UNIQUE (ride_request_id, driver_id)`.
- **`trips`** — `id, ride_request_id, bid_id, driver_id, vehicle_id,
  passenger_id, fare_minor, currency, state trip_state_t
  (assigned|en_route|arrived|in_progress|completed|cancelled), payment_method
  payment_method_t (wallet|cash), started_at, ended_at, cancellation_reason,
  actual_distance_m, actual_duration_s`.
- **`trip_events`** — append-only audit (`kind, actor (driver|passenger|system),
  payload jsonb, occurred_at`).
- **`trip_locations`** — persisted 5 s GPS breadcrumbs (receipt + dispute audit).
- **`messages`** — trip chat, RLS-scoped to the trip's two participants.
- **`calls`** — masked-call rows (`caller_id, callee_id, trip_id, status
  ringing|accepted|declined|cancelled|ended`, Agora channel/token fields).
- **`driver_presence`** — driver online status + last GPS fix (`upsert_driver_presence`).
- **`passenger_ratings` / `driver_ratings`**, **`wallets` / `wallet_ledger`**,
  **`profiles` / `passengers` / `drivers` / `vehicles`**, **`subscriptions`**.

### RPCs by caller

| Rider app calls | Driver app calls |
|---|---|
| `create_ride_request`, `cancel_my_ride_request`, `get_my_active_ride_request`, `list_bids_for_my_request` | `list_nearby_ride_requests`, `get_ride_request`, `submit_bid`, `withdraw_bid`, `get_bid` |
| `accept_bid`, `get_my_active_trip`, `cancel_my_active_trip` | `transition_trip`, `get_trip_with_route`, `get_my_active_trip` |
| `submit_driver_rating`, `report_amenity_mismatch`, `get_my_driver_rating_for_trip`, `create_trip_share` | passenger-rating RPCs, `record_trip_location`, `get_trip_locations` |
| `get_state_pricing_default`, `reverse-state` (edge fn) | `get_state_pricing_default` / state guidance, `get_or_create_my_profile` |
| `start_call` / `answer_call` / `decline_call` / `cancel_call` / `end_call`, `get_trip_contact` | same call RPCs, `get_trip_contact` |
| wallet: `init_wallet_topup`, `complete_wallet_topup`, `topup_wallet_dev_mode` | wallet via `driver_wallets` views, payouts/withdrawals |

`accept_bid`, `submit_bid`, `transition_trip`, `cancel_*` are the four
gates that actually change cross-app state; all are `SECURITY DEFINER`,
`authenticated`-only, and idempotent where re-call is plausible.

---

## 5. Live driver location

- **Driver publishes** (`TripLocationRecorder`, `autoDispose.family` by tripId):
  starts the moment the trip is `assigned` (so the rider's `/confirm` shows the
  car immediately), stops on a terminal state. Two tickers, both **5 s**:
  - broadcast `trip:<id>:driver_location` event `driver_location`
    `{lat, lng, speed_kph, heading_deg, at}` (reuses one channel, never
    re-subscribes per tick);
  - `record_trip_location(p_trip_id, p_lat, p_lng, …, p_recorded_at)` →
    `trip_locations` (the audit/receipt trail; also drives the driver's own
    route polyline overlay).
  - GPS source is the presence foreground-location service (`PresenceController`),
    which keeps streaming even if the UI process is killed. 5 s matches the
    position stream's own floor — faster broadcasts just re-sent stale fixes and
    5×'d the Realtime bill.
- **Rider consumes** (`DriverLocationController`, `autoDispose.family` by tripId):
  subscribes to the broadcast, discards events with `at` older than 30 s (network
  reorder), flips `stale = true` after 15 s of silence → marker dims + "Driver
  signal weak" amber banner on `/trip`.

---

## 6. Chat & voice calls

### Chat
Shared **`messages`** table, RLS-scoped to the trip's driver + passenger. Both
apps have a near-identical `ChatController` (`autoDispose.family` by tripId):
snapshot `listForTrip` → `watchForTrip` postgres-changes → optimistic append with
id-dedupe of the realtime echo → 1 pull-to-refresh recovery path. Same row drives
both surfaces; neither side can read/post into a chat it isn't part of.

### Masked voice calls (Agora)
`agora_rtc_engine` on both sides; numbers are never exchanged. Signaling is a
`calls` row + RPCs: `start_call(p_trip_id)` → `answer_call` / `decline_call` /
`cancel_call` / `end_call(p_call_id, p_reason)`. `get_trip_contact(p_trip_id)`
returns the counterpart's display name/avatar only.

- Caller: `start_call` → ring row (`status='ringing'`) → watch `calls:<id>` →
  30 s ring timeout → on `accepted` both join the Agora channel.
- Callee: foreground `calls:incoming:<userId>` insert watcher, or FCM
  push + CallKit/`flutter_local_notifications` full-screen intent when
  backgrounded (`call_push_handler.dart`, `call_push.dart`).
- Terminal transitions are idempotent — whichever signal lands first (row update,
  engine event, local tap, timer) wins; `calls` error codes: `call_in_progress`,
  `trip_not_active`.

---

## 7. Who is allowed to bid — driver gating

`submit_bid` rejects bids from drivers who aren't "active", and the driver shell
(`DriveShellPage`) won't even go online / show the feed unless **all** gates pass.
The gates, each with its own bottom sheet:

1. **Location** — "Allow all the time" background permission (Android) is required
   to be online; losing it force-offlines.
2. **Vehicle** — at least one `vehicles` row with `status = active`
   (`VehicleGateSheet` / `VehiclePendingSheet`).
3. **KYC** — `KycController`: overall `approved` **and** liveness/face check
   passed (`KycGateSheet`).
4. **Subscription** — "Drivio Pro" flat-rate sub must be in an unlocking state
   (`SubscriptionController.unlocksMarketplace`). Paused/expired/cancelled →
   `SubscriptionGateSheet` and auto-offline (but the app will **not** force-offline
   mid-trip — it honours the gate once the active trip closes).

The rider app neither reads nor cares about any of this — the marketplace only
ever contains active drivers because the server-side `submit_bid` is the gate.

---

## 8. Cancellations

| Who | How | Server effect | Other side sees |
|---|---|---|---|
| Rider, **before** match | `cancel_my_ride_request(request_id)` | request → `cancelled`, all `pending` bids on it → `rejected` | Driver's `ride_bids:<bidId>` fires `rejected` → `BidPhase.lost` → toast, back to idle |
| Rider, **after** match (trip `assigned`/`en_route`) | `cancel_my_active_trip(p_reason='passenger_cancelled')` | trip → `cancelled`, releases the ₦100 wallet hold, writes `trip_events` | Driver `trips:<id>` fires → shell reads `cancellation_reason` starts-with `passenger` → "Passenger cancelled the ride." → terminal `tripCancelled` body |
| Driver, after match | `transition_trip(tripId, cancelled, reason)` — `driver_cancelled` or a reason from the cancel-reason sheet | trip → `cancelled` | Rider `trips:<id>` fires → `/trip` auto-routes to `/edge/driver-cancelled` |

Rider policy is "free to cancel anytime"; driver-compensation for late rider
cancels (`PLAT-018`) is not built yet. Rider `RideRequestController.cancel()`
optimistically flips local state and trusts the realtime echo for the canonical
one.

---

## 9. "Book a ride for someone else" (circles)

Rider-app-only feature layered on the same primitives. A rider (the *orderer*)
can request and pay for rides on behalf of a connected *target* rider.
`accept_bid` takes `p_circle_id`, `p_for_target_id`, `p_payer` (`orderer` |
`target`). Supporting types/RPCs: `BookedRide` (`list_rides_i_booked`),
`IncomingBookingRequest` (`list_incoming_booking_requests`), `BookedByInfo`
(`get_active_trip_booking` — powers the "booked by X" banner on the target's
trip). `booking_repository` / `circle_repository` in the rider app. The driver
app is unaware — it just sees a normal trip.

---

## 10. Time, money, geo conventions

- **Money**: `bigint` minor units (kobo). `fare_minor` on the trip = the accepted
  bid's `price_minor`. Display `~/ 100` then `NairaFormatter` / `₦` + thousands.
- **Wallet hold**: ₦100 (`10000` kobo) at `accept_bid`, full fare at completion.
- **Auction window**: request 60 s (server clamps ≥15 s); each bid ~60 s.
- **Time**: `timestamptz` server-side. Rider bidding/offer countdowns run off
  `ServerClock` (estimated server-time), not the device clock — the windows are
  too short to trust a skewed phone.
- **Distance/ETA**: haversine + 25 km/h (rider) / driver's own pricing profile
  for the fare suggestion. No directions polyline in v1 (`USR-033` pending).
- **Geo filter**: expanding ring 2→8 km server-side in `list_nearby_ride_requests`;
  `pickup_geohash6` is a generated column (don't insert into it).
- **Pickup arrival gate**: driver must be ≤200 m to mark `arrived`.
- **Service area**: 100 m–80 km trip distance enforced in `create_ride_request`.
  Address *search* is global; only ride creation is bounded.

---

## 11. Failure-mode handling worth knowing

- **Silent Phoenix channel death**: every realtime stream in both apps has a
  polling fallback — marketplace feed 5 s, rider bids 10 s, driver bid-watch 4 s,
  trip-state 5 s both sides, chat pull-to-refresh.
- **Bare realtime rows**: `ride_bids` postgres-changes payloads carry no joins;
  the rider merges with previously-known join data + debounced re-fetch. A
  freshly-tapped bid card can briefly show "Driver" / "Vehicle" fallbacks.
- **Expired-bid race**: rider `liveBids` drops bids past `expires_at` so it never
  tries to `accept_bid` on a server-aged-out bid (which the driver already
  stopped seeing).
- **Missed "bid won"**: driver `_reconcileActiveTrip()` on mount/resume rebuilds
  shell state from `get_my_active_trip`.
- **Process killed while online / mid-trip**: driver presence foreground service
  is the source of truth; UI reconciles `isOnline` and re-arms location
  streaming on resume.
- **`accept_bid` double-tap**: `BidsController._accepting` single-flight +
  server-side idempotency + `FOR UPDATE` lock.

---

## 12. Where the docs and the code disagree (read the code)

- `drivio_driver/knowledge.md` is pre-backend ("no real backend", "seeded
  constant data", 39 screens). The driver app now has a full Supabase data layer
  (`modules/commons/data/*_impl.dart`), the `marketplace`, `trip`, `kyc`,
  `subscription`, `documents`, `vehicle`, `support` modules, Mixpanel, FCM push,
  Agora calls, background location. Trust `lib/`.
- `drivio-user/knowledge.md` §4.3 / §9 describe a `marketplace:zone:<geohash6>`
  broadcast for driver discovery. The shipped mechanism is
  `public:ride_requests` postgres-changes + `list_nearby_ride_requests` RPC +
  5 s poll + FCM. Same outcome, different transport.
- `drivio-user/knowledge.md` says "no suggested fare, no median anchor" pre-bid.
  The shipped rider flow **does** show a state-band fare estimate
  (`FareEstimateRepository`) and the server hard-caps bids to that band — the
  "platform never sets *the* fare" principle holds, but there is a visible band
  now.
- Repo paths in both knowledge docs point at `~/StudioProjects/…`; the actual
  checkouts are `~/FlutterMobileProjects/drivio-user` and
  `~/FlutterMobileProjects/drivio_driver`.
