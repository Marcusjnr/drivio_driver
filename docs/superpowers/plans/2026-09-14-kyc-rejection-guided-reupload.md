# KYC/Vehicle Document Rejection Guided Re-upload Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** When a driver's document is rejected, show it on the home screen, walk them through fixing only the rejected item(s) with the reason shown, and stop the vehicle re-upload flow from creating duplicate vehicles.

**Architecture:** No backend schema/enum changes. `drivers.kyc_status` is never set to `rejected` by design (a prior migration explicitly avoids demoting an approved driver) and this plan does not change that. Instead, "what's rejected right now" is derived client-side from the *latest* `documents` row per kind — the same rule the backend already uses for `_kyc_evidence_complete`/`_kyc_fully_approved`. A rejected vehicle-related item is fixed by re-registering a new document against the driver's *existing* vehicle id (already a supported parameter on `DocumentRepository.registerDocument`), never by re-running the add-vehicle wizard, which is what created duplicate vehicles today.

**Tech Stack:** Flutter (Riverpod `StateNotifier`), Supabase Postgres (raw SQL migrations via the Supabase MCP tools), existing `DocumentRepository`/`KycRepository` data layer.

## Global Constraints

- Do not set or read `drivers.kyc_status = 'rejected'` anywhere — it's intentionally never written by the backend today (see `20260901140000_selfie_rejection_clears_liveness.sql`'s comment) and this plan does not change that.
- In-scope document kinds are exactly: `drivers_licence`, `profile_selfie`, `vehicle_reg`, `vehicle_photo_front`, `vehicle_photo_back`, `vehicle_photo_side`, `vehicle_photo_interior`. `insurance`, `road_worthiness`, `lasrra`, `inspection_report` are enum values that exist but are not collected by any current UI — never surface them.
- "Latest document per kind wins" — always resolve a kind's current status from its most-recently-created `documents` row for that owner, matching the backend's own `_kyc_evidence_complete`/`_kyc_fully_approved` convention. Never look at older superseded rows.
- An approved, already-driving/online-eligible driver who later gets one item rejected keeps their normal approved experience everywhere except the new rejection signal — never demote them to a full "rejected from scratch" treatment.
- Run `fvm flutter analyze` after every client task and confirm it reports no new issues before committing.
- Project id for all Supabase MCP calls: `gxzyednqegqycnmbdghf`.
- Every SQL migration in this plan must be dry-run verified (a `select`, not the real `update`/`create or replace`) before being applied for real, for anything that mutates data (Task 1).

---

### Task 1: Backend — clean up existing duplicate vehicle rows

**Files:**
- Create: `drivio-backend/supabase/migrations/20260914070000_cleanup_duplicate_vehicles.sql`

**Interfaces:**
- Consumes: nothing (standalone data migration).
- Produces: nothing later tasks import directly, but Tasks 3+ assume each driver has at most one non-deleted `vehicles` row, which this task guarantees.

- [ ] **Step 1: Dry-run the cleanup logic as a read-only query**

Run via the Supabase MCP `execute_sql` tool against project `gxzyednqegqycnmbdghf`:

```sql
with ranked as (
  select
    v.id,
    v.driver_id,
    v.created_at,
    (select count(*) from public.documents d
       where d.vehicle_id = v.id and d.status = 'approved') as approved_docs,
    row_number() over (
      partition by v.driver_id
      order by
        (select count(*) from public.documents d
           where d.vehicle_id = v.id and d.status = 'approved') desc,
        v.created_at desc
    ) as rn
  from public.vehicles v
  where v.deleted_at is null
)
select driver_id, id, approved_docs, created_at, rn
from ranked
where driver_id in (
  select driver_id from public.vehicles where deleted_at is null
  group by driver_id having count(*) > 1
)
order by driver_id, rn;
```

Confirm: for every `driver_id` with more than one row, exactly one row has `rn = 1` (the kept one — most approved documents, tie-broken by most recently created) and the rest have `rn > 1` (to be soft-deleted).

- [ ] **Step 2: Write the migration file**

```sql
-- Data cleanup for the duplicate-vehicle bug: the add-vehicle wizard's
-- resubmission path (fixed in this same change set) used to create a
-- brand-new `vehicles` row every time a driver re-ran it after a
-- document rejection, instead of editing the rejected one. This is a
-- one-off sweep to collapse every driver back down to a single vehicle
-- before the fixed flow ships, so nothing needs manual admin cleanup.
--
-- For each driver with more than one non-deleted vehicle, keep the one
-- with the most approved documents (tie-break: most recently created)
-- and soft-delete the rest.

with ranked as (
  select
    v.id,
    v.driver_id,
    v.created_at,
    (select count(*) from public.documents d
       where d.vehicle_id = v.id and d.status = 'approved') as approved_docs,
    row_number() over (
      partition by v.driver_id
      order by
        (select count(*) from public.documents d
           where d.vehicle_id = v.id and d.status = 'approved') desc,
        v.created_at desc
    ) as rn
  from public.vehicles v
  where v.deleted_at is null
)
update public.vehicles v
set deleted_at = now()
from ranked r
where v.id = r.id and r.rn > 1;
```

- [ ] **Step 3: Apply the migration**

Use the Supabase MCP `apply_migration` tool with `project_id: gxzyednqegqycnmbdghf`, `name: cleanup_duplicate_vehicles`, and the SQL from Step 2 as `query`.

- [ ] **Step 4: Verify no driver has more than one non-deleted vehicle**

```sql
select driver_id, count(*) as n
from public.vehicles
where deleted_at is null
group by driver_id
having count(*) > 1;
```

Expected: zero rows returned.

- [ ] **Step 5: Commit**

```bash
cd /Users/ebube/FlutterMobileProjects/drivio-backend
git add supabase/migrations/20260914070000_cleanup_duplicate_vehicles.sql
git commit -m "Clean up duplicate vehicle rows from the resubmission bug

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

### Task 2: Backend — carry vehicle id and reason in the rejection push payload

**Files:**
- Create: `drivio-backend/supabase/migrations/20260914071000_document_rejected_push_vehicle_id.sql`

**Interfaces:**
- Consumes: nothing.
- Produces: the `call-notify` push for `type: 'document_rejected'` now also includes `payload.vehicle_id` (string or null) and `payload.rejection_reason` (string or null) alongside the existing `payload.document_kind`. Task 11's client handler reads these three keys.

- [ ] **Step 1: Write the migration file**

```sql
-- Adds `vehicle_id` and `rejection_reason` to the document_rejected
-- push's data payload (document_kind already existed) so the client can
-- deep-link straight to the right fix screen — pre-filled with which
-- vehicle to attach a re-upload to, and the reason to show up front —
-- without an extra round trip after the tap.

create or replace function public._push_document_rejected()
returns trigger
language plpgsql
security definer
set search_path to 'public', 'pg_temp'
as $$
declare
  v_label text;
  v_body text;
begin
  if new.status = 'rejected' and old.status is distinct from 'rejected' then
    v_label := case new.kind
      when 'drivers_licence' then 'Driver''s licence'
      when 'vehicle_reg' then 'Vehicle registration'
      when 'insurance' then 'Proof of insurance'
      when 'road_worthiness' then 'Road worthiness certificate'
      when 'lasrra' then 'LASRRA card'
      when 'inspection_report' then 'Inspection report'
      when 'profile_selfie' then 'Profile photo'
      when 'vehicle_photo_front' then 'Vehicle photo (front)'
      when 'vehicle_photo_back' then 'Vehicle photo (back)'
      when 'vehicle_photo_side' then 'Vehicle photo (side)'
      when 'vehicle_photo_interior' then 'Vehicle photo (interior)'
      else 'A document'
    end;
    v_body := nullif(trim(coalesce(new.rejection_reason, '')), '');
    if v_body is null then
      v_body := 'Tap to see what to fix and re-upload. It takes about a minute.';
    end if;
    perform net.http_post(
      url := 'https://gxzyednqegqycnmbdghf.supabase.co/functions/v1/call-notify',
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'x-hook-secret', 'clhook_7d2a94e1b8c3f4065a9d1c8e2f7b3a50'
      ),
      body := jsonb_build_object(
        'calleeUserId', new.owner_user_id,
        'calleeApp', 'driver',
        'payload', jsonb_build_object(
          'type', 'document_rejected',
          'document_kind', new.kind,
          'vehicle_id', new.vehicle_id,
          'rejection_reason', new.rejection_reason
        ),
        'notification', jsonb_build_object(
          'title', v_label || ' needs another look',
          'body', v_body
        )
      )
    );
  end if;
  return new;
end;
$$;
```

- [ ] **Step 2: Apply the migration**

Use the Supabase MCP `apply_migration` tool with `project_id: gxzyednqegqycnmbdghf`, `name: document_rejected_push_vehicle_id`, and the SQL from Step 1 as `query`.

- [ ] **Step 3: Verify the function body actually changed**

```sql
select pg_get_functiondef(oid) like '%rejection_reason%, ''document_kind''%'
    or pg_get_functiondef(oid) like '%''vehicle_id'', new.vehicle_id%' as has_vehicle_id
from pg_proc
where proname = '_push_document_rejected' and pronamespace = 'public'::regnamespace;
```

Expected: `has_vehicle_id` is `true`.

- [ ] **Step 4: Commit**

```bash
cd /Users/ebube/FlutterMobileProjects/drivio-backend
git add supabase/migrations/20260914071000_document_rejected_push_vehicle_id.sql
git commit -m "Add vehicle_id and rejection_reason to document_rejected push payload

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

### Task 3: Expose the driver's current vehicle id from `KycRepository`

**Files:**
- Modify: `drivio_driver/lib/modules/kyc/features/kyc_home/presentation/logic/data/kyc_repository.dart`
- Modify: `drivio_driver/lib/modules/kyc/features/kyc_home/presentation/logic/data/kyc_repository_impl.dart`

