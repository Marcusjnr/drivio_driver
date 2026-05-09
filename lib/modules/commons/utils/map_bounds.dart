import 'package:maplibre_gl/maplibre_gl.dart' show LatLng;

/// Compute a bounding box for a polyline as the (south-west, north-east)
/// pair the `LiveMap.fitBounds` parameter expects. Returns `null` for
/// fewer than two distinct points so the caller can keep its existing
/// fallback (typically the straight pickup→dropoff endpoints).
({LatLng a, LatLng b})? boundsForPoints(List<LatLng> points) {
  if (points.length < 2) {
    return null;
  }
  double minLat = points.first.latitude;
  double maxLat = points.first.latitude;
  double minLng = points.first.longitude;
  double maxLng = points.first.longitude;
  for (int i = 1; i < points.length; i++) {
    final LatLng p = points[i];
    if (p.latitude < minLat) {
      minLat = p.latitude;
    }
    if (p.latitude > maxLat) {
      maxLat = p.latitude;
    }
    if (p.longitude < minLng) {
      minLng = p.longitude;
    }
    if (p.longitude > maxLng) {
      maxLng = p.longitude;
    }
  }
  // A degenerate single-point polyline (all coords equal) is treated as
  // "no bounds" — the camera shouldn't zoom to a single pixel.
  if (minLat == maxLat && minLng == maxLng) {
    return null;
  }
  return (a: LatLng(minLat, minLng), b: LatLng(maxLat, maxLng));
}
