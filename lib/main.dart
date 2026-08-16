import 'dart:async';
import 'dart:ui' show PlatformDispatcher;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show kDebugMode, kReleaseMode;
import 'package:flutter/widgets.dart';

import 'package:drivio_driver/app.dart';
import 'package:drivio_driver/modules/commons/analytics/mixpanel_service.dart';
import 'package:drivio_driver/modules/commons/config/flavor.dart';
import 'package:drivio_driver/modules/commons/di/di.dart';
import 'package:drivio_driver/modules/commons/push/call_push_handler.dart';
import 'package:drivio_driver/modules/commons/push/push_service.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'firebase_options_prod.dart' as prod_firebase;
import 'firebase_options_stage.dart' as stage_firebase;

/// Bare `flutter run` (no --flavor) — dev convenience: staging wiring with
/// the plain `.env` file. Real builds use `main_prod.dart` / `main_stage.dart`.
Future<void> main() => bootstrap(Flavor.staging, envFile: '.env');

/// Shared startup for every flavor target. Keeping this in one place stops
/// the entrypoints drifting apart (the old per-flavor mains had already
/// diverged — prod was missing the Mixpanel init).
Future<void> bootstrap(Flavor flavor, {String? envFile}) async {
  WidgetsFlutterBinding.ensureInitialized();
  await setupServiceLocator(flavor);

  await Firebase.initializeApp(
    options: flavor == Flavor.prod
        ? prod_firebase.DefaultFirebaseOptions.currentPlatform
        : stage_firebase.DefaultFirebaseOptions.currentPlatform,
  );

  // Crashlytics — release/profile builds only. Debug crashes stay in the
  // console where they're actually being watched; each flavor reports
  // into its own Firebase project. Uncaught framework errors and
  // uncaught async errors both count as fatals so crash-free-users
  // stays honest.
  final FirebaseCrashlytics crashlytics = FirebaseCrashlytics.instance;
  await crashlytics.setCrashlyticsCollectionEnabled(!kDebugMode);
  if (!kDebugMode) {
    // Leave debug builds on Flutter's default handlers so errors still
    // land in the console instead of a disabled Crashlytics queue.
    FlutterError.onError = crashlytics.recordFlutterFatalError;
    PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
      crashlytics.recordError(error, stack, fatal: true);
      return true;
    };
  }

  await dotenv.load(fileName: envFile ?? '.env.${flavor.name}');

  // Analytics — prod release builds ONLY. Debug/profile runs and the
  // staging flavor must never send events into the production Mixpanel
  // project. Left uninitialised, MixpanelService no-ops everywhere.
  if (flavor == Flavor.prod && kReleaseMode) {
    await locator<MixpanelService>().init();
  }

  // Push tokens (device_tokens). Fire-and-forget so the iOS permission
  // prompt never blocks startup.
  unawaited(locator<PushService>().init(env: flavor.name));

  // Background/killed incoming-call ring path (FCM data → native call UI),
  // and the bridge that adopts accepted native calls into the app.
  FirebaseMessaging.onBackgroundMessage(callPushBackgroundHandler);
  unawaited(CallPushBridge(App.container).init());

  App.run();
}
