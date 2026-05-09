import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:drivio_driver/modules/commons/all.dart';

class EdgeOfflinePage extends ConsumerWidget {
  const EdgeOfflinePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ScreenScaffold(
      child: Stack(
        children: <Widget>[
          const Positioned.fill(child: DrivioMap()),
          Positioned.fill(
            child: Container(color: context.bg.withValues(alpha: 0.78)),
          ),
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: context.red.withValues(alpha: 0.14),
                      border: Border.all(
                        color: context.red.withValues(alpha: 0.30),
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      Icons.cloud_off_rounded,
                      size: 30,
                      color: context.red,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    "You're offline",
                    style: AppTextStyles.h1.copyWith(color: context.text),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "We can't reach Drivio right now. Your active trip "
                    "is saved — we'll sync as soon as you're back.",
                    textAlign: TextAlign.center,
                    style: AppTextStyles.bodySm.copyWith(
                      color: context.textDim,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 22),
                  DrivioButton(
                    label: 'Retry connection',
                    variant: DrivioButtonVariant.primary,
                    onPressed: () =>
                        AppNavigation.replaceAll<void>(AppRoutes.home),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Last synced 2 min ago · Wi-Fi unavailable',
                    style: AppTextStyles.mono.copyWith(
                      fontSize: 12,
                      color: context.textMuted,
                      letterSpacing: 0.6,
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
