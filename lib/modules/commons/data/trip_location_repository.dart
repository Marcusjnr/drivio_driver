class TripLocationSample {
  const TripLocationSample({
    required this.lat,
    required this.lng,
    required this.recordedAt,
    this.speedKph,
    this.headingDeg,
  });

  final double lat;
  final double lng;
  final DateTime recordedAt;
  final int? speedKph;
  final int? headingDeg;

  factory TripLocationSample.fromJson(Map<String, dynamic> json) {
    return TripLocationSample(
      lat: (json['lat'] as num).toDouble(),
      lng: (json['lng'] as num).toDouble(),
      recordedAt: DateTime.parse(json['recorded_at'] as String),
      speedKph: (json['speed_kph'] as num?)?.toInt(),
      headingDeg: (json['heading_deg'] as num?)?.toInt(),
    );
  }
}

abstract class TripLocationRepository {
  /// Persist a single GPS sample (5s batched cadence per spec).
  Future<void> record({
    required String tripId,
    required double lat,
    required double lng,
    int? speedKph,
    int? headingDeg,
    DateTime? recordedAt,
  });

  /// Broadcast a single GPS sample on the trip's 1Hz channel
  /// (`trip:<id>:driver_location`). No DB write — purely for
  /// passenger-side live map consumption.
  Future<void> broadcast({
    required String tripId,
    required double lat,
    required double lng,
    int? speedKph,
    int? headingDeg,
  });

  /// Fetch recorded breadcrumbs for a trip, newest first.
  Future<List<TripLocationSample>> listSamples({
    required String tripId,
    int limit = 720,
  });
}
