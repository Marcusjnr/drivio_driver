import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:drivio_driver/modules/commons/theme/context_theme.dart';

class DrivioMap extends ConsumerWidget {
  const DrivioMap({
    super.key,
    this.demand = false,
    this.routePoints,
    this.driverPosition,
    this.pickupPosition,
    this.dropoffPosition,
  });

  final bool demand;
  final List<Offset>? routePoints;
  final Offset? driverPosition;
  final Offset? pickupPosition;
  final Offset? dropoffPosition;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return CustomPaint(
      painter: _MapPainter(
        bg: context.mapBg,
        road: context.mapRoad,
        roadMajor: context.mapRoadMajor,
        water: context.mapWater,
        park: context.mapPark,
        accent: context.accent,
        red: context.red,
        amber: context.amber,
        text: context.text,
        demand: demand,
        routePoints: routePoints,
        driver: driverPosition,
        pickup: pickupPosition,
        dropoff: dropoffPosition,
      ),
      child: const SizedBox.expand(),
    );
  }
}

class _MapPainter extends CustomPainter {
  _MapPainter({
    required this.bg,
    required this.road,
    required this.roadMajor,
    required this.water,
    required this.park,
    required this.accent,
    required this.red,
    required this.amber,
    required this.text,
    required this.demand,
    this.routePoints,
    this.driver,
    this.pickup,
    this.dropoff,
  });

  final Color bg;
  final Color road;
  final Color roadMajor;
  final Color water;
  final Color park;
  final Color accent;
  final Color red;
  final Color amber;
  final Color text;
  final bool demand;
  final List<Offset>? routePoints;
  final Offset? driver;
  final Offset? pickup;
  final Offset? dropoff;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint bgP = Paint()..color = bg;
    canvas.drawRect(Offset.zero & size, bgP);

    final Paint waterP = Paint()..color = water;
    final Path waterPath = Path()
      ..moveTo(size.width * 0.6, size.height * 0.65)
      ..quadraticBezierTo(
        size.width * 0.85,
        size.height * 0.45,
        size.width * 1.1,
        size.height * 0.55,
      )
      ..lineTo(size.width * 1.1, size.height * 1.1)
      ..lineTo(size.width * 0.4, size.height * 1.1)
      ..close();
    canvas.drawPath(waterPath, waterP);

    final Paint parkP = Paint()..color = park;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          size.width * 0.06,
          size.height * 0.55,
          size.width * 0.28,
          size.height * 0.18,
        ),
        const Radius.circular(20),
      ),
      parkP,
    );

    final Paint majorP = Paint()
      ..color = roadMajor
      ..strokeWidth = 14
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(
      Offset(0, size.height * 0.32),
      Offset(size.width, size.height * 0.36),
      majorP,
    );
    canvas.drawLine(
      Offset(size.width * 0.45, 0),
      Offset(size.width * 0.55, size.height),
      majorP,
    );

    final Paint roadP = Paint()
      ..color = road
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;

    final List<List<Offset>> minor = <List<Offset>>[
      <Offset>[Offset(0, size.height * 0.2), Offset(size.width, size.height * 0.18)],
      <Offset>[Offset(0, size.height * 0.78), Offset(size.width, size.height * 0.74)],
      <Offset>[Offset(size.width * 0.15, 0), Offset(size.width * 0.18, size.height)],
      <Offset>[Offset(size.width * 0.78, 0), Offset(size.width * 0.82, size.height)],
    ];
    for (final List<Offset> seg in minor) {
      canvas.drawLine(seg.first, seg.last, roadP);
    }

    if (demand) {
      _paintDemand(canvas, size);
    }

    if (routePoints != null && routePoints!.length >= 2) {
      final Path path = Path()..moveTo(routePoints!.first.dx, routePoints!.first.dy);
      for (int i = 1; i < routePoints!.length; i++) {
        path.lineTo(routePoints![i].dx, routePoints![i].dy);
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = accent
          ..strokeWidth = 5
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
    }

    if (pickup != null) {
      _paintPin(canvas, pickup!, accent);
    }
    if (dropoff != null) {
      _paintPin(canvas, dropoff!, red);
    }
    if (driver != null) {
      _paintDriver(canvas, driver!);
    }
  }

  void _paintDemand(Canvas canvas, Size size) {
    final List<List<double>> hotspots = <List<double>>[
      <double>[0.3, 0.4, 80],
      <double>[0.7, 0.55, 100],
      <double>[0.5, 0.75, 60],
      <double>[0.2, 0.65, 50],
    ];
    for (final List<double> h in hotspots) {
      final Offset center = Offset(size.width * h[0], size.height * h[1]);
      final double r = h[2];
      final Paint p = Paint()
        ..shader = RadialGradient(
          colors: <Color>[
            red.withValues(alpha: 0.45),
            red.withValues(alpha: 0.0),
          ],
        ).createShader(Rect.fromCircle(center: center, radius: r));
      canvas.drawCircle(center, r, p);
    }
  }

  void _paintPin(Canvas canvas, Offset center, Color color) {
    final Paint glow = Paint()
      ..color = color.withValues(alpha: 0.25)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawCircle(center, 14, glow);
    canvas.drawCircle(center, 9, Paint()..color = color);
    canvas.drawCircle(center, 4, Paint()..color = Colors.white);
  }

  void _paintDriver(Canvas canvas, Offset center) {
    final Paint outer = Paint()
      ..color = accent.withValues(alpha: 0.3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawCircle(center, 18, outer);
    canvas.drawCircle(center, 10, Paint()..color = accent);

    final Path arrow = Path()
      ..moveTo(center.dx, center.dy - 5)
      ..lineTo(center.dx - 4, center.dy + 4)
      ..lineTo(center.dx + 4, center.dy + 4)
      ..close();
    canvas.drawPath(arrow, Paint()..color = const Color(0xFF0A2418));

    final Paint ringP = Paint()
      ..color = accent.withValues(alpha: 0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawCircle(center, 22 + math.sin(0) * 2, ringP);
  }

  @override
  bool shouldRepaint(_MapPainter old) =>
      old.bg != bg ||
      old.demand != demand ||
      old.driver != driver ||
      old.pickup != pickup ||
      old.dropoff != dropoff;
}
