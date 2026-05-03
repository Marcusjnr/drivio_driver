import 'package:drivio_driver/modules/commons/config/env.dart';
import 'package:drivio_driver/modules/commons/config/flavor.dart';

class Config {
  Config(this.flavor);

  final Flavor flavor;

  String get title {
    switch (flavor) {
      case Flavor.prod:
        return 'Drivio Driver';
      case Flavor.stage:
        return 'Drivio Driver · Stage';
    }
  }

  String get supabaseUrl => Env.supabaseUrl;
  String get supabaseAnonKey => Env.supabaseAnonKey;

  bool get isStage => flavor == Flavor.stage;
}
