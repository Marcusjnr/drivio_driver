# Drivio Business Requirements Document (BRD)

**Project Name:** Drivio — Driver-Priced Ride-Hailing Marketplace (MVP)

**Product Owner:** [Product Owner Name]
**Date:** May 31, 2026
**Version:** 1.0
**Status:** Draft

---

## 📌 What This Document Is About

Here's the deal: we're building a different kind of ride-hailing platform, and this document is going to walk you through why we're doing this, what problem we're solving for Lagos drivers and passengers, and how we plan to actually pull it off. Think of this as the business case for Drivio — the "why should we invest people, money, and runway into this?" document.

We're targeting a Lagos-first launch with Nigeria-wide expansion to follow. There are three apps in scope: the Passenger app, the Driver app, and the Admin dashboard. They all run against one shared Supabase backend. Let's dive in.

---

## 1. Executive Summary

Here's what we're building: Drivio is a three-app ride-hailing ecosystem (Passenger + Driver + Admin) where **drivers set their own prices for every ride**. Not us. Not an algorithm. The driver.

You might be thinking, "isn't that just inDrive?" Not quite. inDrive lets passengers *negotiate* — you propose a price, the driver counters, you go back and forth. We don't do negotiation. A passenger requests a ride, every nearby driver proposes their own price, the passenger sees all the bids and picks one. One round. 60-second window. Done.

And here's the part that changes the economics: **we take zero per-trip commission**. None. Whatever price the driver bids is what the driver keeps. Our entire revenue comes from a **driver subscription** (Drivio Pro), priced in three tiers so drivers can choose the commitment that fits how they actually work:

- **Daily — ₦2,500** (auto-renews 24 hours after purchase)
- **Weekly — ₦15,000** (saves ~₦2,500 vs daily-for-7-days)
- **Monthly — ₦50,000** (cheapest per-day rate — for full-time drivers)

New drivers still get a **90-day free trial**. At trial end, the driver picks a tier (Monthly is the default suggestion). They can switch tiers anytime — the change takes effect at the next renewal. Trial is one-time-per-driver, never re-grantable.

Why does this matter? Because Uber and Bolt's business model is to take 20–30% of every trip. The more a driver earns, the more those platforms make. Drivers have been protesting that for years. Drivio inverts the incentive: once a driver has paid their subscription (whichever tier they chose), every naira they bid is theirs. We make money when drivers stay subscribed — which means we make money by delivering enough trips that the subscription feels like a bargain at whatever cadence the driver chose.

The numbers we're targeting for Year 1:
- **1,000 active subscribed drivers** in Lagos by month 6 post-launch.
- **50,000 completed trips/month** by month 6.
- **Driver NPS of 50+** (Uber/Bolt sit around -10 to +10 in Lagos).
- **₦45M+ monthly recurring revenue** by month 6, based on a blended-tier mix (modelled at 55% Monthly + 30% Weekly + 15% Daily). The math: 550 × ₦50k + 300 × ₦60k (weekly-equivalent monthly) + 150 × ₦75k (daily-equivalent monthly) ≈ ₦56.75M. We discount ~20% for the gap between assumed and actual usage = **~₦45M MRR conservative**.

That's what success looks like. Not "downloads." Not "DAUs." Trips drivers actually earn on and a subscription they actually renew.

---

## 2. Background & Context

Let me paint you a picture of what's happening on Lagos roads right now.

Two platforms dominate ride-hailing in Lagos: **Uber and Bolt**. There's also inDrive (the negotiation one) and a few smaller players (Rida, Lagos Ride, Kabukabu). Between them, they've trained an entire generation of Lagos drivers and passengers to use apps for transport — that demand-side education is done. We don't have to convince Lagosians that hailing a ride from a phone is normal. That battle is over.

But here's what's happening underneath the surface, and it's ugly.

**Drivers are angry.** Uber takes 25% of every trip. Bolt takes 20%. A driver who grosses ₦100,000 in a week is taking home maybe ₦70,000 after the platform's cut — and then fuel, vehicle maintenance, and "agent" payments eat into that further. There have been multiple driver strikes in Lagos in the last 18 months. Drivers have organized WhatsApp groups to coordinate going offline simultaneously to protest fare cuts. The relationship between platforms and drivers is openly hostile.

**Pricing is opaque.** Both Uber and Bolt use dynamic pricing controlled by an algorithm. When demand spikes, prices go up. When supply spikes, prices drop. Drivers can't see why a trip they're being offered pays ₦1,200 when a nearly identical trip yesterday paid ₦1,800. Passengers can't see why a 5km ride costs ₦3,500 in the morning but ₦8,200 in the evening. Neither side trusts the price.

**Payments are broken.** Card penetration in Nigeria is patchy — a huge chunk of the population is bank-account-rich but card-poor. Both Uber and Bolt push card-on-file as the default, which excludes a real chunk of the market and creates card-fraud headaches. Cash works but with constant disputes (driver claims passenger underpaid, passenger claims they paid the right amount).

**Drivers get deactivated arbitrarily.** Algorithmic compliance flags drivers off the platform with no appeal process. Lose your livelihood because the algorithm thought your acceptance rate dropped too low. No human review.

So where's the opportunity? Nobody has built a Lagos-native ride-hailing platform where:
1. Drivers set their own prices and keep 100% of the fare.
2. Passengers see real bids from real drivers and pick — no algorithm in the middle.
3. The platform makes money only from a transparent flat subscription, not by skimming trips.
4. Payments work for the actual Nigerian market (wallet + cash, no card-on-file requirement).
5. Drivers get a human appeal process when something goes wrong.

We're not trying to compete with Uber and Bolt on their terms. We're creating a new category: **driver-priced ride-hailing**. The closest analog is inDrive's bidding flow, but we've made deliberately different decisions on every consequential question (no negotiation, no card-on-file, geohash-based marketplace fanout, flat-subscription economics).

And here's the beautiful part: the conditions for this to work — high smartphone penetration, mature payment rails (Paystack, Flutterwave), driver dissatisfaction with incumbents, regulatory clarity around KYC (BVN/NIN/LASRRA) — are all in place in Lagos right now. The market is ready. The window is open.

---

## 3. Business Objectives

Let's be crystal clear about what we're trying to achieve. These aren't nice-to-haves — they're the goals that determine whether Drivio is a real business or a pet project.

### 1. Become the Highest-Earning Platform for Lagos Drivers (This Is Everything)

This is our North Star. Drivio drivers, on average, should take home **more naira per hour driven** than they would on Uber or Bolt — even after paying us their chosen subscription tier.

**Target:** Subscribed Drivio drivers earn 15%+ more per hour than they would on Uber/Bolt (measured via driver-reported earnings + trip volume data) by month 6, net of subscription cost across all three tiers.

**Why this matters:** If drivers don't make more, the entire pitch collapses. The 3-tier structure exists specifically so each driver can match commitment to expected workload — a full-time driver on Monthly only pays ₦50k regardless of how much they earn (which on Uber's 25% cut would have cost them ₦125k+ on ₦500k gross). A part-time driver on Daily pays ₦2,500 only on days they actually work, vs Uber clawing 25% every shift regardless. Across tiers the math has to land in the driver's favor — or we're done.

**Quick math sanity check:**
- Full-time driver grossing ₦400k/month on Uber pays ~₦100k in commission. On Drivio Monthly: ₦50k. Saves ₦50k.
- Part-time driver grossing ₦80k across 10 driving days on Uber pays ~₦20k in commission. On Drivio Daily (₦2,500 × 10 days): ₦25k. Loses ₦5k on commission math alone — but gains pricing control + no algorithmic deactivation + free cancellation reciprocity.
- Weekend-warrior driver grossing ₦40k across 8 days on Uber pays ~₦10k. On Drivio Daily (₦2,500 × 8): ₦20k. Daily tier is **not** the right pick for this driver — Drivio Pro Daily is for drivers who plan to work most days but want flexibility on the days they don't. We surface this in the paywall comparison.

If a driver does fewer than ~15 trips/day at typical Lagos fare, Daily is not their tier. The app's tier-recommendation logic uses the prior week's bid volume to suggest the right tier.

### 2. Earn a Reputation as the Trustworthy, Driver-Owned Alternative

We want every Lagos driver to know that Drivio doesn't take a cut. Every Lagos passenger to know they're choosing from real, verified drivers' actual prices — not a black-box algorithm.

