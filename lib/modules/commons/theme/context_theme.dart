import 'package:flutter/material.dart';

import 'package:drivio_driver/modules/commons/theme/app_colors.dart';

/// Read brand colors via `context.<token>`.
///
/// The legacy names (`accent`, `blue`, `amber`) and the explicit
/// brand names (`coral`, `teal`, `butter`) coexist on purpose —
/// existing widgets keep compiling against the legacy names, and new
/// brand-aware widgets can spell coral/teal/butter directly.
extension DrivioColors on BuildContext {
  bool get isDark => Theme.of(this).brightness == Brightness.dark;

  // ── Foundation ──────────────────────────────────────────────────────
  Color get bg => isDark ? AppColors.bgDark : AppColors.bgLight;
  Color get surface => isDark ? AppColors.surfaceDark : AppColors.surfaceLight;
  Color get surface2 =>
      isDark ? AppColors.surface2Dark : AppColors.surface2Light;
  Color get surface3 =>
      isDark ? AppColors.surface3Dark : AppColors.surface3Light;
  Color get surface4 =>
      isDark ? AppColors.surface4Dark : AppColors.surface4Light;

  Color get border => isDark ? AppColors.borderDark : AppColors.borderLight;
  Color get borderStrong =>
      isDark ? AppColors.borderStrongDark : AppColors.borderStrongLight;

  Color get text => isDark ? AppColors.textDark : AppColors.textLight;
  Color get textDim => isDark ? AppColors.textDimDark : AppColors.textDimLight;
  Color get textMuted =>
      isDark ? AppColors.textMutedDark : AppColors.textMutedLight;

  // ── Coastal Pulse — brand colors, explicit names ────────────────────
  /// Hero / motion / live state. Pickup pin. Primary CTA fill.
  Color get coral => AppColors.coral;
  Color get coralInk => AppColors.coralInk;

  /// Depth / drop-off / quiet supporting accent.
  Color get teal => AppColors.teal;
  Color get tealInk => AppColors.tealInk;

  /// Sparing accent — peak hour, "new", micro-callouts.
  Color get butter => AppColors.butter;
  Color get butterInk => AppColors.butterInk;

  /// The brand anchor — light-mode text + dark-mode background.
  Color get charcoalTeal => AppColors.charcoalTeal;

  /// Breathing space — light-mode bg + ink on coral/charcoal-teal.
  Color get ivory => AppColors.ivory;

  // ── Legacy aliases — keep code that reads `context.accent` working ──
  Color get accent => isDark ? AppColors.accentDark : AppColors.accentLight;
  Color get accentInk =>
      isDark ? AppColors.accentInkDark : AppColors.accentInkLight;
  Color get accentDim =>
      isDark ? AppColors.accentDimDark : AppColors.accentDimLight;
  Color get blue => isDark ? AppColors.blueDark : AppColors.blueLight;
  Color get blueInk => isDark ? AppColors.blueInkDark : AppColors.blueInkLight;
  Color get amber => isDark ? AppColors.amberDark : AppColors.amberLight;
  Color get amberInk =>
      isDark ? AppColors.amberInkDark : AppColors.amberInkLight;
  Color get red => isDark ? AppColors.redDark : AppColors.redLight;
  Color get redInk => isDark ? AppColors.redInkDark : AppColors.redInkLight;
  Color get success =>
      isDark ? AppColors.successDark : AppColors.successLight;

  // ── Map palette ─────────────────────────────────────────────────────
  Color get mapBg => isDark ? AppColors.mapBgDark : AppColors.mapBgLight;
  Color get mapRoad => isDark ? AppColors.mapRoadDark : AppColors.mapRoadLight;
  Color get mapRoadMajor =>
      isDark ? AppColors.mapRoadMajorDark : AppColors.mapRoadMajorLight;
  Color get mapWater =>
      isDark ? AppColors.mapWaterDark : AppColors.mapWaterLight;
  Color get mapPark => isDark ? AppColors.mapParkDark : AppColors.mapParkLight;

  Color get appBackdrop =>
      isDark ? AppColors.appBackdropDark : AppColors.appBackdropLight;
}
