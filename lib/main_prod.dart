import 'package:flutter/widgets.dart';

import 'package:drivio_driver/app.dart';
import 'package:drivio_driver/modules/commons/config/flavor.dart';
import 'package:drivio_driver/modules/commons/di/di.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await setupServiceLocator(Flavor.prod);

  await dotenv.load(fileName: '.env');

  App.run();
}
