import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class DrivioSafeArea extends ConsumerWidget {
  const DrivioSafeArea({
    super.key,
    required this.child,
    this.top = true,
    this.bottom = true,
    this.padding,
  });

  final Widget child;
  final bool top;
  final bool bottom;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SafeArea(
      top: top,
      bottom: bottom,
      child: padding == null ? child : Padding(padding: padding!, child: child),
    );
  }
}
