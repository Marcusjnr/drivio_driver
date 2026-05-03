import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:drivio_driver/modules/commons/theme/app_radius.dart';
import 'package:drivio_driver/modules/commons/theme/context_theme.dart';

class OnlineToggle extends ConsumerWidget {
  const OnlineToggle({super.key, required this.online, this.onTap, this.label});

  final bool online;
  final VoidCallback? onTap;
  final String? label;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final String text = label ?? (online ? 'You\'re online' : 'You\'re offline');
    return Material(
      color: context.surface,
      borderRadius: AppRadius.pill,
      child: InkWell(
        borderRadius: AppRadius.pill,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 10, 16, 10),
          decoration: BoxDecoration(
            borderRadius: AppRadius.pill,
            border: Border.all(color: context.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: online ? context.accent : context.textMuted,
                  shape: BoxShape.circle,
                  boxShadow: online
                      ? <BoxShadow>[
                          BoxShadow(
                            color: context.accent.withValues(alpha: 0.4),
                            blurRadius: 0,
                            spreadRadius: 4,
                          ),
                        ]
                      : null,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                text,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: context.text,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