**Interfaces:**
- Consumes: nothing new (the `vehicles` table query already existed; this just stops discarding the id it already selects).
- Produces: `KycSnapshot.vehicleId` (`String?`) — the driver's current non-deleted vehicle id, or null. `KycSnapshot.hasVehicle` becomes a getter (`vehicleId != null`) instead of a stored field, so the one existing call site (`kyc_controller.dart`'s `_buildSteps`, touched in Task 4) keeps compiling unchanged.

- [ ] **Step 1: Update `KycSnapshot`**

In `kyc_repository.dart`, replace the `KycSnapshot` class:

```dart
class KycSnapshot {
  const KycSnapshot({
    required this.kycStatus,
    required this.bvnVerifiedAt,
    required this.ninVerifiedAt,
    required this.livenessPassedAt,
    required this.driversLicenceVerifiedAt,
    required this.documents,
    required this.vehicleId,
  });

  final String kycStatus; // raw enum value from drivers.kyc_status
  final DateTime? bvnVerifiedAt;
  final DateTime? ninVerifiedAt;
  final DateTime? livenessPassedAt;
  final DateTime? driversLicenceVerifiedAt;
  final List<Document> documents;

  /// The driver's current (non-deleted) vehicle id, or null if they
  /// don't have one. Used to attach a rejection-fix re-upload to the
  /// SAME vehicle instead of creating a new one.
  final String? vehicleId;

  bool get hasVehicle => vehicleId != null;
}
```

- [ ] **Step 2: Update `SupabaseKycRepository.loadSnapshot()`**

In `kyc_repository_impl.dart`, the `vehicles` query already selects `id` — only the final `KycSnapshot(...)` construction changes. Replace:

```dart
    final KycSnapshot snapshot = KycSnapshot(
      kycStatus: (driver['kyc_status'] as String?) ?? 'not_started',
      bvnVerifiedAt: parse(driver['bvn_verified_at']),
      ninVerifiedAt: parse(driver['nin_verified_at']),
      livenessPassedAt: parse(driver['liveness_passed_at']),
      driversLicenceVerifiedAt: parse(driver['drivers_licence_verified_at']),
      documents: docs.map(Document.fromJson).toList(growable: false),
      hasVehicle: vehicles.isNotEmpty,
    );
```

with:

```dart
    final KycSnapshot snapshot = KycSnapshot(
      kycStatus: (driver['kyc_status'] as String?) ?? 'not_started',
      bvnVerifiedAt: parse(driver['bvn_verified_at']),
      ninVerifiedAt: parse(driver['nin_verified_at']),
      livenessPassedAt: parse(driver['liveness_passed_at']),
      driversLicenceVerifiedAt: parse(driver['drivers_licence_verified_at']),
      documents: docs.map(Document.fromJson).toList(growable: false),
      vehicleId: vehicles.isEmpty ? null : vehicles.first['id'] as String,
    );
```

- [ ] **Step 3: Analyze**

```bash
cd /Users/ebube/FlutterMobileProjects/drivio_driver
fvm flutter analyze lib/modules/kyc/features/kyc_home/presentation/logic/data/kyc_repository.dart lib/modules/kyc/features/kyc_home/presentation/logic/data/kyc_repository_impl.dart
```

Expected: `No issues found!` — this does NOT check `kyc_controller.dart`, which still references the old `KycSnapshot(hasVehicle: ...)` constructor shape until Task 4; a full-project `flutter analyze` will show one error there until Task 4 lands, which is expected and fixed there.

- [ ] **Step 4: Commit**

```bash
git add lib/modules/kyc/features/kyc_home/presentation/logic/data/kyc_repository.dart lib/modules/kyc/features/kyc_home/presentation/logic/data/kyc_repository_impl.dart
git commit -m "Expose the driver's current vehicle id from KycSnapshot

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

### Task 4: `KycController` — derive rejected items, with unit tests

**Files:**
- Modify: `drivio_driver/lib/modules/commons/types/document.dart`
- Modify: `drivio_driver/lib/modules/kyc/features/kyc_home/presentation/logic/controller/kyc_controller.dart`
- Create: `drivio_driver/test/modules/kyc/kyc_controller_test.dart`

**Interfaces:**
- Consumes: `KycSnapshot.vehicleId` (Task 3), `KycRepository` (existing interface, unchanged).
- Produces: `RejectedDocumentItem` class (`kind: DocumentKind`, `reason: String`, `vehicleId: String?`, `label: String` getter). `KycState.rejectedItems` (`List<RejectedDocumentItem>`) and `KycState.hasRejectedItems` (`bool`), read by Task 8 (home banner), Task 9 (KYC checklist routing), and Task 7 (`RejectedItemsPage`). `vehicleDocumentKinds` (`List<DocumentKind>`, const) and `hasRejectedVehicleDocument(Map<DocumentKind, Document>)` (`bool`) from `document.dart`, reused by Task 10.

- [ ] **Step 1: Add the shared vehicle-document-kinds helper to `document.dart`**

Append to the end of `drivio_driver/lib/modules/commons/types/document.dart` (after the `Document` class):

```dart
/// Vehicle-related document kinds actually collected today — the ones
/// that can be individually rejected and need a targeted re-upload.
/// Insurance, road worthiness, LASRRA and inspection report are enum
/// values that exist but are not collected by any current UI.
const List<DocumentKind> vehicleDocumentKinds = <DocumentKind>[
  DocumentKind.vehicleReg,
  DocumentKind.vehiclePhotoFront,
  DocumentKind.vehiclePhotoBack,
  DocumentKind.vehiclePhotoSide,
  DocumentKind.vehiclePhotoInterior,
];

/// True if any vehicle-related document's latest status is rejected,
/// given a "latest document per kind" map (as `ProfileHubState.
/// documentsByKind` already builds).
bool hasRejectedVehicleDocument(Map<DocumentKind, Document> byKind) {
  return vehicleDocumentKinds.any(
    (DocumentKind k) => byKind[k]?.status == DocumentStatus.rejected,
  );
}
```

- [ ] **Step 2: Write the failing test**

Create `drivio_driver/test/modules/kyc/kyc_controller_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';

import 'package:drivio_driver/modules/commons/types/document.dart';
import 'package:drivio_driver/modules/kyc/features/kyc_home/presentation/logic/controller/kyc_controller.dart';
import 'package:drivio_driver/modules/kyc/features/kyc_home/presentation/logic/data/kyc_repository.dart';

class _FakeKycRepository implements KycRepository {
  _FakeKycRepository(this.snapshot);
  final KycSnapshot snapshot;

  @override
  Future<KycSnapshot> loadSnapshot() async => snapshot;

  @override
  Future<void> markStepCompleted(String step) async {}

  @override
  Future<String?> submitForReview() async => null;

  @override
  Future<NinVerifyResult> verifyNin(String nin) async => NinVerifyResult.error;

  @override
  Future<NinVerifyResult> verifyDriversLicence(String licenceNo) async =>
      NinVerifyResult.error;
}

Document _doc({
  required DocumentKind kind,
  required DocumentStatus status,
  String? rejectionReason,
  DateTime? createdAt,
}) {
  return Document(
    id: 'doc-${kind.wire}-${(createdAt ?? DateTime(2026, 1, 1)).millisecondsSinceEpoch}',
    ownerUserId: 'driver-1',
    kind: kind,
    filePath: 'driver-1/${kind.wire}/file.jpg',
    status: status,
    createdAt: createdAt ?? DateTime(2026, 1, 1),
    rejectionReason: rejectionReason,
  );
}

