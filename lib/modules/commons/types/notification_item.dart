/// Wire format on `notifications.category`. Untyped strings to stay
/// forward-compatible with categories the server may add later.
class NotificationItem {
  const NotificationItem({
    required this.id,
    required this.userId,
    required this.category,
    required this.title,
    required this.createdAt,
    this.body,
    this.data = const <String, dynamic>{},
    this.readAt,
  });

  final String id;
  final String userId;
  final String category;
  final String title;
  final String? body;
  final Map<String, dynamic> data;
  final DateTime? readAt;
  final DateTime createdAt;

  bool get isUnread => readAt == null;

  factory NotificationItem.fromJson(Map<String, dynamic> json) {
    return NotificationItem(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      category: json['category'] as String,
      title: json['title'] as String,
      body: json['body'] as String?,
      data: (json['data'] as Map?)?.cast<String, dynamic>() ??
          const <String, dynamic>{},
      readAt: json['read_at'] == null
          ? null
          : DateTime.parse(json['read_at'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
