import 'package:drivio_driver/modules/commons/types/subscription.dart';

abstract class SubscriptionRepository {
  /// The driver's current subscription, if any.
  Future<Subscription?> getMySubscription();

  /// Active plans available for activation/upgrade.
  Future<List<SubscriptionPlan>> listActivePlans();

  /// Dev-mode shortcut: marks the driver's subscription as paid+active on
  /// the chosen [planCode] tier for one full cycle (24h / 7d / 30d
  /// depending on the plan's `interval_seconds`). Calls the
  /// `activate_subscription_dev_mode(p_plan_code text)` SQL function.
  ///
  /// [planCode] defaults to `drivio_pro_monthly` for backwards-compatible
  /// callers; the paywall passes the driver's actual selection.
  /// Returns the new status string.
  Future<String?> activateSubscriptionDevMode({String? planCode});

  /// Flip the driver's active or trialing subscription to `paused`.
  /// The server stamps `paused_at = now()` and freezes the period
  /// clock; on resume the endpoints shift forward by the elapsed
  /// pause duration so paid days are preserved.
  ///
  /// Throws if there's no subscription, the status isn't pause-eligible,
  /// or the driver has an active trip in flight.
  Future<void> pauseMine();

  /// Restore the prior status (`active` or `trialing`) and shift the
  /// period endpoints forward by the time spent paused. Throws if the
  /// subscription isn't currently paused.
  Future<void> resumeMine();

  /// Driver's recent activity, used by the Pick a Plan recommendation
  /// engine to suggest a tier ("you bid on 67 of 90 days → Weekly").
  ///
  /// Returns a map with:
  ///   - `active_days`: distinct days the driver submitted at least one
  ///     bid in the observed window
  ///   - `observed_days`: length of the observation window, in days
  ///
  /// Defaults to `{'active_days': 0, 'observed_days': 0}` when there's
  /// no history (brand-new driver). Implementation calls the
  /// `get_my_trial_activity` SQL function.
  Future<Map<String, int>> getMyTrialActivity();

  /// Queue a tier switch. The new tier activates at the next renewal
  /// anniversary. No mid-cycle proration; no immediate charge.
  ///
  /// Throws if the subscription is expired/cancelled, or the target
  /// plan code doesn't exist, or it equals the current plan.
  Future<void> queueTierSwitch({
    required String subscriptionId,
    required String targetPlanCode,
    String? reason,
  });

  /// Cancel a queued tier switch. Renewal proceeds on the current plan.
  /// Throws when there's no queued switch.
  Future<void> cancelPendingTierSwitch({required String subscriptionId});
}
