import 'dart:async';
import 'dart:isolate';
import 'dart:ui' show IsolateNameServer;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'package:drivio_driver/modules/commons/logging/app_logger.dart';
import 'package:drivio_driver/modules/commons/overlay/ride_request_overlay.dart';

/// New-trip alert for an online driver whose app is NOT in the foreground.
///
/// Delivery: the server fans out an FCM DATA message (`type=ride_request`)
/// to nearby online drivers when a request is broadcast. The background FCM
/// handler ([callPushBackgroundHandler]) routes it here, which:
///   * plays a looping alert sound (audioplayers) — the driver is online, so
///     the presence foreground service keeps this Dart process alive and
///     able to play audio in the background;
///   * posts a full-screen, high-importance heads-up notification;
///   * (Android) the overlay bubble is shown separately (see the overlay
///     module) — this file owns sound + notification only.
///
/// In the FOREGROUND the live marketplace feed already surfaces the request
/// in-app, so the notification + overlay layers are skipped — but the same
/// looping sound rings via [startForegroundRideAlert] until the driver taps
/// the request. Either alert stops on [stopRideRequestAlert] — called when
/// the driver opens/acts on the request (feed tap, app resume) or after
/// [_kMaxAlertWindow].

const String _kChannelId = 'drivio_ride_request';
const String _kChannelName = 'New trip requests';
const int _kNotificationId = 5071;
const Duration _kMaxAlertWindow = Duration(seconds: 60);

/// Drop the generated file at `assets/audio/ride_request.mp3` (that dir is
/// already registered in pubspec, alongside the call ringtones). Anything
/// audioplayers can decode (mp3/wav/ogg) works — update the extension here
/// if you use .wav.
const String _kAlertAsset = 'audio/ride_request.mp3';

final FlutterLocalNotificationsPlugin _notifs =
    FlutterLocalNotificationsPlugin();
AudioPlayer? _player;
Timer? _autoStop;
bool _initialised = false;

/// Cross-isolate kill switch. The alert rings inside the background FCM
/// isolate (its own engine), so the main isolate can't reach [_player]
/// directly — when the driver opens the app, the main-isolate
/// [stopRideRequestAlert] pings this named port and the ringing isolate
/// silences itself.
const String _kStopPortName = 'drivio_ride_alert_stop';
ReceivePort? _stopPort;

void _registerStopPort() {
  _stopPort?.close();
  IsolateNameServer.removePortNameMapping(_kStopPortName);
  final ReceivePort port = ReceivePort();
  IsolateNameServer.registerPortWithName(port.sendPort, _kStopPortName);
  port.listen((dynamic _) => unawaited(_stopLocal()));
  _stopPort = port;
}

Future<void> _ensureInitialised() async {
  if (_initialised) return;
  const InitializationSettings settings = InitializationSettings(
    android: AndroidInitializationSettings('@drawable/ic_notification'),
    iOS: DarwinInitializationSettings(),
  );
  await _notifs.initialize(settings);
  _initialised = true;
}

/// Start ringing + show the heads-up notification for a new request.
/// Idempotent for a given request id — a duplicate push won't stack rings.
Future<void> startRideRequestAlert(Map<String, dynamic> data) async {
  // Two delivery paths can race for the same request (FCM push and the
  // foreground-service poll fallback, which run in different isolates).
  // If another isolate is already ringing, don't stack a second alert.
  if (_stopPort == null &&
      IsolateNameServer.lookupPortByName(_kStopPortName) != null) {
    return;
  }
  await _ensureInitialised();
  // This isolate owns the ring — expose the kill switch so the main
  // isolate can silence it the moment the driver opens the app.
  _registerStopPort();

  final String pickup = (data['pickup'] as String?) ?? 'Nearby pickup';
  final String dropoff = (data['dropoff'] as String?) ?? 'Destination';
  final String? distance = data['distance_km'] as String?;
  final String body = distance != null
      ? '$pickup → $dropoff · $distance km'
      : '$pickup → $dropoff';

  await _notifs.show(
    _kNotificationId,
    'New trip request',
    body,
    NotificationDetails(
      android: AndroidNotificationDetails(
        _kChannelId,
        _kChannelName,
        channelDescription: 'A rider near you is requesting a trip',
        importance: Importance.max,
        priority: Priority.max,
        category: AndroidNotificationCategory.call,
        // Full-screen intent surfaces it even over the lock screen / other
        // apps — the alarm-style prominence a driver needs.
        fullScreenIntent: true,
        ongoing: true,
        autoCancel: false,
        color: const Color(0xFFEE6F4A),
        // Sound is driven by the looping player below, so the channel
        // itself stays silent to avoid a double hit.
        playSound: false,
        enableVibration: true,
        actions: <AndroidNotificationAction>[
          AndroidNotificationAction(
            'open_request',
            'View trip',
            showsUserInterface: true,
          ),
        ],
      ),
      iOS: const DarwinNotificationDetails(
        interruptionLevel: InterruptionLevel.timeSensitive,
        // iOS can't loop audio for a notification; it uses the bundled
        // sound file once. (No overlay on iOS.)
        sound: 'ride_request.caf',
      ),
    ),
    payload: data['ride_request_id'] as String?,
  );

  await _startLoopingSound();

  // Android bonus layer: the floating Drivio bubble over other apps
  // (no-op on iOS or without the overlay permission).
  await showRideRequestOverlay(data);

  // Safety net: never ring forever. The request window closes ~30–60s.
  _autoStop?.cancel();
  _autoStop = Timer(_kMaxAlertWindow, () => unawaited(stopRideRequestAlert()));
}

