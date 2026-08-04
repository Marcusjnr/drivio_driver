import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:drivio_driver/modules/commons/di/di.dart';
import 'package:drivio_driver/modules/commons/location/presence_background.dart';
import 'package:drivio_driver/modules/commons/overlay/ride_request_overlay.dart';
import 'package:drivio_driver/modules/commons/push/ride_alert_push.dart';
import 'package:drivio_driver/modules/commons/supabase/supabase_module.dart';

class LifecycleController with WidgetsBindingObserver {
  LifecycleController() {
    WidgetsBinding.instance.addObserver(this);
    // App boot = foregrounded. Keep the flag the presence-service poll
    // reads honest from the very first frame.
    unawaited(_setForegroundFlag(true));
  }

  static Future<void> _setForegroundFlag(bool foreground) async {
    try {
      await FlutterForegroundTask.saveData(
        key: BgPresenceKeys.appForeground,
        value: foreground,
      );
    } catch (_) {
      // Best-effort — worst case the poll rings while foregrounded.
    }
  }

  final SupabaseModule _supabase = locator<SupabaseModule>();
  DateTime? _lastPausedAt;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
        _onPaused();
        break;
      case AppLifecycleState.resumed:
        _onResumed();
        break;
      default:
        break;
    }
  }

  void _onPaused() {
    _lastPausedAt = DateTime.now();
    unawaited(_setForegroundFlag(false));
    // On-shift anchor: an ONLINE driver who minimises the app gets the
    // floating Drivio bubble (tap = straight back into the app). Offline
    // drivers get nothing, and without the overlay permission this is a
    // silent no-op.
    unawaited(_showIdleBubbleIfOnline());
  }

  Future<void> _showIdleBubbleIfOnline() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      // This isolate wrote the flag when the driver went online, so no
      // reload needed — and reading the cache keeps this instant.
      if (prefs.getBool('presence_intended_online') ?? false) {
        await showIdleDriverOverlay();
      }
    } catch (_) {
      // Bubble is a bonus layer — never let it interfere with pausing.
    }
  }

  void _onResumed() {
    unawaited(_setForegroundFlag(true));
    // The driver has the app in front of them again — silence any new-trip
    // alert that was ringing in the background (the live feed takes over).
    unawaited(stopRideRequestAlert());
    // Drop this isolate's stale SharedPreferences cache before any screen
    // reads it. Background isolates (the "Go online" notification action)
    // write prefs that this isolate's Dart-side cache will otherwise never
    // see. App-wide because the driver may resume on ANY tab, and only the
    // drive shell reconciles presence on its own.
    unawaited(_reloadPrefs());

    final DateTime? pausedAt = _lastPausedAt;
    _lastPausedAt = null;

    if (pausedAt == null) return;

    final Duration elapsed = DateTime.now().difference(pausedAt);

    // If backgrounded for more than 30 seconds, refresh session
    if (elapsed.inSeconds > 30) {
      _refreshSession();
    }
  }

  Future<void> _reloadPrefs() async {
    try {
      await (await SharedPreferences.getInstance()).reload();
    } catch (_) {
      // Best-effort — reconcileOnStart reloads again before it reads.
    }
  }

  Future<void> _refreshSession() async {
    try {
      await _supabase.auth.refreshSession();
    } catch (_) {
      // SessionGuard handles signedOut/tokenRefreshFailed events
    }
  }

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
  }
}
