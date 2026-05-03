import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:drivio_driver/modules/commons/theme/app_radius.dart';
import 'package:drivio_driver/modules/commons/theme/context_theme.dart';

enum PillTone { neutral, accent, blue, amber, red }

class Pill extends ConsumerWidget {
  const Pill({
    super.key,
    required this.text,
    this.tone = PillTone.neutral,
    this.icon,
  });

  final String text;
  final PillTone tone;
  final IconData? icon;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final _ToneColors c = _toneColors(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: c.bg,
        borderRadius: AppRadius.pill,
        border: Border.all(color: c.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (icon != null) ...<Widget>[
            Icon(icon, size: 12, color: c.fg),
            const SizedBox(width: 4),
          ],
          Text(
            text,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: c.fg,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }

  _ToneColors _toneColors(BuildContext context) {
    switch (tone) {
      case PillTone.neutral:
        return _ToneColors(bg: context.surface3, fg: context.textDim, border: context.border);
      case PillTone.accent:
        return _ToneColors(
          bg: context.accent.withValues(alpha: 0.18),
          fg: context.accent,
          border: context.accent.withValues(alpha: 0.3),
        );
      case PillTone.blue:
        return _ToneColors(
          bg: context.blue.withValues(alpha: 0.16),
          fg: context.blue,
          border: context.blue.withValues(alpha: 0.3),
        );
      case PillTone.amber:
        return _ToneColors(
          bg: context.amber.withValues(alpha: 0.16),
          fg: context.amber,
          border: context.amber.withValues(alpha: 0.3),
        );
      case PillTone.red:
        return _ToneColors(
          bg: context.red.withValues(alpha: 0.16),
          fg: context.red,
          border: context.red.withValues(alpha: 0.3),
        );
    }
  }
}

class _ToneColors {
  _ToneColors({required this.bg, required this.fg, required this.border});
  final Color bg;
  final Color fg;
  final Color border;
}
