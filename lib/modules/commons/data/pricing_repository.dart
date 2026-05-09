import 'package:drivio_driver/modules/commons/types/pricing_profile.dart';

abstract class PricingRepository {
  /// Fetch (lazy-create on first call) the calling driver's pricing
  /// profile.
  Future<PricingProfile> getOrCreateMyProfile();

  /// Persist a partial update. Pass only the fields the caller is
  /// changing to avoid clobbering server-side defaults.
  ///
  /// `tripLength` is stored inside the `preferences` jsonb column.
  /// When provided the repository merges it into the existing jsonb
  /// so unrelated keys (added by future features) are preserved.
  Future<PricingProfile> updateMyProfile({
    int? baseMinor,
    int? perKmMinor,
    double? peakMultiplier,
    bool? peakEnabled,
    double? nightMultiplier,
    bool? nightEnabled,
    TripLengthPreference? tripLength,
  });
}
