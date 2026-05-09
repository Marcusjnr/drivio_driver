import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:drivio_driver/modules/commons/data/pricing_repository.dart';
import 'package:drivio_driver/modules/commons/supabase/supabase_module.dart';
import 'package:drivio_driver/modules/commons/types/pricing_profile.dart';

class SupabasePricingRepository implements PricingRepository {
  SupabasePricingRepository(this._supabase);

  final SupabaseModule _supabase;

  @override
  Future<PricingProfile> getOrCreateMyProfile() async {
    final List<dynamic> rows = await _supabase.client.rpc<dynamic>(
      'get_or_create_my_pricing_profile',
    ) as List<dynamic>;
    if (rows.isEmpty) return PricingProfile.platformDefault;
    return PricingProfile.fromJson(rows.first as Map<String, dynamic>);
  }

  @override
  Future<PricingProfile> updateMyProfile({
    int? baseMinor,
    int? perKmMinor,
    double? peakMultiplier,
    bool? peakEnabled,
    double? nightMultiplier,
    bool? nightEnabled,
    TripLengthPreference? tripLength,
  }) async {
    final User? user = _supabase.auth.currentUser;
    if (user == null) {
      throw const _PricingAuthException();
    }
    // Lazy-create the row so the update has something to hit, and so we
    // can read the current `preferences` jsonb to merge into.
    final PricingProfile current = await getOrCreateMyProfile();

    final Map<String, dynamic> patch = <String, dynamic>{
      if (baseMinor != null) 'base_minor': baseMinor,
      if (perKmMinor != null) 'per_km_minor': perKmMinor,
      if (peakMultiplier != null) 'peak_multiplier': peakMultiplier,
      if (peakEnabled != null) 'peak_enabled': peakEnabled,
      if (nightMultiplier != null) 'night_multiplier': nightMultiplier,
      if (nightEnabled != null) 'night_enabled': nightEnabled,
    };

    // Merge prefs as a single jsonb write. We read-modify-write the
    // whole object so the update is atomic from the row's POV (Supabase
    // doesn't expose `jsonb_set` over PostgREST cleanly). Concurrent
    // edits by the same driver are debounced upstream so a stale
    // base-merge here is unlikely.
    if (tripLength != null) {
      patch['preferences'] = <String, dynamic>{
        ...current.preferencesJson,
        'trip_length': tripLength.wire,
      };
    }

    if (patch.isEmpty) return current;

    final Map<String, dynamic> row = await _supabase
        .db('driver_pricing_profile')
        .update(patch)
        .eq('driver_id', user.id)
        .select()
        .single();
    return PricingProfile.fromJson(row);
  }
}

class _PricingAuthException implements Exception {
  const _PricingAuthException();
  @override
  String toString() => 'PricingAuthException: no signed-in user';
}
