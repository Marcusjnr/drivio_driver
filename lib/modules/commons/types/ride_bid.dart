enum RideBidStatus {
  pending,
  accepted,
  rejected,
  expired,
  withdrawn;

  static RideBidStatus fromWire(String wire) {
    switch (wire) {
      case 'accepted':
        return RideBidStatus.accepted;
      case 'rejected':
        return RideBidStatus.rejected;
      case 'expired':
        return RideBidStatus.expired;
      case 'withdrawn':
        return RideBidStatus.withdrawn;
      case 'pending':
      default:
        return RideBidStatus.pending;
    }
  }

  bool get isTerminal => this != RideBidStatus.pending;
}

class RideBid {
  const RideBid({
    required this.id,
    required this.rideRequestId,
    required this.driverId,
    required this.vehicleId,
    required this.priceMinor,
    required this.currency,
    required this.status,
    required this.createdAt,
    required this.expiresAt,
    this.etaSeconds,
  });

  final String id;
  final String rideRequestId;
  final String driverId;
  final String vehicleId;
  final int priceMinor;
  final String currency;
  final int? etaSeconds;
  final RideBidStatus status;
  final DateTime createdAt;
  final DateTime expiresAt;

  factory RideBid.fromJson(Map<String, dynamic> json) {
    return RideBid(
      id: json['id'] as String,
      rideRequestId: json['ride_request_id'] as String,
      driverId: json['driver_id'] as String,
      vehicleId: json['vehicle_id'] as String,
      priceMinor: (json['price_minor'] as num).toInt(),
      currency: json['currency'] as String,
      etaSeconds: (json['eta_seconds'] as num?)?.toInt(),
      status: RideBidStatus.fromWire(json['status'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
      expiresAt: DateTime.parse(json['expires_at'] as String),
    );
  }
}
