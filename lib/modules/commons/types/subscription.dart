enum SubscriptionStatus {
  trialing,
  active,
  pastDue,
  cancelled,
  expired;

  static SubscriptionStatus fromWire(String wire) {
    switch (wire) {
      case 'active':
        return SubscriptionStatus.active;
      case 'past_due':
        return SubscriptionStatus.pastDue;
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
  /// Paystack grace and still unlocks; expired/cancelled hard-block.
  bool get unlocksMarketplace =>
      this == SubscriptionStatus.trialing ||
      this == SubscriptionStatus.active ||
      this == SubscriptionStatus.pastDue;

  bool get isHardBlocked =>
      this == SubscriptionStatus.expired ||
      this == SubscriptionStatus.cancelled;
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
    this.paystackSubscriptionCode,
  });

  final String id;
  final String driverId;
  final String? planId;
  final SubscriptionStatus status;
  final DateTime? trialEndsAt;
  final DateTime? currentPeriodStart;
  final DateTime? currentPeriodEnd;
  final String? paystackSubscriptionCode;
  final DateTime createdAt;

  /// Days remaining in the current period (or trial). Null if no period set.
  int? get daysRemaining {
    final DateTime? end = currentPeriodEnd ?? trialEndsAt;
    if (end == null) return null;
    final Duration delta = end.difference(DateTime.now());
    if (delta.isNegative) return 0;
    return delta.inHours ~/ 24;
  }

  bool get isTrialing => status == SubscriptionStatus.trialing;

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
      paystackSubscriptionCode:
          json['paystack_subscription_code'] as String?,
      createdAt: parse(json['created_at'])!,
    );
  }
}
