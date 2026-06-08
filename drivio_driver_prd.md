# Drivio Driver — Product Requirements Document (PRD)

**Product Name:** Drivio Driver — Flutter mobile app for the Nigerian ride-hailing marketplace where drivers set their own prices.

**Product Owner:** [Product Owner Name]
**Date:** May 31, 2026
**Version:** 1.0
**Status:** Draft
**Related documents:**
- `drivio_brd.md` — business case, market, KPIs, risks, budget
- `docs/superpowers/specs/2026-05-31-drivio-brand-design.md` — voice, palette, typography, motion
- `driver.md` — engineering ticket roadmap (PLAT-001..014 + DRV-001..101)
- `driver_context.md` — architecture and decision record (the WHY)
- `drivio_context.md` — handoff state (what's built, what's next)

---

## 📌 What This Document Is About

This PRD is the source of truth for **what the Drivio Driver app does**. Not how it's built (engineering tickets and `driver_context.md` cover that). Not why the business is doing this (the BRD covers that). Not how it looks or sounds (the brand spec covers that).

This document covers: the user, the principles, the screens, the features, the requirements, the flows, the success metrics, the open questions. If you need to know "does the driver app do X?" or "what happens when Y?" — this is the document.

Audience: product managers, designers, engineers, ops/support staff who need to understand the product surface. New team members should be productive on a feature after reading the relevant section here + the matching ticket(s).

---

## 1. Executive Summary

**Drivio Driver is a Flutter mobile app for Lagos drivers who want to keep 100% of their fares.**

Unlike Uber and Bolt, where the platform sets the price and takes 20–30% commission, Drivio gives drivers a different deal: the driver decides the price, the passenger picks from competing bids, and the platform takes zero per-trip cut. Drivio's revenue comes only from the **Drivio Pro subscription**, priced in three tiers — Daily ₦2,500, Weekly ₦15,000, Monthly ₦50,000 — so each driver can pick the commitment that matches how they actually work. New drivers get a 90-day free trial, then pick a tier (Monthly is the default suggestion).

The app gives drivers everything they need to operate as micro-entrepreneurs:
- KYC + vehicle onboarding
- Online/offline control with foreground-service location streaming
- A realtime marketplace where they see passenger ride requests within ~500ms
- A bid composer they use to propose their price
- Active trip lifecycle from acceptance through completion
- A wallet, payout system, and earnings analytics
- Pricing strategy tools (peak/night multipliers, max pickup distance, trip-length preferences)
- Safety primitives (SOS, trusted contacts)
- Subscription management

The app is built around three load-bearing decisions:
1. **The driver sets the price.** The bid composer is the brand's hero surface. "You keep" equals the bid price; no commission, no fee math.
2. **The subscription gate is server-enforced.** Drivers who let their subscription lapse cannot bid — but active trips always complete.
3. **The auction is live.** Marketplace requests fan out in <500ms via Supabase Realtime broadcast (geohash6 zones). Bids land in <800ms on the passenger side.

For business context, market, KPIs, and risks, see the BRD.

---

## 2. The Driver — Persona

**Name (illustrative):** Tunde Olawale
**Age:** 34
**Location:** Lagos (Yaba)
**Vehicle:** Toyota Corolla 2018, owned outright
**Income:** ₦200,000–₦400,000/month, after fuel and maintenance
**Currently:** Bolt + Uber driver. Considers himself a "professional driver," not a "gig worker."

### What he wants

- **More naira per hour driven.** He works 10–14 hour shifts; he's tired of platforms taking 25% of every trip.
- **Predictability.** He wants to know what he's earning and why. He distrusts algorithmic pricing he can't see.
- **Choice.** He wants to decline trips that don't make sense — without algorithmic punishment.
- **A human to talk to.** When something goes wrong (wrongful deactivation, dispute, accident) he wants a real person to call, not a chatbot.
- **A platform that respects him.** He's noticed which platforms treat drivers like contractors vs. people. Drivio's pitch — "you set the price, no commission" — feels like the first platform that takes the relationship seriously.

### What he doesn't want

- A complicated app. He uses Uber Driver every day; he can navigate any ride-hailing app, but he doesn't want to learn three new patterns.
- A KYC process that drags on for a week.
- Surprise fees, hidden math, fine print he didn't see.
- Loud notifications. He's in the car most of the day; quiet, useful pings only.

### Constraints

- **Network:** Mostly cellular (MTN, Airtel). Flaky in tunnels, under bridges, in elevators. Drives across full-bar and zero-bar zones every day.
- **Battery:** Phone in mount on dash. Charging while driving but not always. App can't drain the battery.
- **Lighting:** Sun glare during the day, dim mixed lighting at night. The screen has to read in both.
- **Distraction:** Bid decisions in 60 seconds while watching the road. UI has to be glanceable.

### Pain points with current platforms

| Pain | What Drivio does |
|---|---|
| 20–25% commission | Zero per-trip cut |
| Opaque algorithmic pricing | Driver sets the price for every trip |
| Algorithmic deactivation | Human review on every suspension |
| No appeal process | Real support, not chatbots |
| Card-only passenger payments | Wallet + cash; driver gets paid either way |
| Slow payouts (weekly batches) | On-demand payouts via Paystack |
| App-fatigue UI | Calm, considered, premium-warm visual language |

---

## 3. Product Principles

These are the durable rules that decide every product trade-off.

### 3.1 The driver is in charge.

Every screen treats the driver as the protagonist. The bid composer is the hero. The earnings page shows real numbers without commission math. The home page foregrounds **your** day's earnings, **your** rating, **your** trip count. No paternalism. No nudges to drive in zones we want you to drive in (we surface demand, but you decide).

### 3.2 You keep what you earn.

"You keep" equals the bid price. No `* 0.96`. No service fee. No platform fee. No surprise math. This is encoded in product copy, in the bid composer, in the wallet ledger, in the earnings analytics. If a screen displays "You keep ₦X," that X is the unmodified bid amount.

### 3.3 Trips in progress are sacred.

Even if the driver's subscription lapses mid-trip, the trip completes. Even if their phone loses GPS, the trip state preserves. Even if the app is force-killed, the trip resumes on relaunch. We never strand a passenger or a driver mid-flow to enforce a billing rule.

### 3.4 The subscription gate is server-enforced.

A modified client can't bypass the gate. `go-online`, the marketplace channel subscription, and `submit-bid` all check `is_driver_active(user_id)` server-side. Client-side gating is for UX only — to avoid the driver tapping an action that will reject them.

### 3.5 Speed at glance, depth on tap.

A driver glancing at the app while driving needs to read the live state in under a second. Detailed info lives one tap deeper. The home page shows: are you online, how much did you earn today, are there requests nearby — and nothing else. The bid composer shows: distance, ETA, fare input — and nothing else.

### 3.6 Calm under pressure.

The brand voice carries into the app. No exclamation marks (except `AppNotifier.success`). No frantic UI. No panic-coded reds outside of true errors. The auction window is a calm dial, not a flashing countdown. The active-trip status updates feel like a confident friend giving directions, not a dashboard alarm.

### 3.7 Quiet by default, vocal when it matters.

Notifications wake the driver only for state changes that matter: new request received, subscription expiring in 1 day, payout settled, safety event. Marketing pushes — nudges to drive, "we miss you" — are off by default.

### 3.8 Network honesty.

The app shows you when it's offline. The mutation queue tells you when an action is queued vs. live. The realtime channel state surfaces when it drops. Drivers operate in flaky networks; we never pretend an action succeeded when it's only queued locally.

### 3.9 Documents are obligations, not theatre.

KYC and vehicle docs are required because of regulation (FRSC, LASRRA, BVN/NIN). They are not branded as a feature. The KYC flow is fast, clear, and over within minutes of submission.

### 3.10 Privacy by default.

PII (BVN, NIN, bank, phone) is encrypted at rest via `pgcrypto`. Logs scrub PII. Sentry/PostHog never receive personal data. Default behaviors share the minimum signal needed; opt-in for anything richer.

---

## 4. Information Architecture

### 4.1 Top-level surfaces

The app has **four bottom-tab destinations** plus modal/route-based flows.

```
┌─ /splash                 (always first; brand reveal + permission ask)
├─ /welcome                (signed-out)
├─ /sign-in, /sign-up      (auth entry)
├─ /otp                    (OTP verification)
│
├─ /home                   ◄── Drive tab — the marketplace canvas
├─ /earnings               ◄── Earnings tab
├─ /pricing                ◄── Pricing tab
├─ /profile                ◄── Profile tab
│
├─ Modal-style: paywall, KYC, add vehicle
├─ Flow-driven: ride request, active trip, chat, call, safety
└─ Detail/settings: every profile sub-screen
```

### 4.2 Routes (canonical)

| Route | Purpose | Status |
|---|---|---|
| `/` | Splash + permission ask + bootstrap | shipped |
| `/welcome` | Signed-out landing | shipped |
| `/sign-in`, `/sign-up` | Auth | shipped |
| `/otp` | OTP verification | shipped |
| `/paywall` | Subscription paywall (gates trial start) | shipped |
| `/kyc`, `/kyc/bvn-nin`, `/kyc/selfie`, `/kyc/document` | KYC orchestrator | shipped |
| `/home` | DriveShellPage — the central canvas | shipped |
| `/add-vehicle` | Add a vehicle | shipped |
| `/earnings` | Earnings tab | shipped |
| `/pricing` | Pricing strategy tab | shipped |
| `/profile` | Profile hub tab | shipped |
| `/profile/vehicle` | Vehicle details | shipped |
| `/profile/reviews` | Passenger ratings | shipped |
| `/profile/payment-methods` | Payout account + billing history | shipped |
| `/profile/referral` | Refer & earn | shipped |
| `/profile/edit` | Profile editor | shipped |
| `/profile/help` | Static help topics | shipped |
| `/profile/sign-out` | Sign out + DANGER ZONE delete account | shipped |
| `/notifications` | Notifications inbox | shipped |
| `/subscription/manage` | Subscription details + billing | shipped |
| `/ride-request` | Live request → bid composer | shipped |
| `/active-trip` | Active trip state machine | shipped |
| `/chat`, `/call`, `/safety` | Trip realtime + safety | shipped (chat local; call stubbed) |
| `/vehicle/change` | Switch active vehicle | shipped |
| `/pricing/pickup-distance` | Max pickup distance | shipped |
| `/pricing/preferred-trip-length` | Trip-length filter | shipped |
| `/documents/reupload` | Re-upload rejected document | shipped |
| `/edge/*` | No-requests · offline · sub-expired · rider-cancelled | shipped |

