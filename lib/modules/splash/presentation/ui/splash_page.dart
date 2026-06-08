import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:drivio_driver/modules/commons/all.dart';
import 'package:drivio_driver/modules/commons/location/location_permission_service.dart';
import 'package:drivio_driver/modules/splash/presentation/logic/controller/splash_controller.dart';
import 'package:drivio_driver/modules/splash/presentation/ui/widgets/radar_pulse.dart';

/// First page rendered on cold start. Two jobs:
///   1. Brand presence — radar pulse + wordmark — so the launch
///      doesn't open into a generic spinner.
///   2. Up-front location-permission ask. Drivers who say yes never
///      see the prompt again on the home page; those who say no get
///      re-prompted at the moment they tap "Go online".
///
/// Once both bootstrap has resolved AND the splash phase is
/// `proceeding`, the page replaces itself with whatever destination
/// bootstrap picked (welcome / sign-up / home).
class SplashPage extends ConsumerStatefulWidget {
  const SplashPage({super.key});

  @override
  ConsumerState<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends ConsumerState<SplashPage> {
  bool _handedOff = false;

  @override
  void initState() {
    super.initState();
    // Splash always renders against the dark backdrop regardless of
    // device theme — gives the brand a consistent first impression.
    SystemChrome.setSystemUIOverlayStyle(AppTheme.darkSystemOverlay);
  }

  void _maybeHandOff(BootstrapState boot, SplashState splash) {
    if (_handedOff) return;
    if (boot.isLoading) return;
    if (splash.phase != SplashPhase.proceeding) return;
    _handedOff = true;
    // Defer to next frame — we're in a build callback.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final BootstrapController bc =
          ref.read(bootstrapControllerProvider.notifier);
      Navigator.of(context).pushReplacementNamed(
        bc.initialRoute,
        arguments: bc.initialArguments,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final SplashState splash = ref.watch(splashControllerProvider);
    final BootstrapState boot = ref.watch(bootstrapControllerProvider);
    final SplashController c = ref.read(splashControllerProvider.notifier);

    _maybeHandOff(boot, splash);

    final bool showCard = splash.phase == SplashPhase.askingPermission;

    return Scaffold(
      backgroundColor: AppColors.appBackdropDark,
      body: Stack(
        children: <Widget>[
          // Atmospheric backdrop — soft top-down vignette so the centre
          // breathes a touch lighter than the edges.
          const Positioned.fill(child: _BackdropGradient()),
          // Brand block — wordmark + tagline + radar.
          const Positioned.fill(child: _BrandBlock()),
          // Permission card slides up from the bottom edge once the
          // brand reveal completes.
          AnimatedPositioned(
            duration: AppDurations.slow,
            curve: Curves.easeOutQuart,
            left: 0,
            right: 0,
            bottom: showCard
                ? 0
                : -480,
            child: AnimatedOpacity(
              duration: AppDurations.base,
              opacity: showCard ? 1 : 0,
              child: _PermissionCard(
                permission: splash.permission,
                isRequesting: splash.isRequesting,
                onAllow: c.requestPermission,
                onSkip: c.skip,
                onOpenSettings: c.openSettingsAndProceed,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Backdrop ───────────────────────────────────────────────────────────

class _BackdropGradient extends StatelessWidget {
  const _BackdropGradient();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: const Alignment(0, -0.35),
          radius: 1.1,
          colors: <Color>[
            AppColors.bgDark,
            AppColors.appBackdropDark,
          ],
          stops: const <double>[0, 1],
        ),
      ),
    );
  }
}

// ── Brand block ────────────────────────────────────────────────────────

class _BrandBlock extends StatefulWidget {
  const _BrandBlock();

  @override
  State<_BrandBlock> createState() => _BrandBlockState();
}

class _BrandBlockState extends State<_BrandBlock>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  )..forward();

  late final Animation<double> _wordOpacity = CurvedAnimation(
    parent: _ctrl,
    curve: const Interval(0.0, 0.65, curve: Curves.easeOut),
  );
  late final Animation<Offset> _wordSlide = Tween<Offset>(
    begin: const Offset(0, 0.35),
    end: Offset.zero,
  ).animate(CurvedAnimation(
    parent: _ctrl,
    curve: const Interval(0.0, 0.65, curve: Curves.easeOutCubic),
  ));
  late final Animation<double> _eyebrowOpacity = CurvedAnimation(
    parent: _ctrl,
    curve: const Interval(0.45, 1.0, curve: Curves.easeOut),
  );

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 80),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          // Radar pulse anchors the wordmark — sits behind it via Stack.
          Stack(
            alignment: Alignment.center,
            children: <Widget>[
              const RadarPulse(
                color: AppColors.accentDark,
                size: 320,
                maxRadius: 150,
              ),
              FadeTransition(
                opacity: _wordOpacity,
                child: SlideTransition(
                  position: _wordSlide,
                  child: const _Wordmark(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          FadeTransition(
            opacity: _eyebrowOpacity,
            child: SlideTransition(
              position: _wordSlide,
              child: const _Tagline(),
            ),
          ),
        ],
      ),
    );
  }
}

/// The big centred wordmark per SCR-001: "Drivio" in Marcellus, ivory
/// on the charcoal-teal background, with a coral dot at ~96pt. Big
/// enough to anchor the screen and read across the radar rings behind it.
class _Wordmark extends StatelessWidget {
  const _Wordmark();

  @override
  Widget build(BuildContext context) {
    // Splash uses the brand-spec maximum (~96pt). BrandMark handles the
    // Marcellus letters + coral dot composition; on the dark splash, it
    // reads against the radar rings underneath without competing.
    return const BrandMark(size: 96);
  }
}

/// Two-line italic Marcellus tagline overlaid below the wordmark.
/// "Movement," in ivory, "on your terms." in coral — per SCR-001.
/// Read as a single thought; never split with punctuation tweaks.
class _Tagline extends StatelessWidget {
  const _Tagline();

  @override
  Widget build(BuildContext context) {
    final TextStyle line = AppTextStyles.h1.copyWith(
      fontSize: 22,
      fontStyle: FontStyle.italic,
      height: 1.15,
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          'Movement,',
          textAlign: TextAlign.center,
          style: line.copyWith(color: AppColors.ivory),
        ),
        const SizedBox(height: 2),
        Text(
          'on your terms.',
          textAlign: TextAlign.center,
          style: line.copyWith(color: AppColors.coral),
        ),
      ],
    );
  }
}

// ── Permission card ────────────────────────────────────────────────────

/// Bottom-sheet-style card that slides up after the brand reveal.
/// Adapts its copy and CTA to the current [LocationPermState] so a
/// "permanently denied" driver gets an Open Settings button instead
/// of a useless Allow button.
class _PermissionCard extends StatelessWidget {
  const _PermissionCard({
    required this.permission,
    required this.isRequesting,
    required this.onAllow,
    required this.onSkip,
    required this.onOpenSettings,
  });

  final LocationPermState permission;
  final bool isRequesting;
  final VoidCallback onAllow;
  final VoidCallback onSkip;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final (String title, String body, String primary, VoidCallback onPrimary) =
        _copy();

    // Per SCR-001 mockup the permission card is ivory-light *regardless*
    // of the splash background — it reads as the system-sheet moment, the
    // one part of the splash where the OS feels close. Big rounded top
    // corners, no bottom curve so it visually anchors to the screen edge.
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
      decoration: const BoxDecoration(
        color: AppColors.ivory,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(28),
          topRight: Radius.circular(28),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          // Centered coral-tinted disc with a Drivio pin glyph inside —
          // a quiet signal of what this card asks for.
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.coral.withValues(alpha: 0.14),
            ),
            alignment: Alignment.center,
            child: const _LocationGlyph(color: AppColors.coral),
          ),
          const SizedBox(height: 18),
          Text(
            title,
            textAlign: TextAlign.center,
            style: AppTextStyles.screenTitleSm.copyWith(
              color: AppColors.textLight,
              fontSize: 22,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            body,
            textAlign: TextAlign.center,
            style: AppTextStyles.bodySm.copyWith(
              color: AppColors.textDimLight,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 20),
          DrivioButton(
            label: isRequesting ? 'Asking…' : primary,
            disabled: isRequesting,
            onPressed: isRequesting ? null : onPrimary,
          ),
          const SizedBox(height: 6),
          // "Not now" is a text-only ghost per the mockup — no border,
          // no fill, charcoal-teal dim.
          SizedBox(
            height: 44,
            child: TextButton(
              onPressed: isRequesting ? null : onSkip,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.textLight,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: Text(
                'Not now',
                style: AppTextStyles.bodySm.copyWith(
                  color: AppColors.textLight,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Tuple of (title, body, primary CTA label, primary CTA callback)
  /// keyed off the current permission state.
  (String, String, String, VoidCallback) _copy() {
    switch (permission) {
      case LocationPermState.permanentlyDenied:
        return (
          'Location is blocked',
          "We can't show you nearby ride requests without your location. Open Settings → Permissions and turn on Location for Drivio.",
          'Open settings',
          onOpenSettings,
        );
      case LocationPermState.serviceDisabled:
        return (
          'Turn on location services',
          "Your phone's location is switched off. Turn it on so we can match you with passengers nearby.",
          'Open location settings',
          onOpenSettings,
        );
      case LocationPermState.denied:
      case LocationPermState.unknown:
      case LocationPermState.granted:
        return (
          'Drivio uses your location',
          "We need your live position to send you ride requests near you and to share your ETA with passengers during a trip.",
          'Allow location',
          onAllow,
        );
    }
  }
}

/// Hand-drawn location pin — a circle with a tail. Avoids the stock
/// material pin which feels generic on a brand surface.
class _LocationGlyph extends StatelessWidget {
  const _LocationGlyph({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 22,
      child: CustomPaint(painter: _LocationGlyphPainter(color)),
    );
  }
}

class _LocationGlyphPainter extends CustomPainter {
  _LocationGlyphPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final double w = size.width;
    final double h = size.height;
    final Offset top = Offset(w / 2, h * 0.12);
    final Offset bottom = Offset(w / 2, h * 0.95);
    final Offset leftCurve = Offset(w * 0.12, h * 0.42);
    final Offset rightCurve = Offset(w * 0.88, h * 0.42);

    final Path pin = Path()
      ..moveTo(bottom.dx, bottom.dy)
      ..quadraticBezierTo(leftCurve.dx, leftCurve.dy, top.dx, top.dy)
      ..quadraticBezierTo(rightCurve.dx, rightCurve.dy, bottom.dx, bottom.dy);
    canvas.drawPath(pin, stroke);

    // Inner dot — same colour so it reads as a unified mark.
    final Paint dot = Paint()..color = color;
    canvas.drawCircle(Offset(w / 2, h * 0.4), 2.2, dot);
  }

  @override
  bool shouldRepaint(covariant _LocationGlyphPainter old) =>
      old.color != color;
}
