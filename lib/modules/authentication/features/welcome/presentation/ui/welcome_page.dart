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
          Padding(
            padding: const EdgeInsets.fromLTRB(28, 40, 28, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const BrandMark(size: 44),
                const SizedBox(height: 24),
                Text(
                  'DRIVIO · DRIVER',
                  style: AppTextStyles.eyebrow.copyWith(color: context.accent),
                ),
                const Spacer(),
                Text(
                  'Be your own\nboss on the road.',
                  style: AppTextStyles.displayLg.copyWith(color: context.text),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: 300,
                  child: Text(
                    'You set the fare. You pick the trips. We just hand you the requests and the tools to grow.',
                    style: AppTextStyles.body.copyWith(color: context.textDim),
                  ),
                ),
                const SizedBox(height: 28),
                DrivioButton(
                  label: 'Get started',
                  onPressed: () => AppNavigation.push(AppRoutes.signUp),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 40,
                  child: TextButton(
                    onPressed: () => AppNavigation.push(AppRoutes.signIn),
                    child: Text(
                      'I already have an account',
                      style: TextStyle(color: context.textDim, fontSize: 14),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
