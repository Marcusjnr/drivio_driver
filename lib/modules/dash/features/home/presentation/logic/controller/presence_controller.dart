import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import 'package:drivio_driver/modules/commons/config/env.dart';
import 'package:drivio_driver/modules/commons/data/presence_repository.dart';
import 'package:drivio_driver/modules/commons/di/di.dart';
import 'package:drivio_driver/modules/commons/location/background_location_service.dart';
import 'package:drivio_driver/modules/commons/supabase/supabase_module.dart';

enum PresencePermissionState {
  unknown,
  granted,
  denied,
  permanentlyDenied,
  serviceDisabled,
}

class PresenceState {
  const PresenceState({
    this.permission = PresencePermissionState.unknown,
    this.isStreaming = false,
    this.lastLat,
    this.lastLng,
    this.lastAccuracyM,
    this.lastUpdatedAt,
    this.error,
  });

  final PresencePermissionState permission;
  final bool isStreaming;
  final double? lastLat;
  final double? lastLng;
  final int? lastAccuracyM;
  final DateTime? lastUpdatedAt;
  final String? error;

  bool get hasFix => lastLat != null && lastLng != null;

  PresenceState copyWith({
    PresencePermissionState? permission,
    bool? isStreaming,
    double? lastLat,
    double? lastLng,
    int? lastAccuracyM,
    DateTime? lastUpdatedAt,
    String? error,
    bool clearError = false,
  }) {
    return PresenceState(
      permission: permission ?? this.permission,
      isStreaming: isStreaming ?? this.isStreaming,
      lastLat: lastLat ?? this.lastLat,
      lastLng: lastLng ?? this.lastLng,
      lastAccuracyM: lastAccuracyM ?? this.lastAccuracyM,
      lastUpdatedAt: lastUpdatedAt ?? this.lastUpdatedAt,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// Owns the driver's online presence. When the driver goes online we keep
/// their location flowing to `upsert_driver_presence` even after the app
/// is backgrounded, swiped away, or (Android) rebooted:
///
/// * **Android** — delegates to a `location` foreground service
///   ([BackgroundLocationService]) that streams + uploads from its own
///   isolate. This controller only mirrors the fixes into [state] for the
///   UI; it does NOT run a main-isolate stream there (avoids a second,
///   redundant GPS subscription).
/// * **iOS** — runs the main-isolate geolocator stream (kept alive in the
///   background by the `location` UIBackgroundMode) plus the native
///   significant-location shim for force-quit recovery.
class PresenceController extends StateNotifier<PresenceState> {
  PresenceController(this._repo, this._supabase) : super(const PresenceState());

  final PresenceRepository _repo;
  final SupabaseModule _supabase;
  final BackgroundLocationService _bg = BackgroundLocationService();

  StreamSubscription<Position>? _positionSub; // iOS only
  StreamSubscription<BgFix>? _bgFixSub; // Android only
  StreamSubscription<sb.AuthState>? _authSub;
  Timer? _heartbeat; // iOS only

  String? _vehicleId;

  /// Persisted across app restarts so a cold reopen knows the driver
  /// *intended* to be online (even if the UI process was destroyed while
  /// the foreground service kept running). Drives [reconcileOnStart].
  static const String _intendedOnlineKey = 'presence_intended_online';

  /// Asks for location permission, then starts background-capable
  /// streaming. Returns true on success.
  ///
  /// [silent] skips the one-off hardening prompts (notification / battery
  /// / always-upgrade) — used when resuming on a cold reopen, where we
  /// must not pop dialogs the driver already answered.
  Future<bool> startStreaming({String? vehicleId, bool silent = false}) async {
    state = state.copyWith(clearError: true);
    _vehicleId = vehicleId;

    final bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      state = state.copyWith(
        permission: PresencePermissionState.serviceDisabled,
        error: 'Turn on location services to go online.',
      );
      return false;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever) {
      state = state.copyWith(
        permission: PresencePermissionState.permanentlyDenied,
        error: 'Location is blocked. Enable it in Settings to go online.',
      );
      return false;
    }
    if (permission == LocationPermission.denied) {
      state = state.copyWith(
        permission: PresencePermissionState.denied,
        error: 'Location permission is required.',
      );
      return false;
    }

    state = state.copyWith(permission: PresencePermissionState.granted);

    // Best-effort hardening — none of these block going online:
    //  * notification permission so the FGS notification can show (A13+),
    //  * battery-optimisation exemption so OEM task-killers leave the FGS
    //    alone (Android),
    //  * "always" upgrade so the service can restart from the background
    //    (boot / package-replaced). While-in-use already keeps a
    //    foreground-started service running once backgrounded.
    if (!silent) {
      await _bestEffortHardening();
    }

    final BgSession? session = _buildSession();
    if (session == null) {
      state = state.copyWith(
        error: 'Sign-in expired. Sign in again to go online.',
      );
      return false;
    }

    if (Platform.isAndroid) {
      final bool ok = await _bg.start(session);
      if (!ok) {
        state = state.copyWith(
          error: "Couldn't start background tracking. Try again.",
        );
        return false;
      }
      await _bgFixSub?.cancel();
      _bgFixSub = _bg.fixes.listen(_onBgFix);
      unawaited(_seedLastKnownFix());
    } else {
      // iOS: main-isolate stream (background-mode kept alive) + heartbeat,
      // plus the native significant-location shim for force-quit recovery.
      await _startMainIsolateStream();
      await _bg.start(session);
    }

    _listenForTokenRotation();
    await _setIntendedOnline(true);
    state = state.copyWith(isStreaming: true);
    return true;
  }

  /// On a cold reopen, restore the online state if the driver was online
  /// when the UI process was destroyed. The Android foreground service
  /// usually survived (we just re-attach the UI to it); if it didn't
  /// (iOS termination, OEM kill, reboot), we resume streaming silently.
  /// Returns true when the driver should be shown as online.
  Future<bool> reconcileOnStart({String? vehicleId}) async {
    if (state.isStreaming) {
      return true;
    }
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    if (!(prefs.getBool(_intendedOnlineKey) ?? false)) {
      return false;
    }
    _vehicleId = vehicleId;

    if (await _bg.isRunning) {
      // Android service outlived the UI — re-attach, don't restart.
      await _bgFixSub?.cancel();
      _bgFixSub = _bg.fixes.listen(_onBgFix);
      _bg.reattach();
      _listenForTokenRotation();
      state = state.copyWith(
        isStreaming: true,
        permission: PresencePermissionState.granted,
      );
      return true;
    }

    // No live service but the driver intended to be online — resume
    // without re-popping the one-off permission prompts.
    return startStreaming(vehicleId: vehicleId, silent: true);
  }

  Future<void> stopStreaming() async {
    await _setIntendedOnline(false);
    await _authSub?.cancel();
    _authSub = null;
    await _positionSub?.cancel();
    _positionSub = null;
    await _bgFixSub?.cancel();
    _bgFixSub = null;
    _heartbeat?.cancel();
    _heartbeat = null;

    await _bg.stop();

    // Belt-and-suspenders offline marker from the main isolate. On
    // Android the FGS's own onDestroy also writes offline; the upsert is
    // idempotent so a double-write is harmless.
    try {
      await _repo.upsert(status: PresenceStatus.offline);
    } catch (_) {
      // best effort
    }
    state = state.copyWith(isStreaming: false);
  }

  // ── iOS main-isolate stream ──────────────────────────────────────────

  Future<void> _startMainIsolateStream() async {
    try {
      final Position first = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 8),
        ),
      );
      await _publish(first);
    } catch (_) {
      // No fix yet — the stream will deliver one.
    }

