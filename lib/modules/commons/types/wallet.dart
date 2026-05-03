enum LedgerKind {
  tripCredit,
  payoutDebit,
  refund,
  adjustment,
  subscriptionDebit,
  unknown;

  String get wire {
    switch (this) {
      case LedgerKind.tripCredit:
        return 'trip_credit';
      case LedgerKind.payoutDebit:
        return 'payout_debit';
      case LedgerKind.refund:
        return 'refund';
      case LedgerKind.adjustment:
        return 'adjustment';
      case LedgerKind.subscriptionDebit:
        return 'subscription_debit';
      case LedgerKind.unknown:
        return 'unknown';
    }
  }

  static LedgerKind fromWire(String wire) {
    switch (wire) {
      case 'trip_credit':
        return LedgerKind.tripCredit;
      case 'payout_debit':
        return LedgerKind.payoutDebit;
      case 'refund':
        return LedgerKind.refund;
      case 'adjustment':
        return LedgerKind.adjustment;
      case 'subscription_debit':
        return LedgerKind.subscriptionDebit;
      default:
        return LedgerKind.unknown;
    }
  }

  /// True when the entry adds to the driver's balance (vs. removing).
  bool get isCredit => this == LedgerKind.tripCredit || this == LedgerKind.refund;
}

class Wallet {
  const Wallet({
    required this.driverId,
    required this.balanceMinor,
    required this.currency,
    required this.updatedAt,
  });

  final String driverId;
  final int balanceMinor;
  final String currency;
  final DateTime updatedAt;

  int get balanceNaira => balanceMinor ~/ 100;

  factory Wallet.fromJson(Map<String, dynamic> json) {
    return Wallet(
      driverId: json['driver_id'] as String,
      balanceMinor: (json['balance_minor'] as num).toInt(),
      currency: json['currency'] as String,
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }
}

class LedgerEntry {
  const LedgerEntry({
    required this.id,
    required this.driverId,
    required this.kind,
    required this.amountMinor,
    required this.currency,
    required this.createdAt,
    this.referenceId,
    this.description,
  });

  final String id;
  final String driverId;
  final LedgerKind kind;
  final int amountMinor;
  final String currency;
  final String? referenceId;
  final String? description;
  final DateTime createdAt;

  /// Signed naira amount: positive for credits, negative for debits.
  int get signedNaira =>
      (kind.isCredit ? amountMinor : -amountMinor) ~/ 100;

  factory LedgerEntry.fromJson(Map<String, dynamic> json) {
    return LedgerEntry(
      id: json['id'] as String,
      driverId: json['driver_id'] as String,
      kind: LedgerKind.fromWire(json['kind'] as String),
      amountMinor: (json['amount_minor'] as num).toInt(),
      currency: json['currency'] as String,
      referenceId: json['reference_id'] as String?,
      description: json['description'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

class EarningsSummary {
  const EarningsSummary({
    required this.tripCreditsMinor,
    required this.payoutsMinor,
    required this.netMinor,
    required this.tripCount,
    required this.windowStart,
  });

  final int tripCreditsMinor;
  final int payoutsMinor;
  final int netMinor;
  final int tripCount;
  final DateTime windowStart;

  int get tripCreditsNaira => tripCreditsMinor ~/ 100;
  int get netNaira => netMinor ~/ 100;

  factory EarningsSummary.fromJson(Map<String, dynamic> json) {
    return EarningsSummary(
      tripCreditsMinor: (json['trip_credits_minor'] as num?)?.toInt() ?? 0,
      payoutsMinor: (json['payouts_minor'] as num?)?.toInt() ?? 0,
      netMinor: (json['net_minor'] as num?)?.toInt() ?? 0,
      tripCount: (json['trip_count'] as num?)?.toInt() ?? 0,
      windowStart: DateTime.parse(json['window_start'] as String),
    );
  }
}

class DailyEarning {
  const DailyEarning({
    required this.day,
    required this.netMinor,
    required this.tripCount,
  });

  final DateTime day;
  final int netMinor;
  final int tripCount;

  int get netNaira => netMinor ~/ 100;

  factory DailyEarning.fromJson(Map<String, dynamic> json) {
    return DailyEarning(
      day: DateTime.parse(json['day'] as String),
      netMinor: (json['net_minor'] as num?)?.toInt() ?? 0,
      tripCount: (json['trip_count'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Monthly aggregation row used by the "year" tab on the earnings page.
/// `month` is the first day of the month at WAT midnight.
class MonthlyEarning {
  const MonthlyEarning({
    required this.month,
    required this.netMinor,
    required this.tripCount,
  });

  final DateTime month;
  final int netMinor;
  final int tripCount;

  int get netNaira => netMinor ~/ 100;

  factory MonthlyEarning.fromJson(Map<String, dynamic> json) {
    return MonthlyEarning(
      month: DateTime.parse(json['month'] as String),
      netMinor: (json['net_minor'] as num?)?.toInt() ?? 0,
      tripCount: (json['trip_count'] as num?)?.toInt() ?? 0,
    );
  }
}

class AcceptanceMetrics {
  const AcceptanceMetrics({
    required this.bidsSubmitted,
    required this.bidsWon,
    required this.bidsLost,
    required this.tripsAssigned,
    required this.tripsCompleted,
    required this.tripsCancelledByDriver,
  });

  final int bidsSubmitted;
  final int bidsWon;
  final int bidsLost;
  final int tripsAssigned;
  final int tripsCompleted;
  final int tripsCancelledByDriver;

  /// % of bids that won. Null when there's no data yet.
  double? get winRate {
    if (bidsSubmitted == 0) return null;
    return bidsWon / bidsSubmitted;
  }

  /// % of assigned trips the driver cancelled. Null when there's no data.
  double? get cancelRate {
    if (tripsAssigned == 0) return null;
    return tripsCancelledByDriver / tripsAssigned;
  }

  factory AcceptanceMetrics.fromJson(Map<String, dynamic> json) {
    return AcceptanceMetrics(
      bidsSubmitted: (json['bids_submitted'] as num?)?.toInt() ?? 0,
      bidsWon: (json['bids_won'] as num?)?.toInt() ?? 0,
      bidsLost: (json['bids_lost'] as num?)?.toInt() ?? 0,
      tripsAssigned: (json['trips_assigned'] as num?)?.toInt() ?? 0,
      tripsCompleted: (json['trips_completed'] as num?)?.toInt() ?? 0,
      tripsCancelledByDriver:
          (json['trips_cancelled_by_driver'] as num?)?.toInt() ?? 0,
    );
  }
}
