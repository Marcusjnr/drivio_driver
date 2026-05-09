import 'dart:async';

import 'package:drivio_driver/modules/commons/types/ride_bid.dart';
import 'package:drivio_driver/modules/commons/types/ride_request.dart';

/// Realtime stream event for the marketplace feed. The driver app reacts
/// to these by re-fetching the canonical list, since postgres_changes
/// payloads carry geography columns as WKB hex which the client can't
/// easily decode.
enum RideRequestEventKind { inserted, updated, deleted }

class RideRequestEvent {
  const RideRequestEvent({required this.kind, this.requestId});
  final RideRequestEventKind kind;
  final String? requestId;
}

abstract class RideRequestRepository {
  /// Snapshot of currently-open ride requests visible to a driver at the
  /// given GPS fix. The server applies an expanding-ring filter:
  /// requests are visible inside a radius that grows from 2 km to 8 km
  /// in 2 km steps every 20 s of the request's lifetime. Sorted by
  /// proximity to the driver, capped at 50 rows.
  Future<List<RideRequest>> listNearby({
    required double driverLat,
    required double driverLng,
  });

  /// Realtime change events on the `ride_requests` table. Subscribers
  /// should call [listNearby] to refresh the canonical list when a
  /// relevant event arrives.
  Stream<RideRequestEvent> changes();

  /// Single ride request by id.
  Future<RideRequest?> getById(String id);

  /// Submit (or update) the driver's bid on a request. Returns the bid id.
  Future<String> submitBid({
    required String requestId,
    required String vehicleId,
    required int priceMinor,
    int? etaSeconds,
  });

  /// Withdraw a pending bid by id.
  Future<void> withdrawBid(String bidId);

  /// Realtime stream of changes to a single ride_bids row. Each event
  /// carries the parsed [RideBid].
  Stream<RideBid> watchBid(String bidId);

  /// One-shot fetch of a bid by id. Used as a poll-fallback when the
  /// realtime UPDATE event drops (network blip, channel desync, etc.).
  Future<RideBid?> getBid(String bidId);

  /// Look up the trip created from an accepted bid (one-shot).
  Future<String?> findTripIdForBid(String bidId);
}
