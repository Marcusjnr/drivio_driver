import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:drivio_driver/modules/commons/data/safety_repository.dart';
import 'package:drivio_driver/modules/commons/di/di.dart';

class SafetyState {
  const SafetyState({
    this.isTriggering = false,
    this.lastEventId,
    this.error,
  });

  final bool isTriggering;
  final String? lastEventId;
  final String? error;

  bool get hasFired => lastEventId != null;

  SafetyState copyWith({
    bool? isTriggering,
    String? lastEventId,
    String? error,
    bool clearError = false,
    bool clearLastEvent = false,
  }) {
    return SafetyState(
      isTriggering: isTriggering ?? this.isTriggering,
      lastEventId:
          clearLastEvent ? null : (lastEventId ?? this.lastEventId),
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class SafetyController extends StateNotifier<SafetyState> {
  SafetyController(this._repo) : super(const SafetyState());

  final SafetyRepository _repo;

  Future<bool> triggerSos({String? tripId}) async {
    state = state.copyWith(isTriggering: true, clearError: true);
    try {
      final String id = await _repo.triggerSos(tripId: tripId);
      if (!mounted) return false;
      state = state.copyWith(isTriggering: false, lastEventId: id);
      return true;
    } catch (e) {
      if (!mounted) return false;
      state = state.copyWith(
        isTriggering: false,
        error: "Couldn't raise SOS. Try again or call emergency services.",
      );
      return false;
    }
  }

  void dismissConfirmation() {
    state = state.copyWith(clearLastEvent: true);
  }
}

final StateNotifierProvider<SafetyController, SafetyState>
    safetyControllerProvider =
    StateNotifierProvider<SafetyController, SafetyState>(
  (Ref _) => SafetyController(locator<SafetyRepository>()),
);
