import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:drivio_driver/modules/commons/all.dart';
import 'package:drivio_driver/modules/commons/widgets/detail_scaffold.dart';

class HelpPage extends ConsumerWidget {
  const HelpPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<_Topic> topics = const <_Topic>[
      _Topic('💰', 'Payments & payouts', 'Daily transfer, fees, tax'),
      _Topic('🚘', 'My vehicle', 'Update details, inspection, insurance'),
      _Topic('⭐', 'Ratings & reviews', 'How it works, disputes'),
      _Topic('🛡️', 'Safety & incidents', 'Report a rider, emergencies'),
      _Topic('📋', 'Subscription', 'Plans, billing, cancellation'),
      _Topic('💬', 'App issues', 'Bugs, connection problems'),
    ];
    return DetailScaffold(
      title: 'Help & support',
      children: <Widget>[
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: context.red.withValues(alpha: 0.1),
            borderRadius: AppRadius.base,
            border: Border.all(color: context.red.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: <Widget>[
              const Text('🚨', style: TextStyle(fontSize: 22)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Emergency assistance',
                      style: TextStyle(
                        fontSize: 13,
                        color: context.red,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Accident, safety concern, rider issue.',
                      style: TextStyle(fontSize: 11, color: context.textDim),
                    ),
                  ],
                ),
              ),
              ElevatedButton(
                onPressed: () {},
                style: ElevatedButton.styleFrom(
                  backgroundColor: context.red,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  minimumSize: const Size(0, 32),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text(
                  'Call now',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Text(
          'BROWSE TOPICS',
          style: AppTextStyles.eyebrow.copyWith(color: context.textDim),
        ),
        const SizedBox(height: 10),
        ...topics.map(
          (_Topic t) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: InkWell(
              onTap: () => AppNavigation.push(AppRoutes.helpArticle),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: context.surface,
                  borderRadius: AppRadius.base,
                  border: Border.all(color: context.border),
                ),
                child: Row(
                  children: <Widget>[
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: context.surface2,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      alignment: Alignment.center,
                      child: Text(t.icon, style: const TextStyle(fontSize: 16)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            t.label,
                            style: TextStyle(
                              fontSize: 13,
                              color: context.text,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            t.sub,
                            style: TextStyle(fontSize: 11, color: context.textDim),
                          ),
                        ],
                      ),
                    ),
                    Icon(DrivioIcons.chevron, size: 14, color: context.textMuted),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        DrivioButton(
          label: '💬 Chat with support',
          onPressed: () => AppNavigation.push(AppRoutes.supportChat),
        ),
        const SizedBox(height: 10),
        Center(
          child: Text(
            'Average response time: under 4 minutes',
            style: TextStyle(fontSize: 11, color: context.textDim),
          ),
        ),
      ],
    );
  }
}

class _Topic {
  const _Topic(this.icon, this.label, this.sub);
  final String icon;
  final String label;
  final String sub;
}
