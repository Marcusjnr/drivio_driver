import 'dart:math' as math;

enum RideRequestStatus {
  open,
  matched,
  cancelled,
  expired;

  static RideRequestStatus fromWire(String wire) {
    switch (wire) {
      case 'matched':
        return RideRequestStatus.matched;
      case 'cancelled':
        return RideRequestStatus.cancelled;
      case 'expired':
        return RideRequestStatus.expired;
      case 'open':
      default:
        return RideRequestStatus.open;
    }
  }

  bool get isOpen => this == RideRequestStatus.open;
}

class RideRequest {
  const RideRequest({
    required this.id,
    required this.passengerId,
    required this.pickupLat,
    required this.pickupLng,
    required this.dropoffLat,
    required this.dropoffLng,
    required this.status,
    required this.createdAt,
    required this.expiresAt,
    this.pickupAddress,
    this.dropoffAddress,
    this.expectedDistanceM,
    this.expectedDurationS,
    this.pickupGeohash6,
    this.matchedBidId,
  });

  final String id;
  final String passengerId;
  final double pickupLat;
  final double pickupLng;
  final String? pickupAddress;
  final double dropoffLat;
  final double dropoffLng;
  final String? dropoffAddress;
  final int? expectedDistanceM;
  final int? expectedDurationS;
  final RideRequestStatus status;
  final String? pickupGeohash6;
  final String? matchedBidId;
  final DateTime createdAt;
  final DateTime expiresAt;

  /// Seconds remaining until [expiresAt] from a reference [now] (defaults to
  /// wall-clock now). Clamped to ≥ 0.
  int secondsRemaining([DateTime? now]) {
    final Duration delta = expiresAt.difference(now ?? DateTime.now());
    if (delta.isNegative) return 0;
    return delta.inSeconds;
  }

  /// Great-circle distance in metres from a point. Haversine on a sphere.
  double distanceMetersFrom(double lat, double lng) =>
      _haversineMeters(lat, lng, pickupLat, pickupLng);

  factory RideRequest.fromJson(Map<String, dynamic> json) {
    final (double, double) pickup = _readPoint(json, 'pickup',
        latKey: 'pickup_lat', lngKey: 'pickup_lng');
    final (double, double) dropoff = _readPoint(json, 'dropoff',
        latKey: 'dropoff_lat', lngKey: 'dropoff_lng');

    return RideRequest(
      id: json['id'] as String,
      passengerId: json['passenger_id'] as String,
      pickupLat: pickup.$1,
      pickupLng: pickup.$2,
      pickupAddress: json['pickup_address'] as String?,
      dropoffLat: dropoff.$1,
      dropoffLng: dropoff.$2,
      dropoffAddress: json['dropoff_address'] as String?,
      expectedDistanceM: (json['expected_distance_m'] as num?)?.toInt(),
      expectedDurationS: (json['expected_duration_s'] as num?)?.toInt(),
      status: RideRequestStatus.fromWire(json['status'] as String),
      pickupGeohash6: json['pickup_geohash6'] as String?,
      matchedBidId: json['matched_bid_id'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      expiresAt: DateTime.parse(json['expires_at'] as String),
    );
  }

  /// Accepts geometry encoded either as a `{type, coordinates: [lng, lat]}`
  /// GeoJSON object (when selected with `pickup::json`) or as two
  /// pre-extracted lat/lng fields. Falls back to the lat/lng fields by
  /// default since `select=*` returns geography as a WKB hex string we
  /// can't easily parse client-side.
  static (double, double) _readPoint(
    Map<String, dynamic> json,
    String geoKey, {
    required String latKey,
    required String lngKey,
  }) {
    final dynamic geo = json[geoKey];
    if (geo is Map) {
      final List<dynamic> coords = geo['coordinates'] as List<dynamic>;
      return ((coords[1] as num).toDouble(), (coords[0] as num).toDouble());
    }
    return (
      (json[latKey] as num).toDouble(),
      (json[lngKey] as num).toDouble(),
    );
  }
}

double _haversineMeters(double lat1, double lng1, double lat2, double lng2) {
  const double earthR = 6371000;
  final double dLat = _deg2rad(lat2 - lat1);
  final double dLng = _deg2rad(lng2 - lng1);
  final double a = (math.sin(dLat / 2) * math.sin(dLat / 2)) +
      math.cos(_deg2rad(lat1)) *
          math.cos(_deg2rad(lat2)) *
          math.sin(dLng / 2) *
          math.sin(dLng / 2);
  final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  return earthR * c;
}

double _deg2rad(double deg) => deg * (math.pi / 180);
