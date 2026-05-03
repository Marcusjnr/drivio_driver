import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:drivio_driver/modules/commons/data/message_repository.dart';
import 'package:drivio_driver/modules/commons/supabase/supabase_module.dart';
import 'package:drivio_driver/modules/commons/types/message.dart';

class SupabaseMessageRepository implements MessageRepository {
  SupabaseMessageRepository(this._supabase);

  final SupabaseModule _supabase;

  @override
  Future<List<Message>> listForTrip(String tripId) async {
    final List<Map<String, dynamic>> rows = await _supabase
        .db('messages')
        .select()
        .eq('trip_id', tripId)
        .order('created_at', ascending: true);
    return rows.map(Message.fromJson).toList(growable: false);
  }

  @override
  Future<Message> send({
    required String tripId,
    required String body,
    MessageKind kind = MessageKind.text,
  }) async {
    final User? user = _supabase.auth.currentUser;
    if (user == null) {
      throw const _MessageAuthException();
    }
    final Map<String, dynamic> row = await _supabase
        .db('messages')
        .insert(<String, dynamic>{
          'trip_id': tripId,
          'sender_user_id': user.id,
          'body': body,
          'kind': kind.wire,
        })
        .select()
        .single();
    return Message.fromJson(row);
  }

  @override
  Stream<Message> watchForTrip(String tripId) {
    final StreamController<Message> ctrl =
        StreamController<Message>.broadcast();
    final RealtimeChannel channel = _supabase.client
        .channel('messages:$tripId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'trip_id',
            value: tripId,
          ),
          callback: (PostgresChangePayload p) =>
              ctrl.add(Message.fromJson(p.newRecord)),
        );
    channel.subscribe();
    ctrl.onCancel = () async {
      await _supabase.client.removeChannel(channel);
      await ctrl.close();
    };
    return ctrl.stream;
  }
}

class _MessageAuthException implements Exception {
  const _MessageAuthException();
  @override
  String toString() => 'MessageAuthException: no signed-in user';
}
