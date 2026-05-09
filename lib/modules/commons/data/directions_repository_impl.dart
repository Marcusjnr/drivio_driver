import 'package:drivio_driver/modules/commons/data/directions_repository.dart';
import 'package:drivio_driver/modules/commons/logging/app_logger.dart';
import 'package:drivio_driver/modules/commons/network/network_client.dart';
import 'package:drivio_driver/modules/commons/utils/polyline_codec.dart';
import 'package:maplibre_gl/maplibre_gl.dart' show LatLng;
import 'package:supabase_flutter/supabase_flutter.dart';

/// Calls the shared `places-proxy/directions` edge function (deployed
/// from the user app's Supabase project — driver + user point at the
/// same project, so no separate deploy is needed here).
class SupabaseDirectionsRepository implements DirectionsRepository {
  SupabaseDirectionsRepository(this._network);

  final NetworkClient _network;

  static const String _path = 'places-proxy/directions';

  @override
  Future<DirectionsResult> route({
    required double originLat,
    required double originLng,
    required double destinationLat,
    required double destinationLng,
  }) async {
    final FunctionResponse res = await _network.invoke(
      _path,
      body: <String, dynamic>{
        'origin': <String, dynamic>{'lat': originLat, 'lng': originLng},
        'destination': <String, dynamic>{
          'lat': destinationLat,
          'lng': destinationLng,
        },
      },
    );

    final dynamic data = res.data;

    if (res.status == 503 && data is Map && data['code'] == 'config') {
      AppLogger.w('directions: places-proxy not configured');
      throw const DirectionsNotConfigured();
    }
    if (res.status == 404 && data is Map && data['code'] == 'no_route') {
      throw const DirectionsNoRoute();
    }
    if (res.status >= 400 || data is! Map) {
      final String code = data is Map
          ? (data['code'] as String? ?? 'upstream')
          : 'upstream';
      final String message = data is Map
          ? (data['message'] as String? ?? 'Directions call failed.')
          : 'Directions call failed.';
      AppLogger.w('directions failed', data: <String, dynamic>{
        'status': res.status,
        'code': code,
        'message': message,
      });
      throw DirectionsException(
        code: code,
        message: message,
        status: res.status,
      );
    }

    final Map<String, dynamic> payload = data.cast<String, dynamic>();
    final String encoded = (payload['polyline'] as String?) ?? '';
    final List<LatLng> points =
        encoded.isEmpty ? <LatLng>[] : decodePolyline(encoded);
    return DirectionsResult(
      points: points,
      distanceM: (payload['distance_m'] as num?)?.toInt() ?? 0,
      durationS: (payload['duration_s'] as num?)?.toInt() ?? 0,
    );
  }
}

class DirectionsException implements Exception {
  const DirectionsException({
    required this.code,
    required this.message,
    required this.status,
  });

  final String code;
  final String message;
  final int status;

  @override
  String toString() => 'DirectionsException($code, $status): $message';
}
