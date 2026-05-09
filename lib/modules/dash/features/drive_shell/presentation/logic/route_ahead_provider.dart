import 'package:drivio_driver/modules/commons/data/directions_repository.dart';
import 'package:drivio_driver/modules/commons/di/di.dart';
import 'package:drivio_driver/modules/commons/logging/app_logger.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maplibre_gl/maplibre_gl.dart' show LatLng;

/// Lookup key for the road-following polyline shown on the live map.
/// Coords are rounded by the call site so micro GPS drift doesn't
/// trigger a re-fetch on every tick — Riverpod treats two records with
/// equal field values as the same key, so the cache hit ratio stays
/// high while the driver is broadly stationary.
class RouteAheadKey {
  const RouteAheadKey({
    required this.originLat,
    required this.originLng,
    required this.destinationLat,
    required this.destinationLng,
  });

  final double originLat;
  final double originLng;
  final double destinationLat;
  final double destinationLng;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RouteAheadKey &&
          other.originLat == originLat &&
          other.originLng == originLng &&
          other.destinationLat == destinationLat &&
          other.destinationLng == destinationLng);

  @override
  int get hashCode =>
      Object.hash(originLat, originLng, destinationLat, destinationLng);
}

/// Snap a coordinate to a grid of about 100 m (≈ 0.001°) so the
/// `RouteAheadKey` doesn't change on every GPS tick. The displayed
/// polyline updates as soon as the driver crosses a grid cell.
double snapForRouteCache(double coord) {
  return (coord * 1000).round() / 1000.0;
}

/// Auto-fetched road-following shape from `origin → destination`.
/// Returns an empty list while loading or on any failure so the map
/// can fall back to the existing straight-line preview.
final FutureProviderFamily<List<LatLng>, RouteAheadKey>
routeAheadShapeProvider =
    FutureProvider.family<List<LatLng>, RouteAheadKey>(
      (Ref ref, RouteAheadKey key) async {
        try {
          final DirectionsResult res =
              await locator<DirectionsRepository>().route(
                originLat: key.originLat,
                originLng: key.originLng,
                destinationLat: key.destinationLat,
                destinationLng: key.destinationLng,
              );
          return res.points;
        } on DirectionsNoRoute {
          AppLogger.i('route_ahead: no route between origin and target');
          return const <LatLng>[];
        } on DirectionsNotConfigured {
          AppLogger.w('route_ahead: directions proxy not configured');
          return const <LatLng>[];
        } catch (e, st) {
          AppLogger.w('route_ahead: directions failed',
              error: e, stackTrace: st);
          return const <LatLng>[];
        }
      },
    );
