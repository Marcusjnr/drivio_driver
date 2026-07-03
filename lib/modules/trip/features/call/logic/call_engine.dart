import 'dart:async';

import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:drivio_driver/modules/commons/types/call.dart';

/// Events the engine surfaces to the call state machine.
enum CallEngineEvent {
  joined,
  remoteJoined,
  remoteLeft,
  reconnecting,
  reconnected,
  failed,
}

/// Thin lifecycle wrapper around the Agora RTC engine, tuned for 1:1 voice:
/// communication profile (lowest latency for duplex talk), speech-standard
/// audio (~18 kbps voice-optimized — right for Nigerian mobile networks),
/// echo cancellation / noise suppression / AGC on via the default scenario,
/// video never initialized. Created lazily per call and released after —
/// no idle Agora process burning battery.
class CallEngine {
  RtcEngine? _engine;
  final StreamController<CallEngineEvent> _events =
      StreamController<CallEngineEvent>.broadcast();

  Stream<CallEngineEvent> get events => _events.stream;

  /// Last fatal engine error, for diagnostics ("AgoraErrorCode.xyz").
  String? lastFailureDetail;

  bool _muted = false;
  bool _speakerOn = false;

  bool get muted => _muted;
  bool get speakerOn => _speakerOn;

  /// Ask for the microphone. Returns false when denied — the caller shows
  /// the settings nudge.
  Future<bool> ensureMicPermission() async {
    final PermissionStatus status = await Permission.microphone.request();
    return status.isGranted;
  }

  /// Initialize + join. Renewal is handled internally: when the token is
  /// about to expire we re-fetch via [renewToken] and hand it to the engine.
  Future<void> join(
    AgoraCredentials creds, {
    required Future<String?> Function() renewToken,
  }) async {
    final RtcEngine engine = createAgoraRtcEngine();
    _engine = engine;

    await engine.initialize(RtcEngineContext(
      appId: creds.appId,
      channelProfile: ChannelProfileType.channelProfileCommunication,
    ));

    engine.registerEventHandler(RtcEngineEventHandler(
      onJoinChannelSuccess: (RtcConnection c, int elapsed) {
        _events.add(CallEngineEvent.joined);
      },
      onUserJoined: (RtcConnection c, int uid, int elapsed) {
        _events.add(CallEngineEvent.remoteJoined);
      },
      onUserOffline: (RtcConnection c, int uid, UserOfflineReasonType r) {
        _events.add(CallEngineEvent.remoteLeft);
      },
      onConnectionStateChanged: (
        RtcConnection c,
        ConnectionStateType state,
        ConnectionChangedReasonType reason,
      ) {
        if (state == ConnectionStateType.connectionStateReconnecting) {
          _events.add(CallEngineEvent.reconnecting);
        } else if (state == ConnectionStateType.connectionStateConnected) {
          _events.add(CallEngineEvent.reconnected);
        } else if (state == ConnectionStateType.connectionStateFailed) {
          _events.add(CallEngineEvent.failed);
        }
      },
      onError: (ErrorCodeType err, String msg) {
        // Surface fatal join blockers — without this, a bad App ID or a
        // rejected token hangs on "Connecting…" forever.
        const Set<ErrorCodeType> fatal = <ErrorCodeType>{
          ErrorCodeType.errInvalidAppId,
          ErrorCodeType.errInvalidChannelName,
          ErrorCodeType.errInvalidToken,
          ErrorCodeType.errTokenExpired,
          ErrorCodeType.errJoinChannelRejected,
          ErrorCodeType.errFailed,
        };
        if (fatal.contains(err)) {
          lastFailureDetail = '${err.name}${msg.isEmpty ? '' : ' — $msg'}';
          _events.add(CallEngineEvent.failed);
        }
      },
      onTokenPrivilegeWillExpire: (RtcConnection c, String token) async {
        final String? fresh = await renewToken();
        if (fresh != null) {
          await _engine?.renewToken(fresh);
        }
      },
    ));

    await engine.setAudioProfile(
      profile: AudioProfileType.audioProfileSpeechStandard,
      scenario: AudioScenarioType.audioScenarioDefault,
    );
    await engine.enableAudio();
    // Voice starts on the earpiece like a phone call; speaker is a toggle.
    await engine.setDefaultAudioRouteToSpeakerphone(false);

    await engine.joinChannel(
      token: creds.token,
      channelId: creds.channel,
      uid: creds.uid,
      options: const ChannelMediaOptions(
        channelProfile: ChannelProfileType.channelProfileCommunication,
        clientRoleType: ClientRoleType.clientRoleBroadcaster,
        autoSubscribeAudio: true,
        publishMicrophoneTrack: true,
      ),
    );
  }

  Future<void> setMuted(bool muted) async {
    _muted = muted;
    await _engine?.muteLocalAudioStream(muted);
  }

  Future<void> setSpeaker(bool on) async {
    _speakerOn = on;
    await _engine?.setEnableSpeakerphone(on);
  }

  /// Leave + destroy. Safe to call repeatedly.
  Future<void> dispose() async {
    final RtcEngine? engine = _engine;
    _engine = null;
    if (engine != null) {
      try {
        await engine.leaveChannel();
      } catch (_) {/* already left */}
      await engine.release();
    }
    _muted = false;
    _speakerOn = false;
  }
}
