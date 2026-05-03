import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:drivio_driver/modules/commons/all.dart';
import 'package:drivio_driver/modules/commons/types/pricing_profile.dart';
import 'package:drivio_driver/modules/commons/widgets/detail_scaffold.dart';
import 'package:drivio_driver/modules/dash/features/pricing/presentation/logic/controller/pricing_controller.dart';

/// Driver picks the maximum pickup-leg distance they're willing to drive.
/// Stored in `driver_pricing_profile.preferences.max_pickup_km` and
/// honoured by the marketplace feed: requests whose pickup is farther
/// than this from the driver's last GPS fix are hidden client-side.
class PickupDistancePage extends ConsumerWidget {
  const PickupDistancePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final PricingState pricing = ref.watch(pricingControllerProvider);
    final PricingController c =
        ref.read(pricingControllerProvider.notifier);
    final PricingProfile profile =
        pricing.profile ?? PricingProfile.platformDefault;
    final double km = profile.maxPickupKm.clamp(0.5, 10.0);

    return DetailScaffold(
      title: 'Max pickup distance',
      footer: DrivioButton(
        label: 'Done',
        onPressed: () => AppNavigation.pop(),
      ),
      children: <Widget>[
        Text(
          "You won't see ride requests where the pickup is farther than this from your current location.",
          style: AppTextStyles.caption.copyWith(
            color: context.textDim,
            height: 1.55,
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
        const SizedBox(height: 12),
        Center(
          child: Column(
            children: <Widget>[
              RichText(
                text: TextSpan(
                  style: TextStyle(
                    fontSize: 56,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -1.6,
                    color: context.accent,
                  ),
                  children: <InlineSpan>[
                    TextSpan(text: km.toStringAsFixed(1)),
                    TextSpan(
                      text: ' km',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: context.textDim,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '≈ ${(km * 3).round()} min drive on average',
                style: TextStyle(fontSize: 12, color: context.textDim),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: context.accent,
            inactiveTrackColor: context.surface3,
            thumbColor: context.text,
          ),
          child: Slider(
            value: km,
            min: 0.5,
            max: 10,
            divisions: 19,
            // Setter writes through PricingController → debounced flush
            // to driver_pricing_profile.preferences.max_pickup_km.
            onChanged: c.setMaxPickupKm,
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Text('0.5 km',
                style: TextStyle(fontSize: 11, color: context.textDim)),
            Text('10 km',
                style: TextStyle(fontSize: 11, color: context.textDim)),
          ],
        ),
        const SizedBox(height: 24),
        Text('IMPACT ESTIMATE',
            style: AppTextStyles.eyebrow.copyWith(color: context.textDim)),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: context.surface,
            borderRadius: AppRadius.md,
            border: Border.all(color: context.border),
          ),
          child: Column(
            children: <Widget>[
              FieldRow(
                label: 'Requests per hour',
                value: '~${(2 + km * 1.4).round()}',
                chevron: false,
              ),
              FieldRow(
                label: 'Avg pickup time',
                value: '${(km * 2.5).round()} min',
                chevron: false,
              ),
              FieldRow(
                label: 'Fuel spend per trip',
                value: '₦${(km * 180).round()}',
                chevron: false,
                divider: false,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
