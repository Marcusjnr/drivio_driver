import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:drivio_driver/modules/commons/data/payout_account_repository.dart';
import 'package:drivio_driver/modules/commons/data/wallet_repository.dart';
import 'package:drivio_driver/modules/commons/di/di.dart';
import 'package:drivio_driver/modules/commons/types/payout_account.dart';
import 'package:drivio_driver/modules/commons/types/wallet.dart';

class PayoutAccountState {
  const PayoutAccountState({
    this.account,
    this.subscriptionCharges = const <LedgerEntry>[],
    this.isLoading = true,
    this.isSaving = false,
    this.error,
  });

  final PayoutAccount? account;

  /// Subscription debits from the wallet ledger — drives the "billing
  /// history" list. We filter to subscription entries only on the
  /// client because the existing `listMyLedger` endpoint returns all
  /// ledger kinds and we don't want to multiply the surface area for
  /// what's a small in-memory filter.
  final List<LedgerEntry> subscriptionCharges;

  final bool isLoading;
  final bool isSaving;
  final String? error;

  PayoutAccountState copyWith({
    PayoutAccount? account,
    bool clearAccount = false,
    List<LedgerEntry>? subscriptionCharges,
    bool? isLoading,
    bool? isSaving,
    String? error,
    bool clearError = false,
  }) {
    return PayoutAccountState(
      account: clearAccount ? null : (account ?? this.account),
      subscriptionCharges: subscriptionCharges ?? this.subscriptionCharges,
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// Owns the Manage Payment page. Combines the payout account record
/// (one row per driver) with the subscription-debit ledger entries
/// that make up "billing history".
class PayoutAccountController extends StateNotifier<PayoutAccountState> {
  PayoutAccountController({
    required PayoutAccountRepository payoutAccounts,
    required WalletRepository wallet,
  })  : _payoutAccounts = payoutAccounts,
        _wallet = wallet,
        super(const PayoutAccountState()) {
    _hydrate();
  }

  final PayoutAccountRepository _payoutAccounts;
  final WalletRepository _wallet;

  Future<void> refresh() => _hydrate();

  Future<void> _hydrate() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final List<dynamic> r = await Future.wait<dynamic>(<Future<dynamic>>[
        _payoutAccounts.getMyPayoutAccount(),
        // Pull a generous slice; the page caps to the most recent N.
        _wallet.listMyLedger(limit: 200),
      ]);
      if (!mounted) return;
      final PayoutAccount? acct = r[0] as PayoutAccount?;
      final List<LedgerEntry> ledger = r[1] as List<LedgerEntry>;
      state = state.copyWith(
        account: acct,
        clearAccount: acct == null,
        subscriptionCharges: ledger
            .where((LedgerEntry e) => e.kind == LedgerKind.subscriptionDebit)
            .toList(growable: false),
        isLoading: false,
      );
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(
        isLoading: false,
        error: 'Could not load payment info.',
      );
    }
  }

  /// Save a new payout account (or replace the existing one). UI
  /// optimistically reloads the row from the server so what's
  /// rendered always matches what's persisted (incl. the masked
  /// account number the server normalised).
  Future<bool> saveAccount({
    required String bankName,
    required String accountNumber,
    required String accountName,
  }) async {
    state = state.copyWith(isSaving: true, clearError: true);
    try {
      final PayoutAccount saved =
          await _payoutAccounts.upsertMyPayoutAccount(
        bankName: bankName,
        accountNumber: accountNumber,
        accountName: accountName,
      );
      if (!mounted) return false;
      state = state.copyWith(account: saved, isSaving: false);
      return true;
    } catch (e) {
      if (!mounted) return false;
      state = state.copyWith(
        isSaving: false,
        error: 'Could not save bank details: $e',
      );
      return false;
    }
  }

  Future<bool> removeAccount() async {
    if (state.account == null) return true;
    state = state.copyWith(isSaving: true, clearError: true);
    try {
      await _payoutAccounts.removeMyPayoutAccount();
      if (!mounted) return false;
      state = state.copyWith(clearAccount: true, isSaving: false);
      return true;
    } catch (e) {
      if (!mounted) return false;
      state = state.copyWith(
        isSaving: false,
        error: 'Could not remove bank details.',
      );
      return false;
    }
  }
}

final StateNotifierProvider<PayoutAccountController, PayoutAccountState>
    payoutAccountControllerProvider =
    StateNotifierProvider<PayoutAccountController, PayoutAccountState>(
  (Ref _) => PayoutAccountController(
    payoutAccounts: locator<PayoutAccountRepository>(),
    wallet: locator<WalletRepository>(),
  ),
);
