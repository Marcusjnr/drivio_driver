import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:drivio_driver/modules/commons/all.dart';
import 'package:drivio_driver/modules/commons/types/subscription.dart';

/// One of the three tier cards on the Pick a Plan screen (and on the
/// Confirm Tier Switch sheet's comparison row).
///
/// Visual logic — exhausted here so the page can compose without thinking:
///
///   default        — hairline border, surface fill, ivory text.
///   recommended    — coral 1.5px border, tiny "RECOMMENDED" pill TR.
///   selected       — coral 1.5px border + 5% coral wash background +
///                    filled coral radio. Beats "recommended" styling
///                    if both apply.
///   current        — used only in the tierSwitch flow; muted "CURRENT"
///                    pill TR + disabled tap. Selection-equivalent to
///                    "this can't be re-picked." Beats every other state.
///
/// Tap target is the whole card (≥ 44pt) per accessibility. Radio is
/// decorative — the source of truth is the card-wide InkWell.
class TierCard extends ConsumerWidget {
  const TierCard({
    super.key,
    required this.plan,
    required this.selected,
    required this.onTap,
    this.recommended = false,
    this.current = false,
  });

  final SubscriptionPlan plan;
  final bool selected;
  final bool recommended;
  final bool current;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final Color border;
    final Color background;
    final double borderWidth;

    if (current) {
      border = context.borderStrong;
      background = context.surface;
      borderWidth = 1;
    } else if (selected) {
      border = context.accent;
      background = context.accent.withValues(alpha: 0.06);
      borderWidth = 1.5;
    } else if (recommended) {
      border = context.accent;
      background = context.surface;
      borderWidth = 1.5;
    } else {
      border = context.border;
      background = context.surface;
      borderWidth = 1;
    }

    return Semantics(
      button: !current,
      selected: selected,
      label: '${plan.interval.tierName} tier, '
          '${NairaFormatter.format(plan.priceNaira)} per ${plan.interval.label}',
      child: InkWell(
        onTap: current ? null : onTap,
        borderRadius: BorderRadius.circular(16),
        splashColor: context.accent.withValues(alpha: 0.08),
        highlightColor: context.accent.withValues(alpha: 0.04),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutQuart,
          padding: const EdgeInsets.fromLTRB(18, 16, 16, 16),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: border, width: borderWidth),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _TopRow(
                tierName: plan.interval.tierName,
                price: plan.priceNaira,
                cadence: plan.interval.label,
                selected: selected,
                recommended: recommended,
                current: current,
              ),
              const SizedBox(height: 6),
              Text(
                plan.interval.renewalCopy,
                style: AppTextStyles.captionSm.copyWith(
                  color: context.textDim,
                ),
              ),
              const SizedBox(height: 12),
              // Hairline separator — never decorative; quietly separates
              // the pricing block from the value-framing block.
              Container(
                height: 1,
                color: context.border,
              ),
              const SizedBox(height: 10),
              Text(
                plan.valueFraming,
                style: AppTextStyles.bodySm.copyWith(
                  color: context.text,
                  fontStyle: FontStyle.italic,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Top row of the tier card: name + price + cadence on the left,
/// status pills + radio indicator on the right.
class _TopRow extends StatelessWidget {
  const _TopRow({
    required this.tierName,
    required this.price,
    required this.cadence,
    required this.selected,
    required this.recommended,
    required this.current,
  });

  final String tierName;
  final int price;
  final String cadence;
  final bool selected;
  final bool recommended;
  final bool current;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: <Widget>[
                  Text(
                    tierName,
                    style: AppTextStyles.h2.copyWith(color: context.text),
                  ),
                  if (current) ...<Widget>[
                    const SizedBox(width: 10),
                    const _StatusPill.current(),
                  ] else if (recommended && !selected) ...<Widget>[
                    const SizedBox(width: 10),
                    const _StatusPill.recommended(),
                  ],
                ],
              ),
              const SizedBox(height: 4),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: <Widget>[
                  Text(
                    NairaFormatter.format(price),
                    style: AppTextStyles.metricVal.copyWith(
                      color: context.text,
                      fontSize: 30,
                      letterSpacing: -0.6,
                      fontFeatures: const <FontFeature>[
                        FontFeature.tabularFigures(),
                      ],
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '/ $cadence',
                    style: AppTextStyles.bodySm.copyWith(
                      color: context.textDim,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        _Radio(selected: selected, current: current),
      ],
    );
  }
}

/// "RECOMMENDED" / "CURRENT" pill. Coral for recommended, muted for
/// current. Always uppercase, always letter-spaced, always small.
class _StatusPill extends StatelessWidget {
  const _StatusPill.recommended()
      : _isRecommended = true;
  const _StatusPill.current() : _isRecommended = false;

  final bool _isRecommended;

  @override
  Widget build(BuildContext context) {
    final Color fg = _isRecommended ? context.accentInk : context.textDim;
    final Color bg =
        _isRecommended ? context.accent : context.surface3;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        _isRecommended ? 'RECOMMENDED' : 'CURRENT',
        style: AppTextStyles.micro.copyWith(
          color: fg,
          letterSpacing: 1.2,
          height: 1,
        ),
      ),
    );
  }
}

/// Custom radio — echoes the wordmark's dot-as-mark visual language.
/// Outlined when unselected, coral-filled with an inner ivory dot when
/// selected. Bigger than a system radio (20pt) because it earns attention.
class _Radio extends StatelessWidget {
  const _Radio({required this.selected, required this.current});

  final bool selected;
  final bool current;

  @override
  Widget build(BuildContext context) {
    if (current) {
      // No radio for the current tier — it can't be re-picked.
      return const SizedBox(width: 20, height: 20);
    }
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutQuart,
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? context.accent : Colors.transparent,
        border: Border.all(
          color: selected ? context.accent : context.borderStrong,
          width: 1.5,
        ),
      ),
      child: selected
          ? Center(
              child: Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: context.accentInk,
                ),
              ),
            )
          : null,
    );
  }
}
