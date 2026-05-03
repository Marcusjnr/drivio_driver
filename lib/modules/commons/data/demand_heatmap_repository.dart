import 'package:drivio_driver/modules/commons/types/demand_cell.dart';

abstract class DemandHeatmapRepository {
  /// Aggregated open-request counts per geohash6 cell over the last
  /// [minutes]. Returned ordered hottest-first; server caps the row
  /// count at [maxCells] (1000 hard ceiling).
  Future<List<DemandCell>> getHeatmap({
    int minutes = 30,
    int maxCells = 200,
  });
}
