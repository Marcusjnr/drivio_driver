import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:drivio_driver/modules/commons/all.dart';
import 'package:drivio_driver/modules/commons/widgets/detail_scaffold.dart';

class HelpArticlePage extends ConsumerWidget {
  const HelpArticlePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<_QA> qas = const <_QA>[
      _QA('When do I get paid?', 'Every trip payout is batched and sent to your linked bank account nightly at 11 PM. Funds typically land by 7 AM the next morning.'),
      _QA('Does Drivio take a cut?', 'No per-trip commission. Drivio runs on a flat monthly subscription — everything you earn on the road is yours.'),
      _QA('What fees apply?', 'A fixed ₦20 bank transfer fee per payout, absorbed by Drivio for all Drivio Pro subscribers.'),
      _QA('How do I change my payout account?', 'Profile → Payment methods → Payout account. Requires 2-step verification and takes 24 hrs to switch.'),
    ];
    return DetailScaffold(
      title: 'Payments & payouts',
      children: <Widget>[
        Text('POPULAR QUESTIONS',
            style: AppTextStyles.eyebrow.copyWith(color: context.textDim)),
        const SizedBox(height: 10),
        ...qas.map(
          (_QA qa) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _ExpandableQA(qa: qa),
          ),
        ),
        const SizedBox(height: 20),
        Center(
          child: Text(
            'Still stuck?',
            style: TextStyle(fontSize: 11, color: context.textDim),
          ),
        ),
        const SizedBox(height: 10),
        DrivioButton(
          label: '💬 Chat with a human',
          variant: DrivioButtonVariant.ghost,
          onPressed: () => AppNavigation.push(AppRoutes.supportChat),
        ),
      ],
    );
  }
}

class _QA {
  const _QA(this.q, this.a);
  final String q;
  final String a;
}

class _ExpandableQA extends ConsumerStatefulWidget {
  const _ExpandableQA({required this.qa});
  final _QA qa;

  @override
  ConsumerState<_ExpandableQA> createState() => _ExpandableQAState();
}

class _ExpandableQAState extends ConsumerState<_ExpandableQA> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => setState(() => _open = !_open),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: context.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: context.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    widget.qa.q,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: context.text,
                    ),
                  ),
                ),
                Icon(
                  _open ? DrivioIcons.chevronUp : DrivioIcons.chevronDown,
                  size: 18,
                  color: context.textMuted,
                ),
              ],
            ),
            if (_open) ...<Widget>[
              const SizedBox(height: 10),
              Text(
                widget.qa.a,
                style: TextStyle(
                  fontSize: 13,
                  color: context.textDim,
                  height: 1.6,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