### 4.3 Removed routes (durable)

These were placeholder routes deprecated as part of brand and product cleanup:

- `addCard`, `insurance`, `inspection`, `docLicence`, `docRegistration`, `docBackground`, `notifications` (preferences page) — removed; KYC re-routes for documents.

---

## 5. Feature Inventory

| # | Area | Key features | Status |
|---|---|---|---|
| 1 | **Onboarding & Auth** | Welcome, sign-in/sign-up, phone OTP, terms acceptance | shipped (real OTP deferred to PLAT-009) |
| 2 | **KYC** | BVN/NIN, selfie + liveness, vehicle docs (DL, reg, insurance, road worthiness, LASRRA, inspection) | shipped (Dojah integration deferred) |
| 3 | **Vehicle management** | Add vehicle, edit, switch active, vehicle docs, inspection | shipped |
| 4 | **Subscription & Trial** | Drivio Pro 3-tier (Daily ₦2,500 / Weekly ₦15,000 / Monthly ₦50,000), 90-day free trial, anniversary renewal, tier switching, hard block at expiry, sacred-trip rule | gate shipped at single-tier; 3-tier migration is the next pass |
| 5 | **Online/offline** | Toggle, gated by KYC + sub + location permission, location streaming | shipped |
| 6 | **Marketplace discovery** | Realtime nearby requests via geohash6 broadcast, request cards, distance/ETA | shipped |
| 7 | **Bidding** | Composer (type/slider/chips), suggested fare, peak/night multipliers, submit/withdraw | shipped |
| 8 | **Active trip lifecycle** | assigned → en_route → arrived → in_progress → completed/cancelled | shipped (geofence guard disabled — DRV-055) |
| 9 | **Realtime comms** | In-app chat, masked voice call, quick-reply templates | partial (chat local; real chat + masked call deferred) |
| 10 | **Earnings & wallet** | Wallet, ledger, today/week/month/year analytics, acceptance/cancellation metrics | shipped |
| 11 | **Payouts** | Paystack transfers, min ₦5k, max ₦500k/day, payout history | shipped (real Paystack deferred) |
| 12 | **Pricing strategy** | Base fare, per-km, peak/night multipliers, max pickup distance, preferred trip length | shipped |
| 13 | **Driver analytics** | Earnings chart, coach tips (rule-based), demand heatmap | shipped |
| 14 | **Profile, documents, reviews** | Profile hub, vehicle details, reviews from passenger ratings | shipped |
| 15 | **Safety** | SOS hold-to-activate, trusted contacts, trip sharing link | partial (sharing link deferred — DRV-082) |
| 16 | **Support** | Static help topics, support email | shipped (chat support deferred) |
| 17 | **Notifications** | Inbox + push (FCM), settings | shipped (FCM partial — DRV-006) |
| 18 | **Settings & account** | Theme/appearance, sign out, delete account (NDPR), trusted contacts | shipped |
| 19 | **Edge states & failure recovery** | No-requests, offline, sub-expired, rider-cancelled, network-poor mode | shipped |
| 20 | **Security & compliance** | RLS, PII encryption, audit logs, NDPR | partial (audit logs in admin; encryption per PLAT-014) |

Detailed specifications per feature follow in §6.

---

## 6. Feature Specifications

Each feature below has: **purpose · user flow · functional requirements · edge cases · ticket references · status**.

### 6.1 Onboarding & Auth

**Purpose.** Get a new driver from the app-store download to a verified, ready-to-bid state in as few steps as possible. Reauthenticate returning drivers without friction.

**User flow.**
1. Driver opens the app → splash → brand reveal + permission ask (location)
2. Splash hands off to `/welcome` (first launch) or `/home` (returning, signed in)
3. From welcome → "Sign up" or "Sign in"
4. Sign up: name + email + phone + password + (optional) referral code → "Continue" → `/otp`
5. OTP: enter 6-digit code → on success route to `/paywall` (new account) or `/home` (existing)
6. Sign in: phone + password → `/otp` → on success route to `/home`

**Functional requirements.**
- **Phone OTP** via Termii (v1.1; v1 uses a dev OTP `123456` per `drivio_context.md`).
- **Email is required.** Field labelled "Email" (no longer "optional").
- **Password** rules: minimum 8 chars; no other rules in v1.
- **Referral code** optional; validated server-side at signup; stamps `profiles.referred_by`.
- **PhoneNumberInput widget** with 🇳🇬 +234 prefix; strips non-digits; normalizes to E.164.
- **OTP widget** uses invisible overlay TextField (per durable rule — do not replace with per-cell focus-node array).
- **Resend countdown** 24s default; cools 1s/tick.
- **Auto-fill from SMS** on Android where supported; iOS via the SMS OTP autofill suggestion.
- **Sign-in regressions are loud.** The bootstrap controller logs the chosen route (welcome / completeProfile / home) and the cause. Diagnostic logs left in deliberately.

**Edge cases.**
- **OTP expired or wrong.** Show "Wrong code. Try again." Re-allow up to 5 attempts; after that, force resend.
- **Existing phone tries to sign up.** Detect at OTP success → switch to sign-in flow.
- **Cold-start `auth.uid()` race.** RPCs called before JWT is restored fail; bootstrap retry with backoff. See `driver_context.md` §11.
- **Email confirmation enabled in Supabase.** Surface `AuthSetupRequired` with a precise message; do not silently send to welcome.
- **Cross-app schema check (driver/passenger split).** `BootstrapController.resolve` should verify a `drivers` row exists, not just a `profiles` row. (Known gap; will tighten when it becomes a real problem.)

**Tickets.** DRV-010, DRV-011, DRV-012, DRV-013, DRV-014, DRV-015.

**Status.** Shipped with dev OTP stub. Real Termii SMS-OTP is PLAT-009 / DRV-010 final pass.

### 6.2 KYC & Verification

**Purpose.** Bring a new driver from "I have an account" to "I can bid" by collecting and verifying the documents the law (and the marketplace) require.

**User flow.**
1. After paywall (or directly on next launch), driver enters the KYC orchestrator
2. Step 1 — BVN + NIN: enter, verify via Dojah; if pass, advance
3. Step 2 — Selfie + liveness: take a live photo; if pass, advance
4. Step 3 — Document upload, in order:
   - Drivers' licence (front)
   - Vehicle registration
   - Insurance certificate
   - Road worthiness
   - LASRRA
   - Inspection report
5. Each document upload triggers admin review (queue in admin dashboard)
6. Driver returned to `/home`; KYC banner shows "Pending review" until verified
7. When admin approves → `drivers.kyc_status = 'approved'` → trial auto-created (DRV-027) → online toggle unlocks

**Functional requirements.**
- **BVN / NIN** verified via Dojah (PLAT-013). v1 stub: accept any 11-digit input, route to "Pending review."
- **Selfie + liveness** via Dojah liveness API. v1 stub: capture a photo, accept any photo.
- **Document upload** stores files in Supabase Storage `kyc-private` bucket. RLS so only the owner (and admins) can read.
- **Documents are required, in order.** No skipping. The orchestrator state machine prevents jumping ahead.
- **Re-upload flow** for rejected docs. Reason copy from `documents.rejection_reason`. Route `/documents/reupload`.
- **`document_kind_t` enum** values: `drivers_licence, vehicle_reg, insurance, road_worthiness, lasrra, inspection_report, profile_selfie`. No `background_check` value; the profile UI's "Background check" row maps to `road_worthiness` (Q1 in `drivio_context.md`).
- **KYC status flow**: `not_started → in_progress → pending_review → approved | rejected`.
- **On `approved`**: trigger `auto-create-trial` for the driver (DRV-027). One-time per driver — flag in `drivers.has_used_trial`.

**Edge cases.**
- **BVN/NIN provider downtime.** Show "Verification service is temporarily down. We'll review manually within 24h."
- **Document rejected by admin.** Show a banner on `/home` with the rejection reason and a CTA to re-upload.
- **Driver tries to bid before KYC approved.** Online toggle is disabled; tapping it shows `KycGateSheet`.
- **Document expires (e.g., road worthiness past `expires_on`).** Surface a banner 30 days before expiry; hard-block bidding when expired.

**Tickets.** DRV-016, DRV-017, DRV-018, DRV-019, DRV-020, DRV-021.

**Status.** Shipped with stub verification. Real Dojah integration is PLAT-013.

### 6.3 Vehicle Management

**Purpose.** Allow drivers to register, edit, and switch between vehicles. The marketplace needs an active, approved vehicle per ride request.

**User flow.**
1. On profile → Vehicle row → `/profile/vehicle`
2. From there: "Add a vehicle" → `/add-vehicle`
3. Fill make, model, year, colour, plate, VIN, seats, category, vehicle photos (optional v1)
4. Upload vehicle registration, insurance, road worthiness, LASRRA, inspection (re-uses KYC documents flow if not done)
5. On save: vehicle status = `pending`; admin reviews and approves or rejects
6. Once approved, vehicle is the driver's active vehicle (unless they already have one)
7. To switch active vehicle → `/vehicle/change`

