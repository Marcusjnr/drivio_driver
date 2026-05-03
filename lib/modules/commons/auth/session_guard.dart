import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:drivio_driver/modules/commons/di/di.dart';
import 'package:drivio_driver/modules/commons/navigation/app_navigation.dart';
import 'package:drivio_driver/modules/commons/navigation/app_routes.dart';
import 'package:drivio_driver/modules/commons/supabase/supabase_module.dart';

class SessionGuard {
  SessionGuard() {
    _subscription = locator<SupabaseModule>().auth.onAuthStateChange.listen(
      _onAuthStateChange,
    );
  }

  StreamSubscription<AuthState>? _subscription;

  void _onAuthStateChange(AuthState data) {
    switch (data.event) {
      case AuthChangeEvent.signedOut:
      case AuthChangeEvent.tokenRefreshed when data.session == null:
        AppNavigation.replaceAll<void>(AppRoutes.welcome);
        break;
      default:
        break;
    }
  }

  void dispose() {
    _subscription?.cancel();
    _subscription = null;
  }
}
