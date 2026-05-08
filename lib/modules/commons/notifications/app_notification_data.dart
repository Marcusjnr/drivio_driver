import 'package:flutter/foundation.dart';

enum AppNotificationType { success, error, warning, info, neutral }

@immutable
class AppNotificationData {
  const AppNotificationData({
    required this.message,
    required this.type,
    this.title,
    this.duration = const Duration(seconds: 4),
  });

  final String message;
  final String? title;
  final AppNotificationType type;
  final Duration duration;
}
