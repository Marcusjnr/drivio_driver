import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

import 'package:drivio_driver/modules/commons/location/presence_background.dart';

/// The auth + endpoint bundle the background workers need to talk to
/// Supabase without the SDK. Built on the main isolate from the live
/// session and handed to the Android foreground task (via the data
/// store) and the iOS native shim (via a method channel).
@immutable
class BgSession {
  const BgSession({
    required this.supabaseUrl,
    required this.anonKey,
    required this.accessToken,
    required this.refreshToken,
    required this.expiresAtEpoch,
    this.vehicleId,
  });

  final String supabaseUrl;
  final String anonKey;
  final String accessToken;
  final String refreshToken;
  final int expiresAtEpoch;
  final String? vehicleId;
}

/// A position fix surfaced from a background worker back to the UI.
@immutable
class BgFix {
  const BgFix({
    required this.lat,
    required this.lng,
    required this.accuracyM,
    required this.at,
  });

  final double lat;
  final double lng;
  final int accuracyM;
  final DateTime at;
}

/// Owns the OS-level background-location plumbing and keeps the platform
/// differences out of [PresenceController]:
///
/// * **Android** — a `flutter_foreground_task` location foreground
///   service hosting the [PresenceTaskHandler] isolate. Survives the app
///   being backgrounded or swiped away, and (with autoRunOnBoot) resumes
///   after a reboot.
/// * **iOS** — a native significant-location-change shim
///   ([SignificantLocationManager]) that relaunches the app and keeps
///   presence fresh after a force-quit. Continuous foreground/background
///   streaming on iOS stays with the geolocator stream in
///   [PresenceController] (kept alive by the `location` background mode).
class BackgroundLocationService {
  BackgroundLocationService();

  static const MethodChannel _iosChannel = MethodChannel('drivio/bg_presence');

  final StreamController<BgFix> _fixes = StreamController<BgFix>.broadcast();

  /// Position fixes emitted by the Android foreground-task isolate, so
  /// the map/UI can reflect movement while backgrounded. Empty on iOS
  /// (the main-isolate stream feeds the UI there directly).
  Stream<BgFix> get fixes => _fixes.stream;

  bool _initialised = false;

  /// Start OS-level background tracking. Returns true if the platform
  /// mechanism started (or there was nothing to start, e.g. desktop).
  Future<bool> start(BgSession session) async {
    if (Platform.isAndroid) {
      return _startAndroid(session);
    }
    if (Platform.isIOS) {
      return _startIos(session);
    }
    return true;
  }

  Future<void> stop() async {
    if (Platform.isAndroid) {
      await _stopAndroid();
    } else if (Platform.isIOS) {
      await _stopIos();
    }
  }

  /// Whether the Android foreground service is currently running. The
  /// service outlives the UI process, so on a cold reopen this is how we
  /// detect "tracking is still live" and re-attach instead of restarting.
  /// Always false on iOS (no persistent service to query).
  Future<bool> get isRunning async {
    if (!Platform.isAndroid) {
      return false;
    }
    return FlutterForegroundTask.isRunningService;
  }

  /// Re-wire a fresh UI process to an already-running service: re-init the
  /// plugin + communication port and re-register the data callback so the
  /// map/UI receives fixes again. Does NOT restart the service.
  void reattach() {
    if (!Platform.isAndroid) {
      return;
    }
    _ensureInit();
    FlutterForegroundTask.addTaskDataCallback(_onAndroidTaskData);
  }

  /// Push a rotated session into the running background worker after the
  /// main-isolate SDK refreshes its token, so the worker never falls back
  /// to a stale credential.
  Future<void> updateSession(BgSession session) async {
    if (Platform.isAndroid) {
      await _persistAndroidSession(session);
      if (await FlutterForegroundTask.isRunningService) {
        FlutterForegroundTask.sendDataToTask(<String, Object?>{
          BgPresenceMsg.type: BgPresenceMsg.session,
          'access_token': session.accessToken,
          'refresh_token': session.refreshToken,
          'expires_at': session.expiresAtEpoch,
        });
      }
    } else if (Platform.isIOS) {
      await _invokeIos('updateSession', session);
    }
  }

  // ── Android ──────────────────────────────────────────────────────────

