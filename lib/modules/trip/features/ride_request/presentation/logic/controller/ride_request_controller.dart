import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:drivio_driver/modules/commons/data/pricing_repository.dart';
import 'package:drivio_driver/modules/commons/data/ride_request_repository.dart';
import 'package:drivio_driver/modules/commons/di/di.dart';
import 'package:drivio_driver/modules/commons/errors/error_messages.dart';
import 'package:drivio_driver/modules/commons/logging/app_logger.dart';
import 'package:drivio_driver/modules/commons/types/pricing_profile.dart'
    show PricingProfile, PricingWindow;
import 'package:drivio_driver/modules/commons/types/ride_bid.dart';
import 'package:drivio_driver/modules/commons/types/ride_request.dart';
import 'package:drivio_driver/modules/commons/types/vehicle.dart';
import 'package:drivio_driver/modules/dash/features/add_vehicle/presentation/logic/data/vehicle_repository.dart';

// Hard floor / ceiling on bid prices. Per-driver defaults that drive the
// "suggested" hint live in the driver_pricing_profile table (DRV-069).
const int _kAbsoluteMinMinor = 20000; // ₦200
const int _kAbsoluteMaxMinor = 10000000; // ₦100,000

enum PricingVariant { type, slider, chips }

enum BidPhase { composing, submitting, waiting, won, lost }

class RideRequestState {
  const RideRequestState({
    this.requestId,
    this.request,
    this.priceMinor = 0,
    this.suggestedMinor = 0,
    this.suggestedWindow,
    this.suggestedMultiplier = 1.0,
    this.variant = PricingVariant.type,
    this.secondsLeft = 0,
    this.phase = BidPhase.composing,
    this.bidId,
    this.tripId,
    this.error,
    this.isLoading = false,
  });

  final String? requestId;
  final RideRequest? request;
  final int priceMinor;
  final int suggestedMinor;

  /// If non-null, the driver's pricing profile boosted the base suggestion
  /// because the request landed inside their peak or night window. UI
  /// badges this so the driver understands the higher number.
  final PricingWindow? suggestedWindow;
  final double suggestedMultiplier;

  final PricingVariant variant;
  final int secondsLeft;
  final BidPhase phase;
  final String? bidId;
  final String? tripId;
  final String? error;
  final bool isLoading;

  int get priceNaira => priceMinor ~/ 100;
  int get suggestedNaira => suggestedMinor ~/ 100;

  /// In naira (no commission per knowledge.md rule #2).
  int get netToYou => priceNaira;

  double get progressPct {
    final RideRequest? r = request;
    if (r == null) return 0;
    final int total = r.expiresAt.difference(r.createdAt).inSeconds;
    if (total <= 0) return 0;
    return (secondsLeft / total).clamp(0.0, 1.0);
  }

  double get distanceKm {
    final int? d = request?.expectedDistanceM;
    return d == null ? 0 : d / 1000;
  }

  int get durationMin => (request?.expectedDurationS ?? 0) ~/ 60;

  double get delta =>
      suggestedMinor == 0 ? 0 : (priceMinor - suggestedMinor) / suggestedMinor;

  int get sentimentScore {
    if (delta < -0.15) return -2;
    if (delta < -0.05) return -1;
    if (delta < 0.10) return 0;
    if (delta < 0.25) return 1;
    return 2;
  }

  bool get canSubmit =>
      phase == BidPhase.composing &&
      request != null &&
      priceMinor >= _kAbsoluteMinMinor &&
      priceMinor <= _kAbsoluteMaxMinor &&
      secondsLeft > 0;

