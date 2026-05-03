/// Driver's saved bank account for payouts. One row per driver in
/// `driver_payout_accounts` — switching banks overwrites the same
/// row. We never store the full account number on the client; the
/// server only ever returns the last 4 digits.
class PayoutAccount {
  const PayoutAccount({
    required this.driverId,
    required this.bankName,
    required this.accountNumberLast4,
    required this.accountName,
    this.paystackRecipientCode,
    required this.createdAt,
    required this.updatedAt,
  });

  final String driverId;
  final String bankName;
  final String accountNumberLast4;
  final String accountName;

  /// Set once Paystack has verified the account and minted a transfer
  /// recipient. Null until that round-trip completes; UI shows the
  /// row as "verifying" while it's null.
  final String? paystackRecipientCode;

  final DateTime createdAt;
  final DateTime updatedAt;

  /// Driver-facing label: `GTBank · •••• 3340`.
  String get displayLabel => '$bankName · •••• $accountNumberLast4';

  bool get isVerified => paystackRecipientCode != null;

  factory PayoutAccount.fromJson(Map<String, dynamic> json) {
    return PayoutAccount(
      driverId: json['driver_id'] as String,
      bankName: json['bank_name'] as String,
      accountNumberLast4: json['account_number_last4'] as String,
      accountName: json['account_name'] as String,
      paystackRecipientCode: json['paystack_recipient_code'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }
}
