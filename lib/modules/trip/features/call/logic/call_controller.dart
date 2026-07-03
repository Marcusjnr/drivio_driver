import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:drivio_driver/modules/commons/data/call_repository.dart';
import 'package:drivio_driver/modules/commons/di/di.dart';
import 'package:drivio_driver/modules/commons/supabase/supabase_module.dart';
import 'package:drivio_driver/modules/commons/types/call.dart';
import 'package:drivio_driver/modules/trip/features/call/logic/call_engine.dart';
import 'package:drivio_driver/modules/trip/features/call/logic/call_sounds.dart';

/// UI phase of the (single) active call. `muted`/`speakerOn` are flags on
/// the state, not phases.
enum CallPhase {
  idle,
  outgoingRinging,
  incomingRinging,
  connecting,
  connected,
  reconnecting,
  ended,
  declined,
  missed,
  cancelled,
  failed,
}

extension CallPhaseX on CallPhase {
  bool get isLive =>
      this == CallPhase.outgoingRinging ||
      this == CallPhase.incomingRinging ||
      this == CallPhase.connecting ||
      this == CallPhase.connected ||
      this == CallPhase.reconnecting;

  bool get isTerminal =>
      this == CallPhase.ended ||
      this == CallPhase.declined ||
      this == CallPhase.missed ||
      this == CallPhase.cancelled ||
      this == CallPhase.failed;
}

class CallState {
  const CallState({
    this.phase = CallPhase.idle,
    this.call,
    this.contact,
    this.muted = false,
    this.speakerOn = false,
    this.connectedSeconds = 0,
    this.error,
    this.engineJoined = false,
  });

  final CallPhase phase;
  final Call? call;
  final TripContact? contact;
  final bool muted;
  final bool speakerOn;
  final int connectedSeconds;
  final String? error;

  /// True once OUR side has joined the Agora channel — lets the UI say
  /// "waiting for the other side" instead of a generic Connecting….
  final bool engineJoined;

  CallState copyWith({
    CallPhase? phase,
    Call? call,
    TripContact? contact,
    bool? muted,
    bool? speakerOn,
    int? connectedSeconds,
    String? error,
    bool clearError = false,
    bool? engineJoined,
  }) {
    return CallState(
      phase: phase ?? this.phase,
      call: call ?? this.call,
      contact: contact ?? this.contact,
      muted: muted ?? this.muted,
      speakerOn: speakerOn ?? this.speakerOn,
      connectedSeconds: connectedSeconds ?? this.connectedSeconds,
      error: clearError ? null : (error ?? this.error),
      engineJoined: engineJoined ?? this.engineJoined,
    );
  }
}

/// Owns the one active call end to end: signaling (RPCs + call-row realtime),
/// media (CallEngine), ring timeout, and the connected clock. Terminal
/// transitions are idempotent — whichever signal lands first (row update,
/// engine event, local action, timer) wins and the rest no-op.
class ActiveCallController extends StateNotifier<CallState> {
  ActiveCallController({
    required CallRepository calls,
    required SupabaseModule supabase,
  })  : _calls = calls,
        _supabase = supabase,
        super(const CallState());

  static const Duration _ringTimeout = Duration(seconds: 30);

  final CallRepository _calls;
  final SupabaseModule _supabase;

  final CallSounds _sounds = CallSounds();

  CallEngine? _engine;
  StreamSubscription<Call>? _rowSub;
  StreamSubscription<CallEngineEvent>? _engineSub;
  StreamSubscription<Call>? _incomingSub;
  Timer? _ringTimer;
  Timer? _clock;

  String get _myId => _supabase.auth.currentUser?.id ?? '';

  /// Foreground ring path: watch for new ringing calls aimed at me and
  /// attach them. Idempotent — trip screens call this on open.
  void startIncomingWatch() {
    if (_incomingSub != null || _myId.isEmpty) return;
    _incomingSub = _calls.watchIncomingCalls(_myId).listen((Call call) {
      if (!state.phase.isLive) {
        unawaited(attachIncoming(call));
      }
    });
  }

  /// Catch a ring already in flight when a trip screen opens (e.g. the app
  /// was on another page when the INSERT happened).
  Future<void> hydrateLiveCall(String tripId) async {
    if (state.phase.isLive) return;
    try {
      final Call? live = await _calls.getLiveCallForTrip(tripId);
      if (live != null &&
          live.status == CallStatus.ringing &&
          live.calleeId == _myId) {
        await attachIncoming(live);
      }
    } catch (_) {/* best effort */}
  }

  // ── Outgoing ─────────────────────────────────────────────────────────

