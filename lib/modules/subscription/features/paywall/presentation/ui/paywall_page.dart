import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:drivio_driver/modules/commons/all.dart';
import 'package:drivio_driver/modules/commons/types/subscription.dart';
import 'package:drivio_driver/modules/subscription/features/paywall/presentation/logic/controller/paystack_activation_controller.dart';
import 'package:drivio_driver/modules/subscription/features/paywall/presentation/logic/controller/subscription_controller.dart';

class PaywallPage extends ConsumerStatefulWidget {
  const PaywallPage({super.key});

  @override
  ConsumerState<PaywallPage> createState() => _PaywallPageState();
}

class _PaywallPageState extends ConsumerState<PaywallPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(subscriptionControllerProvider.notifier).refresh();
      }
    });
  }

  Future<void> _onActivate(
    BuildContext context,
    SubscriptionPlan? plan,
    Subscription? sub,
  ) async {
    if (sub != null && sub.status.unlocksMarketplace) {
      AppNavigation.replaceAll<void>(AppRoutes.home);
      return;
    }
    // Re-activation path. The 3-tier model means we never silently
    // charge a returning driver on whichever plan the controller
    // featured — they pick.
    if (sub != null && sub.status.isHardBlocked) {
      AppNavigation.replaceAll<void>(AppRoutes.pickPlan);
      return;
    }
    if (plan == null) return;

    final PaystackActivationController activator =
        ref.read(paystackActivationControllerProvider.notifier);

    final bool ok = await activator.activate(context: context, plan: plan);
    if (!mounted) return;
    if (ok) {
      await ref.read(subscriptionControllerProvider.notifier).refresh();
      if (!mounted) return;
      AppNavigation.replaceAll<void>(AppRoutes.home);
    } else {
      final String? err =
          ref.read(paystackActivationControllerProvider).error;
      AppNotifier.error(
        message: err ?? "Couldn't activate your plan. Try again in a moment.",
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final SubscriptionState state = ref.watch(subscriptionControllerProvider);
    final SubscriptionPlan? plan = state.featuredPlan;
    final Subscription? sub = state.subscription;
    final PaystackActivationState activation =
        ref.watch(paystackActivationControllerProvider);

    final List<_Benefit> benefits = const <_Benefit>[
      _Benefit(
        icon: Icons.bolt_rounded,
        title: 'Unlimited ride requests',
        sub: 'No per-trip commission. Keep 100% of what you charge.',
      ),
      _Benefit(
        icon: Icons.tune_rounded,
        title: 'Set your own prices',
        sub: 'Slider, stepper, or counter-offer — you decide the fare.',
      ),
      _Benefit(
        icon: Icons.insights_rounded,
        title: 'Earnings & zone insights',
        sub: 'See where riders pay more and when.',
      ),
      _Benefit(
        icon: Icons.verified_rounded,
        title: 'Verified driver badge',
        sub: 'Get 3× more request visibility.',
      ),
    ];

    return ScreenScaffold(
      bottomBar: _BottomBar(
        subscription: sub,
        isProcessing: activation.isProcessing,
        onActivate: () => _onActivate(context, plan, sub),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 4, 24, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Text(
                  'STEP 4 OF 4',
                  style: AppTextStyles.mono.copyWith(
                    color: context.textDim,
                    letterSpacing: 1.8,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(child: ProgressSteps(total: 4, completed: 4)),
              ],
            ),
            const SizedBox(height: 18),
            Text(
              sub != null && sub.isTrialing
                  ? 'Your trial is\nactive.'
                  : 'Free for\n90 days.',
              style: AppTextStyles.screenTitle.copyWith(color: context.text),
            ),
            const SizedBox(height: 10),
            RichText(
              text: TextSpan(
                style: AppTextStyles.bodySm.copyWith(
                  color: context.textDim,
                  height: 1.5,
                ),
                children: <InlineSpan>[
                  TextSpan(
                    text: sub != null && sub.isTrialing
                        ? 'You\'re on Drivio Pro until your trial ends. '
                            'Pick a plan when that day comes — '
                        : 'Drive Drivio for 90 days, no card today. '
                            'When your trial ends, pick the plan that '
                            'fits how you actually work — ',
                  ),
                  TextSpan(
                    text: 'Daily, Weekly, or Monthly.',
                    style: AppTextStyles.bodySm.copyWith(
                      color: context.text,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const TextSpan(text: ' Switch tiers anytime; no per-trip cut, ever.'),
                ],
              ),
            ),
            const SizedBox(height: 20),
            if (state.isLoading && plan == null)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 30),
                child: Center(child: CircularProgressIndicator()),
              )
            else
              _TierGlanceCard(
                plans: state.plans,
                subscription: sub,
              ),
            const SizedBox(height: 22),
            Text(
              'WHAT YOU GET',
              style: AppTextStyles.eyebrow.copyWith(color: context.textDim),
            ),
            const SizedBox(height: 10),
            ...benefits.map(
              (_Benefit b) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _BenefitTile(b: b),
              ),
            ),
            if (state.error != null) ...<Widget>[
              const SizedBox(height: 12),
              _ErrorRow(message: state.error!),
            ],
          ],
        ),
      ),
    );
  }
}