void main() {
  group('KycController.refresh — rejectedItems', () {
    test('reports no rejected items when everything is pending/approved',
        () async {
      final KycSnapshot snap = KycSnapshot(
        kycStatus: 'pending_review',
        bvnVerifiedAt: null,
        ninVerifiedAt: DateTime(2026, 1, 1),
        livenessPassedAt: DateTime(2026, 1, 1),
        driversLicenceVerifiedAt: null,
        vehicleId: 'vehicle-1',
        documents: <Document>[
          _doc(kind: DocumentKind.driversLicence, status: DocumentStatus.pending),
          _doc(kind: DocumentKind.vehicleReg, status: DocumentStatus.approved),
        ],
      );
      final KycController c = KycController(_FakeKycRepository(snap));
      await c.refresh();

      expect(c.state.rejectedItems, isEmpty);
      expect(c.state.hasRejectedItems, isFalse);
    });

    test('surfaces a rejected vehicle photo with its reason and vehicle id',
        () async {
      final KycSnapshot snap = KycSnapshot(
        kycStatus: 'pending_review',
        bvnVerifiedAt: null,
        ninVerifiedAt: DateTime(2026, 1, 1),
        livenessPassedAt: DateTime(2026, 1, 1),
        driversLicenceVerifiedAt: null,
        vehicleId: 'vehicle-1',
        documents: <Document>[
          _doc(kind: DocumentKind.vehicleReg, status: DocumentStatus.approved),
          _doc(
            kind: DocumentKind.vehiclePhotoFront,
            status: DocumentStatus.rejected,
            rejectionReason: 'Photo is blurry',
          ),
        ],
      );
      final KycController c = KycController(_FakeKycRepository(snap));
      await c.refresh();

      expect(c.state.hasRejectedItems, isTrue);
      expect(c.state.rejectedItems, hasLength(1));
      final RejectedDocumentItem item = c.state.rejectedItems.single;
      expect(item.kind, DocumentKind.vehiclePhotoFront);
      expect(item.reason, 'Photo is blurry');
      expect(item.vehicleId, 'vehicle-1');
      expect(item.label, 'Vehicle photo (front)');
    });

    test(
        'only the LATEST document per kind counts — a superseded '
        'rejection does not block a later approval', () async {
      final KycSnapshot snap = KycSnapshot(
        kycStatus: 'pending_review',
        bvnVerifiedAt: null,
        ninVerifiedAt: DateTime(2026, 1, 1),
        livenessPassedAt: DateTime(2026, 1, 1),
        driversLicenceVerifiedAt: null,
        vehicleId: 'vehicle-1',
        documents: <Document>[
          // Newest first, matching kyc_repository_impl.dart's real query
          // order (`order('created_at', ascending: false)`).
          _doc(
            kind: DocumentKind.driversLicence,
            status: DocumentStatus.pending,
            createdAt: DateTime(2026, 2, 1),
          ),
          _doc(
            kind: DocumentKind.driversLicence,
            status: DocumentStatus.rejected,
            rejectionReason: 'Old, superseded rejection',
            createdAt: DateTime(2026, 1, 1),
          ),
        ],
      );
      final KycController c = KycController(_FakeKycRepository(snap));
      await c.refresh();

      expect(c.state.rejectedItems, isEmpty);
    });

    test('licence/selfie rejections carry no vehicle id', () async {
      final KycSnapshot snap = KycSnapshot(
        kycStatus: 'pending_review',
        bvnVerifiedAt: null,
        ninVerifiedAt: DateTime(2026, 1, 1),
        livenessPassedAt: null,
        driversLicenceVerifiedAt: null,
        vehicleId: 'vehicle-1',
        documents: <Document>[
          _doc(
            kind: DocumentKind.driversLicence,
            status: DocumentStatus.rejected,
            rejectionReason: 'Expired',
          ),
        ],
      );
      final KycController c = KycController(_FakeKycRepository(snap));
      await c.refresh();

      expect(c.state.rejectedItems.single.vehicleId, isNull);
    });

    test('a missing rejection reason falls back to a generic message',
        () async {
      final KycSnapshot snap = KycSnapshot(
        kycStatus: 'pending_review',
        bvnVerifiedAt: null,
        ninVerifiedAt: null,
        livenessPassedAt: null,
        driversLicenceVerifiedAt: null,
        vehicleId: null,
        documents: <Document>[
          _doc(
            kind: DocumentKind.profileSelfie,
            status: DocumentStatus.rejected,
          ),
        ],
      );
      final KycController c = KycController(_FakeKycRepository(snap));
      await c.refresh();

      expect(
        c.state.rejectedItems.single.reason,
        "This didn't pass review. Please upload a new copy.",
      );
    });
  });
}
```

- [ ] **Step 3: Run the tests to verify they fail**

```bash
cd /Users/ebube/FlutterMobileProjects/drivio_driver
fvm flutter test test/modules/kyc/kyc_controller_test.dart
```

Expected: FAIL — `KycSnapshot` doesn't have a `vehicleId` named constructor parameter matching this shape yet in the running analyzer sense, and `KycState` has no `rejectedItems`/`hasRejectedItems` members, and `RejectedDocumentItem` doesn't exist. (If Task 3 already landed, the `KycSnapshot` part compiles; the `RejectedDocumentItem`/`rejectedItems` parts still fail.)

- [ ] **Step 4: Replace `kyc_controller.dart` with the implementation**

Replace the full contents of `drivio_driver/lib/modules/kyc/features/kyc_home/presentation/logic/controller/kyc_controller.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:drivio_driver/modules/commons/analytics/analytics_events.dart';
import 'package:drivio_driver/modules/commons/analytics/mixpanel_service.dart';
import 'package:drivio_driver/modules/commons/di/di.dart';
import 'package:drivio_driver/modules/commons/types/document.dart';
import 'package:drivio_driver/modules/kyc/features/kyc_home/presentation/logic/data/kyc_repository.dart';

enum KycOverallStatus {
  notStarted,
  inProgress,
  pendingReview,
  approved,
  rejected;

  static KycOverallStatus fromWire(String wire) {
    switch (wire) {
      case 'in_progress':
        return KycOverallStatus.inProgress;
      case 'pending_review':
        return KycOverallStatus.pendingReview;
      case 'approved':
        return KycOverallStatus.approved;
      case 'rejected':
        return KycOverallStatus.rejected;
      case 'not_started':
      default:
        return KycOverallStatus.notStarted;
    }
  }

  String get label {
    switch (this) {
      case KycOverallStatus.notStarted:
        return 'Not started';
      case KycOverallStatus.inProgress:
        return 'In progress';
      case KycOverallStatus.pendingReview:
        return 'Pending review';
      case KycOverallStatus.approved:
        return 'Approved';
      case KycOverallStatus.rejected:
        return 'Rejected';
    }
  }
}

enum KycStepKind {
  bvnNin,
  selfie,
  driversLicence,
  vehicle,
}

enum KycStepStatus { required, submitted, approved, rejected, expired }

class KycStep {
  const KycStep({
    required this.kind,
    required this.title,
    required this.subtitle,
    required this.status,
    this.rejectionReason,
  });

  final KycStepKind kind;
  final String title;
  final String subtitle;
  final KycStepStatus status;
  final String? rejectionReason;
}

/// One currently-rejected document, in scope for the guided re-upload
/// flow (`RejectedItemsPage`). Only document kinds an admin actually
/// reviews are ever produced here — see [KycController._inScopeKinds].
class RejectedDocumentItem {
  const RejectedDocumentItem({
    required this.kind,
    required this.reason,
    this.vehicleId,
  });

  final DocumentKind kind;
  final String reason;

  /// Set for vehicle-related kinds (registration, photos) so the fix
  /// screen re-registers the new upload against the SAME vehicle
  /// instead of creating a new one. Null for licence/selfie.
  final String? vehicleId;

  String get label {
    switch (kind) {
      case DocumentKind.driversLicence:
        return "Driver's licence";
      case DocumentKind.profileSelfie:
        return 'Selfie';
      case DocumentKind.vehicleReg:
        return 'Vehicle registration';
      case DocumentKind.vehiclePhotoFront:
        return 'Vehicle photo (front)';
      case DocumentKind.vehiclePhotoBack:
        return 'Vehicle photo (back)';
      case DocumentKind.vehiclePhotoSide:
        return 'Vehicle photo (side)';
      case DocumentKind.vehiclePhotoInterior:
        return 'Vehicle photo (interior)';
      case DocumentKind.insurance:
      case DocumentKind.roadWorthiness:
      case DocumentKind.lasrra:
      case DocumentKind.inspectionReport:
        return 'Document';
    }
  }
}

class KycState {
  const KycState({
    this.overall = KycOverallStatus.notStarted,
    this.steps = const <KycStep>[],
    this.rejectedItems = const <RejectedDocumentItem>[],
    this.isLoading = false,
    this.isSubmitting = false,
    this.error,
  });

  final KycOverallStatus overall;
  final List<KycStep> steps;

  /// Currently-rejected documents across every in-scope kind — licence,
  /// selfie, vehicle registration, and the 4 vehicle photos. Drives the
  /// home banner's "needs attention" state and `RejectedItemsPage`.
  final List<RejectedDocumentItem> rejectedItems;
  final bool isLoading;
  final bool isSubmitting;
  final String? error;

  bool get hasRejectedItems => rejectedItems.isNotEmpty;

  bool get allRequiredSubmitted => steps.every(
    (KycStep s) =>
        s.status == KycStepStatus.submitted ||
        s.status == KycStepStatus.approved,
  );

  /// True once the driver has passed the face-liveness step
  /// (`drivers.liveness_passed_at` is set). Required before going online,
  /// independent of overall KYC approval — so existing approved drivers
  /// who predate liveness are still gated until they complete it.
  bool get livenessPassed => steps.any(
    (KycStep s) =>
        s.kind == KycStepKind.selfie &&
        (s.status == KycStepStatus.submitted ||
            s.status == KycStepStatus.approved),
  );

  /// The status to *display*. A driver isn't truly done until the face
  /// check is passed, so a server-`approved` row with no liveness yet is
  /// surfaced as still in progress, never as "Approved".
  KycOverallStatus get effectiveOverall =>
      overall == KycOverallStatus.approved && !livenessPassed
      ? KycOverallStatus.inProgress
      : overall;

  bool get canSubmitForReview =>
      allRequiredSubmitted &&
      (overall == KycOverallStatus.notStarted ||
          overall == KycOverallStatus.inProgress ||
          overall == KycOverallStatus.rejected);

