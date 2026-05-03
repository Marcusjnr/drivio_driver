import 'package:drivio_driver/modules/commons/data/safety_repository.dart';
import 'package:drivio_driver/modules/commons/supabase/supabase_module.dart';

class SupabaseSafetyRepository implements SafetyRepository {
  SupabaseSafetyRepository(this._supabase);

  final SupabaseModule _supabase;

  @override
  Future<String> triggerSos({
    String? tripId,
    String kind = 'sos',
    String severity = 'critical',
    Map<String, dynamic> payload = const <String, dynamic>{},
  }) async {
    final dynamic res = await _supabase.client.rpc<dynamic>(
      'trigger_sos',
      params: <String, dynamic>{
        'p_kind': kind,
        'p_severity': severity,
        'p_payload': payload,
        'p_trip_id': tripId,
      },
    );
    return res as String;
  }
}
