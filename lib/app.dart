import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:drivio_driver/modules/commons/auth/session_guard.dart';
import 'package:drivio_driver/modules/commons/bootstrap/bootstrap_controller.dart';
import 'package:drivio_driver/modules/commons/di/di.dart';
import 'package:drivio_driver/modules/commons/lifecycle/lifecycle_controller.dart';
import 'package:drivio_driver/modules/commons/navigation/app_navigation.dart';
import 'package:drivio_driver/modules/commons/navigation/app_router.dart';
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
    final BootstrapState bootstrap = ref.watch(bootstrapControllerProvider);

    if (bootstrap.isLoading) {
      return MaterialApp(
        theme: _withInter(AppTheme.dark),
        debugShowCheckedModeBanner: false,
        home: const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    return ScreenUtilInit(
      designSize: const Size(
        AppDimensions.designWidth,
        AppDimensions.designHeight,
      ),
      minTextAdapt: true,
      ensureScreenSize: true,
      builder: (BuildContext _, Widget? __) {
        final BootstrapController bootstrapC =
            ref.read(bootstrapControllerProvider.notifier);
        return MaterialApp(
          title: locator.get<cfg.Config>().title,
          theme: _withInter(AppTheme.light),
          darkTheme: _withInter(AppTheme.dark),
          themeMode: mode,
          debugShowCheckedModeBanner: false,
          navigatorKey: AppNavigation.navigatorKey,
          initialRoute: bootstrapC.initialRoute,
          // Custom initial-route generator so we can pass arguments
          // (notably an activeTripId for cold-start trip resume).
          onGenerateInitialRoutes: (String initial) {
            return <Route<dynamic>>[
              AppRouter.onGenerateRoute(
                RouteSettings(
                  name: initial,
                  arguments: bootstrapC.initialArguments,
                ),
              ),
            ];
          },
          onGenerateRoute: AppRouter.onGenerateRoute,
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
