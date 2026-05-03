import 'package:drivio_driver/modules/commons/types/payout_account.dart';

abstract class PayoutAccountRepository {
  /// The driver's saved payout bank account, or null if they haven't
  /// added one yet.
  Future<PayoutAccount?> getMyPayoutAccount();

  /// Insert or replace the calling driver's payout account. The
  /// caller must have already collected/validated the account number
  /// off the Paystack resolve-account endpoint (or accepted manual
  /// entry).
  ///
  /// `accountNumber` is sent in full to the server which masks it
  /// down to the last 4 before storage. Bank code is no longer
  /// captured client-side — Paystack resolves the bank from the
  /// account number alone.
  Future<PayoutAccount> upsertMyPayoutAccount({
    required String bankName,
    required String accountNumber,
    required String accountName,
  });

  /// Delete the driver's saved payout account. Returns true if a row
  /// was actually removed.
  Future<bool> removeMyPayoutAccount();
}
