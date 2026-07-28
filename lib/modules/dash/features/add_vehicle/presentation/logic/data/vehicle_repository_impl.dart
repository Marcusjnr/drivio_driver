import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:drivio_driver/modules/commons/supabase/supabase_module.dart';
import 'package:drivio_driver/modules/commons/types/vehicle.dart';
import 'package:drivio_driver/modules/dash/features/add_vehicle/presentation/logic/data/vehicle_repository.dart';

class SupabaseVehicleRepository implements VehicleRepository {
  SupabaseVehicleRepository(this._supabase);

  final SupabaseModule _supabase;

  @override
  Future<Vehicle> addVehicle({
    required String make,
    required String model,
    required int year,
    required String plate,
    String? colour,
    String? vin,
    String? transmission,
    String? fuelType,
    int? mileageKm,
  }) async {
    final User? user = _supabase.auth.currentUser;
    if (user == null) {
      throw const VehicleAuthException();
    }

    String? clean(String? v) =>
        (v == null || v.trim().isEmpty) ? null : v.trim();

    final Map<String, dynamic> row = await _supabase
        .db('vehicles')
        .insert(<String, dynamic>{
          'driver_id': user.id,
          'make': make.trim(),
          'model': model.trim(),
          'year': year,
          'colour': clean(colour),
          'plate': plate.trim().toUpperCase(),
          'vin': clean(vin)?.toUpperCase(),
          'transmission': clean(transmission),
          'fuel_type': clean(fuelType),
          'mileage_km': mileageKm,
        })
        .select()
        .single();

    return Vehicle.fromJson(row);
  }

  @override
  Future<List<Vehicle>> listMyVehicles() async {
    final User? user = _supabase.auth.currentUser;
    if (user == null) return const <Vehicle>[];

    final List<Map<String, dynamic>> rows = await _supabase
        .db('vehicles')
        .select()
        .eq('driver_id', user.id)
        .filter('deleted_at', 'is', null)
        .order('created_at', ascending: false);

    return rows.map(Vehicle.fromJson).toList(growable: false);
  }
}

class VehicleAuthException implements Exception {
  const VehicleAuthException();
  @override
  String toString() => 'VehicleAuthException: no signed-in user';
}
