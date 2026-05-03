import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:drivio_driver/modules/commons/data/dashboard_repository.dart';
import 'package:drivio_driver/modules/commons/logging/app_logger.dart';
import 'package:drivio_driver/modules/commons/logging/supabase_logging.dart';
import 'package:drivio_driver/modules/commons/supabase/supabase_module.dart';
import 'package:drivio_driver/modules/commons/types/dashboard_summary.dart';

class SupabaseDashboardRepository implements DashboardRepository {
  SupabaseDashboardRepository(this._supabase);

  final SupabaseModule _supabase;

  @override
  Future<DashboardSummary> getMyToday() async {
    // Fail fast (and clearly) when the JWT isn't ready yet — otherwise
    // the SECURITY DEFINER function would raise the opaque
    // 'not_authenticated' exception server-side and we'd waste a
    // round-trip per retry. The controller's backoff catches this and
    // keeps trying until auth restores.
    final User? user = _supabase.auth.currentUser;
    if (user == null) {
      AppLogger.w('dashboard.getMyToday skipped — no auth user');
      throw const _DashboardAuthException();
    }

    // RPC returns a TABLE; PostgREST may surface it either as a JSON
    // array of rows (the common case) or — when the function returns
    // exactly one row — as a single object. Handle both shapes so a
    // future change on the server doesn't silently break us.
    final dynamic raw = await loggedRpc(_supabase, 'get_my_dashboard_today');
    if (raw == null) {
      AppLogger.w('dashboard.getMyToday: rpc returned null, returning empty');
      return DashboardSummary.empty;
    }
    if (raw is List<dynamic>) {
      if (raw.isEmpty) return DashboardSummary.empty;
      return DashboardSummary.fromJson(raw.first as Map<String, dynamic>);
    }
    if (raw is Map<String, dynamic>) {
      return DashboardSummary.fromJson(raw);
    }
    throw StateError(
      'get_my_dashboard_today returned unexpected shape: '
      '${raw.runtimeType}',
    );
  }
}

class _DashboardAuthException implements Exception {
  const _DashboardAuthException();
  @override
  String toString() => 'DashboardAuthException: no signed-in user';
}
