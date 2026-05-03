import 'dart:async';

import 'package:drivio_driver/modules/commons/types/trip.dart';

abstract class TripRepository {
  /// Fetch a single trip with pickup/dropoff lat/lng and addresses joined.
  Future<Trip?> getTrip(String id);

  /// The driver's currently-active trip (any state ∈ {assigned, en_route,
  /// arrived, in_progress}), if any. Used at cold-start.
  Future<String?> getMyActiveTripId();

  /// Realtime stream for a single trip's row updates.
  Stream<Trip> watchTrip(String tripId);

  /// Calls the `transition_trip` RPC. Returns the resulting state.
  Future<String> transition({
    required String tripId,
    required TripState toState,
    String? reason,
  });
}
