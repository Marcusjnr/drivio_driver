import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_callkit_incoming/entities/entities.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';

import 'package:drivio_driver/modules/commons/data/call_repository.dart';
import 'package:drivio_driver/modules/commons/di/di.dart';
import 'package:drivio_driver/modules/commons/navigation/app_navigation.dart';
import 'package:drivio_driver/modules/commons/push/admin_push.dart';
import 'package:drivio_driver/modules/commons/supabase/supabase_module.dart';
import 'package:drivio_driver/modules/commons/navigation/app_routes.dart';
import 'package:drivio_driver/modules/commons/types/call.dart';
import 'package:drivio_driver/modules/trip/features/call/logic/call_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Background/killed-state ring path. A `call-notify` FCM DATA message with
/// `type=incoming_call` arrives → the native incoming-call UI shows
/// (full-screen intent on Android; CallKit once iOS VoIP is wired). Accepting
/// launches/resumes the app, which answers + joins via the call controller.
///
/// Foreground ringing does NOT go through here — the Realtime watcher on the
/// `calls` table drives the in-app incoming screen (no double ring: the
/// foreground `onMessage` for incoming_call is deliberately ignored).

/// Must be a top-level function: runs in a background isolate.
@pragma('vm:entry-point')
Future<void> callPushBackgroundHandler(RemoteMessage message) async {
  if (message.data['type'] == 'incoming_call') {
    await showNativeIncomingCall(message.data.cast<String, dynamic>());
  } else if (message.data['type'] == 'go_online_prompt') {
    // Admin campaign to offline drivers — rendered locally so it can
    // carry the "Go online" notification action.
    await showGoOnlinePrompt(message.data.cast<String, dynamic>());
  }
}

Future<void> showNativeIncomingCall(Map<String, dynamic> data) async {
  final CallKitParams params = CallKitParams(
    id: data['call_id'] as String?,
    nameCaller: (data['caller_name'] as String?) ?? 'Drivio',
    appName: 'Drivio Driver',
    avatar: data['caller_avatar'] as String?,
    handle: 'Drivio trip call',
    type: 0, // audio
    duration: 30000,
    textAccept: 'Accept',
    textDecline: 'Decline',
    extra: data,
    android: const AndroidParams(
      isCustomNotification: true,
      isShowLogo: false,
      ringtonePath: 'system_ringtone_default',
      backgroundColor: '#0A0D10',
      actionColor: '#2FA36B',
      incomingCallNotificationChannelName: 'Incoming calls',
      missedCallNotificationChannelName: 'Missed calls',
    ),
    ios: const IOSParams(
      handleType: 'generic',
      supportsVideo: false,
      supportsDTMF: false,
      audioSessionMode: 'voiceChat',
    ),
  );
  await FlutterCallkitIncoming.showCallkitIncoming(params);
}

/// Main-isolate side: reacts to accept/decline on the native call UI and
/// bridges into [ActiveCallController]. Started once from bootstrap.
class CallPushBridge {
  CallPushBridge(this._container);

  final ProviderContainer? _container;
  StreamSubscription<CallEvent?>? _sub;
  StreamSubscription<AuthState>? _authSub;
  ProviderSubscription<CallState>? _phaseSub;

  ActiveCallController? get _controller =>
      _container?.read(activeCallControllerProvider.notifier);

