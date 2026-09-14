# KYC/Vehicle Document Rejection — Guided Re-upload

**Status:** Approved for planning
**Date:** 2026-09-14

## Problem

When an admin rejects a driver's document, a push notification goes out, but
nothing inside the app tells the driver what happened or why:

1. **The home banner never shows a rejection.** `drivers.kyc_status` has a
   `rejected` enum value and the app already has fully-built UI for it (a red
   "REJECTED" pill, a checklist with "Re-do" rows in `KycGateSheet`) — but no
   backend code path ever actually sets that value. It's vestigial: a 2026-09
   migration comment explicitly says `kyc_status` is "deliberately NOT
   demoted" for an already-approved driver on a single rejection, and no
   other code sets it to `rejected` either. Result: **zero drivers in
   production have `kyc_status = 'rejected'`** today, so the built rejection
   UI never fires. A driver with a live rejection sees generic "under
   review" copy forever.

2. **Vehicle-document rejection forces a full blank restart, and duplicates
   the vehicle.** Rejecting registration or any vehicle photo routes the
   driver into the full 3-step "Add Vehicle" wizard. That wizard's draft
   (`vehicle_onboarding_drafts`) was deleted the moment the *original*
   submission succeeded — rejection happens later, during admin review — so
   the wizard hydrates to a blank state: every vehicle field, every photo,
   re-entered from scratch. Worse, resubmission calls the same
   `VehicleRepository.addVehicle()` used for a brand-new vehicle, which does
   a plain `INSERT` with no update path and no unique constraint on plate —
   so it **creates a second vehicle row** instead of fixing the rejected
   one. This is live: one driver has 6 duplicate vehicle rows, several have
   2–4. 17 drivers are currently blocked on a rejected registration alone
   (plus 12 on a rejected selfie, 5 on a rejected license).

3. **Insurance, roadworthiness, and the 4 vehicle photos have no per-item
   status at all.** `KycController._buildSteps` only inspects
   `DocumentKind.vehicleReg` for the "vehicle" checklist step — a rejected
   photo produces zero visible signal anywhere.

4. **The rejection push notification is a dead end.** It carries
   `document_kind` in its data payload, but no client code reads that on
   tap — it just opens the app to wherever it would normally land.

## Scope

In scope: driver's license, profile selfie (liveness), vehicle registration,
and the 4 vehicle photos (front/back/side/interior) — the document kinds
that go through actual admin review and can be `rejected` with a reason.

Out of scope: BVN/NIN verification. It's synchronous (YouVerify), pass/fail
in the same screen, with no persisted "rejected, come back later" state —
nothing to guide a driver back to.

Also out of scope (confirmed with the user): blocking or otherwise touching
`drivers.kyc_status` semantics, and any change to the admin dashboard (a
separate codebase).

## Design

### 1. Detecting rejection without touching `kyc_status`

A new RPC, `get_my_rejected_documents()`, security-definer, scoped to
`auth.uid()`. For each of the 6 in-scope document kinds, it looks at that
kind's **latest row** (same "latest per kind wins" rule the backend already
uses in `kyc_latest_document_per_kind` for approval — reuse that pattern
exactly, don't reinvent it) and returns the ones currently `rejected`:

```sql
-- shape: one row per currently-rejected document kind
{ kind: document_kind, rejection_reason: text, vehicle_id: uuid | null }
```

`vehicle_id` is populated for `vehicle_reg`/photo kinds so the client can
load the right vehicle without a second round trip.

Client-side, `KycController` (or a small sibling) exposes
`hasRejectedDocuments` / `rejectedItems` derived from this RPC. This is
**purely additive** — no existing column's meaning changes, nothing the
admin dashboard reads is touched.

### 2. Home banner + every other place vehicle/document status is shown

Banner logic (`drive_shell_page.dart`'s `_KycBanner`) gains a new branch,
checked **before** the existing `inReview`/`approved`/catch-all logic:

- If `rejectedItems.isNotEmpty` → a distinct "needs attention" banner (not
  the full alarming red REJECTED-from-scratch treatment — an approved,
  driving driver whose license-renewal photo got rejected should not look
  like a brand-new rejected applicant). Tapping it opens the new overview
  screen (§3).
- Otherwise, existing behavior is unchanged.

The same `rejectedItems` signal drives:
- `KycHomePage`'s per-step rows (already has the right plumbing for
  license/selfie; gains it for the vehicle-photo kinds it currently
  ignores).
- Profile hub's vehicle row and any other vehicle-summary surface: when a
  rejection is live for that vehicle, show only the rejected item(s) + its
  reason instead of the normal read-only detail summary. Same treatment,
  every place vehicle details can be seen — not just one screen.

### 3. The guided overview screen

