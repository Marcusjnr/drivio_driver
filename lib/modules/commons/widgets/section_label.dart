import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:drivio_driver/modules/commons/theme/app_text_styles.dart';
import 'package:drivio_driver/modules/commons/theme/context_theme.dart';

class SectionLabel extends ConsumerWidget {
  const SectionLabel({super.key, required this.text, this.right});

  final String text;
  final Widget? right;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: <Widget>[
        Text(
          text.toUpperCase(),
          style: AppTextStyles.eyebrow.copyWith(color: context.textDim),
        ),
        if (right != null) right!,
      ],
    );
  }
}
