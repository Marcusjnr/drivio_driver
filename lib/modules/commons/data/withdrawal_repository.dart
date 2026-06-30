/// Bank entry returned by the `paystack-banks` Edge Function — used to
/// populate the bank picker on the payout-account setup flow.
class PaystackBank {
  const PaystackBank({required this.name, required this.code});

  final String name;
  final String code;

  factory PaystackBank.fromJson(Map<String, dynamic> json) {
    return PaystackBank(
      name: json['name'] as String,
      code: json['code'] as String,
    );
  }
}

/// What `driver-payout-recipient` returns once Paystack has resolved the
/// account and minted a transfer recipient server-side. The account name
/// is the server-confirmed name on the bank account.
class PayoutRecipientResult {
  const PayoutRecipientResult({
    required this.accountName,
    required this.accountNumberLast4,
    required this.bankName,
  });

  final String accountName;
  final String accountNumberLast4;
  final String bankName;

  factory PayoutRecipientResult.fromJson(Map<String, dynamic> json) {
    return PayoutRecipientResult(
      accountName: json['account_name'] as String,
      accountNumberLast4: json['account_number_last4'] as String,
      bankName: json['bank_name'] as String,
    );
  }
}

/// What `driver-withdraw` returns on a successful (queued) transfer. The
/// transfer is async at Paystack — the server returns `processing` and the
/// wallet/ledger settle via webhook later.
class WithdrawalResult {
  const WithdrawalResult({
    required this.status,
    required this.reference,
    required this.amountMinor,
    required this.feeMinor,
    required this.totalMinor,
  });

  final String status;
  final String reference;
  final int amountMinor;
  final int feeMinor;
  final int totalMinor;

  factory WithdrawalResult.fromJson(Map<String, dynamic> json) {
    return WithdrawalResult(
      status: json['status'] as String? ?? 'processing',
      reference: json['reference'] as String? ?? '',
      amountMinor: (json['amount_minor'] as num?)?.toInt() ?? 0,
      feeMinor: (json['fee_minor'] as num?)?.toInt() ?? 0,
      totalMinor: (json['total_minor'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Raised when an Edge Function returns a structured `{ error, message }`
/// failure. [errorKey] is the stable machine key (used for analytics) and
/// [message] is the friendly, user-facing copy from the server.
class WithdrawalException implements Exception {
  const WithdrawalException({required this.errorKey, required this.message});

  /// Stable failure key, e.g. `insufficient_balance`, `no_payout_recipient`,
  /// `invalid_account`, `account_resolve_failed`, `recipient_failed`.
  final String errorKey;

  /// Friendly message safe to show the driver.
  final String message;

  @override
  String toString() => 'WithdrawalException($errorKey): $message';
}

/// Calls the server-side withdrawal/payout Edge Functions. The Paystack
/// secret never touches the app — the server resolves accounts, mints
/// transfer recipients, and queues transfers.
abstract class WithdrawalRepository {
  /// Nigerian banks from Paystack for the bank picker.
  Future<List<PaystackBank>> listBanks();

  /// Resolve + verify a bank account and create/replace the driver's
  /// payout recipient server-side. Returns the server-confirmed account
  /// name. Throws [WithdrawalException] on `invalid_account`,
  /// `account_resolve_failed`, or `recipient_failed`.
  Future<PayoutRecipientResult> createPayoutRecipient({
    required String accountNumber,
    required String bankCode,
    required String bankName,
  });

  /// Queue a withdrawal of [amountMinor] (the amount the driver receives;
  /// the server adds the service fee on top). Returns the processing
  /// result. Throws [WithdrawalException] on a server-side failure with a
  /// friendly `message`.
  Future<WithdrawalResult> withdraw({required int amountMinor});
}
