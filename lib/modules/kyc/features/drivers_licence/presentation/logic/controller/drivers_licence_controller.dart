import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:drivio_driver/modules/commons/di/di.dart';
import 'package:drivio_driver/modules/kyc/features/kyc_home/presentation/logic/data/kyc_repository.dart';

/// Driver's-licence verification (FRSC via YouVerify). Mirrors the NIN
/// step: `verify` runs a server-side YouVerify lookup that also checks the
/// licence's identity matches the driver's profile name, and stamps
/// `drivers.drivers_licence_verified_at` only on a match. Admins never
/// approve this step by hand.
class LicenceState {
  const LicenceState({
    this.value = '',
    this.isVerifying = false,
    this.error,
    this.completed = false,
  });

  final String value;
  final bool isVerifying;
  final bool completed;
  final String? error;

  /// FRSC licence numbers are alphanumeric (e.g. FKJ49206AA2). Lenient
  /// length check — YouVerify does the real validation.
  bool get hasValidNumber {
    final String clean = value.replaceAll(RegExp(r'[^A-Za-z0-9]'), '');
    return clean.length >= 6 && clean.length <= 15;
  }

  LicenceState copyWith({
    String? value,
    bool? isVerifying,
    bool? completed,
    String? error,
    bool clearError = false,
  }) {
    return LicenceState(
      value: value ?? this.value,
      isVerifying: isVerifying ?? this.isVerifying,
      completed: completed ?? this.completed,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class LicenceController extends StateNotifier<LicenceState> {
  LicenceController(this._repo) : super(const LicenceState());

  final KycRepository _repo;

  void setValue(String v) => state = state.copyWith(value: v, clearError: true);

  Future<bool> verify() async {
    if (!state.hasValidNumber) return false;
    state = state.copyWith(isVerifying: true, clearError: true);

    final NinVerifyResult result = await _repo.verifyDriversLicence(state.value);
    switch (result) {
      case NinVerifyResult.verified:
        state = state.copyWith(completed: true);
        return true;
      case NinVerifyResult.mismatch:
        state = state.copyWith(
          isVerifying: false,
          error: "The name on your licence doesn't match your profile. "
              'Contact support to get this sorted.',
        );
        return false;
      case NinVerifyResult.notFound:
        state = state.copyWith(
          isVerifying: false,
          error: "We couldn't find that licence. Double-check the number "
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

final AutoDisposeStateNotifierProvider<LicenceController, LicenceState>
    licenceControllerProvider =
    StateNotifierProvider.autoDispose<LicenceController, LicenceState>(
  (Ref ref) => LicenceController(locator<KycRepository>()),
);
