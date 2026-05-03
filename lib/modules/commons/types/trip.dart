enum TripState {
  assigned,
  enRoute,
  arrived,
  inProgress,
  completed,
  cancelled;

  String get wire {
    switch (this) {
      case TripState.assigned:
        return 'assigned';
      case TripState.enRoute:
        return 'en_route';
      case TripState.arrived:
        return 'arrived';
      case TripState.inProgress:
        return 'in_progress';
      case TripState.completed:
        return 'completed';
      case TripState.cancelled:
        return 'cancelled';
    }
  }

  static TripState fromWire(String wire) {
    switch (wire) {
      case 'en_route':
        return TripState.enRoute;
      case 'arrived':
        return TripState.arrived;
      case 'in_progress':
        return TripState.inProgress;
      case 'completed':
        return TripState.completed;
      case 'cancelled':
        return TripState.cancelled;
      case 'assigned':
      default:
        return TripState.assigned;
    }
  }

  bool get isTerminal =>
      this == TripState.completed || this == TripState.cancelled;
}

class Trip {
  const Trip({
    required this.id,
    required this.rideRequestId,
    required this.bidId,
    required this.driverId,
    required this.vehicleId,
    required this.passengerId,
    required this.fareMinor,
    required this.currency,
    required this.state,
    required this.createdAt,
    required this.pickupLat,
    required this.pickupLng,
    required this.dropoffLat,
    required this.dropoffLng,
    this.pickupAddress,
    this.dropoffAddress,
    this.expectedDistanceM,
    this.expectedDurationS,
    this.startedAt,
    this.endedAt,
    this.cancellationReason,
    this.actualDistanceM,
    this.actualDurationS,
  });

  final String id;
  final String rideRequestId;
  final String bidId;
  final String driverId;
  final String vehicleId;
  final String passengerId;
  final int fareMinor;
  final String currency;
  final TripState state;
  final DateTime? startedAt;
  final DateTime? endedAt;
  final String? cancellationReason;
  final int? actualDistanceM;
  final int? actualDurationS;
  final DateTime createdAt;
  final double pickupLat;
  final double pickupLng;
  final String? pickupAddress;
  final double dropoffLat;
  final double dropoffLng;
  final String? dropoffAddress;
  final int? expectedDistanceM;
  final int? expectedDurationS;

  int get fareNaira => fareMinor ~/ 100;
  double get distanceKm =>
      ((expectedDistanceM ?? 0) / 1000).toDouble();
  int get durationMin => (expectedDurationS ?? 0) ~/ 60;

  factory Trip.fromJson(Map<String, dynamic> json) {
    DateTime? parse(Object? v) =>
        v == null ? null : DateTime.parse(v as String);
    return Trip(
      id: json['id'] as String,
      rideRequestId: json['ride_request_id'] as String,
      bidId: json['bid_id'] as String,
      driverId: json['driver_id'] as String,
      vehicleId: json['vehicle_id'] as String,
      passengerId: json['passenger_id'] as String,
      fareMinor: (json['fare_minor'] as num).toInt(),
      currency: json['currency'] as String,
      state: TripState.fromWire(json['state'] as String),
      startedAt: parse(json['started_at']),
      endedAt: parse(json['ended_at']),
      cancellationReason: json['cancellation_reason'] as String?,
      actualDistanceM: (json['actual_distance_m'] as num?)?.toInt(),
      actualDurationS: (json['actual_duration_s'] as num?)?.toInt(),
      createdAt: parse(json['created_at'])!,
      pickupLat: (json['pickup_lat'] as num).toDouble(),
      pickupLng: (json['pickup_lng'] as num).toDouble(),
      pickupAddress: json['pickup_address'] as String?,
      dropoffLat: (json['dropoff_lat'] as num).toDouble(),
      dropoffLng: (json['dropoff_lng'] as num).toDouble(),
      dropoffAddress: json['dropoff_address'] as String?,
      expectedDistanceM: (json['expected_distance_m'] as num?)?.toInt(),
      expectedDurationS: (json['expected_duration_s'] as num?)?.toInt(),
    );
  }
}
