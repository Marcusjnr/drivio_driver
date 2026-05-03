import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:drivio_driver/modules/commons/data/notification_repository.dart';
import 'package:drivio_driver/modules/commons/supabase/supabase_module.dart';
import 'package:drivio_driver/modules/commons/types/notification_item.dart';

class SupabaseNotificationRepository implements NotificationRepository {
  SupabaseNotificationRepository(this._supabase);

  final SupabaseModule _supabase;

  @override
  Future<List<NotificationItem>> listMine({int limit = 50}) async {
    final User? user = _supabase.auth.currentUser;
    if (user == null) return const <NotificationItem>[];
    final List<Map<String, dynamic>> rows = await _supabase
        .db('notifications')
        .select()
        .eq('user_id', user.id)
        .order('created_at', ascending: false)
        .limit(limit);
    return rows.map(NotificationItem.fromJson).toList(growable: false);
  }

  @override
  Future<int> unreadCount() async {
    final User? user = _supabase.auth.currentUser;
    if (user == null) return 0;
    final List<Map<String, dynamic>> rows = await _supabase
        .db('notifications')
        .select('id')
        .eq('user_id', user.id)
        .filter('read_at', 'is', null);
    return rows.length;
  }

  @override
  Future<void> markRead(String id) async {
    await _supabase.client.rpc<void>(
      'mark_notification_read',
      params: <String, dynamic>{'p_id': id},
    );
  }

  @override
  Future<void> markAllRead() async {
    await _supabase.client.rpc<void>('mark_all_notifications_read');
  }

  @override
  Stream<NotificationItem> watchInserts() {
    return _watch(PostgresChangeEvent.insert);
  }

  @override
  Stream<NotificationItem> watchUpdates() {
    return _watch(PostgresChangeEvent.update);
  }

  Stream<NotificationItem> _watch(PostgresChangeEvent event) {
    final User? user = _supabase.auth.currentUser;
    if (user == null) return const Stream<NotificationItem>.empty();

    final StreamController<NotificationItem> ctrl =
        StreamController<NotificationItem>.broadcast();
    final RealtimeChannel channel = _supabase.client
        .channel('notifications:${user.id}:${event.name}')
        .onPostgresChanges(
          event: event,
          schema: 'public',
          table: 'notifications',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: user.id,
          ),
          callback: (PostgresChangePayload p) {
            if (p.newRecord.isNotEmpty) {
              ctrl.add(NotificationItem.fromJson(p.newRecord));
            }
          },
        );
    channel.subscribe();
    ctrl.onCancel = () async {
      await _supabase.client.removeChannel(channel);
      await ctrl.close();
    };
    return ctrl.stream;
  }
}
