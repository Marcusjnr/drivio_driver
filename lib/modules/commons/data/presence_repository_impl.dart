import 'package:drivio_driver/modules/commons/data/presence_repository.dart';
import 'package:drivio_driver/modules/commons/supabase/supabase_module.dart';

class SupabasePresenceRepository implements PresenceRepository {
  SupabasePresenceRepository(this._supabase);

  final SupabaseModule _supabase;

  @override
  Future<void> upsert({
    required PresenceStatus status,
    double? lat,
    double? lng,
    int? accuracyM,
    int? headingDeg,
    int? speedKph,
    int? batteryPct,
    String? vehicleId,
  }) async {
    await _supabase.client.rpc<void>(
      'upsert_driver_presence',
      params: <String, dynamic>{
        'p_status': status.wire,
        'p_lat': lat,
        'p_lng': lng,
        'p_accuracy_m': accuracyM,
        'p_heading_deg': headingDeg,
        'p_speed_kph': speedKph,
        'p_battery_pct': batteryPct,
        'p_vehicle_id': vehicleId,
      },
    );
  }
}
