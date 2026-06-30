import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:drivio_driver/modules/commons/data/payout_account_repository.dart';
import 'package:drivio_driver/modules/commons/data/wallet_repository.dart';
import 'package:drivio_driver/modules/commons/data/withdrawal_repository.dart';
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
    required WithdrawalRepository withdrawals,
  })  : _payoutAccounts = payoutAccounts,
        _wallet = wallet,
        _withdrawals = withdrawals,
        super(const PayoutAccountState()) {
    _hydrate();
  }

  final PayoutAccountRepository _payoutAccounts;
  final WalletRepository _wallet;
  final WithdrawalRepository _withdrawals;

  Future<void> refresh() => _hydrate();

  /// Load the Nigerian bank list for the picker. Best-effort: returns an
  /// empty list on failure so the sheet can show its own error.
  Future<List<PaystackBank>> loadBanks() => _withdrawals.listBanks();

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
        error: "Couldn't load your payment info. Pull down to retry.",
      );
    }
  }

  /// Save (or replace) the driver's payout account. The client no longer
  /// writes the row directly — it calls `driver-payout-recipient`, which
  /// resolves the account with Paystack, mints the transfer recipient,
  /// and persists the row server-side. We then re-load it so the rendered
  /// row matches exactly what was stored (masked number, confirmed name,
  /// recipient code). Returns the server-confirmed account name on
  /// success, or null on failure (with [state.error] set to the friendly
  /// server message).
  Future<String?> saveAccount({
    required String bankName,
    required String bankCode,
    required String accountNumber,
  }) async {
    state = state.copyWith(isSaving: true, clearError: true);
    try {
      final PayoutRecipientResult recipient =
          await _withdrawals.createPayoutRecipient(
        accountNumber: accountNumber,
        bankCode: bankCode,
        bankName: bankName,
      );
      // Re-read the persisted row so UI reflects the server's source of
      // truth (incl. the freshly-minted recipient code).
      final PayoutAccount? saved = await _payoutAccounts.getMyPayoutAccount();
      if (!mounted) return null;
      state = state.copyWith(
        account: saved,
        clearAccount: saved == null,
        isSaving: false,
      );
      return recipient.accountName;
    } on WithdrawalException catch (e) {
      if (!mounted) return null;
      state = state.copyWith(isSaving: false, error: e.message);
      return null;
    } catch (_) {
      if (!mounted) return null;
      state = state.copyWith(
        isSaving: false,
        error: "Couldn't save bank details. Try again in a moment.",
      );
      return null;
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
        error: "Couldn't remove your bank details. Try again in a moment.",
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
    withdrawals: locator<WithdrawalRepository>(),
  ),
);
