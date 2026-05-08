import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:drivio_driver/modules/commons/data/ride_request_repository.dart';
import 'package:drivio_driver/modules/commons/supabase/supabase_module.dart';
import 'package:drivio_driver/modules/commons/types/ride_bid.dart';
import 'package:drivio_driver/modules/commons/types/ride_request.dart';

class SupabaseRideRequestRepository implements RideRequestRepository {
  SupabaseRideRequestRepository(this._supabase);

  final SupabaseModule _supabase;

  @override
  Future<List<RideRequest>> listOpen() async {
    final List<dynamic> rows = await _supabase.client.rpc<dynamic>(
      'list_open_ride_requests',
    ) as List<dynamic>;
    return rows
        .map((dynamic r) => RideRequest.fromJson(r as Map<String, dynamic>))
        .toList(growable: false);
  }

  @override
  Stream<RideRequestEvent> changes() {
    final StreamController<RideRequestEvent> ctrl =
        StreamController<RideRequestEvent>.broadcast();

    final RealtimeChannel channel = _supabase.client
        .channel('public:ride_requests')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'ride_requests',
          callback: (PostgresChangePayload p) => ctrl.add(RideRequestEvent(
            kind: RideRequestEventKind.inserted,
            requestId: p.newRecord['id'] as String?,
          )),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'ride_requests',
          callback: (PostgresChangePayload p) => ctrl.add(RideRequestEvent(
            kind: RideRequestEventKind.updated,
            requestId: p.newRecord['id'] as String?,
          )),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.delete,
          schema: 'public',
          table: 'ride_requests',
          callback: (PostgresChangePayload p) => ctrl.add(RideRequestEvent(
            kind: RideRequestEventKind.deleted,
            requestId: p.oldRecord['id'] as String?,
          )),
        );

    channel.subscribe();

    ctrl.onCancel = () async {
      await _supabase.client.removeChannel(channel);
      await ctrl.close();
    };

    return ctrl.stream;
  }

  @override
  Future<RideRequest?> getById(String id) async {
    final List<dynamic> rows = await _supabase.client.rpc<dynamic>(
      'get_ride_request',
      params: <String, dynamic>{'p_id': id},
    ) as List<dynamic>;
    if (rows.isEmpty) return null;
    return RideRequest.fromJson(rows.first as Map<String, dynamic>);
  }

  @override
  Future<String> submitBid({
    required String requestId,
    required String vehicleId,
    required int priceMinor,
    int? etaSeconds,
  }) async {
    final dynamic res = await _supabase.client.rpc<dynamic>(
      'submit_bid',
      params: <String, dynamic>{
        'p_request_id': requestId,
        'p_vehicle_id': vehicleId,
        'p_price_minor': priceMinor,
        'p_eta_seconds': etaSeconds,
      },
    );
    return res as String;
  }

  @override
  Future<void> withdrawBid(String bidId) async {
    await _supabase.client.rpc<void>(
      'withdraw_bid',
      params: <String, dynamic>{'p_bid_id': bidId},
    );
  }

  @override
  Stream<RideBid> watchBid(String bidId) {
    final StreamController<RideBid> ctrl =
        StreamController<RideBid>.broadcast();

    final RealtimeChannel channel = _supabase.client
        .channel('ride_bids:$bidId')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'ride_bids',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: bidId,
          ),
          callback: (PostgresChangePayload p) {
            ctrl.add(RideBid.fromJson(p.newRecord));
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
  Future<String?> findTripIdForBid(String bidId) async {
    final List<Map<String, dynamic>> rows = await _supabase
        .db('trips')
        .select('id')
        .eq('bid_id', bidId)
        .limit(1);
    if (rows.isEmpty) return null;
    return rows.first['id'] as String;
  }
}
