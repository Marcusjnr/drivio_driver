import 'package:maplibre_gl/maplibre_gl.dart' show LatLng;

/// Driving-route lookup used by the live map to draw the road-following
/// "route ahead" polyline (driver position → pickup pre-trip, → dropoff
/// in-trip).
///
/// Calls `places-proxy/directions` on the shared Supabase project,
/// which proxies Google's Routes API v2 (the legacy Directions API has
/// been disabled for new Cloud projects since March 2025).
abstract interface class DirectionsRepository {
  /// Returns the road-following shape between two points, plus distance
  /// and duration. Throws [DirectionsNoRoute] when Google can't produce
  /// a route (e.g. across water) or [DirectionsNotConfigured] when the
  /// API key is missing on the server.
  Future<DirectionsResult> route({
    required double originLat,
    required double originLng,
    required double destinationLat,
    required double destinationLng,
  });
}

/// Result of a `/directions` proxy call. `points` is the road-following
/// shape decoded from the Routes API encoded polyline.
class DirectionsResult {
  const DirectionsResult({
    required this.points,
    required this.distanceM,
    required this.durationS,
  });

  final List<LatLng> points;
  final int distanceM;
  final int durationS;
}

class DirectionsNoRoute implements Exception {
  const DirectionsNoRoute();
  @override
  String toString() => 'No driving route between those points.';
}

class DirectionsNotConfigured implements Exception {
  const DirectionsNotConfigured();
  @override
  String toString() => 'Directions API not configured.';
}
