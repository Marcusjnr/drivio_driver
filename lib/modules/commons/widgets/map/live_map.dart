import 'dart:async';
import 'dart:math' show Point;

import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

/// OpenFreeMap "liberty" style — free vector tiles, no API key, no quota.
/// Swap for MapTiler / Stadia / a self-hosted style.json when polish matters.
const String _openFreeMapLibertyStyle =
    'https://tiles.openfreemap.org/styles/liberty';

/// Default centre for first paint while we wait for a location fix.
/// Lagos, Marina (centre of v1's service area).
const LatLng _kDefaultCentre = LatLng(6.4530, 3.3958);

enum LiveMapMarkerKind { driver, pickup, dropoff, request }

/// A polyline on the live map. Multiple lines can be drawn at once
/// (e.g. recorded breadcrumb + a forward-looking route-ahead line).
/// Diffed on the map by [id].
class LiveMapPolyline {
  const LiveMapPolyline({
    required this.id,
    required this.points,
    this.color = '#0B7F52',
    this.width = 5,
    this.opacity = 0.95,
  });

  final String id;
  final List<LatLng> points;
  final String color;
  final double width;
  final double opacity;
}

/// A marker rendered as a coloured circle. Avoids the per-style icon-image
/// registration dance — fine for v1; swap for image symbols when we want
/// branded pins.
class LiveMapMarker {
  const LiveMapMarker({
    required this.id,
    required this.position,
    required this.kind,
    this.colorOverride,
    this.radius,
  });

  /// Stable id used for diffing on rebuild.
  final String id;
  final LatLng position;
  final LiveMapMarkerKind kind;
  final String? colorOverride;
  final double? radius;
}

/// A polygon ring (or list of rings — first ring is outer, subsequent are
/// holes). Use for service areas, demand hexes, restricted zones.
class LiveMapPolygon {
  const LiveMapPolygon({
    required this.id,
    required this.rings,
    this.fillColor = '#34D399',
    this.fillOpacity = 0.18,
    this.outlineColor = '#34D399',
  });

  final String id;
  final List<List<LatLng>> rings;
  final String fillColor;
  final double fillOpacity;
  final String outlineColor;
}

/// Reusable real-vector-map widget. Instantiates a single MapLibre view,
/// registers any markers/polylines/polygons after the style finishes
/// loading, and diffs on `didUpdateWidget` so updates from a parent are
/// efficient.
///
/// Usage:
/// ```dart
/// LiveMap(
///   initialCenter: LatLng(6.45, 3.4),
///   followUser: true,
///   markers: [LiveMapMarker(id: 'p', position: ..., kind: pickup)],
///   polylines: [LiveMapPolyline(id: 'route', points: routePoints)],
/// )
/// ```
class LiveMap extends StatefulWidget {
  const LiveMap({
    super.key,
    this.initialCenter,
    this.initialZoom = 14.0,
    this.followUser = false,
    this.showUserLocation = true,
    this.markers = const <LiveMapMarker>[],
    this.polylines = const <LiveMapPolyline>[],
    this.polygons = const <LiveMapPolygon>[],
    this.onTap,
    this.onUserLocationUpdated,
    this.minZoom = 3.0,
    this.maxZoom = 19.0,
    this.fitBounds,
  });

  final LatLng? initialCenter;
  final double initialZoom;

  /// When true, the camera follows the user's location (GPS-tracked).
  final bool followUser;

  /// When true, renders the platform's user location indicator (blue dot).
  final bool showUserLocation;

  final List<LiveMapMarker> markers;

  /// Zero or more polylines, each diffed by [LiveMapPolyline.id]. Lines
  /// with fewer than 2 points are silently skipped.
  final List<LiveMapPolyline> polylines;

  final List<LiveMapPolygon> polygons;

  final void Function(LatLng tappedPoint)? onTap;
  final void Function(UserLocation location)? onUserLocationUpdated;

  final double minZoom;
  final double maxZoom;

  /// When provided, the camera animates to fit these two corners of a
  /// bounding rectangle once the style has finished loading and again
  /// whenever the bounds change. Useful for the bidding preview where
  /// we want the whole pickup→dropoff route on screen at once.
  /// Pair this with `followUser: false` so the GPS dot doesn't yank
  /// the camera back.
  final ({LatLng a, LatLng b})? fitBounds;

  @override
  State<LiveMap> createState() => _LiveMapState();
}

class _LiveMapState extends State<LiveMap> {
  MapLibreMapController? _controller;
  bool _styleLoaded = false;

