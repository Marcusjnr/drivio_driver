import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

/// Background driver-presence tracking that runs inside the Android
/// foreground service isolate.
///
/// This file is loaded into a **separate Dart isolate** by
/// flutter_foreground_task, so it cannot touch Riverpod, get_it, dotenv
/// or the supabase_flutter SDK (none of which are initialised there). It
/// is deliberately self-contained: it carries the Supabase URL, anon key
/// and the driver's auth tokens (handed in via the foreground-task data
/// store) and talks to PostgREST / GoTrue directly over HTTP.
///
/// Contract with the server: `upsert_driver_presence` is SECURITY DEFINER
/// and writes `driver_id = auth.uid()`, so every call MUST carry the
/// driver's JWT as a bearer token plus the anon key as `apikey`.

/// Data-store keys shared between the main isolate (writer) and the task
/// isolate (reader). Kept in one place so the two sides never drift.
class BgPresenceKeys {
  BgPresenceKeys._();

  static const String supabaseUrl = 'bg_presence_supabase_url';
  static const String anonKey = 'bg_presence_anon_key';
  static const String accessToken = 'bg_presence_access_token';
  static const String refreshToken = 'bg_presence_refresh_token';
  static const String expiresAt = 'bg_presence_expires_at'; // epoch seconds
  static const String vehicleId = 'bg_presence_vehicle_id'; // '' when none
}

/// Message keys for [FlutterForegroundTask.sendDataToMain] payloads.
class BgPresenceMsg {
  BgPresenceMsg._();

  static const String type = 'type';
  static const String position = 'position';
  static const String session = 'session';
  static const String error = 'error';

  static const String lat = 'lat';
  static const String lng = 'lng';
  static const String accuracyM = 'accuracy_m';
  static const String at = 'at';
}

/// The foreground-service entry point. flutter_foreground_task invokes
/// this top-level function in the task isolate; it must be annotated so
/// tree-shaking keeps it.
@pragma('vm:entry-point')
void startPresenceForegroundTask() {
  FlutterForegroundTask.setTaskHandler(PresenceTaskHandler());
}

/// Streams location while the driver is online and pushes each fix to
/// `upsert_driver_presence`. A 30s heartbeat (via [onRepeatEvent]) keeps
/// presence fresh when the driver is parked.
class PresenceTaskHandler extends TaskHandler {
  StreamSubscription<Position>? _positionSub;
  _PresenceUploader? _uploader;
  String? _vehicleId;

  double? _lastLat;
  double? _lastLng;
  int? _lastAccuracyM;

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    final _PresenceUploader? uploader = await _loadUploader();
    if (uploader == null) {
      FlutterForegroundTask.sendDataToMain(<String, Object?>{
        BgPresenceMsg.type: BgPresenceMsg.error,
        BgPresenceMsg.error: 'missing_session',
      });
      return;
    }
    _uploader = uploader;

