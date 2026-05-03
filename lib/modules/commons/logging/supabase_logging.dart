import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:drivio_driver/modules/commons/logging/app_logger.dart';
import 'package:drivio_driver/modules/commons/supabase/supabase_module.dart';

/// Thin instrumentation around `SupabaseClient.rpc`. Logs:
///   * what we're calling and the params we're sending,
///   * how long the round-trip took,
///   * the full error (with PostgrestException details when present)
///     before re-throwing so callers see exactly what went wrong.
///
/// Use this from any repository that wants RPC-level diagnostics
/// without each impl rolling its own try/catch + log.
///
/// Example:
/// ```dart
/// final dynamic raw = await loggedRpc(
///   _supabase, 'get_my_dashboard_today',
/// );
/// ```
Future<dynamic> loggedRpc(
  SupabaseModule module,
  String fn, {
  Map<String, dynamic>? params,
}) async {
  final Stopwatch stopwatch = Stopwatch()..start();
  final String? userId = module.auth.currentUser?.id;
  AppLogger.i('rpc → $fn', data: <String, dynamic>{
    'user': userId ?? '(none)',
    if (params != null && params.isNotEmpty) 'params': params,
  });
  try {
    final dynamic result = await module.client.rpc<dynamic>(fn, params: params);
    stopwatch.stop();
    AppLogger.i('rpc ← $fn', data: <String, dynamic>{
      'ms': stopwatch.elapsedMilliseconds,
      'shape': _summarise(result),
    });
    return result;
  } catch (e, st) {
    stopwatch.stop();
    AppLogger.e(
      'rpc ✗ $fn',
      data: <String, dynamic>{
        'ms': stopwatch.elapsedMilliseconds,
        if (e is PostgrestException) ...<String, dynamic>{
          'code': e.code,
          'details': e.details,
          'hint': e.hint,
          'message': e.message,
        },
      },
      error: e,
      stackTrace: st,
    );
    rethrow;
  }
}

/// Compact, human-readable summary of a response payload — keeps the
/// log line short without dropping the type/length signal.
String _summarise(Object? raw) {
  if (raw == null) return 'null';
  if (raw is List) return 'List(${raw.length})';
  if (raw is Map) return 'Map(${raw.length} keys)';
  return raw.runtimeType.toString();
}
