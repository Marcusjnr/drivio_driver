enum VehicleCategory { economy, comfort, xl }

enum VehicleStatus { pending, active, suspended, retired }

class Vehicle {
  const Vehicle({
    required this.id,
    required this.driverId,
    required this.make,
    required this.model,
    required this.year,
    required this.plate,
    required this.category,
    required this.status,
    required this.seats,
    required this.createdAt,
    this.colour,
    this.vin,
  });

  final String id;
  final String driverId;
  final String make;
  final String model;
  final int year;
  final String? colour;
  final String plate;
  final String? vin;
  final int seats;
  final VehicleCategory category;
  final VehicleStatus status;
  final DateTime createdAt;

  factory Vehicle.fromJson(Map<String, dynamic> json) {
    return Vehicle(
      id: json['id'] as String,
      driverId: json['driver_id'] as String,
      make: json['make'] as String,
      model: json['model'] as String,
      year: (json['year'] as num).toInt(),
      colour: json['colour'] as String?,
      plate: json['plate'] as String,
      vin: json['vin'] as String?,
      seats: (json['seats'] as num).toInt(),
      category: VehicleCategory.values.firstWhere(
        (VehicleCategory v) => v.name == json['category'],
        orElse: () => VehicleCategory.economy,
      ),
      status: VehicleStatus.values.firstWhere(
        (VehicleStatus s) => s.name == json['status'],
        orElse: () => VehicleStatus.pending,
      ),
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Vehicle copyWith({
    String? id,
    String? driverId,
    String? make,
    String? model,
    int? year,
    String? colour,
    String? plate,
    String? vin,
    int? seats,
    VehicleCategory? category,
    VehicleStatus? status,
    DateTime? createdAt,
  }) {
    return Vehicle(
      id: id ?? this.id,
      driverId: driverId ?? this.driverId,
      make: make ?? this.make,
      model: model ?? this.model,
      year: year ?? this.year,
      colour: colour ?? this.colour,
      plate: plate ?? this.plate,
      vin: vin ?? this.vin,
      seats: seats ?? this.seats,
      category: category ?? this.category,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
