import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
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

  await dotenv.load(fileName: envFile ?? '.env.${flavor.name}');

  // Analytics. No-op until a real MIXPANEL_TOKEN is set in the env file.
  await locator<MixpanelService>().init();

  // Push tokens (device_tokens). Fire-and-forget so the iOS permission
  // prompt never blocks startup.
  unawaited(locator<PushService>().init(env: flavor.name));

  // Background/killed incoming-call ring path (FCM data → native call UI),
  // and the bridge that adopts accepted native calls into the app.
  FirebaseMessaging.onBackgroundMessage(callPushBackgroundHandler);
  unawaited(CallPushBridge(App.container).init());

  App.run();
}
