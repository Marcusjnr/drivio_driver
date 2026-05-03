import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:drivio_driver/modules/commons/theme/app_colors.dart';
import 'package:drivio_driver/modules/commons/theme/app_text_styles.dart';

class AppTheme {
  AppTheme._();

  static ThemeData get dark {
    final ColorScheme scheme = const ColorScheme.dark(
      primary: AppColors.accentDark,
      onPrimary: AppColors.accentInkDark,
      secondary: AppColors.blueDark,
      onSecondary: AppColors.blueInkDark,
      surface: AppColors.surfaceDark,
      onSurface: AppColors.textDark,
      surfaceContainer: AppColors.surface2Dark,
      surfaceContainerHigh: AppColors.surface3Dark,
      surfaceContainerHighest: AppColors.surface4Dark,
      outline: AppColors.borderStrongDark,
      outlineVariant: AppColors.borderDark,
      error: AppColors.redDark,
      onError: AppColors.redInkDark,
    );
    return _build(scheme, AppColors.bgDark, Brightness.dark);
  }

  static ThemeData get light {
    final ColorScheme scheme = const ColorScheme.light(
      primary: AppColors.accentLight,
      onPrimary: AppColors.accentInkLight,
      secondary: AppColors.blueLight,
      onSecondary: AppColors.blueInkLight,
      surface: AppColors.surfaceLight,
      onSurface: AppColors.textLight,
      surfaceContainer: AppColors.surface2Light,
      surfaceContainerHigh: AppColors.surface3Light,
      surfaceContainerHighest: AppColors.surface4Light,
      outline: AppColors.borderStrongLight,
      outlineVariant: AppColors.borderLight,
      error: AppColors.redLight,
      onError: AppColors.redInkLight,
    );
    return _build(scheme, AppColors.bgLight, Brightness.light);
  }

  static ThemeData _build(ColorScheme scheme, Color bg, Brightness brightness) {
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: bg,
      fontFamily: AppTextStyles.fontFamily,
      dividerColor: scheme.outlineVariant,
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
      hoverColor: Colors.transparent,
      textTheme: TextTheme(
        displayLarge: AppTextStyles.displayLg.copyWith(color: scheme.onSurface),
        headlineLarge: AppTextStyles.screenTitle.copyWith(color: scheme.onSurface),
        headlineMedium: AppTextStyles.h1.copyWith(color: scheme.onSurface),
        titleLarge: AppTextStyles.h2.copyWith(color: scheme.onSurface),
        titleMedium: AppTextStyles.h3.copyWith(color: scheme.onSurface),
        bodyLarge: AppTextStyles.bodyLg.copyWith(color: scheme.onSurface),
        bodyMedium: AppTextStyles.body.copyWith(color: scheme.onSurface),
        bodySmall: AppTextStyles.bodySm.copyWith(color: scheme.onSurface),
        labelLarge: AppTextStyles.button.copyWith(color: scheme.onSurface),
        labelMedium: AppTextStyles.caption.copyWith(color: scheme.onSurface),
        labelSmall: AppTextStyles.captionSm.copyWith(color: scheme.onSurface),
      ),
    );
  }

  static const SystemUiOverlayStyle darkSystemOverlay = SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    statusBarBrightness: Brightness.dark,
  );

  static const SystemUiOverlayStyle lightSystemOverlay = SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
    statusBarBrightness: Brightness.light,
  );
}
