import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:drivio_driver/modules/commons/di/di.dart';
import 'package:drivio_driver/modules/kyc/features/kyc_home/presentation/logic/data/kyc_repository.dart';

enum BvnNinKind { bvn, nin }

class BvnNinState {
  const BvnNinState({
    this.kind = BvnNinKind.bvn,
    this.value = '',
    this.isVerifying = false,
    this.error,
    this.completed = false,
  });

  final BvnNinKind kind;
  final String value;
  final bool isVerifying;
  final bool completed;
  final String? error;

  bool get hasValidNumber {
    final String digits = value.replaceAll(RegExp(r'\D'), '');
    return digits.length == 11;
  }

  BvnNinState copyWith({
    BvnNinKind? kind,
    String? value,
    bool? isVerifying,
    bool? completed,
    String? error,
    bool clearError = false,
  }) {
    return BvnNinState(
      kind: kind ?? this.kind,
      value: value ?? this.value,
      isVerifying: isVerifying ?? this.isVerifying,
      completed: completed ?? this.completed,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class BvnNinController extends StateNotifier<BvnNinState> {
  BvnNinController(this._repo) : super(const BvnNinState());

  final KycRepository _repo;

  void setKind(BvnNinKind k) =>
      state = state.copyWith(kind: k, clearError: true);
  void setValue(String v) =>
      state = state.copyWith(value: v, clearError: true);

  Future<bool> verify() async {
    if (!state.hasValidNumber) return false;
    state = state.copyWith(isVerifying: true, clearError: true);
    try {
      await _repo.markStepCompleted(state.kind == BvnNinKind.bvn ? 'bvn' : 'nin');
      state = state.copyWith(isVerifying: false, completed: true);
      return true;
    } catch (_) {
      state = state.copyWith(
        isVerifying: false,
        error: 'Could not verify. Please try again.',
      );
      return false;
    }
  }
}

final AutoDisposeStateNotifierProvider<BvnNinController, BvnNinState>
    bvnNinControllerProvider =
    StateNotifierProvider.autoDispose<BvnNinController, BvnNinState>(
  (Ref ref) => BvnNinController(locator<KycRepository>()),
);
