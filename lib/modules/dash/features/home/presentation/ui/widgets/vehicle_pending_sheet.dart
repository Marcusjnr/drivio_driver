import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:drivio_driver/modules/commons/all.dart';
import 'package:drivio_driver/modules/commons/types/vehicle.dart';

class VehiclePendingSheet extends ConsumerWidget {
  const VehiclePendingSheet({
    super.key,
    required this.vehicle,
    required this.onDismiss,
  });

  final Vehicle? vehicle;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
                    color: context.amber.withValues(alpha: 0.16),
                    border: Border.all(
                      color: context.amber.withValues(alpha: 0.3),
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  alignment: Alignment.center,
                  child: const Text('🚘', style: TextStyle(fontSize: 26)),
                ),
                const SizedBox(height: 14),
                const Pill(text: 'AWAITING REVIEW', tone: PillTone.amber),
                const SizedBox(height: 10),
                Text(
                  'Your vehicle is\nunder review.',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.h1.copyWith(color: context.text),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: 290,
                  child: Text(
                    "We're verifying your details. You'll be able to go online as soon as your vehicle is approved — usually within 15 minutes.",
                    textAlign: TextAlign.center,
                    style: AppTextStyles.caption.copyWith(
                      color: context.textDim,
                      height: 1.5,
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                if (vehicle != null) _VehicleCard(vehicle: vehicle!),
                const SizedBox(height: 18),
                DrivioButton(
                  label: 'Got it',
                  onPressed: onDismiss,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _VehicleCard extends StatelessWidget {
  const _VehicleCard({required this.vehicle});
  final Vehicle vehicle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: context.surface2,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.border),
      ),
      child: Row(
        children: <Widget>[
          Icon(DrivioIcons.car, size: 22, color: context.text),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  '${vehicle.make} ${vehicle.model}'
                  '${vehicle.colour == null ? '' : ' · ${vehicle.colour}'}',
                  style: TextStyle(
                    fontSize: 13,
                    color: context.text,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${vehicle.year} · ${vehicle.plate}',
                  style: TextStyle(fontSize: 11, color: context.textDim),
                ),
              ],
            ),
          ),
          const Pill(text: 'Pending', tone: PillTone.amber),
        ],
      ),
    );
  }
}
