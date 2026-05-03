import 'dart:io';

import 'package:url_launcher/url_launcher.dart';

/// DRV-053: hand off turn-by-turn navigation to the platform's preferred
/// maps app (Google Maps on Android, Apple Maps on iOS, Google Maps on
/// the web), falling back to the universal Google Maps web URL.
class NavigationLauncher {
  NavigationLauncher._();

  /// Opens an external maps app routed from the user's current location to
  /// the given destination. Returns true if any handler was launched.
  ///
  /// Strategy:
  /// 1. Probe each platform-preferred candidate (`canLaunchUrl` → `launchUrl`).
  /// 2. If every probe fails (e.g. Android queries misconfigured, or the
  ///    device just doesn't have a custom maps scheme registered), force
  ///    the universal Google Maps web URL — browsers handle it on every
  ///    platform we ship to.
  static Future<bool> openDriving({
    required double destLat,
    required double destLng,
    String? destLabel,
  }) async {
    final List<Uri> candidates = _candidatesFor(destLat, destLng, destLabel);
    for (final Uri uri in candidates) {
      try {
        if (await canLaunchUrl(uri)) {
          final bool ok =
              await launchUrl(uri, mode: LaunchMode.externalApplication);
          if (ok) return true;
        }
      } catch (_) {
        // Try the next candidate.
      }
    }

    // Last-ditch: launch the web URL unconditionally. canLaunchUrl can
    // be over-restrictive on Android 11+ when manifest queries don't
    // include the scheme, but browsers always handle https.
    final Uri fallback = Uri.parse(
      'https://www.google.com/maps/dir/?api=1'
      '&destination=$destLat,$destLng&travelmode=driving',
    );
    try {
      return await launchUrl(fallback, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }

  static List<Uri> _candidatesFor(double lat, double lng, String? label) {
    final String coord = '$lat,$lng';
    final String? q = label == null
        ? null
        : Uri.encodeQueryComponent(label);

    if (Platform.isIOS) {
      return <Uri>[
        // Google Maps app deep-link (if installed).
        Uri.parse(
            'comgooglemaps://?daddr=$coord&directionsmode=driving${q == null ? '' : '&q=$q'}'),
        // Apple Maps.
        Uri.parse(
            'http://maps.apple.com/?daddr=$coord&dirflg=d${q == null ? '' : '&q=$q'}'),
        // Web fallback.
        Uri.parse(
            'https://www.google.com/maps/dir/?api=1&destination=$coord&travelmode=driving'),
      ];
    }

    // Android + everything else.
    return <Uri>[
      // Google Navigation (turn-by-turn) — Android only.
      Uri.parse('google.navigation:q=$coord&mode=d'),
      // Generic geo intent.
      Uri.parse('geo:$lat,$lng?q=$coord${q == null ? '' : '($q)'}'),
      // Web fallback (always works).
      Uri.parse(
          'https://www.google.com/maps/dir/?api=1&destination=$coord&travelmode=driving'),
    ];
  }
}
