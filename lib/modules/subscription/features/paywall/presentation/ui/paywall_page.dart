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
    // If the driver is already covered (trial or active), just go home.
    if (sub != null && sub.status.unlocksMarketplace) {
      AppNavigation.replaceAll<void>(AppRoutes.home);
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
      AppNotifier.error(message: err ?? 'Could not activate plan.');
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
        emoji: '🚗',
        title: 'Unlimited ride requests',
        sub: 'No per-trip commission. Keep 100% of what you charge.',
      ),
      _Benefit(
        emoji: '💸',
        title: 'Set your own prices',
        sub: 'Slider, stepper, or counter-offer — you decide the fare.',
      ),
      _Benefit(
        emoji: '📈',
        title: 'Earnings & zone insights',
        sub: 'See where riders pay more and when.',
      ),
      _Benefit(
        emoji: '🛡️',
        title: 'Verified driver badge',
        sub: 'Get 3× more request visibility.',
      ),
    ];

    return ScreenScaffold(
      bottomBar: _BottomBar(
        plan: plan,
        subscription: sub,
        isProcessing: activation.isProcessing,
        onActivate: () => _onActivate(context, plan, sub),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 4, 24, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'STEP 4 OF 4',
              style: TextStyle(
                fontSize: 11,
                color: context.textMuted,
                fontFamily: 'monospace',
                letterSpacing: 1.6,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              sub != null && sub.isTrialing
                  ? 'Your trial is\nactive.'
                  : 'Activate your plan\nto start earning.',
              style: AppTextStyles.screenTitle.copyWith(color: context.text),
            ),
            const SizedBox(height: 8),
            RichText(
              text: TextSpan(
                style: AppTextStyles.bodySm
                    .copyWith(color: context.textDim, height: 1.5),
                children: <InlineSpan>[
                  const TextSpan(text: 'Drivio Pro is '),
                  TextSpan(
                    text: 'flat-rate',
                    style: TextStyle(
                      color: context.text,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const TextSpan(text: ' — no per-trip cut. Ever.'),
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
              _PlanCard(plan: plan, subscription: sub),
            const SizedBox(height: 18),
            ...benefits.map(
              (_Benefit b) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _BenefitTile(b: b),
              ),
            ),
            if (state.error != null) ...<Widget>[
              const SizedBox(height: 12),
              Text(
                state.error!,
                style: AppTextStyles.bodySm.copyWith(color: context.red),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Benefit {
  const _Benefit(
      {required this.emoji, required this.title, required this.sub});
  final String emoji;
  final String title;
  final String sub;
}

class _BenefitTile extends ConsumerWidget {
  const _BenefitTile({required this.b});
  final _Benefit b;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: context.surface,
        borderRadius: AppRadius.md,
        border: Border.all(color: context.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(b.emoji, style: const TextStyle(fontSize: 22)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  b.title,
                  style: TextStyle(
                    fontSize: 14,
                    color: context.text,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  b.sub,
                  style: TextStyle(
                    fontSize: 12,
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

class _PlanCard extends ConsumerWidget {
  const _PlanCard({required this.plan, required this.subscription});

  final SubscriptionPlan? plan;
  final Subscription? subscription;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final int priceNaira = plan == null ? 0 : (plan!.priceMinor ~/ 100);
    final String intervalLabel = plan?.interval.label ?? 'month';
    final String name = plan?.name ?? 'Drivio Pro';
    final bool trialing =
        subscription?.status == SubscriptionStatus.trialing;
    final int? days = subscription?.daysRemaining;

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
      child: Stack(
        children: <Widget>[
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                name.toUpperCase(),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: context.accent,
                  letterSpacing: 0.6,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: <Widget>[
                  Text(
                    NairaFormatter.format(priceNaira),
                    style: TextStyle(
                      fontSize: 42,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -1.2,
                      color: context.text,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '/ $intervalLabel',
                    style: TextStyle(fontSize: 14, color: context.textDim),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                trialing && days != null
                    ? 'Trial: $days days left · cancel anytime'
                    : '90-day free trial · cancel anytime',
                style: TextStyle(fontSize: 12, color: context.textDim),
              ),
            ],
          ),
          if (trialing)
            Positioned(
              top: 0,
              right: 0,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: context.accent,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'TRIAL',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: context.accentInk,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _BottomBar extends ConsumerWidget {
  const _BottomBar({
    required this.plan,
    required this.subscription,
    required this.isProcessing,
    required this.onActivate,
  });

  final SubscriptionPlan? plan;
  final Subscription? subscription;
  final bool isProcessing;
  final VoidCallback onActivate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final SubscriptionStatus? status = subscription?.status;
    final bool covered = status?.unlocksMarketplace ?? false;
    final int priceNaira = plan == null ? 0 : (plan!.priceMinor ~/ 100);
    final String intervalLabel = plan?.interval.label ?? 'month';

    final String label;
    if (isProcessing) {
      label = 'Processing…';
    } else if (covered) {
      label = 'Continue to home';
    } else if (status == SubscriptionStatus.expired ||
        status == SubscriptionStatus.cancelled) {
      label = 'Reactivate Drivio Pro';
    } else {
      label = 'Activate Drivio Pro';
    }

    final DateTime? billDate = subscription?.currentPeriodEnd;
    final bool trialing = status == SubscriptionStatus.trialing;
    final String fineprint = trialing && billDate != null
        ? 'Then ${NairaFormatter.format(priceNaira)}/$intervalLabel · first bill ${_fmtDate(billDate)}'
        : '${NairaFormatter.format(priceNaira)}/$intervalLabel · cancel anytime';

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
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
            style: TextStyle(fontSize: 11, color: context.textMuted),
          ),
        ],
      ),
    );
  }

  static String _fmtDate(DateTime d) {
    const List<String> months = <String>[
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[d.month - 1]} ${d.day}';
  }
}