**Target:** Driver NPS of **50+** and passenger NPS of **40+** by month 6. (For context: Uber and Bolt drivers in Lagos consistently rate their platform experience between -10 and +10.)

**Why this matters:** Word-of-mouth is the only acquisition channel that's going to work for us at our budget. Drivers tell other drivers. Passengers tell other passengers. If our NPS isn't strong, we don't grow.

### 3. Sustainable Revenue via Driver Subscriptions

We charge a tiered subscription, billed via Paystack. Not per trip. Not a fare cut.

| Tier | Price | Renewal cadence | Best for |
|---|---|---|---|
| **Daily** | ₦2,500 | 24h from purchase, auto-renews | Drivers who work some days but not all; testing-the-waters |
| **Weekly** | ₦15,000 | 7 days from purchase, auto-renews | Most drivers most of the time; the safe default for active drivers |
| **Monthly** | ₦50,000 | 30 days from purchase, auto-renews | Full-time drivers — best per-day rate |

Renewal is anchored to the moment of purchase, not calendar boundaries. A driver who subscribes daily at 23:00 Monday renews at 23:00 Tuesday — not at midnight.

**Target:** **₦45M+ MRR by month 6** based on a blended-tier mix (55% Monthly + 30% Weekly + 15% Daily across 1,000 active drivers). **₦135M MRR by month 12** at 3,000 active drivers, same tier mix.

**Why this matters:** We need to validate that drivers will pay a subscription for a no-commission marketplace AND choose the tier appropriate to their workload. If the tier mix skews differently than modelled (e.g., 80%+ Daily), it tells us drivers are testing the platform rather than committing — which is signal worth acting on, either by improving the Monthly offer or by adjusting Daily's price.

### 4. Build a Liquid Lagos Marketplace

A marketplace only works if both sides show up. We need enough drivers in every geohash6 cell across Lagos so that any passenger anywhere in the city sees real bids within 60 seconds.

**Target:** **≥5 active drivers per geohash6 cell** in 80% of Lagos during peak hours by month 6. **<60 seconds median time-to-first-bid** for ride requests anywhere in Lagos.

**Why this matters:** A marketplace that works in Yaba but not in Lekki is a broken marketplace. We need city-wide liquidity for the product to feel real. This is the hardest goal on the list.

### 5. Operational Trust — Verified Drivers, Safe Trips, Fair Disputes

Every driver on Drivio passes BVN + NIN + selfie + vehicle inspection. Every trip has SOS + live trip sharing + trusted-contact alerts. Every dispute is reviewed by a human, not an algorithm.

**Target:** **100% of active drivers KYC-verified.** **<24h dispute resolution SLA.** **Zero algorithmic-only deactivations** — every suspension reviewed by a human admin.

**Why this matters:** The platforms we're displacing have shredded driver trust. If we build the same algorithmic black-box experience, drivers will see through us instantly. Our differentiation runs all the way through to ops.

---

## 4. Problem Statement

Alright, let's talk about the actual problem.

Lagos has roughly 30,000–40,000 active ride-hailing drivers across Uber, Bolt, and inDrive at any given time. These are men and women working 10–14 hour shifts, paying ₦4,000–₦6,000 per day in fuel, ₦25,000–₦40,000 per week in vehicle maintenance, and they're handing 20–30% of every trip to an app that they have zero control over.

Here's what's broken right now:

**The commission model is incompatible with the Nigerian economy.** A ride that grosses ₦3,000 with Uber leaves the driver with ₦2,250 after commission. After ₦600 in fuel for that trip and a slice of weekly maintenance, the driver clears maybe ₦1,200–₦1,500. That's the actual unit economics. The driver isn't broke because they don't work hard. They're broke because the cut is too big.

**Pricing is a black box on both sides.** Drivers can't tell why one trip pays well and another doesn't. Passengers can't tell why surge is on. Neither side understands the price they're being shown, and neither side trusts it. The result: drivers cancel low-fare trips (frustrating passengers), passengers cancel surge-priced trips (frustrating drivers), and trust erodes on both sides every single day.

**Dispatch is non-transparent.** When a passenger requests a ride, the algorithm picks which driver gets offered the trip. Drivers have no idea why they're getting offered a trip — or why they aren't. This breeds conspiracy theories ("the app punishes me when I decline trips," "the app gives the best trips to its favorites"). Some of those conspiracy theories are probably right.

**Payments don't fit Lagos.** Uber and Bolt push card-on-file. That excludes a huge part of the market — Lagos has plenty of bank-account-rich, card-poor users. Cash works, but creates constant disputes ("you paid ₦2,500" / "no I paid ₦3,000") with no platform recourse.

**There's no human in the loop.** When something goes wrong — a fake rider account, an unsafe driver, a wrongful deactivation — there is no human to talk to. The platforms run support like an algorithm: copy-paste email, ticket closed. Nigerians used to dealing with banks know that a real human at the other end of a call solves problems algorithms can't.

**Drivers are exhausted by it.** The result is the strikes, the WhatsApp coordination, the constant turnover. The platforms have a high enough churn rate that they're constantly running acquisition campaigns to replace drivers who leave. That's the symptom of a broken value proposition.

What's the result? Lagos's ride-hailing market is enormous (probably ₦100B+/year in gross fares) but the dominant players have run out the goodwill of their supply side. The opportunity isn't to build a better dispatch algorithm — the opportunity is to **stop running a dispatch algorithm at all** and let the market clear prices directly.

That gap is what Drivio fills.

---

## 5. Proposed Solution (Business View)

So how are we solving this? Let me walk you through what makes Drivio fundamentally different.

### Driver-Priced Marketplace (The Whole Point)

When a passenger taps "Request ride," the request goes out to every Drivio driver within a 1.8km × 1.2km zone around the pickup. Each of those drivers gets 60 seconds to look at the trip (pickup, dropoff, distance, ETA) and decide whether to bid — and if so, at what price.

The passenger sees every bid as it lands. They can sort by price, by ETA, or by driver rating. They have 60 seconds to pick. They pick one. The other drivers see "another driver was chosen." Done.

There is **no algorithm setting the price**. There is **no surge**. There is **no negotiation round** (one bid per driver per request — if you want to change your bid, you withdraw and resubmit). The price the passenger sees is the price they pay. The price the driver bids is the price they keep.

**Why we made this choice:** Auctions work when (a) there are enough sellers to make the auction competitive and (b) the buyer can make an informed pick. Lagos has both. A typical Lagos zone during peak hours has 50–200 drivers. A 60-second window gathers enough bids without making the passenger wait forever.

**Why we don't do counter-offers:** Negotiation rounds explode the realtime complexity, change the UX from "pick a price" to "haggle," and Lagos taxi culture (like every ride-hailing market we've studied) tolerates "this price or no" but resists drawn-out negotiation in-app. Maybe v2.

### Zero Per-Trip Commission

This one is simple. Whatever the driver bids, the driver keeps. We do not skim 20%. We do not skim 5%. We do not skim ₦50. Nothing.

A driver who bids ₦2,800 for a trip earns ₦2,800. That ₦2,800 flows into their Drivio wallet on trip completion. They withdraw it to their bank via Paystack transfer whenever they want (minimum ₦5,000 withdrawal, maximum ₦500,000/day).

Our revenue is the **Drivio Pro subscription** they pay to be on the platform — ₦2,500/day, ₦15,000/week, or ₦50,000/month, driver's choice. That's it. That's the whole monetization model for v1.

**Why this matters:** This is the single biggest difference between us and every other ride-hailing platform in the market. It changes the unit economics for drivers from "I work harder, the platform makes more" to "I work harder, I take home more." That's the entire pitch.

### 90-Day Free Trial for New Drivers

A new driver who completes KYC gets an automatic 90-day Drivio Pro trial. No payment up front. They can bid, accept trips, earn, withdraw — all of it — for 90 days.

At trial end, the driver picks a tier. We default the suggestion to **Monthly** (the cheapest per-day rate, the safest commitment for a driver who has spent 90 days on the platform) but the comparison view shows all three side-by-side with personalized recommendation based on their trial-period activity:

- "You bid on 65% of days during your trial. **Weekly** fits your pattern."
- "You bid on 95% of days during your trial. **Monthly** is your cheapest option."
- "You bid on 30% of days during your trial. **Daily** lets you only pay on days you drive."

