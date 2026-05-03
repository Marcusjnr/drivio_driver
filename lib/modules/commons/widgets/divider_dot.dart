import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:drivio_driver/modules/commons/theme/context_theme.dart';

class DividerDot extends ConsumerWidget {
  const DividerDot({super.key, this.size = 3});

  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: context.textMuted,
        shape: BoxShape.circle,
      ),
    );
  }
}
