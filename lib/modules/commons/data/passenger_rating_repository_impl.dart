import 'package:drivio_driver/modules/commons/data/passenger_rating_repository.dart';
import 'package:drivio_driver/modules/commons/supabase/supabase_module.dart';
import 'package:drivio_driver/modules/commons/types/passenger_rating.dart';

class SupabasePassengerRatingRepository implements PassengerRatingRepository {
  SupabasePassengerRatingRepository(this._supabase);

  final SupabaseModule _supabase;

  @override
  Future<PassengerRating?> getMyRatingForTrip(String tripId) async {
    final List<dynamic> rows = await _supabase.client.rpc<dynamic>(
      'get_my_rating_for_trip',
      params: <String, dynamic>{'p_trip_id': tripId},
    ) as List<dynamic>;
    if (rows.isEmpty) return null;
    return PassengerRating.fromJson(rows.first as Map<String, dynamic>);
  }

  @override
  Future<void> submit({
    required String tripId,
    required int rating,
    required List<String> tags,
    String? comment,
  }) async {
    await _supabase.client.rpc<dynamic>(
      'submit_passenger_rating',
      params: <String, dynamic>{
        'p_trip_id': tripId,
        'p_rating': rating,
        'p_tags': tags,
        'p_comment': comment,
      },
    );
  }
}
