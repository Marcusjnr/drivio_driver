import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:drivio_driver/modules/commons/all.dart';

/// SCR-002 — Welcome (signed out).
///
/// Full-bleed photo carousel: three cinematic driver photographs graded
/// into the brand's charcoal-teal world, each carrying one driver USP
/// (name your price / keep what you earn / verified riders). Slides
/// auto-advance and can be swiped; the wordmark, dots and CTAs stay
/// fixed over the photos. Copy sits on a scrim that deepens to the
/// app backdrop so ivory type and the coral CTA always cut through.
class WelcomePage extends ConsumerStatefulWidget {
  const WelcomePage({super.key});

  @override
  ConsumerState<WelcomePage> createState() => _WelcomePageState();
}

class _Slide {
  const _Slide({
    required this.asset,
    required this.eyebrow,
    required this.title,
    required this.body,
  });

  final String asset;
  final String eyebrow;
  final String title;
  final String body;
}

const List<_Slide> _slides = <_Slide>[
  _Slide(
    asset: 'assets/images/onboarding/onboard_1.jpg',
    eyebrow: 'THE DRIVIO MARKETPLACE',
    title: 'Your fare.\nYour call.',
    body: 'Riders request, you offer the price. '
        'No forced fares, no surprises.',
  ),
  _Slide(
    asset: 'assets/images/onboarding/onboard_2.jpg',
    eyebrow: 'KEEP WHAT YOU EARN',
    title: 'No commission\non trips.',
    body: 'Riders pay you directly. '
        'The full fare stays in your pocket.',
  ),
  _Slide(
    asset: 'assets/images/onboarding/onboard_3.jpg',
    eyebrow: 'SAFER PICKUPS',
    title: 'Know who\nyou carry.',
    body: 'Every rider is verified, with a real photo '
        'and rating before you accept.',
  ),
];

/// Fixed-height content of the bottom controls: dots (6) + gap (18) +
/// primary CTA (52) + gap (10) + outlined CTA (50) + gap (2) + waitlist
/// link (40) + bottom padding (18). The slide copy reserves this plus
/// the device's safe-area inset and a breathing gap, so text can never
/// slip under the buttons on tall-inset (gesture-nav) phones.
const double _kControlsHeight = 196;
const double _kCopyGap = 18;
const Duration _kAutoAdvance = Duration(seconds: 5);
const Duration _kPageTurn = Duration(milliseconds: 650);

