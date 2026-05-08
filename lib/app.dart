import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:drivio_driver/modules/commons/auth/session_guard.dart';
import 'package:drivio_driver/modules/commons/di/di.dart';
import 'package:drivio_driver/modules/commons/lifecycle/lifecycle_controller.dart';
import 'package:drivio_driver/modules/commons/navigation/app_navigation.dart';
import 'package:drivio_driver/modules/commons/navigation/app_router.dart';
import 'package:drivio_driver/modules/commons/navigation/app_routes.dart';
import 'package:drivio_driver/modules/commons/notifications/app_notification_host.dart';
import 'package:drivio_driver/modules/commons/notifications/app_notifier.dart';
import 'package:drivio_driver/modules/commons/theme/app_dimensions.dart';
import 'package:drivio_driver/modules/commons/theme/app_theme.dart';
import 'package:drivio_driver/modules/commons/theme/logic/theme_mode_controller.dart';
import 'package:drivio_driver/modules/commons/config/config.dart' as cfg;

class App extends ConsumerStatefulWidget {
  const App({super.key});

  static void run() => runApp(const ProviderScope(child: App()));

  @override
  ConsumerState<App> createState() => _AppState();
}

class _AppState extends ConsumerState<App> {
  late final LifecycleController _lifecycle;
  late final SessionGuard _sessionGuard;

  @override
  void initState() {
    super.initState();
    _lifecycle = LifecycleController();
    _sessionGuard = SessionGuard();
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    _sessionGuard.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeMode mode = ref.watch(themeModeProvider);

    // The splash page is ALWAYS the first thing rendered. It owns the
    // brand reveal, the location-permission ask, AND the wait for
    // bootstrap to resolve auth/active-trip state. Once everything's
    // ready it pushReplacements to the bootstrap-resolved destination.
    return ScreenUtilInit(
      designSize: const Size(
        AppDimensions.designWidth,
        AppDimensions.designHeight,
      ),
      minTextAdapt: true,
      ensureScreenSize: true,
      builder: (BuildContext _, Widget? __) {
        return MaterialApp(
          title: locator.get<cfg.Config>().title,
          theme: _withInter(AppTheme.light),
          darkTheme: _withInter(AppTheme.dark),
          themeMode: mode,
          debugShowCheckedModeBanner: false,
          navigatorKey: AppNavigation.navigatorKey,
          initialRoute: AppRoutes.splash,
          onGenerateRoute: AppRouter.onGenerateRoute,
          builder: (BuildContext context, Widget? child) {
            return AppNotificationHost(
              controller: AppNotifier.controller,
              child: child ?? const SizedBox.shrink(),
            );
          },
        );
      },
    );
  }

  ThemeData _withInter(ThemeData base) {
    return base.copyWith(
      textTheme: GoogleFonts.interTextTheme(base.textTheme),
    );
  }
}
