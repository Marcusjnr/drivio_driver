import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:drivio_driver/modules/commons/theme/context_theme.dart';
import 'package:drivio_driver/modules/commons/widgets/icons/drivio_icons.dart';

class Rating extends ConsumerWidget {
  const Rating({super.key, required this.value});

  final double value;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(DrivioIcons.star, size: 13, color: context.amber),
        const SizedBox(width: 3),
        Text(
          value.toStringAsFixed(2),
          style: TextStyle(
            color: context.text,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
