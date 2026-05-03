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
  /// Snapshot of currently-open ride requests, sorted by creation time
  /// (newest first). Limited to 50.
  Future<List<RideRequest>> listOpen();

  /// Realtime change events on the `ride_requests` table. Subscribers
  /// should call [listOpen] to refresh the canonical list when a relevant
  /// event arrives.
  Stream<RideRequestEvent> changes();

  /// Dev-mode: spawn a fake ride request near the calling driver.
  /// Returns the new request id.
  Future<String> injectTestRequestNearMe({
    double offsetMeters = 800,
    int expiresInSeconds = 60,
  });

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

  /// Look up the trip created from an accepted bid (one-shot).
  Future<String?> findTripIdForBid(String bidId);

  /// Dev shortcut: accepts the driver's most recent pending bid as if the
  /// passenger had picked it. Returns the new trip id.
  Future<String> acceptMyLatestPendingBid();
}
