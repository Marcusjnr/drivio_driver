import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shimmer/shimmer.dart';

import 'package:drivio_driver/modules/commons/all.dart';
import 'package:drivio_driver/modules/commons/types/subscription.dart';
import 'package:drivio_driver/modules/commons/types/wallet.dart';
import 'package:drivio_driver/modules/dash/features/home/presentation/ui/widgets/driver_tab_bar.dart';
import 'package:drivio_driver/modules/subscription/features/manage/presentation/logic/controller/subscription_manage_controller.dart';
import 'package:drivio_driver/modules/subscription/features/paywall/presentation/logic/controller/subscription_controller.dart';

class SubscriptionManagePage extends ConsumerStatefulWidget {
  const SubscriptionManagePage({super.key});

  @override
  ConsumerState<SubscriptionManagePage> createState() =>
      _SubscriptionManagePageState();
}

class _SubscriptionManagePageState
    extends ConsumerState<SubscriptionManagePage> {
  @override
  void initState() {
    super.initState();
    // Refresh the headline subscription on entry — important after
    // the user just paid, renewed, or had a webhook flip the row.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(subscriptionControllerProvider.notifier).refresh();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final SubscriptionState sub = ref.watch(subscriptionControllerProvider);
    final SubscriptionManageState manage =
        ref.watch(subscriptionManageControllerProvider);
    final SubscriptionManageController c =
        ref.read(subscriptionManageControllerProvider.notifier);

    return ScreenScaffold(
      bottomBar: const DriverTabBar(active: DriverTab.profile),
      child: RefreshIndicator(
        onRefresh: () async {
          await Future.wait<void>(<Future<void>>[
            ref.read(subscriptionControllerProvider.notifier).refresh(),
            c.refresh(),
          ]);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  BackButtonBox(onTap: () => AppNavigation.pop()),
                  const SizedBox(width: 12),
                  Text(
                    'Subscription',
                    style: AppTextStyles.h1.copyWith(color: context.text),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (sub.isLoading && sub.subscription == null)
                _PlanCardShimmer(
                  base: context.surface2,
                  highlight: context.surface3,
                )
              else
                _PlanCard(state: sub),
              const SizedBox(height: 14),
              DrivioButton(
                label: 'Manage payment',
                variant: DrivioButtonVariant.ghost,
                onPressed: () => AppNavigation.push(AppRoutes.paymentMethods),
              ),
              if (sub.error != null) ...<Widget>[
                const SizedBox(height: 8),
                Text(
                  sub.error!,
                  style: AppTextStyles.bodySm.copyWith(color: context.red),
                ),
              ],
              const SizedBox(height: 18),
              Text('BILLING HISTORY',
                  style: AppTextStyles.eyebrow.copyWith(color: context.textDim)),
              const SizedBox(height: 8),
              if (manage.isLoading)
                _BillingShimmer(
                  base: context.surface2,
                  highlight: context.surface3,
                )
              else
                _BillingHistory(charges: manage.charges),
              if (manage.error != null) ...<Widget>[
                const SizedBox(height: 8),
                Text(
                  manage.error!,
                  style: AppTextStyles.bodySm.copyWith(color: context.red),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ── Plan card ──────────────────────────────────────────────────────────

class _PlanCard extends StatelessWidget {
  const _PlanCard({required this.state});
  final SubscriptionState state;

  @override
  Widget build(BuildContext context) {
    final Subscription? sub = state.subscription;
    final SubscriptionPlan? plan = state.featuredPlan;

    final String planName =
        plan?.name ?? (sub == null ? 'No plan' : 'Drivio Pro');
    final String priceLine = plan == null
        ? '—'
        : '${NairaFormatter.format(plan.priceMinor ~/ 100)}/${plan.interval.label}';

    final (String pillText, PillTone pillTone) =
        _statusPill(sub?.status);

    final DateTime? periodStart = sub?.currentPeriodStart;
    final DateTime? periodEnd = sub?.currentPeriodEnd ?? sub?.trialEndsAt;
    final double progress = _periodProgress(periodStart, periodEnd);
    final int? daysLeft = sub?.daysRemaining;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            context.accent.withValues(alpha: 0.12),
            context.accent.withValues(alpha: 0.02),
          ],
        ),
        borderRadius: AppRadius.lg,
        border: Border.all(color: context.accent.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    planName.toUpperCase(),
                    style: AppTextStyles.eyebrow.copyWith(color: context.accent),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    priceLine,
                    style: AppTextStyles.screenTitle
                        .copyWith(color: context.text),
                  ),
                ],
              ),
              Pill(text: pillText, tone: pillTone),
            ],
          ),
          if (periodEnd != null) ...<Widget>[
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: SizedBox(
                height: 6,
                child: Stack(
                  children: <Widget>[
                    Container(color: Colors.white.withValues(alpha: 0.08)),
                    FractionallySizedBox(
                      widthFactor: progress.clamp(0.0, 1.0),
                      child: Container(color: context.accent),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Text(
                  daysLeft == null
                      ? '—'
                      : daysLeft <= 0
                          ? 'Expired'
                          : '$daysLeft day${daysLeft == 1 ? '' : 's'} left',
                  style:
                      AppTextStyles.captionSm.copyWith(color: context.textDim),
                ),
                Text(
                  '${_renewVerb(sub?.status)} ${_fmtDate(periodEnd)}',
                  style:
                      AppTextStyles.captionSm.copyWith(color: context.textDim),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  /// 0..1 fraction of the current period that has elapsed. Returns
  /// 0 when we don't have both endpoints.
  static double _periodProgress(DateTime? start, DateTime? end) {
    if (start == null || end == null) return 0;
    final int total = end.difference(start).inSeconds;
    if (total <= 0) return 1;
    final int elapsed = DateTime.now().difference(start).inSeconds;
    if (elapsed <= 0) return 0;
    return elapsed / total;
  }

  static (String, PillTone) _statusPill(SubscriptionStatus? s) {
    switch (s) {
      case SubscriptionStatus.active:
        return ('ACTIVE', PillTone.accent);
      case SubscriptionStatus.trialing:
        return ('TRIAL', PillTone.blue);
      case SubscriptionStatus.pastDue:
        return ('PAST DUE', PillTone.amber);
      case SubscriptionStatus.expired:
        return ('EXPIRED', PillTone.red);
      case SubscriptionStatus.cancelled:
        return ('CANCELLED', PillTone.neutral);
      case null:
        return ('NONE', PillTone.neutral);
    }
  }

  static String _renewVerb(SubscriptionStatus? s) {
    switch (s) {
      case SubscriptionStatus.trialing:
        return 'Trial ends';
      case SubscriptionStatus.cancelled:
      case SubscriptionStatus.expired:
        return 'Ended';
      case SubscriptionStatus.pastDue:
        return 'Was due';
      case SubscriptionStatus.active:
      case null:
        return 'Renews';
    }
  }

  static String _fmtDate(DateTime t) {
    const List<String> m = <String>[
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${m[(t.month - 1).clamp(0, 11)]} ${t.day}';
  }
}

// ── Billing history ────────────────────────────────────────────────────

class _BillingHistory extends StatelessWidget {
  const _BillingHistory({required this.charges});
  final List<LedgerEntry> charges;

  @override
  Widget build(BuildContext context) {
    if (charges.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: context.surface,
          borderRadius: AppRadius.md,
          border: Border.all(color: context.border),
        ),
        child: Center(
          child: Text(
            'No billing activity yet.',
            style: AppTextStyles.bodySm.copyWith(color: context.textDim),
          ),
        ),
      );
    }
    final List<LedgerEntry> shown = charges.take(20).toList();
    return Container(
      decoration: BoxDecoration(
        color: context.surface,
        borderRadius: AppRadius.md,
        border: Border.all(color: context.border),
      ),
      child: Column(
        children: List<Widget>.generate(shown.length, (int i) {
          final LedgerEntry e = shown[i];
          return Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              border: i == shown.length - 1
                  ? null
                  : Border(bottom: BorderSide(color: context.border)),
            ),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        _fmtDate(e.createdAt),
                        style: AppTextStyles.bodySm.copyWith(
                          color: context.text,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        e.description ?? 'Subscription charge',
                        style: AppTextStyles.captionSm.copyWith(
                          color: context.textDim,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: <Widget>[
                    Text(
                      NairaFormatter.format(e.amountMinor ~/ 100),
                      style: AppTextStyles.bodySm.copyWith(
                        color: context.text,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      '✓ Paid',
                      style: AppTextStyles.captionSm
                          .copyWith(fontSize: 11, color: context.accent),
                    ),
                  ],
                ),
              ],
            ),
          );
        }),
      ),
    );
  }

  static String _fmtDate(DateTime t) {
    const List<String> m = <String>[
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${m[(t.month - 1).clamp(0, 11)]} ${t.day}, ${t.year}';
  }
}

// ── Shimmer skeletons ──────────────────────────────────────────────────

class _PlanCardShimmer extends StatelessWidget {
  const _PlanCardShimmer({required this.base, required this.highlight});

  final Color base;
  final Color highlight;

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: base,
      highlightColor: highlight,
      period: const Duration(milliseconds: 1400),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: AppRadius.lg,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const <Widget>[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    _ShimmerBox(width: 90, height: 9),
                    SizedBox(height: 8),
                    _ShimmerBox(width: 130, height: 26),
                  ],
                ),
                _ShimmerBox(width: 60, height: 22, radius: 11),
              ],
            ),
            SizedBox(height: 18),
            _ShimmerBox(width: double.infinity, height: 6),
            SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                _ShimmerBox(width: 70, height: 10),
                _ShimmerBox(width: 90, height: 10),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _BillingShimmer extends StatelessWidget {
  const _BillingShimmer({required this.base, required this.highlight});

  final Color base;
  final Color highlight;

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: base,
      highlightColor: highlight,
      period: const Duration(milliseconds: 1400),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: AppRadius.md,
        ),
        child: Column(
          children: List<Widget>.generate(3, (int i) {
            return const Padding(
              padding:
                  EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        _ShimmerBox(width: 80, height: 12),
                        SizedBox(height: 6),
                        _ShimmerBox(width: 110, height: 10),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: <Widget>[
                      _ShimmerBox(width: 60, height: 12),
                      SizedBox(height: 6),
                      _ShimmerBox(width: 40, height: 10),
                    ],
                  ),
                ],
              ),
            );
          }),
        ),
      ),
    );
  }
}

/// One opaque rectangle for the shimmer ancestor to tint. The colour
/// itself is irrelevant — Shimmer's gradient paints over it — but the
/// child has to actually paint pixels for the gradient to land.
class _ShimmerBox extends StatelessWidget {
  const _ShimmerBox({
    required this.width,
    required this.height,
    this.radius = 4,
  });

  final double width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}
