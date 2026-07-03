import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:drivio_driver/modules/commons/data/call_repository.dart';
import 'package:drivio_driver/modules/commons/supabase/supabase_module.dart';
import 'package:drivio_driver/modules/commons/types/call.dart';

class SupabaseCallRepository implements CallRepository {
  SupabaseCallRepository(this._supabase);

  final SupabaseModule _supabase;

  /// Our RPCs raise bare string codes (`call_in_progress`, …); PostgREST
  /// surfaces them verbatim in the message.
  static String _codeFrom(String message) {
    final RegExpMatch? m = RegExp(r'([a-z_]+)').firstMatch(message);
    return m?.group(1) ?? 'unknown';
  }

  @override
  Future<Call> startCall(String tripId) async {
    try {
      final dynamic res = await _supabase.client.rpc<dynamic>(
        'start_call',
        params: <String, dynamic>{'p_trip_id': tripId},
      );
      final Map<String, dynamic> json = (res as Map).cast<String, dynamic>();
      final Call? call = await getCall(json['call_id'] as String);
      if (call == null) {
        throw const CallException('unknown', 'Call row missing after start');
      }
      return call;
    } on PostgrestException catch (e) {
      throw CallException(_codeFrom(e.message), e.message);
    }
  }

  @override
  Future<void> answerCall(String callId) => _simpleRpc('answer_call', callId);

  @override
  Future<void> declineCall(String callId) => _simpleRpc('decline_call', callId);

  @override
  Future<void> cancelCall(String callId) => _simpleRpc('cancel_call', callId);

  @override
  Future<void> endCall(String callId, {String? reason}) async {
    try {
      await _supabase.client.rpc<void>(
        'end_call',
        params: <String, dynamic>{'p_call_id': callId, 'p_reason': reason},
      );
    } on PostgrestException catch (e) {
      throw CallException(_codeFrom(e.message), e.message);
    }
  }

  Future<void> _simpleRpc(String fn, String callId) async {
    try {
      await _supabase.client.rpc<void>(
        fn,
        params: <String, dynamic>{'p_call_id': callId},
      );
    } on PostgrestException catch (e) {
      throw CallException(_codeFrom(e.message), e.message);
    }
  }

  @override
  Future<Call?> getCall(String callId) async {
    final Map<String, dynamic>? row = await _supabase
        .db('calls')
        .select()
        .eq('id', callId)
        .maybeSingle();
    return row == null ? null : Call.fromJson(row);
  }

  @override
  Stream<Call> watchCall(String callId) {
    final StreamController<Call> ctrl = StreamController<Call>.broadcast();
    final RealtimeChannel channel = _supabase.client
        .channel('calls:$callId')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'calls',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: callId,
          ),
          callback: (PostgresChangePayload p) {
            try {
              ctrl.add(Call.fromJson(p.newRecord));
            } catch (_) {/* malformed payload — ignore */}
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
  Stream<Call> watchIncomingCalls(String myUserId) {
    final StreamController<Call> ctrl = StreamController<Call>.broadcast();
    final RealtimeChannel channel = _supabase.client
        .channel('calls:incoming:$myUserId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'calls',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'callee_id',
            value: myUserId,
          ),
          callback: (PostgresChangePayload p) {
            try {
              final Call call = Call.fromJson(p.newRecord);
              if (call.status == CallStatus.ringing) ctrl.add(call);
            } catch (_) {/* malformed payload — ignore */}
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
  Future<Call?> getLiveCallForTrip(String tripId) async {
    final List<dynamic> rows = await _supabase
        .db('calls')
        .select()
        .eq('trip_id', tripId)
        .inFilter('status', <String>['ringing', 'accepted'])
        .order('created_at', ascending: false)
        .limit(1);
    if (rows.isEmpty) return null;
    return Call.fromJson((rows.first as Map).cast<String, dynamic>());
  }

  @override
  Future<TripContact?> getTripContact(String tripId) async {
    try {
      final dynamic res = await _supabase.client.rpc<dynamic>(
        'get_trip_contact',
        params: <String, dynamic>{'p_trip_id': tripId},
      );
      final List<dynamic> rows = res as List<dynamic>? ?? <dynamic>[];
      if (rows.isEmpty) return null;
      return TripContact.fromRpc((rows.first as Map).cast<String, dynamic>());
    } on PostgrestException catch (e) {
      throw CallException(_codeFrom(e.message), e.message);
    }
  }

  @override
  Future<AgoraCredentials> fetchAgoraCredentials(String callId) async {
    final FunctionResponse res = await _supabase.functions.invoke(
      'agora-token',
      body: <String, dynamic>{'callId': callId},
    );
    final Map<String, dynamic> json =
        (res.data as Map).cast<String, dynamic>();
    if (res.status != 200) {
      throw CallException(
        (json['error'] as String?) ?? 'token_failed',
        'Could not get a call token (${res.status}).',
      );
    }
    return AgoraCredentials.fromJson(json);
  }
}