  RideRequestState copyWith({
    String? requestId,
    RideRequest? request,
    int? priceMinor,
    int? suggestedMinor,
    PricingWindow? suggestedWindow,
    double? suggestedMultiplier,
    bool clearSuggestedWindow = false,
    PricingVariant? variant,
    int? secondsLeft,
    BidPhase? phase,
    String? bidId,
    String? tripId,
    String? error,
    bool clearError = false,
    bool? isLoading,
  }) {
    return RideRequestState(
      requestId: requestId ?? this.requestId,
      request: request ?? this.request,
      priceMinor: priceMinor ?? this.priceMinor,
      suggestedMinor: suggestedMinor ?? this.suggestedMinor,
      suggestedWindow: clearSuggestedWindow
          ? null
          : (suggestedWindow ?? this.suggestedWindow),
      suggestedMultiplier: suggestedMultiplier ?? this.suggestedMultiplier,
      variant: variant ?? this.variant,
      secondsLeft: secondsLeft ?? this.secondsLeft,
      phase: phase ?? this.phase,
      bidId: bidId ?? this.bidId,
      tripId: tripId ?? this.tripId,
      error: clearError ? null : (error ?? this.error),
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class RideRequestController extends StateNotifier<RideRequestState> {
  RideRequestController({
    required String requestId,
    required RideRequestRepository requests,
    required VehicleRepository vehicles,
    required PricingRepository pricing,
  })  : _requests = requests,
        _vehicles = vehicles,
        _pricing = pricing,
        super(RideRequestState(requestId: requestId, isLoading: true)) {
    _hydrate();
  }

  final RideRequestRepository _requests;
  final VehicleRepository _vehicles;
  final PricingRepository _pricing;

  Timer? _ticker;
  StreamSubscription<RideBid>? _bidSub;

  /// Realtime safety net. Postgres-changes UPDATE events for
  /// `ride_bids` can drop on network blips, OS-suspended foreground
  /// states, or stale channel auth. While in [BidPhase.waiting] we
  /// poll the bid every [_kBidPollWindow] as a fallback so a missed
  /// UPDATE event doesn't leave the driver stuck on the "Bid placed ·
  /// waiting for passenger" UI after the passenger has already
  /// accepted/rejected.
  Timer? _bidPoll;
  static const Duration _kBidPollWindow = Duration(seconds: 4);

  String? _activeVehicleId;
  PricingProfile _pricingProfile = PricingProfile.platformDefault;

  Future<void> _hydrate() async {
    try {
      // Fetch request, vehicles, and pricing profile in parallel — none
      // depend on each other.
      final List<dynamic> r = await Future.wait<dynamic>(<Future<dynamic>>[
        _requests.getById(state.requestId!),
        _vehicles.listMyVehicles(),
        _pricing.getOrCreateMyProfile(),
      ]);
      if (!mounted) return;
      final RideRequest? req = r[0] as RideRequest?;
      if (req == null) {
        state = state.copyWith(
          isLoading: false,
          error: 'Request not found.',
        );
        return;
      }

      final List<Vehicle> mine = r[1] as List<Vehicle>;
      final Vehicle? active = mine
          .where((Vehicle v) => v.status == VehicleStatus.active)
          .cast<Vehicle?>()
          .firstWhere((Vehicle? _) => true, orElse: () => null);
      _activeVehicleId = active?.id;
      _pricingProfile = r[2] as PricingProfile;

      final int suggested = _suggestedForRequest(req);
      final PricingWindow? window =
          _pricingProfile.activeWindow(req.createdAt);
      final double mult = window == PricingWindow.peak
          ? _pricingProfile.peakMultiplier
          : window == PricingWindow.night
              ? _pricingProfile.nightMultiplier
              : 1.0;
      state = state.copyWith(
        request: req,
        suggestedMinor: suggested,
        priceMinor: suggested,
        suggestedWindow: window,
        clearSuggestedWindow: window == null,
        suggestedMultiplier: mult,
        secondsLeft: req.secondsRemaining(),
        isLoading: false,
      );
      _startTicker();
    } catch (e, s) {
      if (!mounted) return;
      AppLogger.e('Ride request hydrate failed', error: e, stackTrace: s);
      state = state.copyWith(
        isLoading: false,
        error: humaniseError(e, fallback: "Couldn't load this request."),
      );
    }
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (Timer t) {
      final RideRequest? r = state.request;
      if (r == null) return;
      final int s = r.secondsRemaining();
      state = state.copyWith(secondsLeft: s);
      if (s <= 0) {
        t.cancel();
        if (state.phase == BidPhase.waiting) {
          state = state.copyWith(
            phase: BidPhase.lost,
            error: 'Request expired before a bid was accepted.',
          );
        }
      }
    });
  }

  void setPriceNaira(int v) {
    final int minor = (v * 100).clamp(_kAbsoluteMinMinor, _kAbsoluteMaxMinor);
    state = state.copyWith(priceMinor: minor, clearError: true);
  }

  void setVariant(PricingVariant v) =>
      state = state.copyWith(variant: v, clearError: true);

  Future<void> submitBid() async {
    if (!state.canSubmit) return;
    if (_activeVehicleId == null) {
      state = state.copyWith(
        error: 'No active vehicle on your account. Add or activate one first.',
      );
      return;
    }
    state = state.copyWith(phase: BidPhase.submitting, clearError: true);

    try {
      final String bidId = await _requests.submitBid(
        requestId: state.requestId!,
        vehicleId: _activeVehicleId!,
        priceMinor: state.priceMinor,
      );
      if (!mounted) return;
      state = state.copyWith(bidId: bidId, phase: BidPhase.waiting);
      _watchBid(bidId);
    } catch (e, s) {
      if (!mounted) return;
      AppLogger.e('Bid submit failed', error: e, stackTrace: s);
      state = state.copyWith(
        phase: BidPhase.composing,
        error: humaniseError(e, fallback: "Couldn't submit bid."),
      );
    }
  }

  void _watchBid(String bidId) {
    _bidSub?.cancel();
    _bidPoll?.cancel();

    _bidSub = _requests.watchBid(bidId).listen((RideBid bid) async {
      await _handleBidUpdate(bidId, bid);
    });

    // Realtime safety net — periodically re-fetch the bid in case
    // postgres-changes drops the UPDATE event. The poll self-cancels as
    // soon as we leave BidPhase.waiting (terminal phase reached).
    _bidPoll = Timer.periodic(_kBidPollWindow, (Timer _) async {
      if (!mounted || state.phase != BidPhase.waiting) {
        _bidPoll?.cancel();
        _bidPoll = null;
        return;
      }
      try {
        final RideBid? fresh = await _requests.getBid(bidId);
        if (fresh == null || !mounted) return;
        if (state.phase != BidPhase.waiting) return;
        if (fresh.status != RideBidStatus.pending) {
          AppLogger.w(
            'bid poll caught a status realtime missed',
            data: <String, dynamic>{
              'bid_id': bidId,
              'status': fresh.status.name,
            },
          );
          await _handleBidUpdate(bidId, fresh);
        }
      } catch (_) {
        // Silent — the realtime stream is the primary path. Polling is
        // best-effort.
      }
    });
  }

  Future<void> _handleBidUpdate(String bidId, RideBid bid) async {
    if (!mounted) return;
    switch (bid.status) {
      case RideBidStatus.accepted:
        // Look up the trip created for this bid and advance.
        final String? tripId = await _requests.findTripIdForBid(bidId);
        if (!mounted) return;
        state = state.copyWith(phase: BidPhase.won, tripId: tripId);
        _bidPoll?.cancel();
        _bidPoll = null;
      case RideBidStatus.rejected:
        state = state.copyWith(
          phase: BidPhase.lost,
          error: 'Another driver was chosen.',
        );
        _bidPoll?.cancel();
        _bidPoll = null;
      case RideBidStatus.expired:
        state = state.copyWith(
          phase: BidPhase.lost,
          error: 'Your bid expired.',
        );
        _bidPoll?.cancel();
        _bidPoll = null;
      case RideBidStatus.withdrawn:
        state = state.copyWith(phase: BidPhase.composing);
        _bidPoll?.cancel();
        _bidPoll = null;
      case RideBidStatus.pending:
        // No-op
        break;
    }
  }

  Future<void> withdraw() async {
    final String? bidId = state.bidId;
    if (bidId == null) return;
    try {
      await _requests.withdrawBid(bidId);
      if (!mounted) return;
      state = state.copyWith(phase: BidPhase.composing, bidId: null);
    } catch (e, s) {
      if (!mounted) return;
      AppLogger.e('Bid withdraw failed', error: e, stackTrace: s);
      state = state.copyWith(
        error: humaniseError(e, fallback: "Couldn't withdraw your bid."),
      );
    }
  }

  /// Driver's saved pricing profile drives this — base + per-km, plus
  /// peak/night multiplier if the toggle is enabled and the request's
  /// local hour falls in the corresponding window. Rounds to the nearest
  /// ₦100 (via the shared helper on [PricingProfile] so the pricing-tab
  /// preview and the bid composer never drift apart) and clamps to the
  /// absolute floor / ceiling.
  int _suggestedForRequest(RideRequest req) {
    final int raw = _pricingProfile.suggestFor(
      req.expectedDistanceM ?? 0,
      req.createdAt,
    );
    return PricingProfile.roundToNearestNaira100(raw)
        .clamp(_kAbsoluteMinMinor, _kAbsoluteMaxMinor);
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _bidSub?.cancel();
    _bidPoll?.cancel();
    super.dispose();
  }
}

final rideRequestControllerProvider = StateNotifierProvider.autoDispose
    .family<RideRequestController, RideRequestState, String>(
  (Ref ref, String requestId) => RideRequestController(
    requestId: requestId,
    requests: locator<RideRequestRepository>(),
    vehicles: locator<VehicleRepository>(),
    pricing: locator<PricingRepository>(),
  ),
);
