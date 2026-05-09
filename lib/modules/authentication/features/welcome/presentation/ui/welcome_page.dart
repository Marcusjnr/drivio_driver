import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:drivio_driver/modules/commons/all.dart';

class WelcomePage extends ConsumerWidget {
  const WelcomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ScreenScaffold(
      child: Stack(
        children: <Widget>[
          const Positioned.fill(child: DrivioMap()),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: const <double>[0, 0.55, 0.85],
                  colors: <Color>[
                    context.bg.withValues(alpha: 0.5),
                    context.bg.withValues(alpha: 0.85),
                    context.bg,
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(28, 24, 28, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      const BrandMark(size: 44),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            'DRIVIO',
                            style: AppTextStyles.h3.copyWith(
                              color: context.text,
                              letterSpacing: 1.4,
                            ),
                          ),
                          Text(
                            'DRIVER',
                            style: AppTextStyles.mono.copyWith(
                              color: context.accent,
                              letterSpacing: 2.2,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const Spacer(),
                  _Tagline(),
                  const SizedBox(height: 14),
                  Text(
                    'Be your own\nboss on the road.',
                    style:
                        AppTextStyles.displayLg.copyWith(color: context.text),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: 320,
                    child: Text(
                      'You set the fare. You pick the trips. '
                      'We hand over the requests.',
                      style:
                          AppTextStyles.body.copyWith(color: context.textDim),
                    ),
                  ),
                  const SizedBox(height: 22),
                  const _Highlights(),
                  const SizedBox(height: 24),
                  DrivioButton(
                    label: 'Get started',
                    onPressed: () => AppNavigation.push(AppRoutes.signUp),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 44,
                    child: TextButton(
                      onPressed: () => AppNavigation.push(AppRoutes.signIn),
                      style: TextButton.styleFrom(
                        foregroundColor: context.text,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: Text(
                        'I have an account',
                        style: AppTextStyles.bodySm.copyWith(
                          color: context.textDim,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Tagline extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        _Dot(color: context.accent),
        const SizedBox(width: 10),
        Text(
          'YOU SET THE FARE',
          style: AppTextStyles.eyebrow.copyWith(
            color: context.accent,
            letterSpacing: 2.2,
          ),
        ),
        const SizedBox(width: 10),
        _Dot(color: context.accent),
      ],
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 5,
      height: 5,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

class _Highlights extends StatelessWidget {
  const _Highlights();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: context.surface.withValues(alpha: 0.7),
        borderRadius: AppRadius.lg,
        border: Border.all(color: context.border),
      ),
      child: Row(
        children: <Widget>[
          const Expanded(
            child: _HighlightItem(value: '0%', label: 'COMMISSION'),
          ),
          _Divider(color: context.border),
          const Expanded(
            child: _HighlightItem(value: '90 d', label: 'FREE TRIAL'),
          ),
          _Divider(color: context.border),
          const Expanded(
            child: _HighlightItem(value: '24/7', label: 'PAYOUTS'),
          ),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(width: 1, height: 28, color: color);
  }
}

class _HighlightItem extends StatelessWidget {
  const _HighlightItem({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          value,
          style: AppTextStyles.metricVal.copyWith(color: context.text),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: AppTextStyles.micro.copyWith(
            color: context.textDim,
            letterSpacing: 1.4,
          ),
        ),
      ],
    );
  }
}
