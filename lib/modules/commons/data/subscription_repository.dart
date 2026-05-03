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
}