  Future<void> init() async {
    _sub = FlutterCallkitIncoming.onEvent.listen(_onEvent);

    // App-global foreground ring path: watch for calls aimed at me from
    // ANY screen (not just the trip page), and route to the incoming
    // screen when one starts ringing.
    final SupabaseModule supabase = locator<SupabaseModule>();
    void startWatch() {
      if (supabase.auth.currentUser != null) {
        _container?.read(activeCallControllerProvider.notifier)
            .startIncomingWatch();
      }
    }

    startWatch();
    _authSub = supabase.auth.onAuthStateChange.listen((AuthState s) {
      if (s.event == AuthChangeEvent.initialSession ||
          s.event == AuthChangeEvent.signedIn ||
          s.event == AuthChangeEvent.tokenRefreshed) {
        startWatch();
      }
    });

    FirebaseMessaging.onMessage.listen((RemoteMessage m) {
      if (m.data['type'] == 'incoming_call') {
        final Object? callId = m.data['call_id'];
        if (callId is String) {
          unawaited(_adoptRinging(callId));
        }
      }
    });

    // Tapping a tray notification (chat message) while backgrounded…
    FirebaseMessaging.onMessageOpenedApp.listen(_onNotificationOpened);
    // …or from the killed state (the tap launched the app).
    final RemoteMessage? initial =
        await FirebaseMessaging.instance.getInitialMessage();
    if (initial != null) {
      _onNotificationOpened(initial);
    }

    _phaseSub = _container?.listen<CallState>(
      activeCallControllerProvider,
      (CallState? prev, CallState next) {
        if (prev?.phase != CallPhase.incomingRinging &&
            next.phase == CallPhase.incomingRinging) {
          AppNavigation.push<void>(AppRoutes.incomingCall);
        }
      },
    );
    // App may have been launched BY an accept on the killed-state UI —
    // adopt any still-active native call.
    try {
      final dynamic active = await FlutterCallkitIncoming.activeCalls();
      if (active is List && active.isNotEmpty) {
        final Map<String, dynamic> first =
            (active.first as Map).cast<String, dynamic>();
        final Map<String, dynamic> extra =
            ((first['extra'] as Map?) ?? <String, dynamic>{})
                .cast<String, dynamic>();
        final String? callId = extra['call_id'] as String?;
        if (callId != null) {
          await _adoptAndAnswer(callId);
        }
      }
    } catch (_) {/* best effort */}
  }

  Future<void> _onEvent(CallEvent? event) async {
    if (event == null) return;
    final Map<String, dynamic> body =
        (event.body as Map? ?? <String, dynamic>{}).cast<String, dynamic>();
    final Map<String, dynamic> extra =
        ((body['extra'] as Map?) ?? <String, dynamic>{})
            .cast<String, dynamic>();
    final String? callId = extra['call_id'] as String?;
    if (callId == null) return;

    switch (event.event) {
      case Event.actionCallAccept:
        await _adoptAndAnswer(callId);
      case Event.actionCallDecline:
      case Event.actionCallTimeout:
        try {
          await locator<CallRepository>().declineCall(callId);
        } catch (_) {/* server sweep covers it */}
      default:
        break;
    }
  }

  /// Notification tap (background or killed launch) → deep-link. Chat pushes
  /// carry `type=chat_message` + `trip_id` and open that trip's chat.
  void _onNotificationOpened(RemoteMessage m) {
    if (m.data['type'] != 'chat_message') {
      return;
    }
    final Object? tripId = m.data['trip_id'];
    if (tripId is! String) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AppNavigation.push<void>(AppRoutes.chat, arguments: tripId);
    });
  }

  /// Foreground-push fallback: surface a ringing call without answering.
  Future<void> _adoptRinging(String callId) async {
    try {
      final Call? call = await locator<CallRepository>().getCall(callId);
      final ActiveCallController? c = _controller;
      if (call == null || c == null || call.status != CallStatus.ringing) {
        return;
      }
      await c.attachIncoming(call);
    } catch (_) {/* realtime path may still land it */}
  }

  Future<void> _adoptAndAnswer(String callId) async {
    try {
      final Call? call = await locator<CallRepository>().getCall(callId);
      if (call == null || call.status.isTerminal) {
        await FlutterCallkitIncoming.endCall(callId);
        return;
      }
      final ActiveCallController? c = _controller;
      if (c == null) return;
      await c.attachIncoming(call, autoAnswer: true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        AppNavigation.push<void>(AppRoutes.call);
      });
    } catch (_) {/* user can retry from the trip screen */}
  }

  void dispose() {
    _sub?.cancel();
    _authSub?.cancel();
    _phaseSub?.close();
  }
}
