import 'package:drivio_driver/modules/commons/errors/error_messages.dart';
import 'package:drivio_driver/modules/commons/logging/app_logger.dart';
import 'package:drivio_driver/modules/commons/notifications/app_notification_controller.dart';
import 'package:drivio_driver/modules/commons/notifications/app_notification_data.dart';

/// Static façade for surfacing in-app notifications from anywhere —
/// controllers, repositories, lifecycle hooks. No `BuildContext`
/// required.
///
/// Use the four semantic helpers:
///   AppNotifier.error(message: 'Could not save changes.');
///   AppNotifier.success(message: 'Vehicle added.');
///   AppNotifier.warning(message: 'Driver signal weak.');
///   AppNotifier.info(message: 'Searching for nearby trips…');
///
/// Or hand any thrown error to [AppNotifier.fromError] — it runs the
/// error through [humaniseError], shows the resulting friendly string
/// as an error notification, logs the raw via AppLogger, and returns
/// the shown string so callers can also write it into `state.error`
/// for inline display.
class AppNotifier {
  AppNotifier._();

  static final AppNotificationController controller =
      AppNotificationController();

  static void success({
    required String message,
    String? title,
    Duration? duration,
  }) =>
      _show(AppNotificationType.success, message, title, duration);

  static void error({
    required String message,
    String? title,
    Duration? duration,
  }) =>
      _show(AppNotificationType.error, message, title, duration);

  static void warning({
    required String message,
    String? title,
    Duration? duration,
  }) =>
      _show(AppNotificationType.warning, message, title, duration);

  static void info({
    required String message,
    String? title,
    Duration? duration,
  }) =>
      _show(AppNotificationType.info, message, title, duration);

  static void neutral({
    required String message,
    String? title,
    Duration? duration,
  }) =>
      _show(AppNotificationType.neutral, message, title, duration);

  static void hide() => controller.hide();

  /// Translate any thrown [cause] to a friendly string, log it, surface
  /// it as an error banner, and return the string actually shown.
  static String fromError(
    Object? cause, {
    String? fallback,
    String? title,
    StackTrace? stackTrace,
    String? logContext,
  }) {
    final String message = humaniseError(cause, fallback: fallback);
    AppLogger.e(
      logContext ?? 'Surfaced error to user',
      data: <String, dynamic>{
        'shown': message,
        'raw': cause?.toString() ?? 'null',
      },
      error: cause,
      stackTrace: stackTrace,
    );
    error(message: message, title: title);
    return message;
  }

  static void _show(
    AppNotificationType type,
    String message,
    String? title,
    Duration? duration,
  ) {
    if (message.trim().isEmpty) return;
    controller.show(
      AppNotificationData(
        message: message,
        title: title,
        type: type,
        duration: duration ?? const Duration(seconds: 4),
      ),
    );
  }
}
