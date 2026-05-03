enum MessageKind {
  text,
  quickReply,
  location,
  system;

  String get wire {
    switch (this) {
      case MessageKind.text:
        return 'text';
      case MessageKind.quickReply:
        return 'quick_reply';
      case MessageKind.location:
        return 'location';
      case MessageKind.system:
        return 'system';
    }
  }

  static MessageKind fromWire(String wire) {
    switch (wire) {
      case 'quick_reply':
        return MessageKind.quickReply;
      case 'location':
        return MessageKind.location;
      case 'system':
        return MessageKind.system;
      case 'text':
      default:
        return MessageKind.text;
    }
  }
}

class Message {
  const Message({
    required this.id,
    required this.tripId,
    required this.senderUserId,
    required this.body,
    required this.kind,
    required this.createdAt,
  });

  final String id;
  final String tripId;
  final String senderUserId;
  final String body;
  final MessageKind kind;
  final DateTime createdAt;

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: json['id'] as String,
      tripId: json['trip_id'] as String,
      senderUserId: json['sender_user_id'] as String,
      body: json['body'] as String,
      kind: MessageKind.fromWire(json['kind'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