    await _positionSub?.cancel();
    _positionSub =
        Geolocator.getPositionStream(
          locationSettings: AppleSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 10,
            allowBackgroundLocationUpdates: true,
            showBackgroundLocationIndicator: true,
            pauseLocationUpdatesAutomatically: false,
            activityType: ActivityType.automotiveNavigation,
          ),
        ).listen(
          _publish,
          onError: (Object e) => state = state.copyWith(error: e.toString()),
        );

    _heartbeat?.cancel();
    _heartbeat = Timer.periodic(const Duration(seconds: 30), (_) async {
      if (state.lastLat == null) return;
      try {
        await _repo.upsert(
          status: PresenceStatus.online,
          lat: state.lastLat,
          lng: state.lastLng,
          accuracyM: state.lastAccuracyM,
          vehicleId: _vehicleId,
        );
      } catch (_) {
        // best effort — next tick retries.
      }
    });
  }

  Future<void> _publish(Position p) async {
    state = state.copyWith(
      lastLat: p.latitude,
      lastLng: p.longitude,
      lastAccuracyM: p.accuracy.round(),
      lastUpdatedAt: DateTime.now(),
      clearError: true,
    );
    try {
      await _repo.upsert(
        status: PresenceStatus.online,
        lat: p.latitude,
        lng: p.longitude,
        accuracyM: p.accuracy.round(),
        headingDeg: p.heading.round(),
        speedKph: (p.speed * 3.6).round(),
        vehicleId: _vehicleId,
      );
    } catch (_) {
      // Network blip — next tick retries.
    }
  }

  // ── Android FGS fixes → UI ───────────────────────────────────────────

  /// Best-effort instant position at go-online so the marketplace feed
  /// positions right away, instead of waiting for the first FGS fix to
  /// round-trip from the isolate (which, while stationary, may be the only
  /// position message and can lose a startup race). Harmless if null.
  Future<void> _seedLastKnownFix() async {
    if (state.lastLat != null) return;
    try {
      final Position? last = await Geolocator.getLastKnownPosition();
      if (last == null || !mounted || state.lastLat != null) return;
      _onBgFix(
        BgFix(
          lat: last.latitude,
          lng: last.longitude,
          accuracyM: last.accuracy.round(),
          at: DateTime.now(),
        ),
      );
    } catch (_) {
      // best effort
    }
  }

  void _onBgFix(BgFix fix) {
    state = state.copyWith(
      lastLat: fix.lat,
      lastLng: fix.lng,
      lastAccuracyM: fix.accuracyM,
      lastUpdatedAt: fix.at,
      clearError: true,
    );
  }

  // ── Session plumbing ─────────────────────────────────────────────────

  BgSession? _buildSession() {
    final sb.Session? s = _supabase.auth.currentSession;
    final String? access = s?.accessToken;
    final String? refresh = s?.refreshToken;
    if (s == null ||
        access == null ||
        access.isEmpty ||
        refresh == null ||
        refresh.isEmpty) {
      return null;
    }
    return BgSession(
      supabaseUrl: Env.supabaseUrl,
      anonKey: Env.supabaseAnonKey,
      accessToken: access,
      refreshToken: refresh,
      expiresAtEpoch: s.expiresAt ?? 0,
      vehicleId: _vehicleId,
    );
  }

  /// When the main SDK rotates the session (token refresh), forward the
  /// fresh credentials to the background worker so it never falls back to
  /// a stale token over a long shift.
  void _listenForTokenRotation() {
    _authSub?.cancel();
    _authSub = _supabase.auth.onAuthStateChange.listen((sb.AuthState ev) {
      if (ev.event != sb.AuthChangeEvent.tokenRefreshed) {
        return;
      }
      final BgSession? session = _buildSession();
      if (session != null) {
        unawaited(_bg.updateSession(session));
      }
    });
  }

  Future<void> _setIntendedOnline(bool value) async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_intendedOnlineKey, value);
    } catch (_) {
      // Non-fatal: worst case the online state isn't restored on reopen.
    }
  }

  Future<void> _bestEffortHardening() async {
    try {
      // "Always" upgrade — advisory; see LocationPermissionService.
      await Geolocator.requestPermission();
    } catch (_) {
      // advisory only
    }
    try {
      final NotificationPermission np =
          await FlutterForegroundTask.checkNotificationPermission();
      if (np != NotificationPermission.granted) {
        await FlutterForegroundTask.requestNotificationPermission();
      }
    } catch (_) {
      // advisory only
    }
    if (Platform.isAndroid) {
      try {
        if (!await FlutterForegroundTask.isIgnoringBatteryOptimizations) {
          await FlutterForegroundTask.requestIgnoreBatteryOptimization();
        }
      } catch (_) {
        // advisory only
      }
    }
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _positionSub?.cancel();
    _bgFixSub?.cancel();
    _heartbeat?.cancel();
    _bg.dispose();
    super.dispose();
  }
}

final StateNotifierProvider<PresenceController, PresenceState>
presenceControllerProvider =
    StateNotifierProvider<PresenceController, PresenceState>(
      (Ref _) => PresenceController(
        locator<PresenceRepository>(),
        locator<SupabaseModule>(),
      ),
    );
