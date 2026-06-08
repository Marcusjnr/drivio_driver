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
    // Two guards because either one alone has historically slipped: an
    // archived row that someone forgot to flip is_active on, or an
    // is_active=false row whose deleted_at hasn't been set. We need both
    // to be true for a plan to surface in the paywall.
    final List<Map<String, dynamic>> rows = await _supabase
        .db('subscription_plans')
        .select()
        .eq('is_active', true)
        .isFilter('deleted_at', null)
        .order('price_minor', ascending: true);
    return rows.map(SubscriptionPlan.fromJson).toList(growable: false);
  }

  @override
  Future<String?> activateSubscriptionDevMode({String? planCode}) async {
    // Server has a default ('drivio_pro_monthly') so passing null still
    // works, but the paywall should always pass the actual selected tier.
    final dynamic res = await _supabase.client.rpc<dynamic>(
      'activate_subscription_dev_mode',
      params: planCode == null
          ? const <String, dynamic>{}
          : <String, dynamic>{'p_plan_code': planCode},
    );
    return res as String?;
  }

  @override
  Future<void> pauseMine() async {
    await _supabase.client.rpc<dynamic>('pause_my_subscription');
  }

  @override
  Future<void> resumeMine() async {
    await _supabase.client.rpc<dynamic>('resume_my_subscription');
  }

  @override
  Future<Map<String, int>> getMyTrialActivity() async {
    final User? user = _supabase.auth.currentUser;
    if (user == null) {
      return const <String, int>{'active_days': 0, 'observed_days': 0};
    }
    try {
      final dynamic res =
          await _supabase.client.rpc<dynamic>('get_my_trial_activity');
      if (res is Map) {
        return <String, int>{
          'active_days': (res['active_days'] as num?)?.toInt() ?? 0,
          'observed_days': (res['observed_days'] as num?)?.toInt() ?? 0,
        };
      }
      return const <String, int>{'active_days': 0, 'observed_days': 0};
    } catch (_) {
      // RPC may not exist yet in this environment — let the recommendation
      // engine fall through to the safe "no history" default.
      return const <String, int>{'active_days': 0, 'observed_days': 0};
    }
  }

  @override
  Future<void> queueTierSwitch({
    required String subscriptionId,
    required String targetPlanCode,
    String? reason,
  }) async {
    await _supabase.client.rpc<dynamic>(
      'queue_tier_switch',
      params: <String, dynamic>{
        'p_subscription_id': subscriptionId,
        'p_target_plan_code': targetPlanCode,
        'p_reason': reason,
      },
    );
  }

  @override
  Future<void> cancelPendingTierSwitch({required String subscriptionId}) async {
    await _supabase.client.rpc<dynamic>(
      'cancel_pending_tier_switch',
      params: <String, dynamic>{'p_subscription_id': subscriptionId},
    );
  }
}
