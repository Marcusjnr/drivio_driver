import 'package:drivio_driver/modules/commons/config/env.dart';
import 'package:drivio_driver/modules/commons/config/flavor.dart';

class Config {
  Config(this.flavor);

  final Flavor flavor;

  String get title {
    switch (flavor) {
      case Flavor.prod:
        return 'Drivio Driver';
      case Flavor.staging:
        return 'Drivio Driver Beta';
    }
  }

  String get supabaseUrl => Env.supabaseUrl;
  String get supabaseAnonKey => Env.supabaseAnonKey;

  bool get isStaging => flavor == Flavor.staging;
}
