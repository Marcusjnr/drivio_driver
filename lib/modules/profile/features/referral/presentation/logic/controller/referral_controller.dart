import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:drivio_driver/modules/commons/data/profile_summary_repository.dart';
import 'package:drivio_driver/modules/commons/di/di.dart';
import 'package:drivio_driver/modules/commons/types/profile_summary.dart';

class ReferralState {
  const ReferralState({
    this.summary = ReferralSummary.empty,
    this.isLoading = true,
    this.error,
  });

  final ReferralSummary summary;
  final bool isLoading;
  final String? error;

  ReferralState copyWith({
    ReferralSummary? summary,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return ReferralState(
      summary: summary ?? this.summary,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class ReferralController extends StateNotifier<ReferralState> {
  ReferralController(this._repo) : super(const ReferralState()) {
    _hydrate();
  }

  final ProfileSummaryRepository _repo;

  Future<void> refresh() => _hydrate();

  Future<void> _hydrate() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final ReferralSummary s = await _repo.getMyReferralSummary();
      if (!mounted) return;
      state = state.copyWith(summary: s, isLoading: false);
    } catch (_) {
      if (!mounted) return;
      state = state.copyWith(
        isLoading: false,
        error: 'Could not load referral data.',
      );
    }
  }
}

final StateNotifierProvider<ReferralController, ReferralState>
    referralControllerProvider =
    StateNotifierProvider<ReferralController, ReferralState>(
  (Ref _) =>
      ReferralController(locator<ProfileSummaryRepository>()),
);
