/// Voice-call signaling types. The `calls` row in Supabase is the source of
/// truth; Agora only carries media. Statuses mirror the DB check constraint.
enum CallStatus {
  ringing,
  accepted,
  declined,
  missed,
  cancelled,
  ended,
  failed,
  unknown;

  static CallStatus fromWire(String? wire) {
    switch (wire) {
      case 'ringing':
        return CallStatus.ringing;
      case 'accepted':
        return CallStatus.accepted;
      case 'declined':
        return CallStatus.declined;
      case 'missed':
        return CallStatus.missed;
      case 'cancelled':
        return CallStatus.cancelled;
      case 'ended':
        return CallStatus.ended;
      case 'failed':
        return CallStatus.failed;
      default:
        return CallStatus.unknown;
    }
  }

  bool get isTerminal =>
      this == CallStatus.declined ||
      this == CallStatus.missed ||
      this == CallStatus.cancelled ||
      this == CallStatus.ended ||
      this == CallStatus.failed;
}

class Call {
  const Call({
    required this.id,
    required this.tripId,
    required this.callerId,
    required this.calleeId,
    required this.channelName,
    required this.status,
    required this.createdAt,
    this.answeredAt,
    this.endedAt,
    this.endReason,
  });

  final String id;
  final String tripId;
  final String callerId;
  final String calleeId;
  final String channelName;
  final CallStatus status;
  final DateTime createdAt;
  final DateTime? answeredAt;
  final DateTime? endedAt;
  final String? endReason;

  factory Call.fromJson(Map<String, dynamic> json) {
    return Call(
      id: json['id'] as String,
      tripId: json['trip_id'] as String,
      callerId: json['caller_id'] as String,
      calleeId: json['callee_id'] as String,
      channelName: (json['channel_name'] as String?) ?? '',
      status: CallStatus.fromWire(json['status'] as String?),
      createdAt: DateTime.parse(json['created_at'] as String),
      answeredAt: json['answered_at'] == null
          ? null
          : DateTime.parse(json['answered_at'] as String),
      endedAt: json['ended_at'] == null
          ? null
          : DateTime.parse(json['ended_at'] as String),
      endReason: json['end_reason'] as String?,
    );
  }
}

/// The counterpart on an active trip (from `get_trip_contact`) — powers the
/// call sheet (Regular Call number) and the call screens' identity header.
class TripContact {
  const TripContact({
    required this.firstName,
    required this.avatarUrl,
    required this.phoneE164,
    required this.role,
  });

  final String? firstName;
  final String? avatarUrl;
  final String? phoneE164;

  /// 'driver' | 'rider' — the counterpart's role.
  final String role;

  String get displayName =>
      (firstName?.isNotEmpty ?? false) ? firstName! : 'your rider';

  factory TripContact.fromRpc(Map<String, dynamic> json) {
    return TripContact(
      firstName: json['first_name'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      phoneE164: json['phone_e164'] as String?,
      role: (json['role'] as String?) ?? 'rider',
    );
  }
}

/// What `agora-token` returns — everything the engine needs to join.
class AgoraCredentials {
  const AgoraCredentials({
    required this.token,
    required this.uid,
    required this.channel,
    required this.appId,
  });

  final String token;
  final int uid;
  final String channel;
  final String appId;

  factory AgoraCredentials.fromJson(Map<String, dynamic> json) {
    return AgoraCredentials(
      token: json['token'] as String,
      uid: (json['uid'] as num).toInt(),
      channel: json['channel'] as String,
      appId: json['appId'] as String,
    );
  }
}
