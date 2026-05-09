import 'package:maplibre_gl/maplibre_gl.dart' show LatLng;

/// Decode a Google Encoded Polyline Algorithm Format string into a list
/// of `LatLng`. The format is the standard one returned by Google's
/// Routes API in `routes[0].polyline.encodedPolyline`.
///
/// Algorithm reference:
/// https://developers.google.com/maps/documentation/utilities/polylinealgorithm
///
/// Each point is encoded as a delta from the previous one to keep the
/// payload tiny. Latitude and longitude are independently delta-encoded
/// as signed 5-decimal integers (1e5 precision), then each integer is
/// chunked into 5-bit groups, OR'd with 0x20 except the final chunk,
/// and offset by 63 to land in printable ASCII.
List<LatLng> decodePolyline(String encoded) {
  final List<LatLng> points = <LatLng>[];
  int index = 0;
  final int len = encoded.length;
  int lat = 0;
  int lng = 0;

  while (index < len) {
    int shift = 0;
    int result = 0;
    int b;
    do {
      b = encoded.codeUnitAt(index++) - 63;
      result |= (b & 0x1f) << shift;
      shift += 5;
    } while (b >= 0x20);
    final int dLat = ((result & 1) != 0) ? ~(result >> 1) : (result >> 1);
    lat += dLat;

    shift = 0;
    result = 0;
    do {
      b = encoded.codeUnitAt(index++) - 63;
      result |= (b & 0x1f) << shift;
      shift += 5;
    } while (b >= 0x20);
    final int dLng = ((result & 1) != 0) ? ~(result >> 1) : (result >> 1);
    lng += dLng;

    points.add(LatLng(lat / 1e5, lng / 1e5));
  }

  return points;
}
