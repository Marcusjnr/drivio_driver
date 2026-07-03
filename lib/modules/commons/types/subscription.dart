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
  day,
  week,
  month;

  static SubscriptionInterval fromWire(String wire) {
    switch (wire) {
      case 'day':
      case 'daily':
        return SubscriptionInterval.day;
      case 'week':
      case 'weekly':
        return SubscriptionInterval.week;
      case 'month':
      case 'monthly':
      default:
        return SubscriptionInterval.month;
    }
  }

  /// Short cadence label used inline next to the price ("/ day", "/ week").
  String get label {
    switch (this) {
      case SubscriptionInterval.day:
        return 'day';
      case SubscriptionInterval.week:
        return 'week';
      case SubscriptionInterval.month:
        return 'month';
    }
  }

  /// Title-case tier name ("Daily", "Weekly", "Monthly") — used in pills,
  /// card headers, and admin tools.
  String get tierName {
    switch (this) {
      case SubscriptionInterval.day:
        return 'Daily';
      case SubscriptionInterval.week:
        return 'Weekly';
      case SubscriptionInterval.month:
        return 'Monthly';
    }
  }

  /// One-line "auto-renews every X" copy for explainers and CTAs.
  String get renewalCopy {
    switch (this) {
      case SubscriptionInterval.day:
        return 'auto-renews every 24 hours';
      case SubscriptionInterval.week:
        return 'auto-renews every 7 days';
      case SubscriptionInterval.month:
        return 'auto-renews every 30 days';
    }
  }

  /// Approximate number of days in one billing cycle — used to compute
  /// the "≈ ₦X/month if used N days" worst-case equivalency in the tier
  /// comparison UI. Anniversary renewal, not calendar.
  int get daysInCycle {
    switch (this) {
      case SubscriptionInterval.day:
        return 1;
      case SubscriptionInterval.week:
        return 7;
      case SubscriptionInterval.month:
        return 30;
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
    this.intervalSeconds,
    this.graceSeconds,
  });

  final String id;
  final String code;
  final String name;
  final int priceMinor;
  final String currency;
  final SubscriptionInterval interval;

  /// Length of one billing cycle in seconds. Server-side authoritative;
  /// the client uses the [interval] enum for display but trusts this
  /// value for computing renewal anniversaries when present.
  final int? intervalSeconds;

  /// Grace window in seconds before a past-due subscription expires.
  /// Tier-aware: Daily ≈ 3600, Weekly ≈ 43200, Monthly ≈ 259200.
  final int? graceSeconds;

  /// Naira value of [priceMinor] (kobo / 100).
  int get priceNaira => priceMinor ~/ 100;

  /// Effective per-day naira cost in a full cycle. Kept as a helper for
  /// future per-day display (e.g., "~₦1,667/day" callout); not currently
  /// rendered.
  int get pricePerDayNaira => priceNaira ~/ interval.daysInCycle;

  /// One-line tagline used inside the tier card under the price.
  /// Calm, never salesy; describes the tier's job-to-be-done.
  String get valueFraming {
    switch (interval) {
      case SubscriptionInterval.day:
        return 'Pay only when you drive';
      case SubscriptionInterval.week:
        return 'Save vs daily for most drivers, most weeks';
      case SubscriptionInterval.month:
        return 'Cheapest per-day rate';
    }
  }

  factory SubscriptionPlan.fromJson(Map<String, dynamic> json) {
    return SubscriptionPlan(
      id: json['id'] as String,
      code: json['code'] as String,
      name: json['name'] as String,
      priceMinor: (json['price_minor'] as num).toInt(),
      currency: json['currency'] as String,
      interval: SubscriptionInterval.fromWire(json['interval'] as String),
      intervalSeconds:
          json['interval_seconds'] == null
              ? null
              : (json['interval_seconds'] as num).toInt(),
      graceSeconds:
          json['grace_seconds'] == null
              ? null
              : (json['grace_seconds'] as num).toInt(),
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
    this.pendingPlanId,
    this.trialEndsAt,
    this.currentPeriodStart,
    this.currentPeriodEnd,
    this.pausedAt,
    this.paystackSubscriptionCode,
  });

  final String id;
  final String driverId;
  final String? planId;

  /// When non-null, the driver has queued a tier switch. The new tier
  /// activates at the next renewal anniversary. No mid-cycle proration.
  final String? pendingPlanId;

  final SubscriptionStatus status;
  final DateTime? trialEndsAt;
  final DateTime? currentPeriodStart;
  final DateTime? currentPeriodEnd;
  final DateTime? pausedAt;
  final String? paystackSubscriptionCode;
  final DateTime createdAt;

  bool get hasPendingSwitch => pendingPlanId != null;

  /// Grace window after a paid period lapses before hard-blocking. The
  /// server derives the real value from the plan's grace_seconds; this
  /// client-side default only has to be no more generous than that.
  static const Duration _defaultGrace = Duration(days: 3);

  /// Status derived from the timestamps. The server has no scheduler
  /// flipping lapsed rows, so the stored status alone can lie: a trial
  /// past `trialEndsAt` reads as expired, and a paid period past
  /// `currentPeriodEnd` reads as pastDue inside the grace window and
  /// expired beyond it. Server RPCs (`is_driver_active`) apply the same
  /// derivation — this keeps the UI gates in agreement with them.
  SubscriptionStatus get effectiveStatus {
    final DateTime now = DateTime.now();
    switch (status) {
      case SubscriptionStatus.trialing:
        final DateTime? end = trialEndsAt ?? currentPeriodEnd;
        if (end != null && end.isBefore(now)) {
          return SubscriptionStatus.expired;
        }
        return status;
      case SubscriptionStatus.active:
      case SubscriptionStatus.pastDue:
        final DateTime? end = currentPeriodEnd;
        if (end == null) {
          return status;
        }
        if (end.add(_defaultGrace).isBefore(now)) {
          return SubscriptionStatus.expired;
        }
        if (end.isBefore(now)) {
          return SubscriptionStatus.pastDue;
        }
        return status;
      case SubscriptionStatus.paused:
      case SubscriptionStatus.cancelled:
      case SubscriptionStatus.expired:
        return status;
    }
  }

  /// Gating conveniences — always derived, never the raw stored status.
  bool get unlocksMarketplace => effectiveStatus.unlocksMarketplace;
  bool get isHardBlocked => effectiveStatus.isHardBlocked;
  bool get canPause => effectiveStatus.canPause;

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

  bool get isTrialing => effectiveStatus == SubscriptionStatus.trialing;
  bool get isPaused => effectiveStatus == SubscriptionStatus.paused;

  factory Subscription.fromJson(Map<String, dynamic> json) {
    DateTime? parse(Object? v) =>
        v == null ? null : DateTime.parse(v as String);
    return Subscription(
      id: json['id'] as String,
      driverId: json['driver_id'] as String,
      planId: json['plan_id'] as String?,
      pendingPlanId: json['pending_plan_id'] as String?,
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
