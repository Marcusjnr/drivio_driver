abstract class SafetyRepository {
  /// Fire an SOS event for the calling driver. Server resolves to the
  /// active trip (if any), stamps the driver's last GPS fix, and inserts
  /// a `safety_events` row. Returns the new event id.
  Future<String> triggerSos({
    String? tripId,
    String kind = 'sos',
    String severity = 'critical',
    Map<String, dynamic> payload = const <String, dynamic>{},
  });
}
