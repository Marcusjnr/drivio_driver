import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:drivio_driver/modules/commons/data/coach_tip_repository.dart';
import 'package:drivio_driver/modules/commons/di/di.dart';
import 'package:drivio_driver/modules/commons/types/coach_tip.dart';

class CoachTipState {
  const CoachTipState({
    this.tips = const <CoachTip>[],
    this.isLoading = true,
    this.dismissed = const <String>{},
  });

  final List<CoachTip> tips;
  final bool isLoading;

  /// Codes the user dismissed in this session — we don't surface
  /// them again until the next refresh window.
  final Set<String> dismissed;

  /// Visible tips: server-returned minus session-dismissed.
  List<CoachTip> get visible =>
      tips.where((CoachTip t) => !dismissed.contains(t.code)).toList();

  CoachTipState copyWith({
    List<CoachTip>? tips,
    bool? isLoading,
    Set<String>? dismissed,
  }) {
    return CoachTipState(
      tips: tips ?? this.tips,
      isLoading: isLoading ?? this.isLoading,
      dismissed: dismissed ?? this.dismissed,
    );
  }
}

/// Pulls the curated coaching tips on mount + every 5 min so a tip
/// triggered by recent activity (e.g. "low_win_rate" after a string
/// of losses) appears without an app restart. Cheap RPC, single row
/// per call.
class CoachTipController extends StateNotifier<CoachTipState> {
  CoachTipController(this._repo) : super(const CoachTipState()) {
    _hydrate();
    _ticker = Timer.periodic(const Duration(minutes: 5), (_) => _hydrate());
  }

  final CoachTipRepository _repo;
  Timer? _ticker;

  Future<void> refresh() => _hydrate();

  Future<void> _hydrate() async {
    try {
      final List<CoachTip> tips = await _repo.getMyTips();
      if (!mounted) return;
      state = state.copyWith(tips: tips, isLoading: false);
    } catch (_) {
      if (!mounted) return;
      // Quiet failure — coach tips are non-critical UX.
      state = state.copyWith(isLoading: false);
    }
  }

  /// Hide a tip for this session. The next server refresh re-evaluates
  /// the rule; if the underlying behaviour hasn't changed it'll come
  /// back, which is intentional (the warning still applies).
  void dismiss(String code) {
    final Set<String> next = <String>{...state.dismissed, code};
    state = state.copyWith(dismissed: next);
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }
}

final StateNotifierProvider<CoachTipController, CoachTipState>
    coachTipControllerProvider =
    StateNotifierProvider<CoachTipController, CoachTipState>(
  (Ref _) => CoachTipController(locator<CoachTipRepository>()),
);
