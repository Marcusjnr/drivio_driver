import 'package:drivio_driver/modules/commons/types/vehicle.dart';

abstract class VehicleRepository {
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
  });

  Future<List<Vehicle>> listMyVehicles();
}
