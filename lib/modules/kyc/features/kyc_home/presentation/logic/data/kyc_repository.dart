import 'package:drivio_driver/modules/commons/types/document.dart';

class KycSnapshot {
  const KycSnapshot({
    required this.kycStatus,
    required this.bvnVerifiedAt,
    required this.ninVerifiedAt,
    required this.livenessPassedAt,
    required this.driversLicenceVerifiedAt,
    required this.documents,
    required this.vehicleId,
  });

  final String kycStatus; // raw enum value from drivers.kyc_status
  final DateTime? bvnVerifiedAt;
  final DateTime? ninVerifiedAt;
  final DateTime? livenessPassedAt;
  final DateTime? driversLicenceVerifiedAt;
  final List<Document> documents;

  /// The driver's current (non-deleted) vehicle id, or null if they
  /// don't have one. Used to attach a rejection-fix re-upload to the
  /// SAME vehicle instead of creating a new one.
  final String? vehicleId;

  bool get hasVehicle => vehicleId != null;
}

/// Outcome of a server-side NIN verification (YouVerify).
enum NinVerifyResult {
  /// NIN found and its identity matches the driver's profile — verified.
  verified,

  /// The NIN doesn't exist / couldn't be found at NIMC.
  notFound,

  /// NIN found, but the name on it doesn't match the driver's profile.
  mismatch,

  /// Network / server / config failure — retryable.
  error,
}

abstract class KycRepository {
  Future<KycSnapshot> loadSnapshot();
  Future<void> markStepCompleted(String step); // 'bvn' | 'nin' | 'selfie'
  Future<String?> submitForReview();

  /// Verifies [nin] against NIMC via the `youverify-verify-nin` edge
  /// function and, on a match with the driver's profile, stamps
  /// `drivers.nin_verified_at` server-side.
  Future<NinVerifyResult> verifyNin(String nin);

  /// Verifies [licenceNo] against FRSC via the
  /// `youverify-verify-drivers-license` edge function and, on a name match,
  /// stamps `drivers.drivers_licence_verified_at` server-side. Reuses
  /// [NinVerifyResult] — the outcomes are identical (verified / not found /
  /// mismatch / error).
  Future<NinVerifyResult> verifyDriversLicence(String licenceNo);
}
