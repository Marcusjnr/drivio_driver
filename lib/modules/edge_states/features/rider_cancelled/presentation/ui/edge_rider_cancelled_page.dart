import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:drivio_driver/modules/commons/all.dart';

class EdgeRiderCancelledPage extends ConsumerWidget {
  const EdgeRiderCancelledPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ScreenScaffold(
      child: Stack(
        children: <Widget>[
          const Positioned.fill(
            child: DrivioMap(pickupPosition: Offset(180, 220)),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: <Color>[
                    context.bg.withValues(alpha: 0.2),
                    context.bg.withValues(alpha: 0.9),
                  ],
                ),
              ),
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
                      color: context.red.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: context.red.withValues(alpha: 0.30),
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      Icons.close_rounded,
                      size: 28,
                      color: context.red,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'The rider cancelled this trip',
                    style: AppTextStyles.h2.copyWith(color: context.text),
                  ),
                  const SizedBox(height: 6),
                  RichText(
                    textAlign: TextAlign.center,
                    text: TextSpan(
                      style: AppTextStyles.caption.copyWith(
                        color: context.textDim,
                        height: 1.5,
                      ),
                      children: <InlineSpan>[
                        const TextSpan(
                          text: "Because you'd started driving, you earned a ",
                        ),
                        TextSpan(
                          text: '${NairaFormatter.format(1200)} cancellation fee',
                          style: AppTextStyles.caption.copyWith(
                            color: context.accent,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const TextSpan(text: '.'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                    decoration: BoxDecoration(
                      color: context.surface2,
                      borderRadius: AppRadius.md,
                      border: Border.all(color: context.border),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: <Widget>[
                        Text(
                          'Cancellation credit',
                          style: AppTextStyles.caption
                              .copyWith(color: context.textDim),
                        ),
                        Text(
                          '+${NairaFormatter.format(1200)}',
                          style: AppTextStyles.caption.copyWith(
                            color: context.accent,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  DrivioButton(
                    label: 'Back online · find next trip',
                    onPressed: () =>
                        AppNavigation.replaceAll<void>(AppRoutes.home),
                  ),
                  const SizedBox(height: 8),
                  const DrivioButton(
                    label: 'View details',
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
