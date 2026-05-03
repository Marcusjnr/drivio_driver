import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:drivio_driver/modules/commons/bootstrap/bootstrap_destination.dart';
import 'package:drivio_driver/modules/commons/data/trip_repository.dart';
import 'package:drivio_driver/modules/commons/di/di.dart';
import 'package:drivio_driver/modules/commons/navigation/app_routes.dart';
import 'package:drivio_driver/modules/commons/supabase/supabase_module.dart';

class BootstrapState {
  const BootstrapState({
    this.destination = BootstrapDestination.welcome,
    this.isLoading = true,
    this.activeTripId,
  });

  final BootstrapDestination destination;
  final bool isLoading;
  final String? activeTripId;

  BootstrapState copyWith({
    BootstrapDestination? destination,
    bool? isLoading,
    String? activeTripId,
    bool clearActiveTripId = false,
  }) {
    return BootstrapState(
      destination: destination ?? this.destination,
      isLoading: isLoading ?? this.isLoading,
      activeTripId:
          clearActiveTripId ? null : (activeTripId ?? this.activeTripId),
    );
  }
}

class BootstrapController extends StateNotifier<BootstrapState> {
  BootstrapController() : super(const BootstrapState()) {
    resolve();
  }

  final SupabaseModule _supabase = locator<SupabaseModule>();
  final TripRepository _trips = locator<TripRepository>();

  Future<void> resolve() async {
    state = state.copyWith(isLoading: true, clearActiveTripId: true);

    try {
      final Session? session = _supabase.auth.currentSession;
      if (session == null) {
        state = state.copyWith(
          destination: BootstrapDestination.welcome,
          isLoading: false,
        );
        return;
      }

      final String userId = session.user.id;

      // Profile must exist before anything else.
      final List<dynamic> profileRows = await _supabase
          .db('profiles')
          .select('user_id')
          .eq('user_id', userId)
          .limit(1);

      if (profileRows.isEmpty) {
        state = state.copyWith(
          destination: BootstrapDestination.completeProfile,
          isLoading: false,
        );
        return;
      }

      // DRV-009 cold-start resume: if the driver has a non-terminal trip,
      // drop them right back into it. The shell page reads the trip id
      // out of the route arguments and switches itself into trip mode —
      // we always land on /home because the shell is the canvas.
      final String? activeTripId = await _trips.getMyActiveTripId();
      state = state.copyWith(
        destination: BootstrapDestination.home,
        activeTripId: activeTripId,
        clearActiveTripId: activeTripId == null,
        isLoading: false,
      );
    } catch (_) {
      state = state.copyWith(
        destination: BootstrapDestination.welcome,
        isLoading: false,
      );
    }
  }

  String get initialRoute {
    switch (state.destination) {
      case BootstrapDestination.welcome:
        return AppRoutes.welcome;
      case BootstrapDestination.completeProfile:
        return AppRoutes.signUp;
      case BootstrapDestination.home:
        return AppRoutes.home;
    }
  }

  /// When destination is [BootstrapDestination.home] and there's an
  /// active trip, this returns the trip id so the shell page can mount
  /// straight into trip mode.
  Object? get initialArguments {
    if (state.destination == BootstrapDestination.home &&
        state.activeTripId != null) {
      return state.activeTripId;
    }
    return null;
  }
}

final StateNotifierProvider<BootstrapController, BootstrapState>
    bootstrapControllerProvider =
    StateNotifierProvider<BootstrapController, BootstrapState>(
  (Ref _) => BootstrapController(),
);
