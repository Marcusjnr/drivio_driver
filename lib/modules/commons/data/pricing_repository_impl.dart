import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:drivio_driver/modules/commons/data/pricing_repository.dart';
import 'package:drivio_driver/modules/commons/location/location_permission_service.dart';
import 'package:drivio_driver/modules/commons/logging/app_logger.dart';
import 'package:drivio_driver/modules/commons/supabase/supabase_module.dart';
import 'package:drivio_driver/modules/commons/types/pricing_profile.dart';
import 'package:drivio_driver/modules/commons/types/state_price_guidance.dart';

class SupabasePricingRepository implements PricingRepository {
  SupabasePricingRepository(this._supabase);

  final SupabaseModule _supabase;

  // In-memory cache of the last resolved state guidance. The state and its
  // admin-set defaults change rarely, so both the Pricing screen and the
  // per-request bid composer can reuse this within a session.
  String? _cachedGuidanceState;
  StatePriceGuidance? _cachedGuidance;

  @override
  Future<PricingProfile> getOrCreateMyProfile({String? state}) async {
    final String? trimmed = state?.trim();
    final List<dynamic> rows = await _supabase.client.rpc<dynamic>(
      'get_or_create_my_pricing_profile',
      params: <String, dynamic>{
        if (trimmed != null && trimmed.isNotEmpty) 'p_state': trimmed,
      },
    ) as List<dynamic>;
    if (rows.isEmpty) return PricingProfile.platformDefault;
    return PricingProfile.fromJson(rows.first as Map<String, dynamic>);
  }

  @override
  Future<String?> resolveMyState() async {
    try {
      // Prefer the cached fix — instant and free. When there isn't one
      // (fresh install, first launch after reboot) fall back to a real
      // fix, but ONLY if permission is already granted: this path must
      // never pop the system permission dialog. Without permission we
      // return null and the caller decides how to gate.
      Position? last = await Geolocator.getLastKnownPosition();
      if (last == null) {
        final LocationPermState perm =
            await const LocationPermissionService().currentState();
        if (!perm.isUsable) return null;
        last = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.low,
            timeLimit: Duration(seconds: 8),
          ),
        );
      }

      final FunctionResponse res = await _supabase.functions.invoke(
        'reverse-state',
        body: <String, dynamic>{
          'lat': last.latitude,
          'lng': last.longitude,
        },
      );
      final Object? data = res.data;
      if (data is! Map) return null;
      final Object? state = data['state'];
      if (state is! String) return null;
      final String trimmed = state.trim();
      return trimmed.isEmpty ? null : trimmed;
    } catch (e, st) {
      // Any failure just means we seed from the national default.
      AppLogger.w('resolveMyState failed', error: e, stackTrace: st);
      return null;
    }
  }

  @override
  Future<StatePriceGuidance?> getStateGuidance({String? state}) async {
    try {
      final String? resolved = (state != null && state.trim().isNotEmpty)
          ? state.trim()
          : await resolveMyState();
      // Key the cache by the resolved state ('' = national default) so a
      // second surface in the same session skips the round-trip.
      final String key = resolved ?? '';
      if (_cachedGuidance != null && _cachedGuidanceState == key) {
        return _cachedGuidance;
      }
      final List<dynamic> rows = await _supabase.client.rpc<dynamic>(
        'get_state_pricing_default',
        params: <String, dynamic>{'p_state': resolved ?? ''},
      ) as List<dynamic>;
      if (rows.isEmpty) return null;
      final StatePriceGuidance g =
          StatePriceGuidance.fromRpc(rows.first as Map<String, dynamic>);
      _cachedGuidance = g;
      _cachedGuidanceState = key;
      return g;
    } catch (e, st) {
      AppLogger.w('getStateGuidance failed', error: e, stackTrace: st);
      return null;
    }
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
