import 'package:drivio_driver/main.dart';
import 'package:drivio_driver/modules/commons/config/flavor.dart';

/// Staging (Beta) entrypoint:
/// `flutter run --flavor staging -t lib/main_stage.dart`.
Future<void> main() => bootstrap(Flavor.staging);
