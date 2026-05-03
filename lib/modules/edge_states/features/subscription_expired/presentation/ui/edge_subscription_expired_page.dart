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
                    color: context.red.withValues(alpha: 0.16),
                    border: Border.all(color: context.red.withValues(alpha: 0.35)),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  alignment: Alignment.center,
                  child: const Text('🔒', style: TextStyle(fontSize: 34)),
                ),
                const SizedBox(height: 24),
                const Pill(text: 'SUBSCRIPTION EXPIRED', tone: PillTone.red),
                const SizedBox(height: 14),
                Text(
                  'Reactivate to get\nback on the road.',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.screenTitleSm.copyWith(color: context.text),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: 300,
                  child: Text(
                    "Your Drivio Pro plan ended 2 days ago. You won't receive ride requests until you renew.",
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
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: context.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: context.border),
                      ),
                      child: Opacity(
                        opacity: r.locked ? 1 : 0.6,
                        child: Row(
                          children: <Widget>[
                            Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                color: (r.locked ? context.red : context.accent)
                                    .withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                r.locked ? '🔒' : '✓',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: r.locked ? context.red : context.accent,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                r.label,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: context.text,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
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
                      Text('DRIVIO PRO',
                          style: AppTextStyles.eyebrow.copyWith(color: context.textDim)),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: <Widget>[
                          Text(
                            '${NairaFormatter.format(15000)}/mo',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: context.text,
                            ),
                          ),
                          Text(
                            'Same as before',
                            style: TextStyle(fontSize: 12, color: context.accent),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                DrivioButton(
                  label: 'Reactivate now',
                  onPressed: () =>
                      AppNavigation.replaceAll<void>(AppRoutes.subscriptionManage),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LockedRow {
  const _LockedRow({required this.locked, required this.label});
  final bool locked;
  final String label;
}
