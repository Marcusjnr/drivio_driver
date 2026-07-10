import 'dart:async';
import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:drivio_driver/modules/commons/logging/app_logger.dart';
import 'package:drivio_driver/modules/commons/push/admin_push.dart';
import 'package:drivio_driver/modules/commons/supabase/supabase_module.dart';

/// Registers this device for push notifications: obtains the FCM token and
/// upserts it into `device_tokens` (keyed user+app+platform) whenever a
/// driver is signed in; removes it on sign-out. Phase B of the voice-call
/// project — the `call-notify` edge function reads these rows to ring the
/// callee's device in background/killed state.
class PushService {
  PushService(this._supabase);

  static const String _app = 'driver';

  final SupabaseModule _supabase;

  /// Build env ('staging' | 'prod', from the flavor). FCM tokens belong to
  /// one Firebase project, so call-notify needs to know which service
  /// account can reach this token.
  late String _env;

  StreamSubscription<AuthState>? _authSub;
  StreamSubscription<String>? _tokenSub;

  String get _platform => Platform.isIOS ? 'ios' : 'android';

  /// Call once at startup (after Firebase.initializeApp). Registers now if a
  /// session exists and keeps the token in sync across sign-in/out and FCM
  /// token rotation. Never throws — push is best-effort.
  Future<void> init({required String env}) async {
    _env = env;
    // Admin campaign pushes: local rendering of go-online prompts + the
    // session snapshot their notification action boots from.
    unawaited(initAdminPush(_supabase.client));
    _authSub = _supabase.auth.onAuthStateChange.listen((AuthState s) {
      if (s.event == AuthChangeEvent.signedIn) {
        unawaited(registerDevice());
      }
      // NOTE: sign-out cleanup can't run here — by the time `signedOut`
      // fires the JWT is gone and the RPC would be unauthenticated. The
      // sign-out flow calls [unregisterDevice] BEFORE auth.signOut().
    });

    _tokenSub = FirebaseMessaging.instance.onTokenRefresh.listen(
      (String token) => unawaited(_upsert(fcmToken: token)),
      onError: (Object _) {/* best effort */},
    );

    if (_supabase.auth.currentUser != null) {
      await registerDevice();
    }
  }

  /// Ask permission (iOS + Android 13 notification permission) and store the
  /// current FCM token. Safe to call repeatedly.
  Future<void> registerDevice() async {
    try {
      await FirebaseMessaging.instance.requestPermission();
      // On iOS the FCM token isn't available until APNs hands one out; a null
      // here is fine — onTokenRefresh delivers it when it arrives.
      final String? token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        await _upsert(fcmToken: token);
      }
    } catch (e) {
      AppLogger.w('Push registration failed', error: e);
    }
  }

  /// Store the iOS PushKit VoIP token (wired up with CallKit in Phase C).
  Future<void> saveVoipToken(String voipToken) =>
      _upsert(voipToken: voipToken);

  Future<void> _upsert({String? fcmToken, String? voipToken}) async {
    if (_supabase.auth.currentUser == null) {
      return;
    }
    try {
      await _supabase.client.rpc<void>(
        'upsert_device_token',
        params: <String, dynamic>{
          'p_app': _app,
          'p_platform': _platform,
          'p_env': _env,
          'p_fcm_token': fcmToken,
          'p_voip_token': voipToken,
        },
      );
    } catch (e) {
      AppLogger.w('Device token upsert failed', error: e);
    }
  }

  /// Remove this device's token row + local FCM token. Must be called
  /// BEFORE `auth.signOut()` (the RPC needs the still-valid JWT).
  Future<void> unregisterDevice() async {
    try {
      await _supabase.client.rpc<void>(
        'delete_my_device_token',
        params: <String, dynamic>{
          'p_app': _app,
          'p_platform': _platform,
          'p_env': _env,
        },
      );
      await FirebaseMessaging.instance.deleteToken();
    } catch (_) {/* best effort — token also dies with the FCM install */}
  }

  void dispose() {
    _authSub?.cancel();
    _tokenSub?.cancel();
  }
}
