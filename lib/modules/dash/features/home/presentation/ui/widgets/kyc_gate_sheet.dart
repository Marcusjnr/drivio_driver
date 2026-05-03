import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:drivio_driver/modules/commons/all.dart';
import 'package:drivio_driver/modules/kyc/features/kyc_home/presentation/logic/controller/kyc_controller.dart';

class KycGateSheet extends ConsumerWidget {
  const KycGateSheet({
    super.key,
    required this.status,
    required this.onContinue,
    required this.onDismiss,
  });

  final KycOverallStatus status;
  final VoidCallback onContinue;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final _Copy copy = _copyFor(status);
    final List<KycStep> steps = ref.watch(
      kycControllerProvider.select((KycState s) => s.steps),
    );

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
                    border: Border.all(color: copy.tone.withValues(alpha: 0.3)),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  alignment: Alignment.center,
                  child: const Text('🪪', style: TextStyle(fontSize: 26)),
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
                const SizedBox(height: 18),
                ...steps.map(
                  (KycStep s) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _ChecklistRow(step: s),
                  ),
                ),
                const SizedBox(height: 14),
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

  _Copy _copyFor(KycOverallStatus s) {
    switch (s) {
      case KycOverallStatus.pendingReview:
        return const _Copy(
          pill: 'UNDER REVIEW',
          pillTone: PillTone.accent,
          title: 'We\'re reviewing\nyour application.',
          body:
              'You\'ll be able to go online as soon as your verification is approved. We\'ll send you a notification.',
          cta: 'View application',
          tone: Color(0xFF34D399),
        );
      case KycOverallStatus.rejected:
        return const _Copy(
          pill: 'REJECTED',
          pillTone: PillTone.red,
          title: 'Some details\nneed fixing.',
          body:
              'Open the items marked "Re-do" to update them, then re-submit for review.',
          cta: 'See what to fix',
          tone: Color(0xFFF87171),
        );
      case KycOverallStatus.notStarted:
      case KycOverallStatus.inProgress:
      case KycOverallStatus.approved:
        return const _Copy(
          pill: 'VERIFICATION REQUIRED',
          pillTone: PillTone.amber,
          title: 'Complete verification\nto go online.',
          body:
              'Drivio needs to verify your identity, vehicle, and documents before you can accept trips.',
          cta: 'Continue verification',
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

class _ChecklistRow extends StatelessWidget {
  const _ChecklistRow({required this.step});
  final KycStep step;

  @override
  Widget build(BuildContext context) {
    final bool done = step.status == KycStepStatus.submitted ||
        step.status == KycStepStatus.approved;
    final bool needsAction = step.status == KycStepStatus.rejected ||
        step.status == KycStepStatus.expired;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: context.surface2,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: context.border),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 20,
            height: 20,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: done ? context.accent : Colors.transparent,
              border: Border.all(
                color: done ? context.accent : context.textMuted,
                width: 1.5,
              ),
              borderRadius: BorderRadius.circular(6),
            ),
            child: done
                ? Icon(DrivioIcons.check, size: 12, color: context.bg)
                : null,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              step.title,
              style: TextStyle(
                fontSize: 13,
                color: context.text,
                decoration:
                    done ? TextDecoration.lineThrough : TextDecoration.none,
                decorationColor: context.textMuted,
              ),
            ),
          ),
          if (needsAction)
            Pill(
              text: step.status == KycStepStatus.expired ? 'Renew' : 'Re-do',
              tone: PillTone.red,
            ),
        ],
      ),
    );
  }
}