    // Best-effort immediate fix so the server sees the driver right away,
    // rather than waiting for the first stream emission.
    try {
      final Position first = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 8),
        ),
      );
      await _onPosition(first);
    } catch (_) {
      // No fix yet — the stream will deliver one.
    }

    await _positionSub?.cancel();
    _positionSub =
        Geolocator.getPositionStream(
          locationSettings: _streamSettings(),
        ).listen(
          _onPosition,
          onError: (Object e) {
            FlutterForegroundTask.sendDataToMain(<String, Object?>{
              BgPresenceMsg.type: BgPresenceMsg.error,
              BgPresenceMsg.error: e.toString(),
            });
          },
        );
  }

  /// 30s heartbeat, even when stationary (the stream is silent when the
  /// driver hasn't moved [distanceFilter] metres).
  @override
  void onRepeatEvent(DateTime timestamp) {
    final _PresenceUploader? uploader = _uploader;
    if (uploader == null || _lastLat == null) {
      return;
    }
    // Re-push the last known fix to the main isolate every tick. The
    // position stream is silent while the driver is stationary (distance
    // filter), so without this the UI's PresenceState.lastLat would only
    // ever be set by the single onStart fix — and if that one message is
    // missed (startup race) the marketplace feed never positions and the
    // driver sees no requests. Repeating it makes foreground positioning
    // self-healing.
    FlutterForegroundTask.sendDataToMain(<String, Object?>{
      BgPresenceMsg.type: BgPresenceMsg.position,
      BgPresenceMsg.lat: _lastLat,
      BgPresenceMsg.lng: _lastLng,
      BgPresenceMsg.accuracyM: _lastAccuracyM ?? 0,
      BgPresenceMsg.at: DateTime.now().millisecondsSinceEpoch,
    });
    // Fire-and-forget: onRepeatEvent is synchronous. A dropped tick is
    // harmless; the next one (30s) retries.
    unawaited(
      uploader.upsert(
        status: 'online',
        lat: _lastLat,
        lng: _lastLng,
        accuracyM: _lastAccuracyM,
        vehicleId: _vehicleId,
      ),
    );
  }

  @override
  Future<void> onDestroy(DateTime timestamp) async {
    await _positionSub?.cancel();
    _positionSub = null;
    // Best-effort offline marker. If the process is being torn down hard
    // this may not land; the server also ages out stale presence rows.
    try {
      await _uploader?.upsert(status: 'offline');
    } catch (_) {
      // ignore
    }
  }

  /// The main isolate can push a rotated session (after its own SDK
  /// refresh) so the task always has a live token.
  @override
  void onReceiveData(Object data) {
    if (data is! Map) {
      return;
    }
    final Object? type = data[BgPresenceMsg.type];
    if (type == BgPresenceMsg.session) {
      _uploader?.adoptSession(
        accessToken: data['access_token'] as String?,
        refreshToken: data['refresh_token'] as String?,
        expiresAt: (data['expires_at'] as num?)?.toInt(),
      );
    }
  }

  Future<void> _onPosition(Position p) async {
    _lastLat = p.latitude;
    _lastLng = p.longitude;
    _lastAccuracyM = p.accuracy.round();

    FlutterForegroundTask.sendDataToMain(<String, Object?>{
      BgPresenceMsg.type: BgPresenceMsg.position,
      BgPresenceMsg.lat: p.latitude,
      BgPresenceMsg.lng: p.longitude,
      BgPresenceMsg.accuracyM: p.accuracy.round(),
      BgPresenceMsg.at: DateTime.now().millisecondsSinceEpoch,
    });

    await _uploader?.upsert(
      status: 'online',
      lat: p.latitude,
      lng: p.longitude,
      accuracyM: p.accuracy.round(),
      headingDeg: p.heading.round(),
      speedKph: (p.speed * 3.6).round(),
      vehicleId: _vehicleId,
    );
  }

  /// High accuracy is required for ride matching, but a 10m distance
  /// filter + 5s interval floor keeps GPS sampling battery-reasonable:
  /// no emissions while parked, capped frequency while moving.
  LocationSettings _streamSettings() {
    if (defaultTargetPlatform == TargetPlatform.android) {
      return AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
        intervalDuration: const Duration(seconds: 5),
      );
    }
    return const LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10,
    );
  }

  Future<_PresenceUploader?> _loadUploader() async {
    final String? url = await FlutterForegroundTask.getData<String>(
      key: BgPresenceKeys.supabaseUrl,
    );
    final String? anon = await FlutterForegroundTask.getData<String>(
      key: BgPresenceKeys.anonKey,
    );
    final String? access = await FlutterForegroundTask.getData<String>(
      key: BgPresenceKeys.accessToken,
    );
    final String? refresh = await FlutterForegroundTask.getData<String>(
      key: BgPresenceKeys.refreshToken,
    );
    final int? expiresAt = await FlutterForegroundTask.getData<int>(
      key: BgPresenceKeys.expiresAt,
    );
    final String? vehicle = await FlutterForegroundTask.getData<String>(
      key: BgPresenceKeys.vehicleId,
    );
    _vehicleId = (vehicle == null || vehicle.isEmpty) ? null : vehicle;

    if (url == null ||
        url.isEmpty ||
        anon == null ||
        anon.isEmpty ||
        access == null ||
        access.isEmpty ||
        refresh == null ||
        refresh.isEmpty) {
      return null;
    }
    return _PresenceUploader(
      baseUrl: url,
      anonKey: anon,
      accessToken: access,
      refreshToken: refresh,
      expiresAtEpoch: expiresAt ?? 0,
    );
  }
}

/// Thin PostgREST/GoTrue client for the task isolate. Owns the live
/// access token, refreshes it before expiry (or on a 401), and persists
/// any rotated tokens back to the data store so a service restart picks
/// up the latest credentials rather than a stale one.
class _PresenceUploader {
  _PresenceUploader({
    required this.baseUrl,
    required this.anonKey,
    required String accessToken,
    required String refreshToken,
    required int expiresAtEpoch,
  }) : _accessToken = accessToken,
       _refreshToken = refreshToken,
       _expiresAtEpoch = expiresAtEpoch;

  final String baseUrl;
  final String anonKey;

  String _accessToken;
  String _refreshToken;
  int _expiresAtEpoch;

  bool _refreshing = false;

  Uri get _rpcUri => Uri.parse('$baseUrl/rest/v1/rpc/upsert_driver_presence');
  Uri get _refreshUri =>
      Uri.parse('$baseUrl/auth/v1/token?grant_type=refresh_token');

