enum SubscriptionStatus {
  trialing,
  active,
  pastDue,
  paused,
  cancelled,
  expired;

  static SubscriptionStatus fromWire(String wire) {
    switch (wire) {
      case 'active':
        return SubscriptionStatus.active;
      case 'past_due':
        return SubscriptionStatus.pastDue;
      case 'paused':
        return SubscriptionStatus.paused;
      case 'cancelled':
        return SubscriptionStatus.cancelled;
      case 'expired':
        return SubscriptionStatus.expired;
      case 'trialing':
      default:
        return SubscriptionStatus.trialing;
    }
  }

  /// Per spec: trialing/active are fully unlocked; past_due is in 3-day
  /// Paystack grace and still unlocks; paused soft-blocks (the driver
  /// chose to step away — resume restores the prior state); expired/
  /// cancelled hard-block.
  bool get unlocksMarketplace =>
      this == SubscriptionStatus.trialing ||
      this == SubscriptionStatus.active ||
      this == SubscriptionStatus.pastDue;

  bool get isHardBlocked =>
      this == SubscriptionStatus.expired ||
      this == SubscriptionStatus.cancelled;

  /// True only when the driver themselves stepped away. The paywall
  /// gate routes paused users to the manage screen (where the resume
  /// control lives) instead of trying to sell them a fresh plan.
  bool get isPaused => this == SubscriptionStatus.paused;

  /// Pause is offered while a subscription is in a normal "running"
  /// state. Past-due / cancelled / expired need a payment action, not
  /// a pause.
  bool get canPause =>
      this == SubscriptionStatus.trialing ||
      this == SubscriptionStatus.active;
}

enum SubscriptionInterval {
  month,
  quarter,
  year;

  static SubscriptionInterval fromWire(String wire) {
    switch (wire) {
      case 'quarter':
        return SubscriptionInterval.quarter;
      case 'year':
        return SubscriptionInterval.year;
      case 'month':
      default:
        return SubscriptionInterval.month;
    }
  }

  String get label {
    switch (this) {
      case SubscriptionInterval.month:
        return 'month';
      case SubscriptionInterval.quarter:
        return 'quarter';
      case SubscriptionInterval.year:
        return 'year';
    }
  }
}

class SubscriptionPlan {
  const SubscriptionPlan({
    required this.id,
    required this.code,
    required this.name,
    required this.priceMinor,
    required this.currency,
    required this.interval,
  });

  final String id;
  final String code;
  final String name;
  final int priceMinor;
  final String currency;
  final SubscriptionInterval interval;

  factory SubscriptionPlan.fromJson(Map<String, dynamic> json) {
    return SubscriptionPlan(
      id: json['id'] as String,
      code: json['code'] as String,
      name: json['name'] as String,
      priceMinor: (json['price_minor'] as num).toInt(),
      currency: json['currency'] as String,
      interval: SubscriptionInterval.fromWire(json['interval'] as String),
    );
  }
}

class Subscription {
  const Subscription({
    required this.id,
    required this.driverId,
    required this.status,
    required this.createdAt,
    this.planId,
    this.trialEndsAt,
    this.currentPeriodStart,
    this.currentPeriodEnd,
    this.pausedAt,
    this.paystackSubscriptionCode,
  });

  final String id;
  final String driverId;
  final String? planId;
  final SubscriptionStatus status;
  final DateTime? trialEndsAt;
  final DateTime? currentPeriodStart;
  final DateTime? currentPeriodEnd;
  final DateTime? pausedAt;
  final String? paystackSubscriptionCode;
  final DateTime createdAt;

  /// Days remaining in the current period (or trial). Null if no period set.
  /// Frozen at the value captured when the driver paused — the server
  /// shifts the period endpoints forward on resume so this number is
  /// preserved across pauses without any client-side fudge.
  int? get daysRemaining {
    final DateTime? end = currentPeriodEnd ?? trialEndsAt;
    if (end == null) return null;
    final DateTime reference = pausedAt ?? DateTime.now();
    final Duration delta = end.difference(reference);
    if (delta.isNegative) return 0;
    return delta.inHours ~/ 24;
  }

  bool get isTrialing => status == SubscriptionStatus.trialing;
  bool get isPaused => status == SubscriptionStatus.paused;

  factory Subscription.fromJson(Map<String, dynamic> json) {
    DateTime? parse(Object? v) =>
        v == null ? null : DateTime.parse(v as String);
    return Subscription(
      id: json['id'] as String,
      driverId: json['driver_id'] as String,
      planId: json['plan_id'] as String?,
      status: SubscriptionStatus.fromWire(json['status'] as String),
      trialEndsAt: parse(json['trial_ends_at']),
      currentPeriodStart: parse(json['current_period_start']),
      currentPeriodEnd: parse(json['current_period_end']),
      pausedAt: parse(json['paused_at']),
      paystackSubscriptionCode:
          json['paystack_subscription_code'] as String?,
      createdAt: parse(json['created_at'])!,
    );
  }
}
