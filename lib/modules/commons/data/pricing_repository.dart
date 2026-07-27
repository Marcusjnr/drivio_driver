import 'package:drivio_driver/modules/commons/types/pricing_profile.dart';

abstract class PricingRepository {
  /// Fetch (lazy-create on first call) the calling driver's pricing
  /// profile.
  ///
  /// [state] seeds a *brand-new* profile from that state's admin-set
  /// default (base fare + per-km). It is only consulted the first time a
  /// row is created — an existing driver's numbers are never overwritten.
  /// Pass null (or an unknown state) to seed from the national default.
  Future<PricingProfile> getOrCreateMyProfile({String? state});

  /// Best-effort resolution of the driver's current Nigerian state from
  /// their last known GPS fix, so a first-time profile can be seeded from
  /// the local default. Returns null on any failure (no fix, no
  /// permission, network error, unknown state) — the caller then falls
  /// back to the national default. Never prompts for permission.
  Future<String?> resolveMyState();

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
