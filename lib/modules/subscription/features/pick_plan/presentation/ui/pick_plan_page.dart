import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:drivio_driver/modules/commons/all.dart';
import 'package:drivio_driver/modules/commons/types/subscription.dart';
import 'package:drivio_driver/modules/subscription/features/paywall/presentation/logic/controller/paystack_activation_controller.dart';
import 'package:drivio_driver/modules/subscription/features/paywall/presentation/logic/controller/subscription_controller.dart';
import 'package:drivio_driver/modules/subscription/features/pick_plan/presentation/logic/pick_plan_controller.dart';
import 'package:drivio_driver/modules/subscription/features/pick_plan/presentation/ui/widgets/confirm_tier_switch_sheet.dart';
import 'package:drivio_driver/modules/subscription/features/pick_plan/presentation/ui/widgets/recommendation_banner.dart';
import 'package:drivio_driver/modules/subscription/features/pick_plan/presentation/ui/widgets/tier_card.dart';

/// SCR-006b — Pick a Plan.
///
/// Shown to drivers picking their first tier at trial end, re-subscribing
/// after expiry, or switching tiers mid-subscription. Three tier cards,
/// one personalised recommendation, one sticky CTA. No timers, no
/// scarcity, no progress chip — this is a moment of choice, not an
/// onboarding step.
///
/// Intent is passed via [GoRouterState.extra] as a `PickPlanIntent` (or
/// inferred from current subscription state when absent — defaults to
/// `trialChoice`).
class PickPlanPage extends ConsumerStatefulWidget {
  const PickPlanPage({super.key, this.intent, this.currentTierCode});

  final PickPlanIntent? intent;
  final String? currentTierCode;

  @override
  ConsumerState<PickPlanPage> createState() => _PickPlanPageState();
}

