import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:drivio_driver/modules/commons/data/payout_account_repository.dart';
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