class _Benefit {
  const _Benefit({
    required this.icon,
    required this.title,
    required this.sub,
  });

  final IconData icon;
  final String title;
  final String sub;
}

class _BenefitTile extends StatelessWidget {
  const _BenefitTile({required this.b});

  final _Benefit b;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        color: context.surface,
        borderRadius: AppRadius.md,
        border: Border.all(color: context.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: context.accent.withValues(alpha: 0.14),
              borderRadius: AppRadius.sm,
            ),
            alignment: Alignment.center,
            child: Icon(b.icon, size: 16, color: context.accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  b.title,
                  style: AppTextStyles.h3.copyWith(color: context.text),
                ),
                const SizedBox(height: 3),
                Text(
                  b.sub,
                  style: AppTextStyles.captionSm.copyWith(
                    color: context.textDim,
                    height: 1.4,
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

/// "At a glance" card showing what the three tiers cost. Visually
/// quiet — three rows in a single card with the cadence on the left
/// and the per-cycle price on the right, plus a TRIAL pill at the top
/// when the driver is currently trialing.
///
/// This card replaces the old single-plan price hero. The pick-a-plan
/// flow handles the actual selection at trial end; this surface just
/// sets expectation.
class _TierGlanceCard extends StatelessWidget {
  const _TierGlanceCard({
    required this.plans,
    required this.subscription,
  });

  final List<SubscriptionPlan> plans;
  final Subscription? subscription;

  @override
  Widget build(BuildContext context) {
    // Order Daily → Weekly → Monthly. We tolerate a partial catalog
    // (e.g., one tier missing in dev) by only rendering rows we have.
    final List<SubscriptionPlan> ordered = <SubscriptionPlan>[
      ..._pick(plans, SubscriptionInterval.day),
      ..._pick(plans, SubscriptionInterval.week),
      ..._pick(plans, SubscriptionInterval.month),
    ];

    final bool trialing =
        subscription?.status == SubscriptionStatus.trialing;
    final int? days = subscription?.daysRemaining;

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
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
        border: Border.all(color: context.accent.withValues(alpha: 0.32)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Text(
                'DRIVIO PRO',
                style: AppTextStyles.eyebrow.copyWith(
                  color: context.accent,
                  letterSpacing: 1.4,
                ),
              ),
              const Spacer(),
              if (trialing)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: context.accent,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'TRIAL',
                    style: AppTextStyles.micro.copyWith(
                      color: context.accentInk,
                      letterSpacing: 1.4,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            trialing && days != null
                ? '$days days left · then pick a plan'
                : 'Three plans, your call',
            style: AppTextStyles.h2.copyWith(color: context.text),
          ),
          const SizedBox(height: 14),
          for (int i = 0; i < ordered.length; i++) ...<Widget>[
            if (i > 0)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Container(
                  height: 1,
                  color: context.accent.withValues(alpha: 0.14),
                ),
              ),
            _TierGlanceRow(plan: ordered[i]),
          ],
          const SizedBox(height: 12),
          Text(
            'Auto-renews each cycle until you cancel or switch.',
            style: AppTextStyles.captionSm.copyWith(color: context.textDim),
          ),
        ],
      ),
    );
  }

