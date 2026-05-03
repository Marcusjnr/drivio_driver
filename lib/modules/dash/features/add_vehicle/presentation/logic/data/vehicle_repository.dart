import 'package:drivio_driver/modules/commons/types/vehicle.dart';

abstract class VehicleRepository {
  Future<Vehicle> addVehicle({
    required String make,
    required String model,
    required int year,
    required String plate,
    String? colour,
  });

  Future<List<Vehicle>> listMyVehicles();
}
