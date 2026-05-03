import 'package:drivio_driver/modules/commons/data/driver_rating_repository.dart';
import 'package:drivio_driver/modules/commons/supabase/supabase_module.dart';
import 'package:drivio_driver/modules/commons/types/driver_rating.dart';

class SupabaseDriverRatingRepository implements DriverRatingRepository {
  SupabaseDriverRatingRepository(this._supabase);

  final SupabaseModule _supabase;

  @override
  Future<DriverRatingSummary> getMySummary() async {
    final List<dynamic> rows = await _supabase.client
        .rpc<dynamic>('get_my_driver_rating_summary') as List<dynamic>;
    if (rows.isEmpty) return DriverRatingSummary.empty;
    return DriverRatingSummary.fromJson(rows.first as Map<String, dynamic>);
  }

  @override
  Future<List<DriverRating>> listMyRecent({int limit = 25}) async {
    final List<dynamic> rows = await _supabase.client.rpc<dynamic>(
      'list_my_recent_driver_ratings',
      params: <String, dynamic>{'p_limit': limit},
    ) as List<dynamic>;
    return rows
        .map((Object? r) =>
            DriverRating.fromJson(r! as Map<String, dynamic>))
        .toList(growable: false);
  }
}
