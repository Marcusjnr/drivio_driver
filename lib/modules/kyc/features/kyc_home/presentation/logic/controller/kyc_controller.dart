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
  /// reason — see [rejectableDocumentKinds].
  static const List<DocumentKind> _inScopeKinds = rejectableDocumentKinds;

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
