import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_callkit_incoming/entities/entities.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';

import 'package:drivio_driver/modules/commons/data/call_repository.dart';
import 'package:drivio_driver/modules/commons/di/di.dart';
import 'package:drivio_driver/modules/commons/navigation/app_navigation.dart';
import 'package:drivio_driver/modules/commons/push/admin_push.dart';
import 'package:drivio_driver/modules/commons/push/ride_alert_push.dart';
import 'package:drivio_driver/modules/marketplace/features/feed/presentation/logic/controller/marketplace_controller.dart';
import 'package:drivio_driver/modules/commons/supabase/supabase_module.dart';
import 'package:drivio_driver/modules/commons/navigation/app_routes.dart';
import 'package:drivio_driver/modules/commons/types/call.dart';
import 'package:drivio_driver/modules/commons/types/document.dart';
import 'package:drivio_driver/modules/kyc/features/document_capture/presentation/ui/document_capture_page.dart';
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
  } else if (message.data['type'] == 'ride_request') {
    // A rider near this online driver broadcast a trip while the app is
    // backgrounded/killed — ring + heads-up notification (on
    // Android, wired separately).
    await startRideRequestAlert(message.data.cast<String, dynamic>());
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
      } else if (m.data['type'] == 'ride_request') {
        // App is in the foreground: the alert sound rings until the
        // driver interacts with the auto-presented bid sheet.
        unawaited(
          startForegroundRideAlert(m.data['ride_request_id'] as String?),
        );
        // Fast-present: hand the request id straight to the drive shell
        // so the bid sheet opens WITH the ring, hydrating in parallel —
        // not seconds later when the nearby-list refresh lands. The
        // push is geo-targeted server-side, so presenting it directly
        // is safe; the shell still applies its own guards.
        final Object? pushedId = m.data['ride_request_id'];
        if (pushedId is String && _container != null) {
          _container.read(pushedRequestIdProvider.notifier).state = pushedId;
        }
        // The feed refresh stays as queue bookkeeping (dismissals,
        // ordering, the poll safety net) and as the fallback present
        // path when the shell's guards defer the fast-present.
        final MarketplaceController? feed = _container?.read(
          marketplaceControllerProvider.notifier,
        );
        if (feed != null) {
          unawaited(feed.refresh());
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

  /// Notification tap (background or killed launch) → deep-link. Chat
  /// pushes carry `type=chat_message` + `trip_id` and open that trip's
  /// chat; document-rejection pushes carry `type=document_rejected` and
  /// open the fix screen for that exact document.
  void _onNotificationOpened(RemoteMessage m) {
    if (m.data['type'] == 'document_rejected') {
      _openRejectedDocument(m.data.cast<String, dynamic>());
      return;
    }
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

/// Deep-links a tapped "document rejected" push straight to the fix
/// screen for that exact document — the push already told the driver
/// which one, so there's no reason to route through the overview list
/// first. The push carries the SAME rejection reason shown in its own
/// notification body, plus the vehicle id for vehicle-related kinds
/// (see `_push_document_rejected` in the backend).
///
/// Only [rejectableDocumentKinds] are ever opened here — a malformed or
/// out-of-scope `document_kind` (the backend still labels pushes for
/// insurance/road-worthiness/LASRRA/inspection, none of which the app
/// collects any UI for) is dropped rather than resolved via
/// `DocumentKind.fromWire`'s built-in fallback, which would otherwise
/// silently open the vehicle-registration screen for an unrelated kind.
void _openRejectedDocument(Map<String, dynamic> data) {
  final Object? kindWire = data['document_kind'];
  if (kindWire is! String) {
    return;
  }
  DocumentKind? kind;
  for (final DocumentKind k in DocumentKind.values) {
    if (k.wire == kindWire) {
      kind = k;
      break;
    }
  }
  if (kind == null || !rejectableDocumentKinds.contains(kind)) {
    return;
  }
  final DocumentKind resolvedKind = kind;
  final Object? vehicleId = data['vehicle_id'];
  final Object? reason = data['rejection_reason'];
  final String? rejectionReason =
      reason is String && reason.trim().isNotEmpty ? reason : null;

  // Selfie has its own dedicated recapture flow (face liveness +
  // profile photo + the server-side liveness stamp) — routing it
  // through the generic document-capture screen would leave
  // `drivers.liveness_passed_at` unset even after a successful
  // re-upload, silently leaving the driver blocked from going online.
  if (resolvedKind == DocumentKind.profileSelfie) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AppNavigation.push<void>(AppRoutes.kycSelfie, arguments: rejectionReason);
    });
    return;
  }

  WidgetsBinding.instance.addPostFrameCallback((_) {
    AppNavigation.push<bool>(
      AppRoutes.kycDocumentCapture,
      arguments: DocumentCaptureArgs(
        kind: resolvedKind,
        vehicleId: vehicleId is String ? vehicleId : null,
        rejectionReason: rejectionReason,
      ),
    );
  });
}
