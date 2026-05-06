import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Concentric radar pulse rendered behind the wordmark on the splash.
///
/// Three rings expand from a centred point on a 1.6s loop, each one
/// staggered 0.4s after the previous so there's always at least one
/// ring mid-flight. The rings fade out as they grow — a softly
/// breathing focal point that doubles as a hint at "we need your
/// location".
///
/// Pure paint — no expensive widget tree per frame. Uses one
/// AnimationController + one CustomPaint for the entire effect.
class RadarPulse extends StatefulWidget {
  const RadarPulse({
    super.key,
    required this.color,
    this.size = 280,
    this.maxRadius = 140,
    this.ringCount = 3,
  });

  /// Base colour of the rings; alpha decreases with radius.
  final Color color;

  /// Outer canvas size (width = height). Rings will not exceed
  /// [maxRadius] from the centre.
  final double size;
  final double maxRadius;
  final int ringCount;

  @override
  State<RadarPulse> createState() => _RadarPulseState();
}

class _RadarPulseState extends State<RadarPulse>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..repeat();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: widget.size,
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (BuildContext _, __) {
          return CustomPaint(
            painter: _RadarPainter(
              t: _ctrl.value,
              color: widget.color,
              maxRadius: widget.maxRadius,
              ringCount: widget.ringCount,
            ),
          );
        },
      ),
    );
  }
}

class _RadarPainter extends CustomPainter {
  _RadarPainter({
    required this.t,
    required this.color,
    required this.maxRadius,
    required this.ringCount,
  });

  /// Animation phase 0..1 — read live from the controller.
  final double t;
  final Color color;
  final double maxRadius;
  final int ringCount;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = Offset(size.width / 2, size.height / 2);

    // Stationary glow at the centre — anchors the eye when the rings
    // are mid-fade. Soft radial gradient.
    final Paint glow = Paint()
      ..shader = RadialGradient(
        colors: <Color>[
          color.withValues(alpha: 0.18),
          color.withValues(alpha: 0),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: maxRadius));
    canvas.drawCircle(center, maxRadius, glow);

    // Each ring is offset in time so the loop never has a "dead"
    // moment where all rings are at the same phase.
    final double stagger = 1.0 / ringCount;
    for (int i = 0; i < ringCount; i++) {
      final double phase = (t + i * stagger) % 1.0;
      // Ease-out on radius; ease-in on alpha so they fade into the
      // background as they grow rather than popping out abruptly.
      final double radius = maxRadius * _easeOut(phase);
      final double alpha = (1.0 - phase) * 0.35;
      final Paint stroke = Paint()
        ..color = color.withValues(alpha: alpha)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4;
      canvas.drawCircle(center, radius, stroke);
    }

    // Solid focal dot — small, deliberate, sits dead-centre.
    final Paint dot = Paint()..color = color;
    canvas.drawCircle(center, 4.5, dot);

    // Subtle outer glow on the dot for extra presence.
    final Paint dotGlow = Paint()
      ..color = color.withValues(alpha: 0.45)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawCircle(center, 6, dotGlow);
  }

  /// Standard quadratic ease-out — fast at the start, slow at the
  /// end. Makes the rings feel like they have momentum.
  double _easeOut(double x) => 1 - math.pow(1 - x, 2).toDouble();

  @override
  bool shouldRepaint(covariant _RadarPainter old) =>
      old.t != t || old.color != color;
}
