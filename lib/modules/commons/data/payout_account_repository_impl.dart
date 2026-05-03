import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:drivio_driver/modules/commons/data/payout_account_repository.dart';
import 'package:drivio_driver/modules/commons/logging/app_logger.dart';
import 'package:drivio_driver/modules/commons/supabase/supabase_module.dart';
import 'package:drivio_driver/modules/commons/types/payout_account.dart';

class SupabasePayoutAccountRepository implements PayoutAccountRepository {
  SupabasePayoutAccountRepository(this._supabase);

  final SupabaseModule _supabase;

  @override
  Future<PayoutAccount?> getMyPayoutAccount() async {
    final User? user = _supabase.auth.currentUser;
    if (user == null) return null;
    final List<Map<String, dynamic>> rows = await _supabase
        .db('driver_payout_accounts')
        .select()
        .eq('driver_id', user.id)
        .limit(1);
    if (rows.isEmpty) return null;
    return PayoutAccount.fromJson(rows.first);
  }

  @override
  Future<PayoutAccount> upsertMyPayoutAccount({
    required String bankName,
    required String accountNumber,
    required String accountName,
  }) async {
    final User? user = _supabase.auth.currentUser;
    if (user == null) {
      throw const _PayoutAuthException();
    }
    // Mask client-side too so we never send the full number into the
    // wire log. Server has the full number transient only inside the
    // upsert call below.
    final String last4 = accountNumber.length >= 4
        ? accountNumber.substring(accountNumber.length - 4)
        : accountNumber.padLeft(4, '0');
    AppLogger.i('payout.upsertMyPayoutAccount', data: <String, dynamic>{
      'bank_name': bankName,
      'account_last4': last4,
      'account_name': accountName,
    });
    final Map<String, dynamic> row = await _supabase
        .db('driver_payout_accounts')
        .upsert(<String, dynamic>{
          'driver_id': user.id,
          'bank_name': bankName,
          'account_number_last4': last4,
          'account_name': accountName,
          // paystack_recipient_code stays null until a server-side job
          // verifies the account; UI shows "verifying" in the meantime.
        })
        .select()
        .single();
    return PayoutAccount.fromJson(row);
  }

  @override
  Future<bool> removeMyPayoutAccount() async {
    final User? user = _supabase.auth.currentUser;
    if (user == null) return false;
    final List<Map<String, dynamic>> deleted = await _supabase
        .db('driver_payout_accounts')
        .delete()
        .eq('driver_id', user.id)
        .select();
    return deleted.isNotEmpty;
  }
}

class _PayoutAuthException implements Exception {
  const _PayoutAuthException();
  @override
  String toString() => 'PayoutAuthException: no signed-in user';
}