  static Iterable<SubscriptionPlan> _pick(
    List<SubscriptionPlan> plans,
    SubscriptionInterval interval,
  ) sync* {
    for (final SubscriptionPlan p in plans) {
      if (p.interval == interval) yield p;
    }
  }
}

class _TierGlanceRow extends StatelessWidget {
  const _TierGlanceRow({required this.plan});

  final SubscriptionPlan plan;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                plan.interval.tierName,
                style: AppTextStyles.h3.copyWith(color: context.text),
              ),
              const SizedBox(height: 2),
              Text(
                plan.valueFraming,
                style: AppTextStyles.captionSm.copyWith(
                  color: context.textDim,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: <Widget>[
            Text(
              NairaFormatter.format(plan.priceNaira),
              style: AppTextStyles.metricVal.copyWith(
                color: context.text,
                fontSize: 22,
                letterSpacing: -0.4,
                fontFeatures: const <FontFeature>[
                  FontFeature.tabularFigures(),
                ],
              ),
            ),
            const SizedBox(width: 4),
            Text(
              '/ ${plan.interval.label}',
              style: AppTextStyles.captionSm.copyWith(color: context.textDim),
            ),
          ],
        ),
      ],
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.subscription,
    required this.isProcessing,
    required this.onActivate,
  });

  final Subscription? subscription;
  final bool isProcessing;
  final VoidCallback onActivate;

  @override
  Widget build(BuildContext context) {
    final SubscriptionStatus? status = subscription?.status;
    final bool covered = status?.unlocksMarketplace ?? false;
    final bool hardBlocked = status?.isHardBlocked ?? false;
    final bool trialing = status == SubscriptionStatus.trialing;
    final int? daysLeft = subscription?.daysRemaining;

    final String label;
    if (isProcessing) {
      label = 'Opening…';
    } else if (covered) {
      label = trialing ? 'Continue driving' : 'Continue to home';
    } else if (hardBlocked) {
      label = 'Pick a plan';
    } else {
      label = 'Start trial — KYC next';
    }

    final String fineprint;
    if (trialing && daysLeft != null) {
      fineprint = '$daysLeft day${daysLeft == 1 ? '' : 's'} left of '
          'your trial · pick a plan when it ends';
    } else if (covered) {
      fineprint = "You're good to drive.";
    } else if (hardBlocked) {
      fineprint = 'Daily ₦2,500 · Weekly ₦15,000 · Monthly ₦50,000';
    } else {
      fineprint = "No card today. We'll remind you 7 days "
          'before your trial ends.';
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
      decoration: BoxDecoration(
        color: context.bg,
        border: Border(top: BorderSide(color: context.border)),
      ),
      child: Column(
        children: <Widget>[
          DrivioButton(
            label: label,
            disabled: isProcessing,
            onPressed: onActivate,
          ),
          const SizedBox(height: 8),
          Text(
            fineprint,
            style: AppTextStyles.micro.copyWith(
              color: context.textMuted,
              letterSpacing: 0.3,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _ErrorRow extends StatelessWidget {
  const _ErrorRow({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: context.red.withValues(alpha: 0.10),
        borderRadius: AppRadius.md,
        border: Border.all(color: context.red.withValues(alpha: 0.30)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(Icons.error_outline_rounded, size: 16, color: context.red),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: AppTextStyles.bodySm.copyWith(
                color: context.red,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