The driver can override the recommendation. They can switch tiers anytime post-trial — the switch takes effect at the next renewal cycle.

**Why 90 days specifically?** A 30-day trial gets eaten by KYC delays and slow weeks. A 6-month trial gives away the business. 90 days is long enough that a driver has ridden through a typical month-to-month earnings curve, felt the marketplace velocity, and decided whether the platform is worth paying for at whichever cadence fits their pattern. It's the smallest window that actually lets the trial do its job.

Trial is **one-time-per-driver, forever**. We don't reset it when someone cancels and comes back. If you've used your 90 days, you've used them.

**Tier switching mechanics:**
- A driver can switch tiers anytime via Subscription Manage page
- The switch is queued as `pending_plan_id` on their `subscriptions` row
- At the next renewal, the new tier kicks in
- No mid-cycle pro-ration — they finish their paid cycle on the current tier
- Audit log captures every switch with reason

### Wallet + Cash Payments (No Card-on-File)

Passengers pay one of two ways: **wallet** (top up via Paystack card or bank transfer, debited at trip completion) or **cash** (record the trip, no platform money moves, both parties confirm).

We deliberately do not offer card-on-file. The Nigerian payment fraud landscape (stolen-card fraud against ride-hailing has been a Bolt and Uber problem in Lagos for years) makes card-on-file an expensive liability. The wallet model moves the fraud surface to the top-up event, where Paystack can defend it with 3DS and velocity checks.

We hold ₦100 from the passenger's wallet at the moment they accept a bid (the "trip hold"). The full fare is debited at completion. If the trip is cancelled, the hold is reversed.

**Why this matters:** Wallet + cash covers ~95% of the Lagos market. Card-on-file would gain us maybe 5% more passengers at the cost of a real fraud rate and a more complex UX. Not worth it for v1.

### Free Anytime Passenger Cancellation

A passenger can cancel a ride at any point — before bidding closes, after a bid is accepted, even after the driver is en route — and pay no cancellation fee. Ever.

This sounds like we're inviting abuse. We're not. Here's how it works:
- If the driver hasn't departed yet, no money has moved (the ₦100 hold is reversed).
- If the driver was en route for more than 60 seconds, we pay the driver compensation from a **platform-funded driver compensation pool**. The passenger pays nothing.
- If a passenger habitually cancels (>30% cancel rate), our anti-abuse system flags them for human review.

**Why this matters:** The single biggest UX win we can give passengers is "you can change your mind." The cost (driver compensation from our pool) is real but trackable. We absorb it because it's the price of letting passengers feel free, which is the price of getting them to use the marketplace.

### Three Apps, One Shared Supabase Backend

We're shipping three applications:

1. **Passenger app** (Flutter, iOS + Android) — request rides, browse bids, pick a driver, track the trip, pay, rate.
2. **Driver app** (Flutter, iOS + Android) — go online, see ride requests, bid, run trips, manage subscription, withdraw earnings, view performance analytics.
3. **Admin dashboard** (Next.js 16, web) — ops/support/finance/risk control center. Drives KYC review, dispute resolution, payouts, marketplace monitoring, subscription management, configuration.

All three run against **one shared Supabase project**. There is exactly one `trips` table. One `wallets` table. One marketplace channel. Drivers and passengers are discriminated by `auth.users.raw_user_meta_data.role` (`driver` or `passenger`) and `wallets.owner_kind`. This unifies operations (one dashboard, one ledger) and lets us evolve features without federation pain.

### Built on Supabase

