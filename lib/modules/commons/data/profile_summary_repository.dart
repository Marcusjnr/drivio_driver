import 'package:drivio_driver/modules/commons/types/profile_summary.dart';

abstract class ProfileSummaryRepository {
  /// Aggregated profile-hub metrics for the calling driver.
  Future<ProfileSummary> getMyProfileSummary();

  /// Counters for the Refer & Earn page (own code + referred-driver
  /// counts).
  Future<ReferralSummary> getMyReferralSummary();
}
