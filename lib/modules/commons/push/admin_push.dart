import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:drivio_driver/modules/commons/config/env.dart';
import 'package:drivio_driver/modules/commons/location/background_location_service.dart';
import 'package:drivio_driver/modules/commons/logging/app_logger.dart';

/// Admin push campaigns (dashboard → drivers).
///
/// Two message shapes arrive from `send_driver_push`:
///  * `admin_message` — a normal FCM notification (title/body/banner image).
///    The system tray renders it; nothing to do here.
///  * `go_online_prompt` — DATA-ONLY. We render it locally so it can carry
///    the "Go online" action, which flips the driver online from the
///    notification itself: no app open needed. The action handler runs in
///    a background isolate and starts the presence foreground service from
///    a persisted session snapshot.
///
/// The snapshot (Supabase URL + keys + tokens) is re-persisted on every
/// token refresh, because GoTrue rotates refresh tokens: a stale copy
/// would be unusable. The presence service itself refreshes tokens once
/// running, so a recent snapshot is all it needs to boot.

const String _kChannelId = 'drivio_admin';
const String _kGoOnlineActionId = 'go_online';
const int _kGoOnlineNotificationId = 4037;

// Keep in sync with PresenceController._intendedOnlineKey — the resume
// reconciler reads this to keep the driver online across app restarts.
const String _kIntendedOnlineKey = 'presence_intended_online';

const String _kSnapUrl = 'go_online_snap_url';
const String _kSnapAnonKey = 'go_online_snap_anon';
const String _kSnapAccess = 'go_online_snap_access';
const String _kSnapRefresh = 'go_online_snap_refresh';
const String _kSnapExpires = 'go_online_snap_expires';

final FlutterLocalNotificationsPlugin _localNotifs =
    FlutterLocalNotificationsPlugin();

bool _initialised = false;

/// Idempotent plugin init — safe to call from the main isolate at startup
/// AND from the FCM background isolate right before showing.
Future<void> ensureAdminPushInitialised() async {
  if (_initialised) return;
  const InitializationSettings settings = InitializationSettings(
    android: AndroidInitializationSettings('@drawable/ic_notification'),
    iOS: DarwinInitializationSettings(),
  );
  await _localNotifs.initialize(
    settings,
    onDidReceiveBackgroundNotificationResponse: adminPushActionBackground,
  );
  _initialised = true;
}

/// Main-isolate wiring, called once from PushService.init:
///  * keeps the go-online session snapshot fresh on every token refresh
///  * renders go-online prompts that arrive while the app is foregrounded
Future<void> initAdminPush(SupabaseClient client) async {
  await ensureAdminPushInitialised();

  Future<void> persist(Session? session) async {
    if (session == null) return;
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kSnapUrl, Env.supabaseUrl);
      await prefs.setString(_kSnapAnonKey, Env.supabaseAnonKey);
      await prefs.setString(_kSnapAccess, session.accessToken);
      await prefs.setString(_kSnapRefresh, session.refreshToken ?? '');
      await prefs.setInt(_kSnapExpires, session.expiresAt ?? 0);
    } catch (e) {
      AppLogger.w('go-online snapshot persist failed', error: e);
    }
  }

  await persist(client.auth.currentSession);
  client.auth.onAuthStateChange.listen((AuthState change) {
    if (change.event == AuthChangeEvent.tokenRefreshed ||
        change.event == AuthChangeEvent.signedIn) {
      unawaited(persist(change.session));
    }
    if (change.event == AuthChangeEvent.signedOut) {
      unawaited(SharedPreferences.getInstance().then(
        (SharedPreferences p) => p.remove(_kSnapRefresh),
      ));
    }
  });

  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    if (message.data['type'] == 'go_online_prompt') {
      unawaited(showGoOnlinePrompt(message.data.cast<String, dynamic>()));
    }
  });
}

/// Renders the go-online prompt with its notification action. Used from
/// both the foreground listener above and the FCM background handler.
Future<void> showGoOnlinePrompt(Map<String, dynamic> data) async {
  await ensureAdminPushInitialised();
  final String title = (data['title'] as String?) ?? 'Riders are waiting';
  final String body =
      (data['body'] as String?) ?? 'Go online to start receiving requests.';
  await _localNotifs.show(
    _kGoOnlineNotificationId,
    title,
    body,
    const NotificationDetails(
      android: AndroidNotificationDetails(
        _kChannelId,
        'Drivio updates',
        channelDescription: 'Messages from the Drivio team',
        importance: Importance.high,
        priority: Priority.high,
        color: Color(0xFFEE6F4A),
        actions: <AndroidNotificationAction>[
          AndroidNotificationAction(
            _kGoOnlineActionId,
            'Go online',
            // The whole point: handled in the background, no app open.
            showsUserInterface: false,
          ),
          AndroidNotificationAction(
            'open_app',
            'Open app',
            showsUserInterface: true,
          ),
        ],
      ),
      iOS: DarwinNotificationDetails(),
    ),
  );
}

/// Background-isolate handler for notification actions. Flips the driver
/// online by starting the same presence foreground service the in-app
/// toggle uses, bootstrapped from the persisted session snapshot.
@pragma('vm:entry-point')
void adminPushActionBackground(NotificationResponse response) {
  if (response.actionId != _kGoOnlineActionId) return;
  unawaited(_goOnlineHeadless());
}

Future<void> _goOnlineHeadless() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String url = prefs.getString(_kSnapUrl) ?? '';
    final String anon = prefs.getString(_kSnapAnonKey) ?? '';
    final String access = prefs.getString(_kSnapAccess) ?? '';
    final String refresh = prefs.getString(_kSnapRefresh) ?? '';
    final int expires = prefs.getInt(_kSnapExpires) ?? 0;
    if (url.isEmpty || anon.isEmpty || refresh.isEmpty) {
      await _showFallback();
      return;
    }

    // Same flag the in-app toggle sets — the resume reconciler and the
    // service watchdog both treat the driver as intentionally online.
    await prefs.setBool(_kIntendedOnlineKey, true);

    final bool ok = await BackgroundLocationService().start(
      BgSession(
        supabaseUrl: url,
        anonKey: anon,
        accessToken: access,
        refreshToken: refresh,
        expiresAtEpoch: expires,
      ),
    );
    if (!ok) {
      await prefs.setBool(_kIntendedOnlineKey, false);
      await _showFallback();
    }
  } catch (e) {
    AppLogger.w('headless go-online failed', error: e);
    await _showFallback();
  }
}

/// Anything blocked the silent path (missing permission, stale session,
/// OEM restrictions): tell the driver to finish the job in the app.
Future<void> _showFallback() async {
  await ensureAdminPushInitialised();
  await _localNotifs.show(
    _kGoOnlineNotificationId,
    "Couldn't take you online",
    'Tap to open Drivio and go online from the app.',
    const NotificationDetails(
      android: AndroidNotificationDetails(
        _kChannelId,
        'Drivio updates',
        channelDescription: 'Messages from the Drivio team',
        importance: Importance.high,
        priority: Priority.high,
        color: Color(0xFFEE6F4A),
      ),
      iOS: DarwinNotificationDetails(),
    ),
  );
}
