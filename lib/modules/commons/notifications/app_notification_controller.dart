import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:drivio_driver/modules/commons/notifications/app_notification_data.dart';

/// The single source of truth for the active in-app notification.
///
/// One instance is created at app boot, attached to [AppNotifier], and
/// listened to by [AppNotificationHost]. New `show*` calls REPLACE any
/// currently-displayed notification (no queue) — same behaviour as
/// Kalabash. Auto-dismisses after [AppNotificationData.duration].
class AppNotificationController {
  AppNotificationController();

  final ValueNotifier<AppNotificationData?> current =
      ValueNotifier<AppNotificationData?>(null);

  Timer? _autoDismiss;

  void show(AppNotificationData data) {
    _autoDismiss?.cancel();
    current.value = data;
    _autoDismiss = Timer(data.duration, hide);
  }

  void hide() {
    _autoDismiss?.cancel();
    _autoDismiss = null;
    current.value = null;
  }

  void dispose() {
    _autoDismiss?.cancel();
    current.dispose();
  }
}
