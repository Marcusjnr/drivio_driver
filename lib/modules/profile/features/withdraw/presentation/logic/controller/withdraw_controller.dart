import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:drivio_driver/modules/commons/analytics/analytics_events.dart';
import 'package:drivio_driver/modules/commons/analytics/mixpanel_service.dart';
import 'package:drivio_driver/modules/commons/data/payout_account_repository.dart';
import 'package:drivio_driver/modules/commons/data/wallet_repository.dart';
import 'package:drivio_driver/modules/commons/data/withdrawal_repository.dart';
import 'package:drivio_driver/modules/commons/di/di.dart';
import 'package:drivio_driver/modules/commons/types/payout_account.dart';
import 'package:drivio_driver/modules/commons/types/wallet.dart';
import 'package:drivio_driver/modules/commons/utils/withdrawal_fee.dart';

class WithdrawState {
  const WithdrawState({
    this.isLoading = true,
    this.isSubmitting = false,
    this.balanceMinor = 0,
    this.account,
    this.amountMinor = 0,
    this.error,
    this.successResult,
  });

  final bool isLoading;
  final bool isSubmitting;

  /// Withdrawable balance = the driver's wallet balance, in kobo.
  final int balanceMinor;

  /// The saved payout account, if any. Null means "add your bank first".
  final PayoutAccount? account;

  /// The amount (kobo) the driver wants to RECEIVE — what they typed.
  final int amountMinor;

  final String? error;

  /// Set once a withdrawal is accepted (status: processing).
  final WithdrawalResult? successResult;

  bool get hasPayoutAccount => account != null;

  int get feeMinor => WithdrawalFee.feeMinorFor(amountMinor);
  int get totalMinor => WithdrawalFee.totalMinorFor(amountMinor);

  /// True when the typed amount is a valid, submittable withdrawal:
  /// at least the minimum, and the total (amount + fee) fits the balance.
  bool get canSubmit {
    if (amountMinor < WithdrawalFee.minAmountMinor) return false;
    if (totalMinor > balanceMinor) return false;
    return true;
  }

  /// Inline validation message for the amount field, or null when valid /
  /// empty. Kept separate from [error] (which is for submit failures).
  String? get amountHint {
    if (amountMinor == 0) return null;
    if (amountMinor < WithdrawalFee.minAmountMinor) {
      return 'Minimum withdrawal is ₦1,000.';
    }
    if (totalMinor > balanceMinor) {
      return 'Amount plus the fee is more than your balance.';
    }
    return null;
  }

  WithdrawState copyWith({
    bool? isLoading,
    bool? isSubmitting,
    int? balanceMinor,
    PayoutAccount? account,
    bool clearAccount = false,
    int? amountMinor,
    String? error,
    bool clearError = false,
    WithdrawalResult? successResult,
  }) {
    return WithdrawState(
      isLoading: isLoading ?? this.isLoading,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      balanceMinor: balanceMinor ?? this.balanceMinor,
      account: clearAccount ? null : (account ?? this.account),
      amountMinor: amountMinor ?? this.amountMinor,
      error: clearError ? null : (error ?? this.error),
      successResult: successResult ?? this.successResult,
    );
  }
}

/// Drives the driver withdrawal screen: loads the withdrawable balance
/// (wallet) + the saved payout account, computes the live fee breakdown,
/// and submits to the `driver-withdraw` Edge Function.
class WithdrawController extends StateNotifier<WithdrawState> {
  WithdrawController({
    required WalletRepository wallet,
    required PayoutAccountRepository payoutAccounts,
    required WithdrawalRepository withdrawals,
    required MixpanelService analytics,
  })  : _wallet = wallet,
        _payoutAccounts = payoutAccounts,
        _withdrawals = withdrawals,
        _analytics = analytics,
        super(const WithdrawState()) {
    _hydrate();
  }

  final WalletRepository _wallet;
  final PayoutAccountRepository _payoutAccounts;
  final WithdrawalRepository _withdrawals;
  final MixpanelService _analytics;

  Future<void> refresh() => _hydrate();

  Future<void> _hydrate() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final List<dynamic> r = await Future.wait<dynamic>(<Future<dynamic>>[
        _wallet.getMyWallet(),
        _payoutAccounts.getMyPayoutAccount(),
      ]);
      if (!mounted) return;
      final Wallet? w = r[0] as Wallet?;
      final PayoutAccount? acct = r[1] as PayoutAccount?;
      state = state.copyWith(
        isLoading: false,
        balanceMinor: w?.balanceMinor ?? 0,
        account: acct,
        clearAccount: acct == null,
      );
    } catch (_) {
      if (!mounted) return;
      state = state.copyWith(
        isLoading: false,
        error: "Couldn't load your balance. Pull down to retry.",
      );
    }
  }

  /// Update the amount the driver wants to receive, in naira.
  void setAmountNaira(int naira) {
    state = state.copyWith(amountMinor: naira * 100, clearError: true);
  }

  Future<bool> submit() async {
    if (!state.canSubmit || state.isSubmitting) return false;

    final int amount = state.amountMinor;
    state = state.copyWith(isSubmitting: true, clearError: true);

    // Never track the exact amount — bucket into a band.
    _analytics.track(
      AnalyticsEvents.withdrawalRequested,
      properties: <String, dynamic>{'amount_band': _amountBand(amount)},
    );

    try {
      final WithdrawalResult result =
          await _withdrawals.withdraw(amountMinor: amount);
      if (!mounted) return false;
      _analytics.track(
        AnalyticsEvents.withdrawalSucceeded,
        properties: <String, dynamic>{'amount_band': _amountBand(amount)},
      );
      state = state.copyWith(isSubmitting: false, successResult: result);
      return true;
    } on WithdrawalException catch (e) {
      if (!mounted) return false;
      _analytics.track(
        AnalyticsEvents.withdrawalFailed,
        properties: <String, dynamic>{'failure_reason': e.errorKey},
      );
      state = state.copyWith(isSubmitting: false, error: e.message);
      return false;
    } catch (_) {
      if (!mounted) return false;
      _analytics.track(
        AnalyticsEvents.withdrawalFailed,
        properties: <String, dynamic>{'failure_reason': 'unknown'},
      );
      state = state.copyWith(
        isSubmitting: false,
        error: "Something went wrong. Please try again.",
      );
      return false;
    }
  }

  /// Coarse amount buckets (naira) for analytics — never the exact value.
  static String _amountBand(int amountMinor) {
    final int naira = amountMinor ~/ 100;
    if (naira < 5000) return '1k-5k';
    if (naira < 10000) return '5k-10k';
    if (naira < 25000) return '10k-25k';
    if (naira < 50000) return '25k-50k';
    if (naira < 100000) return '50k-100k';
    return '100k+';
  }
}

// autoDispose so a fresh visit re-hydrates (balance + payout account). A
// long-lived singleton would keep stale state — e.g. account == null from an
// earlier visit — and wrongly bounce the driver back to "add bank account"
// even after they've added one.
final AutoDisposeStateNotifierProvider<WithdrawController, WithdrawState>
    withdrawControllerProvider =
    StateNotifierProvider.autoDispose<WithdrawController, WithdrawState>(
  (Ref _) => WithdrawController(
    wallet: locator<WalletRepository>(),
    payoutAccounts: locator<PayoutAccountRepository>(),
    withdrawals: locator<WithdrawalRepository>(),
    analytics: locator<MixpanelService>(),
  ),
);
