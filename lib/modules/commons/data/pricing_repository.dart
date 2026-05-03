import 'package:drivio_driver/modules/commons/types/pricing_profile.dart';

abstract class PricingRepository {
  /// Fetch (lazy-create on first call) the calling driver's pricing
  /// profile.
  Future<PricingProfile> getOrCreateMyProfile();

  /// Persist a partial update. Pass only the fields the caller is
  /// changing to avoid clobbering server-side defaults.
  ///
  /// `maxPickupKm` and `tripLength` are stored inside the `preferences`
  /// jsonb column. When either is provided the repository merges them
  /// into the existing jsonb so unrelated keys (added by future
  /// features) are preserved.
  Future<PricingProfile> updateMyProfile({
    int? baseMinor,
    int? perKmMinor,
    double? peakMultiplier,
    bool? peakEnabled,
    double? nightMultiplier,
    bool? nightEnabled,
    double? maxPickupKm,
    TripLengthPreference? tripLength,
  });
}
