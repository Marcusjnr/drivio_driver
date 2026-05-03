import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:drivio_driver/modules/commons/theme/app_gradients.dart';

class Avatar extends ConsumerWidget {
  const Avatar({
    super.key,
    required this.name,
    this.variant = 0,
    this.size = 40,
  });

  final String name;
  final int variant;
  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<String> parts = name.trim().split(RegExp(r'\s+'));
    final String initials = parts
        .take(2)
        .map((String p) => p.isEmpty ? '' : p[0].toUpperCase())
        .join();
    final LinearGradient g =
        AppGradients.avatars[variant % AppGradients.avatars.length];
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: g,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
          fontSize: size * 0.38,
        ),
      ),
    );
  }
}