  // Track what we've already drawn so we can diff on update.
  final Map<String, Circle> _circlesById = <String, Circle>{};
  final Map<String, Fill> _fillsById = <String, Fill>{};
  final Map<String, Line> _linesById = <String, Line>{};

  @override
  Widget build(BuildContext context) {
    final LatLng centre = widget.initialCenter ?? _kDefaultCentre;
    return MapLibreMap(
      styleString: _openFreeMapLibertyStyle,
      initialCameraPosition: CameraPosition(
        target: centre,
        zoom: widget.initialZoom,
      ),
      minMaxZoomPreference: MinMaxZoomPreference(widget.minZoom, widget.maxZoom),
      myLocationEnabled: widget.showUserLocation,
      myLocationTrackingMode: widget.followUser
          ? MyLocationTrackingMode.trackingGps
          : MyLocationTrackingMode.none,
      // Render mode requires myLocationEnabled=true. Fall back to `normal`
      // (no heading indicator) when the dot itself is off.
      myLocationRenderMode: widget.showUserLocation
          ? MyLocationRenderMode.gps
          : MyLocationRenderMode.normal,
      trackCameraPosition: true,
      compassEnabled: true,
      attributionButtonPosition: AttributionButtonPosition.bottomRight,
      onMapCreated: (MapLibreMapController c) => _controller = c,
      onStyleLoadedCallback: _onStyleLoaded,
      onUserLocationUpdated: widget.onUserLocationUpdated,
      onMapClick: widget.onTap == null
          ? null
          : (Point<double> _, LatLng coord) => widget.onTap!(coord),
    );
  }

  Future<void> _onStyleLoaded() async {
    _styleLoaded = true;
    await _redrawAll();
    await _maybeFitBounds();
  }

