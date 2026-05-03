import 'package:flutter/widgets.dart';

import 'package:drivio_driver/modules/commons/di/di.dart';
import 'package:drivio_driver/modules/commons/supabase/supabase_module.dart';

class LifecycleController with WidgetsBindingObserver {
  LifecycleController() {
    WidgetsBinding.instance.addObserver(this);
  }

  final SupabaseModule _supabase = locator<SupabaseModule>();
  DateTime? _lastPausedAt;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
        _onPaused();
        break;
      case AppLifecycleState.resumed:
        _onResumed();
        break;
      default:
        break;
    }
  }

  void _onPaused() {
    _lastPausedAt = DateTime.now();
  }

  void _onResumed() {
    final DateTime? pausedAt = _lastPausedAt;
    _lastPausedAt = null;

    if (pausedAt == null) return;

    final Duration elapsed = DateTime.now().difference(pausedAt);

    // If backgrounded for more than 30 seconds, refresh session
    if (elapsed.inSeconds > 30) {
      _refreshSession();
    }
  }

  Future<void> _refreshSession() async {
    try {
      await _supabase.auth.refreshSession();
    } catch (_) {
      // SessionGuard handles signedOut/tokenRefreshFailed events
    }
  }

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
  }
}