**Functional requirements.**
- **`vehicles` table:** `id, driver_id, make, model, year, colour, plate, vin, seats, category, status, deleted_at`.
- **`vehicle_status_t` enum:** `pending, active, suspended, retired`.
- **Active-vehicle look-up** must filter `status='active' AND deleted_at IS NULL`. Use the most-recent active row.
- **One active vehicle per driver at a time.** Switching deactivates the previous active row (status → `retired` or just removes from `is_active` via `is_active=false` flag).
- **`vehicles.colour` is nullable.** Handle the null case in any "Vehicle: <colour>" display.
- **Plate validation:** loose v1 (any non-empty string); add regex in v1.5.
- **Vehicle category:** v1 = `economy` only. Future categories (`comfort`, `xl`, `airport`) deferred but the column exists.
- **Vehicle photos:** optional v1; max 4 photos; stored in Storage `vehicle-photos` bucket.

**Edge cases.**
- **Driver tries to go online without an approved vehicle.** Online toggle disabled; tap shows `VehicleGateSheet`.
- **Vehicle photos missing.** Allow proceed; reminder banner in profile.
- **Plate duplicates another driver's vehicle.** Server returns `409 plate_already_registered`; surface as a friendly error.
- **Vehicle data oddity** (e.g., model spelled "Corrolla" — see test data note in `drivio_context.md`). Display reflects DB faithfully; fix at the source if needed.

**Tickets.** DRV-022, DRV-023, DRV-024, DRV-025.

**Status.** Shipped.

### 6.4 Subscription & Trial

**Purpose.** Run the entire driver-app revenue model. New drivers get 90 days free; existing drivers pick from **three subscription tiers** — Daily ₦2,500, Weekly ₦15,000, Monthly ₦50,000 — or are hard-blocked at expiry. Active trips always complete.

**The three tiers.**

| Tier | Price | Auto-renews | Designed for |
|---|---|---|---|
| **Daily** | ₦2,500 | 24h after purchase | Occasional drivers, weekend warriors, drivers testing the platform |
| **Weekly** | ₦15,000 | 168h (7 days) after purchase | The default for most active drivers |
| **Monthly** | ₦50,000 | 720h (30 days) after purchase | Full-time drivers; cheapest per-day rate (~₦1,667/day) |

Renewals are **anniversary-based**, not calendar-aligned. A driver who pays at 23:00 Monday renews at 23:00 Tuesday (Daily) / 23:00 next Monday (Weekly) / 23:00 thirty days later (Monthly). This means there's no penalty for late-day signups and no fractional pricing math.

**User flow.**

**Trial start (new driver):**
1. After KYC approved → trial auto-created (subscription row with `status='trialing'`, `trial_ends_at = now() + 90 days`, `plan_id = NULL` because no tier chosen yet)
2. Driver can immediately bid; trial is invisible during normal use
3. Banner appears T-7 days from trial end: "Trial ends in 7 days. Pick a plan to keep driving."
4. T-3 / T-1 banners escalate
5. At trial end: driver must pick a tier (paywall blocks bidding); if no tier chosen, status → `expired`

**Tier selection (at trial end OR re-subscription):**
1. Paywall opens with 3-tier comparison: Daily / Weekly / Monthly side-by-side
2. **Personalized recommendation** based on driver's trial-period bid activity:
   - Active 90%+ of days during trial → Monthly recommended (with savings callout vs Weekly)
   - Active 60-89% of days → Weekly recommended (with daily-vs-weekly math)
   - Active <60% of days → Daily recommended (with "pay only on days you drive" framing)
3. Driver picks; payment method enters; first charge runs immediately
4. On success: subscription row updates with `plan_id`, `status='active'`, `current_period_start=now()`, `current_period_end=now() + interval`

**Tier switching (mid-subscription):**
1. Driver opens `/subscription/manage` → "Change plan"
2. Selects new tier; modal shows: "Your <current tier> stays active until <expiry>. From then on, you'll pay <new price> per <new cadence>."
3. Confirm → server queues the switch as `subscriptions.pending_plan_id`
4. At next renewal: the renewal charge uses the new plan; `plan_id` updates; `pending_plan_id` clears
5. No mid-cycle pro-ration; no refunds on the current cycle
6. Driver can cancel a pending switch anytime before renewal

**Paid subscription (existing driver):**
1. Each renewal charge runs at the anniversary (24h/7d/30d after the previous successful charge)
2. Paystack subscription created via edge function `create-subscription`; uses the Paystack plan matching the chosen tier
3. Webhook confirms each charge
4. Failed charge → status `past_due`; grace period differs by tier (Daily: 1h, Weekly: 12h, Monthly: 3 days — see Functional Requirements); banner urges payment update
5. Successful retry → `active`; grace expiry without successful retry → `expired`

**At expiry (hard block):**
1. `subscriptions.status = 'expired'` → `is_driver_active()` returns false
2. Online toggle auto-flips off (if driver was online and not in a trip)
3. Marketplace channel unsubscribes
4. Server gates (`go-online`, `submit-bid`) reject
5. Edge state `/edge/subscription-expired` shown when driver opens the app
6. To resume: driver must pick a tier and pay; can use referral / re-subscribe in `/subscription/manage`

**Functional requirements.**
- **`subscription_plans` table:** `id, code, name, price_minor, currency, interval, interval_seconds`. v1 has three plans:
  - `drivio_pro_daily` — ₦2,500 / NGN / daily / 86400 seconds
  - `drivio_pro_weekly` — ₦15,000 / NGN / weekly / 604800 seconds
  - `drivio_pro_monthly` — ₦50,000 / NGN / monthly / 2592000 seconds (30 days)
- **`subscriptions` table:** `id, driver_id, plan_id, pending_plan_id, status, trial_ends_at, current_period_start, current_period_end, paystack_subscription_code, paystack_plan_code`. The `pending_plan_id` activates at the next renewal.
- **`subscription_status_t` enum:** `trialing, active, past_due, cancelled, expired`.
- **`is_driver_active(driver_id)` SECURITY DEFINER:** returns true for `trialing/active/past_due`; false for `expired/cancelled`. Single source of truth for the gate.
- **Sacred-trip rule:** if a driver is in a trip when expiry fires, the trip completes. Auto-flip-offline happens on `onTripCompleted` if `subHardBlocked`.
- **Trial is one-time per driver.** `drivers.has_used_trial` flag; never re-grantable.
- **Anniversary renewal:** server computes `current_period_end = current_period_start + interval_seconds`. Cron sweeper at 1-minute granularity for Daily tier; 5-minute granularity for Weekly/Monthly.
- **Tier-aware grace period:**
  - Daily: 1 hour grace after failed charge → `expired`
  - Weekly: 12 hours grace
  - Monthly: 3 days grace (preserves the Paystack-native dunning behaviour for Monthly)
- **Paystack integration:** three separate Paystack Plans (one per tier). On tier switch, the existing Paystack subscription is cancelled and a new one is created for the new plan, but only at the anniversary moment. Webhook reconciles.
- **`SubscriptionStatus.unlocksMarketplace`** returns true for `trialing/active/past_due`; `isHardBlocked` returns true for `expired/cancelled`.
- **Drive shell auto-flips offline** when `home.isOnline && subHardBlocked && !shell.isTripLike`. Marketplace channel is also `.stop()`-ed in the same hand-off.

**Edge cases.**
- **Webhook arrives before client poll.** Realtime postgres-changes on `subscriptions` triggers UI flip; poll exits.
- **Webhook lag > 60s.** PLAT-014 alerts ops; manual reconciliation.
- **Paystack outage.** Pause renewal dunning; don't auto-deactivate drivers because of our PSP. Flutterwave fallback for new activations only.
- **Driver cancels subscription mid-period.** Status → `cancelled` but `current_period_end` honoured — they keep access until that date. No refund of the current cycle.
- **Driver tries to bid while past-due in grace.** Allowed (`past_due` returns true from `is_driver_active`). Banner reminds payment is past due.
- **Driver on Daily tier with phone off when renewal fires.** Renewal charge runs; if it fails, 1h grace; if app stays closed past grace, driver opens to find `/edge/subscription-expired`.
- **Driver queues a tier switch then cancels before renewal.** `pending_plan_id` cleared; renewal proceeds on current plan.
- **Driver queues a tier switch and then queues another before the first takes effect.** The second overwrites the first.
- **Driver upgrades from Daily to Monthly mid-cycle.** Current Daily cycle completes; first Monthly charge runs at the next anniversary (24h after the last Daily charge), then 30-day cycles begin from there.

**Tickets.** DRV-026 (plan catalog — now 3 plans), DRV-027 (90-day trial), DRV-028 (Paystack activation per tier), DRV-029 (auto-renewal with anniversary scheduler), DRV-030 (receipts per tier), DRV-031 (realtime sync), DRV-032 (hard-block gate), DRV-033 (pre-expiry warnings), DRV-034 (NEW — tier-switching with pending_plan_id), DRV-035 (NEW — personalized tier recommendation engine).

**Status.** Subscription gate shipped with dev-mode Paystack stub at single-tier ₦5,000/mo. Migration to 3-tier model is the next pass:
1. Apply Supabase migration (new plans, pending_plan_id column, helper functions)
2. Update paywall UI for 3-tier selection with recommendation
3. Update Subscription Manage page for current tier display + change-tier flow
4. Wire Paystack with three Plans
5. Update edge functions for tier-aware logic
6. Comms updates (push templates per tier renewal)

### 6.5 Online / Offline

**Purpose.** The most-used control in the app. Lets the driver join or leave the marketplace.

