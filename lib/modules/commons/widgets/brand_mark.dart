import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:drivio_driver/modules/commons/theme/app_text_styles.dart';
import 'package:drivio_driver/modules/commons/theme/context_theme.dart';

/// The Drivio wordmark — **"Drivio"** in Marcellus + a coral dot accent
/// after the "o", per brand spec §5.2.
///
/// The dot is the period-as-mark; it visually anchors the wordmark and
/// reads as "arrival, the destination." Size of the dot is ~14% of the
/// cap-height of "D", baseline-aligned with a small bottom offset.
///
/// Variations per surface (auto via theme):
///   - Light: wordmark in charcoal-teal, dot in coral
///   - Dark:  wordmark in ivory, dot in coral
///   - On coral hero surfaces: pass `inkOnCoral: true` to flip
///     (wordmark in ivory, dot in charcoal-teal)
///
/// The standalone mark direction (Sealed D / Pin / Dot-Period) is
/// deferred per spec §10 — until then this wordmark IS the brand mark.
class BrandMark extends ConsumerWidget {
  const BrandMark({
    super.key,
    this.size = 22,
    this.inkOnCoral = false,
  });

  /// Font size of the "Drivio" wordmark, in logical pixels. Defaults
  /// to 22pt — the top-bar size from SCR-002. Splash uses 96–120pt.
  final double size;

  /// Set true when the wordmark sits on a coral hero surface so the
  /// dot flips to charcoal-teal and the letters become ivory.
  final bool inkOnCoral;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final Color letters = inkOnCoral ? context.ivory : context.text;
    final Color dot = inkOnCoral ? context.charcoalTeal : context.coral;

    // Dot diameter ≈ 14% of cap-height. For Marcellus the cap-height is
    // ~0.7 of em, so ~0.10 * size lands close to spec.
    final double dotSize = size * 0.13;
    final double dotPadding = size * 0.06;

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: <Widget>[
        Text(
          'Drivio',
          style: AppTextStyles.h1.copyWith(
            fontSize: size,
            color: letters,
            // Tighter than default Marcellus per spec §5.2.
            letterSpacing: -size * 0.004,
            height: 1.0,
          ),
        ),
        // Baseline-aligned dot. The Padding on `bottom` lifts it onto
        // the typographic baseline (Marcellus descenders are minimal,
        // so a small offset reads correctly).
        Padding(
          padding: EdgeInsets.only(left: dotPadding, bottom: size * 0.06),
          child: Container(
            width: dotSize,
            height: dotSize,
            decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
          ),
        ),
      ],
    );
  }
}
