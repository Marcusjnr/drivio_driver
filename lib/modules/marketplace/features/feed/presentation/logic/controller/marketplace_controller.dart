import 'dart:async';
import 'dart:math' as math;

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

  /// Already filtered + ordered by proximity by the server.
  final List<RideRequest> requests;
  final double? driverLat;
  final double? driverLng;
  final bool isLoading;
  final String? error;

  /// Apply the driver's saved trip-length preference. The server
  /// already enforces the expanding-radius geo filter, so this is
  /// purely a UI-side bucket filter.
  ///
  /// `profile` is null while pricing is hydrating — fall back to the
  /// raw list so the UI stays usable on cold start.
  List<RideRequest> visibleFor(PricingProfile? profile) {
    if (profile == null) return requests;
    return requests
        .where((RideRequest r) => profile.acceptsDistance(r.expectedDistanceM))
        .toList(growable: false);
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

/// Driver-side marketplace feed.
///
/// The server applies an expanding-ring geo filter (2 → 4 → 6 → 8 km
/// over 80 s) keyed on the driver's GPS fix, so a fresh fetch is only
/// useful once we have a position. The controller therefore:
///
///   * defers the first fetch until `updateDriverPosition` lands the
///     initial fix;
///   * refetches whenever the driver moves more than
///     [_kRefetchOnMoveM] (so a cruising driver picks up requests that
///     just entered range);
///   * refetches on every realtime change event for a request the
///     driver may now (or may no longer) see.
class MarketplaceController extends StateNotifier<MarketplaceState> {
  MarketplaceController(this._repo) : super(const MarketplaceState());

  final RideRequestRepository _repo;
  StreamSubscription<RideRequestEvent>? _eventSub;
  Timer? _expiryTimer;

  /// Re-fetch when the driver has moved at least this far since the
  /// last fetch. Cheaper than refetching on every 10 m GPS tick, dense
  /// enough that even at the smallest 2 km ring the feed stays fresh.
  static const double _kRefetchOnMoveM = 250;

  double? _lastFetchLat;
  double? _lastFetchLng;

  /// Subscribe to realtime + (if we already have a fix) do an initial
  /// fetch. Idempotent.
  Future<void> start() async {
    if (_eventSub == null) {
      _eventSub = _repo.changes().listen(
        (RideRequestEvent _) => _refetchIfPositioned(),
        onError: (Object e) =>
            state = state.copyWith(error: 'Realtime: $e'),
      );
      _expiryTimer ??= Timer.periodic(
        const Duration(seconds: 5),
        (_) => _pruneExpired(),
      );
    }
    await _refetchIfPositioned();
  }

  Future<void> stop() async {
    await _eventSub?.cancel();
    _eventSub = null;
    _expiryTimer?.cancel();
    _expiryTimer = null;
    _lastFetchLat = null;
    _lastFetchLng = null;
    state = state.copyWith(requests: const <RideRequest>[]);
  }

  /// Manual pull-to-refresh hook. Forces a fetch even if the driver
  /// hasn't moved.
  Future<void> refresh() async {
    if (state.driverLat == null || state.driverLng == null) {
      return;
    }
    await _fetch(state.driverLat!, state.driverLng!);
  }

  /// Push the driver's latest GPS fix in. Triggers a refetch if it's
  /// the first fix or the driver has moved at least
  /// [_kRefetchOnMoveM].
  void updateDriverPosition(double lat, double lng) {
    final bool firstFix =
        state.driverLat == null || state.driverLng == null;
    state = state.copyWith(driverLat: lat, driverLng: lng);

    final bool moved = _lastFetchLat == null ||
        _lastFetchLng == null ||
        _haversineM(_lastFetchLat!, _lastFetchLng!, lat, lng) >=
            _kRefetchOnMoveM;
    if (_eventSub != null && (firstFix || moved)) {
      _fetch(lat, lng);
    }
  }

  Future<void> _refetchIfPositioned() async {
    final double? lat = state.driverLat;
    final double? lng = state.driverLng;
    if (lat == null || lng == null) {
      return;
    }
    await _fetch(lat, lng);
  }

  Future<void> _fetch(double lat, double lng) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final List<RideRequest> next = await _repo.listNearby(
        driverLat: lat,
        driverLng: lng,
      );
      _lastFetchLat = lat;
      _lastFetchLng = lng;
      state = state.copyWith(requests: next, isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Could not load requests: $e',
      );
    }
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

  static double _haversineM(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
  ) {
    const double r = 6371000;
    final double dLat = (lat2 - lat1) * (math.pi / 180);
    final double dLng = (lng2 - lng1) * (math.pi / 180);
    final double a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1 * (math.pi / 180)) *
            math.cos(lat2 * (math.pi / 180)) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    return 2 * r * math.atan2(math.sqrt(a), math.sqrt(1 - a));
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
/// list filtered by the driver's saved trip-length preference. The
/// expanding-radius geo filter and proximity sort are already applied
/// server-side.
final Provider<List<RideRequest>> visibleRequestsProvider =
    Provider<List<RideRequest>>((Ref ref) {
  final MarketplaceState m = ref.watch(marketplaceControllerProvider);
  final PricingProfile? profile = ref.watch(
    pricingControllerProvider.select((PricingState s) => s.profile),
  );
  return m.visibleFor(profile);
});
