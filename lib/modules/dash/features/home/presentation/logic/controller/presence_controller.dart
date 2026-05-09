import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import 'package:drivio_driver/modules/commons/data/presence_repository.dart';
import 'package:drivio_driver/modules/commons/di/di.dart';

enum PresencePermissionState {
  unknown,
  granted,
  denied,
  permanentlyDenied,
  serviceDisabled,
}

class PresenceState {
  const PresenceState({
    this.permission = PresencePermissionState.unknown,
    this.isStreaming = false,
    this.lastLat,
    this.lastLng,
    this.lastAccuracyM,
    this.lastUpdatedAt,
    this.error,
  });

  final PresencePermissionState permission;
  final bool isStreaming;
  final double? lastLat;
  final double? lastLng;
  final int? lastAccuracyM;
  final DateTime? lastUpdatedAt;
  final String? error;

  bool get hasFix => lastLat != null && lastLng != null;

  PresenceState copyWith({
    PresencePermissionState? permission,
    bool? isStreaming,
    double? lastLat,
    double? lastLng,
    int? lastAccuracyM,
    DateTime? lastUpdatedAt,
    String? error,
    bool clearError = false,
  }) {
    return PresenceState(
      permission: permission ?? this.permission,
      isStreaming: isStreaming ?? this.isStreaming,
      lastLat: lastLat ?? this.lastLat,
      lastLng: lastLng ?? this.lastLng,
      lastAccuracyM: lastAccuracyM ?? this.lastAccuracyM,
      lastUpdatedAt: lastUpdatedAt ?? this.lastUpdatedAt,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class PresenceController extends StateNotifier<PresenceState> {
  PresenceController(this._repo) : super(const PresenceState());

  final PresenceRepository _repo;
  StreamSubscription<Position>? _positionSub;
  Timer? _heartbeat;

  /// Asks for location permission, then starts streaming. Returns true on
  /// success.
  Future<bool> startStreaming({String? vehicleId}) async {
    state = state.copyWith(clearError: true);

    final bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      state = state.copyWith(
        permission: PresencePermissionState.serviceDisabled,
        error: 'Turn on location services to go online.',
      );
      return false;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever) {
      state = state.copyWith(
        permission: PresencePermissionState.permanentlyDenied,
        error: 'Location is blocked. Enable it in Settings to go online.',
      );
      return false;
    }
    if (permission == LocationPermission.denied) {
      state = state.copyWith(
        permission: PresencePermissionState.denied,
        error: 'Location permission is required.',
      );
      return false;
    }

    state = state.copyWith(permission: PresencePermissionState.granted);

    // Best-effort initial fix → upsert immediately.
    try {
      final Position first = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 8),
        ),
      );
      await _publish(first, vehicleId: vehicleId);
    } catch (_) {
      // No fix yet — stream will deliver one.
    }

    await _positionSub?.cancel();
    _positionSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10, // metres
      ),
    ).listen(
      (Position p) => _publish(p, vehicleId: vehicleId),
      onError: (Object e) => state = state.copyWith(error: e.toString()),
    );

    // 30s heartbeat per DRV-037, even if the driver is stationary.
    _heartbeat?.cancel();
    _heartbeat = Timer.periodic(const Duration(seconds: 30), (_) async {
      if (state.lastLat == null) return;
      try {
        await _repo.upsert(
          status: PresenceStatus.online,
          lat: state.lastLat,
          lng: state.lastLng,
          accuracyM: state.lastAccuracyM,
          vehicleId: vehicleId,
        );
      } catch (_) {
        // Network blip / connection reset — next tick (30s) retries.
        // Heartbeat is best-effort; missing one tick is fine.
      }
    });

    state = state.copyWith(isStreaming: true);
    return true;
  }

  Future<void> stopStreaming() async {
    await _positionSub?.cancel();
    _positionSub = null;
    _heartbeat?.cancel();
    _heartbeat = null;
    try {
      await _repo.upsert(status: PresenceStatus.offline);
    } catch (_) {
      // best effort
    }
    state = state.copyWith(isStreaming: false);
  }

  Future<void> _publish(Position p, {String? vehicleId}) async {
    state = state.copyWith(
      lastLat: p.latitude,
      lastLng: p.longitude,
      lastAccuracyM: p.accuracy.round(),
      lastUpdatedAt: DateTime.now(),
      clearError: true,
    );
    try {
      await _repo.upsert(
        status: PresenceStatus.online,
        lat: p.latitude,
        lng: p.longitude,
        accuracyM: p.accuracy.round(),
        headingDeg: p.heading.round(),
        speedKph: (p.speed * 3.6).round(),
        vehicleId: vehicleId,
      );
    } catch (_) {
      // Network blip — next tick retries.
    }
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    _heartbeat?.cancel();
    super.dispose();
  }
}

final StateNotifierProvider<PresenceController, PresenceState>
    presenceControllerProvider =
    StateNotifierProvider<PresenceController, PresenceState>(
  (Ref _) => PresenceController(locator<PresenceRepository>()),
);
