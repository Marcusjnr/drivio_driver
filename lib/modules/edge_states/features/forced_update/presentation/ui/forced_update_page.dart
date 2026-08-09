import 'dart:io' show Platform;
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:drivio_driver/modules/commons/all.dart';
import 'package:drivio_driver/modules/commons/utils/store_launcher.dart';
import 'package:drivio_driver/modules/splash/presentation/ui/widgets/radar_pulse.dart';

/// Blocking screen shown when the installed build is below the supported
/// floor (or ops flipped the force_update kill switch). There is no way
/// past it: back is swallowed, and the only action opens the store.
/// Bootstrap routes here INSTEAD of the normal destination, so nothing
/// behind it has loaded.
///
/// Visually it borrows the splash's language — dark radial backdrop and
/// the coral radar pulse — so being stopped here still feels like Drivio,
/// not an error page. One orchestrated entrance (icon → title → body →
/// CTA), then the only thing left moving is the radar and a slow float
/// on the hero.
class ForcedUpdatePage extends ConsumerStatefulWidget {
  const ForcedUpdatePage({super.key});

  @override
  ConsumerState<ForcedUpdatePage> createState() => _ForcedUpdatePageState();
}

class _ForcedUpdatePageState extends ConsumerState<ForcedUpdatePage>
    with TickerProviderStateMixin {
  /// One-shot entrance. Children pick staggered intervals off this.
  late final AnimationController _enter = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..forward();

  /// Slow ±4px float on the hero tile. Subtle on purpose: it keeps the
  /// screen alive without competing with the radar.
  late final AnimationController _float = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  )..repeat();

  @override
  void dispose() {
    _enter.dispose();
    _float.dispose();
    super.dispose();
  }

  Animation<double> _fadeAt(double start) => CurvedAnimation(
        parent: _enter,
        curve: Interval(start, math.min(start + 0.45, 1), curve: Curves.easeOut),
      );

  Animation<Offset> _riseAt(double start) => Tween<Offset>(
        begin: const Offset(0, 0.18),
        end: Offset.zero,
      ).animate(CurvedAnimation(
        parent: _enter,
        curve: Interval(start, math.min(start + 0.45, 1),
            curve: Curves.easeOutCubic),
      ));

  Widget _staggered(double start, Widget child) => FadeTransition(
        opacity: _fadeAt(start),
        child: SlideTransition(position: _riseAt(start), child: child),
      );

  @override
  Widget build(BuildContext context) {
    final BootstrapState boot = ref.watch(bootstrapControllerProvider);
    final String storeName = Platform.isIOS ? 'the App Store' : 'Google Play';

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: AppColors.appBackdropDark,
        body: Stack(
          children: <Widget>[
            // Splash-style vignette: centre breathes lighter than edges.
            const Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment(0, -0.3),
                    radius: 1.1,
                    colors: <Color>[
                      AppColors.bgDark,
                      AppColors.appBackdropDark,
                    ],
                  ),
                ),
              ),
            ),
            SafeArea(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      // Hero: radar rings sweeping out behind a floating
                      // coral tile. The radar is the brand's "calling you
                      // back to the marketplace" mark.
                      _staggered(
                        0,
                        SizedBox(
                          height: 240,
                          child: Stack(
                            alignment: Alignment.center,
                            children: <Widget>[
                              const RadarPulse(
                                color: AppColors.coral,
                                size: 240,
                                maxRadius: 120,
                              ),
                              AnimatedBuilder(
                                animation: _float,
                                builder: (BuildContext _, Widget? child) {
                                  final double dy = math.sin(
                                        _float.value * 2 * math.pi,
                                      ) *
                                      4;
                                  return Transform.translate(
                                    offset: Offset(0, dy),
                                    child: child,
                                  );
                                },
                                child: Container(
                                  width: 84,
                                  height: 84,
                                  decoration: BoxDecoration(
                                    color: AppColors.coral,
                                    borderRadius: BorderRadius.circular(26),
                                    boxShadow: <BoxShadow>[
                                      BoxShadow(
                                        color: AppColors.coral
                                            .withValues(alpha: 0.45),
                                        blurRadius: 42,
                                        spreadRadius: 2,
                                      ),
                                    ],
                                  ),
                                  alignment: Alignment.center,
                                  child: const Icon(
                                    Icons.system_update_rounded,
                                    size: 38,
                                    color: AppColors.coralInk,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      // Butter eyebrow — literally the "new" accent.
                      _staggered(
                        0.15,
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.butter.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: AppColors.butter.withValues(alpha: 0.35),
                            ),
                          ),
                          child: Text(
                            'NEW VERSION READY',
                            style: AppTextStyles.mono.copyWith(
                              fontSize: 11,
                              letterSpacing: 2.4,
                              color: AppColors.butter,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      _staggered(
                        0.28,
                        Text(
                          'Update Drivio\nto keep driving',
                          textAlign: TextAlign.center,
                          style: AppTextStyles.displayLg.copyWith(
                            color: AppColors.ivory,
                            height: 1.08,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      _staggered(
                        0.4,
                        Text(
                          'This version of the app is no longer supported. '
                          'Install the latest update from $storeName and '
                          "you'll be back on the road in a minute.",
                          textAlign: TextAlign.center,
                          style: AppTextStyles.bodySm.copyWith(
                            color: AppColors.ivory.withValues(alpha: 0.66),
                            height: 1.55,
                          ),
                        ),
                      ),
                      const SizedBox(height: 30),
                      _staggered(
                        0.52,
                        SizedBox(
                          width: double.infinity,
                          child: DrivioButton(
                            label: 'Update on $storeName',
                            variant: DrivioButtonVariant.accent,
                            onPressed: () =>
                                openStoreListing(boot.updateCheck.updateUrl),
                          ),
                        ),
                      ),
                      if (boot.updateCheck.currentVersion.isNotEmpty) ...<Widget>[
                        const SizedBox(height: 16),
                        _staggered(
                          0.62,
                          Text(
                            'INSTALLED  V${boot.updateCheck.currentVersion}',
                            style: AppTextStyles.mono.copyWith(
                              fontSize: 11,
                              letterSpacing: 2,
                              color: AppColors.ivory.withValues(alpha: 0.35),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
