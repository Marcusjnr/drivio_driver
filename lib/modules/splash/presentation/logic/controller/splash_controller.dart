import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:drivio_driver/modules/commons/di/di.dart';
import 'package:drivio_driver/modules/commons/location/location_permission_service.dart';

/// Phases the splash transitions through. Drives both the visual
/// composition (when to show the permission card vs continue button)
/// and the moment we hand off to the bootstrap-resolved route.
enum SplashPhase {
  /// Brand reveal animation playing, no permission action surfaced.
  brandReveal,

  /// Permission status was checked; we're either prompting the user
  /// or showing a "Go to settings" CTA depending on [permission].
  askingPermission,

  /// Driver dismissed the permission card (granted or skipped) and
  /// the splash is fading out before the navigator hands off.
  proceeding,
}

class SplashState {
  const SplashState({
    this.phase = SplashPhase.brandReveal,
    this.permission = LocationPermState.unknown,
    this.isRequesting = false,
  });

  final SplashPhase phase;
  final LocationPermState permission;

  /// True while a system permission dialog is up — used to disable
  /// the buttons so the driver can't hammer them.
  final bool isRequesting;

  SplashState copyWith({
    SplashPhase? phase,
    LocationPermState? permission,
    bool? isRequesting,
  }) {
    return SplashState(
      phase: phase ?? this.phase,
      permission: permission ?? this.permission,
      isRequesting: isRequesting ?? this.isRequesting,
    );
  }
}

/// Owns the splash's permission flow. The brand-reveal timing lives
/// here too so the page can reactively swap from "logo only" to
/// "logo + permission card" once the brand-reveal is complete.
class SplashController extends StateNotifier<SplashState> {
  SplashController(this._perm) : super(const SplashState()) {
    _begin();
  }

  final LocationPermissionService _perm;

  /// How long the wordmark + radar pulse hold center-stage before
  /// the permission card slides up. Long enough to register the
  /// brand, short enough not to feel slow.
  static const Duration _brandRevealHold = Duration(milliseconds: 1100);

  Future<void> _begin() async {
    // Check permission silently in parallel with the brand reveal.
    // If permission is already granted we'll skip the card entirely
    // and proceed straight to the app — drivers who've used the
    // app before don't see the ask twice.
    final Future<LocationPermState> probe = _perm.currentState();
    await Future<void>.delayed(_brandRevealHold);
    final LocationPermState current = await probe;
    if (!mounted) return;

    if (current == LocationPermState.granted) {
      state = state.copyWith(
        permission: current,
        phase: SplashPhase.proceeding,
      );
      return;
    }
    state = state.copyWith(
      permission: current,
      phase: SplashPhase.askingPermission,
    );
  }

  /// Fired by the "Allow location" button. Triggers the system
  /// dialog and routes the user to whichever continuation is
  /// appropriate based on the result.
  Future<void> requestPermission() async {
    if (state.isRequesting) return;
    state = state.copyWith(isRequesting: true);
    final LocationPermState result = await _perm.request();
    if (!mounted) return;
    state = state.copyWith(
      permission: result,
      isRequesting: false,
      // Whatever the outcome, the splash is done — the home page's
      // online-toggle gate is the safety net for denied/disabled.
      phase: SplashPhase.proceeding,
    );
  }

  /// Fired by "Not now" — driver chose to skip. Fall through to the
  /// app; they'll be re-prompted when they tap "Go online".
  void skip() {
    state = state.copyWith(phase: SplashPhase.proceeding);
  }

  /// For permanently-denied state: open the device settings so the
  /// driver can flip the toggle, then proceed regardless. We don't
  /// wait for them to come back — Android/iOS don't reliably notify
  /// us, so we let them re-trigger via the online toggle.
  Future<void> openSettingsAndProceed() async {
    if (state.permission == LocationPermState.serviceDisabled) {
      await _perm.openLocationSettings();
    } else {
      await _perm.openAppSettings();
    }
    if (!mounted) return;
    state = state.copyWith(phase: SplashPhase.proceeding);
  }
}

final StateNotifierProvider<SplashController, SplashState>
    splashControllerProvider =
    StateNotifierProvider<SplashController, SplashState>(
  (Ref _) =>
      SplashController(locator<LocationPermissionService>()),
);
