/// One bucket on the demand-heatmap overlay. Returned by the
/// `get_demand_heatmap` RPC — one row per geohash6 cell that has at
/// least one open request in the trailing window.
class DemandCell {
  const DemandCell({
    required this.cellId,
    required this.centerLat,
    required this.centerLng,
    required this.latSpan,
    required this.lngSpan,
    required this.requestCount,
  });

  final String cellId;
  final double centerLat;
  final double centerLng;

  /// Cell height in degrees latitude. Used to render the polygon
  /// without re-decoding the geohash on the client.
  final double latSpan;

  /// Cell width in degrees longitude.
  final double lngSpan;

  /// Open requests in the cell within the trailing window.
  final int requestCount;

  factory DemandCell.fromJson(Map<String, dynamic> json) {
    return DemandCell(
      cellId: json['cell_id'] as String,
      centerLat: (json['center_lat'] as num).toDouble(),
      centerLng: (json['center_lng'] as num).toDouble(),
      latSpan: (json['cell_lat_span'] as num).toDouble(),
      lngSpan: (json['cell_lng_span'] as num).toDouble(),
      requestCount: (json['request_count'] as num).toInt(),
    );
  }
}
