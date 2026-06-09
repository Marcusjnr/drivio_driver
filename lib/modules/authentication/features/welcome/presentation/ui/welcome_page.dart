import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:drivio_driver/modules/commons/all.dart';

/// SCR-002 — Welcome (signed out).
///
/// Light ivory canvas. Top-left wordmark. Hero zone occupies ~60% of
/// the screen — a brand-pure Coastal Pulse composition (coral sky,
/// butter radar halo, charcoal-teal city silhouette) standing in until
/// commissioned photography from the §8.3 photographer roster lands.
/// Below the hero: eyebrow → Marcellus headline → Albert Sans body →
/// coral primary CTA + ghost secondary.
class WelcomePage extends ConsumerWidget {
  const WelcomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ScreenScaffold(
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              // Top-left wordmark — Marcellus "Drivio" + coral dot at
              // 22pt per SCR-002 mockup.
              const BrandMark(size: 22),
              const SizedBox(height: 12),

              // Hero zone — 60% of remaining vertical space.
              const Expanded(
                flex: 60,
                child: _HeroIllustration(),
              ),

              const SizedBox(height: 22),

              // Eyebrow + headline + body. Below the hero, with
              // generous whitespace per brand §3.3 premium-warm.
              Expanded(
                flex: 40,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'DRIVE WITH DRIVIO',
                      style: AppTextStyles.eyebrow.copyWith(
                        color: context.textDim,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Set your price.\nKeep what you earn.',
                      style: AppTextStyles.displayLg.copyWith(
                        color: context.text,
                        fontSize: 36,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      "Drivio doesn't take a per-trip cut. You decide "
                      'what each ride is worth.',
                      style: AppTextStyles.bodySm.copyWith(
                        color: context.textDim,
                        height: 1.55,
                      ),
                    ),
                    const Spacer(),
                    DrivioButton(
                      label: 'Get started',
                      onPressed: () =>
                          AppNavigation.push(AppRoutes.signUp),
                    ),
                    const SizedBox(height: 6),
                    SizedBox(
                      width: double.infinity,
                      height: 44,
                      child: TextButton(
                        onPressed: () =>
                            AppNavigation.push(AppRoutes.signIn),
                        style: TextButton.styleFrom(
                          foregroundColor: context.text,
                          padding:
                              const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: Text(
                          'I already have an account',
                          style: AppTextStyles.bodySm.copyWith(
                            color: context.text,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// **Placeholder.** Hero illustration painted in pure Coastal Pulse
/// tokens — coral dawn sky, butter radar halo (echoing the splash
/// pulse), charcoal-teal city silhouette, teal accent building.
///
/// Per brand spec §8 the hero on this surface should eventually be
/// commissioned photography from the §8.3 photographer roster (Lakin
/// Ogunbanwo / Stephen Tayo / Aida Muluneh et al). Until then this
/// painted composition stands in; it uses only palette tokens, no raw
/// hex, no stock photos that might violate §8.4 sourcing rules.
class _HeroIllustration extends StatelessWidget {
  const _HeroIllustration();

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: CustomPaint(
        painter: _HeroPainter(),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _HeroPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;
    final Rect frame = Rect.fromLTWH(0, 0, w, h);

    // ── Dawn sky — coral fading to charcoal-teal at the horizon ─────
    // Mid-stop is derived (not a new token): Color.lerp picks a tint
    // exactly 55% between coral and charcoal-teal so the gradient
    // breathes a beat before settling into the dark horizon — no raw
    // hex, no new palette token.
    final Color midSky =
        Color.lerp(AppColors.coral, AppColors.charcoalTeal, 0.55)!;
    final Paint sky = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: <Color>[AppColors.coral, midSky, AppColors.charcoalTeal],
        stops: const <double>[0.0, 0.55, 1.0],
      ).createShader(frame);
    canvas.drawRect(frame, sky);

    // ── Butter radar halo — three concentric rings, top-right ───────
    // Echoes the splash pulse. Sparing use (§4.4 butter rule) — this
    // is the one butter moment on the page.
    final Offset haloCenter = Offset(w * 0.72, h * 0.32);
    for (int i = 1; i <= 3; i++) {
      final Paint ring = Paint()
        ..color = AppColors.butter
            .withValues(alpha: 0.55 - 0.12 * (i - 1).toDouble())
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;
      canvas.drawCircle(haloCenter, w * 0.10 * i, ring);
    }

    // ── City silhouette — charcoal-teal at the bottom ───────────────
    final Paint city = Paint()..color = AppColors.charcoalTeal;
    // (x_frac, width_frac, height_frac) per building.
    final List<List<double>> buildings = <List<double>>[
      <double>[0.02, 0.12, 0.18],
      <double>[0.16, 0.10, 0.28],
      <double>[0.28, 0.13, 0.22],
      <double>[0.62, 0.14, 0.25],
      <double>[0.78, 0.10, 0.32],
      <double>[0.90, 0.10, 0.20],
    ];
    for (final List<double> b in buildings) {
      final double x = w * b[0];
      final double bw = w * b[1];
      final double bh = h * b[2];
      canvas.drawRect(Rect.fromLTWH(x, h - bh, bw, bh), city);
    }

    // ── Teal accent — a single taller building, centered foreground ─
    // The "calm sibling to coral" — the focal point at street level.
    final Paint tealAccent = Paint()..color = AppColors.teal;
    canvas.drawRect(
      Rect.fromLTWH(w * 0.42, h * 0.42, w * 0.18, h * 0.58),
      tealAccent,
    );
    // Triangular roof
    final Path roof = Path()
      ..moveTo(w * 0.42, h * 0.42)
      ..lineTo(w * 0.51, h * 0.30)
      ..lineTo(w * 0.60, h * 0.42)
      ..close();
    canvas.drawPath(roof, tealAccent);
  }

  @override
  bool shouldRepaint(covariant _HeroPainter oldDelegate) => false;
}
