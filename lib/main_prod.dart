import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/widgets.dart';

import 'package:drivio_driver/app.dart';
import 'package:drivio_driver/modules/commons/config/flavor.dart';
import 'package:drivio_driver/modules/commons/di/di.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'firebase_options_stage.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await setupServiceLocator(Flavor.prod);

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  await dotenv.load(fileName: '.env');

  App.run();
}
