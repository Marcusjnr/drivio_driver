import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:drivio_driver/modules/commons/theme/context_theme.dart';
import 'package:drivio_driver/modules/commons/widgets/icons/drivio_icons.dart';

class FieldRow extends ConsumerWidget {
  const FieldRow({
    super.key,
    required this.label,
    this.value,
    this.icon,
    this.iconColor,
    this.right,
    this.chevron = true,
    this.onTap,
    this.divider = true,
  });

  final String label;
  final String? value;
  final IconData? icon;
  final Color? iconColor;
  final Widget? right;
  final bool chevron;
  final VoidCallback? onTap;
  final bool divider;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          border: divider
              ? Border(bottom: BorderSide(color: context.border))
              : null,
        ),
        child: Row(
          children: <Widget>[
            if (icon != null) ...<Widget>[
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: (iconColor ?? context.accent).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Icon(icon, size: 18, color: iconColor ?? context.accent),
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 15,
                      color: context.text,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (value != null && value!.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 2),
                    Text(
                      value!,
                      style: TextStyle(
                        fontSize: 13,
                        color: context.textDim,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (right != null) right!,
            if (chevron && right == null) ...<Widget>[
              const SizedBox(width: 6),
              Icon(DrivioIcons.chevron, size: 16, color: context.textMuted),
            ],
          ],
        ),
      ),
    );
  }
}
