import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  static const Color bgDark = Color(0xFF0A0B0D);
  static const Color surfaceDark = Color(0xFF111316);
  static const Color surface2Dark = Color(0xFF16191D);
  static const Color surface3Dark = Color(0xFF1C2025);
  static const Color surface4Dark = Color(0xFF23282F);
  static const Color borderDark = Color(0x12FFFFFF);
  static const Color borderStrongDark = Color(0x1FFFFFFF);
  static const Color textDark = Color(0xFFF4F5F7);
  static const Color textDimDark = Color(0xFF9AA0A6);
  static const Color textMutedDark = Color(0xFF686C73);

  static const Color bgLight = Color(0xFFF4F5F7);
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color surface2Light = Color(0xFFF7F8FA);
  static const Color surface3Light = Color(0xFFECEEF2);
  static const Color surface4Light = Color(0xFFE2E5EA);
  static const Color borderLight = Color(0x14000000);
  static const Color borderStrongLight = Color(0x24000000);
  static const Color textLight = Color(0xFF0F1115);
  static const Color textDimLight = Color(0xFF515762);
  static const Color textMutedLight = Color(0xFF878C95);

  static const Color accentDark = Color(0xFF5EE4A8);
  static const Color accentInkDark = Color(0xFF0A2418);
  static const Color accentDimDark = Color(0xFF3BA87A);
  static const Color blueDark = Color(0xFF5B8CFF);
  static const Color blueInkDark = Color(0xFF0A142E);
  static const Color amberDark = Color(0xFFFFB547);
  static const Color amberInkDark = Color(0xFF2A1C00);
  static const Color redDark = Color(0xFFFF5A5F);
  static const Color redInkDark = Color(0xFF2A0708);

  static const Color accentLight = Color(0xFF18B374);
  static const Color accentInkLight = Color(0xFFFFFFFF);
  static const Color accentDimLight = Color(0xFF0B7F52);
  static const Color blueLight = Color(0xFF2A5BFF);
  static const Color blueInkLight = Color(0xFFFFFFFF);
  static const Color amberLight = Color(0xFFD8820E);
  static const Color amberInkLight = Color(0xFFFFFFFF);
  static const Color redLight = Color(0xFFE03B3F);
  static const Color redInkLight = Color(0xFFFFFFFF);

  static const Color mapBgDark = Color(0xFF1A1D21);
  static const Color mapRoadDark = Color(0xFF2A2F36);
  static const Color mapRoadMajorDark = Color(0xFF353B45);
  static const Color mapWaterDark = Color(0xFF152026);
  static const Color mapParkDark = Color(0xFF1A241D);

  static const Color mapBgLight = Color(0xFFE7EBEF);
  static const Color mapRoadLight = Color(0xFFFFFFFF);
  static const Color mapRoadMajorLight = Color(0xFFFFFFFF);
  static const Color mapWaterLight = Color(0xFFCFE0EA);
  static const Color mapParkLight = Color(0xFFD6E7D4);

  static const Color appBackdropDark = Color(0xFF050608);
  static const Color appBackdropLight = Color(0xFFECEFF3);

  static const Color phoneBezel = Color(0xFF1A1D21);

  static Color withAlpha(Color color, double alpha) =>
      color.withValues(alpha: alpha);
}
