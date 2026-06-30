/// Client-side mirror of the server's withdrawal service-fee tiers.
/// MUST stay in sync with `driver-withdraw` — the server is authoritative
/// and recomputes the fee, but we show a live breakdown before submit.
///
/// All amounts are in kobo (minor units). The driver enters the amount
/// they RECEIVE; the fee is added on top, so what leaves their balance is
/// `amount + fee`.
class WithdrawalFee {
  WithdrawalFee._();

  /// Minimum withdrawable amount the driver receives: ₦1,000.
  static const int minAmountMinor = 100000;

  /// Service fee (kobo) charged on top of [amountMinor]. Tiers exactly
  /// match the server:
  ///   amount <= ₦5,000   → ₦10
  ///   amount <= ₦50,000  → ₦25
  ///   else               → ₦50
  static int feeMinorFor(int amountMinor) {
    if (amountMinor <= 500000) return 1000;
    if (amountMinor <= 5000000) return 2500;
    return 5000;
  }

  /// Total debited from the wallet: amount + service fee.
  static int totalMinorFor(int amountMinor) =>
      amountMinor + feeMinorFor(amountMinor);
}
