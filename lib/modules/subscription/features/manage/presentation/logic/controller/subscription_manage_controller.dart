import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:drivio_driver/modules/commons/data/wallet_repository.dart';
import 'package:drivio_driver/modules/commons/di/di.dart';
import 'package:drivio_driver/modules/commons/types/wallet.dart';

class SubscriptionManageState {
  const SubscriptionManageState({
    this.charges = const <LedgerEntry>[],
    this.isLoading = true,
    this.error,
  });

  /// Subscription debits from the wallet ledger — the "billing
  /// history" rows on this page. Filtered to `subscription_debit`
  /// only; the listing limit is generous (50) and the page renders
  /// the most recent N.
  final List<LedgerEntry> charges;
  final bool isLoading;
  final String? error;

  SubscriptionManageState copyWith({
    List<LedgerEntry>? charges,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return SubscriptionManageState(
      charges: charges ?? this.charges,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// Owns the billing-history slice of the Subscription Manage page.
/// The headline subscription state (plan + status + period) comes
/// from the existing `subscriptionControllerProvider`, so this
/// controller stays narrowly scoped to "what charges happened?".
class SubscriptionManageController
    extends StateNotifier<SubscriptionManageState> {
  SubscriptionManageController(this._wallet)
      : super(const SubscriptionManageState()) {
    _hydrate();
  }

  final WalletRepository _wallet;

  Future<void> refresh() => _hydrate();

  Future<void> _hydrate() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final List<LedgerEntry> ledger =
          await _wallet.listMyLedger(limit: 100);
      if (!mounted) return;
      state = state.copyWith(
        charges: ledger
            .where((LedgerEntry e) => e.kind == LedgerKind.subscriptionDebit)
            .toList(growable: false),
        isLoading: false,
      );
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(
        isLoading: false,
        error: 'Could not load billing history.',
      );
    }
  }
}

final StateNotifierProvider<SubscriptionManageController,
        SubscriptionManageState> subscriptionManageControllerProvider =
    StateNotifierProvider<SubscriptionManageController,
        SubscriptionManageState>(
  (Ref _) =>
      SubscriptionManageController(locator<WalletRepository>()),
);
