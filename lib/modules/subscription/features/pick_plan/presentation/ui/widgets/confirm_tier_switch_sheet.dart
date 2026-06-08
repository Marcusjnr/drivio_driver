import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:drivio_driver/modules/commons/all.dart';
import 'package:drivio_driver/modules/commons/types/subscription.dart';

/// SCR-043b — Confirm Tier Switch.
///
/// Modal sheet shown after the driver picks a new tier on the Pick a Plan
/// screen and the intent is [PickPlanIntent.tierSwitch]. Explains exactly
/// when the switch takes effect ("Your `<current>` stays active until
/// `<date>`. From then on, you'll pay X every `<cadence>`.") and shows
/// a side-by-side comparison row.
///
/// Returns true if the driver confirmed.
class ConfirmTierSwitchSheet extends ConsumerWidget {
  const ConfirmTierSwitchSheet({
    super.key,
    required this.current,
    required this.target,
    required this.currentPeriodEnd,
  });

  final SubscriptionPlan current;
  final SubscriptionPlan target;
  final DateTime? currentPeriodEnd;

  static Future<bool> show({
    required BuildContext context,
    required SubscriptionPlan current,
    required SubscriptionPlan target,
    required DateTime? currentPeriodEnd,
  }) async {
    final bool? result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.40),
      builder: (BuildContext _) => ConfirmTierSwitchSheet(
        current: current,
        target: target,
        currentPeriodEnd: currentPeriodEnd,
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final MediaQueryData mq = MediaQuery.of(context);
    return SafeArea(
      top: false,
      child: Container(
        margin: EdgeInsets.only(bottom: mq.viewInsets.bottom),
        decoration: BoxDecoration(
          color: context.bg,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(24),
          ),
          border: Border(top: BorderSide(color: context.borderStrong)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            // Drag indicator
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: context.borderStrong,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Switch to ${target.interval.tierName}?',
              style: AppTextStyles.h1.copyWith(color: context.text),
            ),
            const SizedBox(height: 10),
            _BodyCopy(
              current: current,
              target: target,
              currentPeriodEnd: currentPeriodEnd,
            ),
            const SizedBox(height: 18),
            _ComparisonRow(current: current, target: target),
            const SizedBox(height: 22),
            DrivioButton(
              label: 'Queue switch',
              onPressed: () => Navigator.of(context).pop(true),
            ),
            const SizedBox(height: 8),
            DrivioButton(
              label: 'Keep ${current.interval.tierName}',
              variant: DrivioButtonVariant.ghost,
              onPressed: () => Navigator.of(context).pop(false),
            ),
          ],
        ),
      ),
    );
  }
}

class _BodyCopy extends StatelessWidget {
  const _BodyCopy({
    required this.current,
    required this.target,
    required this.currentPeriodEnd,
  });

  final SubscriptionPlan current;
  final SubscriptionPlan target;
  final DateTime? currentPeriodEnd;

  @override
  Widget build(BuildContext context) {
    final String when = currentPeriodEnd == null
        ? 'at your next renewal'
        : 'on ${_fmtDate(currentPeriodEnd!)}';
    return Text.rich(
      TextSpan(
        style: AppTextStyles.body.copyWith(
          color: context.textDim,
          height: 1.5,
        ),
        children: <InlineSpan>[
          TextSpan(text: 'Your '),
          TextSpan(
            text: '${current.interval.tierName} plan',
            style: AppTextStyles.body.copyWith(
              color: context.text,
              fontWeight: FontWeight.w700,
            ),
          ),
          TextSpan(text: ' stays active until $when. From then on, '
              'you\'ll pay '),
          TextSpan(
            text: '${NairaFormatter.format(target.priceNaira)} '
                'every ${target.interval.daysInCycle == 1 ? '24 hours' : '${target.interval.daysInCycle} days'}',
            style: AppTextStyles.body.copyWith(
              color: context.text,
              fontWeight: FontWeight.w700,
            ),
          ),
          const TextSpan(
            text: '. We won\'t charge anything today.',
          ),
        ],
      ),
    );
  }

  static String _fmtDate(DateTime d) {
    const List<String> m = <String>[
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${m[d.month - 1]} ${d.day}';
  }
}

/// Side-by-side mini cards: CURRENT (muted) → arrow → NEW (coral).
/// The arrow says "this is a deliberate change," not a marketing
/// flourish — it gives the comparison a direction.
class _ComparisonRow extends StatelessWidget {
  const _ComparisonRow({required this.current, required this.target});

  final SubscriptionPlan current;
  final SubscriptionPlan target;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        Expanded(
          child: _MiniCard(
            eyebrow: 'CURRENT',
            tier: current.interval.tierName,
            price: NairaFormatter.format(current.priceNaira),
            cadence: '/ ${current.interval.label}',
            highlighted: false,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Icon(
            Icons.arrow_forward_rounded,
            color: context.accent,
            size: 22,
          ),
        ),
        Expanded(
          child: _MiniCard(
            eyebrow: 'NEW',
            tier: target.interval.tierName,
            price: NairaFormatter.format(target.priceNaira),
            cadence: '/ ${target.interval.label}',
            highlighted: true,
          ),
        ),
      ],
    );
  }
}

class _MiniCard extends StatelessWidget {
  const _MiniCard({
    required this.eyebrow,
    required this.tier,
    required this.price,
    required this.cadence,
    required this.highlighted,
  });

  final String eyebrow;
  final String tier;
  final String price;
  final String cadence;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final Color border = highlighted ? context.accent : context.border;
    final Color bg = highlighted
        ? context.accent.withValues(alpha: 0.06)
        : context.surface;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: border,
          width: highlighted ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            eyebrow,
            style: AppTextStyles.eyebrow.copyWith(
              color: highlighted ? context.accent : context.textMuted,
              letterSpacing: 1.4,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            tier,
            style: AppTextStyles.h3.copyWith(color: context.text),
          ),
          const SizedBox(height: 2),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: <Widget>[
              Flexible(
                child: Text(
                  price,
                  style: AppTextStyles.bodyLg.copyWith(
                    color: context.text,
                    fontWeight: FontWeight.w700,
                    fontFeatures: const <FontFeature>[
                      FontFeature.tabularFigures(),
                    ],
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                cadence,
                style: AppTextStyles.caption.copyWith(
                  color: context.textDim,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