class _PickPlanPageState extends ConsumerState<PickPlanPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final PickPlanIntent intent = widget.intent ?? _inferIntent(ref);
      final String? currentCode = widget.currentTierCode ?? _inferCurrent(ref);
      await ref
          .read(pickPlanControllerProvider.notifier)
          .hydrate(intent: intent, currentTierCode: currentCode);
    });
  }

  /// When no explicit intent is passed, derive one from the live
  /// subscription state. Active driver on a plan → tierSwitch.
  /// Expired/cancelled → reactivation. Default → trialChoice.
  PickPlanIntent _inferIntent(WidgetRef ref) {
    final Subscription? sub =
        ref.read(subscriptionControllerProvider).subscription;
    if (sub == null) return PickPlanIntent.trialChoice;
    if (sub.status == SubscriptionStatus.expired ||
        sub.status == SubscriptionStatus.cancelled) {
      return PickPlanIntent.reactivation;
    }
    if (sub.status == SubscriptionStatus.active ||
        sub.status == SubscriptionStatus.pastDue) {
      return PickPlanIntent.tierSwitch;
    }
    return PickPlanIntent.trialChoice;
  }

  String? _inferCurrent(WidgetRef ref) {
    final SubscriptionState s = ref.read(subscriptionControllerProvider);
    final String? planId = s.subscription?.planId;
    if (planId == null) return null;
    for (final SubscriptionPlan p in s.plans) {
      if (p.id == planId) return p.code;
    }
    return null;
  }

  Future<void> _onSubmit() async {
    final PickPlanState s = ref.read(pickPlanControllerProvider);
    final SubscriptionPlan? plan = s.selectedTier;
    if (plan == null) return;

    final SubscriptionState subState =
        ref.read(subscriptionControllerProvider);
    final Subscription? sub = subState.subscription;

    // Three submit paths, dispatched by live subscription state — not by
    // the page's intent enum. Intent governs *copy*; subscription state
    // governs *behaviour*.
    //
    //   1. No sub OR hard-blocked (expired/cancelled) → activate now via
    //      Paystack/dev-mode. The driver is paying today.
    //   2. Trialing → queue for end-of-trial. No charge today. If the
    //      picked tier matches the trial's default plan, silently confirm
    //      (no RPC needed, no pending_plan_id to write).
    //   3. Active / past_due → confirm sheet + queue switch for next
    //      renewal anniversary. No charge today.
    if (sub == null || sub.isHardBlocked) {
      await _onSubmitActivation(plan);
      return;
    }
    if (sub.effectiveStatus == SubscriptionStatus.trialing) {
      await _onSubmitTrialChoice(plan);
      return;
    }
    await _onSubmitTierSwitch(plan);
  }

  /// Trialing drivers don't pay today. Their pick is stored on the
  /// subscription as `pending_plan_id` and applied at trial-end renewal.
  ///
  /// Two sub-cases:
  ///   • Pick matches the trial's default plan (Monthly, set by the
  ///     `grant_trial_on_kyc_approval` trigger). Nothing to queue — the
  ///     subscription already points at this tier. Toast + pop.
  ///   • Pick differs from the trial default. Call `queue_tier_switch`
  ///     which writes `pending_plan_id`. No confirmation sheet here —
  ///     for trialing drivers the choice is low-stakes (no charge moves
  ///     either way), so we skip the modal friction.
  Future<void> _onSubmitTrialChoice(SubscriptionPlan target) async {
    final SubscriptionState subState =
        ref.read(subscriptionControllerProvider);
    final Subscription? sub = subState.subscription;
    final SubscriptionPlan? currentPlan = subState.featuredPlan;

    if (sub == null) {
      AppNotifier.error(
        message: "Couldn't find your subscription. Try again in a moment.",
      );
      return;
    }

    // Same tier as the trial default → no RPC needed.
    if (currentPlan != null && currentPlan.id == target.id) {
      AppNotifier.success(
        message: '${target.interval.tierName} locked in for after your trial.',
      );
      AppNavigation.pop();
      return;
    }

    final bool ok = await ref
        .read(pickPlanControllerProvider.notifier)
        .queueSwitch(subscriptionId: sub.id, targetPlanCode: target.code);
    if (!mounted) return;

    if (!ok) {
      AppNotifier.error(
        message: ref.read(pickPlanControllerProvider).error ??
            "Couldn't lock in your pick. Try again in a moment.",
      );
      return;
    }

    await ref.read(subscriptionControllerProvider.notifier).refresh();
    if (!mounted) return;
    AppNotifier.success(
      message:
          '${target.interval.tierName} locked in for after your trial.',
    );
    AppNavigation.pop();
  }

  Future<void> _onSubmitActivation(SubscriptionPlan plan) async {
    final PaystackActivationController activator =
        ref.read(paystackActivationControllerProvider.notifier);
    final bool ok = await activator.activate(context: context, plan: plan);
    if (!mounted) return;
    if (!ok) {
      AppNotifier.error(
        message: ref.read(paystackActivationControllerProvider).error ??
            "Couldn't activate your plan. Try again in a moment.",
      );
      return;
    }
    await ref.read(subscriptionControllerProvider.notifier).refresh();
    if (!mounted) return;
    AppNotifier.success(message: 'Drivio Pro active. Welcome back.');
    AppNavigation.replaceAll<void>(AppRoutes.home);
  }

  Future<void> _onSubmitTierSwitch(SubscriptionPlan target) async {
    final SubscriptionState subState =
        ref.read(subscriptionControllerProvider);
    final Subscription? sub = subState.subscription;
    final SubscriptionPlan? currentPlan = subState.featuredPlan;

    // Guard: we should never land here without an active subscription
    // and a current plan, but the controller can't *prove* it, so we
    // fail soft.
    if (sub == null || currentPlan == null) {
      AppNotifier.error(
        message:
            "Couldn't find your current plan. Try again in a moment.",
      );
      return;
    }

    final bool confirmed = await ConfirmTierSwitchSheet.show(
      context: context,
      current: currentPlan,
      target: target,
      currentPeriodEnd: sub.currentPeriodEnd ?? sub.trialEndsAt,
    );
    if (!mounted || !confirmed) return;

    final bool ok = await ref
        .read(pickPlanControllerProvider.notifier)
        .queueSwitch(subscriptionId: sub.id, targetPlanCode: target.code);
    if (!mounted) return;

    if (!ok) {
      AppNotifier.error(
        message: ref.read(pickPlanControllerProvider).error ??
            "Couldn't queue your switch. Try again in a moment.",
      );
      return;
    }

    await ref.read(subscriptionControllerProvider.notifier).refresh();
    if (!mounted) return;
    AppNotifier.success(
      message: 'Switch queued. ${target.interval.tierName} kicks in '
          'at your next renewal.',
    );
    AppNavigation.pop();
  }

  @override
  Widget build(BuildContext context) {
    final PickPlanState state = ref.watch(pickPlanControllerProvider);
    final PaystackActivationState activation =
        ref.watch(paystackActivationControllerProvider);

    final Subscription? sub =
        ref.watch(subscriptionControllerProvider).subscription;

    return ScreenScaffold(
      bottomBar: _Cta(
        plan: state.selectedTier,
        subscription: sub,
        isSubmitting: activation.isProcessing || state.isSubmitting,
        onPressed: _onSubmit,
      ),
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        slivers: <Widget>[
          SliverToBoxAdapter(
            child: _Header(intent: state.intent),
          ),
          if (state.isLoading)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(child: CircularProgressIndicator()),
            )
          else if (!state.hasTiers)
            SliverToBoxAdapter(child: _EmptyState(message: state.error)),
          if (state.hasTiers) ...<Widget>[
            if (state.recommendation != null)
              SliverToBoxAdapter(
                child: _Animated(
                  delayMs: 120,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 4, 24, 18),
                    child: RecommendationBanner(
                      recommendation: state.recommendation!,
                    ),
                  ),
                ),
              ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
              sliver: SliverList.separated(
                separatorBuilder: (BuildContext _, int _) =>
                    const SizedBox(height: 12),
                itemCount: state.tiers.length,
                itemBuilder: (BuildContext context, int i) {
                  final SubscriptionPlan plan = state.tiers[i];
                  final bool isSelected = state.selectedTierCode == plan.code;
                  final bool isRecommended =
                      state.recommendation?.tierCode == plan.code;
                  final bool isCurrent =
                      state.currentTierCode == plan.code &&
                          state.intent == PickPlanIntent.tierSwitch;
                  return _Animated(
                    delayMs: 220 + (i * 110),
                    child: TierCard(
                      plan: plan,
                      selected: isSelected,
                      recommended: isRecommended,
                      current: isCurrent,
                      onTap: () => ref
                          .read(pickPlanControllerProvider.notifier)
                          .selectTier(plan.code),
                    ),
                  );
                },
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 4, 24, 16),
                child: Text(
                  'Switch anytime. Changes apply at your next renewal.',
                  style: AppTextStyles.captionSm.copyWith(
                    color: context.textMuted,
                    height: 1.4,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Page header: literary title in Marcellus (via screenTitle token),
/// quiet supporting paragraph in body sans. Optional back button when
/// the driver isn't hard-blocked.
class _Header extends StatelessWidget {
  const _Header({required this.intent});

  final PickPlanIntent intent;

  @override
  Widget build(BuildContext context) {
    final bool showBack = intent != PickPlanIntent.reactivation;
    final String title = switch (intent) {
      PickPlanIntent.trialChoice => 'Pick your plan.',
      PickPlanIntent.reactivation => 'Pick your plan.',
      PickPlanIntent.tierSwitch => 'Change your plan.',
    };
    final String sub = switch (intent) {
      PickPlanIntent.trialChoice =>
        'Three ways to stay on Drivio Pro. You can switch any time.',
      PickPlanIntent.reactivation =>
        'Get back on the marketplace. Pick the cadence that fits.',
      PickPlanIntent.tierSwitch =>
        'Your current plan stays active until renewal. Your new pick kicks in then.',
    };
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              if (showBack)
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: BackButtonBox(
                    onTap: () => AppNavigation.pop(),
                  ),
                ),
              const Spacer(),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            title,
            style: AppTextStyles.screenTitle.copyWith(color: context.text),
          ),
          const SizedBox(height: 10),
          Text(
            sub,
            style: AppTextStyles.bodySm.copyWith(
              color: context.textDim,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: context.border),
        ),
        child: Row(
          children: <Widget>[
            Icon(Icons.error_outline_rounded, size: 18, color: context.red),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message ?? "Couldn't load plans. Pull down to retry.",
                style: AppTextStyles.bodySm.copyWith(color: context.text),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Sticky CTA — mirrors the three submit paths in `_onSubmit`:
///   • no sub or hard-blocked → pay today
///   • trialing → lock in for after trial (no charge today)
///   • active/past_due → queue switch at next renewal (no charge today)
/// One coral primary button, one micro footer line.
class _Cta extends StatelessWidget {
  const _Cta({
    required this.plan,
    required this.subscription,
    required this.isSubmitting,
    required this.onPressed,
  });

  final SubscriptionPlan? plan;
  final Subscription? subscription;
  final bool isSubmitting;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final bool hasPlan = plan != null;
    final String label;
    final String fineprint;

    if (!hasPlan) {
      label = 'Pick a plan to continue';
      fineprint = '';
    } else if (isSubmitting) {
      label = 'Processing…';
      fineprint = '';
    } else {
      final SubscriptionStatus? status = subscription?.effectiveStatus;
      final bool chargeToday = status == null || status.isHardBlocked;
      final bool trialing = status == SubscriptionStatus.trialing;

      if (chargeToday) {
        // No sub, expired, or cancelled — paying today.
        label = 'Continue · pay ${NairaFormatter.format(plan!.priceNaira)} today';
        fineprint =
            '${plan!.interval.renewalCopy.capitalize()}. Cancel anytime.';
      } else if (trialing) {
        // Trial driver locking in a tier for trial-end.
        label = 'Lock in ${plan!.interval.tierName} for after trial';
        final DateTime? trialEnd = subscription?.trialEndsAt;
        fineprint = trialEnd == null
            ? 'No charge today. ${plan!.interval.tierName} starts when your '
                'trial ends.'
            : 'No charge today. ${plan!.interval.tierName} starts when your '
                'trial ends on ${_fmtShortDate(trialEnd)}.';
      } else {
        // Active / past_due — queue a mid-cycle tier switch.
        label = 'Queue switch to ${plan!.interval.tierName}';
        fineprint = 'No charge today. ${plan!.interval.tierName} kicks in '
            'at your next renewal.';
      }
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
      decoration: BoxDecoration(
        color: context.bg,
        border: Border(top: BorderSide(color: context.border)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          DrivioButton(
            label: label,
            disabled: !hasPlan || isSubmitting,
            onPressed: onPressed,
          ),
          if (fineprint.isNotEmpty) ...<Widget>[
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
        ],
      ),
    );
  }
}

/// Lightweight staggered fade-in + lift, used for the recommendation
/// banner and each tier card so the page composes on first paint in a
/// calm cascade — 120ms apart, easeOutQuart, 16pt lift. No springs.
class _Animated extends StatelessWidget {
  const _Animated({required this.child, required this.delayMs});

  final Widget child;
  final int delayMs;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: Duration(milliseconds: 360 + delayMs),
      curve: Interval(
        delayMs / (360 + delayMs),
        1,
        curve: Curves.easeOutQuart,
      ),
      builder: (BuildContext _, double t, Widget? c) => Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(0, (1 - t) * 16),
          child: c,
        ),
      ),
      child: child,
    );
  }
}

extension on String {
  String capitalize() =>
      isEmpty ? this : '${this[0].toUpperCase()}${substring(1)}';
}

/// "Aug 12" style short date for the trial-end fineprint. Matches the
/// format used on subscription manage and the expired edge state, so the
/// driver sees the same date shape everywhere their trial is referenced.
String _fmtShortDate(DateTime d) {
  const List<String> months = <String>[
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  return '${months[d.month - 1]} ${d.day}';
}
