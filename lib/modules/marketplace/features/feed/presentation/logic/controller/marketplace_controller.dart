import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:drivio_driver/modules/commons/data/ride_request_repository.dart';
import 'package:drivio_driver/modules/commons/di/di.dart';
import 'package:drivio_driver/modules/commons/types/pricing_profile.dart';
import 'package:drivio_driver/modules/commons/types/ride_request.dart';
import 'package:drivio_driver/modules/dash/features/pricing/presentation/logic/controller/pricing_controller.dart';

class MarketplaceState {
  const MarketplaceState({
    this.requests = const <RideRequest>[],
    this.driverLat,
    this.driverLng,
    this.isLoading = false,
    this.error,
  });

  final List<RideRequest> requests;
  final double? driverLat;
  final double? driverLng;
  final bool isLoading;
  final String? error;

  /// Requests sorted by distance from the driver (closest first). Falls
  /// back to creation-time order if no fix yet.
  List<RideRequest> get sorted {
    if (driverLat == null || driverLng == null) return requests;
    final List<RideRequest> sorted = List<RideRequest>.from(requests);
    sorted.sort((RideRequest a, RideRequest b) {
      final double da = a.distanceMetersFrom(driverLat!, driverLng!);
      final double db = b.distanceMetersFrom(driverLat!, driverLng!);
      return da.compareTo(db);
    });
    return sorted;
  }

  /// Sorted, then filtered by the driver's saved preferences:
  ///   * `max_pickup_km` — drops requests whose pickup leg from the
  ///     driver's last GPS fix exceeds the cap. If no fix yet, the
  ///     filter is permissive (we'd rather show too much than hide
  ///     valid work pre-fix).
  ///   * `trip_length` — drops trips whose `expectedDistanceM` falls
  ///     outside the chosen short/long bucket.
  ///
  /// `profile` is null while pricing is hydrating — in that case fall
  /// back to the unfiltered sort so the UI stays usable on cold start.
  List<RideRequest> visibleFor(PricingProfile? profile) {
    final List<RideRequest> base = sorted;
    if (profile == null) return base;
    final double? lat = driverLat;
    final double? lng = driverLng;
    final double maxPickupM = profile.maxPickupKm * 1000;
    return base.where((RideRequest r) {
      if (lat != null && lng != null) {
        final double pickupM = r.distanceMetersFrom(lat, lng);
        if (pickupM > maxPickupM) return false;
      }
      return profile.acceptsDistance(r.expectedDistanceM);
    }).toList(growable: false);
  }

  MarketplaceState copyWith({
    List<RideRequest>? requests,
    double? driverLat,
    double? driverLng,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return MarketplaceState(
      requests: requests ?? this.requests,
      driverLat: driverLat ?? this.driverLat,
      driverLng: driverLng ?? this.driverLng,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class MarketplaceController extends StateNotifier<MarketplaceState> {
  MarketplaceController(this._repo) : super(const MarketplaceState());

  final RideRequestRepository _repo;
  StreamSubscription<RideRequestEvent>? _eventSub;
  Timer? _expiryTimer;

  /// Fetch + subscribe. Idempotent — calling twice is safe.
  Future<void> start() async {
    if (_eventSub != null) {
      await refresh();
      return;
    }
    _eventSub = _repo.changes().listen(
      (RideRequestEvent _) => refresh(),
      onError: (Object e) =>
          state = state.copyWith(error: 'Realtime: $e'),
    );
    _expiryTimer ??= Timer.periodic(
      const Duration(seconds: 5),
      (_) => _pruneExpired(),
    );
    await refresh();
  }

  Future<void> stop() async {
    await _eventSub?.cancel();
    _eventSub = null;
    _expiryTimer?.cancel();
    _expiryTimer = null;
    state = state.copyWith(requests: const <RideRequest>[]);
  }

  Future<void> refresh() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final List<RideRequest> next = await _repo.listOpen();
      state = state.copyWith(requests: next, isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Could not load requests: $e',
      );
    }
  }

  void updateDriverPosition(double lat, double lng) {
    state = state.copyWith(driverLat: lat, driverLng: lng);
  }

  void _pruneExpired() {
    final DateTime now = DateTime.now();
    final List<RideRequest> kept = state.requests
        .where((RideRequest r) => r.expiresAt.isAfter(now))
        .toList(growable: false);
    if (kept.length != state.requests.length) {
      state = state.copyWith(requests: kept);
    }
  }

  @override
  void dispose() {
    _eventSub?.cancel();
    _expiryTimer?.cancel();
    super.dispose();
  }
}

final StateNotifierProvider<MarketplaceController, MarketplaceState>
    marketplaceControllerProvider =
    StateNotifierProvider<MarketplaceController, MarketplaceState>(
  (Ref _) => MarketplaceController(locator<RideRequestRepository>()),
);

/// What the marketplace UI should actually render — the open-request
/// list filtered by the driver's saved pricing preferences and sorted
/// by pickup distance. Recomputes whenever either source changes.
final Provider<List<RideRequest>> visibleRequestsProvider =
    Provider<List<RideRequest>>((Ref ref) {
  final MarketplaceState m = ref.watch(marketplaceControllerProvider);
  final PricingProfile? profile = ref.watch(
    pricingControllerProvider.select((PricingState s) => s.profile),
  );
  return m.visibleFor(profile);
});
