import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:drivio_driver/modules/commons/theme/app_radius.dart';
import 'package:drivio_driver/modules/commons/theme/app_shadows.dart';
import 'package:drivio_driver/modules/commons/theme/context_theme.dart';

class BottomSheetCard extends ConsumerWidget {
  const BottomSheetCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(18, 14, 18, 24),
    this.showHandle = true,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final bool showHandle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      decoration: BoxDecoration(
        color: context.surface,
        borderRadius: AppRadius.sheetTop,
        border: Border(top: BorderSide(color: context.border)),
        boxShadow: AppShadows.sheet,
      ),
      child: Padding(
        padding: padding,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (showHandle)
              Container(
                width: 40,
                height: 5,
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(5),
                ),
              ),
            child,
          ],
        ),
      ),
    );
  }
}
