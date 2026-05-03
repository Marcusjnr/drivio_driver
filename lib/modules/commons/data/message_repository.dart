import 'dart:async';

import 'package:drivio_driver/modules/commons/types/message.dart';

abstract class MessageRepository {
  /// All messages on a trip, oldest first (chat-bubble order).
  Future<List<Message>> listForTrip(String tripId);

  /// Send a message as the calling driver. Returns the persisted row.
  Future<Message> send({
    required String tripId,
    required String body,
    MessageKind kind = MessageKind.text,
  });

  /// Realtime stream of new messages for a trip. Only new inserts are
  /// emitted; the caller hydrates the initial list via [listForTrip].
  Stream<Message> watchForTrip(String tripId);
}
