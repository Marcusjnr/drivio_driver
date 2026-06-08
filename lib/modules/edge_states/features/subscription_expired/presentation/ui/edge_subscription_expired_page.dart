import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:drivio_driver/modules/commons/all.dart';
import 'package:drivio_driver/modules/commons/types/subscription.dart';
import 'package:drivio_driver/modules/subscription/features/paywall/presentation/logic/controller/subscription_controller.dart';

class EdgeSubscriptionExpiredPage extends ConsumerWidget {
  const EdgeSubscriptionExpiredPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<_LockedRow> rows = const <_LockedRow>[
      _LockedRow(locked: true, label: 'Incoming ride requests'),
      _LockedRow(locked: true, label: 'Custom pricing & counter-offers'),
      _LockedRow(locked: false, label: 'Earnings & trip history (view only)'),
    ];

    final SubscriptionState sub = ref.watch(subscriptionControllerProvider);
    final SubscriptionPlan? lastPlan = sub.featuredPlan;
    final String lastTierName =
        lastPlan?.interval.tierName ?? 'Drivio Pro';
    final String? endedAtCopy = _formatEndedAt(sub.subscription);
    final String bodyCopy = lastPlan == null
        ? "Your Drivio Pro plan ended. Pick a plan to get back on the marketplace."
        : "Your $lastTierName plan ended${endedAtCopy == null ? '' : ' $endedAtCopy'}. "
            'Pick a plan to get back on the marketplace.';
    return ScreenScaffold(
      child: Stack(
        children: <Widget>[
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0, -0.4),
                  radius: 0.7,
                  colors: <Color>[
                    context.red.withValues(alpha: 0.18),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(26, 40, 26, 30),
            child: Column(
              children: <Widget>[
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: context.red.withValues(alpha: 0.14),
                    border: Border.all(
                      color: context.red.withValues(alpha: 0.32),
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.lock_rounded,
                    size: 32,
                    color: context.red,
                  ),
                ),
                const SizedBox(height: 22),
                const Pill(text: 'SUBSCRIPTION EXPIRED', tone: PillTone.red),
                const SizedBox(height: 14),
                Text(
                  'Subscription paused.',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.screenTitleSm
                      .copyWith(color: context.text),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: 320,
                  child: Text(
                    bodyCopy,
                    textAlign: TextAlign.center,
                    style: AppTextStyles.bodySm.copyWith(
                      color: context.textDim,
                      height: 1.5,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                ...rows.map(
                  (_LockedRow r) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _LockedItem(row: r),
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: context.surface,
                    borderRadius: AppRadius.md,
                    border: Border.all(color: context.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'DRIVIO PRO',
                        style: AppTextStyles.eyebrow
                            .copyWith(color: context.textDim),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Choose Daily, Weekly, or Monthly — '
                        'whatever fits how you drive.',
                        style: AppTextStyles.bodySm.copyWith(
                          color: context.text,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                DrivioButton(
                  label: 'Pick a plan',
                  onPressed: () => AppNavigation.replaceAll<void>(
                    AppRoutes.pickPlan,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LockedItem extends StatelessWidget {
  const _LockedItem({required this.row});

  final _LockedRow row;

  @override
  Widget build(BuildContext context) {
    final Color tint = row.locked ? context.red : context.accent;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: context.surface,
        borderRadius: AppRadius.md,
        border: Border.all(color: context.border),
      ),
      child: Opacity(
        opacity: row.locked ? 1 : 0.62,
        child: Row(
          children: <Widget>[
            Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                color: tint.withValues(alpha: 0.18),
                borderRadius: AppRadius.sm,
              ),
              alignment: Alignment.center,
              child: Icon(
                row.locked ? Icons.lock_rounded : Icons.check_rounded,
                size: 14,
                color: tint,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                row.label,
                style: AppTextStyles.caption.copyWith(
                  color: context.text,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LockedRow {
  const _LockedRow({required this.locked, required this.label});
  final bool locked;
  final String label;
}

/// "today" for an end within the last day; "Jun 8" otherwise. Returns
/// null when we have no period_end to anchor on (e.g., trial that
/// silently ended with no charge attempt).
String? _formatEndedAt(Subscription? sub) {
  final DateTime? end = sub?.currentPeriodEnd ?? sub?.trialEndsAt;
  if (end == null) return null;
  final Duration ago = DateTime.now().difference(end);
  if (ago.inHours < 24) return 'today';
  if (ago.inDays < 7) {
    final int d = ago.inDays;
    return '$d day${d == 1 ? '' : 's'} ago';
  }
  const List<String> m = <String>[
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  return 'on ${m[(end.month - 1).clamp(0, 11)]} ${end.day}';
}