  /// Start ringing the counterpart of [tripId]. Returns false (with error
  /// state) when the call couldn't start.
  Future<bool> startOutgoing(String tripId) async {
    if (state.phase.isLive) return false;
    _resetInternals();
    state = const CallState(phase: CallPhase.outgoingRinging);
    unawaited(_sounds.playRingback());
    unawaited(_loadContact(tripId));
    try {
      final Call call = await _calls.startCall(tripId);
      if (!mounted) return false;
      state = state.copyWith(call: call);
      _watchRow(call.id);
      _armRingTimer(onTimeout: () async {
        await _safeCancel();
        _finish(CallPhase.missed);
      });
      return true;
    } on CallException catch (e) {
      if (!mounted) return false;
      state = CallState(
        phase: CallPhase.failed,
        error: switch (e.code) {
          'call_in_progress' => 'A call is already in progress on this trip.',
          'trip_not_active' => 'This trip is no longer active.',
          _ => "Couldn't start the call. Try again.",
        },
      );
      return false;
    }
  }

  /// Caller taps end while still ringing.
  Future<void> cancelOutgoing() async {
    await _safeCancel();
    _finish(CallPhase.cancelled);
  }

  Future<void> _safeCancel() async {
    final String? id = state.call?.id;
    if (id == null) return;
    try {
      await _calls.cancelCall(id);
    } catch (_) {/* row may already be terminal */}
  }

  // ── Incoming ─────────────────────────────────────────────────────────

  /// Attach a ringing call aimed at me (from the trip screen's realtime
  /// watcher, or hydrated from a push payload / CallKit accept).
  Future<void> attachIncoming(Call call, {bool autoAnswer = false}) async {
    if (state.phase.isLive && state.call?.id == call.id) return;
    _resetInternals();
    state = CallState(phase: CallPhase.incomingRinging, call: call);
    if (!autoAnswer) {
      unawaited(_sounds.playRingtone());
    }
    unawaited(_loadContact(call.tripId));
    _watchRow(call.id);
    _armRingTimer(onTimeout: () async => _finish(CallPhase.missed));
    if (autoAnswer) {
      await answer();
    }
  }

  Future<void> answer() async {
    final Call? call = state.call;
    if (call == null || state.phase != CallPhase.incomingRinging) return;
    _ringTimer?.cancel();
    unawaited(_sounds.stop());
    state = state.copyWith(phase: CallPhase.connecting);
    try {
      await _calls.answerCall(call.id);
      await _connectMedia(call);
    } on CallException {
      _finish(CallPhase.failed, error: "Couldn't join the call.");
    }
  }

  Future<void> decline() async {
    final String? id = state.call?.id;
    if (id != null) {
      try {
        await _calls.declineCall(id);
      } catch (_) {}
    }
    _finish(CallPhase.declined);
  }

  // ── In-call controls ─────────────────────────────────────────────────

  Future<void> toggleMute() async {
    final bool next = !state.muted;
    await _engine?.setMuted(next);
    state = state.copyWith(muted: next);
  }

  Future<void> toggleSpeaker() async {
    final bool next = !state.speakerOn;
    await _engine?.setSpeaker(next);
    state = state.copyWith(speakerOn: next);
  }

  Future<void> hangUp() async {
    final String? id = state.call?.id;
    if (id != null) {
      try {
        await _calls.endCall(id);
      } catch (_) {}
    }
    _finish(CallPhase.ended);
  }

  /// Back to idle after the UI has shown the terminal state.
  void reset() {
    _resetInternals();
    state = const CallState();
  }

  // ── Internals ────────────────────────────────────────────────────────

  Future<void> _loadContact(String tripId) async {
    try {
      final TripContact? c = await _calls.getTripContact(tripId);
      if (mounted && c != null) state = state.copyWith(contact: c);
    } catch (_) {/* identity header degrades gracefully */}
  }

  void _watchRow(String callId) {
    _rowSub?.cancel();
    _rowSub = _calls.watchCall(callId).listen((Call call) {
      if (!mounted || state.call?.id != call.id) return;
      state = state.copyWith(call: call);
      switch (call.status) {
        case CallStatus.accepted:
          // Caller side: callee picked up → join media.
          if (state.phase == CallPhase.outgoingRinging) {
            _ringTimer?.cancel();
            unawaited(_sounds.stop());
            state = state.copyWith(phase: CallPhase.connecting);
            unawaited(_connectMedia(call));
          }
        case CallStatus.declined:
          _finish(CallPhase.declined);
        case CallStatus.missed:
          _finish(CallPhase.missed);
        case CallStatus.cancelled:
          _finish(CallPhase.cancelled);
        case CallStatus.ended:
          _finish(CallPhase.ended);
        case CallStatus.failed:
          _finish(CallPhase.failed);
        case CallStatus.ringing:
        case CallStatus.unknown:
          break;
      }
    });
  }

