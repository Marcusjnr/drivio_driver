import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:drivio_driver/modules/commons/di/di.dart';
import 'package:drivio_driver/modules/kyc/features/kyc_home/presentation/logic/data/kyc_repository.dart';

/// NIN verification (NIMC via YouVerify). Identity is NIN-only — BVN was
/// dropped from the KYC flow. `verify` runs a server-side YouVerify
/// lookup that also checks the NIN's identity matches the driver's
/// profile name, and stamps `drivers.nin_verified_at` only on a match.
/// Admins never approve this step by hand.
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

    final NinVerifyResult result = await _repo.verifyNin(state.value);
    switch (result) {
      case NinVerifyResult.verified:
        // Success: stay verifying — the page refreshes KYC and pops.
        state = state.copyWith(completed: true);
        return true;
      case NinVerifyResult.mismatch:
        state = state.copyWith(
          isVerifying: false,
          error: "The details on your NIN don't match your profile. "
              'Contact support to get this sorted.',
        );
        return false;
      case NinVerifyResult.notFound:
        state = state.copyWith(
          isVerifying: false,
          error: "We couldn't find that NIN. Double-check the number "
              'and try again.',
        );
        return false;
      case NinVerifyResult.error:
        state = state.copyWith(
          isVerifying: false,
          error: "Couldn't verify right now. Check your connection "
              'and try again.',
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
