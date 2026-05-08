import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:drivio_driver/modules/commons/data/trip_repository.dart';
import 'package:drivio_driver/modules/commons/di/di.dart';
import 'package:drivio_driver/modules/commons/errors/error_messages.dart';
import 'package:drivio_driver/modules/commons/logging/app_logger.dart';
import 'package:drivio_driver/modules/commons/types/trip.dart';

class ActiveTripState {
  const ActiveTripState({
    this.tripId,
    this.trip,
    this.isLoading = false,
    this.isAdvancing = false,
    this.error,
  });

  final String? tripId;
  final Trip? trip;
  final bool isLoading;
  final bool isAdvancing;
  final String? error;

  TripState? get state => trip?.state;

  /// Next state the driver action button transitions to, or null if there
  /// isn't one (terminal states).
  TripState? get nextStateOnAdvance {
    switch (state) {
      case TripState.assigned:
        return TripState.enRoute;
      case TripState.enRoute:
        return TripState.arrived;
      case TripState.arrived:
        return TripState.inProgress;
      case TripState.inProgress:
        return TripState.completed;
      case TripState.completed:
      case TripState.cancelled:
      case null:
        return null;
    }
  }

  String get advanceLabel {
    switch (state) {
      case TripState.assigned:
        return "I'm on my way";
      case TripState.enRoute:
        return "I've arrived";
      case TripState.arrived:
        return 'Start trip';
      case TripState.inProgress:
        return 'Complete trip';
      case TripState.completed:
        return 'Back online';
      case TripState.cancelled:
        return 'Back to home';
      case null:
        return '…';
    }
  }

  ActiveTripState copyWith({
    String? tripId,
    Trip? trip,
    bool? isLoading,
    bool? isAdvancing,
    String? error,
    bool clearError = false,
  }) {
    return ActiveTripState(
      tripId: tripId ?? this.tripId,
      trip: trip ?? this.trip,
      isLoading: isLoading ?? this.isLoading,
      isAdvancing: isAdvancing ?? this.isAdvancing,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class ActiveTripController extends StateNotifier<ActiveTripState> {
  ActiveTripController({
    required String tripId,
    required TripRepository repo,
  })  : _repo = repo,
        super(ActiveTripState(tripId: tripId, isLoading: true)) {
    _hydrate();
  }

  final TripRepository _repo;
  StreamSubscription<Trip>? _sub;

  Future<void> _hydrate() async {
    try {
      final Trip? t = await _repo.getTrip(state.tripId!);
      if (!mounted) return;
      if (t == null) {
        state = state.copyWith(
          isLoading: false,
          error: 'Trip not found.',
        );
        return;
      }
      state = state.copyWith(trip: t, isLoading: false);
      _sub = _repo.watchTrip(state.tripId!).listen(
        (Trip fresh) {
          if (!mounted) return;
          state = state.copyWith(trip: fresh);
        },
        onError: (Object e) {
          if (!mounted) return;
          state = state.copyWith(error: 'Realtime: $e');
        },
      );
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(
        isLoading: false,
        error: 'Could not load trip: $e',
      );
    }
  }

  Future<void> advance() async {
    final TripState? next = state.nextStateOnAdvance;
    if (next == null) return;
    await _transitionTo(next);
  }

  Future<void> cancel({String reason = 'driver_cancelled'}) async {
    await _transitionTo(TripState.cancelled, reason: reason);
  }

  Future<void> _transitionTo(TripState next, {String? reason}) async {
    if (state.tripId == null || state.isAdvancing) return;
    state = state.copyWith(isAdvancing: true, clearError: true);
    try {
      await _repo.transition(
        tripId: state.tripId!,
        toState: next,
        reason: reason,
      );
      if (!mounted) return;
      // Realtime listener delivers the fresh row; just clear the busy flag.
      state = state.copyWith(isAdvancing: false);
    } catch (e, s) {
      if (!mounted) return;
      AppLogger.e('Trip transition failed', error: e, stackTrace: s);
      // Server returns "too_far_from_pickup_<n>m" — pull the distance
      // out so the driver sees exactly how far they are. For every
      // other shape, hand off to the central translator.
      final String raw = e.toString();
      final RegExpMatch? farMatch =
          RegExp(r'too_far_from_pickup_(\d+)m').firstMatch(raw);
      final String friendly = farMatch != null
          ? "You're ${farMatch.group(1)} m from the pickup. Get within 200 m to mark arrived."
          : humaniseError(e, fallback: "Couldn't update the trip.");
      state = state.copyWith(isAdvancing: false, error: friendly);
    }
  }

  Future<void> refresh() => _hydrate();

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

final activeTripControllerProvider = StateNotifierProvider.autoDispose
    .family<ActiveTripController, ActiveTripState, String>(
  (Ref ref, String tripId) => ActiveTripController(
    tripId: tripId,
    repo: locator<TripRepository>(),
  ),
);