  Future<void> _connectMedia(Call call) async {
    final CallEngine engine = CallEngine();
    _engine = engine;

    if (!await engine.ensureMicPermission()) {
      await _calls.endCall(call.id, reason: 'mic_permission_denied');
      _finish(
        CallPhase.failed,
        error: 'Microphone access is needed for calls. Enable it in Settings.',
      );
      return;
    }

    _engineSub = engine.events.listen((CallEngineEvent e) {
      if (!mounted) return;
      switch (e) {
        case CallEngineEvent.joined:
          state = state.copyWith(engineJoined: true);
        case CallEngineEvent.remoteJoined:
          state = state.copyWith(phase: CallPhase.connected);
          _startClock();
        case CallEngineEvent.remoteLeft:
          // The row update will confirm; treat as ended for snappy UX.
          unawaited(hangUp());
        case CallEngineEvent.reconnecting:
          if (state.phase == CallPhase.connected) {
            state = state.copyWith(phase: CallPhase.reconnecting);
          }
        case CallEngineEvent.reconnected:
          if (state.phase == CallPhase.reconnecting) {
            state = state.copyWith(phase: CallPhase.connected);
          }
        case CallEngineEvent.failed:
          unawaited(_calls.endCall(call.id, reason: 'connection_failed'));
          _finish(
            CallPhase.failed,
            error: engine.lastFailureDetail == null
                ? 'Connection lost.'
                : 'Call failed: ${engine.lastFailureDetail}',
          );
      }
    });

    // Watchdog: media must be flowing within 25s of starting the join,
    // otherwise fail loudly instead of hanging on "Connecting…".
    Timer(const Duration(seconds: 25), () {
      if (mounted &&
          (state.phase == CallPhase.connecting)) {
        unawaited(_calls.endCall(call.id, reason: 'connect_timeout'));
        _finish(
          CallPhase.failed,
          error: state.engineJoined
              ? "Couldn't hear the other side — they never joined the call."
              : "Couldn't connect to the call service. Check your internet.",
        );
      }
    });

    try {
      final AgoraCredentials creds =
          await _calls.fetchAgoraCredentials(call.id);
      await engine.join(creds, renewToken: () async {
        try {
          final AgoraCredentials fresh =
              await _calls.fetchAgoraCredentials(call.id);
          return fresh.token;
        } catch (_) {
          return null;
        }
      });
    } on CallException catch (e) {
      await _calls.endCall(call.id, reason: e.code);
      _finish(
        CallPhase.failed,
        error: e.code == 'agora_not_configured'
            ? 'Calling is not configured yet on this server.'
            : "Couldn't connect the call ({${e.code}}).",
      );
    } catch (e) {
      // e.g. FunctionException from the token endpoint — never hang.
      await _calls.endCall(call.id, reason: 'token_error');
      _finish(CallPhase.failed, error: 'Call setup failed: $e');
    }
  }

  void _armRingTimer({required Future<void> Function() onTimeout}) {
    _ringTimer?.cancel();
    _ringTimer = Timer(_ringTimeout, () {
      if (mounted && state.phase.isLive && state.phase != CallPhase.connected) {
        unawaited(onTimeout());
      }
    });
  }

  void _startClock() {
    _clock?.cancel();
    _clock = Timer.periodic(const Duration(seconds: 1), (Timer _) {
      if (!mounted) return;
      if (state.phase == CallPhase.connected ||
          state.phase == CallPhase.reconnecting) {
        state = state.copyWith(connectedSeconds: state.connectedSeconds + 1);
      }
    });
  }

  void _finish(CallPhase terminal, {String? error}) {
    if (!mounted || state.phase.isTerminal) return;
    unawaited(_sounds.stop());
    _ringTimer?.cancel();
    _clock?.cancel();
    _rowSub?.cancel();
    _engineSub?.cancel();
    final CallEngine? engine = _engine;
    _engine = null;
    unawaited(engine?.dispose() ?? Future<void>.value());
    state = state.copyWith(phase: terminal, error: error);
  }

  void _resetInternals() {
    // Note: _incomingSub deliberately survives resets — the watch is
    // app-lifetime once started.
    unawaited(_sounds.stop());
    _ringTimer?.cancel();
    _clock?.cancel();
    _rowSub?.cancel();
    _engineSub?.cancel();
    final CallEngine? engine = _engine;
    _engine = null;
    unawaited(engine?.dispose() ?? Future<void>.value());
  }

  /// Is this ringing call for me (I'm the callee)?
  bool isForMe(Call call) => call.calleeId == _myId;

  @override
  void dispose() {
    _incomingSub?.cancel();
    _resetInternals();
    unawaited(_sounds.dispose());
    super.dispose();
  }
}

/// Deliberately NOT autoDispose: the call outlives individual pages (sheet →
/// outgoing page → in-call). Lifecycle is explicit — `startOutgoing`/
/// `attachIncoming` reset state, `reset()` returns to idle after a terminal
/// phase has been shown.
final StateNotifierProvider<ActiveCallController, CallState>
    activeCallControllerProvider =
    StateNotifierProvider<ActiveCallController, CallState>(
  (Ref _) => ActiveCallController(
    calls: locator<CallRepository>(),
    supabase: locator<SupabaseModule>(),
  ),
);