  KycState copyWith({
    KycOverallStatus? overall,
    List<KycStep>? steps,
    List<RejectedDocumentItem>? rejectedItems,
    bool? isLoading,
    bool? isSubmitting,
    String? error,
    bool clearError = false,
  }) {
    return KycState(
      overall: overall ?? this.overall,
      steps: steps ?? this.steps,
      rejectedItems: rejectedItems ?? this.rejectedItems,
      isLoading: isLoading ?? this.isLoading,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class KycController extends StateNotifier<KycState> {
  KycController(this._repo) : super(const KycState());

  final KycRepository _repo;

  /// Document kinds an admin actually reviews and can reject with a
  /// reason. Insurance/road-worthiness/LASRRA/inspection are enum values
  /// that exist but are not collected anywhere in the current UI — never
  /// surfaced here.
  static const List<DocumentKind> _inScopeKinds = <DocumentKind>[
    DocumentKind.driversLicence,
    DocumentKind.profileSelfie,
    ...vehicleDocumentKinds,
  ];

  Future<void> refresh() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final KycSnapshot snap = await _repo.loadSnapshot();
      state = state.copyWith(
        overall: KycOverallStatus.fromWire(snap.kycStatus),
        steps: _buildSteps(snap),
        rejectedItems: _buildRejectedItems(snap),
        isLoading: false,
      );
    } catch (_) {
      state = state.copyWith(
        isLoading: false,
        error: "Couldn't load your KYC status. Pull down to retry.",
      );
    }
  }

  Future<bool> submitForReview() async {
    if (!state.canSubmitForReview) return false;
    state = state.copyWith(isSubmitting: true, clearError: true);
    try {
      final String? next = await _repo.submitForReview();
      if (next == null) {
        state = state.copyWith(
          isSubmitting: false,
          error: 'Submission rejected. Refresh and try again.',
        );
        return false;
      }
      locator<MixpanelService>().track(AnalyticsEvents.kycSubmitted);
      await refresh();
      state = state.copyWith(isSubmitting: false);
      return true;
    } catch (_) {
      state = state.copyWith(
        isSubmitting: false,
        error: "Couldn't submit. Check your connection and try again.",
      );
      return false;
    }
  }

  /// Latest document of [kind] for this driver, or null. `snap.documents`
  /// is already ordered newest-first (`kyc_repository_impl.dart`), so
  /// the first match IS the latest — mirrors the "latest per kind wins"
  /// rule the backend uses in `_kyc_evidence_complete`/
  /// `_kyc_fully_approved`.
  static Document? _docOf(KycSnapshot snap, DocumentKind kind) {
    for (final Document d in snap.documents) {
      if (d.kind == kind) return d;
    }
    return null;
  }

  List<RejectedDocumentItem> _buildRejectedItems(KycSnapshot snap) {
    final List<RejectedDocumentItem> items = <RejectedDocumentItem>[];
    for (final DocumentKind kind in _inScopeKinds) {
      final Document? doc = _docOf(snap, kind);
      if (doc == null || doc.status != DocumentStatus.rejected) continue;
      final String? reason = doc.rejectionReason?.trim();
      items.add(
        RejectedDocumentItem(
          kind: kind,
          reason: (reason == null || reason.isEmpty)
              ? "This didn't pass review. Please upload a new copy."
              : reason,
          vehicleId: vehicleDocumentKinds.contains(kind) ? snap.vehicleId : null,
        ),
      );
    }
    return items;
  }

  List<KycStep> _buildSteps(KycSnapshot snap) {
    KycStepStatus statusOf(Document? d, {bool fallbackSubmitted = false}) {
      if (d == null) {
        return fallbackSubmitted
            ? KycStepStatus.submitted
            : KycStepStatus.required;
      }
      switch (d.status) {
        case DocumentStatus.approved:
          return KycStepStatus.approved;
        case DocumentStatus.rejected:
          return KycStepStatus.rejected;
        case DocumentStatus.expired:
          return KycStepStatus.expired;
        case DocumentStatus.pending:
          return KycStepStatus.submitted;
      }
    }

    // NIN-only: identity is verified against NIMC by its own service,
    // never by an admin. BVN is no longer part of the flow.
    final KycStepStatus ninStatus = snap.ninVerifiedAt != null
        ? KycStepStatus.submitted
        : KycStepStatus.required;
    final KycStepStatus selfieStatus = snap.livenessPassedAt != null
        ? KycStepStatus.submitted
        : KycStepStatus.required;
    // Licence is an UPLOADED photo reviewed by an admin (the FRSC
    // number check was retired) — its step is driven by the document's
    // review status, exactly like the vehicle registration.
    final Document? licenceDoc = _docOf(snap, DocumentKind.driversLicence);
    final KycStepStatus licenceStatus = statusOf(licenceDoc);

    // The registration uploads inside the add-vehicle flow; the vehicle
    // step is only "done" once the vehicle AND its registration are in.
    final Document? reg = _docOf(snap, DocumentKind.vehicleReg);
    final bool vehicleDocsIn = reg != null;
    final bool vehicleDocRejected = statusOf(reg) == KycStepStatus.rejected;

    return <KycStep>[
      KycStep(
        kind: KycStepKind.bvnNin,
        title: 'NIN',
        subtitle: 'Verify your identity (NIMC).',
        status: ninStatus,
      ),
      KycStep(
        kind: KycStepKind.selfie,
        title: 'Selfie & liveness',
        subtitle: 'A quick photo to match your ID.',
        status: selfieStatus,
      ),
      KycStep(
        kind: KycStepKind.driversLicence,
        title: "Driver's licence",
        subtitle: 'Upload a clear photo of your licence.',
        status: licenceStatus,
        rejectionReason: licenceDoc?.rejectionReason,
      ),
      KycStep(
        kind: KycStepKind.vehicle,
        title: 'Add a vehicle',
        subtitle: 'Make, model, plate, registration & photos.',
        status: vehicleDocRejected
            ? KycStepStatus.rejected
            : (snap.hasVehicle && vehicleDocsIn)
                ? KycStepStatus.submitted
                : KycStepStatus.required,
        rejectionReason: reg?.rejectionReason,
      ),
    ];
  }
}

final StateNotifierProvider<KycController, KycState> kycControllerProvider =
    StateNotifierProvider<KycController, KycState>(
      (Ref _) => KycController(locator<KycRepository>()),
    );
```

- [ ] **Step 5: Run the tests to verify they pass**

```bash
fvm flutter test test/modules/kyc/kyc_controller_test.dart
```

Expected: all 5 tests PASS.

- [ ] **Step 6: Analyze**

```bash
fvm flutter analyze lib/modules/commons/types/document.dart lib/modules/kyc/features/kyc_home/presentation/logic/controller/kyc_controller.dart
```

Expected: `No issues found!`

- [ ] **Step 7: Commit**

```bash
git add lib/modules/commons/types/document.dart lib/modules/kyc/features/kyc_home/presentation/logic/controller/kyc_controller.dart test/modules/kyc/kyc_controller_test.dart
git commit -m "Derive per-document rejected items in KycController

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

### Task 5: `DocumentCaptureController` — support attaching an upload to an existing vehicle

**Files:**
- Modify: `drivio_driver/lib/modules/kyc/features/document_capture/presentation/logic/controller/document_capture_controller.dart`

**Interfaces:**
- Consumes: `DocumentRepository.registerDocument({required DocumentKind kind, required String filePath, String? vehicleId})` (existing, unchanged signature).
- Produces: `DocumentCaptureState.vehicleId` (`String?`) and `DocumentCaptureController.setVehicleId(String id)`, consumed by Task 6.

- [ ] **Step 1: Add `vehicleId` to `DocumentCaptureState`**

Replace the `DocumentCaptureState` class:

```dart
class DocumentCaptureState {
  const DocumentCaptureState({
    this.kind,
    this.vehicleId,
    this.isUploading = false,
    this.isRegistering = false,
    this.uploadedFilePath,
    this.uploadedFileName,
    this.error,
  });

  final DocumentKind? kind;

  /// Set when this capture is fixing a rejected vehicle-related document
  /// (registration, a photo) — the new upload gets registered against
  /// this EXISTING vehicle instead of creating a new one. Null for
  /// licence/selfie, and null for a normal (non-fix) first-time capture.
  final String? vehicleId;
  final bool isUploading;
  final bool isRegistering;
  final String? uploadedFilePath;
  final String? uploadedFileName;
  final String? error;

  bool get hasUpload => uploadedFilePath != null;

  DocumentCaptureState copyWith({
    DocumentKind? kind,
    String? vehicleId,
    bool? isUploading,
    bool? isRegistering,
    String? uploadedFilePath,
    String? uploadedFileName,
    String? error,
    bool clearError = false,
    bool clearUpload = false,
  }) {
    return DocumentCaptureState(
      kind: kind ?? this.kind,
      vehicleId: vehicleId ?? this.vehicleId,
      isUploading: isUploading ?? this.isUploading,
      isRegistering: isRegistering ?? this.isRegistering,
      uploadedFilePath:
          clearUpload ? null : (uploadedFilePath ?? this.uploadedFilePath),
      uploadedFileName:
          clearUpload ? null : (uploadedFileName ?? this.uploadedFileName),
      error: clearError ? null : (error ?? this.error),
    );
  }
}
```

- [ ] **Step 2: Add `setVehicleId` and pass it through `registerDocument`**

In `DocumentCaptureController`, add this method right after `setKind`:

```dart
  void setKind(DocumentKind k) =>
      state = state.copyWith(kind: k, clearError: true);

  /// Set once, right after construction, when this capture is fixing a
  /// rejected vehicle-related document. The provider is `autoDispose`,
  /// so every push of the capture screen gets a fresh controller — this
  /// never needs to be cleared back to null mid-session.
  void setVehicleId(String id) => state = state.copyWith(vehicleId: id);
```

Then update `registerDocument()` to pass the vehicle id through:

```dart
  Future<bool> registerDocument() async {
    final DocumentKind? kind = state.kind;
    final String? filePath = state.uploadedFilePath;
    if (kind == null || filePath == null) return false;

    state = state.copyWith(isRegistering: true, clearError: true);
    try {
      await _docs.registerDocument(
        kind: kind,
        filePath: filePath,
        vehicleId: state.vehicleId,
      );
      // Success: stay in the registering state — the page refreshes the
      // checklist and pops; flipping to idle first reads as a failure.
      return true;
    } catch (_) {
      state = state.copyWith(
        isRegistering: false,
        error: "Couldn't save the document. Try again in a moment.",
      );
      return false;
    }
  }
```

- [ ] **Step 3: Analyze**

```bash
fvm flutter analyze lib/modules/kyc/features/document_capture/presentation/logic/controller/document_capture_controller.dart
```

Expected: `No issues found!`

- [ ] **Step 4: Commit**

```bash
git add lib/modules/kyc/features/document_capture/presentation/logic/controller/document_capture_controller.dart
git commit -m "Let DocumentCaptureController attach an upload to an existing vehicle

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

### Task 6: `DocumentCapturePage` — accept fix-flow arguments, show the rejection reason, report success

**Files:**
- Modify: `drivio_driver/lib/modules/kyc/features/document_capture/presentation/ui/document_capture_page.dart`

**Interfaces:**
- Consumes: `DocumentCaptureController.setVehicleId` (Task 5).
- Produces: `DocumentCaptureArgs` class (`kind: DocumentKind`, `vehicleId: String?`, `rejectionReason: String?`) — the route argument type Task 7 and Task 11 push with. The route `AppRoutes.kycDocumentCapture` still also accepts a bare `DocumentKind` (existing behavior, e.g. `kyc_home_page.dart`'s licence row and `profile_hub_page.dart`'s `_DocLinkRow` — untouched, still work). On successful submit the page now pops with `true` (was: pops with no value) — existing callers that don't await/use the result are unaffected.

- [ ] **Step 1: Replace the file**

Replace the full contents of `drivio_driver/lib/modules/kyc/features/document_capture/presentation/ui/document_capture_page.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:drivio_driver/modules/commons/all.dart';
import 'package:drivio_driver/modules/commons/types/document.dart';
import 'package:drivio_driver/modules/kyc/features/document_capture/presentation/logic/controller/document_capture_controller.dart';
import 'package:drivio_driver/modules/kyc/features/kyc_home/presentation/logic/controller/kyc_controller.dart';

/// Route arguments for a targeted re-upload: which document, which
/// vehicle to attach it to (vehicle-related kinds only), and why the
/// previous one was rejected. `AppRoutes.kycDocumentCapture` also still
/// accepts a bare [DocumentKind] for a normal, non-fix capture — see
/// `didChangeDependencies` below — so every existing call site keeps
/// working unchanged.
class DocumentCaptureArgs {
  const DocumentCaptureArgs({
    required this.kind,
    this.vehicleId,
    this.rejectionReason,
  });

