import 'package:drivio_driver/modules/commons/types/subscription.dart';

abstract class SubscriptionRepository {
  /// The driver's current subscription, if any.
  Future<Subscription?> getMySubscription();

  /// Active plans available for activation/upgrade.
  Future<List<SubscriptionPlan>> listActivePlans();

  /// Dev-mode shortcut: marks the driver's subscription as paid+active for
  /// 30 days. Calls the `activate_subscription_dev_mode` SQL function.
  /// Returns the new status string.
  Future<String?> activateSubscriptionDevMode();

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
}
