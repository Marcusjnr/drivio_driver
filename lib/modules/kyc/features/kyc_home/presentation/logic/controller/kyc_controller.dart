import 'package:flutter_riverpod/flutter_riverpod.dart';

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
  vehicleReg,
  insurance,
  roadWorthiness,
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

class KycState {
  const KycState({
    this.overall = KycOverallStatus.notStarted,
    this.steps = const <KycStep>[],
    this.isLoading = false,
    this.isSubmitting = false,
    this.error,
  });

  final KycOverallStatus overall;
  final List<KycStep> steps;
  final bool isLoading;
  final bool isSubmitting;
  final String? error;

  bool get allRequiredSubmitted => steps.every(
        (KycStep s) =>
            s.status == KycStepStatus.submitted ||
            s.status == KycStepStatus.approved,
      );

  bool get canSubmitForReview =>
      allRequiredSubmitted &&
      (overall == KycOverallStatus.notStarted ||
          overall == KycOverallStatus.inProgress ||
          overall == KycOverallStatus.rejected);

  KycState copyWith({
    KycOverallStatus? overall,
    List<KycStep>? steps,
    bool? isLoading,
    bool? isSubmitting,
    String? error,
    bool clearError = false,
  }) {
    return KycState(
      overall: overall ?? this.overall,
      steps: steps ?? this.steps,
      isLoading: isLoading ?? this.isLoading,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class KycController extends StateNotifier<KycState> {
  KycController(this._repo) : super(const KycState());

  final KycRepository _repo;

  Future<void> refresh() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final KycSnapshot snap = await _repo.loadSnapshot();
      state = state.copyWith(
        overall: KycOverallStatus.fromWire(snap.kycStatus),
        steps: _buildSteps(snap),
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
          error: 'Submission rejected — refresh and try again.',
        );
        return false;
      }
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

  List<KycStep> _buildSteps(KycSnapshot snap) {
    Document? docOf(DocumentKind k) {
      for (final Document d in snap.documents) {
        if (d.kind == k) return d;
      }
      return null;
    }

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

    final KycStepStatus bvnNinStatus = (snap.bvnVerifiedAt != null ||
            snap.ninVerifiedAt != null)
        ? KycStepStatus.submitted
        : KycStepStatus.required;
    final KycStepStatus selfieStatus = snap.livenessPassedAt != null
        ? KycStepStatus.submitted
        : KycStepStatus.required;

    final Document? dl = docOf(DocumentKind.driversLicence);
    final Document? reg = docOf(DocumentKind.vehicleReg);
    final Document? ins = docOf(DocumentKind.insurance);
    final Document? rw = docOf(DocumentKind.roadWorthiness);

    return <KycStep>[
      KycStep(
        kind: KycStepKind.bvnNin,
        title: 'BVN or NIN',
        subtitle: 'Verify your identity (NIBSS / NIMC).',
        status: bvnNinStatus,
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
        subtitle: 'FRSC card · front and back.',
        status: statusOf(dl),
        rejectionReason: dl?.rejectionReason,
      ),
      KycStep(
        kind: KycStepKind.vehicle,
        title: 'Add a vehicle',
        subtitle: 'Make, model, plate.',
        status: snap.hasVehicle
            ? KycStepStatus.submitted
            : KycStepStatus.required,
      ),
      KycStep(
        kind: KycStepKind.vehicleReg,
        title: 'Vehicle registration',
        subtitle: 'Lagos State or your home state.',
        status: statusOf(reg),
        rejectionReason: reg?.rejectionReason,
      ),
      KycStep(
        kind: KycStepKind.insurance,
        title: 'Proof of insurance',
        subtitle: 'Comprehensive cover preferred.',
        status: statusOf(ins),
        rejectionReason: ins?.rejectionReason,
      ),
      KycStep(
        kind: KycStepKind.roadWorthiness,
        title: 'Road worthiness',
        subtitle: 'Annual certificate.',
        status: statusOf(rw),
        rejectionReason: rw?.rejectionReason,
      ),
    ];
  }
}

final StateNotifierProvider<KycController, KycState> kycControllerProvider =
    StateNotifierProvider<KycController, KycState>(
  (Ref _) => KycController(locator<KycRepository>()),
);