  @override
  void didUpdateWidget(covariant LiveMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_styleLoaded || _controller == null) return;
    unawaited(_diff(oldWidget));
    if (widget.fitBounds != oldWidget.fitBounds && widget.fitBounds != null) {
      unawaited(_maybeFitBounds());
    }
  }

  Future<void> _maybeFitBounds() async {
    final ({LatLng a, LatLng b})? b = widget.fitBounds;
    if (b == null || _controller == null) {
      return;
    }
    final double south =
        b.a.latitude < b.b.latitude ? b.a.latitude : b.b.latitude;
    final double north =
        b.a.latitude > b.b.latitude ? b.a.latitude : b.b.latitude;
    final double west =
        b.a.longitude < b.b.longitude ? b.a.longitude : b.b.longitude;
    final double east =
        b.a.longitude > b.b.longitude ? b.a.longitude : b.b.longitude;
    await _controller!.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(south, west),
          northeast: LatLng(north, east),
        ),
        left: 64,
        right: 64,
        top: 96,
        bottom: 240,
      ),
    );
  }

  Future<void> _diff(LiveMap old) async {
    // Markers (circles): remove deleted, add new, update changed.
    final Map<String, LiveMapMarker> nextById = <String, LiveMapMarker>{
      for (final LiveMapMarker m in widget.markers) m.id: m,
    };
    final Map<String, LiveMapMarker> prevById = <String, LiveMapMarker>{
      for (final LiveMapMarker m in old.markers) m.id: m,
    };

    for (final String id in prevById.keys.toList()) {
      if (!nextById.containsKey(id)) {
        final Circle? circle = _circlesById.remove(id);
        if (circle != null) {
          await _controller!.removeCircle(circle);
        }
      }
    }
    for (final MapEntry<String, LiveMapMarker> entry in nextById.entries) {
      final LiveMapMarker m = entry.value;
      final Circle? existing = _circlesById[entry.key];
      if (existing == null) {
        _circlesById[entry.key] =
            await _controller!.addCircle(_circleOptionsFor(m));
      } else {
        // Update geometry / colour in place.
        await _controller!.updateCircle(existing, _circleOptionsFor(m));
      }
    }

    // Polylines: diff by id. Skip lines with <2 points.
    final Map<String, LiveMapPolyline> nextLineById =
        <String, LiveMapPolyline>{
      for (final LiveMapPolyline p in widget.polylines) p.id: p,
    };
    final Map<String, LiveMapPolyline> prevLineById =
        <String, LiveMapPolyline>{
      for (final LiveMapPolyline p in old.polylines) p.id: p,
    };

    for (final String id in prevLineById.keys.toList()) {
      if (!nextLineById.containsKey(id)) {
        final Line? line = _linesById.remove(id);
        if (line != null) {
          await _controller!.removeLine(line);
        }
      }
    }
    for (final MapEntry<String, LiveMapPolyline> entry
        in nextLineById.entries) {
      final LiveMapPolyline p = entry.value;
      final Line? existing = _linesById[entry.key];
      if (p.points.length < 2) {
        if (existing != null) {
          _linesById.remove(entry.key);
          await _controller!.removeLine(existing);
        }
        continue;
      }
      // Skip work entirely when both points and styling match.
      if (existing != null && _polylineUnchanged(prevLineById[entry.key], p)) {
        continue;
      }
      if (existing == null) {
        _linesById[entry.key] = await _controller!.addLine(_lineOptionsFor(p));
      } else {
        await _controller!.updateLine(existing, _lineOptionsFor(p));
      }
    }

    // Polygons: diff by id.
    final Map<String, LiveMapPolygon> nextPolyById =
        <String, LiveMapPolygon>{for (final p in widget.polygons) p.id: p};
    final Map<String, LiveMapPolygon> prevPolyById =
        <String, LiveMapPolygon>{for (final p in old.polygons) p.id: p};

    for (final String id in prevPolyById.keys.toList()) {
      if (!nextPolyById.containsKey(id)) {
        final Fill? fill = _fillsById.remove(id);
        if (fill != null) {
          await _controller!.removeFill(fill);
        }
      }
    }
    for (final MapEntry<String, LiveMapPolygon> entry
        in nextPolyById.entries) {
      final LiveMapPolygon p = entry.value;
      final Fill? existing = _fillsById[entry.key];
      if (existing == null) {
        _fillsById[entry.key] =
            await _controller!.addFill(_fillOptionsFor(p));
      } else {
        await _controller!.updateFill(existing, _fillOptionsFor(p));
      }
    }
  }

  Future<void> _redrawAll() async {
    if (_controller == null) return;
    // First paint: draw everything against current props (treat old as empty).
    await _diff(LiveMap(
      initialCenter: widget.initialCenter,
      initialZoom: widget.initialZoom,
      followUser: widget.followUser,
      showUserLocation: widget.showUserLocation,
    ));
  }

  CircleOptions _circleOptionsFor(LiveMapMarker m) {
    final String color = m.colorOverride ?? _defaultColorFor(m.kind);
    final double radius = m.radius ?? _defaultRadiusFor(m.kind);
    return CircleOptions(
      geometry: m.position,
      circleColor: color,
      circleRadius: radius,
      circleStrokeColor: '#FFFFFF',
      circleStrokeWidth: 2,
      circleOpacity: 0.95,
    );
  }

  FillOptions _fillOptionsFor(LiveMapPolygon p) {
    return FillOptions(
      geometry: p.rings,
      fillColor: p.fillColor,
      fillOpacity: p.fillOpacity,
      fillOutlineColor: p.outlineColor,
    );
  }

  LineOptions _lineOptionsFor(LiveMapPolyline p) {
    return LineOptions(
      geometry: p.points,
      lineColor: p.color,
      lineWidth: p.width,
      lineOpacity: p.opacity,
      lineJoin: 'round',
    );
  }

  static bool _polylineUnchanged(LiveMapPolyline? a, LiveMapPolyline b) {
    if (a == null) return false;
    if (a.color != b.color) return false;
    if (a.width != b.width) return false;
    if (a.opacity != b.opacity) return false;
    return _pointListsEqual(a.points, b.points);
  }

  static String _defaultColorFor(LiveMapMarkerKind kind) {
    switch (kind) {
      case LiveMapMarkerKind.driver:
        return '#34D399'; // accent green
      case LiveMapMarkerKind.pickup:
        return '#3B82F6'; // blue
      case LiveMapMarkerKind.dropoff:
        return '#F87171'; // red
      case LiveMapMarkerKind.request:
        return '#F59E0B'; // amber
    }
  }

  static double _defaultRadiusFor(LiveMapMarkerKind kind) {
    switch (kind) {
      case LiveMapMarkerKind.driver:
        return 8;
      case LiveMapMarkerKind.pickup:
      case LiveMapMarkerKind.dropoff:
        return 10;
      case LiveMapMarkerKind.request:
        return 9;
    }
  }

  static bool _pointListsEqual(List<LatLng>? a, List<LatLng>? b) {
    if (identical(a, b)) return true;
    if (a == null || b == null) return false;
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

}
