import 'dart:async';

import 'package:drivio_driver/modules/commons/types/wallet.dart';

abstract class WalletRepository {
  /// The driver's wallet (creates lazily on first credit, so may not yet
  /// exist for a brand-new driver).
  Future<Wallet?> getMyWallet();

  /// Recent ledger entries, newest first.
  Future<List<LedgerEntry>> listMyLedger({int limit = 50});

  /// Aggregate earnings over the last [days] days.
  Future<EarningsSummary> getEarningsSummary({int days = 7});

  /// Per-day earnings buckets (oldest → newest) over the last [days].
  /// Lists every day in the window, even those with zero earnings, so
  /// charts can render evenly spaced bars.
  Future<List<DailyEarning>> getDailyEarnings({int days = 7});

  /// Per-month earnings buckets (oldest → newest) over the last
  /// [months]. Used by the year tab where 365 daily bars would be too
  /// dense; one bar per month keeps the chart legible.
  Future<List<MonthlyEarning>> getMonthlyEarnings({int months = 12});

  /// Bid acceptance + trip cancellation aggregates for the last [days].
  Future<AcceptanceMetrics> getAcceptanceMetrics({int days = 7});

  /// Realtime push when the wallets row changes — fires after trip
  /// completions, payouts, refunds, etc.
  Stream<Wallet> watchMyWallet();

  /// Realtime push of new ledger entries for this driver. Subscribers
  /// should append to the in-memory list.
  Stream<LedgerEntry> watchMyLedger();
}
