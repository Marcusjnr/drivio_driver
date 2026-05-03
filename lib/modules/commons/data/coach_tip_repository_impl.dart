import 'package:drivio_driver/modules/commons/data/coach_tip_repository.dart';
import 'package:drivio_driver/modules/commons/supabase/supabase_module.dart';
import 'package:drivio_driver/modules/commons/types/coach_tip.dart';

class SupabaseCoachTipRepository implements CoachTipRepository {
  SupabaseCoachTipRepository(this._supabase);

  final SupabaseModule _supabase;

  @override
  Future<List<CoachTip>> getMyTips({int limit = 3}) async {
    final List<dynamic> rows = await _supabase.client.rpc<dynamic>(
      'get_my_coach_tips',
      params: <String, dynamic>{'p_limit': limit},
    ) as List<dynamic>;
    return rows
        .map((Object? r) => CoachTip.fromJson(r! as Map<String, dynamic>))
        .toList(growable: false);
  }
}
