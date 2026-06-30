import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:drivio_driver/modules/commons/data/withdrawal_repository.dart';
import 'package:drivio_driver/modules/commons/logging/app_logger.dart';
import 'package:drivio_driver/modules/commons/supabase/supabase_module.dart';

class SupabaseWithdrawalRepository implements WithdrawalRepository {
  SupabaseWithdrawalRepository(this._supabase);

  final SupabaseModule _supabase;

  @override
  Future<List<PaystackBank>> listBanks() async {
    final FunctionResponse res =
        await _supabase.functions.invoke('paystack-banks');
    final Object? data = res.data;
    final Object? rawBanks = data is Map ? data['banks'] : null;
    if (rawBanks is! List) {
      return const <PaystackBank>[];
    }
    return rawBanks
        .whereType<Map<dynamic, dynamic>>()
        .map((Map<dynamic, dynamic> b) =>
            PaystackBank.fromJson(Map<String, dynamic>.from(b)))
        .toList(growable: false);
  }

  @override
  Future<PayoutRecipientResult> createPayoutRecipient({
    required String accountNumber,
    required String bankCode,
    required String bankName,
  }) async {
    // Never log the full account number — last4 only.
    final String last4 = accountNumber.length >= 4
        ? accountNumber.substring(accountNumber.length - 4)
        : accountNumber;
    AppLogger.i('withdraw.createPayoutRecipient', data: <String, dynamic>{
      'bank_name': bankName,
      'account_last4': last4,
    });
    try {
      final FunctionResponse res = await _supabase.functions.invoke(
        'driver-payout-recipient',
        body: <String, dynamic>{
          'account_number': accountNumber,
          'bank_code': bankCode,
          'bank_name': bankName,
        },
      );
      final Object? data = res.data;
      if (data is! Map) {
        throw const WithdrawalException(
          errorKey: 'recipient_failed',
          message: "Couldn't verify that account. Please try again.",
        );
      }
      return PayoutRecipientResult.fromJson(Map<String, dynamic>.from(data));
    } on FunctionException catch (e) {
      throw _mapFunctionException(
        e,
        fallbackKey: 'recipient_failed',
        fallbackMessage:
            "Couldn't verify that account. Check the details and try again.",
      );
    }
  }

  @override
  Future<WithdrawalResult> withdraw({required int amountMinor}) async {
    try {
      final FunctionResponse res = await _supabase.functions.invoke(
        'driver-withdraw',
        body: <String, dynamic>{'amount_minor': amountMinor},
      );
      final Object? data = res.data;
      if (data is! Map) {
        throw const WithdrawalException(
          errorKey: 'transfer_failed',
          message: "Couldn't start that withdrawal. Please try again.",
        );
      }
      return WithdrawalResult.fromJson(Map<String, dynamic>.from(data));
    } on FunctionException catch (e) {
      throw _mapFunctionException(
        e,
        fallbackKey: 'transfer_failed',
        fallbackMessage:
            "Couldn't start that withdrawal. Please try again in a moment.",
      );
    }
  }

  /// Pulls the structured `{ error, message }` out of a non-2xx Edge
  /// Function response. The functions client parses the JSON body into
  /// [FunctionException.details].
  WithdrawalException _mapFunctionException(
    FunctionException e, {
    required String fallbackKey,
    required String fallbackMessage,
  }) {
    final Object? details = e.details;
    if (details is Map) {
      final String? key = details['error'] as String?;
      final String? msg = details['message'] as String?;
      return WithdrawalException(
        errorKey: key ?? fallbackKey,
        message: (msg != null && msg.trim().isNotEmpty) ? msg : fallbackMessage,
      );
    }
    return WithdrawalException(
      errorKey: fallbackKey,
      message: fallbackMessage,
    );
  }
}