Future<void> _startLoopingSound() => _playAlertSound(loop: true);

String? _lastForegroundAlertRequestId;

/// The same looping alert for a request that arrives while the app is in
/// the FOREGROUND (FCM `onMessage`). The feed card is the visual layer
/// there, so no notification and no overlay — but the sound loops exactly
/// like the background ring and stops the moment the driver taps the
/// request (see `enterBidding` → [stopRideRequestAlert]), or after
/// [_kMaxAlertWindow] when the request window has closed anyway.
Future<void> startForegroundRideAlert(String? requestId) async {
  // Duplicate FCM delivery of a request the driver already acted on →
  // don't re-ring it.
  if (requestId != null && requestId == _lastForegroundAlertRequestId) {
    return;
  }
  _lastForegroundAlertRequestId = requestId;
  // A ring is already sounding (background-isolate race around the moment
  // the app comes to the front) — don't stack a second player.
  if (_stopPort == null &&
      IsolateNameServer.lookupPortByName(_kStopPortName) != null) {
    return;
  }
  // Own the ring: lets stopRideRequestAlert() (feed tap, lifecycle) kill
  // it through the same switch the background ring uses.
  _registerStopPort();
  await _playAlertSound(loop: true);
  _autoStop?.cancel();
  _autoStop = Timer(_kMaxAlertWindow, () => unawaited(stopRideRequestAlert()));
}

Future<void> _playAlertSound({required bool loop}) async {
  try {
    await _player?.stop();
    await _player?.dispose();
    final AudioPlayer p = AudioPlayer();
    await p.setReleaseMode(loop ? ReleaseMode.loop : ReleaseMode.release);
    await p.setAudioContext(
      AudioContext(
        android: const AudioContextAndroid(
          isSpeakerphoneOn: true,
          contentType: AndroidContentType.sonification,
          usageType: AndroidUsageType.notificationRingtone,
          audioFocus: AndroidAudioFocus.gainTransientMayDuck,
        ),
        iOS: AudioContextIOS(
          category: AVAudioSessionCategory.playback,
          options: const <AVAudioSessionOptions>{
            AVAudioSessionOptions.mixWithOthers,
          },
        ),
      ),
    );
    await p.play(AssetSource(_kAlertAsset));
    _player = p;
  } catch (e, st) {
    // The notification (with its own iOS sound) is the guaranteed layer;
    // looping audio is best-effort and can fail on locked-down OEMs.
    AppLogger.w('ride alert sound failed', error: e, stackTrace: st);
  }
}

/// Stop the ring + clear the notification. Safe to call when nothing is
/// active, and safe to call from ANY isolate: it tears down whatever this
/// isolate owns, then pings the ringing isolate's kill-switch port (the
/// looping player lives in the background FCM isolate — a direct stop from
/// the main isolate can't reach it).
Future<void> stopRideRequestAlert() async {
  await _stopLocal();
  final SendPort? ringer =
      IsolateNameServer.lookupPortByName(_kStopPortName);
  ringer?.send('stop');
}

/// In-isolate teardown only (also the kill-switch port's handler — must
/// never re-send, or the two isolates would ping-pong forever).
Future<void> _stopLocal() async {
  _autoStop?.cancel();
  _autoStop = null;
  // Retire the kill-switch port: "port registered" doubles as the
  // cross-isolate "a ring is in progress" signal, so it must not outlive
  // the ring.
  if (_stopPort != null) {
    IsolateNameServer.removePortNameMapping(_kStopPortName);
    _stopPort?.close();
    _stopPort = null;
  }
  try {
    await _player?.stop();
    await _player?.dispose();
  } catch (_) {
  } finally {
    _player = null;
  }
  try {
    await _ensureInitialised();
    await _notifs.cancel(_kNotificationId);
  } catch (_) {}
  await closeRideRequestOverlay();
}
