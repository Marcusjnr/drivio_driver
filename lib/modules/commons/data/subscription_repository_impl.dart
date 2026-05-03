import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:drivio_driver/modules/commons/data/subscription_repository.dart';
import 'package:drivio_driver/modules/commons/supabase/supabase_module.dart';
import 'package:drivio_driver/modules/commons/types/subscription.dart';

class SupabaseSubscriptionRepository implements SubscriptionRepository {
  SupabaseSubscriptionRepository(this._supabase);

  final SupabaseModule _supabase;

  @override
  Future<Subscription?> getMySubscription() async {
    final User? user = _supabase.auth.currentUser;
    if (user == null) return null;

    final List<Map<String, dynamic>> rows = await _supabase
        .db('subscriptions')
        .select()
        .eq('driver_id', user.id)
        .order('created_at', ascending: false)
        .limit(1);

    if (rows.isEmpty) return null;
    return Subscription.fromJson(rows.first);
  }

  @override
  Future<List<SubscriptionPlan>> listActivePlans() async {
    final List<Map<String, dynamic>> rows = await _supabase
        .db('subscription_plans')
        .select()
        .eq('is_active', true)
        .order('price_minor', ascending: true);
    return rows.map(SubscriptionPlan.fromJson).toList(growable: false);
  }

  @override
  Future<String?> activateSubscriptionDevMode() async {
    final dynamic res =
        await _supabase.client.rpc<dynamic>('activate_subscription_dev_mode');
    return res as String?;
  }
}
