/// Aggregated profile-hub data: header stats, KYC status, vehicle
/// summary, lifetime metrics, and rating aggregate. Returned by the
/// `get_my_profile_summary` RPC in a single round-trip so the hub
/// doesn't need 5 parallel queries on first paint.
class ProfileSummary {
  const ProfileSummary({
    this.joinedAt,
    this.kycStatus,
    this.livenessPassed = false,
    this.hasActiveVehicle = false,
    this.activeVehicleModel,
    this.lifetimeTrips = 0,
    this.lifetimeEarningsMinor = 0,
    this.ratingAvg,
    this.ratingCount = 0,
  });

  final DateTime? joinedAt;
  final String?
  kycStatus; // raw enum: not_started/in_progress/pending_review/approved/rejected
  final bool livenessPassed; // drivers.liveness_passed_at is set
  final bool hasActiveVehicle;
  final String? activeVehicleModel;
  final int lifetimeTrips;
  final int lifetimeEarningsMinor;
  final double? ratingAvg;
  final int ratingCount;

  int get lifetimeEarningsNaira => lifetimeEarningsMinor ~/ 100;

  /// Driver is "verified" for UI badge purposes when KYC is approved,
  /// the face-liveness check has passed, AND they have an active vehicle.
  /// All three gate the on-the-road green check.
  bool get isVerified =>
      kycStatus == 'approved' && livenessPassed && hasActiveVehicle;

  static const ProfileSummary empty = ProfileSummary();

  factory ProfileSummary.fromJson(Map<String, dynamic> json) {
    return ProfileSummary(
      joinedAt: json['joined_at'] == null
          ? null
          : DateTime.parse(json['joined_at'] as String),
      kycStatus: json['kyc_status'] as String?,
      livenessPassed: (json['liveness_passed'] as bool?) ?? false,
      hasActiveVehicle: (json['has_active_vehicle'] as bool?) ?? false,
      activeVehicleModel: json['active_vehicle_model'] as String?,
      lifetimeTrips: (json['lifetime_trips'] as num?)?.toInt() ?? 0,
      lifetimeEarningsMinor:
          (json['lifetime_earnings_minor'] as num?)?.toInt() ?? 0,
      ratingAvg: (json['rating_avg'] as num?)?.toDouble(),
      ratingCount: (json['rating_count'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Counters for the Refer & Earn page.
class ReferralSummary {
  const ReferralSummary({
    this.myCode,
    this.totalReferred = 0,
    this.activeReferred = 0,
    this.pendingReferred = 0,
  });

  /// The driver's own referral code (what they share). Null until the
  /// profile row has one assigned.
  final String? myCode;

  /// Anyone who signed up using [myCode], regardless of KYC status.
  final int totalReferred;

  /// Subset of [totalReferred] who finished KYC (=fully active).
  final int activeReferred;

  /// Subset of [totalReferred] still mid-onboarding.
  final int pendingReferred;

  static const ReferralSummary empty = ReferralSummary();

  factory ReferralSummary.fromJson(Map<String, dynamic> json) {
    return ReferralSummary(
      myCode: json['my_code'] as String?,
      totalReferred: (json['total_referred'] as num?)?.toInt() ?? 0,
      activeReferred: (json['active_referred'] as num?)?.toInt() ?? 0,
      pendingReferred: (json['pending_referred'] as num?)?.toInt() ?? 0,
    );
  }
}