  final DocumentKind kind;
  final String? vehicleId;
  final String? rejectionReason;
}

class DocumentCapturePage extends ConsumerStatefulWidget {
  const DocumentCapturePage({super.key});

  @override
  ConsumerState<DocumentCapturePage> createState() =>
      _DocumentCapturePageState();
}

class _DocumentCapturePageState extends ConsumerState<DocumentCapturePage> {
  bool _initialized = false;
  DocumentKind _kind = DocumentKind.driversLicence;
  String? _vehicleId;
  String? _rejectionReason;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;

    final Object? arg = ModalRoute.of(context)?.settings.arguments;
    if (arg is DocumentCaptureArgs) {
      _kind = arg.kind;
      _vehicleId = arg.vehicleId;
      _rejectionReason = arg.rejectionReason;
    } else if (arg is DocumentKind) {
      _kind = arg;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final DocumentCaptureController c =
          ref.read(documentCaptureControllerProvider.notifier);
      c.setKind(_kind);
      final String? vehicleId = _vehicleId;
      if (vehicleId != null) {
        c.setVehicleId(vehicleId);
      }
    });
  }

  String get _title {
    switch (_kind) {
      case DocumentKind.driversLicence:
        return "Driver's licence";
      case DocumentKind.vehicleReg:
        return 'Vehicle registration';
      case DocumentKind.insurance:
        return 'Proof of insurance';
      case DocumentKind.roadWorthiness:
        return 'Road worthiness';
      case DocumentKind.lasrra:
        return 'LASRRA';
      case DocumentKind.inspectionReport:
        return 'Inspection report';
      case DocumentKind.profileSelfie:
        return 'Selfie';
      case DocumentKind.vehiclePhotoFront:
      case DocumentKind.vehiclePhotoBack:
      case DocumentKind.vehiclePhotoSide:
      case DocumentKind.vehiclePhotoInterior:
        return 'Vehicle photo';
    }
  }

  @override
  Widget build(BuildContext context) {
    final DocumentCaptureState state =
        ref.watch(documentCaptureControllerProvider);
    final DocumentCaptureController c =
        ref.read(documentCaptureControllerProvider.notifier);

    return ScreenScaffold(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            BackButtonBox(onTap: () => AppNavigation.pop()),
            const SizedBox(height: 18),
            Text(
              'Upload your\n$_title.',
              style: AppTextStyles.h1.copyWith(color: context.text),
            ),
            const SizedBox(height: 6),
            Text(
              'Make sure all four corners are visible and the text is sharp.',
              style: AppTextStyles.bodySm.copyWith(color: context.textDim),
            ),
            if (_rejectionReason != null) ...<Widget>[
              const SizedBox(height: 16),
              _RejectionReasonBanner(reason: _rejectionReason!),
            ],
            const SizedBox(height: 26),
            _UploadTile(state: state, controller: c),
            if (state.error != null) ...<Widget>[
              const SizedBox(height: 12),
              Text(
                state.error!,
                style: AppTextStyles.bodySm.copyWith(color: context.red),
              ),
            ],
            const SizedBox(height: 22),
            DrivioButton(
              label: state.isRegistering
                  ? 'Saving…'
                  : 'Submit for review',
              disabled: !state.hasUpload || state.isRegistering,
              onPressed: () async {
                final bool ok = await c.registerDocument();
                if (!mounted || !ok) return;
                await ref.read(kycControllerProvider.notifier).refresh();
                if (!mounted) return;
                AppNavigation.pop(true);
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Why the previous upload didn't pass review — shown up front, before
/// the upload control, so the driver knows exactly what to fix instead
/// of guessing and re-submitting the same thing.
class _RejectionReasonBanner extends StatelessWidget {
  const _RejectionReasonBanner({required this.reason});
  final String reason;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: context.red.withValues(alpha: 0.10),
        borderRadius: AppRadius.md,
        border: Border.all(color: context.red.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(DrivioIcons.close, size: 16, color: context.red),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Why this was rejected',
                  style: AppTextStyles.captionSm.copyWith(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: context.red,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  reason,
                  style: AppTextStyles.bodySm.copyWith(
                    color: context.text,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _UploadTile extends StatelessWidget {
  const _UploadTile({required this.state, required this.controller});

  final DocumentCaptureState state;
  final DocumentCaptureController controller;

  @override
  Widget build(BuildContext context) {
    final bool busy = state.isUploading;
    final bool uploaded = state.hasUpload;
    return InkWell(
      onTap: busy ? null : () => _openSourceSheet(context, controller),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
        decoration: BoxDecoration(
          color: context.surface,
          borderRadius: AppRadius.md,
          border: Border.all(
            color: uploaded ? context.accent : context.borderStrong,
          ),
        ),
        child: Row(
          children: <Widget>[
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: (uploaded ? context.accent : context.textDim)
                    .withValues(alpha: 0.14),
                borderRadius: AppRadius.sm,
              ),
              alignment: Alignment.center,
              child: Icon(
                uploaded
                    ? Icons.check_circle_rounded
                    : Icons.upload_file_rounded,
                size: 18,
                color: uploaded ? context.accent : context.textDim,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    busy
                        ? 'Uploading…'
                        : uploaded
                            ? (state.uploadedFileName ?? 'Uploaded')
                            : 'Tap to upload · PDF or photo',
                    style: AppTextStyles.bodySm.copyWith(
                      color: context.text,
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    uploaded
                        ? 'Looking good. Submit when ready.'
                        : 'Camera, gallery, or file picker.',
                    style: AppTextStyles.captionSm.copyWith(
                      fontSize: 11,
                      color: uploaded ? context.accent : context.textDim,
                    ),
                  ),
                ],
              ),
            ),
            if (busy)
              SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: context.accent,
                ),
              )
            else if (uploaded)
              GestureDetector(
                onTap: controller.clearUpload,
                child: Icon(DrivioIcons.close,
                    size: 18, color: context.textDim),
              )
            else
              Icon(DrivioIcons.plus, size: 18, color: context.textDim),
          ],
        ),
      ),
    );
  }

  Future<void> _openSourceSheet(
      BuildContext context, DocumentCaptureController c) async {
    final DocPickerSource? choice = await showModalBottomSheet<DocPickerSource>(
      context: context,
      backgroundColor: context.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Container(
                  width: 38,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    color: ctx.borderStrong,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                Text(
                  'Add document',
                  style: AppTextStyles.bodyLg.copyWith(
                    color: ctx.text,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                _Option(
                  icon: DrivioIcons.camera,
                  label: 'Take a photo',
                  onTap: () =>
                      Navigator.of(ctx).pop(DocPickerSource.camera),
                ),
                _Option(
                  icon: DrivioIcons.image,
                  label: 'Choose from gallery',
                  onTap: () =>
                      Navigator.of(ctx).pop(DocPickerSource.gallery),
                ),
                _Option(
                  icon: DrivioIcons.document,
                  label: 'Choose a PDF',
                  onTap: () => Navigator.of(ctx).pop(DocPickerSource.file),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (choice != null) {
      await c.pickAndUpload(choice);
    }
  }
}

class _Option extends StatelessWidget {
  const _Option(
      {required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        child: Row(
          children: <Widget>[
            Icon(icon, size: 22, color: context.text),
            const SizedBox(width: 14),
            Text(label,
                style: AppTextStyles.body.copyWith(color: context.text)),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Analyze**

```bash
fvm flutter analyze lib/modules/kyc/features/document_capture/presentation/ui/document_capture_page.dart
```

Expected: `No issues found!`

- [ ] **Step 3: Commit**

```bash
git add lib/modules/kyc/features/document_capture/presentation/ui/document_capture_page.dart
git commit -m "DocumentCapturePage: accept fix-flow args, show rejection reason

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

### Task 7: New `RejectedItemsPage` — the guided "what needs fixing" overview

**Files:**
- Create: `drivio_driver/lib/modules/kyc/features/rejected_items/presentation/ui/rejected_items_page.dart`
- Modify: `drivio_driver/lib/modules/commons/navigation/app_routes.dart`
- Modify: `drivio_driver/lib/modules/commons/navigation/app_router.dart`

**Interfaces:**
- Consumes: `kycControllerProvider` / `KycState.rejectedItems` (Task 4), `AppRoutes.kycDocumentCapture` + `DocumentCaptureArgs` (Task 6).
- Produces: `AppRoutes.kycRejectedItems` route (`'/kyc/rejected'`) and `RejectedItemsPage` widget, pushed by Task 8, Task 9, Task 10, and Task 11.

- [ ] **Step 1: Add the route constant**

In `app_routes.dart`, add this line right after `static const String kycDocumentView = '/kyc/document-view';`:

```dart
  static const String kycRejectedItems = '/kyc/rejected';
```

- [ ] **Step 2: Write `RejectedItemsPage`**

Create `drivio_driver/lib/modules/kyc/features/rejected_items/presentation/ui/rejected_items_page.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:drivio_driver/modules/commons/all.dart';
import 'package:drivio_driver/modules/commons/types/document.dart';
import 'package:drivio_driver/modules/kyc/features/document_capture/presentation/ui/document_capture_page.dart';
import 'package:drivio_driver/modules/kyc/features/kyc_home/presentation/logic/controller/kyc_controller.dart';

/// The guided "what needs fixing" screen. Reached from the home banner,
/// a rejection push notification, the KYC checklist, or the profile
/// hub's vehicle row — always the same list, always the same behaviour:
/// one row per currently-rejected document, tap to fix just that one.
///
/// The list is captured ONCE when the screen loads (a fresh
/// `KycController.refresh()`, then whatever `rejectedItems` comes back)
/// and never reflows afterwards. Fixing an item flips its row to a
/// non-tappable "Uploaded" state instead of removing it, so progress
/// reads clearly against a stable list even though a fresh server fetch
/// would technically already show fewer rejected items.
class RejectedItemsPage extends ConsumerStatefulWidget {
  const RejectedItemsPage({super.key});

  @override
  ConsumerState<RejectedItemsPage> createState() => _RejectedItemsPageState();
}

class _RejectedItemsPageState extends ConsumerState<RejectedItemsPage> {
  List<RejectedDocumentItem>? _items;
  final Set<DocumentKind> _completed = <DocumentKind>{};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    await ref.read(kycControllerProvider.notifier).refresh();
    if (!mounted) return;
    setState(() {
      _items = ref.read(kycControllerProvider).rejectedItems;
    });
  }

  Future<void> _fix(RejectedDocumentItem item) async {
    final bool? done = await AppNavigation.push<bool>(
      AppRoutes.kycDocumentCapture,
      arguments: DocumentCaptureArgs(
        kind: item.kind,
        vehicleId: item.vehicleId,
        rejectionReason: item.reason,
      ),
    );
    if (done == true && mounted) {
      setState(() => _completed.add(item.kind));
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<RejectedDocumentItem>? items = _items;
    if (items == null) {
      return ScreenScaffold(
        child: Center(
          child: CircularProgressIndicator(color: context.accent),
        ),
      );
    }

    final bool allDone = items.isNotEmpty &&
        items.every((RejectedDocumentItem i) => _completed.contains(i.kind));

    return ScreenScaffold(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            BackButtonBox(onTap: () => AppNavigation.pop()),
            const SizedBox(height: 18),
            Text(
              'What needs\nfixing.',
              style: AppTextStyles.h1.copyWith(color: context.text),
            ),
            const SizedBox(height: 6),
            Text(
              allDone
                  ? "You're all set — we'll review this shortly."
                  : items.isEmpty
                      ? 'Nothing needs fixing right now.'
                      : 'A few things need another look. Fix each one below.',
              style: AppTextStyles.bodySm.copyWith(color: context.textDim),
            ),
            const SizedBox(height: 22),
            for (final RejectedDocumentItem item in items) ...<Widget>[
              _RejectedItemRow(
                item: item,
                done: _completed.contains(item.kind),
                onTap: () => _fix(item),
              ),
              const SizedBox(height: 10),
            ],
          ],
        ),
      ),
    );
  }
}

class _RejectedItemRow extends StatelessWidget {
  const _RejectedItemRow({
    required this.item,
    required this.done,
    required this.onTap,
  });

  final RejectedDocumentItem item;
  final bool done;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color tone = done ? context.accent : context.red;
    return Opacity(
      opacity: done ? 0.6 : 1,
      child: InkWell(
        onTap: done ? null : onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: context.surface,
            borderRadius: AppRadius.md,
            border: Border.all(color: tone),
          ),
          child: Row(
            children: <Widget>[
              Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: tone.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Icon(
                  done ? DrivioIcons.check : DrivioIcons.close,
                  size: 16,
                  color: tone,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      item.label,
                      style: AppTextStyles.bodySm.copyWith(
                        color: context.text,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      done ? 'Uploaded — pending review' : item.reason,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.captionSm.copyWith(
                        fontSize: 11,
                        color: tone,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                done ? 'Uploaded' : 'Fix',
                style: AppTextStyles.captionSm.copyWith(
                  fontSize: 11,
                  color: tone,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 3: Wire the route**

In `app_router.dart`, add the import alongside the other `kyc/features` imports:

```dart
import 'package:drivio_driver/modules/kyc/features/rejected_items/presentation/ui/rejected_items_page.dart';
```

Add the case right after `case AppRoutes.kycDocumentCapture:`:

```dart
      case AppRoutes.kycRejectedItems:
        return (BuildContext _) => const RejectedItemsPage();
```

- [ ] **Step 4: Analyze**

```bash
fvm flutter analyze lib/modules/kyc/features/rejected_items/presentation/ui/rejected_items_page.dart lib/modules/commons/navigation/app_routes.dart lib/modules/commons/navigation/app_router.dart
```

Expected: `No issues found!`

- [ ] **Step 5: Commit**

```bash
git add lib/modules/kyc/features/rejected_items/presentation/ui/rejected_items_page.dart lib/modules/commons/navigation/app_routes.dart lib/modules/commons/navigation/app_router.dart
git commit -m "Add RejectedItemsPage — the guided what-needs-fixing overview

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

### Task 8: Home banner shows a rejection, regardless of overall approval

**Files:**
- Modify: `drivio_driver/lib/modules/dash/features/drive_shell/presentation/ui/drive_shell_page.dart`

**Interfaces:**
- Consumes: `KycState.hasRejectedItems` (Task 4), `AppRoutes.kycRejectedItems` (Task 7).
- Produces: nothing new consumed elsewhere.

- [ ] **Step 1: Watch `hasRejectedItems` alongside the existing tuple**

Find this block (around line 213):

```dart
    final (KycOverallStatus, bool) kycGate = ref.watch(
      kycControllerProvider.select(
        (KycState s) => (s.overall, s.livenessPassed),
      ),
    );
    final KycOverallStatus kycStatus = kycGate.$1;
    // Liveness is required on top of overall approval, so the banner keeps
    // nudging an approved driver who still hasn't done the face check.
    final bool kycComplete =
        kycStatus == KycOverallStatus.approved && kycGate.$2;
```

Replace it with:

```dart
    final (KycOverallStatus, bool, bool) kycGate = ref.watch(
      kycControllerProvider.select(
        (KycState s) => (s.overall, s.livenessPassed, s.hasRejectedItems),
      ),
    );
    final KycOverallStatus kycStatus = kycGate.$1;
    // Liveness is required on top of overall approval, so the banner keeps
    // nudging an approved driver who still hasn't done the face check.
    final bool kycComplete =
        kycStatus == KycOverallStatus.approved && kycGate.$2;
    final bool kycHasRejectedItems = kycGate.$3;
```

- [ ] **Step 2: Pass it into `_buildBanner`**

Find (around line 390):

```dart
    final Widget? banner = _buildBanner(shell, home, kycComplete, kycStatus);
```

Replace with:

```dart
    final Widget? banner =
        _buildBanner(shell, home, kycComplete, kycStatus, kycHasRejectedItems);
```

- [ ] **Step 3: Update `_buildBanner` to check the rejection signal first**

Find:

```dart
  Widget? _buildBanner(
    DriveShellState shell,
    HomeState home,
    bool kycComplete,
    KycOverallStatus kycStatus,
  ) {
    if (!shell.isIdle) return null;
    // High-demand highlight hidden for now — the banner used hardcoded
    // placeholder copy. Re-enable once the real demand signal ships.
    // if (home.isOnline) return _DemandBanner();
    if (!kycComplete) return _KycBanner(status: kycStatus);
    if (!home.hasVehicle) {
      return _AddVehicleBanner(onAdd: () => setState(() => _gateOpen = true));
    }
    return null;
  }
```

Replace with:

```dart
  Widget? _buildBanner(
    DriveShellState shell,
    HomeState home,
    bool kycComplete,
    KycOverallStatus kycStatus,
    bool kycHasRejectedItems,
  ) {
    if (!shell.isIdle) return null;
    // Checked BEFORE kycComplete: an already-approved, driving driver
    // whose license renewal (or anything else) gets rejected later must
    // still see this — kycComplete alone would hide it from them.
    if (kycHasRejectedItems) return const _KycRejectedBanner();
    // High-demand highlight hidden for now — the banner used hardcoded
    // placeholder copy. Re-enable once the real demand signal ships.
    // if (home.isOnline) return _DemandBanner();
    if (!kycComplete) return _KycBanner(status: kycStatus);
    if (!home.hasVehicle) {
      return _AddVehicleBanner(onAdd: () => setState(() => _gateOpen = true));
    }
    return null;
  }
```

- [ ] **Step 4: Add the `_KycRejectedBanner` widget**

Add this new class right before the existing `class _KycBanner extends StatelessWidget {` definition:

```dart
/// Shown whenever ANY in-scope document has a live rejection — checked
/// before [_KycBanner]'s own logic, so even an otherwise-approved,
/// already-driving driver sees this. Deliberately lighter than a full
/// "application rejected" treatment (amber, matching the app's existing
/// "needs attention" tone, not red) — being approved with one item
/// flagged later isn't the same as never having been approved.
class _KycRejectedBanner extends StatelessWidget {
  const _KycRejectedBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: context.surface.withValues(alpha: 0.92),
        border: Border.all(color: context.amber.withValues(alpha: 0.35)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: <Widget>[
          Icon(DrivioIcons.document, size: 16, color: context.amber),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Some documents need fixing',
                  style: TextStyle(
                    fontSize: 12,
                    color: context.amber,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  'Tap to see what needs another look.',
                  style: TextStyle(fontSize: 11, color: context.text),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: () =>
                AppNavigation.push<void>(AppRoutes.kycRejectedItems),
            style: ElevatedButton.styleFrom(
              backgroundColor: context.amber,
              foregroundColor: context.amberInk,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              minimumSize: const Size(0, 30),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              'Review',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

```

- [ ] **Step 5: Analyze**

```bash
fvm flutter analyze lib/modules/dash/features/drive_shell/presentation/ui/drive_shell_page.dart
```

Expected: `No issues found!`

- [ ] **Step 6: Commit**

```bash
git add lib/modules/dash/features/drive_shell/presentation/ui/drive_shell_page.dart
git commit -m "Home banner surfaces a live document rejection

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

### Task 9: KYC checklist routes a rejected step into the guided overview

**Files:**
- Modify: `drivio_driver/lib/modules/kyc/features/kyc_home/presentation/ui/kyc_home_page.dart`

**Interfaces:**
- Consumes: `AppRoutes.kycRejectedItems` (Task 7), `KycStep.status`/`KycStepStatus` (existing).
- Produces: nothing new consumed elsewhere.

- [ ] **Step 1: Route a rejected/expired step through the overview**

Find the `_StepRow` widget's tap handler and `_routeForStep` method:

```dart
        onTap: isInteractive
            ? () => _routeForStep(
                step.kind,
              ).whenComplete(() => onReturned?.call())
            : null,
```

and

```dart
  Future<void> _routeForStep(KycStepKind kind) {
    // Vehicle registration and insurance upload INSIDE the add-vehicle
    // flow, so they are not separate checklist steps.
    switch (kind) {
      case KycStepKind.bvnNin:
        return AppNavigation.push<void>(AppRoutes.kycBvnNin);
      case KycStepKind.selfie:
        return AppNavigation.push<void>(AppRoutes.kycSelfie);
      case KycStepKind.driversLicence:
        return AppNavigation.push<void>(
          AppRoutes.kycDocumentCapture,
          arguments: DocumentKind.driversLicence,
        );
      case KycStepKind.vehicle:
        return AppNavigation.push<void>(AppRoutes.addVehicle);
    }
  }
```

Replace the tap handler with:

```dart
        onTap: isInteractive
            ? () => _routeForStep(step).whenComplete(() => onReturned?.call())
            : null,
```

Replace `_routeForStep` with:

```dart
  Future<void> _routeForStep(KycStep step) {
    // A rejected (or expired) step always goes through the guided
    // overview — even for a step with its own normal starting flow
    // (licence, vehicle) — so there's exactly one consistent "fix what's
    // wrong" experience everywhere, no matter which surface the driver
    // tapped from.
    if (step.status == KycStepStatus.rejected ||
        step.status == KycStepStatus.expired) {
      return AppNavigation.push<void>(AppRoutes.kycRejectedItems);
    }
    // Vehicle registration and insurance upload INSIDE the add-vehicle
    // flow, so they are not separate checklist steps.
    switch (step.kind) {
      case KycStepKind.bvnNin:
        return AppNavigation.push<void>(AppRoutes.kycBvnNin);
      case KycStepKind.selfie:
        return AppNavigation.push<void>(AppRoutes.kycSelfie);
      case KycStepKind.driversLicence:
        return AppNavigation.push<void>(
          AppRoutes.kycDocumentCapture,
          arguments: DocumentKind.driversLicence,
        );
      case KycStepKind.vehicle:
        return AppNavigation.push<void>(AppRoutes.addVehicle);
    }
  }
```

- [ ] **Step 2: Analyze**

```bash
fvm flutter analyze lib/modules/kyc/features/kyc_home/presentation/ui/kyc_home_page.dart
```

Expected: `No issues found!`

- [ ] **Step 3: Commit**

```bash
git add lib/modules/kyc/features/kyc_home/presentation/ui/kyc_home_page.dart
git commit -m "KYC checklist routes a rejected step into the guided overview

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

### Task 10: Profile hub and vehicle details show a live vehicle rejection

**Files:**
- Modify: `drivio_driver/lib/modules/dash/features/profile_hub/presentation/ui/profile_hub_page.dart`
- Modify: `drivio_driver/lib/modules/profile/features/vehicle_details/presentation/ui/vehicle_details_page.dart`

**Interfaces:**
- Consumes: `hasRejectedVehicleDocument(Map<DocumentKind, Document>)` (Task 4), `ProfileHubState.documentsByKind` (existing), `AppRoutes.kycRejectedItems` (Task 7).
- Produces: nothing new consumed elsewhere.

- [ ] **Step 1: `_VehicleGroup` (profile hub) — show and route the rejection**

Find the `_VehicleGroup` class in `profile_hub_page.dart`:

```dart
class _VehicleGroup extends StatelessWidget {
  const _VehicleGroup({required this.state});
  final ProfileHubState state;

  @override
  Widget build(BuildContext context) {
    final Vehicle? active = state.activeVehicle;
    final Vehicle? pending = state.pendingVehicle;
    final Vehicle? v = active ?? pending;
    final bool approved = active != null;
    final bool changeRequested = active != null && pending != null;
    final bool inReview = !approved && pending != null;
    final String vehicleTitle = v == null
        ? 'No active vehicle'
        : '${v.make} ${v.model}${v.year > 0 ? ' · ${v.year}' : ''}';
    final String? colour = v?.colour;
    final String plateBit = v == null
        ? ''
        : '${v.plate}${(colour == null || colour.isEmpty) ? '' : ' · ${colour.toLowerCase()}'}';
    final String vehicleSub = v == null
        ? 'Add or activate one to receive requests'
        : inReview
            ? '$plateBit · In review'
            : plateBit;
    return _Group(
      title: 'VEHICLE',
      children: <Widget>[
        FieldRow(
          label: vehicleTitle,
          value: vehicleSub,
          right: approved
              ? Icon(DrivioIcons.checkCircle, size: 18, color: context.accent)
              : inReview
                  ? Icon(DrivioIcons.refresh, size: 18, color: context.amber)
                  : null,
          divider: changeRequested,
          onTap: v == null
              ? () => AppNavigation.push(AppRoutes.addVehicle)
              : () => AppNavigation.push(AppRoutes.vehicleDetails),
        ),
        // A requested swap reads as a second line under the current
        // vehicle: what they drive today above, what is coming below.
        if (changeRequested)
          FieldRow(
            label: 'Changing to ${pending.make} ${pending.model}',
            value: 'New vehicle in review',
            right: Icon(DrivioIcons.refresh, size: 18, color: context.amber),
            divider: false,
            onTap: () => AppNavigation.push(AppRoutes.vehicleDetails),
          ),
      ],
    );
  }
}
```

Replace it with:

```dart
class _VehicleGroup extends StatelessWidget {
  const _VehicleGroup({required this.state});
  final ProfileHubState state;

  @override
  Widget build(BuildContext context) {
    final Vehicle? active = state.activeVehicle;
    final Vehicle? pending = state.pendingVehicle;
    final Vehicle? v = active ?? pending;
    final bool approved = active != null;
    final bool changeRequested = active != null && pending != null;
    final bool inReview = !approved && pending != null;
    final bool rejected = hasRejectedVehicleDocument(state.documentsByKind);
    final String vehicleTitle = v == null
        ? 'No active vehicle'
        : '${v.make} ${v.model}${v.year > 0 ? ' · ${v.year}' : ''}';
    final String? colour = v?.colour;
    final String plateBit = v == null
        ? ''
        : '${v.plate}${(colour == null || colour.isEmpty) ? '' : ' · ${colour.toLowerCase()}'}';
    final String vehicleSub = rejected
        ? 'Needs another look — tap to fix'
        : v == null
            ? 'Add or activate one to receive requests'
            : inReview
                ? '$plateBit · In review'
                : plateBit;
    return _Group(
      title: 'VEHICLE',
      children: <Widget>[
        FieldRow(
          label: vehicleTitle,
          value: vehicleSub,
          right: rejected
              ? Icon(DrivioIcons.close, size: 18, color: context.red)
              : approved
                  ? Icon(DrivioIcons.checkCircle,
                      size: 18, color: context.accent)
                  : inReview
                      ? Icon(DrivioIcons.refresh,
                          size: 18, color: context.amber)
                      : null,
          divider: changeRequested,
          // A live rejection always wins the tap target — never send a
          // driver with a rejected vehicle document back into "Add a
          // vehicle" (that's what created duplicate vehicles before).
          onTap: rejected
              ? () => AppNavigation.push(AppRoutes.kycRejectedItems)
              : v == null
                  ? () => AppNavigation.push(AppRoutes.addVehicle)
                  : () => AppNavigation.push(AppRoutes.vehicleDetails),
        ),
        // A requested swap reads as a second line under the current
        // vehicle: what they drive today above, what is coming below.
        if (changeRequested)
          FieldRow(
            label: 'Changing to ${pending.make} ${pending.model}',
            value: 'New vehicle in review',
            right: Icon(DrivioIcons.refresh, size: 18, color: context.amber),
            divider: false,
            onTap: () => AppNavigation.push(AppRoutes.vehicleDetails),
          ),
      ],
    );
  }
}
```

- [ ] **Step 2: `VehicleDetailsPage` — show the rejection there too**

Find:

```dart
class VehicleDetailsPage extends ConsumerWidget {
  const VehicleDetailsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ProfileHubState state = ref.watch(profileHubControllerProvider);
    final Vehicle? v = state.activeVehicle;

    if (state.isLoading && v == null) {
      return DetailScaffold(
        title: 'Vehicle details',
        children: <Widget>[
          _VehicleDetailsShimmer(
            base: context.surface2,
            highlight: context.surface3,
          ),
        ],
      );
    }

    if (v == null) {
      return DetailScaffold(
        title: 'Vehicle details',
        footer: DrivioButton(
          label: 'Add a vehicle',
          onPressed: () => AppNavigation.push(AppRoutes.addVehicle),
        ),
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 30),
            child: Center(
              child: Text(
                'No active vehicle on your account.',
                style: AppTextStyles.bodySm.copyWith(color: context.textDim),
              ),
            ),
          ),
        ],
      );
    }

    final (String pillText, PillTone pillTone) = _statusPill(v.status);
    final Vehicle? pendingChange =
        state.activeVehicle != null ? state.pendingVehicle : null;

    return DetailScaffold(
      title: 'Vehicle details',
      subtitle: '${v.make} ${v.model} · ${v.plate}',
      badge: Pill(text: pillText, tone: pillTone),
      // While a change is under review a second request makes no sense,
      // so the footer action steps aside for the status section below.
      footer: pendingChange != null
          ? null
          : DrivioButton(
              label: 'Request vehicle change',
              variant: DrivioButtonVariant.ghost,
              onPressed: () => AppNavigation.push(AppRoutes.vehicleChange),
            ),
      children: <Widget>[
        if (pendingChange != null) ...<Widget>[
          _ChangeRequestSection(pending: pendingChange, current: v),
          const SizedBox(height: 16),
        ],
```

Replace it with:

```dart
class VehicleDetailsPage extends ConsumerWidget {
  const VehicleDetailsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ProfileHubState state = ref.watch(profileHubControllerProvider);
    final Vehicle? v = state.activeVehicle;
    final bool rejected = hasRejectedVehicleDocument(state.documentsByKind);

    if (state.isLoading && v == null) {
      return DetailScaffold(
        title: 'Vehicle details',
        children: <Widget>[
          _VehicleDetailsShimmer(
            base: context.surface2,
            highlight: context.surface3,
          ),
        ],
      );
    }

    if (v == null) {
      return DetailScaffold(
        title: 'Vehicle details',
        footer: DrivioButton(
          label: rejected ? 'Review what needs fixing' : 'Add a vehicle',
          onPressed: () => AppNavigation.push(
            rejected ? AppRoutes.kycRejectedItems : AppRoutes.addVehicle,
          ),
        ),
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 30),
            child: Center(
              child: Text(
                rejected
                    ? 'One or more of your vehicle documents need another look.'
                    : 'No active vehicle on your account.',
                style: AppTextStyles.bodySm.copyWith(color: context.textDim),
              ),
            ),
          ),
        ],
      );
    }

    final (String pillText, PillTone pillTone) = _statusPill(v.status);
    final Vehicle? pendingChange =
        state.activeVehicle != null ? state.pendingVehicle : null;

    return DetailScaffold(
      title: 'Vehicle details',
      subtitle: '${v.make} ${v.model} · ${v.plate}',
      badge: Pill(text: pillText, tone: pillTone),
      // While a change is under review a second request makes no sense,
      // so the footer action steps aside for the status section below.
      footer: pendingChange != null
          ? null
          : DrivioButton(
              label: 'Request vehicle change',
              variant: DrivioButtonVariant.ghost,
              onPressed: () => AppNavigation.push(AppRoutes.vehicleChange),
            ),
      children: <Widget>[
        if (rejected) ...<Widget>[
          _VehicleRejectedBanner(
            onTap: () => AppNavigation.push(AppRoutes.kycRejectedItems),
          ),
          const SizedBox(height: 16),
        ],
        if (pendingChange != null) ...<Widget>[
          _ChangeRequestSection(pending: pendingChange, current: v),
          const SizedBox(height: 16),
        ],
```

(Everything after this point in the file — the vehicle image, `GridView.count` stat blocks, and the "Changing your vehicle requires re-verification" info box — is unchanged.)

- [ ] **Step 3: Add the `_VehicleRejectedBanner` widget**

Add this class to `vehicle_details_page.dart`, right after the closing brace of the `VehicleDetailsPage` class (before `class _StatBlock extends StatelessWidget {`):

```dart
class _VehicleRejectedBanner extends StatelessWidget {
  const _VehicleRejectedBanner({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.base,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: context.red.withValues(alpha: 0.10),
          borderRadius: AppRadius.base,
          border: Border.all(color: context.red.withValues(alpha: 0.35)),
        ),
        child: Row(
          children: <Widget>[
            Icon(DrivioIcons.close, size: 18, color: context.red),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'One or more vehicle documents need another look.',
                style: AppTextStyles.bodySm.copyWith(
                  color: context.text,
                  height: 1.4,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'Fix',
              style: AppTextStyles.captionSm.copyWith(
                fontSize: 11,
                color: context.red,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Import `hasRejectedVehicleDocument`**

Both files already import `DocumentKind`/`Document` (confirm via the existing `documentsByKind: state.documentsByKind` usage). Add this import to `vehicle_details_page.dart` (it isn't currently imported there):

```dart
import 'package:drivio_driver/modules/commons/types/document.dart';
```

`profile_hub_page.dart` already imports `commons/types/document.dart` — no change needed there.

- [ ] **Step 5: Analyze**

```bash
fvm flutter analyze lib/modules/dash/features/profile_hub/presentation/ui/profile_hub_page.dart lib/modules/profile/features/vehicle_details/presentation/ui/vehicle_details_page.dart
```

Expected: `No issues found!`

- [ ] **Step 6: Commit**

```bash
git add lib/modules/dash/features/profile_hub/presentation/ui/profile_hub_page.dart lib/modules/profile/features/vehicle_details/presentation/ui/vehicle_details_page.dart
git commit -m "Profile hub and vehicle details surface a live vehicle rejection

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

### Task 11: Push notification deep-links straight to the rejected document's fix screen

**Files:**
- Modify: `drivio_driver/lib/modules/commons/push/call_push_handler.dart`

**Interfaces:**
- Consumes: `payload.document_kind` / `payload.vehicle_id` / `payload.rejection_reason` from the `document_rejected` push (Task 2), `DocumentCaptureArgs` (Task 6), `DocumentKind.fromWire` (existing).
- Produces: nothing new consumed elsewhere.

- [ ] **Step 1: Add the imports**

At the top of `call_push_handler.dart`, add these two imports alongside the existing ones:

```dart
import 'package:drivio_driver/modules/commons/types/document.dart';
import 'package:drivio_driver/modules/kyc/features/document_capture/presentation/ui/document_capture_page.dart';
```

- [ ] **Step 2: Branch on `document_rejected` in `_onNotificationOpened`**

Find:

```dart
  /// Notification tap (background or killed launch) → deep-link. Chat pushes
  /// carry `type=chat_message` + `trip_id` and open that trip's chat.
  void _onNotificationOpened(RemoteMessage m) {
    if (m.data['type'] != 'chat_message') {
      return;
    }
    final Object? tripId = m.data['trip_id'];
    if (tripId is! String) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AppNavigation.push<void>(AppRoutes.chat, arguments: tripId);
    });
  }
```

Replace it with:

```dart
  /// Notification tap (background or killed launch) → deep-link. Chat
  /// pushes carry `type=chat_message` + `trip_id` and open that trip's
  /// chat; document-rejection pushes carry `type=document_rejected` and
  /// open the fix screen for that exact document.
  void _onNotificationOpened(RemoteMessage m) {
    if (m.data['type'] == 'document_rejected') {
      _openRejectedDocument(m.data.cast<String, dynamic>());
      return;
    }
    if (m.data['type'] != 'chat_message') {
      return;
    }
    final Object? tripId = m.data['trip_id'];
    if (tripId is! String) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AppNavigation.push<void>(AppRoutes.chat, arguments: tripId);
    });
  }
```

- [ ] **Step 3: Add the top-level deep-link function**

Add this function near the bottom of the file, right after the `CallPushBridge` class's closing brace:

```dart
/// Deep-links a tapped "document rejected" push straight to the fix
/// screen for that exact document — the push already told the driver
/// which one, so there's no reason to route through the overview list
/// first. The push carries the SAME rejection reason shown in its own
/// notification body, plus the vehicle id for vehicle-related kinds
/// (see `_push_document_rejected` in the backend).
void _openRejectedDocument(Map<String, dynamic> data) {
  final Object? kindWire = data['document_kind'];
  if (kindWire is! String) {
    return;
  }
  final DocumentKind kind = DocumentKind.fromWire(kindWire);
  final Object? vehicleId = data['vehicle_id'];
  final Object? reason = data['rejection_reason'];
  WidgetsBinding.instance.addPostFrameCallback((_) {
    AppNavigation.push<bool>(
      AppRoutes.kycDocumentCapture,
      arguments: DocumentCaptureArgs(
        kind: kind,
        vehicleId: vehicleId is String ? vehicleId : null,
        rejectionReason:
            reason is String && reason.trim().isNotEmpty ? reason : null,
      ),
    );
  });
}
```

- [ ] **Step 4: Analyze**

```bash
fvm flutter analyze lib/modules/commons/push/call_push_handler.dart
```

Expected: `No issues found!`

- [ ] **Step 5: Full-project analyze**

```bash
fvm flutter analyze
```

Expected: only the same pre-existing, unrelated lint infos that existed before this feature (no new errors or warnings anywhere in the project).

- [ ] **Step 6: Run the full test suite**

```bash
fvm flutter test
```

Expected: all tests pass, including the 5 new tests from Task 4.

- [ ] **Step 7: Commit**

```bash
git add lib/modules/commons/push/call_push_handler.dart
git commit -m "Deep-link the document-rejected push to its fix screen

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

## Manual end-to-end verification (after all tasks)

Not automatable without a live device + real Supabase state — run once after Task 11:

1. Pick a real (or test) driver. Via `execute_sql` against project `gxzyednqegqycnmbdghf`, reject one vehicle photo and the driver's licence:
   ```sql
   update public.documents
   set status = 'rejected', rejection_reason = 'Test: photo is blurry', updated_at = now()
   where owner_user_id = '<driver-uuid>' and kind = 'vehicle_photo_front'
   order by created_at desc limit 1;

   update public.documents
   set status = 'rejected', rejection_reason = 'Test: expired licence', updated_at = now()
   where owner_user_id = '<driver-uuid>' and kind = 'drivers_licence'
   order by created_at desc limit 1;
   ```
2. Open the app as that driver: confirm the home banner reads "Some documents need fixing" (amber, not the full onboarding-incomplete banner).
3. Tap the banner → confirm `RejectedItemsPage` lists exactly 2 rows (vehicle photo + licence) with the test reasons.
4. Tap the vehicle photo row → confirm the rejection reason shows above the upload control, upload a new photo, submit → confirm it pops back to the overview with that row now showing "Uploaded" and no longer tappable, while the licence row is still active.
5. Fix the licence row the same way → confirm the closing "You're all set" state appears.
6. Query `public.vehicles` for this driver and confirm there is still exactly ONE non-deleted row (no duplicate was created).
7. Confirm `public.documents` has a new `pending` row for both kinds, and the OLD rejected rows are untouched (history preserved).
8. Send a fresh rejection push (re-run one of the `update` statements above) and tap the resulting notification (or `getInitialMessage` from a killed state) — confirm it opens `DocumentCapturePage` directly for that one document, reason shown, without visiting the overview.
