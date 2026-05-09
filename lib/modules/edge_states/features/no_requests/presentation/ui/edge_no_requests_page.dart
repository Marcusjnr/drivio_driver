import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:drivio_driver/modules/commons/all.dart';

class EdgeNoRequestsPage extends ConsumerWidget {
  const EdgeNoRequestsPage({super.key});

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
                  colors: <Color>[
                    context.bg.withValues(alpha: 0.3),
                    context.bg.withValues(alpha: 0.9),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: 12,
            left: 16,
            right: 16,
            child: OnlineToggle(
              online: true,
              onTap: () => AppNavigation.replaceAll<void>(AppRoutes.home),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: BottomSheetCard(
              child: Column(
                children: <Widget>[
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: context.surface2,
                      shape: BoxShape.circle,
                      border: Border.all(color: context.borderStrong),
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      Icons.bedtime_rounded,
                      size: 26,
                      color: context.textDim,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    "It's quiet right now",
                    style: AppTextStyles.h2.copyWith(color: context.text),
                  ),
                  const SizedBox(height: 6),
                  SizedBox(
                    width: 280,
                    child: Text(
                      "No requests around you yet. We'll show busy "
                      "zones the moment they pick up.",
                      textAlign: TextAlign.center,
                      style: AppTextStyles.caption.copyWith(
                        color: context.textDim,
                        height: 1.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  const DrivioButton(
                    label: 'Show nearby hotspots',
                    onPressed: null,
                  ),
                  const SizedBox(height: 8),
                  const DrivioButton(
                    label: 'Lower my fare',
                    variant: DrivioButtonVariant.ghost,
                    onPressed: null,
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
