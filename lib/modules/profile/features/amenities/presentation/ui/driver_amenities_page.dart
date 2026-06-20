import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:drivio_driver/modules/commons/all.dart';
import 'package:drivio_driver/modules/commons/data/driver_amenities_repository.dart';
import 'package:drivio_driver/modules/commons/utils/amenity_icons.dart';
import 'package:drivio_driver/modules/commons/widgets/amenity_chip.dart';
import 'package:drivio_driver/modules/commons/widgets/detail_scaffold.dart';
import 'package:drivio_driver/modules/profile/features/amenities/presentation/logic/controller/driver_amenities_controller.dart';

/// `/profile/amenities` — the driver toggles the curated perks they offer.
/// Shown to riders as tags on the offer card.
class DriverAmenitiesPage extends ConsumerWidget {
  const DriverAmenitiesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final DriverAmenitiesState state =
        ref.watch(driverAmenitiesControllerProvider);
    final DriverAmenitiesController controller =
        ref.read(driverAmenitiesControllerProvider.notifier);

    return DetailScaffold(
      title: 'Amenities',
      subtitle: 'What you offer riders. Shown on your offers.',
      footer: DrivioButton(
        label: state.isSaving ? 'Saving…' : 'Save amenities',
        onPressed: state.isSaving
            ? null
            : () async {
                final bool ok = await controller.save();
                if (ok) {
                  AppNotifier.success(message: 'Amenities updated');
                }
              },
      ),
      children: <Widget>[
        if (state.isLoading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 48),
            child: Center(child: CircularProgressIndicator()),
          )
        else ...<Widget>[
          Text(
            'Pick the perks you genuinely offer. Riders see these as tags '
            'when they compare offers.',
            style: AppTextStyles.bodySm.copyWith(color: context.textDim),
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: state.options.map((AmenityOption o) {
              return AmenityChip(
                label: o.label,
                icon: amenityIcon(o.code),
                isSelected: state.selected.contains(o.code),
                onTap: () => controller.toggle(o.code),
              );
            }).toList(growable: false),
          ),
          if (state.error != null) ...<Widget>[
            const SizedBox(height: 16),
            Text(
              state.error!,
              style: AppTextStyles.captionSm.copyWith(color: context.coral),
            ),
          ],
        ],
      ],
    );
  }
}
