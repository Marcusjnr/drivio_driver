import 'package:drivio_driver/modules/commons/data/vehicle_catalog_repository.dart';
import 'package:drivio_driver/modules/commons/supabase/supabase_module.dart';

class SupabaseVehicleCatalogRepository implements VehicleCatalogRepository {
  SupabaseVehicleCatalogRepository(this._supabase);

  final SupabaseModule _supabase;

  @override
  Future<List<VehicleCatalogEntry>> getCatalog() async {
    final List<dynamic> rows = await _supabase.client.rpc<dynamic>(
      'get_vehicle_catalog',
    ) as List<dynamic>;
    return rows
        .map((dynamic r) =>
            VehicleCatalogEntry.fromJson(r as Map<String, dynamic>))
        .toList(growable: false);
  }
}
