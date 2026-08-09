import 'package:flutter/foundation.dart';

enum AppNotificationType { success, error, warning, info, neutral }

@immutable
class AppNotificationData {
  const AppNotificationData({
    required this.message,
    required this.type,
    this.title,
    this.duration = const Duration(seconds: 4),
    this.actionLabel,
    this.onAction,
  });

  final String message;
  final String? title;
  final AppNotificationType type;
  final Duration duration;

  /// Optional inline action (e.g. "Update"). Rendered as a small button
  /// under the message; tapping it dismisses the banner then runs
  /// [onAction]. Both must be provided for the button to show.
  final String? actionLabel;
  final VoidCallback? onAction;

  bool get hasAction =>
      actionLabel != null && actionLabel!.trim().isNotEmpty && onAction != null;
}
