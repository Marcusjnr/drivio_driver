import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:drivio_driver/modules/commons/data/wallet_repository.dart';
import 'package:drivio_driver/modules/commons/di/di.dart';
import 'package:drivio_driver/modules/commons/types/wallet.dart';

/// Time window for the earnings page chart + headline metrics.
enum EarningsPeriod {
  week,
  month,
  year;

  /// Number of days to roll up for the daily/monthly RPCs and the
  /// summary window. Year uses monthly buckets — see [usesMonthlyBuckets].
  int get days {
    switch (this) {
      case EarningsPeriod.week:
        return 7;
      case EarningsPeriod.month:
        return 30;
      case EarningsPeriod.year:
        return 365;
    }
  }

  bool get usesMonthlyBuckets => this == EarningsPeriod.year;

  /// Header label shown above the chart.
  String get sectionLabel {
    switch (this) {
      case EarningsPeriod.week:
        return 'THIS WEEK';
      case EarningsPeriod.month:
        return 'THIS MONTH';
      case EarningsPeriod.year:
        return 'THIS YEAR';
    }
  }

  /// Footer phrase: "X trip(s) in last 7 days" / "30 days" / "365 days".
  String get tripFooterSuffix {
    switch (this) {
      case EarningsPeriod.week:
        return 'last 7 days';
      case EarningsPeriod.month:
        return 'last 30 days';
      case EarningsPeriod.year:
        return 'last 12 months';
    }
  }
}

class WalletState {
  const WalletState({
    this.wallet,
    this.entries = const <LedgerEntry>[],
    this.summary,
    this.daily = const <DailyEarning>[],
    this.monthly = const <MonthlyEarning>[],
    this.acceptance,
    this.period = EarningsPeriod.week,
    this.isLoading = false,
    this.isPeriodLoading = false,
    this.error,
  });

  final Wallet? wallet;
  final List<LedgerEntry> entries;
  final EarningsSummary? summary;

  /// Daily buckets — populated for week (7) and month (30) periods.
  final List<DailyEarning> daily;

  /// Monthly buckets — populated for year (12) period.
  final List<MonthlyEarning> monthly;

  final AcceptanceMetrics? acceptance;
  final EarningsPeriod period;
  final bool isLoading;

  /// True while a period switch is mid-flight; lets the chart show a
  /// faint loading state without blanking out the whole page.
  final bool isPeriodLoading;
  final String? error;

  int get balanceNaira => wallet?.balanceNaira ?? 0;
  int get periodNetNaira => summary?.netNaira ?? 0;
  int get periodTripCount => summary?.tripCount ?? 0;

  WalletState copyWith({
    Wallet? wallet,
    List<LedgerEntry>? entries,
    EarningsSummary? summary,
    List<DailyEarning>? daily,
    List<MonthlyEarning>? monthly,
    AcceptanceMetrics? acceptance,
    EarningsPeriod? period,
    bool? isLoading,
    bool? isPeriodLoading,
    String? error,
    bool clearError = false,
  }) {
    return WalletState(
      wallet: wallet ?? this.wallet,
      entries: entries ?? this.entries,
      summary: summary ?? this.summary,
      daily: daily ?? this.daily,
      monthly: monthly ?? this.monthly,
      acceptance: acceptance ?? this.acceptance,
      period: period ?? this.period,
      isLoading: isLoading ?? this.isLoading,
      isPeriodLoading: isPeriodLoading ?? this.isPeriodLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class WalletController extends StateNotifier<WalletState> {
  WalletController(this._repo) : super(const WalletState()) {
    _start();
  }

  final WalletRepository _repo;
  StreamSubscription<Wallet>? _walletSub;
  StreamSubscription<LedgerEntry>? _ledgerSub;

  Future<void> _start() async {
    await refresh();
    _walletSub = _repo.watchMyWallet().listen(
          (Wallet w) => state = state.copyWith(wallet: w),
          onError: (Object _) {/* swallowed; refresh covers gaps */},
        );
    _ledgerSub = _repo.watchMyLedger().listen(
          (LedgerEntry e) {
            // Prepend the new entry, drop any duplicate by id.
            final List<LedgerEntry> next = <LedgerEntry>[
              e,
              ...state.entries.where((LedgerEntry x) => x.id != e.id),
            ];
            state = state.copyWith(entries: next);
            // Refresh summary so the headline keeps up with new credits.
            unawaited(_refreshSummary());
          },
          onError: (Object _) {},
        );
  }

  Future<void> refresh() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final EarningsPeriod p = state.period;
      final List<dynamic> r = await Future.wait<dynamic>(<Future<dynamic>>[
        _repo.getMyWallet(),
        _repo.listMyLedger(),
        _repo.getEarningsSummary(days: p.days),
        if (p.usesMonthlyBuckets)
          _repo.getMonthlyEarnings(months: 12)
        else
          _repo.getDailyEarnings(days: p.days),
        _repo.getAcceptanceMetrics(days: p.days),
      ]);
      if (!mounted) return;
      state = state.copyWith(
        wallet: r[0] as Wallet?,
        entries: r[1] as List<LedgerEntry>,
        summary: r[2] as EarningsSummary,
        daily: p.usesMonthlyBuckets
            ? const <DailyEarning>[]
            : r[3] as List<DailyEarning>,
        monthly: p.usesMonthlyBuckets
            ? r[3] as List<MonthlyEarning>
            : const <MonthlyEarning>[],
        acceptance: r[4] as AcceptanceMetrics,
        isLoading: false,
        isPeriodLoading: false,
      );
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(
        isLoading: false,
        isPeriodLoading: false,
        error: 'Could not load earnings.',
      );
    }
  }

  /// Swap the active period and re-fetch the rolled-up RPCs. Wallet
  /// balance + ledger feed are period-agnostic and stay put.
  Future<void> setPeriod(EarningsPeriod next) async {
    if (state.period == next) return;
    state = state.copyWith(period: next, isPeriodLoading: true);
    await _refreshSummary();
    if (!mounted) return;
    state = state.copyWith(isPeriodLoading: false);
  }

  Future<void> _refreshSummary() async {
    try {
      final EarningsPeriod p = state.period;
      final List<dynamic> r = await Future.wait<dynamic>(<Future<dynamic>>[
        _repo.getEarningsSummary(days: p.days),
        if (p.usesMonthlyBuckets)
          _repo.getMonthlyEarnings(months: 12)
        else
          _repo.getDailyEarnings(days: p.days),
        _repo.getAcceptanceMetrics(days: p.days),
      ]);
      if (!mounted) return;
      state = state.copyWith(
        summary: r[0] as EarningsSummary,
        daily: p.usesMonthlyBuckets
            ? const <DailyEarning>[]
            : r[1] as List<DailyEarning>,
        monthly: p.usesMonthlyBuckets
            ? r[1] as List<MonthlyEarning>
            : const <MonthlyEarning>[],
        acceptance: r[2] as AcceptanceMetrics,
      );
    } catch (_) {/* best effort */}
  }

  @override
  void dispose() {
    _walletSub?.cancel();
    _ledgerSub?.cancel();
    super.dispose();
  }
}

final StateNotifierProvider<WalletController, WalletState>
    walletControllerProvider =
    StateNotifierProvider<WalletController, WalletState>(
  (Ref _) => WalletController(locator<WalletRepository>()),
);