**User flow.**
1. Home page top-overlay shows the `OnlineToggle` widget (state: offline / online / on-trip)
2. Tap to go online → server check via `go-online` edge function
3. If gates pass: state flips, location streaming starts, marketplace channel subscribes
4. If any gate fails: appropriate gate sheet (`KycGateSheet`, `SubscriptionGateSheet`, `LocationGateSheet`, `VehicleGateSheet`)
5. To go offline: tap toggle → confirm if in a trip-like state; otherwise immediate flip

**Functional requirements.**
- **Gates checked at online toggle:**
  1. `auth.uid()` is set
  2. KYC status is `approved`
  3. An approved vehicle exists
  4. Subscription is in `trialing | active | past_due`
  5. Location permission is `granted`
  6. Location services are enabled
- **Each failure surfaces the matching gate sheet.** Sheet copy adapts to the failure mode.
- **Server gate (`go-online` edge function)** re-checks subscription status and writes a `driver_presence` row.
- **Location streaming starts on success.** 5s while stationary, 1s while moving. Per `driver_context.md` §6.3.
- **Marketplace channel subscribes** to current geohash6 + 8 neighbours.
- **Going offline** stops location streaming, unsubscribes marketplace, sets `driver_presence.online = false`.
- **Auto-flip-offline conditions:** subscription hard block fires while idle, OS kills location service, GPS lost >30s, app backgrounded for OS-throttled period without foreground service.
- **`OnlineToggle` widget** is the only thing that calls `HomeController.toggleOnline`. No fanout — single source.

**Edge cases.**
- **Driver tries to go online but is mid-trip from a previous session.** App detects on cold start (resume the active trip) and skips the toggle.
- **Location permission revoked while online.** `LocationPermissionService` detects → flip offline → show `LocationGateSheet`.
- **GPS lost mid-trip.** Banner "GPS signal weak"; trip continues; at 30s auto-flip-offline.
- **Network drop while online.** Realtime channel state goes `DISCONNECTED`; banner; on reconnect, resubscribe and reconcile via REST snapshot.

**Tickets.** DRV-034, DRV-035, DRV-036 (location FGS — iOS background modes + Android foreground service), DRV-037, DRV-038, DRV-039.

**Status.** Shipped. iOS background modes need polish (DRV-036 still has work).

### 6.6 Marketplace Discovery

**Purpose.** Surface every relevant ride request from passengers within ~500ms of creation so the driver can decide whether to bid.

**User flow.**
1. Driver is online (state `online`) → home page shows the marketplace feed
2. A passenger creates a request in the driver's zone → request card slides into the feed within ~500ms
3. Driver reviews: pickup/dropoff, distance, ETA, passenger rating, expiry countdown
4. Driver taps the card → `/ride-request` → bid composer
5. Driver bids OR taps "Decline" OR ignores (the card expires after 60s)

**Functional requirements.**
- **Marketplace channel:** Supabase Realtime broadcast keyed `marketplace:zone:<geohash6>`. Driver subscribes to current cell + 8 neighbours.
- **Cell re-subscription** when driver crosses >50% of cell width (PLAT-004).
- **Request card data:** `id, pickup_address, dropoff_address, expected_distance_m, expected_duration_s, expires_at, passenger_rating_avg`.
- **Sort order:** newest first. (Future: per-driver preference for "closest first" or "highest ETA" sorting.)
- **Distance + ETA computation** is server-provided; client trusts (`expected_distance_m`, `expected_duration_s`).
- **Multi-request handling:** multiple cards can be in the feed simultaneously; tapping one opens its bid composer.
- **Reconnect + backfill:** on resume, call `list-open-requests-near` REST endpoint, merge results with cached requests by `id`.

**Edge cases.**
- **Card lands after request expired** (race during reconnect): client filters by `expires_at > now`, hides expired cards.
- **Driver outside service area (Lagos polygon):** `go-online` rejects with `outside_service_area`; surface "Drivio isn't live in your area yet."
- **No requests for >5 min:** show empty-state copy "No requests yet — keep an eye out." (Edge state `/edge/no-requests` shown only if the driver pulls-to-refresh and confirms).
- **Driver filters (max pickup distance, preferred trip length):** apply via `visibleRequestsProvider` (derived); see §6.11 Pricing strategy.

**Tickets.** DRV-040, DRV-041, DRV-042, DRV-043, DRV-044, DRV-045.

**Status.** Shipped.

### 6.7 Bidding

**Purpose.** The brand's hero feature. The driver sets a price for a specific ride request.

**User flow.**
1. From the marketplace feed, driver taps a request card → `/ride-request`
2. Map at top shows pickup + dropoff; auction window countdown in the eyebrow
3. Bid composer below: shows pickup/dropoff addresses, distance, ETA, **suggested fare** (greyed if not custom)
4. Driver edits the price using one of three variants:
   - **Type variant** (default): keyboard-editable hero number with `+500 / +100 / −100 / −500` quick-adjusters
   - **Slider variant**: range slider from 60–160% of suggested
   - **Chips variant**: four chips at −15% / suggested / +15% / +30%
5. "Submit bid" → `submit-bid` edge function → optimistic state flip → on success, return to home; on failure, surface error
6. Bid status updates via `public:ride_bids:driver_id=eq.<self>` postgres-changes channel
7. On `accepted`: route to `/active-trip` (passenger picked you); on `rejected/expired`: edge state or back to home

**Functional requirements.**
- **Suggested fare** computed client-side via `PricingProfile.suggestFor(distanceM, requestedAt)`:
  - Base: `base_minor + per_km_minor × (distance_m / 1000)`
  - Peak multiplier: applied if `peak_enabled && hour in peak window (06–08:59, 17–19:59 WAT)`
  - Night multiplier: applied if `night_enabled && hour in night window (22–04:59 WAT)`
  - Rounded to nearest ₦100 via `PricingProfile.roundToNearestNaira100`
- **Suggested pill** ("PEAK · 1.5×" amber or "NIGHT · 1.2×" blue) appears next to "Suggested ₦X" when active.
- **"You keep" line** = bid price exactly. No `* 0.96`. (Durable rule — see Principle §3.2.)
- **Submit bid** server validates:
  - Driver is active (`is_driver_active(auth.uid())`)
  - Request is still `open`
  - Driver hasn't already bid this request (`UNIQUE (ride_request_id, driver_id)`)
  - Driver isn't currently in another trip
  - Price is within [₦100, ₦100,000] (engineering safety rails; product to confirm cap)
- **Withdraw bid:** allowed while bid is `pending`. After acceptance, returns 409.
- **One bid per driver per request.** UNIQUE constraint enforced.
- **Win/lose handling:**
  - `accepted` → optimistic route to `/active-trip`; `TripController.hydrateActive`
  - `rejected` (passenger picked another driver) → edge state "Another driver was chosen" (DRV-051) → back to home
  - `expired` (request expired with no winner) → silent removal from feed
  - `withdrawn` (driver withdrew) → silent removal

**Edge cases.**
- **Bid lands after `expires_at`:** server returns 409 `request_expired`; UI removes card from feed.
- **Bid lands after another driver was accepted:** server returns 409 `request_no_longer_open`; same handling.
- **Driver tries to bid while in another trip:** `submit-bid` rejects with `driver_in_trip`; surface message.
- **Driver bid amount < ₦100 or > ₦100,000:** client-side validation; if bypassed, server rejects.
- **Network drop mid-submit:** mutation queue retries; idempotency key prevents double-bids.

**Tickets.** DRV-046 (bid composer), DRV-047 (submit-bid edge function), DRV-048 (lifecycle updates), DRV-049 (withdraw/cancel), DRV-050 (anti-spam limits), DRV-051 (win/lose result handling).

**Status.** Shipped.

### 6.8 Active Trip Lifecycle

**Purpose.** Carry the driver from "I just won a bid" through "the trip is complete and I got paid."

**State machine.**

```
assigned → en_route → arrived → in_progress → completed
                                              → cancelled
```

**User flow per state.**

**assigned (just won):**
- Optimistic state from `accept-bid` event
- Bottom sheet shows passenger name, vehicle they expect (your car), pickup address, locked fare
- "I'm on my way" → state advance to `en_route` + navigation hand-off to Google/Apple Maps

**en_route (driving to pickup):**
- Map shows live driver position (your phone GPS) + pickup pin
- Location publishing: 1Hz broadcast on `trip:<id>:driver_location`; 5s batch persist to `trip_locations`
- ETA recompute every 30s (deferred — currently haversine; future: directions API)
- Bottom sheet: passenger name, "I've arrived" CTA
- Tap "I've arrived" → state advance to `arrived`

**arrived (waiting for passenger):**
- Geofence check disabled in v1 (TODO DRV-055); driver can tap "I've arrived" anywhere
- Sheet shows: passenger name, "Start trip" CTA, "Call passenger" / "Chat" affordances
- 5-min auto-cancel timer if passenger doesn't board (driver-initiated) — future v1.1
- Driver taps "Start trip" → state advance to `in_progress`

**in_progress (driving with passenger):**
- Map shows live driver position + dropoff pin + route polyline
- "End trip" CTA on sheet
- Driver taps "End trip" → state advance to `completed`

**completed (trip done):**
- Driver-side: "Earned ₦X" summary (trip credit lands in wallet via `complete-trip`)
- Optional: rate the passenger (1–5 stars + optional tags)
- "Done" → back to home (with auto-flip-offline if subscription hard-blocked)

**cancelled (driver or passenger cancellation):**
- Driver-side: "Trip cancelled" summary
- If passenger cancelled mid-en-route, driver receives compensation from the pool (PLAT-018 deferred)
- "Done" → back to home

