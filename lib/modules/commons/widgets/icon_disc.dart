import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:drivio_driver/modules/commons/theme/context_theme.dart';

/// Tone of an [IconDisc]. Each tone resolves to a `(tint, foreground)`
/// colour pair from the design system. Tints land at ~14% alpha — the
/// canonical fill weight for the affordance across error notifications,
/// KYC rows, paywall benefits, OTP phone-cards, and edge-state heroes.
///
/// Stick to these tones rather than passing custom colours — that's what
/// keeps the icon-disc affordance recognisable system-wide.
enum IconDiscTone {
  accent,
  blue,
  amber,
  red,
  /// Surface-coloured disc for "neutral / waiting / quiet" states. Tint
  /// is `surface2`; foreground is `textDim`. Used by the no-requests
  /// edge state, no-active-request fallbacks, and similar.
  neutral,
}

/// Shape of the disc background.
enum IconDiscShape { circle, square }

/// The Drivio icon-disc — a tinted square or circle with a Material
/// icon centered. Used as the visual anchor for status, error, success,
/// and feature-callout cards across both apps.
///
/// Sizes are anchored to the design system's affordance scale:
///  * **xs (28)** — inline status pills (rare; usually use `Pill` instead)
///  * **sm (32)** — KYC step rows, document-upload tiles, in-card icons
///  * **md (44)** — empty-state callouts, banner heroes
///  * **lg (56)** — section heroes inside bottom sheets
///  * **xl (72)** — full-screen edge-state heroes (offline, expired)
///
/// Use [IconDiscShape.circle] for "person/place/thing" semantics
/// (someone/something) and [IconDiscShape.square] for "feature/state"
/// semantics (an action, a category, an event).
class IconDisc extends ConsumerWidget {
  const IconDisc({
    super.key,
    required this.icon,
    this.tone = IconDiscTone.accent,
    this.size = IconDiscSize.md,
    this.shape = IconDiscShape.square,
    this.bordered = false,
  });

  final IconData icon;
  final IconDiscTone tone;
  final IconDiscSize size;
  final IconDiscShape shape;

  /// Adds a 1px border at the same tint as the fill at ~32% alpha.
  /// Use on full-screen edge-state heroes (xl) to give them weight.
  final bool bordered;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final _ToneColors c = _toneColors(context, tone);
    final double box = _box(size);
    final double iconSize = _iconSize(size);
    final double radius = _cornerRadius(size, shape);
    return Container(
      width: box,
      height: box,
      decoration: BoxDecoration(
        color: c.tint,
        borderRadius:
            shape == IconDiscShape.circle ? null : BorderRadius.circular(radius),
        shape: shape == IconDiscShape.circle ? BoxShape.circle : BoxShape.rectangle,
        border: bordered
            ? Border.all(color: c.fg.withValues(alpha: 0.32), width: 1)
            : null,
      ),
      alignment: Alignment.center,
      child: Icon(icon, size: iconSize, color: c.fg),
    );
  }
}

/// Sizing scale for [IconDisc].
enum IconDiscSize { xs, sm, md, lg, xl }

double _box(IconDiscSize s) {
  switch (s) {
    case IconDiscSize.xs:
      return 28;
    case IconDiscSize.sm:
      return 32;
    case IconDiscSize.md:
      return 44;
    case IconDiscSize.lg:
      return 56;
    case IconDiscSize.xl:
      return 72;
  }
}

double _iconSize(IconDiscSize s) {
  switch (s) {
    case IconDiscSize.xs:
      return 14;
    case IconDiscSize.sm:
      return 16;
    case IconDiscSize.md:
      return 22;
    case IconDiscSize.lg:
      return 28;
    case IconDiscSize.xl:
      return 32;
  }
}

double _cornerRadius(IconDiscSize s, IconDiscShape shape) {
  if (shape == IconDiscShape.circle) return 0; // unused for circles
  switch (s) {
    case IconDiscSize.xs:
    case IconDiscSize.sm:
      return 8;
    case IconDiscSize.md:
      return 12;
    case IconDiscSize.lg:
      return 14;
    case IconDiscSize.xl:
      return 20;
  }
}

class _ToneColors {
  const _ToneColors({required this.tint, required this.fg});
  final Color tint;
  final Color fg;
}

_ToneColors _toneColors(BuildContext context, IconDiscTone tone) {
  switch (tone) {
    case IconDiscTone.accent:
      return _ToneColors(
        tint: context.accent.withValues(alpha: 0.14),
        fg: context.accent,
      );
    case IconDiscTone.blue:
      return _ToneColors(
        tint: context.blue.withValues(alpha: 0.14),
        fg: context.blue,
      );
    case IconDiscTone.amber:
      return _ToneColors(
        tint: context.amber.withValues(alpha: 0.14),
        fg: context.amber,
      );
    case IconDiscTone.red:
      return _ToneColors(
        tint: context.red.withValues(alpha: 0.14),
        fg: context.red,
      );
    case IconDiscTone.neutral:
      return _ToneColors(
        tint: context.surface2,
        fg: context.textDim,
      );
  }
}
