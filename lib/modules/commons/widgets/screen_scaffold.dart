import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:drivio_driver/modules/commons/theme/app_theme.dart';
import 'package:drivio_driver/modules/commons/theme/context_theme.dart';

class ScreenScaffold extends ConsumerWidget {
  const ScreenScaffold({
    super.key,
    required this.child,
    this.background,
    this.bottomBar,
    this.extendBody = false,
  });

  final Widget child;
  final Color? background;
  final Widget? bottomBar;
  final bool extendBody;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: context.isDark
          ? AppTheme.darkSystemOverlay
          : AppTheme.lightSystemOverlay,
      child: Scaffold(
        backgroundColor: background ?? context.bg,
        extendBody: extendBody,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: <Widget>[
              Expanded(child: child),
              if (bottomBar != null) bottomBar!,
            ],
          ),
        ),
      ),
    );
  }
}
