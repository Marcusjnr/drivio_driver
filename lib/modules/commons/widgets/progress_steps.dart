import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:drivio_driver/modules/commons/theme/context_theme.dart';

class ProgressSteps extends ConsumerWidget {
  const ProgressSteps({
    super.key,
    required this.total,
    required this.completed,
  });

  final int total;
  final int completed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      children: List<Widget>.generate(total, (int i) {
        final bool active = i < completed;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: i == total - 1 ? 0 : 3),
            child: Container(
              height: 3,
              decoration: BoxDecoration(
                color: active ? context.accent : context.surface3,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        );
      }),
    );
  }
}
