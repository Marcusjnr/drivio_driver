import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:drivio_driver/modules/commons/data/trip_repository.dart';
import 'package:drivio_driver/modules/commons/supabase/supabase_module.dart';
import 'package:drivio_driver/modules/commons/types/trip.dart';

class SupabaseTripRepository implements TripRepository {
  SupabaseTripRepository(this._supabase);

  final SupabaseModule _supabase;

  @override
  Future<Trip?> getTrip(String id) async {
    final List<dynamic> rows = await _supabase.client.rpc<dynamic>(
      'get_trip_with_route',
      params: <String, dynamic>{'p_id': id},
    ) as List<dynamic>;
    if (rows.isEmpty) return null;
    return Trip.fromJson(rows.first as Map<String, dynamic>);
  }

  @override
  Future<String?> getMyActiveTripId() async {
    final dynamic res = await _supabase.client.rpc<dynamic>(
      'get_my_active_trip',
    );
    return res as String?;
  }

  @override
  Stream<Trip> watchTrip(String tripId) {
    final StreamController<Trip> ctrl = StreamController<Trip>.broadcast();
    final RealtimeChannel channel = _supabase.client
        .channel('trips:$tripId')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'trips',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: tripId,
          ),
          callback: (PostgresChangePayload _) async {
            // Re-fetch to get the joined route fields.
            final Trip? fresh = await getTrip(tripId);
            if (fresh != null) ctrl.add(fresh);
          },
        );
    channel.subscribe();
    ctrl.onCancel = () async {
      await _supabase.client.removeChannel(channel);
      await ctrl.close();
    };
    return ctrl.stream;
  }

  @override
  Future<String> transition({
    required String tripId,
    required TripState toState,
    String? reason,
  }) async {
    final dynamic res = await _supabase.client.rpc<dynamic>(
      'transition_trip',
      params: <String, dynamic>{
        'p_trip_id': tripId,
        'p_to_state': toState.wire,
        'p_reason': reason,
      },
    );
    return res as String;
  }
}
