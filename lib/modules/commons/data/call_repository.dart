import 'package:drivio_driver/modules/commons/types/call.dart';

/// Wire error from the call RPCs / edge functions with a stable machine key
/// (e.g. `call_in_progress`, `trip_not_active`, `agora_not_configured`).
class CallException implements Exception {
  const CallException(this.code, this.message);

  final String code;
  final String message;

  @override
  String toString() => 'CallException($code)';
}

abstract interface class CallRepository {
  /// Start ringing the trip counterpart. Returns the created [Call]
  /// (status ringing). Throws [CallException] with `call_in_progress`,
  /// `trip_not_active`, etc.
  Future<Call> startCall(String tripId);

  Future<void> answerCall(String callId);

  Future<void> declineCall(String callId);

  Future<void> cancelCall(String callId);

  Future<void> endCall(String callId, {String? reason});

  /// Fetch a call row once (hydration after push-accept or app restart).
  Future<Call?> getCall(String callId);

  /// Live updates for one call row (Realtime postgres-changes).
  Stream<Call> watchCall(String callId);

  /// New ringing calls aimed at me (INSERTs where callee_id = my uid) —
  /// the foreground ring path while the app is open.
  Stream<Call> watchIncomingCalls(String myUserId);

  /// A currently-ringing (or accepted) call for me on this trip, if any —
  /// used when the trip screen opens to catch a ring already in flight.
  Future<Call?> getLiveCallForTrip(String tripId);

  /// Counterpart identity + phone (active trip only, server-enforced).
  Future<TripContact?> getTripContact(String tripId);

  /// Mint Agora credentials for a live call via the `agora-token` edge fn.
  Future<AgoraCredentials> fetchAgoraCredentials(String callId);
}
