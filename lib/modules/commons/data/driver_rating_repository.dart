import 'package:drivio_driver/modules/commons/types/driver_rating.dart';

abstract class DriverRatingRepository {
  /// Aggregated rating snapshot for the calling driver. Returns
  /// `DriverRatingSummary.empty` when no ratings exist.
  Future<DriverRatingSummary> getMySummary();

  /// Recent passenger reviews for the calling driver, newest first.
  /// Cap is server-clamped to 100.
  Future<List<DriverRating>> listMyRecent({int limit = 25});
}