  Future<void> upsert({
    required String status,
    double? lat,
    double? lng,
    int? accuracyM,
    int? headingDeg,
    int? speedKph,
    String? vehicleId,
  }) async {
    await _ensureFreshToken();

    final Map<String, Object?> body = <String, Object?>{
      'p_status': status,
      'p_lat': lat,
      'p_lng': lng,
      'p_accuracy_m': accuracyM,
      'p_heading_deg': headingDeg,
      'p_speed_kph': speedKph,
      'p_vehicle_id': vehicleId,
    };

    http.Response res;
    try {
      res = await _postRpc(body);
    } catch (e) {
      // Network blip — the next position or heartbeat retries.
      if (kDebugMode) {
        debugPrint('bg-presence upsert network error: $e');
      }
      return;
    }

    // A 401 means the access token died between our expiry check and the
    // call (clock skew, early server-side revocation). Refresh once and
    // retry the single call.
    if (res.statusCode == 401) {
      final bool ok = await _refresh();
      if (ok) {
        try {
          res = await _postRpc(body);
        } catch (_) {
          return;
        }
      }
    }

    if (res.statusCode >= 400 && kDebugMode) {
      debugPrint('bg-presence upsert HTTP ${res.statusCode}: ${res.body}');
    }
  }

  Future<http.Response> _postRpc(Map<String, Object?> body) {
    return http
        .post(
          _rpcUri,
          headers: <String, String>{
            'apikey': anonKey,
            'Authorization': 'Bearer $_accessToken',
            'Content-Type': 'application/json',
          },
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 12));
  }

  void adoptSession({
    String? accessToken,
    String? refreshToken,
    int? expiresAt,
  }) {
    if (accessToken != null && accessToken.isNotEmpty) {
      _accessToken = accessToken;
    }
    if (refreshToken != null && refreshToken.isNotEmpty) {
      _refreshToken = refreshToken;
    }
    if (expiresAt != null && expiresAt > 0) {
      _expiresAtEpoch = expiresAt;
    }
  }

  Future<void> _ensureFreshToken() async {
    final int now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    // Refresh proactively 60s before expiry so an in-flight upsert never
    // races the boundary.
    if (_expiresAtEpoch == 0 || now < _expiresAtEpoch - 60) {
      return;
    }
    await _refresh();
  }

  /// Exchanges the refresh token for a new session via GoTrue. Supabase
  /// rotates refresh tokens, so we persist the new pair immediately. A
  /// brief double-refresh race with the main isolate is tolerated by
  /// GoTrue's reuse-interval window.
  Future<bool> _refresh() async {
    if (_refreshing) {
      return false;
    }
    _refreshing = true;
    try {
      final http.Response res = await http
          .post(
            _refreshUri,
            headers: <String, String>{
              'apikey': anonKey,
              'Content-Type': 'application/json',
            },
            body: jsonEncode(<String, String>{'refresh_token': _refreshToken}),
          )
          .timeout(const Duration(seconds: 12));
      if (res.statusCode != 200) {
        if (kDebugMode) {
          debugPrint('bg-presence refresh HTTP ${res.statusCode}');
        }
        return false;
      }
      final Map<String, dynamic> json =
          jsonDecode(res.body) as Map<String, dynamic>;
      final String? access = json['access_token'] as String?;
      final String? refresh = json['refresh_token'] as String?;
      final int? expiresAt = (json['expires_at'] as num?)?.toInt();
      if (access == null || refresh == null) {
        return false;
      }
      _accessToken = access;
      _refreshToken = refresh;
      _expiresAtEpoch =
          expiresAt ??
          (DateTime.now().millisecondsSinceEpoch ~/ 1000) +
              ((json['expires_in'] as num?)?.toInt() ?? 3600);

      // Persist so a service restart (kill/boot) resumes with live creds.
      await FlutterForegroundTask.saveData(
        key: BgPresenceKeys.accessToken,
        value: _accessToken,
      );
      await FlutterForegroundTask.saveData(
        key: BgPresenceKeys.refreshToken,
        value: _refreshToken,
      );
      await FlutterForegroundTask.saveData(
        key: BgPresenceKeys.expiresAt,
        value: _expiresAtEpoch,
      );

      // Tell the main isolate so its SDK session and ours stay aligned.
      FlutterForegroundTask.sendDataToMain(<String, Object?>{
        BgPresenceMsg.type: BgPresenceMsg.session,
        'access_token': _accessToken,
        'refresh_token': _refreshToken,
        'expires_at': _expiresAtEpoch,
      });
      return true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('bg-presence refresh error: $e');
      }
      return false;
    } finally {
      _refreshing = false;
    }
  }
}