class _WelcomePageState extends ConsumerState<WelcomePage> {
  final PageController _controller = PageController();
  Timer? _timer;
  int _current = 0;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onPageScroll);
    _startTimer();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    for (final _Slide s in _slides) {
      precacheImage(AssetImage(s.asset), context);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onPageScroll() {
    final int page = (_controller.page ?? 0).round() % _slides.length;
    if (page != _current) {
      setState(() => _current = page);
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(_kAutoAdvance, (_) {
      if (!mounted || !_controller.hasClients) {
        return;
      }
      _controller.nextPage(duration: _kPageTurn, curve: Curves.easeOutQuart);
    });
  }

  bool _onScroll(ScrollNotification n) {
    // A finger on the carousel pauses auto-advance; it resumes (with a
    // fresh full interval) once the drag settles.
    if (n is ScrollStartNotification && n.dragDetails != null) {
      _timer?.cancel();
    } else if (n is ScrollEndNotification) {
      _startTimer();
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: AppTheme.darkSystemOverlay,
      child: Scaffold(
        backgroundColor: AppColors.appBackdropDark,
        body: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            NotificationListener<ScrollNotification>(
              onNotification: _onScroll,
              child: PageView.builder(
                controller: _controller,
                itemBuilder: (BuildContext _, int i) =>
                    _SlideView(slide: _slides[i % _slides.length]),
              ),
            ),

            // Top scrim + wordmark — fixed above the swiping photos.
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: <Color>[
                      AppColors.appBackdropDark.withValues(alpha: 0.55),
                      AppColors.appBackdropDark.withValues(alpha: 0),
                    ],
                  ),
                ),
                child: const SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(24, 14, 24, 28),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: _MarkOnPhoto(),
                    ),
                  ),
                ),
              ),
            ),

            // Fixed bottom controls: dots + CTAs.
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 18),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      _Dots(current: _current, count: _slides.length),
                      const SizedBox(height: 18),
                      DrivioButton(
                        label: 'Get started',
                        onPressed: () => AppNavigation.push(AppRoutes.signUp),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: OutlinedButton(
                          onPressed: () =>
                              AppNavigation.push(AppRoutes.signIn),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.ivory,
                            side: BorderSide(
                              color: AppColors.ivory.withValues(alpha: 0.55),
                              width: 1.2,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: Text(
                            'I already have an account',
                            style: AppTextStyles.bodySm.copyWith(
                              color: AppColors.ivory,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 2),
                      SizedBox(
                        width: double.infinity,
                        height: 40,
                        child: TextButton(
                          onPressed: () => AppNavigation.push(
                            AppRoutes.signUp,
                            arguments: true, // fromWaitlist banner
                          ),
                          child: Text(
                            'Joined the waitlist? Finish setting up',
                            style: AppTextStyles.captionSm.copyWith(
                              color: AppColors.ivory.withValues(alpha: 0.75),
                              fontWeight: FontWeight.w600,
                              decoration: TextDecoration.underline,
                              decorationColor:
                                  AppColors.ivory.withValues(alpha: 0.4),
                            ),
                          ),
                        ),
                      ),
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

/// One carousel slide: slow-breathing photo, scrim, and the USP copy
/// block sitting just above the fixed controls.
class _SlideView extends StatefulWidget {
  const _SlideView({required this.slide});

  final _Slide slide;

  @override
  State<_SlideView> createState() => _SlideViewState();
}

class _SlideViewState extends State<_SlideView>
    with SingleTickerProviderStateMixin {
  // Ken Burns drift — a barely-there zoom so the photos feel alive
  // during the 5s dwell without calling attention to themselves.
  late final AnimationController _kenBurns = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 12),
  )..repeat(reverse: true);

  late final Animation<double> _scale = Tween<double>(begin: 1.0, end: 1.07)
      .animate(CurvedAnimation(parent: _kenBurns, curve: Curves.easeInOut));

  @override
  void dispose() {
    _kenBurns.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        ClipRect(
          child: ScaleTransition(
            scale: _scale,
            child: Image.asset(widget.slide.asset, fit: BoxFit.cover),
          ),
        ),

        // Reading scrim — clear up top, settling into the app backdrop
        // where the copy and CTAs live.
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              stops: const <double>[0.34, 0.62, 0.86, 1.0],
              colors: <Color>[
                AppColors.appBackdropDark.withValues(alpha: 0),
                AppColors.appBackdropDark.withValues(alpha: 0.45),
                AppColors.appBackdropDark.withValues(alpha: 0.92),
                AppColors.appBackdropDark,
              ],
            ),
          ),
        ),

        // USP copy — anchored above the real height of the fixed
        // controls, including this device's bottom safe-area inset.
        Positioned(
          left: 24,
          right: 24,
          bottom: _kControlsHeight +
              MediaQuery.paddingOf(context).bottom +
              _kCopyGap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                widget.slide.eyebrow,
                style: AppTextStyles.eyebrow.copyWith(color: AppColors.coral),
              ),
              const SizedBox(height: 12),
              Text(
                widget.slide.title,
                style: AppTextStyles.displayLg.copyWith(
                  color: AppColors.ivory,
                  fontSize: 40,
                  height: 1.08,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                widget.slide.body,
                style: AppTextStyles.bodySm.copyWith(
                  color: AppColors.ivory.withValues(alpha: 0.78),
                  height: 1.55,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Wordmark rendered explicitly in ivory + coral — the photos underneath
/// are always dark, so this can't defer to the ambient theme the way
/// [BrandMark] does.
class _MarkOnPhoto extends StatelessWidget {
  const _MarkOnPhoto();

  @override
  Widget build(BuildContext context) {
    const double size = 24;
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: <Widget>[
        Text(
          'Drivio',
          style: AppTextStyles.h1.copyWith(
            fontSize: size,
            color: AppColors.ivory,
            height: 1.0,
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 3),
          child: Container(
            width: size * 0.13,
            height: size * 0.13,
            decoration: const BoxDecoration(
              color: AppColors.coral,
              shape: BoxShape.circle,
            ),
          ),
        ),
      ],
    );
  }
}

class _Dots extends StatelessWidget {
  const _Dots({required this.current, required this.count});

  final int current;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        for (int i = 0; i < count; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 240),
            curve: Curves.easeOutQuart,
            margin: const EdgeInsets.symmetric(horizontal: 3.5),
            width: i == current ? 22 : 6,
            height: 6,
            decoration: BoxDecoration(
              color: i == current
                  ? AppColors.coral
                  : AppColors.ivory.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
      ],
    );
  }
}
