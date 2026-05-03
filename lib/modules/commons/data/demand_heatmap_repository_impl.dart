import 'package:drivio_driver/modules/commons/data/demand_heatmap_repository.dart';
import 'package:drivio_driver/modules/commons/supabase/supabase_module.dart';
import 'package:drivio_driver/modules/commons/types/demand_cell.dart';

class SupabaseDemandHeatmapRepository implements DemandHeatmapRepository {
  SupabaseDemandHeatmapRepository(this._supabase);

  final SupabaseModule _supabase;

  @override
  Future<List<DemandCell>> getHeatmap({
    int minutes = 30,
    int maxCells = 200,
  }) async {
    final List<dynamic> rows = await _supabase.client.rpc<dynamic>(
      'get_demand_heatmap',
      params: <String, dynamic>{
        'p_minutes': minutes,
        'p_max_cells': maxCells,
      },
    ) as List<dynamic>;
    return rows
        .map((Object? r) => DemandCell.fromJson(r! as Map<String, dynamic>))
        .toList(growable: false);
  }
}
