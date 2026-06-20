import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:drivio_driver/modules/commons/all.dart';
import 'package:drivio_driver/modules/subscription/features/pick_plan/presentation/logic/pick_plan_controller.dart';

/// The quiet-confidence recommendation card above the tier list.
///
/// Voice & layout per brand spec: warm + literary blend. The eyebrow
/// labels the lens; the body delivers a single personalised observation
/// with the verdict in bold. There is no CTA — this banner exists to
/// inform, not to nudge. The driver picks below.
class RecommendationBanner extends ConsumerWidget {
  const RecommendationBanner({super.key, required this.recommendation});

  final PlanRecommendation recommendation;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
      decoration: BoxDecoration(
        color: context.accent.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: context.accent.withValues(alpha: 0.28),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: context.accent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(6),
                ),
                alignment: Alignment.center,
                child: Icon(
                  Icons.auto_awesome_rounded,
                  size: 12,
                  color: context.accent,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                _eyebrow(recommendation),
                style: AppTextStyles.eyebrow.copyWith(
                  color: context.accent,
                  letterSpacing: 1.4,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _ReasonText(reason: recommendation.reason),
        ],
      ),
    );
  }

  String _eyebrow(PlanRecommendation r) {
    if (r.observedDays <= 0) {
      return 'A SAFE PLACE TO START';
    }
    return 'BASED ON YOUR PATTERN';
  }
}

/// Renders the recommendation reason with the **bolded** phrase emphasised
/// inline. Markdown-light: only one bold span is supported, the
/// **first** one. Keeps the parser dead simple and the copy honest.
class _ReasonText extends StatelessWidget {
  const _ReasonText({required this.reason});

  final String reason;

  @override
  Widget build(BuildContext context) {
    final List<InlineSpan> spans = _parse(reason, context);
    return RichText(
      text: TextSpan(
        style: AppTextStyles.body.copyWith(
          color: context.text,
          height: 1.45,
        ),
        children: spans,
      ),
    );
  }

  List<InlineSpan> _parse(String reason, BuildContext context) {
    final int start = reason.indexOf('**');
    if (start == -1) {
      return <InlineSpan>[TextSpan(text: reason)];
    }
    final int end = reason.indexOf('**', start + 2);
    if (end == -1) {
      return <InlineSpan>[TextSpan(text: reason.replaceAll('**', ''))];
    }

    final String before = reason.substring(0, start);
    final String highlight = reason.substring(start + 2, end);
    final String after = reason.substring(end + 2);

    return <InlineSpan>[
      if (before.isNotEmpty) TextSpan(text: before),
      TextSpan(
        text: highlight,
        style: AppTextStyles.body.copyWith(
          color: context.text,
          fontWeight: FontWeight.w700,
        ),
      ),
      if (after.isNotEmpty) TextSpan(text: after),
    ];
  }
}
