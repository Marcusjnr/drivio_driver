import 'package:drivio_driver/modules/commons/supabase/supabase_module.dart';

/// A single curated amenity from `amenity_catalog`.
class AmenityOption {
  const AmenityOption({required this.code, required this.label});
  final String code;
  final String label;
}

abstract class DriverAmenitiesRepository {
  /// The active curated catalog, ordered for display.
  Future<List<AmenityOption>> catalog();

  /// The signed-in driver's currently selected amenity codes.
  Future<List<String>> myCodes();

  /// Replace the driver's amenity set; returns the persisted codes.
  Future<List<String>> setMyCodes(List<String> codes);
}

class SupabaseDriverAmenitiesRepository implements DriverAmenitiesRepository {
  SupabaseDriverAmenitiesRepository(this._supabase);
  final SupabaseModule _supabase;

  @override
  Future<List<AmenityOption>> catalog() async {
    final List<Map<String, dynamic>> rows =
        await _supabase.db('amenity_catalog').select('code,label').eq(
              'active',
              true,
            ).order('sort_order');
    return rows
        .map(
          (Map<String, dynamic> r) => AmenityOption(
            code: r['code'] as String,
            label: r['label'] as String,
          ),
        )
        .toList(growable: false);
  }

  @override
  Future<List<String>> myCodes() async {
    final dynamic res = await _supabase.client.rpc<dynamic>('get_my_amenities');
    return (res as List<dynamic>? ?? <dynamic>[])
        .map((dynamic e) => e as String)
        .toList(growable: false);
  }

  @override
  Future<List<String>> setMyCodes(List<String> codes) async {
    final dynamic res = await _supabase.client.rpc<dynamic>(
      'set_my_amenities',
      params: <String, dynamic>{'p_codes': codes},
    );
    return (res as List<dynamic>? ?? <dynamic>[])
        .map((dynamic e) => e as String)
        .toList(growable: false);
  }
}
