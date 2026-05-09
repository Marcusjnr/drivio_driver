import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:drivio_driver/modules/commons/all.dart';

class EdgeSubscriptionExpiredPage extends ConsumerWidget {
  const EdgeSubscriptionExpiredPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<_LockedRow> rows = const <_LockedRow>[
      _LockedRow(locked: true, label: 'Incoming ride requests'),
      _LockedRow(locked: true, label: 'Custom pricing & counter-offers'),
      _LockedRow(locked: false, label: 'Earnings & trip history (view only)'),
    ];
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
                  'Renew to keep\ndriving on Drivio.',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.screenTitleSm
                      .copyWith(color: context.text),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: 300,
                  child: Text(
                    "Your Drivio Pro plan ended. You won't see ride "
                    "requests until you renew.",
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
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: <Widget>[
                          Text(
                            '${NairaFormatter.format(15000)}/mo',
                            style: AppTextStyles.metricVal
                                .copyWith(color: context.text),
                          ),
                          Text(
                            'Same as before',
                            style: AppTextStyles.captionSm
                                .copyWith(color: context.accent),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                DrivioButton(
                  label: 'Renew plan',
                  onPressed: () => AppNavigation.replaceAll<void>(
                    AppRoutes.subscriptionManage,
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
