import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:drivio_driver/modules/commons/all.dart';
import 'package:drivio_driver/modules/commons/widgets/detail_scaffold.dart';

class ReuploadDocPage extends ConsumerWidget {
  const ReuploadDocPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<String> tips = const <String>[
      'Whole document visible, no corners cut off',
      'Well-lit, not blurry',
      'All text readable',
      'No glare or reflections',
    ];
    return DetailScaffold(
      title: 'Re-upload document',
      footer: DrivioButton(
        label: 'Submit for review',
        onPressed: () => AppNavigation.pop(),
      ),
      children: <Widget>[
        Text(
          'Upload a clear photo or PDF. Your existing document stays active until the new one is approved (usually under 15 min).',
          style: AppTextStyles.caption.copyWith(
            color: context.textDim,
            height: 1.55,
          ),
        ),
        const SizedBox(height: 16),
        Text('NEW FILE', style: AppTextStyles.eyebrow.copyWith(color: context.textDim)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: context.surface,
            borderRadius: AppRadius.md,
            border: Border.all(color: context.borderStrong),
          ),
          child: Column(
            children: <Widget>[
              const Text('📸', style: TextStyle(fontSize: 40)),
              const SizedBox(height: 10),
              Text(
                'Tap to take a photo',
                style: TextStyle(
                  fontSize: 14,
                  color: context.text,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'or upload from files',
                style: TextStyle(fontSize: 12, color: context.textDim),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text('GOOD PHOTOS', style: AppTextStyles.eyebrow.copyWith(color: context.textDim)),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: context.surface,
            borderRadius: AppRadius.md,
            border: Border.all(color: context.border),
          ),
          child: Column(
            children: List<Widget>.generate(tips.length, (int i) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  border: i == tips.length - 1
                      ? null
                      : Border(bottom: BorderSide(color: context.border)),
                ),
                child: Row(
                  children: <Widget>[
                    Icon(DrivioIcons.check, size: 16, color: context.accent),
                    const SizedBox(width: 10),
                    Text(tips[i],
                        style: TextStyle(fontSize: 13, color: context.text)),
                  ],
                ),
              );
            }),
          ),
        ),
      ],
    );
  }
}
