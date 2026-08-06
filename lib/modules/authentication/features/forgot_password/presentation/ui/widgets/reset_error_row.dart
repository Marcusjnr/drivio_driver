import 'package:flutter/material.dart';

import 'package:drivio_driver/modules/commons/all.dart';

/// Inline error banner for the reset screens. Same shape as the one on
/// sign in, kept here so the reset flow does not reach into another
/// feature's private widgets.
class ResetErrorRow extends StatelessWidget {
  const ResetErrorRow({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: context.red.withValues(alpha: 0.10),
        borderRadius: AppRadius.md,
        border: Border.all(color: context.red.withValues(alpha: 0.30)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(Icons.error_outline_rounded, size: 16, color: context.red),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: AppTextStyles.bodySm.copyWith(
                color: context.red,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