  void _ensureInit() {
    if (_initialised) {
      return;
    }
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'drivio_presence',
        channelName: 'Online status',
        channelDescription:
            'Keeps you discoverable to riders while you are online.',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
        onlyAlertOnce: true,
      ),
      iosNotificationOptions: const IOSNotificationOptions(),
      foregroundTaskOptions: ForegroundTaskOptions(
        // 30s heartbeat — matches the existing presence cadence and keeps
        // a parked driver from ageing out.
        eventAction: ForegroundTaskEventAction.repeat(30000),
        autoRunOnBoot: true,
        autoRunOnMyPackageReplaced: true,
        allowWakeLock: true,
        allowWifiLock: true,
      ),
    );
    FlutterForegroundTask.initCommunicationPort();
    _initialised = true;
  }

  Future<bool> _startAndroid(BgSession session) async {
    _ensureInit();
    await _persistAndroidSession(session);

    FlutterForegroundTask.addTaskDataCallback(_onAndroidTaskData);

    final ServiceRequestResult result;
    if (await FlutterForegroundTask.isRunningService) {
      result = await FlutterForegroundTask.restartService();
    } else {
      result = await FlutterForegroundTask.startService(
        serviceId: 4036,
        notificationTitle: "You're online",
        notificationText: 'Drivio is keeping you visible to nearby riders.',
        callback: startPresenceForegroundTask,
      );
    }
    return result is ServiceRequestSuccess;
  }

  Future<void> _stopAndroid() async {
    FlutterForegroundTask.removeTaskDataCallback(_onAndroidTaskData);
    if (await FlutterForegroundTask.isRunningService) {
      await FlutterForegroundTask.stopService();
    }
    await _clearAndroidSession();
  }

  Future<void> _persistAndroidSession(BgSession s) async {
    await FlutterForegroundTask.saveData(
      key: BgPresenceKeys.supabaseUrl,
      value: s.supabaseUrl,
    );
    await FlutterForegroundTask.saveData(
      key: BgPresenceKeys.anonKey,
      value: s.anonKey,
    );
    await FlutterForegroundTask.saveData(
      key: BgPresenceKeys.accessToken,
      value: s.accessToken,
    );
    await FlutterForegroundTask.saveData(
      key: BgPresenceKeys.refreshToken,
      value: s.refreshToken,
    );
    await FlutterForegroundTask.saveData(
      key: BgPresenceKeys.expiresAt,
      value: s.expiresAtEpoch,
    );
    await FlutterForegroundTask.saveData(
      key: BgPresenceKeys.vehicleId,
      value: s.vehicleId ?? '',
    );
  }

  Future<void> _clearAndroidSession() async {
    await FlutterForegroundTask.removeData(key: BgPresenceKeys.accessToken);
    await FlutterForegroundTask.removeData(key: BgPresenceKeys.refreshToken);
    await FlutterForegroundTask.removeData(key: BgPresenceKeys.expiresAt);
    await FlutterForegroundTask.removeData(key: BgPresenceKeys.vehicleId);
  }

  void _onAndroidTaskData(Object data) {
    if (data is! Map) {
      return;
    }
    if (data[BgPresenceMsg.type] != BgPresenceMsg.position) {
      return;
    }
    final num? lat = data[BgPresenceMsg.lat] as num?;
    final num? lng = data[BgPresenceMsg.lng] as num?;
    if (lat == null || lng == null) {
      return;
    }
    _fixes.add(
      BgFix(
        lat: lat.toDouble(),
        lng: lng.toDouble(),
        accuracyM: (data[BgPresenceMsg.accuracyM] as num?)?.toInt() ?? 0,
        at: DateTime.fromMillisecondsSinceEpoch(
          (data[BgPresenceMsg.at] as num?)?.toInt() ??
              DateTime.now().millisecondsSinceEpoch,
        ),
      ),
    );
  }

  // ── iOS ──────────────────────────────────────────────────────────────

  Future<bool> _startIos(BgSession session) async {
    final bool? ok = await _invokeIos('start', session);
    return ok ?? false;
  }

  Future<void> _stopIos() async {
    try {
      await _iosChannel.invokeMethod<void>('stop');
    } on PlatformException catch (e) {
      if (kDebugMode) {
        debugPrint('bg-presence iOS stop failed: ${e.message}');
      }
    }
  }

  Future<bool?> _invokeIos(String method, BgSession s) async {
    try {
      return await _iosChannel.invokeMethod<bool>(method, <String, Object?>{
        'supabaseUrl': s.supabaseUrl,
        'anonKey': s.anonKey,
        'accessToken': s.accessToken,
        'refreshToken': s.refreshToken,
        'expiresAt': s.expiresAtEpoch,
        'vehicleId': s.vehicleId,
      });
    } on PlatformException catch (e) {
      if (kDebugMode) {
        debugPrint('bg-presence iOS $method failed: ${e.message}');
      }
      return false;
    }
  }

  void dispose() {
    _fixes.close();
  }
}
