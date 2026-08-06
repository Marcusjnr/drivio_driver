# Subscription pause cap — 14-day cumulative, Monthly-only

**Date:** 2026-07-27
**Status:** Approved (design)
**Scope:** Driver app + Supabase migration. No admin-dashboard UI in this pass.

## Problem

Today a driver can pause a paid subscription indefinitely (`pause_my_subscription`
sets `paused_at`; `resume_my_subscription` shifts the period endpoints forward by
the paused duration — no cap). We want:

1. A driver may pause only up to **14 cumulative days** within a single
   subscription period.
2. While paused, the app shows a **countdown of pause-days remaining** with
   appropriate copy; the paid clock is frozen.
3. When the 14 cumulative days are exhausted, the subscription **resumes counting
   down automatically**.
4. Once exhausted, the driver **cannot pause again** until the subscription
   period is completed.
5. The allowance **resets on renewal** — they can pause again on the next period.

Decisions taken during brainstorming:
- **Monthly tier only.** A 14-day cap is longer than a Daily (1d) or Weekly (7d)
  period. Enforced via per-plan config (`max_pause_days`): Monthly = 14, others
  = 0 ⇒ not pausable.
- **Cumulative with early resume + re-pause.** The driver can pause, resume
  early, and pause again, until 14 cumulative paused days are used this period.
- **Admin-configurable cap** stored on the plan. (Admin *UI* is a fast-follow;
  this pass sets Monthly = 14 via migration.)

## Key constraint: no scheduler

This system has **no server-side scheduler**. Lapsed and paused states are
*derived* from timestamps at read time (`Subscription.effectiveStatus`,
`is_driver_active`), never flipped by a cron. Therefore "auto-resume when 14 days
are up" must also be **derived**, not an event.

## Approach B — immutable endpoints + a pause ledger (chosen)

`current_period_end` never moves. We track one counter,
`pause_seconds_used` (cumulative *finalized* paused time this period), and always
derive:

```
cap_seconds          = plan.max_pause_days * 86400
in_progress          = paused_at IS NULL ? 0
                       : LEAST(now - paused_at, cap_seconds - pause_seconds_used)
effective_pause      = LEAST(pause_seconds_used + in_progress, cap_seconds)
effective_period_end = current_period_end + effective_pause
pause_exhausted      = (pause_seconds_used + in_progress) >= cap_seconds
pause_seconds_left   = GREATEST(cap_seconds - pause_seconds_used - in_progress, 0)
```

Everything — gating, countdown, expiry — derives from `effective_period_end`.
Pausing only sets `paused_at`; resuming only adds the capped delta to
`pause_seconds_used`. No endpoint shifting, no overlay/mutation disagreement.

Rejected **Approach A** ("shift endpoints on resume") because a cap that elapses
while the app is closed leaves the endpoints unshifted, forcing a derivation
overlay *on top of* the mutation path — two sources of truth that can disagree.

### Worked example (Monthly, 30-day period, cap 14d)

- Day 0: period_end = day 30. 30 days left.
- Day 10: pause. `used=0`, `paused_at=10`.
- Day 15 (5d paused): `eff_end = 30 + 5 = 35`, now 15 → **20 left, frozen** (= 30−10). ✓
- Resume day 15: `used=5`, `paused_at=null`. `eff_end = 35`, 20 left, counting. ✓
- Pause again day 20 (allowed, 5 < 14): `paused_at=20`.
- Day 29 (9 more, total 14): `eff_end = 30 + 14 = 44` (capped), 15 left, frozen.
- Day 30+: cumulative would exceed 14 → capped → **auto-resumes**; `is_driver_active`
  unlocks even though the row still reads `paused`; countdown proceeds to day 44,
  then grace, then expired — all derived. ✓

## Data model

- `subscription_plans.max_pause_days int` (nullable). Monthly = 14; Daily/Weekly
  = 0/null ⇒ not pausable. Converted to seconds server-side.
- `subscriptions.pause_seconds_used bigint NOT NULL DEFAULT 0` — cumulative
  finalized paused time this period; reset to 0 whenever a new period starts.

## Server RPCs

- **`pause_my_subscription`** — new guards, in addition to the existing
  (active-only, no active trip, flip presence offline):
  - plan not pausable (`max_pause_days` null/0) → `not_pausable`.
  - allowance exhausted (`pause_seconds_used >= cap_seconds`) → `pause_exhausted`.
- **`resume_my_subscription`** — no endpoint shift. Credit the capped delta:
  `pause_seconds_used += LEAST(now - paused_at, cap_seconds - pause_seconds_used)`,
  clear `paused_at`, status → `active`. (Trial pausing stays disallowed, so the
  old trial-endpoint-shift branch is dropped.)
- **`is_driver_active`** — add a `paused` branch: unlock **iff**
  `(pause_seconds_used + elapsed) >= cap_seconds` **and**
  `now <= current_period_end + cap_seconds + grace`. A genuinely-still-paused
  driver stays locked; an auto-resumed one unlocks.
- Subscription reads must return `pause_seconds_used` and the plan's
  `max_pause_days` (the app selects the `subscriptions` row directly and can join
  the plan; expose `max_pause_days` alongside the plan fields it already reads).

## Client (driver app)

- `SubscriptionPlan` gains `maxPauseDays`; `Subscription` gains
  `pauseSecondsUsed`.
- `Subscription.effectiveStatus` and `daysRemaining` fold in `effective_period_end`
  (so a paused-exhausted driver reads as active with the right countdown). New
  getters: `pauseDaysLeft`, `pauseExhausted`, and a `canPause` that also requires
  a pausable plan and remaining allowance.
- **Auto-finalize on load:** if the client derives that a paused subscription has
  exhausted its cap, it silently calls `resume` once to reconcile the row. This is
  the no-scheduler finalization — cheap and safe (resume on an already-active row
  no-ops via the `not_paused` guard, which the client ignores).
- **`_PausedBanner`** leads with the pause countdown, e.g.
  *"Paused · 9 pause-days left"* + *"Paid days are frozen — 20 left. Resume
  anytime, or you'll auto-resume when your pause days run out."*
- **`_PauseResumeButton`**: when active with allowance remaining, show
  *"You can pause for up to N more days this cycle"*; when exhausted, replace the
  button with *"You've used all 14 pause days this cycle. Pausing is available
  again when your plan renews."*
- Pause confirm sheet copy updated to mention the cap and cumulative nature.

## Renewal reset

`pause_seconds_used` must be reset to 0 whenever a fresh period begins. Real
Paystack renewal isn't built yet; the reset lives in the activation/renewal path
(currently `activate_subscription_dev_mode` / whatever seeds the next period) so
it's correct the moment renewal exists.

## Out of scope

- Admin-dashboard field to edit `max_pause_days` (fast-follow).
- Any new scheduler / background job.
- Daily/Weekly pausing.

## Files

- Migration: `drivio_backend/supabase/migrations/<ts>_subscription_pause_cap.sql`
  (mirrored + applied to project `gxzyednqegqycnmbdghf`).
- `lib/modules/commons/types/subscription.dart` — model + derivation.
- `lib/modules/subscription/features/manage/presentation/ui/subscription_manage_page.dart`
  — banner + button + confirm copy.
- Subscription controller / repository — surface `pauseSecondsUsed` +
  `maxPauseDays`, auto-finalize call.