**Functional requirements.**
- **`trips` table:** `id, ride_request_id, bid_id, driver_id, vehicle_id, passenger_id, fare_minor, currency, state, started_at, ended_at, cancellation_reason, actual_distance_m, actual_duration_s`.
- **`trip_state_t` enum:** `assigned, en_route, arrived, in_progress, completed, cancelled`.
- **State transitions are server-side.** Edge functions: `start-trip`, `arrive`, `begin-trip`, `complete-trip`, `cancel-trip`.
- **Location publishing:** 1Hz broadcast on `trip:<id>:driver_location`; 5s batch persist (server worker handles persist).
- **Navigation hand-off** to Google Maps / Apple Maps via `url_launcher` — no embedded turn-by-turn in v1.
- **Locked fare** equals the bid amount; immutable from acceptance forward.
- **Trip credit on completion** flows to `wallet_ledger` with kind `trip_credit` and amount = bid (no commission deduction).
- **Realtime updates** via `public:trips:driver_id=eq.<self>` postgres-changes channel.
- **Driver-initiated cancellation:** reason required (passenger no-show, vehicle issue, safety concern, other). Threshold-based: >X cancellations in Y trips triggers ops review (admin Epic 18.4).

**Edge cases.**
- **App crash mid-trip.** Sentry captures; on relaunch, `BootstrapController` reads `trips.state` and resumes; user lands on `/active-trip`.
- **OS kills foreground service.** Heartbeat misses; PLAT-011 marks driver offline; passenger app shows "lost connection"; driver app on relaunch sees `trips.state = in_progress` and resumes.
- **GPS lost mid-trip.** Banner "Lost GPS"; passenger sees "Driver signal weak"; auto-flip-offline at 30s; trip continues on the server.
- **Driver loses network mid-trip.** Mutation queue holds outgoing events; trip state on server unchanged; passenger sees stale ETA.
- **Passenger cancels mid-en-route.** Driver gets compensation from pool (PLAT-018 deferred); driver returned to home.
- **Trip-in-progress when subscription expires.** Trip completes. Auto-flip-offline at `onTripCompleted`. Sacred rule (Principle §3.3).

**Tickets.** DRV-052 (state machine), DRV-053 (navigation hand-off), DRV-054 (location publish), DRV-055 (arrived check-in via geofence — currently disabled), DRV-056 (start trip), DRV-057 (complete trip), DRV-058 (driver-initiated cancellation), DRV-059 (passenger-cancelled handling), DRV-060 (post-trip rating).

**Status.** Shipped except geofence guard (DRV-055), which was explicitly disabled per user request.

### 6.9 Realtime Communications (Chat & Call)

**Purpose.** Let driver and passenger coordinate mid-trip without leaving the app.

**User flow.**

**Chat:**
1. From `/active-trip` sheet, tap "Message" → `/chat`
2. Chat scoped to the active trip; messages persist in `messages` table
3. Quick-reply chips at top: "I'm here", "I'm 2 minutes away", "Where exactly are you?", "Could you come outside?"
4. Bubble list scrollable; composer at bottom

**Call:**
1. From `/active-trip` sheet, tap "Call" → `/call`
2. v1: stub (the existing prototype call state, decoratively)
3. v1.1: masked voice call via Africa's Talking or Twilio (DRV-062 deferred)

**Functional requirements.**

**Chat (v1 currently local; server-backed in v1.1):**
- **`messages` table:** `id, trip_id, sender_user_id, kind (text|template), body, created_at`.
- **Realtime channel:** `public:messages:trip_id=eq.<active_trip_id>` postgres-changes.
- **Quick-reply templates:** seeded constants in app code; reduce keyboard friction on the road.
- **Append-only:** no edit, no delete in v1.
- **Auto-archive** chat 24h after trip ends.

**Call (v1.1):**
- **Masked voice call:** server proxies; neither party sees the other's real phone number.
- **Provider:** Africa's Talking primary, Twilio fallback.
- **Call records:** logged to `safety_events` for ops review.

**Edge cases.**
- **Chat message fails to send** (network drop): queued via mutation queue; retries on reconnect.
- **Trip ends mid-conversation.** Chat remains accessible for 24h via `/chat?trip_id=`. After 24h, archived (read-only).
- **Driver tries to chat post-trip.** Allowed within 24h; otherwise routed to support.

**Tickets.** DRV-061 (in-app chat), DRV-062 (masked voice call), DRV-063 (quick-reply templates).

**Status.** Chat is local with canned replies in v1 prototype state; server-backed `messages` table is DRV-061's final pass. Masked call is fully deferred (DRV-062).

### 6.10 Earnings & Wallet

**Purpose.** Let drivers see exactly what they've earned, when, and from which trips — without commission math.

**Surfaces.**
- **Home page**: today's earnings tile (`get_my_dashboard_today`)
- **Earnings tab**: full chart + period segmenter (week/month/year) + metrics + coach tips + demand heatmap toggle
- **Wallet (within `/profile/payment-methods`)**: balance, ledger history, payout history

**User flow.**
1. Driver opens `/earnings` → today/week/month/year segmenter at top
2. Chart shows earnings over chosen period
3. Below chart: metric tiles (acceptance rate, cancellation rate, average fare, trips count)
4. Below metrics: coach tips card (rotating, dismissable)
5. Below coach tips: demand heatmap toggle (when on, shows heatmap on `/home` map)

**Functional requirements.**

**Wallet (`wallets` + `wallet_ledger`):**
- **`wallets`:** `user_id PK, balance_minor, currency, updated_at, owner_kind (driver|passenger)`. Driver app reads via `driver_wallets` view.
- **`wallet_ledger`:** append-only. Kinds: `trip_credit, payout_debit, refund, adjustment, subscription_debit, topup_credit, trip_hold, trip_debit, cancellation_refund, tip_debit, referral_credit`.
- **Balance:** sum of ledger entries (denormalised on `wallets.balance_minor` for speed).
- **Currency:** NGN only in v1; column exists for future markets.

**Earnings analytics:**
- **`get_my_dashboard_today()` RPC:** today's earnings, trip count, online seconds, rating. WAT-anchored day boundary.
- **`get_my_earnings_summary(p_window_days)`, `get_my_daily_earnings(p_days)`, `get_my_monthly_earnings(p_months)` RPCs:** drive the chart.
- **`get_my_acceptance_metrics(p_days)` RPC:** acceptance + cancellation rates.
- **`EarningsPeriod` enum:** `week | month | year`. Controls chart axis labels, RPC choice, and metric calculation window.
- **Smart axis labels:** week = day initials, month = day-of-month every 5 days, year = month initials.
- **Tile UX:** distinguish "first load pending" (`—`) from "loaded and genuinely zero" (`₦0`). Inline error banner with "TAP TO RETRY" when load fails.