Supabase gives us Postgres + Auth + Realtime + Storage + Edge Functions in one bundle, with RLS as the security model. The realtime story is what made this load-bearing for us: marketplace fanout (a new request arriving) is a broadcast to a geohash6 zone (so drivers in Yaba don't get woken up by requests in Lekki); personal channels (your bids, your trip, your wallet) are postgres-changes (so RLS does the security work for free).

We use **PostGIS** for geo, **geohash6** for marketplace zoning, **H3** for the demand heatmap. **Paystack** for subscriptions and payouts (with Flutterwave as a failover for activations). **Termii** for SMS OTP (Sendchamp as fallback). **Dojah** for BVN/NIN identity verification and liveness checks. **FCM** for push. **Sentry** for crash reporting. **PostHog** for product analytics. **MapLibre** with **OpenFreeMap** tiles for maps (no Google Maps SDK lock-in or per-load fees).

### The Admin Side: Operations at Scale

While drivers and passengers get mobile apps, ops needs a web dashboard to run the business:

- **KYC review queue**: drivers' uploaded BVN, NIN, selfie, vehicle docs reviewed and approved/rejected by a human verification team.
- **Dispute resolution**: passenger-driver conflicts (cash disputes, no-shows, safety reports) triaged by support.
- **Marketplace monitoring**: live heatmap of supply/demand, ability to broadcast targeted nudges to drivers ("Demand is high in Lekki — head there for better trips").
- **Subscription management**: see who's trialing, who's active, who's churning. Trigger nudges. Process renewals.
- **Payout reconciliation**: daily reconciliation between our wallet ledger and Paystack's float. Zero-tolerance variance.
- **Configuration**: dispatch radius, cancellation rules, compensation amounts, plan pricing — all tunable from admin, all dual-approved on changes, all audit-logged.
- **RBAC**: fine-grained permissions composed into roles. Ops Lead, Support L1/L2, Verification Agent, Finance Ops, Risk Analyst, Super Admin.
- **Audit log**: every consequential admin action hash-chained, append-only, retained 7 years (per CBN financial-records rules).

This is how we actually run the platform behind the scenes. The mobile apps are the product; the admin dashboard is the business.

---

## 6. Scope

Let's be really clear about what we're building for MVP (v1, Lagos launch) and what we're explicitly not building.

### In Scope — What We're Building

**Passenger Mobile App (iOS + Android, Flutter):**
- Phone OTP signup/signin (Termii dev OTP `123456` for v1 stub, real Termii for prod)
- Passenger profile (name, phone, email, avatar, referral code)
- Home page with GPS pickup + saved places + recent destinations
- Address picker with global search (Google Places via server-side proxy, Lagos centroid bias)
- Saved Places CRUD (Home, Work, custom)
- Ride request creation (60-second auction window)
- Live bid feed (real-time arrival of driver bids, sort by price/ETA/rating)
- Bid acceptance with payment method choice (wallet or cash)
- Wallet top-up via Paystack (card + bank transfer)
- Wallet balance, ledger history, ₦100 hold/debit transparency
- Confirm screen (locked fare, matched driver, vehicle details)
- Active trip page with live driver location overlay (1Hz broadcast)
- Trip cancellation (free anytime; server-side compensation if driver en route >60s)
- Complete page with fare summary, tip selector, 5-star rating
- Trip history, sharing link
- Edge states: no drivers, too expensive, driver cancelled, offline
- Profile, settings, support, account deletion
- Push notifications (bid received, trip state changes)

**Driver Mobile App (iOS + Android, Flutter):**
- Phone OTP signup/signin
- KYC orchestrator: BVN + NIN + selfie + liveness + drivers' licence + vehicle docs (registration, insurance, road worthiness, LASRRA, inspection report)
- Vehicle management (add/edit/replace vehicle, multiple vehicles per driver)
- Subscription paywall + Drivio Pro 90-day trial (auto-created on KYC approval, one-time-per-driver) + 3-tier selection (Daily ₦2,500 / Weekly ₦15,000 / Monthly ₦50,000) with personalized recommendation based on trial-period activity
- Online/offline toggle (gated by KYC + subscription + location permission)
- Foreground location streaming (5s stationary, 1s moving)
- Background location during trips (FGS on Android, iOS background modes)
- Single shared root map (Uber-style) with idle/bidding/trip mode transitions
- Marketplace request feed (realtime via geohash6 broadcast)
- Bid composer with 3 pricing variants (type, slider, chips)
- Suggested fare with peak/night surcharge multipliers
- Pricing strategy page (base fare, per-km, peak/night toggles, max pickup distance, trip-length preference)
- Active trip lifecycle (assigned → en_route → arrived → in_progress → completed/cancelled)
- Trip chat (passenger ↔ driver, scoped to active trip)
- Masked voice call (deferred to PLAT-018)
- Safety: SOS hold-to-activate, trusted contacts (cap 3, 1 primary)
- Earnings: today/week/month/year tiles + chart, acceptance/cancellation metrics, coach tips, demand heatmap
- Wallet + payout (Paystack transfers, min ₦5k, max ₦500k/day)
- Profile hub (joined date, KYC status, vehicle, lifetime trips/earnings, reviews)
- Notifications inbox, profile editor, help center, sign out + account deletion
- Subscription management page (status, plan, renewal date, billing history)
- Push notifications (request received, trip state, subscription warnings)

**Admin Dashboard (Web, Next.js 16):**
- RBAC with fine-grained permissions, system roles + custom roles, scope DSL
- Audit log (hash-chained, append-only, 7-year retention)
- KYC review queue with approve/reject + reason codes
- Driver lifecycle: view, suspend (with reason), unsuspend, deactivate, archive
- Passenger lifecycle: view, suspend, deactivate, anonymise
- Live marketplace view: supply/demand heatmap (H3), online drivers, active requests
- Trip detail drawer: full timeline, audit events, dispute attachment
- Dispute inbox with macros, evidence linking, both-party rebuttal flow
- Wallet + ledger explorer (per-user, per-trip)
- Payout dashboard with dual-PSP routing (Paystack primary, Flutterwave failover)
- Daily reconciliation against PSP float (₦0 tolerance)
- Subscription management (versioned plans, bulk migration, dunning)
- Notification broadcasts (templates, segmentation, throttling, opt-out bypass logging)
- Geo-zone configuration (service areas, dispatch radius, cancellation rules)
- Risk signals (cancellation gaming, supply gaming, location spoofing)
- Cron job health (matchmaker, expiry sweeper, payout reconciliation)
- Daily analytics: GMV, MRR, active drivers, trip count, NPS rollups
- Admin user management (create, MFA enrolment, IP-pinning)

**Backend (Supabase):**
- Postgres + PostGIS schema (drivers, passengers, vehicles, documents, subscriptions, ride_requests, ride_bids, trips, trip_events, trip_locations, wallets, wallet_ledger, payouts, ratings, messages, safety_events, notifications, audit_logs)
- RLS on every table
- Realtime: postgres-changes for personal channels + broadcast for marketplace fanout (geohash6 zones) and live trip locations
- Edge Functions (Deno): `submit-bid`, `accept-bid`, `cancel-trip`, `complete-trip`, `go-online`, `update-presence`, `paystack-webhook`, `places-proxy`, `confirm-cash-paid`
- Storage buckets: `kyc-private`, `vehicle-photos`, `avatars`, `chat-attachments`, `dispute-evidence`
- Cron workers: matchmaker, expiry sweeper, payout reconciliation, archiver, audit-chain verifier
- Termii SMS integration (OTP)
- Paystack subscriptions, transfers, webhooks
- Flutterwave failover for activations
- Dojah BVN/NIN/liveness integration
- FCM push delivery

**Business Operations:**
- KYC review team training and SOP (target: <24h median verification SLA)
- Dispute resolution playbooks (cash, no-show, safety, identity)
- 24/7 SOS escalation playbook (LASTMA/police coordination)
- Marketing assets for Lagos launch (driver acquisition events, focus group sessions)
- Terms of service + privacy policy + NDPR compliance documentation
- Customer support email + WhatsApp number
- Driver-acquisition events (partnerships with mechanic networks, fuel station coupons, driver association meetups)

### Out of Scope — What We're NOT Building (At Least Not for MVP)

- **Pre-bid pricing hints** (no suggested fare shown to passenger before bids arrive — keeps the auction's price discovery honest)
- **Counter-offers / multi-round negotiation** (one bid per driver per request — single-round auction only)
- **Card-on-file payments** (wallet + cash only; closed-loop wallet limits fraud surface)
- **Pooled / shared rides** (single-rider trips only)
- **Driver tiers** (gold/platinum/etc — every driver is "a driver" until we have data on what differentiates good drivers)
- **Fleet / multi-driver accounts** (individual drivers only — FK-friendly to add later)
- **Multi-currency** (NGN only — schema has `currency` column for future)
- **Multi-tenant / white-label** (single-org Supabase project — multi-tenant only if we sell to a fleet partner)
- **Localisation** (English only — Yoruba, Igbo, Hausa deferred to post-launch)
- **Embedded turn-by-turn navigation** (hand off to Google/Apple Maps via `url_launcher`)
- **Native ML for insights** (rule-based coach tips for v1; ML deferred to month 6+ when we have data)
- **Sentry/PostHog SDK live in apps** (env keys wired but initialisation deferred — will land in v1.1)
- **Driver-side push notifications via FCM (full)** (current state is partial — full delivery coverage post-MVP)
- **Live ETA recompute during trip** (current is haversine estimate; directions-API recompute is post-MVP)
- **Real-time chat backend** (current chat is local with canned replies; server-backed `messages` table post-MVP)
- **Masked voice calls** (Africa's Talking integration deferred)
- **Force-update version gate** (post-MVP)
- **Mutation queue with idempotency** (currently relies on PG UNIQUE constraints; full client-side queue post-MVP)
- **International expansion** (Lagos only for v1; Abuja, Port Harcourt are v1.5)
- **Web interface for end users** (mobile-only for drivers and passengers)
- **Public partner API** (post-MVP)
- **Loyalty programs, referral rewards** (referral codes are tracked but rewards aren't computed yet)

If it's not listed in "In Scope," assume it's out. We're being ruthless about keeping MVP focused so we can ship.

---

## 7. Success Metrics & KPIs

Here's how we'll know if Drivio is actually working. These aren't vanity metrics — they're the numbers that prove the model.

### Primary Metrics (What We Care About Most)

**1. Driver Hourly Earnings vs Uber/Bolt Baseline**

This is the big one. Are Drivio drivers actually taking home more per hour driven than they would on the alternatives?

- **Target:** Subscribed Drivio drivers earn **15%+ more naira per hour** than equivalent Uber/Bolt drivers by month 6, net of their chosen subscription tier (Daily/Weekly/Monthly).
- **How we measure:** Driver-reported earnings + trip count + active hours from `wallet_ledger` and `driver_presence` tables, benchmarked against periodic driver surveys + public reporting on Uber/Bolt earnings.

If this is wrong, our entire value proposition collapses. Drivers aren't paying a subscription to earn less.

**2. Active Subscribed Driver Count**

How many drivers have completed KYC, paid (or are trialling) Drivio Pro, and submitted at least one bid in the last 14 days?

- **Target:** **1,000 active subscribed drivers** by month 6. **3,000** by month 12.
- **How we measure:** Count of `drivers` with `is_active = true` joined with `subscriptions` where status is `trialing | active | past_due`, filtered for those who submitted ≥1 bid in trailing 14 days.

This is the supply side of the marketplace. Without enough drivers, the passenger experience falls apart (no bids land in 60s).

**3. Completed Trips per Month**

Are passengers actually choosing bids and going on trips?

- **Target:** **50,000 completed trips/month** by month 6.
- **How we measure:** Count of rows in `trips` with `state = 'completed'`, grouped by month.

Trips are the unit of value exchange in the system. If they're not happening, neither side is getting what they came for.

### Secondary Metrics (Important Context)

**4. Time to First Bid**

When a passenger requests a ride, how fast does the first driver bid land?

- **Target:** **<30s median** time-to-first-bid across all Lagos requests, **<60s p95**.
- **How we measure:** `ride_bids.created_at - ride_requests.created_at` for the first bid per request.

If this is too slow, passengers abandon the request before bids arrive. Marketplace dies on the passenger side.

**5. Bid Coverage Rate**

What percentage of ride requests get at least one bid before expiry?

- **Target:** **90%+ of requests get at least one bid** within the 60-second window across Lagos.
- **How we measure:** (Requests with ≥1 bid / total requests) × 100, broken down by geohash6 cell and time-of-day.

This is the city-wide liquidity metric. If coverage is uneven (90% in Yaba, 40% in Lekki), we know where to push driver acquisition.

**6. Subscription Conversion Rate (Trial → Paid)**

What percentage of drivers convert from the 90-day trial to a paid subscription?

- **Target:** **60%+ trial-to-paid conversion** by month 9 (the first trials end around month 3 post-launch).
- **How we measure:** (Drivers with `subscriptions.status = active` post-trial / drivers who completed 90-day trial) × 100.

This validates that drivers find Drivio Pro worth paying at one of the three tiers. We also track the **tier mix at conversion** (what % pick Daily / Weekly / Monthly at trial end) — that signals whether our pricing structure matches driver work patterns. If conversion is below 50% or if Daily dominates (>60% of conversions), we re-examine pricing and feature differentiation per tier.

**7. Marketplace Latency (Bid Submission → Passenger Render)**

How fast does a submitted bid land on the passenger's screen?

- **Target:** **<800ms p95** round-trip from driver tap-submit to passenger render.
- **How we measure:** Client + server timestamps, captured in PostHog.

The marketplace has to *feel* live. Latency above 1s breaks the illusion.

**8. KYC Throughput**

How long does a driver wait from "I uploaded my docs" to "I'm approved to bid"?

- **Target:** **<24h median KYC approval time**. **<72h p95.**
- **How we measure:** `drivers.kyc_status` transition timestamps captured in `audit_logs`.

Slow KYC is a leak in the driver acquisition funnel. Drivers who wait 5+ days for approval don't come back.

**9. Cash vs Wallet Payment Mix**

What percentage of completed trips use wallet vs cash?

- **Target:** **40%+ wallet share** by month 6 (we expect cash to dominate at launch and wallet share to grow).
- **How we measure:** Count of `trips.payment_method` grouped by month.

If cash stays at 95%+, our wallet build doesn't pay back its complexity. We need wallet adoption to justify the engineering investment.

**10. Driver Acceptance Rate**

What percentage of ride requests does a driver see + bid on?

- **Target:** **40%+ bid rate** on viewable requests. (This is a marketplace, not a dispatch — drivers can be picky. But too low means the requests aren't priced right.)
- **How we measure:** (Bids submitted / requests visible to driver) × 100, tracked per-driver and aggregated.

### Lagging Indicators (Long-Term Business Health)

**11. Driver NPS**

Would Drivio drivers recommend the platform to other Lagos drivers?

- **Target:** **NPS of 50+** by month 6. (Uber/Bolt sit at -10 to +10 with Lagos drivers.)
- **How we measure:** Quarterly in-app NPS survey: "How likely are you to recommend Drivio to another driver?" on a 0–10 scale.

Driver word-of-mouth is our acquisition channel. High NPS = organic growth.

**12. Passenger NPS**

Same question, passenger side.

- **Target:** **NPS of 40+** by month 6.
- **How we measure:** Quarterly in-app NPS survey.

**13. Monthly Recurring Revenue (MRR)**

- **Target:** **₦45M+ MRR** by month 6 (blended-tier mix of 55% Monthly / 30% Weekly / 15% Daily across 1,000 active drivers). **₦135M MRR** by month 12 (3,000 drivers, same tier mix).
- **How we measure:** Sum of active subscription billings from Paystack dashboard.

**14. Cost Per Driver Acquisition (CPA)**

How much do we spend to acquire one verified, subscribed driver?

- **Target:** **<₦15,000 CPA** at launch, **<₦8,000** by month 6 as organic growth kicks in.
- **How we measure:** Total acquisition costs (event spend + marketing + referral payouts) ÷ new active subscribed drivers.

**15. Driver LTV (Lifetime Value)**

How much subscription revenue does the average driver generate before they churn?

- **Target:** **₦480,000+ LTV** (12 months × ~₦40,000 blended-tier average revenue per driver).
- **How we measure:** Total subscription revenue from churned drivers ÷ number of churned drivers.

CPA must be well under LTV for unit economics to work. Right now we model LTV/CPA ≥ 4×.

**16. Dispute Rate**

What percentage of completed trips result in a dispute?

- **Target:** **<2% dispute rate** on completed trips. **<24h median resolution time.**
- **How we measure:** (Disputed trips / completed trips) × 100, dispute lifecycle tracked in admin dashboard.

Disputes erode trust. High dispute rate = bad pool quality or bad UX.

**17. Audit Chain Integrity**

Has the audit log ever been tampered with?

- **Target:** **Zero** chain-integrity breaks.
- **How we measure:** Daily verifier walks the SHA-256 chain. Any mismatch pages on-call.

Non-negotiable. Audit log integrity is the foundation of operational trust.

---

## 8. Assumptions & Dependencies

Let's talk about what we're betting on and what we need to go right.

### Assumptions (What We're Betting On)

**1. Lagos has the supply density for an auction marketplace.** We're assuming there are at least 5 active drivers per geohash6 cell (~1.2km × 0.6km) during peak hours in 80% of Lagos. If density falls below that, passengers see too few bids and the marketplace feels broken. We mitigate by phasing the launch (Lekki, Yaba, Ikeja first) and concentrating driver acquisition events in those zones.

**2. Lagos drivers want to set their own prices.** This is the philosophical bet. We're assuming drivers will see the autonomy of pricing their own rides as a feature, not a chore. Some drivers might prefer the "just give me trips" simplicity of Uber. We mitigate via sane default pricing in `driver_pricing_profile` so a driver who doesn't want to think can let suggested fares carry them.

**3. Passengers will tolerate a 60-second wait.** Uber promises a price instantly. We make passengers wait 60 seconds for bids to land. We're assuming the wait feels alive (count-of-bids, animations, countdown) and that the resulting choice is worth it. If passenger abandonment on `/waiting` exceeds 30%, we know we have a problem.

**4. The 3-tier subscription structure (₦2,500/day, ₦15,000/week, ₦50,000/month) matches Lagos driver work patterns.** Daily is for occasional / testing drivers; Weekly is the default for most active drivers; Monthly is for full-time drivers and has the cheapest per-day rate. We mitigate by reviewing the tier mix in month 6 — if 60%+ of drivers pick Daily (signalling distrust of longer commitment) or Monthly is under 30% adoption, we re-examine pricing levels and feature differentiation. We also model the unit economics so each tier remains a better deal than Uber's 25% commission at the workload it's designed for.

**5. Wallet adoption will follow cash.** We expect cash to dominate at launch (80%+) and wallet share to grow as passengers experience the convenience of one-tap payment. If wallet share stays below 25% at month 6, we add incentives (first-trip discounts on wallet payments, top-up bonuses).

**6. Paystack will be reliable.** Our subscription billing, payouts, and wallet top-ups all flow through Paystack. We expect 99.5%+ uptime. We mitigate with Flutterwave failover for activations (renewals still flow through Paystack to preserve the dunning state machine).

**7. Supabase Realtime can handle Lagos-scale concurrency.** At 1,000 active drivers + 5,000 active passengers + ~10k concurrent active sessions, we're testing the upper end of what Supabase Realtime is built for. We load-test pre-launch (PLAT-099) and have a path to self-host Phoenix Channels if Supabase becomes the bottleneck.

**8. BVN/NIN coverage is high enough.** We assume 95%+ of prospective drivers can pass BVN + NIN verification via Dojah. If coverage gaps emerge (e.g., drivers without NIN), we'd add a manual review path.

**9. Lagos drivers are reachable through trade associations and mechanic networks.** Our v1 acquisition strategy is event-based: meetups with driver associations, partnerships with fuel stations and mechanic networks. We're betting these channels reach enough drivers to seed the marketplace in the first 3 months.

**10. Drivers will tolerate the KYC friction.** BVN + NIN + selfie + liveness + 5 document uploads is a lot. We're betting that the autonomy + earnings story makes it worth the friction. If we see >40% drop-off during onboarding, we'll re-examine which steps are negotiable.

### Dependencies (What Needs to Happen for Us to Succeed)

**Technical Dependencies:**

- **Supabase project provisioning.** Single shared project (`gxzyednqegqycnmbdghf`). Production sizing and Realtime tier upgrade pre-launch.
- **Paystack merchant account approval.** We need Paystack to approve our merchant onboarding for subscriptions + transfers + wallet collections. Could take 2–3 weeks.
- **Flutterwave secondary merchant account** for failover.
- **Termii SMS integration** with sufficient credit (~₦8/SMS × OTP volume estimates).
- **Dojah API agreement** for BVN, NIN, liveness checks. Pricing typically ₦40–₦60 per verification.
- **MapLibre + OpenFreeMap reliability.** No dependency on Google Maps for in-app navigation — we use MapLibre for both apps and OpenFreeMap for tiles (no API key, no quota).
- **Google Places API key** for the server-side proxy (autocomplete + reverse geocoding only).
- **App Store + Google Play approvals.** Both apps need approval. Typically 1–2 weeks per store; could be longer for ride-hailing.

**Team Dependencies:**

- **Backend lead must finish core schema + RLS + realtime topology before mobile can integrate.** This is the longest pole in the tent.
- **Designs locked early.** Both Flutter apps and the admin dashboard share a design language; design delays push all three streams.
- **A single KYC review team trained and ready** for launch day. Hiring + training takes ~6 weeks.
- **Ops Lead identified and onboarded** to use the admin dashboard from day 1.
- **Customer-support staff** (email + WhatsApp) trained on common issues + escalation matrix.

**External Dependencies:**

- **LASTMA / Lagos State Government coordination** for service-area definition and dispute-of-record contacts.
- **Driver associations** (NURTW, RTEAN where applicable) for awareness and partnership.
- **Mechanic network partnerships** for vehicle inspection report acceptance.
- **Legal review** of terms of service, privacy policy, NDPR compliance.
- **App store classification** as a ride-hailing app (subject to additional review on both iOS and Android).

**Business Dependencies:**

- **Capital runway** for 12 months minimum. Driver acquisition events, KYC team salaries, infra, marketing.
- **Compensation pool funding** (PLAT-018). We need a budget line for cancellation compensation payouts. Modelled at ~₦20 per trip on average (5% cancel rate × ₦400 average payout).
- **Driver-side referral budget** for the inevitable post-launch referral program.
- **Ops escalation budget** for the 24/7 SOS line, including LASTMA/police coordination retainers.

---

## 9. Risks

Let's be honest about what could go wrong and how we plan to handle it.

| Risk | Impact | Likelihood | How We'll Handle It |
|---|---|---|---|
| **Cold start: not enough drivers in early zones, passengers see zero bids and churn** | High | High | Phased launch — concentrate driver acquisition events in 3 zones (Lekki, Yaba, Ikeja) before opening city-wide. Don't enable passenger app outside seeded zones at first. Seed minimum 200 drivers per zone before opening to passenger sign-ups in that zone. |
| **Drivers don't see Drivio Pro as worth paying at any tier** | High | Medium | Track trial-to-paid conversion weekly + tier mix at conversion. If conversion <50% by month 9, test price reductions per tier OR add tier-differentiated features (Monthly gets priority placement in the marketplace?). Build coach-tips + insights features (DRV-074) so drivers see the value during their trial. |
| **Tier mix skews to Daily (>60%), implying drivers don't trust longer commitment** | Medium | Medium | This signal would mean drivers see Drivio as ride-hailing-side-hustle, not a primary platform. Mitigate via in-app messaging during the trial showing "Monthly would save you ₦X based on your activity"; gate certain features (e.g., demand heatmap full access, or priority dispatch radius) to Weekly+ tiers. |
| **Supabase Realtime can't sustain 1k concurrent drivers per zone** | High | Medium | Load-test pre-launch (PLAT-099) at 2× projected peak. Shard further by sub-geohash if needed. Have a Phoenix Channels self-host plan ready (1–2 weeks engineering effort to migrate marketplace channels off Supabase). |
| **Paystack outage breaks subscription renewals or wallet top-ups** | High | Medium | Flutterwave fallback for activations. Pause renewal dunning during confirmed Paystack outages (don't auto-deactivate drivers because of our PSP). Ops dashboard surfaces webhook lag for manual reconciliation. |
| **Marketplace gaming: drivers coordinate to bid artificially high in a zone** | Medium | Medium | Marketplace monitoring + anomaly detection in admin (Epic 18). Random sampling of zones for "expected price" benchmarks. Driver risk-score flag for outlier pricing patterns. Subscription suspension as ultimate enforcement. |
| **Passenger cancellation gaming (book → cancel for free) bleeds the compensation pool** | Medium | Medium | Track passenger cancel rate. Flag passengers >30% cancel rate for human review. Soft-warn at 20%; suspend ability to book at 50%. Compensation pool budget tracked in admin dashboard with daily burn-rate alerts. |
| **iOS background suspension stops driver location streaming during trips** | High | High | Foreground service / Live Activity / significant-location-change combo (DRV-036). Heavy iOS testing on real devices pre-launch. Stale-driver-signal banner on passenger side (current implementation triggers at 15s). |
| **KYC bottleneck: drivers wait 5+ days for verification, churn before they bid once** | High | Medium | Set ops SLA at <24h median. Hire 2 part-time reviewers at launch, scale to 4 by month 3. Auto-decline obvious fails (e.g., expired docs) without manual review. Plan to add Dojah ML-assisted verification post-MVP. |
| **Driver client modding: a driver fakes their GPS to claim trips they can't reach** | Medium | Medium | All location writes go through `update-presence` edge function (PLAT-003) which validates plausibility (Δ from previous fix consistent with `speed_kph`). Rate-limit to 4Hz. Pattern detection in admin risk feed. |
| **Lagos passengers reject "no card on file" and abandon the funnel** | Medium | Low | We don't think this is high-risk — Nigerian payment culture skews wallet/cash heavy. Track sign-up-to-first-ride conversion. If wallet adoption is the bottleneck, push first-trip wallet credit (₦500 on top-up) as a launch incentive. |
| **Driver compensation pool drains faster than projected** | Medium | Medium | Cap individual driver compensation at ₦2,000 per cancellation. Behavioural detection of gaming passengers (per the cancel-rate flag above). Reserve budget tracked daily; ops alert at 30-day burn projection > monthly budget. |
| **App Store rejection (ride-hailing apps face extra scrutiny)** | Medium | Medium | Engage Apple Developer Relations early. Submit test builds 3 weeks before public launch deadline. Get legal sign-off on terms of service and KYC flows. Have a contingency for 1-week approval slippage. |
| **Realtime channel sprawl as features grow** | Medium | Medium | The `realtime/CHANNELS.md` registry is the discipline — every new channel reviewed in PR. Operational dashboard tracks channel count and concurrency. |
| **Driver acquisition through events doesn't scale beyond Lagos zone 1** | Medium | Medium | Build a referral program in v1.1 (driver-refers-driver, ₦5,000 credit to both on KYC completion). Partner with mechanic networks and fuel station chains for distribution. |
| **Sentry/PostHog not actually catching production issues at launch** | High | Low | Make Sentry/PostHog wiring a P0 blocker before launch. Run a fire drill 2 weeks before launch to confirm error events show up in Sentry and funnel events show up in PostHog. |
| **Cash dispute volume overwhelms support** | Medium | Medium | Auto-settle cash disputes after 24h favouring the driver (configurable from admin). Surface dispute volume in admin daily summary. Build dispute macros to keep support throughput high. |
| **NDPR / regulatory enforcement scrutiny** | Medium | Low | Legal review pre-launch. NDPR Article 23 (erasure) and Article 26 (DPO) fulfilled by DSAR pipeline + consent ledger. Phone numbers normalized to E.164, PII tagged at the schema layer, default-masked in admin rendering. |
| **Audit chain integrity break (data corruption or tampering)** | High | Low | Daily verifier walks the chain, alerts on mismatch. Hash chain + offline backups. Audit retained 7 years (CBN compliance). |
| **Timeline slips — small team can't ship all three apps simultaneously** | High | Medium | The 5 core flows are non-negotiable: driver onboarding → go-online → marketplace bidding → trip lifecycle → wallet/payout. Everything else can be simplified or post-MVP. Weekly check-ins to catch slippage early. Ruthless prioritisation; cut features before missing launch date. |

---

## 10. Budget & Resources

Let's talk about what this actually costs in people, time, and money.

### Team Resources

We're running lean for v1. Here's what we need:

**Core Engineering Team:**

- **Backend Lead (Supabase + Postgres + Realtime + Edge Functions):** 1 senior engineer, full-time, 8 months. Owns schema, RLS, realtime topology, edge functions, Paystack/Termii/Dojah integrations, cron workers, observability.
- **Mobile Engineering Lead (Flutter):** 1 senior engineer, full-time, 8 months. Owns the architecture across both Flutter apps (passenger + driver). Shared widget library, theme system, mutation queue, realtime client.
- **Mobile Engineer #2 (Flutter):** 1 mid-to-senior engineer, full-time, 6 months. Builds out features on one of the two apps (passenger or driver).
- **Mobile Engineer #3 (Flutter):** 1 mid engineer, full-time, 6 months. Builds out features on the other Flutter app.
- **Frontend Lead (Next.js 16 + React 19):** 1 senior engineer, full-time, 6 months. Owns admin dashboard architecture (Server Components, Server Actions, RBAC HOFs, audit-log integration).
- **Frontend Engineer #2 (Next.js):** 1 mid engineer, full-time, 5 months. Builds out admin dashboard modules.
- **Product Designer:** 1 senior designer, full-time, 6 months. Owns design language across all three apps, motion design, accessibility, illustrations.
- **Product Manager:** 1 PM, full-time, the whole time. Requirements, stakeholder communication, launch plan, ops coordination.
- **DevOps / SRE:** 1 engineer, part-time (50%), 8 months. Supabase production setup, Sentry/PostHog deployment, log aggregation, on-call runbooks, app store publishing.

**Operations Team (ramping pre-launch):**

- **Ops Lead:** 1 full-time, joins month 4. Establishes ops playbooks, KYC review SOP, dispute resolution flows.
- **KYC Reviewers:** 2 part-time at launch, scales to 4 by month 3 based on driver acquisition velocity. Could be contractors initially.
- **Support L1:** 2 full-time at launch, handling email + WhatsApp. Scales with active driver/passenger count.
- **Risk Analyst:** 1 part-time (50%) at launch. Monitors marketplace gaming, cash disputes, fraud signals.
- **24/7 SOS Coordinator (third-party security firm retainer):** Always-on escalation path for safety events.

**Supporting Roles:**

- **QA Engineer:** 1 full-time for 6 weeks pre-launch. Comprehensive testing across all three apps + admin + payment flows + KYC.
- **Legal Counsel:** Contract engagement for terms of service, privacy policy, NDPR compliance, app store classification.
- **Driver Acquisition Lead:** 1 full-time from month 4. Owns driver-side go-to-market — events, partnerships, referral programs.

### External Costs

**Development & Infrastructure (Monthly Estimates):**

- **Supabase Pro plan:** ~$25/month starting, scaling with Realtime concurrency and DB CPU. Expect ~$300–$500/month by month 6 based on projected concurrency.
- **Sentry Team plan:** ~$26/month + per-event overage.
- **PostHog Cloud:** ~$0 for first 1M events/month, then scales.
- **MapLibre + OpenFreeMap:** Free (open-source tiles).
- **Google Places API (for proxy):** ~$0.005 per autocomplete session. Modelled at ~$200/month at projected volume; cached aggressively in `place_cache`.
- **Dojah BVN/NIN/liveness:** ~₦40–₦60 per verification. At 100 new drivers/week, ~₦25,000/week. Most expensive per-unit dep.
- **Termii SMS:** ~₦8/SMS. At 200 new sign-ups/day (drivers + passengers), ~₦50,000/day.
- **Paystack fees:** Subscriptions: 1.5% capped at ₦2,000 per charge. Transfers (driver payouts): ₦50 fixed fee per transfer. Wallet top-ups: 1.5% + ₦100.
- **Flutterwave (fallback):** Similar to Paystack.
- **FCM:** Free.
- **App Store fees:** $99/year (Apple Developer) + $25 one-time (Google Play). Per app, so $99 × 2 = $198/year + $25 × 2 = $50 one-time.
- **Domain + SSL:** ~$15/year for drivio.app or similar.

**Operations:**

- **KYC review labour:** Modelled at 6 minutes per verification × 100 new drivers/week ÷ 60 = 10 hours/week per reviewer. At 4 reviewers × ₦200,000/month × 6 months = ₦4.8M.
- **Support team labour:** 2 L1 support × ₦300,000/month = ₦600,000/month, scaling with volume.
- **Risk + ops lead:** ₦600,000–₦1.2M/month per role.
- **Legal review:** [PLACEHOLDER] one-time.
- **Driver acquisition events:** [PLACEHOLDER]. Estimated ₦200,000 per event (venue, refreshments, materials) × 8 events in first 6 months = ₦1.6M.
- **Marketing / brand:** [PLACEHOLDER].
- **Driver compensation pool (PLAT-018):** Modelled at ~₦20/trip × 50,000 trips/month = ~₦1M/month by month 6.
- **24/7 SOS retainer:** [PLACEHOLDER]. Estimate ₦300,000/month for a security firm partnership.

### Contingency

- **Unexpected costs buffer:** 20% of total external costs. Lagos-specific ops always cost more than you model.

### Total Estimated Cost

**Team Resources (Opportunity Cost):**
- ~50 person-months of engineering + design across 8 months.

**External Costs (First Year):**
- Setup / one-time: [PLACEHOLDER] (legal, app fees, initial marketing)
- Monthly recurring (steady-state by month 6): ~₦4–6M/month (infra + ops + KYC + compensation pool)
- First-year total external: ~₦40–55M (modelled, will refine as we go).

Actual costs depend heavily on driver acquisition velocity, marketplace volume, and the compensation pool burn rate. These are estimates; we'll refine monthly.

---

## 11. Timeline & Milestones

We started building in February 2026 and we're targeting a public launch in August 2026. That gives us roughly 6 months. Here's the plan.

| Milestone | Target Date | Owner | Status |
|---|---|---|---|
| Project kickoff + initial planning | February 2026 | Product Owner + Eng Leads | ✅ Complete |
| Driver app prototype (Flutter, 39 screens, no backend) | March 2026 | Mobile Lead | ✅ Complete |
| Passenger app prototype (Flutter, 23 screens, no backend) | March 2026 | Mobile Lead | ✅ Complete |
| Supabase schema v1 + RLS baseline | April 2026 | Backend Lead | ✅ Complete |
| Driver app real backend integration (auth, KYC, vehicle, marketplace) | April–May 2026 | Mobile Lead | ✅ Complete |
| Passenger app real backend integration (auth, request, bids, accept, trip) | May 2026 | Mobile Lead | ✅ Complete |
| Subscription gate + 90-day trial (DRV-027 + DRV-032) | May 2026 | Backend + Mobile Lead | ✅ Complete |
| MapLibre + OpenFreeMap integration on both apps | May 2026 | Mobile Lead | ✅ Complete |
| Wallet top-up + payout flows (passenger + driver) | May 2026 | Backend + Mobile | ✅ Complete |
| Driver app analytics + coach tips + demand heatmap | May 2026 | Mobile Lead | ✅ Complete |
| **BRD / PRD finalized** | **May 31, 2026** | **Product Owner** | **🔄 In Progress (this document)** |
| Admin dashboard kickoff (Next.js 16 scaffolding) | June 2026 | Frontend Lead | 🔜 Upcoming |
| Admin RBAC + audit log + KYC review queue | June 2026 | Frontend Lead | 🔜 Upcoming |
| Admin dispute inbox + marketplace monitoring + risk feed | June–July 2026 | Frontend Lead | 🔜 Upcoming |
| Admin subscription mgmt + payout dashboard + reconciliation | July 2026 | Frontend Lead | 🔜 Upcoming |
| Real Termii SMS OTP (replace dev stub) | June 2026 | Backend Lead | 🔜 Upcoming |
| Cash settlement flow (PLAT-017) | June 2026 | Backend Lead | 🔜 Upcoming |
| Driver compensation pool (PLAT-018) | June 2026 | Backend Lead | 🔜 Upcoming |
| Masked voice calls integration (Africa's Talking) | July 2026 | Backend Lead | 🔜 Upcoming |
| Server-backed chat | July 2026 | Backend + Mobile | 🔜 Upcoming |
| Real Paystack subscription + payout (replace dev mode) | July 2026 | Backend Lead | 🔜 Upcoming |
| Dojah BVN/NIN/liveness integration (replace stubs) | July 2026 | Backend Lead | 🔜 Upcoming |
| Sentry + PostHog wired into both Flutter apps + admin | July 2026 | Mobile + Frontend Lead | 🔜 Upcoming |
| QA pass (all three apps + admin + e2e flows) | August 1–10, 2026 | QA Engineer | 🔜 Upcoming |
| Load testing (Supabase Realtime + Postgres at 2× projected peak) | August 5, 2026 | Backend Lead + DevOps | 🔜 Upcoming |
| Legal docs finalized (terms, privacy, NDPR) | August 10, 2026 | Product Owner + Legal | 🔜 Upcoming |
| App store submissions (driver + passenger, iOS + Android) | August 12, 2026 | Mobile Lead | 🔜 Upcoming |
| Closed beta (25 Lagos drivers + 50 passengers, single zone) | August 15–22, 2026 | Product Owner + Ops | 🔜 Upcoming |
| Driver acquisition event #1 (Lekki) | August 18, 2026 | Driver Acquisition Lead | 🔜 Upcoming |
| App store approvals received | August 24, 2026 | N/A | 🔜 Upcoming |
| **🚀 Public Launch — Lekki/Yaba/Ikeja zones** | **August 26, 2026** | **All Team** | **🔜 Upcoming** |
| Post-launch hypercare + bug-fix sprint | August 26 – September 9, 2026 | All Team | 🔜 Upcoming |
| Expand to remaining Lagos zones | September 2026 | Ops + Driver Acquisition | 🔜 Upcoming |
| First trial-to-paid conversion wave (Sep–Nov sign-ups → Dec–Feb conversion) | November 2026 – February 2027 | Product + Ops | 🔜 Upcoming |
| Driver acquisition program scale-out (referrals + partnerships) | October 2026 onward | Driver Acquisition Lead | 🔜 Upcoming |
| Abuja + Port Harcourt launch (v1.5) | Q2 2027 | All Team | 🔜 Upcoming |

### Critical Path Items (These Cannot Slip)

1. **Admin dashboard core (KYC + dispute + audit) by July 31** — we can't run ops without it; we can't launch without ops.
2. **Real Paystack + Termii + Dojah by July 31** — without these, the apps are stubs and we can't onboard real drivers.
3. **Driver compensation pool (PLAT-018) by August 1** — we can't allow passenger cancellations of in-flight trips without it.
4. **Load testing by August 10** — Supabase Realtime + Postgres at 2× projected peak. If we don't catch scaling issues here, we catch them on launch day.
5. **App store submissions by August 12** — both stores typically need 7–10 days for review; ride-hailing classification can extend this.
6. **Closed beta by August 22** — at least 5 days of real-world testing with paying customers before public launch.
7. **Legal docs by August 10** — non-negotiable for app store submissions and NDPR compliance.

### Contingency Plans If Timeline Slips

- **Behind by 1 week:** Cut admin dashboard advanced features (custom reports, advanced analytics). Launch with core ops modules (user management, KYC, dispute, audit, subscription).
- **Behind by 2 weeks:** Defer server-backed chat to v1.1 (chat continues as local-with-canned-replies). Defer masked voice calls.
- **Behind by 3+ weeks:** Push launch to September and seriously rebuild the plan. Don't rush a buggy launch in a market this competitive — Uber/Bolt drivers will give Drivio one chance.

The good news: we've been building since February, both Flutter apps are functionally complete on the marketplace + trip + wallet flows, and Supabase backend is largely wired. The remaining work is admin dashboard + production integrations + ops readiness — not foundational rebuilds.

The bad news: the admin dashboard is still early scaffolding. That's a real risk. Weekly check-ins from June onward to catch slippage.

---

## 12. Key Definitions

So we're all on the same page, here's the language we use throughout this document:

**Ride Request:** A passenger's tap on "Find a ride." Creates a `ride_requests` row with `status='open'` and `expires_at = now() + 60s`. Drivers within a 1.8km × 1.2km zone (9 geohash6 cells) receive it via the marketplace broadcast channel.

**Bid:** A driver's proposed price for a specific ride request, with their ETA. One row per `(ride_request_id, driver_id)`. Status moves from `pending → accepted | rejected | expired | withdrawn`.

**Accept Bid:** Passenger picks one bid. A serializable Postgres transaction locks the request, accepts the chosen bid, rejects all sibling bids, marks the request `matched`, and inserts a `trips` row. From here, the auction is closed.

**Trip:** A row in `trips`. Lifecycle: `assigned → en_route → arrived → in_progress → completed | cancelled`. Each transition writes a `trip_events` audit row.

**Drivio Pro:** Our driver subscription, priced in three tiers — Daily ₦2,500 (24h anniversary renewal), Weekly ₦15,000 (7-day anniversary renewal), Monthly ₦50,000 (30-day anniversary renewal). 90-day trial for new drivers, one-time-per-driver. At trial end, driver picks a tier (Monthly is the default suggestion with personalized recommendation based on trial-period activity). Drivers can switch tiers anytime — the switch takes effect at the next renewal cycle. Billed via Paystack. Hard block at expiry (no marketplace access) except for trips already in progress, which always complete.

**Subscription Tier:** One of `daily`, `weekly`, `monthly` — the cadence the driver chose for their Drivio Pro subscription. Stored on `subscriptions.plan_id` (foreign key to `subscription_plans`). A pending tier switch is stored on `subscriptions.pending_plan_id` and activates at the next renewal.

**Renewal Anniversary:** The moment a tier auto-renews is exactly N hours after the last successful charge, not aligned to calendar boundaries. Daily = 24h, Weekly = 168h (7 days), Monthly = 720h (30 days). A driver who pays at 23:00 Monday renews at 23:00 Tuesday (Daily) / next Monday (Weekly) / 30 days later (Monthly). This avoids penalizing late-day signups and keeps the metric predictable across timezones.

**Subscription Gate:** Server-side check (`is_driver_active(user_id)`) at three points — go-online, marketplace channel subscribe, bid submission. Returns false for `expired | cancelled`; true for `trialing | active | past_due` (past_due is the 3-day Paystack grace).

**Wallet:** Closed-loop NGN value store keyed by `user_id` and discriminated by `owner_kind` (`driver | passenger`). Driver wallets accrue trip credits, debit at payout. Passenger wallets accrue top-ups, debit at trip completion.

**Wallet Hold:** ₦100 reserved from the passenger's wallet at the moment they accept a bid. Reversed on cancellation; converted to a real debit at trip completion (where the full fare moves).

**Compensation Pool:** Platform-funded reserve used to pay drivers when a passenger cancels post-acceptance and the driver was en route. Funded from the subscription revenue line.

**Geohash6 Zone:** The marketplace fanout cell. ~1.2km × 0.6km in Lagos. Drivers subscribe to their current cell + 8 neighbours (so the effective marketplace radius is ~1.8km × 1.2km).

**Marketplace Broadcast:** Supabase Realtime broadcast channel keyed by `marketplace:zone:<geohash6>`. When a ride request lands in a cell, every subscribed driver gets the request payload in <500ms.

**KYC Status:** A driver's verification state. Values: `not_started → in_progress → pending_review → approved | rejected`. The 90-day trial is auto-created when status flips to `approved`.

**Service Area:** The geographic boundary of where Drivio operates. v1 = Lagos State polygon. Server-side check in `create-ride-request` enforces this.

**Audit Chain:** The hash-chained append-only audit log in the admin database. Every consequential admin action writes a row. A daily verifier walks the SHA-256 chain and alerts on mismatch.

**Dispute:** A passenger or driver report against the other party for a specific trip. Triaged in the admin dispute inbox. Status: `open → in_review → resolved (driver_favoured | passenger_favoured | split)`.

**Active Driver:** A driver with `is_active = true`, KYC `approved`, subscription `trialing | active | past_due`, and at least one bid submitted in the trailing 14 days.

**Bid Window:** The 60-second period after a ride request is created during which drivers can submit bids. Closes automatically; late bids return 409.

**Decision Window:** An additional 60-second period after the bid window closes during which the passenger can pick from any bids that landed. If no bid is picked by the end of this window, the request expires and the passenger lands on the no-drivers edge state.

**Pickup Geohash6:** The geohash6 cell of the pickup point on a ride request. A generated column on `ride_requests`. Used for fanout.

---

## Version History

| Version | Date | Author | Changes Made |
|---|---|---|---|
| 1.0 | May 31, 2026 | [Product Owner] | Initial BRD creation covering the full Drivio ecosystem (Passenger + Driver + Admin) for Lagos MVP launch. |

---

**END OF DOCUMENT**

Questions? Feedback? Push back on any of the assumptions? Let's talk about them — none of this is set until we ship.
