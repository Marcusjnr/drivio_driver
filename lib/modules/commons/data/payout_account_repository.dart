import 'package:drivio_driver/modules/commons/types/payout_account.dart';

abstract class PayoutAccountRepository {
  /// The driver's saved payout bank account, or null if they haven't
  /// added one yet.
  Future<PayoutAccount?> getMyPayoutAccount();

  // The payout account row is no longer written directly from the
  // client. Saving a bank account goes through the
  // `driver-payout-recipient` Edge Function (see WithdrawalRepository),
  // which resolves the account with Paystack, mints the transfer
  // recipient, and persists the row server-side. The client only reads
  // it back via [getMyPayoutAccount].

  /// Delete the driver's saved payout account. Returns true if a row
  /// was actually removed.
  Future<bool> removeMyPayoutAccount();
}
