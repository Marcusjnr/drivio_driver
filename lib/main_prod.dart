import 'package:drivio_driver/main.dart';
import 'package:drivio_driver/modules/commons/config/flavor.dart';

/// Production entrypoint: `flutter run --flavor prod -t lib/main_prod.dart`.
Future<void> main() => bootstrap(Flavor.prod);
