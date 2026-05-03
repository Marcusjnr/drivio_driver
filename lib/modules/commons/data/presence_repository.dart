enum PresenceStatus { offline, online, onTrip }

extension PresenceStatusWire on PresenceStatus {
  String get wire {
    switch (this) {
      case PresenceStatus.offline:
        return 'offline';
      case PresenceStatus.online:
        return 'online';
      case PresenceStatus.onTrip:
        return 'on_trip';
    }
  }
}

abstract class PresenceRepository {
  Future<void> upsert({
    required PresenceStatus status,
    double? lat,
    double? lng,
    int? accuracyM,
    int? headingDeg,
    int? speedKph,
    int? batteryPct,
    String? vehicleId,
  });
}