New screen + controller (e.g. `RejectedItemsPage` /
`RejectedItemsController`), reachable from: the home banner, the push
notification (§5), the KYC checklist row, and the profile hub vehicle row.

Behavior:
- On open, fetch `rejectedItems` once and render one row per item (label +
  short reason preview), each tappable.
- Tapping a row navigates to that item's fix screen:
  - **License / selfie** → the existing single-document recapture screens
    (`DocumentViewPage` → `kycDocumentCapture`), which already have the
    right shape (status, reason, "upload a new copy"). They gain a
    prominent rejection-reason display when arriving in this context (they
    can already show `rejectionReason`; today it's rendered but this makes
    it the lead element, not an afterthought, per "stating the reason
    there why it was rejected").
  - **Registration / any photo** → the new vehicle-fix flow (§4).
- On returning from a fix screen having successfully uploaded, that row
  flips to a non-tappable "Uploaded" state (checkmark, muted styling) for
  the rest of this session on this screen — it does not disappear or
  reflow the list, so progress reads clearly against a stable list.
- Once every row is "Uploaded," the screen shows a clear closing state
  ("You're all set — we'll review this shortly") instead of just becoming
  empty.

### 4. Vehicle-fix flow (also fixes the duplicate-vehicle bug)

New screen + controller — **not** `AddVehiclePage`/`AddVehicleController`.
It shares the existing document-upload widgets from that wizard's step 3
but is a much smaller, purpose-built flow:

- Takes the `vehicle_id` from `get_my_rejected_documents()` and the specific
  rejected kind(s) to fix (could be just one photo, could be registration +
  two photos).
- Never re-asks vehicle details or amenities — those weren't what got
  rejected.
- Walks through the rejected kinds one at a time (same hand-holding pattern
  as §3: reason shown, upload, confirm, next), OR — if the overview screen
  already does the one-at-a-time walk — this can be a single-purpose
  "upload this one document" screen invoked per kind, same as the
  license/selfie path. (Left for planning to pick whichever reuses more of
  the existing single-document capture screen; functionally equivalent
  either way.)
- **The fix for the duplicate bug**: on upload, it registers the new
  document row against the **existing** `vehicle_id` — it never calls
  `VehicleRepository.addVehicle()` (which is what creates a new vehicle
  row). Reuses whatever upload+register call `AddVehicleController.submit()`
  already makes per-document today, just pointed at the existing vehicle
  instead of a freshly-inserted one. (Exact existing method name to be
  confirmed during planning — the repository already does this per-document
  registration today as part of `submit()`, it just always follows a fresh
  `INSERT` into `vehicles` first; this flow skips that insert.)

### 5. Push notification deep link

`document_rejected` pushes already carry `document_kind` (and, once added
here, should also carry `vehicle_id` when relevant — a small addition to
the existing `_push_document_rejected()` trigger's payload). Add a handler
alongside the existing `call_push_handler.dart` pattern:
`FirebaseMessaging.onMessageOpenedApp` / `getInitialMessage` checks for
`type == 'document_rejected'` and navigates straight to that kind's fix
screen (license/selfie screen, or the vehicle-fix flow pre-scoped to that
one kind) — not just the overview, since the push is already specific about
which document.

### 6. Cleanup migration for existing duplicate vehicles

One-off migration, run once: for every driver with more than one
non-deleted vehicle row, keep the one with the most approved documents
(tie-break: most recently created), soft-delete (not hard-delete, matching
this schema's existing convention) the rest. This clears the 17+ currently
duplicated drivers into a single clean vehicle each before the fixed flow
ships, so nothing needs manual admin intervention.

## Error handling

- `get_my_rejected_documents()` fails open: any error surfaces as "couldn't
  load your status" with a retry, never silently hides a real rejection nor
  blocks the rest of the home screen from rendering.
- Vehicle-fix upload failures behave like the existing single-document
  capture screen's failure handling (retry in place, no data loss, row
  stays in its "rejected, tap to fix" state on the overview until a real
  success).

## Testing

Primarily manual/integration, since this depends on real Supabase state:
- Reject a license, a selfie, a vehicle photo, and a registration for a
  test driver (via direct SQL, mirroring how the exploration for this spec
  queried "latest document per kind") and confirm: banner shows the new
  state, overview lists exactly those items with correct reasons, fixing
  one flips it to "Uploaded" without affecting the others, vehicle
  resubmission does not create a second `vehicles` row, and re-review
  clears the item from the list on next fetch.
- Confirm an approved, already-driving test driver whose license-renewal
  gets rejected sees the lighter "needs attention" banner, not a full
  REJECTED treatment.
- Confirm the push payload's `document_kind` (and `vehicle_id` where
  applicable) round-trips to the right fix screen.
