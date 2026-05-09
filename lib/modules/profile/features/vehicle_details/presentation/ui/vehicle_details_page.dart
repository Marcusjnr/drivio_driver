import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shimmer/shimmer.dart';

import 'package:drivio_driver/modules/commons/all.dart';
import 'package:drivio_driver/modules/commons/types/vehicle.dart';
import 'package:drivio_driver/modules/commons/widgets/detail_scaffold.dart';
import 'package:drivio_driver/modules/dash/features/profile_hub/presentation/logic/controller/profile_hub_controller.dart';

class VehicleDetailsPage extends ConsumerWidget {
  const VehicleDetailsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ProfileHubState state = ref.watch(profileHubControllerProvider);
    final Vehicle? v = state.activeVehicle;

    if (state.isLoading && v == null) {
      return DetailScaffold(
        title: 'Vehicle details',
        children: <Widget>[
          _VehicleDetailsShimmer(
            base: context.surface2,
            highlight: context.surface3,
          ),
        ],
      );
    }

    if (v == null) {
      return DetailScaffold(
        title: 'Vehicle details',
        footer: DrivioButton(
          label: 'Add a vehicle',
          onPressed: () => AppNavigation.push(AppRoutes.addVehicle),
        ),
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 30),
            child: Center(
              child: Text(
                'No active vehicle on your account.',
                style: AppTextStyles.bodySm.copyWith(color: context.textDim),
              ),
            ),
          ),
        ],
      );
    }

    final (String pillText, PillTone pillTone) = _statusPill(v.status);

    return DetailScaffold(
      title: 'Vehicle details',
      subtitle: '${v.make} ${v.model} · ${v.plate}',
      badge: Pill(text: pillText, tone: pillTone),
      footer: DrivioButton(
        label: 'Request vehicle change',
        variant: DrivioButtonVariant.ghost,
        onPressed: () => AppNavigation.push(AppRoutes.vehicleChange),
      ),
      children: <Widget>[
        Container(
          height: 140,
          decoration: BoxDecoration(
            color: context.surface,
            borderRadius: AppRadius.base,
            border: Border.all(color: context.border),
          ),
          alignment: Alignment.center,
          child: const Text('🚘', style: TextStyle(fontSize: 72)),
        ),
        const SizedBox(height: 16),
        GridView.count(
          crossAxisCount: 2,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 2.4,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: <Widget>[
            _StatBlock(label: 'Make', value: v.make),
            _StatBlock(label: 'Model', value: v.model),
            _StatBlock(label: 'Year', value: v.year > 0 ? '${v.year}' : '—'),
            _StatBlock(label: 'Colour', value: _titleCase(v.colour) ?? '—'),
            _StatBlock(label: 'Plate', value: v.plate, mono: true),
            _StatBlock(label: 'Seats', value: '${v.seats}'),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: context.surface2,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            'ℹ️ Changing your vehicle requires re-verification. You\'ll stay online during review.',
            style: AppTextStyles.captionSm.copyWith(
              fontSize: 11,
              color: context.textDim,
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }

  static (String, PillTone) _statusPill(VehicleStatus s) {
    switch (s) {
      case VehicleStatus.active:
        return ('APPROVED', PillTone.accent);
      case VehicleStatus.pending:
        return ('PENDING', PillTone.amber);
      case VehicleStatus.suspended:
        return ('SUSPENDED', PillTone.red);
      case VehicleStatus.retired:
        return ('RETIRED', PillTone.neutral);
    }
  }

  static String? _titleCase(String? s) {
    if (s == null || s.isEmpty) return null;
    return s[0].toUpperCase() + s.substring(1).toLowerCase();
  }
}

class _StatBlock extends StatelessWidget {
  const _StatBlock({required this.label, required this.value, this.mono = false});
  final String label;
  final String value;
  final bool mono;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.surface,
        borderRadius: AppRadius.md,
        border: Border.all(color: context.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label.toUpperCase(),
            style: AppTextStyles.eyebrow.copyWith(color: context.textDim),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: mono
                ? AppTextStyles.mono.copyWith(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: context.text,
                  )
                : AppTextStyles.body.copyWith(
                    color: context.text,
                    fontWeight: FontWeight.w700,
                  ),
          ),
        ],
      ),
    );
  }
}

/// Loading-state mirror of the page: hero box + 6-tile grid + footnote.
/// Single Shimmer ancestor so one sweep covers the whole skeleton.
class _VehicleDetailsShimmer extends StatelessWidget {
  const _VehicleDetailsShimmer({required this.base, required this.highlight});

  final Color base;
  final Color highlight;

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: base,
      highlightColor: highlight,
      period: const Duration(milliseconds: 1400),
      child: Column(
        children: <Widget>[
          Container(
            height: 140,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: AppRadius.base,
            ),
          ),
          const SizedBox(height: 16),
          GridView.count(
            crossAxisCount: 2,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 2.4,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: List<Widget>.generate(6, (int _) {
              return Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: AppRadius.md,
                ),
              );
            }),
          ),
          const SizedBox(height: 16),
          Container(
            height: 38,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ],
      ),
    );
  }
}
