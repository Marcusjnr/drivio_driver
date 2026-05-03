import 'dart:async';

import 'package:drivio_driver/modules/commons/types/notification_item.dart';

abstract class NotificationRepository {
  Future<List<NotificationItem>> listMine({int limit = 50});
  Future<int> unreadCount();
  Future<void> markRead(String id);
  Future<void> markAllRead();
  Stream<NotificationItem> watchInserts();
  Stream<NotificationItem> watchUpdates();
}
