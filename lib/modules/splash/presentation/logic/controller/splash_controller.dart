import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Phases the splash transitions through. Location permission is no
/// longer requested here — it's asked in context the first time the
/// driver taps "Go online" (the online toggle owns the permission gate).
/// This keeps the launch from greeting drivers with a permission wall on
/// every cold start.
enum SplashPhase {
  /// Brand reveal animation playing.
  brandReveal,

  /// Reveal done; the splash fades out and hands off to the
  /// bootstrap-resolved route.
  proceeding,
}

class SplashState {
  const SplashState({this.phase = SplashPhase.brandReveal});

  final SplashPhase phase;

  SplashState copyWith({SplashPhase? phase}) =>
      SplashState(phase: phase ?? this.phase);
}

/// Holds the brand reveal on screen briefly, then proceeds. No permission
/// gating — drivers go straight into the app.
class SplashController extends StateNotifier<SplashState> {
  SplashController() : super(const SplashState()) {
    _begin();
  }

  /// How long the wordmark + radar pulse hold center-stage before the
  /// splash hands off. Long enough to register the brand, short enough
  /// not to feel slow.
  static const Duration _brandRevealHold = Duration(milliseconds: 1100);

  Future<void> _begin() async {
    await Future<void>.delayed(_brandRevealHold);
    if (!mounted) return;
    state = state.copyWith(phase: SplashPhase.proceeding);
  }
}

final StateNotifierProvider<SplashController, SplashState>
splashControllerProvider = StateNotifierProvider<SplashController, SplashState>(
  (Ref _) => SplashController(),
);
