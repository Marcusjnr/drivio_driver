import 'package:drivio_driver/modules/commons/types/passenger_rating.dart';

abstract class PassengerRatingRepository {
  /// Existing rating for a trip if the driver already submitted one.
  Future<PassengerRating?> getMyRatingForTrip(String tripId);

  /// Insert (or upsert) a passenger rating for a completed trip.
  Future<void> submit({
    required String tripId,
    required int rating,
    required List<String> tags,
    String? comment,
  });
}
