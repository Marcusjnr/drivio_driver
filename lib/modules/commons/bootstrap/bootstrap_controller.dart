import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:drivio_driver/modules/commons/analytics/analytics_events.dart';
import 'package:drivio_driver/modules/commons/analytics/mixpanel_service.dart';
import 'package:drivio_driver/modules/commons/bootstrap/bootstrap_destination.dart';
import 'package:drivio_driver/modules/commons/data/trip_repository.dart';
import 'package:drivio_driver/modules/commons/data/update_repository.dart';
import 'package:drivio_driver/modules/commons/di/di.dart';
import 'package:drivio_driver/modules/commons/logging/app_logger.dart';
import 'package:drivio_driver/modules/commons/navigation/app_routes.dart';
import 'package:drivio_driver/modules/commons/notifications/app_notifier.dart';
import 'package:drivio_driver/modules/commons/supabase/supabase_module.dart';
import 'package:drivio_driver/modules/commons/types/app_update.dart';
import 'package:drivio_driver/modules/commons/utils/store_launcher.dart';

class BootstrapState {
  const BootstrapState({
    this.destination = BootstrapDestination.welcome,
    this.isLoading = true,
    this.activeTripId,
    this.updateCheck = UpdateCheck.none,
  });

  final BootstrapDestination destination;
  final bool isLoading;
  final String? activeTripId;

  /// Boot-time version verdict. The forced-update page reads its store
  /// URL from here.
  final UpdateCheck updateCheck;

  BootstrapState copyWith({
    BootstrapDestination? destination,
    bool? isLoading,
    String? activeTripId,
    UpdateCheck? updateCheck,
    bool clearActiveTripId = false,
  }) {
    return BootstrapState(
      destination: destination ?? this.destination,
      isLoading: isLoading ?? this.isLoading,
      activeTripId:
          clearActiveTripId ? null : (activeTripId ?? this.activeTripId),
      updateCheck: updateCheck ?? this.updateCheck,
    );
  }
}

class BootstrapController extends StateNotifier<BootstrapState> {
  BootstrapController() : super(const BootstrapState()) {
    resolve();
  }

  final SupabaseModule _supabase = locator<SupabaseModule>();
  final TripRepository _trips = locator<TripRepository>();

  /// Guards the one-shot "App Opened" + identify so a re-`resolve()`
  /// (e.g. after sign-in) doesn't double-count the launch.
  bool _appOpenedTracked = false;

  /// The version gate runs once per process. A re-`resolve()` after
  /// sign-in must not re-fetch the channel or re-show the nudge.
  bool _updateChecked = false;

  Future<void> resolve() async {
    state = state.copyWith(isLoading: true, clearActiveTripId: true);
    AppLogger.i('bootstrap.resolve start');

    // Version gate first: a build below the supported floor never gets
    // past the splash, signed in or not. The repository fails open, so a
    // driver with no signal is unaffected.
    if (!_updateChecked) {
      _updateChecked = true;
      final UpdateCheck check = await locator<UpdateRepository>().check();
      if (check.verdict == UpdateVerdict.required) {
        state = state.copyWith(
          destination: BootstrapDestination.forcedUpdate,
          updateCheck: check,
          isLoading: false,
        );
        return;
      }
      if (check.verdict == UpdateVerdict.recommended) {
        state = state.copyWith(updateCheck: check);
        // Let the first page settle before nudging; the banner host sits
        // above all routes so this lands wherever the driver ends up.
        Future<void>.delayed(const Duration(seconds: 2), () {
          AppNotifier.info(
            title: 'Update available',
            message: 'A new version of Drivio is ready.',
            duration: const Duration(seconds: 10),
            actionLabel: 'Update',
            onAction: () => openStoreListing(check.updateUrl),
          );
        });
      }
    }

    try {
      final Session? session = _supabase.auth.currentSession;
      if (session == null) {
        AppLogger.w('bootstrap.resolve: no session → welcome');
        state = state.copyWith(
          destination: BootstrapDestination.welcome,
          isLoading: false,
        );
        return;
      }

      final String userId = session.user.id;
      AppLogger.i('bootstrap.resolve: have session',
          data: <String, dynamic>{'user_id': userId});

      // Signed-in session known at startup — tie analytics to the driver
      // and stamp the launch. Distinct id is the Supabase user uuid.
      if (!_appOpenedTracked) {
        _appOpenedTracked = true;
        final MixpanelService mp = locator<MixpanelService>();
        mp.identifyUser(userId);
        mp.setProfile(<String, dynamic>{'user_role': 'driver'});
        mp.track(AnalyticsEvents.appOpened);
      }

      // Profile must exist before anything else.
      final List<dynamic> profileRows = await _supabase
          .db('profiles')
          .select('user_id')
          .eq('user_id', userId)
          .limit(1);

      if (profileRows.isEmpty) {
        AppLogger.w('bootstrap.resolve: no profile row → completeProfile');
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
      // Active-trip lookup is best-effort — if the RPC errors (e.g.
      // schema drift on the shared Supabase project), we still send a
      // signed-in driver with a profile to /home rather than bouncing
      // them back to /welcome.
      String? activeTripId;
      try {
        activeTripId = await _trips.getMyActiveTripId();
      } catch (e, st) {
        AppLogger.w('bootstrap.resolve: getMyActiveTripId threw — ignoring',
            error: e, stackTrace: st);
        activeTripId = null;
      }
      AppLogger.i('bootstrap.resolve → home',
          data: <String, dynamic>{'active_trip_id': activeTripId ?? '—'});
      state = state.copyWith(
        destination: BootstrapDestination.home,
        activeTripId: activeTripId,
        clearActiveTripId: activeTripId == null,
        isLoading: false,
      );
    } catch (e, st) {
      AppLogger.e('bootstrap.resolve threw → welcome',
          error: e, stackTrace: st);
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
      case BootstrapDestination.forcedUpdate:
        return AppRoutes.forcedUpdate;
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
