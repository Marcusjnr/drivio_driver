import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';

import 'package:drivio_driver/modules/commons/logging/app_logger.dart';

/// Android-only "display over other apps" bubble for background ride alerts.
///
/// Shown by [startRideRequestAlert] when a `ride_request` push lands while
/// the app is backgrounded/killed (the presence foreground service keeps the
/// process alive). Renders in a separate Flutter engine via
/// `flutter_overlay_window`, so this module is self-contained: no theme
/// context, no locator — brand colours are inlined and trip details arrive
/// through [FlutterOverlayWindow.shareData].
///
/// UX: a compact pulsing Drivio bubble; tapping expands it into a mini-card
/// (pickup → drop-off · distance) with "View trip" (brings the app to the
/// foreground via [FlutterForegroundTask.launchApp]) and a dismiss ✕.

// Brand (Coastal Pulse) — inlined; the overlay engine has no app theme.
const Color _kCharcoal = Color(0xFF122624);
const Color _kIvory = Color(0xFFF6F1E7);
const Color _kCoral = Color(0xFFEE6F4A);

const double _kBubbleSize = 76;
const double _kCardWidth = 300;
const double _kCardHeight = 200;

/// Show the overlay bubble for a new request (no-op off-Android or without
/// the "display over other apps" permission).
Future<void> showRideRequestOverlay(Map<String, dynamic> data) async {
  if (!Platform.isAndroid) return;
  try {
    if (!await FlutterOverlayWindow.isPermissionGranted()) return;
    if (await FlutterOverlayWindow.isActive()) {
      await FlutterOverlayWindow.closeOverlay();
    }
    await FlutterOverlayWindow.showOverlay(
      height: (_kBubbleSize * 2).toInt(),
      width: (_kBubbleSize * 2).toInt(),
      alignment: OverlayAlignment.centerRight,
      flag: OverlayFlag.defaultFlag,
      enableDrag: true,
      overlayTitle: 'Drivio',
      overlayContent: 'New trip request',
    );
    // Give the engine a beat to boot before pushing the trip details.
    await Future<void>.delayed(const Duration(milliseconds: 400));
    await FlutterOverlayWindow.shareData(<String, dynamic>{
      'pickup': data['pickup'],
      'dropoff': data['dropoff'],
      'distance_km': data['distance_km'],
      'ride_request_id': data['ride_request_id'],
    });
  } catch (e, st) {
    // Overlay is a bonus layer — sound + notification already fired.
    AppLogger.w('ride overlay show failed', error: e, stackTrace: st);
  }
}

/// Tear the bubble down (driver acted, request expired, app resumed).
Future<void> closeRideRequestOverlay() async {
  if (!Platform.isAndroid) return;
  try {
    if (await FlutterOverlayWindow.isActive()) {
      await FlutterOverlayWindow.closeOverlay();
    }
  } catch (_) {}
}

/// Ask for the "display over other apps" permission (opens system settings
/// the first time). Call from a foreground UI moment — we hook the driver's
/// go-online flow. Safe to call repeatedly.
Future<void> ensureOverlayPermission() async {
  if (!Platform.isAndroid) return;
  try {
    if (await FlutterOverlayWindow.isPermissionGranted()) return;
    await FlutterOverlayWindow.requestPermission();
  } catch (e) {
    AppLogger.w('overlay permission request failed', error: e);
  }
}

// ────────────────────────────────────────────────────────────────────
// Overlay UI (separate engine — entry point wired in main.dart)
// ────────────────────────────────────────────────────────────────────

class RideRequestOverlayApp extends StatelessWidget {
  const RideRequestOverlayApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: _OverlayRoot(),
    );
  }
}

class _OverlayRoot extends StatefulWidget {
  const _OverlayRoot();

  @override
  State<_OverlayRoot> createState() => _OverlayRootState();
}

class _OverlayRootState extends State<_OverlayRoot>
    with SingleTickerProviderStateMixin {
  bool _expanded = false;
  String _pickup = 'Nearby pickup';
  String _dropoff = 'Destination';
  String? _distanceKm;
  StreamSubscription<dynamic>? _dataSub;

  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  @override
  void initState() {
    super.initState();
    _dataSub = FlutterOverlayWindow.overlayListener.listen((dynamic event) {
      if (event is! Map) return;
      setState(() {
        _pickup = (event['pickup'] as String?) ?? _pickup;
        _dropoff = (event['dropoff'] as String?) ?? _dropoff;
        _distanceKm = event['distance_km'] as String?;
      });
    });
  }

  @override
  void dispose() {
    _pulse.dispose();
    _dataSub?.cancel();
    super.dispose();
  }

  Future<void> _toggle() async {
    if (_expanded) {
      await FlutterOverlayWindow.resizeOverlay(
        (_kBubbleSize * 2).toInt(),
        (_kBubbleSize * 2).toInt(),
        false,
      );
    } else {
      await FlutterOverlayWindow.resizeOverlay(
        _kCardWidth.toInt(),
        _kCardHeight.toInt(),
        false,
      );
    }
    if (mounted) setState(() => _expanded = !_expanded);
  }

  Future<void> _openApp() async {
    try {
      FlutterForegroundTask.launchApp('/');
    } catch (_) {}
    await FlutterOverlayWindow.closeOverlay();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Center(
        child: _expanded ? _card() : _bubble(),
      ),
    );
  }

  Widget _bubble() {
    return GestureDetector(
      onTap: _toggle,
      child: AnimatedBuilder(
        animation: _pulse,
        builder: (BuildContext _, Widget? child) {
          final double t =
              Curves.easeInOut.transform(_pulse.value);
          return Container(
            width: _kBubbleSize,
            height: _kBubbleSize,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _kCharcoal,
              border: Border.all(
                color: _kCoral.withValues(alpha: 0.35 + t * 0.65),
                width: 2 + t * 2,
              ),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: child,
          );
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(Icons.local_taxi_rounded, color: _kCoral, size: 26),
            const SizedBox(height: 1),
            Text(
              'TRIP',
              style: TextStyle(
                color: _kIvory.withValues(alpha: 0.9),
                fontSize: 8.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _card() {
    return Container(
      width: _kCardWidth - 16,
      padding: const EdgeInsets.fromLTRB(16, 12, 10, 12),
      decoration: BoxDecoration(
        color: _kCharcoal,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _kCoral.withValues(alpha: 0.5)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(Icons.local_taxi_rounded, color: _kCoral, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _distanceKm != null
                      ? 'NEW TRIP · $_distanceKm KM'
                      : 'NEW TRIP REQUEST',
                  style: const TextStyle(
                    color: _kCoral,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.6,
                  ),
                ),
              ),
              GestureDetector(
                onTap: _toggle,
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(
                    Icons.close_rounded,
                    size: 18,
                    color: _kIvory.withValues(alpha: 0.6),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _routeLine(Icons.circle, _pickup),
          const SizedBox(height: 6),
          _routeLine(Icons.square_rounded, _dropoff),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _openApp,
              style: FilledButton.styleFrom(
                backgroundColor: _kCoral,
                foregroundColor: _kCharcoal,
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'View trip',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _routeLine(IconData icon, String text) {
    return Row(
      children: <Widget>[
        Icon(icon, size: 9, color: _kCoral),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: _kIvory.withValues(alpha: 0.92),
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
