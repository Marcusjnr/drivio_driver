import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:drivio_driver/modules/commons/di/di.dart';
import 'package:drivio_driver/modules/commons/types/vehicle.dart';
import 'package:drivio_driver/modules/dash/features/add_vehicle/presentation/logic/data/vehicle_repository.dart';

enum DriverStatus { offline, online, onTrip }

class HomeState {
  const HomeState({
    this.status = DriverStatus.offline,
    this.hasVehicle = false,
    this.hasAnyVehicle = false,
    this.pendingVehicle,
    this.isVehicleLoaded = false,
    this.priceTrip = 3800,
    this.todaysEarnings = 24800,
    this.tripsToday = 7,
    this.hoursOnline = 5.2,
    this.rating = 4.9,
  });

  final DriverStatus status;

  /// True when the driver has at least one `status = active` vehicle.
  /// Drives the online-toggle gate.
  final bool hasVehicle;

  /// True when any non-deleted vehicle exists (pending/active/suspended).
  /// Used to differentiate "no vehicle yet" from "vehicle awaiting review".
  final bool hasAnyVehicle;

  /// Most recently registered non-active vehicle, used by the
  /// "vehicle pending" gate sheet to show specifics.
  final Vehicle? pendingVehicle;

  final bool isVehicleLoaded;
  final int priceTrip;
  final int todaysEarnings;
  final int tripsToday;
  final double hoursOnline;
  final double rating;

  bool get isOnline => status == DriverStatus.online;
  bool get isOnTrip => status == DriverStatus.onTrip;

  HomeState copyWith({
    DriverStatus? status,
    bool? hasVehicle,
    bool? hasAnyVehicle,
    Vehicle? pendingVehicle,
    bool clearPendingVehicle = false,
    bool? isVehicleLoaded,
    int? priceTrip,
  }) {
    return HomeState(
      status: status ?? this.status,
      hasVehicle: hasVehicle ?? this.hasVehicle,
      hasAnyVehicle: hasAnyVehicle ?? this.hasAnyVehicle,
      pendingVehicle:
          clearPendingVehicle ? null : (pendingVehicle ?? this.pendingVehicle),
      isVehicleLoaded: isVehicleLoaded ?? this.isVehicleLoaded,
      priceTrip: priceTrip ?? this.priceTrip,
      todaysEarnings: todaysEarnings,
      tripsToday: tripsToday,
      hoursOnline: hoursOnline,
      rating: rating,
    );
  }
}

class HomeController extends StateNotifier<HomeState> {
  HomeController(this._vehicles) : super(const HomeState());

  final VehicleRepository _vehicles;

  Future<void> refreshVehicleStatus() async {
    try {
      final List<Vehicle> mine = await _vehicles.listMyVehicles();
      final bool hasActive =
          mine.any((Vehicle v) => v.status == VehicleStatus.active);
      final Vehicle? pending = hasActive
          ? null
          : mine
              .where((Vehicle v) => v.status == VehicleStatus.pending)
              .cast<Vehicle?>()
              .firstWhere(
                (Vehicle? _) => true,
                orElse: () => null,
              );

      state = state.copyWith(
        hasVehicle: hasActive,
        hasAnyVehicle: mine.isNotEmpty,
        pendingVehicle: pending,
        clearPendingVehicle: pending == null,
        isVehicleLoaded: true,
      );
    } catch (_) {
      state = state.copyWith(isVehicleLoaded: true);
    }
  }

  void toggleOnline() {
    if (!state.hasVehicle && !state.isOnline) {
      return;
    }
    state = state.copyWith(
      status: state.isOnline ? DriverStatus.offline : DriverStatus.online,
    );
  }

  void setHasVehicle(bool value) =>
      state = state.copyWith(hasVehicle: value, isVehicleLoaded: true);
  void setStatus(DriverStatus s) => state = state.copyWith(status: s);
}

final StateNotifierProvider<HomeController, HomeState> homeControllerProvider =
    StateNotifierProvider<HomeController, HomeState>(
  (Ref _) => HomeController(locator<VehicleRepository>()),
);
