import 'package:flutter/material.dart';

import 'package:drivio_driver/modules/commons/theme/app_dimensions.dart';

class AppRadius {
  AppRadius._();

  static const BorderRadius sm = BorderRadius.all(Radius.circular(AppDimensions.radiusSm));
  static const BorderRadius md = BorderRadius.all(Radius.circular(AppDimensions.radiusMd));
  static const BorderRadius base = BorderRadius.all(Radius.circular(AppDimensions.radius));
  static const BorderRadius lg = BorderRadius.all(Radius.circular(AppDimensions.radiusLg));
  static const BorderRadius xl = BorderRadius.all(Radius.circular(AppDimensions.radiusXl));
  static const BorderRadius pill = BorderRadius.all(Radius.circular(AppDimensions.radiusPill));

  static const BorderRadius sheetTop = BorderRadius.only(
    topLeft: Radius.circular(AppDimensions.radiusXl),
    topRight: Radius.circular(AppDimensions.radiusXl),
  );
}
