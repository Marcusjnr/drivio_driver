import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:drivio_driver/modules/commons/all.dart';
import 'package:drivio_driver/modules/commons/types/pricing_profile.dart';
import 'package:drivio_driver/modules/commons/widgets/detail_scaffold.dart';
import 'package:drivio_driver/modules/dash/features/pricing/presentation/logic/controller/pricing_controller.dart';

/// Driver picks which trip lengths they want to see in the marketplace
/// feed. Stored in `driver_pricing_profile.preferences.trip_length`
/// (`any` / `short` / `long`). Filter is applied client-side in the
/// marketplace feed via the `acceptsDistance` predicate on
/// [PricingProfile].
class PreferredTripLengthPage extends ConsumerWidget {
  const PreferredTripLengthPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final PricingState pricing = ref.watch(pricingControllerProvider);
    final PricingController c =
        ref.read(pricingControllerProvider.notifier);
    final TripLengthPreference current =
        pricing.profile?.tripLength ?? TripLengthPreference.any;

    return DetailScaffold(
      title: 'Preferred trip length',
      footer: DrivioButton(
        label: 'Done',
        onPressed: () => AppNavigation.pop(),
      ),
      children: <Widget>[
        Text(
          "Filter the requests you see. Short = under 5 km, long = 8 km or more.",
          style: AppTextStyles.caption.copyWith(
            color: context.textDim,
            height: 1.55,
          ),
        ),
        const SizedBox(height: 18),
        Container(
          decoration: BoxDecoration(
            color: context.surface,
            borderRadius: AppRadius.md,
            border: Border.all(color: context.border),
          ),
          child: Column(
            children: <Widget>[
              _OptionRow(
                title: 'Any trip length',
                sub: 'Show me everything that comes in.',
                selected: current == TripLengthPreference.any,
                onTap: () => c.setTripLength(TripLengthPreference.any),
              ),
              _OptionRow(
                title: 'Short trips only',
                sub: 'Quick city hops, under 5 km.',
                selected: current == TripLengthPreference.short,
                onTap: () => c.setTripLength(TripLengthPreference.short),
              ),
              _OptionRow(
                title: 'Long trips only',
                sub: 'Inter-suburb runs, 8 km or more.',
                selected: current == TripLengthPreference.long,
                onTap: () => c.setTripLength(TripLengthPreference.long),
                isLast: true,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (pricing.isSaving)
          Row(
            children: <Widget>[
              SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(
                  strokeWidth: 1.5,
                  color: context.textDim,
                ),
              ),
              const SizedBox(width: 8),
              Text('Saving…',
                  style: TextStyle(fontSize: 11, color: context.textDim)),
            ],
          )
        else if (pricing.lastSavedAt != null)
          Text('Saved',
              style: TextStyle(fontSize: 11, color: context.accent)),
      ],
    );
  }
}

class _OptionRow extends StatelessWidget {
  const _OptionRow({
    required this.title,
    required this.sub,
    required this.selected,
    required this.onTap,
    this.isLast = false,
  });

  final String title;
  final String sub;
  final bool selected;
  final VoidCallback onTap;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          border: isLast
              ? null
              : Border(bottom: BorderSide(color: context.border)),
        ),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      color: context.text,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    sub,
                    style: TextStyle(
                      fontSize: 12,
                      color: context.textDim,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected ? context.accent : context.borderStrong,
                  width: 2,
                ),
                color: selected ? context.accent : Colors.transparent,
              ),
              alignment: Alignment.center,
              child: selected
                  ? Icon(DrivioIcons.check,
                      size: 12, color: context.accentInk)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