**Edge cases.**
- **Cold-start race** (RPC fires before JWT restored): backoff retry 2s/5s/15s + listen to `Supabase.auth.onAuthStateChange`.
- **Trip credit pending vs. settled:** v1 credits immediately on `complete-trip`. v1.5 may add holding period.
- **`actual_duration_s` is null on trips** (trip state machine doesn't populate it). Online seconds use `coalesce(actual_duration_s, EXTRACT(EPOCH FROM (ended_at - started_at)))`.

**Tickets.** DRV-064 (trip earnings ledger), DRV-065 (wallet balance), DRV-066 (payout request), DRV-067 (payout history), DRV-068 (daily/weekly summary).

**Status.** Shipped.

### 6.11 Pricing Strategy

**Purpose.** Let drivers configure their pricing defaults so they don't have to set a price from scratch on every bid.

**User flow.**
1. Driver opens `/pricing` tab
2. Steppers for **base fare** (default ₦600) and **per-km** (default ₦200)
3. Toggle: **peak hours** (default off); slider for multiplier (1.1×–2.0×, default 1.5×)
4. Toggle: **night shift** (default off); slider for multiplier (1.0×–1.5×, default 1.2×)
5. Trip preferences row: **Max pickup distance** (`/pricing/pickup-distance` — picker) and **Preferred trip length** (`/pricing/preferred-trip-length`)
6. Live preview at the bottom: "Example: 8 km trip would suggest ₦2,200" — recomputes as the driver changes inputs
7. Save (debounced 500ms — no explicit save button)

**Functional requirements.**
- **`driver_pricing_profile` table:** `driver_id PK, base_minor, per_km_minor, peak_multiplier, peak_enabled, night_multiplier, night_enabled, preferences jsonb`.
- **`get_or_create_my_pricing_profile()` RPC:** lazy-creates on first call.
- **Peak window:** 06:00–08:59 + 17:00–19:59 WAT (constants in app; tunable later via admin config).
- **Night window:** 22:00–04:59 WAT.
- **Suggested fare formula:** `(base + per_km × distance_km)` × (peak_multiplier if peak_enabled and in peak window) × (night_multiplier if night_enabled and in night window). Rounded to nearest ₦100.
- **Preferences jsonb:**
  - `max_pickup_km` (default null = no filter)
  - `trip_length` (`short | medium | long | any` — default `any`)
- **`visibleRequestsProvider`:** derived from `marketplaceControllerProvider + pricingControllerProvider.profile`. Filters requests by max pickup distance and trip length preference. Used by request feed + drive shell idle-mode markers — keeps map and feed in lockstep.
- **PickupDistancePage + PreferredTripLengthPage** use the controller (live data, debounced save, no separate "Save" button).
- **`PricingProfile.suggestFor(distanceM, requestedAt)`:** static method shared between controller and pricing page preview — so they can never drift.
- **`PricingProfile.roundToNearestNaira100`:** the single rounding helper used everywhere.

**Edge cases.**
- **Driver sets max_pickup_km = 0:** treated as null (no filter). Don't filter all requests away.
- **Driver toggles peak on outside peak window:** preview shows the formula without the multiplier (it's enabled-but-not-applicable now).
- **Trip length filter and very short/long requests:** "Short" = <5km, "Medium" = 5–15km, "Long" = >15km. (Adjustable.)

**Tickets.** DRV-069, DRV-070, DRV-071.

**Status.** Shipped.

### 6.12 Driver Analytics & Insights

**Purpose.** Help drivers improve their earnings without algorithmic paternalism — surface patterns, not prescriptions.

**Surfaces.**
- **Earnings chart** with period segmenter (week/month/year)
- **Acceptance / cancellation tiles** with delta vs. previous period
- **Coach tips** card (rule-based, 7 hand-curated rules)
- **Demand heatmap** toggle on the home map

**User flow.**
1. From `/earnings`, see the chart + metrics
2. Below metrics: 1–3 coach tip cards (rule-fired). Tap dismisses; tap CTA navigates to relevant screen.
3. Tap "Demand heatmap" toggle (on home map's idle mode) → polygon overlay shows demand by geohash6 cell.

**Functional requirements.**

**Coach tips (DRV-074):**
- **`get_my_coach_tips(p_limit)` RPC:** hand-curated 7-rule set.
- **Rules (v1):**
  - Friday peak (busiest day)
  - Peak-off (you missed peak hours)
  - Low win rate
  - High cancel
  - Rating drop
  - Strong day
  - Slow week
- **Tip payload:** `code, severity (info|warning|win), emoji, title, body, cta_label, cta_route`.
- **Session-level dismiss:** dismissed tips don't reappear until next session.
- **CTA route:** deep links to `/pricing`, `/profile/reviews`, etc. v1.5: more CTAs as more rules ship.

**Demand heatmap (DRV-075):**
- **`get_demand_heatmap(p_minutes, p_max_cells)` RPC:** aggregates `ride_requests.pickup_geohash6` over trailing window. Returns `cell_id, center_lat, center_lng, cell_lat_span, cell_lng_span, request_count`.
- **Visualisation:** polygon overlay on `LiveMap` — each geohash6 cell as a coloured rectangle with 5-step intensity ramp (teal → amber → orange → red), opacity 0.18–0.6.
- **Auto-refresh** every 5 min while visible.
- **Toggle button** on idle-mode top overlay (fire icon, theme-tinted amber when active).

**Edge cases.**
- **No tips fire** (driver has no patterns yet): show a single "Just getting started — check back tomorrow" tip.
- **Tip CTA route deprecated.** Coach tip handler silently no-ops if route doesn't exist.
- **Heatmap data sparse** (low request volume): show a single faint cell or empty state.

**Tickets.** DRV-072 (earnings chart), DRV-073 (acceptance/cancellation metrics), DRV-074 (coach tips), DRV-075 (demand heatmap).

**Status.** Shipped (rule-based v1; ML upgrade is post-launch).

### 6.13 Payouts

**Purpose.** Move the driver's wallet balance to their bank.

**User flow.**
1. From `/profile/payment-methods` → "Manage payment"
2. First time: bottom sheet to add bank account (bank name, account number 10-digit NUBAN, account name)
3. Once added: payout account stored in `driver_payout_accounts`; account number masked in UI
4. From wallet balance card: "Withdraw" → enter amount (min ₦5,000, max ₦500,000/day) → confirm → submitted
5. Server queues `payout_request` → Paystack transfer initiated → status `pending`
6. On success: `wallet_ledger` debits via `payout_debit`; payout row → `settled`
7. Driver gets push: "Payout settled — ₦X is in your bank"

**Functional requirements.**
- **`driver_payout_accounts` table:** `driver_id PK, bank_name, account_number_last4, account_name, paystack_recipient_code, created_at, updated_at`. **`bank_code` column was dropped** — Paystack resolves bank from account number.
- **`payouts` table:** `id, driver_id, amount_minor, currency, status, paystack_transfer_code, bank_account_masked, failure_reason, settled_at`.
- **`payout_status_t` enum:** `pending, processing, settled, failed`.
- **Min withdrawal:** ₦5,000. Max per day: ₦500,000.
- **Paystack transfer** via `request-payout` edge function. Webhook confirms `settled`.
- **Account number validation:** 10-digit NUBAN; client-side digits-only enforcement.

**Edge cases.**
- **Paystack outage.** Payout status remains `pending`; banner explains. Ops dashboard for manual reconciliation.
- **Bank account rejected** (wrong account name, frozen account): `failed` status with `failure_reason`. Driver re-enters details.
- **Driver requests more than balance:** client-side block; server re-checks.
- **Daily cap exceeded:** UI prevents; server re-checks.

**Tickets.** DRV-066 (payout request), DRV-067 (payout history).

**Status.** Shipped with dev-mode Paystack stub. Real transfers is the final pass.

### 6.14 Profile, Documents, Reviews

**Purpose.** Single page where the driver sees their identity, vehicle, KYC status, reviews, account.

**Surfaces.**
- **Profile hub** (`/profile`): header (avatar + name + verified badge), 3-stat strip (joined / lifetime trips / lifetime earnings), groups for Vehicle / Documents / Reviews / Account / Settings.
- **Vehicle details** (`/profile/vehicle`): active vehicle full details, "Add a vehicle" if none.
- **Reviews** (`/profile/reviews`): real distribution bars, top tags, time-ago list.
- **Edit profile** (`/profile/edit`): full name, email, phone (read-only after KYC), DOB, gender, avatar.
- **Documents:** all routes through KYC `DocumentCapturePage` with the appropriate `DocumentKind` argument (per Q3 — re-use onboarding flow).
- **Help** (`/profile/help`): static topics.
- **Sign out** (`/profile/sign-out`) includes DANGER ZONE delete account.

**Functional requirements.**

**Profile hub:**
- **`get_my_profile_summary()` RPC:** joined_at, kyc_status, has_active_vehicle, active_vehicle_model, lifetime_trips, lifetime_earnings_minor, rating_avg, rating_count.
- **VERIFIED pill:** appears when `kyc_status == 'approved' && has_active_vehicle`.
- **Joined date format:** `May 2026` (full month + 4-digit year). Never `May '26`.
- **All document rows** route to KYC `DocumentCapturePage` with their `DocumentKind`.
- **"Background check"** maps to `DocumentKind.roadWorthiness`.
- **VEHICLE row** reads from active vehicle; falls back to "Add a vehicle" CTA when none.
- **REVIEWS card** shows most-recent real review.
- **ACCOUNT — Subscription row** uses live `subscriptionControllerProvider`; status pill colour-coded; days remaining real.
- **ACCOUNT — Referral code** from `profiles.referral_code`.
- **Loading skeleton:** uses `shimmer` package; `ProfileHubShimmer` matches loaded layout 1:1.
- **Notification preferences row removed** (Q4/Q7 — no server store yet).
- **Card-on-file payment block removed entirely** (Q2). `addCard` route deleted, `cards/` module deleted.

**Reviews:**
- **`driver_ratings` table** (RLS gated; insert is RPC-only — only passenger app can rate).
- **`get_my_driver_rating_summary()` RPC:** lifetime + 30-day average, per-star distribution.
- **`list_my_recent_driver_ratings(p_limit)` RPC:** joins to `profiles.full_name` for passenger names.
- **`DriverReviewsController`:** loads summary + recent in parallel.
- **Reviews page:** real distribution bars, top-tags chips (derived client-side), time-ago, empty/error states.

**Edit profile:**
- Editable: full name, email, DOB, gender, avatar.
- Phone read-only after KYC (changing phone requires BVN re-verification — DRV-015, v1.1).
- Avatar upload to Storage `avatars` bucket.

**Edge cases.**
- **No vehicle yet:** VEHICLE row shows "Add a vehicle" CTA.
- **No reviews yet:** REVIEWS card shows "No reviews yet — your first one is coming."
- **Joined date < 60 days:** date format `May 12, 2026` (with day). > 60 days: `May 2026`.

**Tickets.** DRV-076 (profile editor), DRV-077 (documents — handled via KYC), DRV-078 (driver ratings), DRV-079 (reviews page).

**Status.** Shipped.

### 6.15 Safety

**Purpose.** Give the driver a panic button that actually does something, plus trusted-contact reach in emergencies.

**User flow.**

**SOS:**
1. From `/active-trip` or `/home`, tap "Safety" → `/safety`
2. SOS button hero: hold to activate (3s hold)
3. On activate: `trigger_sos` RPC → `safety_events` row + push to trusted contacts + ops alert
4. Confirmation screen: "Help requested. Stay on this screen."

**Trusted contacts:**
1. From `/safety` → "Trusted contacts" row
2. List of contacts (up to 3); one primary (partial-unique index)
3. Add/edit via bottom sheet (name + phone in E.164)
4. Mark one as primary; toggling demotes others atomically (`set_primary_trusted_contact` RPC)

**Trip sharing link (DRV-082 — deferred):**
- Generate a public read-only URL with driver position + ETA, auto-revoked 1h after trip end.
- Share via system share sheet.

**Functional requirements.**
- **`trusted_contacts` table:** `id, user_id, name, phone_e164, is_primary, created_at`. Cap 3 per user. Partial unique index for one primary.
- **`trigger_sos` RPC:** inserts `safety_events` row with `trusted_contacts` array in `payload` jsonb. Triggers webhooks to ops + push to trusted contacts.
- **`set_primary_trusted_contact(p_id)` RPC:** atomically demote existing primary then promote target.
- **SOS hold-to-activate:** 3-second hold; visual ring fills. Tap-only does not trigger.
- **Trip sharing (DRV-082):** deferred.
- **Incident report (DRV-083):** post-trip "report an issue" with categories. Deferred.

**Edge cases.**
- **SOS while offline (no network):** queue the trigger; surface "Sending help request..." UI; retry on reconnect; show "Sent" once landed.
- **Driver tries to delete the only trusted contact:** allowed; SOS still fires to ops.
- **Trusted contact phone invalid:** E.164 validation client-side; bottom sheet refuses save.

**Tickets.** DRV-080 (SOS), DRV-081 (trusted contacts), DRV-082 (trip sharing), DRV-083 (incident report).

**Status.** SOS + trusted contacts shipped. Trip sharing and incident report deferred.

### 6.16 Support

**Purpose.** Give the driver a path to a human when something goes wrong.

**User flow.**
1. From `/profile/help` → static topics (KYC, payment, safety, trip issues)
2. Each topic expands to inline answer; CTAs to "Contact support" (email + WhatsApp) at the bottom
3. v1.1: in-app support chat (DRV-085 deferred)

**Functional requirements.**
- **Static help topics** in app code; copy maintained alongside product changes.
- **Contact support:** `mailto:support@drivio.app` and WhatsApp deep link.
- **Help-article search** (DRV-084 deferred).
- **Support chat** (DRV-086 deferred to Q4 2026 once support team is staffed).

**Edge cases.**
- **No email client configured:** fallback to copy-to-clipboard with the email address shown.

**Tickets.** DRV-084, DRV-085, DRV-086.

**Status.** Static help is shipped. Search + chat deferred.

### 6.17 Notifications

**Purpose.** Let drivers know about state changes that matter — without spamming.

**Surfaces.**
- **In-app inbox** (`/notifications`): chronological list of notifications.
- **System push** via FCM.
- **In-app banners** via `AppNotifier` (top slide-down).

**Notification triggers (v1):**
- Subscription expiring (T-7, T-3, T-1, T-0)
- Subscription renewed
- Payout settled
- Payout failed
- KYC approved / rejected
- Vehicle approved / rejected
- New review received
- Safety event acknowledged by ops

**Functional requirements.**
- **`notifications` table:** `id, user_id, kind, title, body, payload jsonb, deeplink, read_at, created_at`.
- **Inbox sorting:** newest first; tap a row marks `read_at`; deeplink navigates.
- **Realtime subscription:** `public:notifications:user_id=eq.<self>` postgres-changes; in-app badge count updates live.
- **FCM push:** delivery via `send-push` edge function. Category-specific (payout-settled vs trip-related vs marketing).
- **Default opt-ins (v1):** all transactional categories. No marketing pushes by default.

**Edge cases.**
- **Push permission denied:** banner explains; can still re-prompt via settings.
- **Notification arrives while inbox open:** new row slides in at the top.
- **Old notifications (>90 days):** archived (not deleted); accessible via "Older" expand.

**Tickets.** DRV-087 (push notification delivery), DRV-088 (inbox).

**Status.** Inbox shipped; FCM partial (DRV-006 / DRV-087).

### 6.18 Settings & Account

**Purpose.** Theme, language (future), sign out, delete account, trusted contacts.

**Surfaces.**
- **Settings entry** lives in `/profile` "Account" group.
- **Sign out** with delete-account "DANGER ZONE."
- **Appearance** setting (Match system / Light / Dark) — see brand spec §6.

**Account deletion (DRV-090):**
1. From sign-out page, scroll to "Danger zone" → "Delete my account"
2. Two-step confirm: user types `DELETE` in a text field
3. `request_account_deletion` RPC stamps `drivers.deleted_at = now()`
4. Schedules 30-day PII purge (replace name/phone with hashes, drop documents)
5. Driver signed out and routed to `/welcome`

**Functional requirements.**
- **`request_account_deletion` RPC:** refuses if active trip exists, otherwise stamps `deleted_at`.
- **Theme/Appearance setting:** persisted in `SharedPreferences`. Defaults to Light.
- **Language:** English only in v1. Yoruba/Igbo/Hausa deferred.

**Edge cases.**
- **Active trip exists:** RPC returns `cannot_delete_active_trip`; UI explains.
- **30-day window:** during that window, driver can sign back in to cancel deletion (account record retains a flag).

**Tickets.** DRV-089 (appearance/theme), DRV-090 (delete account).

**Status.** Shipped.

### 6.19 Edge States & Failure Recovery

**Purpose.** Every failure mode has a designed screen instead of a crashed app.

**Edge state pages.**
- `/edge/no-requests`: shown after pull-to-refresh with no requests found
- `/edge/offline`: shown when device has no network
- `/edge/subscription-expired`: shown when driver opens the app with `is_driver_active = false`
- `/edge/rider-cancelled`: shown when a winning bid's passenger cancelled before the driver started the trip

**Functional requirements.**
- **Each edge page** has: centered IconDisc + h1 + bodySm + primary CTA.
- **Connectivity awareness:** `ConnectivityController` (DRV-092) watches `connectivity_plus` + periodic health ping + Realtime channel state. Any of the three unhealthy → banner.
- **Reconnection orchestration** (DRV-093): on reconnect, fetch state via REST snapshot, merge with cache, resubscribe realtime channels.

**Tickets.** DRV-091 (offline-first queue UI), DRV-092 (connectivity), DRV-093 (reconnection), DRV-094 (subscription-expired lock), DRV-095 (no-requests).

**Status.** Shipped.

---

## 7. Non-Functional Requirements

### 7.1 Performance

| Metric | Target | Source of truth |
|---|---|---|
| Cold start (warm OS, cached) | < 1.5s to first paint | Sentry performance |
| Cold start to home interactive | < 3.5s p95 | Sentry |
| Marketplace event latency (passenger create → driver render) | < 500ms p95 | PostHog |
| Bid submission round-trip | < 600ms p95 | edge.invocation duration_ms |
| Trip location p95 latency (driver tick → passenger render) | < 1.2s | broadcast metric |
| Edge function p95 (warm) | < 200ms | Logflare |
| RLS query p95 | < 50ms | pg_stat_statements |
| Battery drain at typical use | < 8% / hour | Manual measurement |
| Animation framerate | 60Hz (no jank on bid arrival, dial pulse, sheet open) | Sentry frame rate |

### 7.2 Reliability

- **Crash-free rate ≥ 99.5%** (Sentry).
- **Mutation queue** survives cold start. Idempotency keys persist.
- **Realtime reconnection** reconciles state via REST snapshot — no missed bids, no stale trips.
- **Foreground location service** survives OS throttling during active trip.

### 7.3 Security

- **TLS only.** Certificate pinning deferred to v1.1 (velocity cost vs. benefit).
- **PII encryption at rest** via `pgcrypto` (BVN, NIN, bank account number).
- **RLS on every table.** Driver scope: `auth.uid() = driver_id`.
- **No PII in logs.** Sentry `beforeSend` strips known patterns; PostHog never receives phone/BVN/NIN.
- **Service-role key** only inside edge functions. Never in mobile binary, never in CI logs.
- **Idempotency keys** on every write edge function. 24h response cache.

### 7.4 Privacy / NDPR

- **Consent at sign-up** for KYC processing (terms acceptance gate — currently inline at sign-up; explicit screen if regulator requires v1.5).
- **Right to access:** drivers can request a data export via support email (v1); v1.5 self-serve in-app.
- **Right to deletion:** DRV-090 honours within 30 days. PII purged; trip/financial history retained for compliance.
- **Data minimisation:** the app collects only what each feature needs.
- **Breach notification within 72h.** Ops runbook (PLAT-014).

### 7.5 Accessibility

- **Hit targets ≥ 32×32.** Buttons, list rows, icon buttons default to ≥ 48 in practice.
- **Contrast WCAG AA** at all text sizes (verified at brand-spec sign-off).
- **Dynamic type** respected. Never `textScaleFactor: 1.0`. Layouts tested up to 1.3× scaling.
- **Reduced motion** respected on heavy animations.
- **Semantics** on every `IconCircleButton` and standalone interactive element.

### 7.6 Internationalization

- **English only in v1.** Yoruba, Igbo, Hausa deferred.
- **String externalization** prepared (Flutter `intl` package wired); copy currently inline.
- **Currency tokens** in app code (`NGN` only in v1; future markets add codes).
- **Phone E.164** with `+234` default; future markets add country codes.

### 7.7 Observability

- **Sentry** for crashes, performance traces, error events. PII stripped.
- **PostHog** for product analytics — funnel events, feature usage.
- **Logflare** (or Supabase logs) for edge function logs.
- **`AppLogger`** static façade (`.d/.i/.w/.e`) with structured `data:` map. Silenced in release builds.
- **`loggedRpc(module, fn, params)`** wraps every Supabase RPC call.
- **Standing diagnostic logs:** BootstrapController, OtpController, SessionGuard. Useful any time sign-in feels off.

---

## 8. Key End-to-End User Flows

These are the load-bearing journeys. Each is a litmus test: can a driver complete this without getting lost?

### 8.1 New driver — from app download to first paid trip

```
Download → Splash + permission ask → Welcome → Sign Up
  → Phone + Email + Password → OTP → Paywall (trial starts on KYC)
  → KYC orchestrator: BVN/NIN → Selfie → Documents (6 uploads)
  → "Pending review" → admin approves → KYC = approved
  → trial auto-created (90 days)
  → Add vehicle → admin approves → vehicle = active
  → Home (online toggle now unlocked)
  → Tap "Go online" → location streaming starts → marketplace subscribes
  → First ride request lands within ~500ms of a nearby passenger creating it
  → Tap request → Bid composer → Submit ₦X → "Bid sent"
  → Win notification (passenger picked you)
  → Active trip: en route → arrived → in progress → completed
  → Earnings tile updates (₦X added to today's earnings)
  → Wallet ledger gets a `trip_credit` row
  → Driver does another trip, or goes offline
```

Target: **<10 minutes** from "Sign Up" to "online and ready to bid" (excluding KYC admin review wait).

### 8.2 Returning driver — typical day

```
Open app → Splash → Auto-routed to /home (signed in)
  → Tap "Go online" → all gates pass → online
  → Marketplace requests arrive
  → Driver picks one, bids, wins → active trip → complete
  → Repeat ~6–12 times per day
  → Periodically check /earnings for today's tile
  → At end of day, "Go offline"
```

### 8.3 Withdraw to bank

```
/profile → Manage payment → Add payout account (first time: bank name + account number)
  → Bank account verified (Paystack lookup) → saved
  → Wallet card → "Withdraw ₦X"
  → Enter amount (≥ ₦5,000) → confirm
  → Payout status "Processing"
  → Push: "Payout settled — ₦X in your bank" (within minutes)
  → Wallet balance decreases by ₦X
  → Ledger entry: `payout_debit -₦X`
```

### 8.4 Subscription renewal (failed → recovered)

```
Trial / paid period ends → Paystack auto-charges card on file
  → Failure (insufficient funds) → status = past_due
  → Banner appears on home: "Update payment to keep driving"
  → 3-day Paystack retry window; banner urges payment update
  → Driver opens /subscription/manage → updates card → triggers retry
  → Successful charge → status = active → banner clears
  → Driver keeps driving without interruption
```

If retry fails for 3 days:
```
status → expired → is_driver_active = false
  → Driver tries to go online → SubscriptionGateSheet
  → Drive page auto-flips offline (if was online)
  → Driver opens /subscription/manage → updates card + pays → status = active
  → Online toggle unlocks
```

### 8.5 Safety event (SOS)

```
Driver feels unsafe → Tap "Safety" → /safety
  → Hold SOS button 3 seconds → trigger_sos RPC fires
  → safety_events row inserted with trusted contacts payload
  → Server sends:
    - Push to trusted contacts ("[Driver name] requested help")
    - Ops dashboard alert (P0)
    - Ops contacts driver via masked call
  → Confirmation screen: "Help requested. Stay on this screen."
  → If in trip: passenger app SOS event mirrors the trip ID
```

### 8.6 Account deletion (NDPR)

```
/profile → Sign out → Danger zone "Delete account"
  → Two-step confirm: driver types DELETE
  → request_account_deletion RPC
  → If active trip: refused
  → Otherwise: stamps drivers.deleted_at, schedules 30-day PII purge
  → Driver signed out, routed to /welcome
  → Within 30 days, driver can sign back in to reverse
  → After 30 days: PII replaced with hashes; account record retained for trip/financial compliance
```

---

## 9. Out of Scope (v1)

These are deliberate non-features. If anyone asks "does Drivio Driver do X?" and X is on this list, the answer is "no, by design."

- **Multi-tenant / white-label.** Single tenant. Multi-tenant only if we sell to a fleet partner.
- **Multi-currency.** NGN only. Future markets add codes.
- **Fleet accounts.** Individual drivers only. Fleet companies become account-type with sub-drivers in v2.
- **Driver tiers.** Every driver is "a driver." Gold / platinum etc. post-launch with data.
- **Price negotiation / counter-offer.** One round of bids. v2 may add.
- **Embedded turn-by-turn navigation.** Hand off to Google/Apple Maps.
- **Native ML insights.** Rule-based v1; ML when we have 6+ months of trip data.
- **Localization (Yoruba, Igbo, Hausa).** Deferred.
- **Self-serve account recovery.** Manual via support in v1.
- **Push notification preferences server store.** Deferred (UI on profile was removed in cleanup).
- **Card-on-file payment to passengers (driver-app concern: none).** N/A — driver app doesn't handle cards.
- **In-app turn-by-turn nav.** Hand-off only.
- **Driver-side commission display.** Never — there is no commission.
- **Real-time chat in v1.** Chat is local with canned replies in v1; server-backed messages is the next pass.
- **Masked voice calls in v1.** Stubbed; real masking via Africa's Talking/Twilio in v1.1.
- **Trip sharing link.** DRV-082 deferred.
- **Incident report form.** DRV-083 deferred.
- **Help search / in-app support chat.** DRV-084/085/086 deferred.
- **Background check via separate provider.** Mapped to `road_worthiness` for now; separate provider not in v1.

---

## 10. Success Metrics

For full business-level KPIs see the BRD §7. Product-level success metrics specifically for the driver app:

| Metric | Target | Measured |
|---|---|---|
| Sign-up → KYC submitted | ≥ 80% | PostHog funnel |
| KYC approved within 24h | ≥ 90% | DB query (status transitions) |
| Trial → paid conversion (month 9) | ≥ 60% | DB query (subscriptions) |
| Bid response rate (driver sees → driver bids) | ≥ 40% | PostHog (bid.submit / request.visible) |
| Bid win rate | tracked, no target | DB query |
| Mean time from request received to bid submitted | < 20s p50 | PostHog (request.viewed → bid.submitted) |
| Active driver count (bid ≥ 1 / 14d) | 1,000 by month 6 | DB query |
| Crash-free sessions | ≥ 99.5% | Sentry |
| App-to-rate (driver NPS) | ≥ 50 by month 6 | Quarterly survey |

---

## 11. Open Questions

These need product decisions before v1 launches or v1.1.

1. **Per-trip price ceiling.** Engineering safety rail of ₦100,000 in place. Should it be lower / higher / removed? Product confirmation needed.
2. **Cancellation penalties.** What triggers auto-suspension? (e.g., 30% cancel rate threshold?) v1 shows the metric; v2 may auto-suspend.
3. **Trial reset on suspension-then-readmission.** A driver who completes the trial, gets suspended (bad behaviour), comes back via support — do they get more trial? v1 says no. Confirm.
4. **Notification preferences server store.** When does this come back? Currently removed from profile because no backend.
5. **Dispute SOP for incomplete location trails.** Gaps > 5 min would be suspicious. Need an ops SOP.
6. **Driver-share-of-fare for tips (passenger app feature).** 100% to driver, or platform takes a small cut? v1 = 100% to driver (no platform cut). Confirm.
7. **Background check provider.** v1 maps to `road_worthiness`. Real background check provider (e.g., DataReporters, Smile Identity) for v1.5.
8. **Accident-report flow.** Currently no in-app accident-report. Deferred to DRV-083 (incident report). When?
9. **Driver onboarding video / how-it-works guide.** None in v1. Reduces "how does the marketplace work?" support questions but adds production effort. v1.1 candidate.

---

## 12. Glossary

| Term | Definition |
|---|---|
| **Ride request** | A passenger's tap on "Find a ride" — creates a `ride_requests` row, 60s auction window, fanned out to drivers in the geohash6 zone. |
| **Bid** | A driver's proposed price for a specific ride request, with ETA. One bid per (request, driver). |
| **Accept bid** | The passenger picking one bid. Serializable Postgres transaction: locks request, accepts one bid, rejects siblings, inserts `trips` row. |
| **Trip** | A row in `trips`. Lifecycle: `assigned → en_route → arrived → in_progress → completed | cancelled`. Each transition writes a `trip_events` audit row. |
| **Drivio Pro** | The driver subscription, in three tiers. Daily ₦2,500 (24h anniversary renewal), Weekly ₦15,000 (7-day), Monthly ₦50,000 (30-day). 90-day trial for new drivers, defaults to Monthly suggestion at trial end. Drivers can switch tiers anytime — change takes effect at the next renewal. Hard block at expiry except for trips already in progress. |
| **Anniversary renewal** | Renewal anchored to the moment of the previous successful charge, not calendar boundaries. Pay at 23:00 Monday on Daily → renew at 23:00 Tuesday. |
| **Tier switch** | Driver-initiated change between Daily / Weekly / Monthly. Queued as `pending_plan_id`; activates at next renewal. No mid-cycle pro-ration. |
| **Subscription gate** | Server-side check (`is_driver_active(user_id)`) at three points: `go-online`, marketplace channel subscribe, `submit-bid`. Returns true for `trialing | active | past_due`; false for `expired | cancelled`. |
| **Subscription gate** | Server-side check (`is_driver_active(user_id)`) at three points — go-online, marketplace channel subscribe, bid submission. |
| **Wallet** | NGN value store for drivers. Credits from trip completion; debits at payout. Read via `driver_wallets` view in driver-app code. |
| **Geohash6 zone** | Marketplace fanout cell. ~1.2km × 0.6km in Lagos. Drivers subscribe to current cell + 8 neighbours. |
| **Marketplace broadcast** | Supabase Realtime broadcast channel keyed by `marketplace:zone:<geohash6>`. Drivers in the cell get the request within ~500ms. |
| **Active vehicle** | A `vehicles` row with `status='active' AND deleted_at IS NULL`. One per driver. |
| **KYC status** | Driver's verification state. `not_started → in_progress → pending_review → approved | rejected`. Trial auto-created on approval. |
| **Online state** | Driver is in the marketplace and broadcasting location. Gated by KYC + sub + location + vehicle. |
| **Idle / bidding / trip / trip-cancelled / trip-completed mode** | Drive shell sub-modes the driver moves through during normal use. Bottom sheets transition modes, not separate routes. |
| **Coach tip** | Hand-curated rule-fired insight surfaced on the earnings + home page. Rule-based v1; ML in v2. |
| **Demand heatmap** | Geohash6 polygon overlay on the live map showing recent request density. |

---

## 13. Version History

| Version | Date | Author | Changes Made |
|---|---|---|---|
| 1.0 | 2026-05-31 | [Product Owner] | Initial PRD for Drivio Driver app. Covers persona, principles, IA, 19 feature areas with detailed specifications, non-functional requirements, key user flows, out-of-scope list, success metrics, open questions, and glossary. Synthesizes BRD strategic frame, brand spec voice/visual direction, and existing engineering tickets (DRV-001..101) into PRD format. |

---

**END OF DOCUMENT**

Questions? Push back on any of the requirements? Things missing? Let's talk — none of this is final until we ship.
