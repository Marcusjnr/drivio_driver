import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:drivio_driver/modules/commons/all.dart';
import 'package:drivio_driver/modules/splash/presentation/logic/controller/splash_controller.dart';
import 'package:drivio_driver/modules/splash/presentation/ui/widgets/radar_pulse.dart';

/// First page rendered on cold start. Its one job is brand presence —
/// radar pulse + wordmark — so the launch doesn't open into a generic
/// spinner. Location permission is intentionally NOT asked here; it's
/// requested in context the first time the driver taps "Go online".
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
      final BootstrapController bc = ref.read(
        bootstrapControllerProvider.notifier,
      );
      Navigator.of(
        context,
      ).pushReplacementNamed(bc.initialRoute, arguments: bc.initialArguments);
    });
  }

  @override
  Widget build(BuildContext context) {
    final SplashState splash = ref.watch(splashControllerProvider);
    final BootstrapState boot = ref.watch(bootstrapControllerProvider);

    _maybeHandOff(boot, splash);

    return Scaffold(
      backgroundColor: AppColors.appBackdropDark,
      body: Stack(
        children: <Widget>[
          // Atmospheric backdrop — soft top-down vignette so the centre
          // breathes a touch lighter than the edges.
          const Positioned.fill(child: _BackdropGradient()),
          // Brand block — wordmark + tagline + radar.
          const Positioned.fill(child: _BrandBlock()),
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
          colors: <Color>[AppColors.bgDark, AppColors.appBackdropDark],
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
  late final Animation<Offset> _wordSlide =
      Tween<Offset>(begin: const Offset(0, 0.35), end: Offset.zero).animate(
        CurvedAnimation(
          parent: _ctrl,
          curve: const Interval(0.0, 0.65, curve: Curves.easeOutCubic),
        ),
      );
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
