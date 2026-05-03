import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:drivio_driver/modules/commons/data/dashboard_repository.dart';
import 'package:drivio_driver/modules/commons/di/di.dart';
import 'package:drivio_driver/modules/commons/logging/app_logger.dart';
import 'package:drivio_driver/modules/commons/supabase/supabase_module.dart';
import 'package:drivio_driver/modules/commons/types/dashboard_summary.dart';

class DashboardState {
  const DashboardState({
    this.summary = DashboardSummary.empty,
    this.isLoading = true,
    this.lastFetchedAt,
    this.error,
  });

  final DashboardSummary summary;
  final bool isLoading;
  final DateTime? lastFetchedAt;
  final String? error;

  /// True the moment a successful fetch lands. Used by the home tile
  /// to distinguish "real ₦0 today" from "we never managed to load."
  bool get hasEverLoaded => lastFetchedAt != null;

  DashboardState copyWith({
    DashboardSummary? summary,
    bool? isLoading,
    DateTime? lastFetchedAt,
    String? error,
    bool clearError = false,
  }) {
    return DashboardState(
      summary: summary ?? this.summary,
      isLoading: isLoading ?? this.isLoading,
      lastFetchedAt: lastFetchedAt ?? this.lastFetchedAt,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// Owns the home-screen "today" tile (earnings / trips / online / rating).
/// Pulls a single RPC summary on mount and on a slow timer so the
/// numbers stay live without hammering the server. Other code paths
/// (trip-completed, going online) can call [refresh] for an immediate
/// update.
///
/// Cold-start race: the dashboard provider can spin up before Supabase
/// has fully restored auth, so the first call may throw
/// `not_authenticated`. We retry with short backoff (2s, 5s, 15s)
/// before falling back to the slow 60s ticker.
class DashboardController extends StateNotifier<DashboardState> {
  DashboardController(this._repo) : super(const DashboardState()) {
    _hydrate();
    // 60s is plenty for a "today's metrics" tile. Lighter than the
    // 5s presence stream and well inside the cache TTL on Supabase.
    _ticker = Timer.periodic(const Duration(seconds: 60), (_) => _hydrate());
    // Re-fire on auth-state changes so we recover the moment a
    // late-restoring session lands. Without this, a `signedIn` event
    // arriving after our retry burst exhausts would leave the tile
    // stuck until the 60s ticker fires.
    _authSub = locator<SupabaseModule>().auth.onAuthStateChange.listen(
      (AuthState s) {
        if (s.event == AuthChangeEvent.signedIn ||
            s.event == AuthChangeEvent.tokenRefreshed ||
            s.event == AuthChangeEvent.initialSession) {
          _retryAttempt = 0;
          _hydrate();
        }
      },
      onError: (Object _) {/* swallowed; tick covers it */},
    );
  }

  final DashboardRepository _repo;
  Timer? _ticker;
  StreamSubscription<AuthState>? _authSub;

  /// Backoff schedule for cold-start retries. Stops once a successful
  /// fetch lands; the 60s ticker takes over from there.
  static const List<Duration> _retryBackoff = <Duration>[
    Duration(seconds: 2),
    Duration(seconds: 5),
    Duration(seconds: 15),
  ];
  int _retryAttempt = 0;
  Timer? _retryTimer;

  /// Manual refresh — also resets the retry counter so the next
  /// failure starts a fresh backoff sequence instead of being a no-op
  /// because the previous burst was exhausted.
  Future<void> refresh() {
    _retryAttempt = 0;
    return _hydrate();
  }

  Future<void> _hydrate() async {
    AppLogger.d('dashboard._hydrate', data: <String, dynamic>{
      'attempt': _retryAttempt,
      'hasEverLoaded': state.hasEverLoaded,
    });
    try {
      final DashboardSummary s = await _repo.getMyToday();
      if (!mounted) return;
      state = state.copyWith(
        summary: s,
        isLoading: false,
        lastFetchedAt: DateTime.now(),
        clearError: true,
      );
      AppLogger.i('dashboard._hydrate ok', data: <String, dynamic>{
        'earnings_minor': s.earningsMinor,
        'trips': s.tripsCompleted,
        'online_seconds': s.onlineSeconds,
        'rating': s.rating,
      });
      // Successful fetch — drop any pending retry; the 60s ticker
      // is now in charge.
      _retryAttempt = 0;
      _retryTimer?.cancel();
      _retryTimer = null;
    } catch (e, st) {
      if (!mounted) return;
      // Keep the previous summary so a steady-state hiccup doesn't
      // blank a working tile. Only surface the error when we never
      // got a first successful load — that's the user-visible "stuck
      // on 0/0/0" failure mode worth flagging. Include the underlying
      // exception so it's diagnosable in the field.
      AppLogger.e(
        'dashboard._hydrate failed',
        data: <String, dynamic>{'attempt': _retryAttempt},
        error: e,
        stackTrace: st,
      );
      state = state.copyWith(
        isLoading: false,
        error: state.hasEverLoaded ? null : _humanise(e),
      );
      _scheduleRetry();
    }
  }

  /// Best-effort mapping from raw exception → short message the driver
  /// can act on (or at least relay to support).
  String _humanise(Object e) {
    final String s = e.toString();
    if (s.contains('DashboardAuthException')) {
      return 'Waiting for sign-in to restore…';
    }
    if (s.contains('not_authenticated')) {
      return 'Session expired — sign out and back in.';
    }
    if (s.contains('SocketException') || s.contains('Failed host lookup')) {
      return 'Offline — check your connection.';
    }
    // Show the raw error so a failing first-load is diagnosable
    // without grepping logs. Truncate to keep it readable.
    return s.length > 120 ? '${s.substring(0, 120)}…' : s;
  }

  void _scheduleRetry() {
    if (_retryAttempt >= _retryBackoff.length) {
      // Give up the fast retry; the 60s ticker will keep trying.
      return;
    }
    final Duration delay = _retryBackoff[_retryAttempt++];
    _retryTimer?.cancel();
    _retryTimer = Timer(delay, _hydrate);
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _retryTimer?.cancel();
    _authSub?.cancel();
    super.dispose();
  }
}

final StateNotifierProvider<DashboardController, DashboardState>
    dashboardControllerProvider =
    StateNotifierProvider<DashboardController, DashboardState>(
  (Ref _) => DashboardController(locator<DashboardRepository>()),
);
