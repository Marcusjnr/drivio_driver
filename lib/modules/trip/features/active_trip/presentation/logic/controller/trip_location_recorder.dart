import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:drivio_driver/modules/commons/data/trip_location_repository.dart';
import 'package:drivio_driver/modules/commons/di/di.dart';
import 'package:drivio_driver/modules/commons/types/trip.dart';
import 'package:drivio_driver/modules/dash/features/home/presentation/logic/controller/presence_controller.dart';

/// Per spec DRV-054: while a trip is live, broadcast the driver's GPS at
/// 1 Hz on `trip:<id>:driver_location` and persist a sample every 5 s to
/// `trip_locations`. The latter is what the receipt + dispute audit reads;
/// the broadcast is what a passenger map subscribes to.
const Duration _kBroadcastInterval = Duration(seconds: 1);
const Duration _kPersistInterval = Duration(seconds: 5);

class TripLocationRecorderState {
  const TripLocationRecorderState({
    this.isRecording = false,
    this.lastBroadcastAt,
    this.lastPersistAt,
    this.persistedCount = 0,
    this.samples = const <TripLocationSample>[],
    this.error,
  });

  final bool isRecording;
  final DateTime? lastBroadcastAt;
  final DateTime? lastPersistAt;
  final int persistedCount;

  /// Recorded breadcrumbs in chronological order (oldest → newest).
  /// Drives the polyline overlay on the trip map.
  final List<TripLocationSample> samples;

  final String? error;

  TripLocationRecorderState copyWith({
    bool? isRecording,
    DateTime? lastBroadcastAt,
    DateTime? lastPersistAt,
    int? persistedCount,
    List<TripLocationSample>? samples,
    String? error,
    bool clearError = false,
  }) {
    return TripLocationRecorderState(
      isRecording: isRecording ?? this.isRecording,
      lastBroadcastAt: lastBroadcastAt ?? this.lastBroadcastAt,
      lastPersistAt: lastPersistAt ?? this.lastPersistAt,
      persistedCount: persistedCount ?? this.persistedCount,
      samples: samples ?? this.samples,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class TripLocationRecorder extends StateNotifier<TripLocationRecorderState> {
  TripLocationRecorder({
    required this.tripId,
    required TripLocationRepository repo,
    required this.readPresence,
  })  : _repo = repo,
        super(const TripLocationRecorderState());

  final String tripId;
  final TripLocationRepository _repo;

  /// Source of truth for the latest GPS fix. Injected so the recorder
  /// stays decoupled from how presence is acquired (geolocator stream,
  /// background plugin, etc.).
  final PresenceState Function() readPresence;

  Timer? _broadcastTicker;
  Timer? _persistTicker;
  TripState? _lastSeenState;

  /// Reacts to trip state changes. Starts when entering a live state,
  /// stops when reaching a terminal one. Idempotent.
  void onTripStateChanged(TripState newState) {
    if (newState == _lastSeenState) return;
    _lastSeenState = newState;
    final bool isLive = newState == TripState.enRoute ||
        newState == TripState.arrived ||
        newState == TripState.inProgress;
    if (isLive && !state.isRecording) {
      _start();
    } else if (!isLive && state.isRecording) {
      _stop();
    }
  }

  void _start() {
    _broadcastTicker?.cancel();
    _persistTicker?.cancel();
    _broadcastTicker = Timer.periodic(_kBroadcastInterval, (_) => _tickBroadcast());
    _persistTicker = Timer.periodic(_kPersistInterval, (_) => _tickPersist());
    state = state.copyWith(isRecording: true, clearError: true);
    // Hydrate previously-recorded breadcrumbs (covers cold-start resume
    // mid-trip), then emit one fresh sample.
    unawaited(_hydrateExistingSamples());
    unawaited(_tickPersist());
  }

  Future<void> _hydrateExistingSamples() async {
    try {
      final List<TripLocationSample> rows =
          await _repo.listSamples(tripId: tripId);
      if (!mounted) return;
      // Server returns newest-first; reverse for chronological order.
      final List<TripLocationSample> chrono =
          rows.reversed.toList(growable: true);
      state = state.copyWith(samples: chrono);
    } catch (_) {
      // Best effort; leave samples as-is.
    }
  }

  void _stop() {
    _broadcastTicker?.cancel();
    _broadcastTicker = null;
    _persistTicker?.cancel();
    _persistTicker = null;
    state = state.copyWith(isRecording: false);
  }

  Future<void> _tickBroadcast() async {
    final PresenceState p = readPresence();
    if (p.lastLat == null || p.lastLng == null) return;
    try {
      await _repo.broadcast(
        tripId: tripId,
        lat: p.lastLat!,
        lng: p.lastLng!,
      );
      if (!mounted) return;
      state = state.copyWith(lastBroadcastAt: DateTime.now());
    } catch (_) {
      // Broadcast is best-effort; the persistence path is the source of
      // truth. Ignore transient errors.
    }
  }

  Future<void> _tickPersist() async {
    final PresenceState p = readPresence();
    if (p.lastLat == null || p.lastLng == null) return;
    final DateTime now = DateTime.now();
    try {
      await _repo.record(
        tripId: tripId,
        lat: p.lastLat!,
        lng: p.lastLng!,
        recordedAt: now,
      );
      if (!mounted) return;
      final TripLocationSample sample = TripLocationSample(
        lat: p.lastLat!,
        lng: p.lastLng!,
        recordedAt: now,
      );
      state = state.copyWith(
        lastPersistAt: now,
        persistedCount: state.persistedCount + 1,
        samples: <TripLocationSample>[...state.samples, sample],
      );
    } catch (e) {
      if (!mounted) return;
      // Quiet log to state — UI can show a small indicator if it cares.
      state = state.copyWith(error: e.toString());
    }
  }

  @override
  void dispose() {
    _stop();
    super.dispose();
  }
}

final tripLocationRecorderProvider = StateNotifierProvider.autoDispose
    .family<TripLocationRecorder, TripLocationRecorderState, String>(
  (Ref ref, String tripId) {
    return TripLocationRecorder(
      tripId: tripId,
      repo: locator<TripLocationRepository>(),
      readPresence: () => ref.read(presenceControllerProvider),
    );
  },
);
