import 'package:drivio_driver/modules/commons/types/document.dart';

class KycSnapshot {
  const KycSnapshot({
    required this.kycStatus,
    required this.bvnVerifiedAt,
    required this.ninVerifiedAt,
    required this.livenessPassedAt,
    required this.documents,
    required this.hasVehicle,
  });

  final String kycStatus; // raw enum value from drivers.kyc_status
  final DateTime? bvnVerifiedAt;
  final DateTime? ninVerifiedAt;
  final DateTime? livenessPassedAt;
  final List<Document> documents;
  final bool hasVehicle;
}

abstract class KycRepository {
  Future<KycSnapshot> loadSnapshot();
  Future<void> markStepCompleted(String step); // 'bvn' | 'nin' | 'selfie'
  Future<String?> submitForReview();
}
