enum Flavor { prod, stage }

extension FlavorName on Flavor {
  String get name {
    switch (this) {
      case Flavor.prod:
        return 'prod';
      case Flavor.stage:
        return 'stage';
    }
  }
}
