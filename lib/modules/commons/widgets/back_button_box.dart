import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:drivio_driver/modules/commons/navigation/app_navigation.dart';
import 'package:drivio_driver/modules/commons/theme/app_radius.dart';
import 'package:drivio_driver/modules/commons/theme/context_theme.dart';
import 'package:drivio_driver/modules/commons/widgets/icons/drivio_icons.dart';

class BackButtonBox extends ConsumerWidget {
  const BackButtonBox({super.key, this.onTap, this.icon = DrivioIcons.back});

  final VoidCallback? onTap;
  final IconData icon;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Material(
      color: context.surface,
      borderRadius: AppRadius.sm,
      child: InkWell(
        borderRadius: AppRadius.sm,
        onTap: onTap ?? () => AppNavigation.pop(),
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            borderRadius: AppRadius.sm,
            border: Border.all(color: context.border),
          ),
          alignment: Alignment.center,
          child: Icon(icon, size: 14, color: context.text),
        ),
      ),
    );
  }
}
