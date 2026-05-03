import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:drivio_driver/modules/commons/theme/app_shadows.dart';
import 'package:drivio_driver/modules/commons/theme/context_theme.dart';

class BrandMark extends ConsumerWidget {
  const BrandMark({super.key, this.size = 28});

  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final double inner = size * 0.45;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: context.accent,
        borderRadius: BorderRadius.circular(size * 0.28),
        boxShadow: AppShadows.brandMark,
      ),
      alignment: Alignment.center,
      child: Transform.rotate(
        angle: -0.785,
        child: Container(
          width: inner,
          height: inner,
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(color: context.accentInk, width: size * 0.1),
              bottom: BorderSide(color: context.accentInk, width: size * 0.1),
            ),
            borderRadius: BorderRadius.circular(size * 0.08),
          ),
        ),
      ),
    );
  }
}
