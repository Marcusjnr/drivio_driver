import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:drivio_driver/modules/commons/theme/context_theme.dart';

class IconCircleButton extends ConsumerWidget {
  const IconCircleButton({
    super.key,
    required this.icon,
    this.onTap,
    this.size = 40,
    this.bg,
    this.fg,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final double size;
  final Color? bg;
  final Color? fg;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final Color background = bg ?? context.surface;
    final Color foreground = fg ?? context.text;
    return Material(
      color: background,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: context.border),
          ),
          alignment: Alignment.center,
          child: Icon(icon, size: size * 0.45, color: foreground),
        ),
      ),
    );
  }
}
