import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:drivio_driver/modules/commons/data/trip_location_repository.dart';
import 'package:drivio_driver/modules/commons/supabase/supabase_module.dart';

class SupabaseTripLocationRepository implements TripLocationRepository {
  SupabaseTripLocationRepository(this._supabase);

  final SupabaseModule _supabase;

  /// Channels are created lazily and reused across broadcasts so we don't
  /// pay subscribe/teardown cost per tick.
  final Map<String, RealtimeChannel> _channels = <String, RealtimeChannel>{};

  @override
  Future<void> record({
    required String tripId,
    required double lat,
    required double lng,
    int? speedKph,
    int? headingDeg,
    DateTime? recordedAt,
  }) async {
    await _supabase.client.rpc<void>(
      'record_trip_location',
      params: <String, dynamic>{
        'p_trip_id': tripId,
        'p_lat': lat,
        'p_lng': lng,
        'p_speed_kph': speedKph,
        'p_heading_deg': headingDeg,
        if (recordedAt != null)
          'p_recorded_at': recordedAt.toUtc().toIso8601String(),
      },
    );
  }

  @override
  Future<void> broadcast({
    required String tripId,
    required double lat,
    required double lng,
    int? speedKph,
    int? headingDeg,
  }) async {
    final RealtimeChannel ch = _channelFor(tripId);
    await ch.sendBroadcastMessage(
      event: 'driver_location',
      payload: <String, dynamic>{
        'lat': lat,
        'lng': lng,
        'speed_kph': speedKph,
        'heading_deg': headingDeg,
        'at': DateTime.now().toUtc().toIso8601String(),
      },
    );
  }

  @override
  Future<List<TripLocationSample>> listSamples({
    required String tripId,
    int limit = 720,
  }) async {
    final List<dynamic> rows = await _supabase.client.rpc<dynamic>(
      'get_trip_locations',
      params: <String, dynamic>{'p_trip_id': tripId, 'p_limit': limit},
    ) as List<dynamic>;
    return rows
        .map((dynamic r) =>
            TripLocationSample.fromJson(r as Map<String, dynamic>))
        .toList(growable: false);
  }

  RealtimeChannel _channelFor(String tripId) {
    final RealtimeChannel? existing = _channels[tripId];
    if (existing != null) return existing;
    final RealtimeChannel ch = _supabase.client
        .channel('trip:$tripId:driver_location')
      ..subscribe();
    _channels[tripId] = ch;
    return ch;
  }
}
