import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import 'package:drivio_driver/modules/commons/di/di.dart';
import 'package:drivio_driver/modules/commons/supabase/supabase_module.dart';

class NetworkClient {
  NetworkClient();

  static const Uuid _uuid = Uuid();
  final SupabaseModule _supabase = locator<SupabaseModule>();

  /// Call an edge function directly (not queued).
  /// Use this for reads or non-critical writes.
  Future<FunctionResponse> invoke(
    String functionName, {
    Map<String, dynamic>? body,
    Map<String, String>? headers,
  }) {
    return _supabase.functions.invoke(
      functionName,
      body: body,
      headers: <String, String>{
        'Idempotency-Key': _uuid.v4(),
        ...?headers,
      },
    );
  }
}
