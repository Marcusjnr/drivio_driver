import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:drivio_driver/modules/commons/all.dart';
import 'package:drivio_driver/modules/commons/types/subscription.dart';

class SubscriptionGateSheet extends ConsumerWidget {
  const SubscriptionGateSheet({
    super.key,
    required this.subscription,
    required this.onContinue,
    required this.onDismiss,
  });

  final Subscription? subscription;
  final VoidCallback onContinue;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final _Copy copy = _copyFor(subscription?.status);

    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        GestureDetector(
          onTap: onDismiss,
          child: Container(color: Colors.black.withValues(alpha: 0.55)),
        ),
        Align(
          alignment: Alignment.bottomCenter,
          child: BottomSheetCard(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: copy.tone.withValues(alpha: 0.16),
                    border: Border.all(
                      color: copy.tone.withValues(alpha: 0.3),
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  alignment: Alignment.center,
                  child: const Text('💳', style: TextStyle(fontSize: 26)),
                ),
                const SizedBox(height: 14),
                Pill(text: copy.pill, tone: copy.pillTone),
                const SizedBox(height: 10),
                Text(
                  copy.title,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.h1.copyWith(color: context.text),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: 290,
                  child: Text(
                    copy.body,
                    textAlign: TextAlign.center,
                    style: AppTextStyles.caption.copyWith(
                      color: context.textDim,
                      height: 1.5,
                    ),
                  ),
                ),
                const SizedBox(height: 22),
                DrivioButton(label: copy.cta, onPressed: onContinue),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: onDismiss,
                  child: Text(
                    'Maybe later',
                    style:
                        TextStyle(color: context.textDim, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  _Copy _copyFor(SubscriptionStatus? s) {
    switch (s) {
      case SubscriptionStatus.expired:
      case null:
        return const _Copy(
          pill: 'SUBSCRIPTION REQUIRED',
          pillTone: PillTone.amber,
          title: 'Activate Drivio Pro\nto go online.',
          body:
              'Your subscription is no longer active. Reactivate Drivio Pro to start receiving ride requests again.',
          cta: 'Reactivate plan',
          tone: Color(0xFFF59E0B),
        );
      case SubscriptionStatus.cancelled:
        return const _Copy(
          pill: 'SUBSCRIPTION CANCELLED',
          pillTone: PillTone.red,
          title: 'Reactivate to go\nback online.',
          body:
              'You cancelled Drivio Pro. Re-activate any time and your account picks up where you left off.',
          cta: 'Reactivate plan',
          tone: Color(0xFFF87171),
        );
      case SubscriptionStatus.trialing:
      case SubscriptionStatus.active:
      case SubscriptionStatus.pastDue:
        return const _Copy(
          pill: 'SUBSCRIPTION REQUIRED',
          pillTone: PillTone.amber,
          title: 'Activate Drivio Pro\nto go online.',
          body:
              'A monthly Drivio Pro subscription is required to receive ride requests.',
          cta: 'Continue',
          tone: Color(0xFFF59E0B),
        );
    }
  }
}

class _Copy {
  const _Copy({
    required this.pill,
    required this.pillTone,
    required this.title,
    required this.body,
    required this.cta,
    required this.tone,
  });
  final String pill;
  final PillTone pillTone;
  final String title;
  final String body;
  final String cta;
  final Color tone;
}
