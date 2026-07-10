import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:drivio_driver/modules/commons/di/di.dart';
import 'package:drivio_driver/modules/kyc/features/kyc_home/presentation/logic/data/kyc_repository.dart';

/// NIN verification (NIMC). Identity is NIN-only — BVN was dropped from
/// the KYC flow. `verify` is a dev stub today: it stamps the step
/// completed so the flow can be exercised end to end. The real NIMC
/// lookup API replaces the repo call when it lands; admins never approve
/// this step by hand.
class NinState {
  const NinState({
    this.value = '',
    this.isVerifying = false,
    this.error,
    this.completed = false,
  });

  final String value;
  final bool isVerifying;
  final bool completed;
  final String? error;

  bool get hasValidNumber {
    final String digits = value.replaceAll(RegExp(r'\D'), '');
    return digits.length == 11;
  }

  NinState copyWith({
    String? value,
    bool? isVerifying,
    bool? completed,
    String? error,
    bool clearError = false,
  }) {
    return NinState(
      value: value ?? this.value,
      isVerifying: isVerifying ?? this.isVerifying,
      completed: completed ?? this.completed,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class NinController extends StateNotifier<NinState> {
  NinController(this._repo) : super(const NinState());

  final KycRepository _repo;

  void setValue(String v) => state = state.copyWith(value: v, clearError: true);

  Future<bool> verify() async {
    if (!state.hasValidNumber) return false;
    state = state.copyWith(isVerifying: true, clearError: true);
    try {
      await _repo.markStepCompleted('nin');
      // Success: stay verifying — the page refreshes KYC and pops.
      state = state.copyWith(completed: true);
      return true;
    } catch (_) {
      state = state.copyWith(
        isVerifying: false,
        error: "Couldn't verify. Double-check your NIN and try again.",
      );
      return false;
    }
  }
}

final AutoDisposeStateNotifierProvider<NinController, NinState>
    ninControllerProvider =
    StateNotifierProvider.autoDispose<NinController, NinState>(
  (Ref ref) => NinController(locator<KycRepository>()),
);
